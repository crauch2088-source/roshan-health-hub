-- Phase 31: security and clinical workflow hardening.
-- PRECONDITIONS: deploy the matching frontend first, then run authenticated smoke tests.
-- Prepared in Git only; do not apply to production until explicit approval.
-- Live PostgreSQL 17 schema verified: results are in lab_results; queue_tickets has visit_id/status/completed_at;
-- medical_certificates has serial integer id; supplier_bills has total_amount/paid_amount.
-- Re-run duplicate preflight in docs/CLINICAL_SECURITY_HARDENING_PREFLIGHT_2026-10-18.md immediately before rollout.
BEGIN;

CREATE OR REPLACE FUNCTION private.current_app_user_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT u.id FROM public.users AS u
  WHERE u.auth_user_id = auth.uid()
    AND COALESCE(u.active, true) = true
    AND u.deleted_at IS NULL
  ORDER BY u.id LIMIT 1
$function$;

CREATE OR REPLACE FUNCTION private.app_has_perm(_code text)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.users AS u
    WHERE u.auth_user_id = auth.uid()
      AND COALESCE(u.active, true) = true
      AND u.deleted_at IS NULL
      AND (
        (SELECT private.is_super_admin())
        OR EXISTS (
          SELECT 1 FROM public.role_permissions AS rp
          JOIN public.permissions AS p ON p.id = rp.permission_id
          WHERE rp.role_id = u.role_id AND p.code = _code
        )
      )
  )
$function$;

CREATE OR REPLACE FUNCTION public.post_cashbox_entry(
  _direction text, _amount numeric, _method text DEFAULT 'cash'::text,
  _category text DEFAULT 'manual'::text, _description text DEFAULT NULL::text,
  _date timestamp with time zone DEFAULT now()
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE signed_amount numeric; new_id uuid; uid uuid; bid uuid;
BEGIN
  IF NOT public.app_has_perm('cashbox.create')
     AND NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to post cashbox entries' USING ERRCODE = '42501';
  END IF;
  IF _amount IS NULL OR _amount::text IN ('NaN','Infinity','-Infinity')
     OR _amount <= 0 OR _amount <> pg_catalog.round(_amount, 2) THEN
    RAISE EXCEPTION 'amount must be finite, positive, with at most two decimals' USING ERRCODE = '22023';
  END IF;
  IF _direction IS NULL OR _direction NOT IN ('deposit','withdrawal') THEN
    RAISE EXCEPTION 'direction must be deposit or withdrawal' USING ERRCODE = '22023';
  END IF;
  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users
  WHERE id=uid AND deleted_at IS NULL AND active IS TRUE;
  IF NOT public.is_super_admin() AND bid IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501';
  END IF;
  signed_amount := CASE WHEN _direction='deposit' THEN _amount ELSE -_amount END;
  INSERT INTO public.cashbox_transactions(
    branch_id,transaction_type,amount,payment_method,category,description,source_type,transaction_date,created_by
  ) VALUES (
    bid,_direction,signed_amount,COALESCE(_method,'cash'),COALESCE(_category,'manual'),
    _description,'manual',COALESCE(_date,now()),uid
  ) RETURNING id INTO new_id;
  RETURN new_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.post_supplier_payment(
  _bill_id uuid, _amount numeric, _method text DEFAULT 'cash'::text,
  _reference text DEFAULT NULL::text, _payment_date date DEFAULT CURRENT_DATE,
  _notes text DEFAULT NULL::text
)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE bill public.supplier_bills; outstanding numeric; pay_id uuid; uid uuid; user_br uuid;
BEGIN
  IF NOT public.app_has_perm('debts.create') AND NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to pay suppliers' USING ERRCODE = '42501';
  END IF;
  IF _amount IS NULL OR _amount::text IN ('NaN','Infinity','-Infinity')
     OR _amount <= 0 OR _amount <> pg_catalog.round(_amount, 2) THEN
    RAISE EXCEPTION 'amount must be finite, positive, with at most two decimals' USING ERRCODE = '22023';
  END IF;
  uid := public.current_app_user_id();
  SELECT branch_id INTO user_br FROM public.users
  WHERE id=uid AND deleted_at IS NULL AND active IS TRUE;
  IF NOT public.is_super_admin() AND user_br IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501';
  END IF;
  SELECT * INTO bill FROM public.supplier_bills
  WHERE id=_bill_id AND deleted_at IS NULL FOR UPDATE;
  IF bill.id IS NULL THEN RAISE EXCEPTION 'supplier bill not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT public.is_super_admin() AND bill.branch_id IS DISTINCT FROM user_br THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;
  outstanding := greatest(coalesce(bill.total_amount,0)-coalesce(bill.paid_amount,0),0);
  IF _amount > outstanding THEN
    RAISE EXCEPTION 'payment (%) exceeds outstanding balance (%)',_amount,outstanding USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.supplier_payments(
    supplier_bill_id,supplier_id,branch_id,amount,payment_method,reference,payment_date,notes,created_by
  ) VALUES (
    bill.id,bill.supplier_id,bill.branch_id,_amount,coalesce(_method,'cash'),
    nullif(btrim(coalesce(_reference,'')),''),coalesce(_payment_date,current_date),_notes,uid
  ) RETURNING id INTO pay_id;
  RETURN pay_id;
END;
$function$;

-- Both duplicate preflight checks returned zero groups / zero excess rows.
CREATE UNIQUE INDEX IF NOT EXISTS patients_active_national_id_normalized_uq
  ON public.patients (pg_catalog.lower(pg_catalog.btrim(national_id)))
  WHERE deleted_at IS NULL AND national_id IS NOT NULL AND pg_catalog.btrim(national_id) <> '';
CREATE UNIQUE INDEX IF NOT EXISTS insurance_claims_one_active_nonrejected_per_invoice_uq
  ON public.insurance_claims (invoice_id)
  WHERE deleted_at IS NULL AND invoice_id IS NOT NULL AND status IS DISTINCT FROM 'rejected';

CREATE OR REPLACE FUNCTION public.complete_visit_atomic(p_visit_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_user_id uuid; v_status text;
BEGIN
  IF NOT public.app_has_perm('visits.update') THEN
    RAISE EXCEPTION 'visit update permission required' USING ERRCODE = '42501';
  END IF;
  IF p_visit_id IS NULL THEN RAISE EXCEPTION 'visit is required' USING ERRCODE = '22023'; END IF;
  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE = '42501';
  END IF;
  SELECT v.status INTO v_status FROM public.visits AS v
  WHERE v.id = p_visit_id AND v.deleted_at IS NULL FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'visit not found' USING ERRCODE = 'P0002'; END IF;
  IF NOT private.app_has_visit_branch_access(p_visit_id) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_status = 'cancelled' THEN
    RAISE EXCEPTION 'cancelled visit cannot be completed' USING ERRCODE = '22023';
  END IF;
  UPDATE public.visits
  SET status='completed', completed_at=COALESCE(completed_at, pg_catalog.now()),
      updated_by=v_user_id, updated_at=pg_catalog.now()
  WHERE id=p_visit_id AND deleted_at IS NULL;
  UPDATE public.queue_tickets
  SET status='completed', completed_at=COALESCE(completed_at, pg_catalog.now()), updated_by=v_user_id
  WHERE visit_id=p_visit_id AND deleted_at IS NULL AND status IN ('waiting','called','in_progress');
END;
$function$;

CREATE OR REPLACE FUNCTION public.complete_lab_order_item(p_order_item_id uuid)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_order_id uuid; v_status text; v_user_id uuid;
BEGIN
  IF NOT public.app_has_perm('lab.update') THEN
    RAISE EXCEPTION 'lab update permission required' USING ERRCODE = '42501';
  END IF;
  IF p_order_item_id IS NULL THEN RAISE EXCEPTION 'lab order item is required' USING ERRCODE = '22023'; END IF;
  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE = '42501';
  END IF;
  SELECT item.order_id, item.status INTO v_order_id, v_status
  FROM public.lab_order_items AS item
  JOIN public.lab_orders AS orders ON orders.id = item.order_id
  WHERE item.id=p_order_item_id AND item.deleted_at IS NULL AND orders.deleted_at IS NULL
  FOR UPDATE OF item;
  IF NOT FOUND OR v_order_id IS NULL THEN
    RAISE EXCEPTION 'lab order item not found' USING ERRCODE = 'P0002';
  END IF;
  IF NOT private.app_has_lab_order_item_branch_access(v_order_id) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;
  IF v_status NOT IN ('pending','ordered','sample_collected','in_progress') THEN
    RAISE EXCEPTION 'invalid lab status transition' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.lab_results AS result
    WHERE result.order_item_id=p_order_item_id AND result.deleted_at IS NULL
      AND (result.numeric_value IS NOT NULL
        OR NULLIF(pg_catalog.btrim(COALESCE(result.result_value,'')), '') IS NOT NULL)
  ) THEN
    RAISE EXCEPTION 'lab result is required before completion' USING ERRCODE = '22023';
  END IF;
  UPDATE public.lab_order_items
  SET status='completed', completed_at=COALESCE(completed_at, pg_catalog.now()), updated_by=v_user_id
  WHERE id=p_order_item_id AND deleted_at IS NULL
    AND status IN ('pending','ordered','sample_collected','in_progress');
  IF NOT FOUND THEN RAISE EXCEPTION 'invalid lab status transition' USING ERRCODE = '22023'; END IF;
END;
$function$;

ALTER TABLE public.medical_certificates ADD COLUMN IF NOT EXISTS visit_id uuid;
DO $constraint$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_constraint
    WHERE conname='medical_certificates_visit_id_fkey'
      AND conrelid='public.medical_certificates'::regclass
  ) THEN
    ALTER TABLE public.medical_certificates
      ADD CONSTRAINT medical_certificates_visit_id_fkey
      FOREIGN KEY (visit_id) REFERENCES public.visits(id) ON DELETE RESTRICT NOT VALID;
  END IF;
END;
$constraint$;
ALTER TABLE public.medical_certificates VALIDATE CONSTRAINT medical_certificates_visit_id_fkey;
-- The live preflight found zero certificate rows. Fail closed if rows appear before rollout;
-- never invent historical visit links to satisfy this invariant.
ALTER TABLE public.medical_certificates ALTER COLUMN visit_id SET NOT NULL;

CREATE SEQUENCE IF NOT EXISTS public.medical_certificate_number_seq;
ALTER TABLE public.medical_certificates ADD COLUMN IF NOT EXISTS certificate_number bigint;
UPDATE public.medical_certificates SET certificate_number=id WHERE certificate_number IS NULL;
SELECT pg_catalog.setval(
  'public.medical_certificate_number_seq'::regclass,
  GREATEST(COALESCE((SELECT MAX(certificate_number) FROM public.medical_certificates),0)+1,1),
  false
);
ALTER TABLE public.medical_certificates
  ALTER COLUMN certificate_number SET DEFAULT nextval('public.medical_certificate_number_seq'::regclass);
ALTER TABLE public.medical_certificates ALTER COLUMN certificate_number SET NOT NULL;
ALTER SEQUENCE public.medical_certificate_number_seq OWNED BY public.medical_certificates.certificate_number;
CREATE UNIQUE INDEX IF NOT EXISTS medical_certificates_certificate_number_uq
  ON public.medical_certificates (certificate_number);

CREATE OR REPLACE FUNCTION public.create_medical_certificate(
  p_patient_id uuid, p_diagnosis text, p_start_date date, p_end_date date, p_visit_id uuid
)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE v_user_id uuid; v_certificate_id integer; v_visit_patient_id uuid;
BEGIN
  IF NOT public.app_has_perm('certificates.create') THEN
    RAISE EXCEPTION 'certificate create permission required' USING ERRCODE = '42501';
  END IF;
  v_user_id := public.current_app_user_id();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'active application user required' USING ERRCODE = '42501';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.users AS u
    JOIN public.roles AS r ON r.id=u.role_id
    WHERE u.id=v_user_id AND u.deleted_at IS NULL
      AND COALESCE(u.active,true)=true AND r.code='doctor'
  ) THEN
    RAISE EXCEPTION 'only a doctor may issue medical certificates' USING ERRCODE = '42501';
  END IF;
  IF p_patient_id IS NULL OR p_visit_id IS NULL THEN
    RAISE EXCEPTION 'patient and visit are required' USING ERRCODE = '22023';
  END IF;
  IF p_start_date IS NULL OR p_end_date IS NULL OR p_end_date < p_start_date THEN
    RAISE EXCEPTION 'certificate dates are invalid' USING ERRCODE = '22023';
  END IF;
  IF NULLIF(pg_catalog.btrim(COALESCE(p_diagnosis,'')), '') IS NULL THEN
    RAISE EXCEPTION 'certificate diagnosis is required' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.patients AS p
    WHERE p.id=p_patient_id AND p.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'active patient not found' USING ERRCODE = 'P0002';
  END IF;
  SELECT v.patient_id INTO v_visit_patient_id
  FROM public.visits AS v WHERE v.id=p_visit_id AND v.deleted_at IS NULL;
  IF NOT FOUND OR v_visit_patient_id IS DISTINCT FROM p_patient_id THEN
    RAISE EXCEPTION 'visit does not belong to the selected patient' USING ERRCODE = '22023';
  END IF;
  IF NOT private.app_has_visit_branch_access(p_visit_id)
     OR NOT private.app_has_patient_branch(p_patient_id) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;
  INSERT INTO public.medical_certificates(
    patient_id,doctor_id,diagnosis,start_date,end_date,visit_id
  ) VALUES (
    p_patient_id,v_user_id,pg_catalog.btrim(p_diagnosis),p_start_date,p_end_date,p_visit_id
  ) RETURNING id INTO v_certificate_id;
  RETURN v_certificate_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.create_medical_certificate(uuid,text,date,date) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_medical_certificate(uuid,text,date,date,uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_medical_certificate(uuid,text,date,date,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.fn_dispense_prescription(uuid) FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.lab_order_items FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.medical_certificates FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.medical_certificates_id_seq FROM PUBLIC, anon, authenticated;
REVOKE ALL ON SEQUENCE public.medical_certificate_number_seq FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_visit_atomic(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_visit_atomic(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.complete_lab_order_item(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_lab_order_item(uuid) TO authenticated;
COMMIT;
