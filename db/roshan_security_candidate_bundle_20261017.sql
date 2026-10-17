-- Roshan Health Hub branch-isolation + finance-write security bundle.
-- Canonical ordered artifact for this set of five candidate changes.
-- Apply this file as ONE tracked migration only after the documented release gates
-- are satisfied; do not execute the component candidate files separately.
-- Source order: invoice items -> patient/visit children -> queue/follow-ups ->
-- prescription/lab children -> finance RPC-only writes.
-- Validation workflow applies this exact bundle to one PostgreSQL 17 schema.


-- ============================================================================
-- Component: db/roshan_invoice_item_branch_isolation.sql
-- ============================================================================

-- Focused remediation for invoice child-row branch isolation.
-- Apply only after the normal migration-history/replay review.
-- invoice_items has no branch_id; derive authorization from its parent invoice.
REVOKE ALL ON FUNCTION private.app_has_invoice_branch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_invoice_branch(uuid) TO authenticated;

ALTER POLICY invoice_items_select ON public.invoice_items
  USING (
    (
      (SELECT public.app_has_perm('billing.read'))
      OR (SELECT public.app_has_perm('billing.view'))
    )
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  );

ALTER POLICY invoice_items_insert ON public.invoice_items
  WITH CHECK (
    (SELECT public.app_has_perm('billing.create'))
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  );

ALTER POLICY invoice_items_update ON public.invoice_items
  USING (
    (
      (SELECT public.app_has_perm('billing.update'))
      OR (SELECT public.app_has_perm('billing.edit'))
    )
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  )
  WITH CHECK (
    (
      (SELECT public.app_has_perm('billing.update'))
      OR (SELECT public.app_has_perm('billing.edit'))
    )
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  );

ALTER POLICY invoice_items_delete ON public.invoice_items
  USING (
    (SELECT public.app_has_perm('billing.delete'))
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  );


-- ============================================================================
-- Component: db/roshan_parent_branch_isolation.sql
-- ============================================================================

-- Focused parent-branch isolation for child tables without branch_id.
-- This source migration is not production-applied; migration replay parity is a release gate.
REVOKE ALL ON FUNCTION private.app_has_patient_branch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_patient_branch(uuid) TO authenticated;
REVOKE ALL ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_patient_visit_branch_access(_patient_id uuid, _visit_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.app_has_attachment_branch_access(_patient_id, _visit_id)
    AND (
      _visit_id IS NULL
      OR _patient_id IS NULL
      OR EXISTS (
        SELECT 1
        FROM public.visits AS v
        WHERE v.id = _visit_id
          AND v.patient_id = _patient_id
      )
    )
$function$;
REVOKE ALL ON FUNCTION private.app_has_patient_visit_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_patient_visit_branch_access(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_procedure_order_branch_access(_order_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.procedure_orders AS po
    WHERE po.id = _order_id
      AND private.app_has_patient_visit_branch_access(po.patient_id, po.visit_id)
  )
$function$;
REVOKE ALL ON FUNCTION private.app_has_procedure_order_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_procedure_order_branch_access(uuid) TO authenticated;

ALTER POLICY certificates_select ON public.certificates
  USING (
    (SELECT public.app_has_perm('certificates.read'))
    AND (SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id))
  );
ALTER POLICY certificates_insert ON public.certificates
  WITH CHECK (
    (SELECT public.app_has_perm('certificates.create'))
    AND (SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id))
  );
ALTER POLICY certificates_update ON public.certificates
  USING (
    (SELECT public.app_has_perm('certificates.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('certificates.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id))
  );
ALTER POLICY certificates_delete ON public.certificates
  USING (
    (SELECT public.app_has_perm('certificates.delete'))
    AND (SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id))
  );

ALTER POLICY medical_certificates_select ON public.medical_certificates
  USING (
    (SELECT public.app_has_perm('certificates.read'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  );
ALTER POLICY medical_certificates_insert ON public.medical_certificates
  WITH CHECK (
    (SELECT public.app_has_perm('certificates.create'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  );
ALTER POLICY medical_certificates_update ON public.medical_certificates
  USING (
    (SELECT public.app_has_perm('certificates.update'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('certificates.update'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  );
ALTER POLICY medical_certificates_delete ON public.medical_certificates
  USING (
    (SELECT public.app_has_perm('certificates.delete'))
    AND (SELECT private.app_has_patient_branch(medical_certificates.patient_id))
  );

ALTER POLICY patient_discounts_select ON public.patient_discounts
  USING (
    (
      (SELECT public.app_has_perm('billing.read'))
      OR (SELECT public.app_has_perm('patients.read'))
    )
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  );
ALTER POLICY patient_discounts_insert ON public.patient_discounts
  WITH CHECK (
    (SELECT public.app_has_perm('billing.create'))
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  );
ALTER POLICY patient_discounts_update ON public.patient_discounts
  USING (
    (
      (SELECT public.app_has_perm('billing.update'))
      OR (SELECT public.app_has_perm('billing.edit'))
    )
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  )
  WITH CHECK (
    (
      (SELECT public.app_has_perm('billing.update'))
      OR (SELECT public.app_has_perm('billing.edit'))
    )
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  );
ALTER POLICY patient_discounts_delete ON public.patient_discounts
  USING (
    (SELECT public.app_has_perm('billing.delete'))
    AND (SELECT private.app_has_patient_branch(patient_discounts.patient_id))
  );

ALTER POLICY procedure_orders_select ON public.procedure_orders
  USING (
    (SELECT public.app_has_perm('procedures.read'))
    AND (SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  );
ALTER POLICY procedure_orders_insert ON public.procedure_orders
  WITH CHECK (
    (SELECT public.app_has_perm('procedures.create'))
    AND (SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  );
ALTER POLICY procedure_orders_update ON public.procedure_orders
  USING (
    (SELECT public.app_has_perm('procedures.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('procedures.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  );
ALTER POLICY procedure_orders_delete ON public.procedure_orders
  USING (
    (SELECT public.app_has_perm('procedures.delete'))
    AND (SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id))
  );

ALTER POLICY procedure_results_select ON public.procedure_results
  USING (
    (SELECT public.app_has_perm('procedures.read'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  );
ALTER POLICY procedure_results_insert ON public.procedure_results
  WITH CHECK (
    (SELECT public.app_has_perm('procedures.create'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  );
ALTER POLICY procedure_results_update ON public.procedure_results
  USING (
    (SELECT public.app_has_perm('procedures.update'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('procedures.update'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  );
ALTER POLICY procedure_results_delete ON public.procedure_results
  USING (
    (SELECT public.app_has_perm('procedures.delete'))
    AND (SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id))
  );


-- ============================================================================
-- Component: db/roshan_queue_followup_branch_isolation.sql
-- ============================================================================

-- Parent-branch authorization for queue tickets and follow-ups.
-- Source-only: do not apply to production until migration replay parity is resolved.
CREATE OR REPLACE FUNCTION private.app_has_patient_visit_branch_access(_patient_id uuid, _visit_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
  SELECT private.app_has_attachment_branch_access(_patient_id, _visit_id)
    AND (
      _visit_id IS NULL
      OR _patient_id IS NULL
      OR EXISTS (
        SELECT 1 FROM public.visits AS v
        WHERE v.id = _visit_id AND v.patient_id = _patient_id
      )
    )
$function$;
REVOKE ALL ON FUNCTION private.app_has_patient_visit_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_patient_visit_branch_access(uuid, uuid) TO authenticated;

REVOKE ALL ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) TO authenticated;

ALTER POLICY followups_select ON public.followups
  USING ((SELECT public.app_has_perm('followups.read'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)));
ALTER POLICY followups_insert ON public.followups
  WITH CHECK ((SELECT public.app_has_perm('followups.create'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)));
ALTER POLICY followups_update ON public.followups
  USING ((SELECT public.app_has_perm('followups.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)))
  WITH CHECK ((SELECT public.app_has_perm('followups.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)));
ALTER POLICY followups_delete ON public.followups
  USING ((SELECT public.app_has_perm('followups.delete'))
    AND (SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id)));

ALTER POLICY queue_tickets_sel ON public.queue_tickets
  USING ((SELECT public.app_has_perm('queue.read'))
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)));
ALTER POLICY queue_tickets_ins ON public.queue_tickets
  WITH CHECK ((SELECT public.app_has_perm('queue.create'))
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)));
ALTER POLICY queue_tickets_upd ON public.queue_tickets
  USING ((SELECT public.app_has_perm('queue.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)))
  WITH CHECK ((SELECT public.app_has_perm('queue.update'))
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)));
ALTER POLICY queue_tickets_del ON public.queue_tickets
  USING ((SELECT public.is_super_admin())
    AND (SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id)));


-- ============================================================================
-- Component: db/roshan_prescription_lab_child_branch_isolation.sql
-- ============================================================================

-- Parent-branch isolation for prescriptions, prescription items, and lab-order items.
-- Source-only candidate: never apply to live Supabase before migration replay parity review.
REVOKE ALL ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_attachment_branch_access(uuid, uuid) TO authenticated;
REVOKE ALL ON FUNCTION private.app_has_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_branch_access(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_prescription_parent_branch_access(_patient_id uuid, _visit_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT private.app_has_attachment_branch_access(_patient_id, _visit_id)
    AND (
      _visit_id IS NULL OR _patient_id IS NULL
      OR EXISTS (SELECT 1 FROM public.visits v WHERE v.id=_visit_id AND v.patient_id=_patient_id)
    )
$function$;
REVOKE ALL ON FUNCTION private.app_has_prescription_parent_branch_access(uuid, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_prescription_parent_branch_access(uuid, uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_prescription_branch_access(_prescription_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.prescriptions p
    WHERE p.id=_prescription_id
      AND private.app_has_prescription_parent_branch_access(p.patient_id, p.visit_id)
  )
$function$;
REVOKE ALL ON FUNCTION private.app_has_prescription_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_prescription_branch_access(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION private.app_has_lab_order_item_branch_access(_order_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.lab_orders lo
    WHERE lo.id=_order_id
      AND private.app_has_branch_access(lo.branch_id)
      AND private.app_has_attachment_branch_access(lo.patient_id, lo.visit_id)
      AND (
        lo.visit_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.visits v
          WHERE v.id = lo.visit_id AND v.patient_id = lo.patient_id
        )
      )
  )
$function$;
REVOKE ALL ON FUNCTION private.app_has_lab_order_item_branch_access(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_lab_order_item_branch_access(uuid) TO authenticated;

ALTER POLICY prescriptions_select ON public.prescriptions
  USING (
    ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_insert ON public.prescriptions
  WITH CHECK (
    ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_update ON public.prescriptions
  USING (
    ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  )
  WITH CHECK (
    ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );
ALTER POLICY prescriptions_delete ON public.prescriptions
  USING (
    ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')))
    AND (SELECT private.app_has_prescription_parent_branch_access(prescriptions.patient_id, prescriptions.visit_id))
  );

ALTER POLICY prescription_items_select ON public.prescription_items
  USING (
    ((SELECT public.app_has_perm('pharmacy.read')) OR (SELECT public.app_has_perm('emr.read')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_insert ON public.prescription_items
  WITH CHECK (
    ((SELECT public.app_has_perm('pharmacy.create')) OR (SELECT public.app_has_perm('emr.create')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_update ON public.prescription_items
  USING (
    ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  )
  WITH CHECK (
    ((SELECT public.app_has_perm('pharmacy.update')) OR (SELECT public.app_has_perm('emr.update')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );
ALTER POLICY prescription_items_delete ON public.prescription_items
  USING (
    ((SELECT public.app_has_perm('pharmacy.delete')) OR (SELECT public.app_has_perm('emr.delete')))
    AND (SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id))
  );

ALTER POLICY lab_order_items_select ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.read'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_insert ON public.lab_order_items
  WITH CHECK (
    (SELECT public.app_has_perm('lab.create'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_update ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.update'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  )
  WITH CHECK (
    (SELECT public.app_has_perm('lab.update'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  );
ALTER POLICY lab_order_items_delete ON public.lab_order_items
  USING (
    (SELECT public.app_has_perm('lab.delete'))
    AND (SELECT private.app_has_lab_order_item_branch_access(lab_order_items.order_id))
  );


-- ============================================================================
-- Component: db/roshan_phase27_finance_rpc_only_writes.sql
-- ============================================================================

-- Finance-only direct-write hardening, split from the insurance-coupled draft.
-- Source-only candidate. Do not apply before full migration-source parity review.
-- Existing UI uses post_cashbox_entry; add_cashbox_entry is legacy and has no current
-- application call sites, so retire its authenticated EXECUTE path after verification.

CREATE OR REPLACE FUNCTION public.post_cashbox_entry(
  _direction text,
  _amount numeric,
  _method text DEFAULT 'cash',
  _category text DEFAULT 'manual',
  _description text DEFAULT NULL,
  _date timestamptz DEFAULT now()
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  signed_amount numeric;
  new_id uuid;
  uid uuid;
  bid uuid;
BEGIN
  IF NOT public.app_has_perm('cashbox.create')
     AND NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to post cashbox entries' USING ERRCODE = '42501';
  END IF;
  IF _amount IS NULL OR _amount::text IN ('NaN','Infinity','-Infinity') OR _amount <= 0 THEN
    RAISE EXCEPTION 'amount must be finite and greater than zero' USING ERRCODE = '22023';
  END IF;
  IF _direction IS NULL OR _direction NOT IN ('deposit','withdrawal') THEN
    RAISE EXCEPTION 'direction must be deposit or withdrawal' USING ERRCODE = '22023';
  END IF;
  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id=uid AND deleted_at IS NULL AND active IS TRUE;
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

CREATE OR REPLACE FUNCTION public.post_invoice_payment(
  _invoice_id uuid,
  _amount numeric,
  _method text DEFAULT 'cash',
  _reference text DEFAULT NULL,
  _idempotency_key text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  net numeric;
  already numeric;
  outstanding numeric;
  pay_id uuid;
  uid uuid;
  invoice_branch uuid;
  user_branch uuid;
  existing_actor uuid;
  existing_invoice_id uuid;
  existing_amount numeric;
  existing_method text;
  existing_reference text;
BEGIN
  IF NOT public.app_has_perm('payments.create')
     AND NOT public.app_has_perm('billing.create')
     AND NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to record payments' USING ERRCODE = '42501';
  END IF;
  IF _amount IS NULL OR _amount::text IN ('NaN','Infinity','-Infinity') OR _amount <= 0 THEN
    RAISE EXCEPTION 'payment amount must be finite and greater than zero' USING ERRCODE = '22023';
  END IF;
  IF _invoice_id IS NULL THEN RAISE EXCEPTION 'invoice is required' USING ERRCODE = '22023'; END IF;
  uid := public.current_app_user_id();
  SELECT branch_id INTO user_branch FROM public.users WHERE id=uid AND deleted_at IS NULL AND active IS TRUE;
  IF NOT public.is_super_admin() AND user_branch IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501';
  END IF;
  IF _idempotency_key IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended('roshan.payment.idempotency:' || _idempotency_key,0)
    );
    SELECT p.id,p.created_by,p.invoice_id,p.amount,
           COALESCE(p.payment_method,p.method,'cash'),
           NULLIF(BTRIM(COALESCE(p.reference_no,p.reference,'')),'')
      INTO pay_id,existing_actor,existing_invoice_id,existing_amount,existing_method,existing_reference
    FROM public.payments p WHERE p.idempotency_key=_idempotency_key;
    IF pay_id IS NOT NULL THEN
      IF existing_actor IS DISTINCT FROM uid
         OR existing_invoice_id IS DISTINCT FROM _invoice_id
         OR existing_amount IS DISTINCT FROM _amount
         OR existing_method IS DISTINCT FROM COALESCE(_method,'cash')
         OR existing_reference IS DISTINCT FROM NULLIF(BTRIM(COALESCE(_reference,'')),'') THEN
        RAISE EXCEPTION 'idempotency key reused with different payment request' USING ERRCODE = '22023';
      END IF;
      RETURN pay_id;
    END IF;
  END IF;
  SELECT COALESCE(i.net_amount,i.total_amount,0),COALESCE(i.paid_amount,0),i.branch_id
    INTO net,already,invoice_branch
  FROM public.invoices i WHERE i.id=_invoice_id AND i.deleted_at IS NULL FOR UPDATE;
  IF net IS NULL THEN RAISE EXCEPTION 'invoice not found' USING ERRCODE = '22023'; END IF;
  IF NOT public.is_super_admin() AND invoice_branch IS DISTINCT FROM user_branch THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;
  outstanding := GREATEST(net-already,0);
  IF _amount > outstanding THEN
    RAISE EXCEPTION 'payment (%) exceeds outstanding balance (%)',_amount,outstanding USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.payments(
    invoice_id,amount,payment_method,method,reference_no,reference,payment_date,received_at,received_by,created_by,branch_id,idempotency_key
  ) VALUES (
    _invoice_id,_amount,COALESCE(_method,'cash'),COALESCE(_method,'cash'),
    NULLIF(BTRIM(COALESCE(_reference,'')),''),NULLIF(BTRIM(COALESCE(_reference,'')),''),
    CURRENT_DATE,now(),uid,uid,invoice_branch,_idempotency_key
  ) RETURNING id INTO pay_id;
  RETURN pay_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.post_supplier_bill(
  _supplier_id uuid,
  _invoice_number text,
  _bill_date date,
  _due_date date,
  _subtotal numeric,
  _discount numeric DEFAULT 0,
  _notes text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  bill_id uuid;
  uid uuid;
  user_branch uuid;
  is_admin boolean;
  discount_value numeric := COALESCE(_discount,0);
  net numeric;
BEGIN
  IF NOT private.app_has_perm('debts.create')
     AND NOT private.app_has_perm('accounting.create')
     AND NOT private.app_has_perm('pharmacy.create') THEN
    RAISE EXCEPTION 'not authorised to record supplier bills' USING ERRCODE = '42501';
  END IF;
  IF _supplier_id IS NULL THEN RAISE EXCEPTION 'supplier is required' USING ERRCODE = '22023'; END IF;
  IF _subtotal IS NULL OR _subtotal::text IN ('NaN','Infinity','-Infinity') OR _subtotal <= 0 THEN
    RAISE EXCEPTION 'bill subtotal must be finite and greater than zero' USING ERRCODE = '22023';
  END IF;
  IF discount_value::text IN ('NaN','Infinity','-Infinity') OR discount_value < 0 OR discount_value > _subtotal THEN
    RAISE EXCEPTION 'discount must be finite and between zero and subtotal' USING ERRCODE = '22023';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.suppliers s WHERE s.id=_supplier_id AND s.deleted_at IS NULL AND s.active IS TRUE
  ) THEN RAISE EXCEPTION 'active supplier not found' USING ERRCODE = '22023'; END IF;
  uid := private.current_app_user_id();
  is_admin := private.is_super_admin();
  SELECT u.branch_id INTO user_branch FROM public.users u
   WHERE u.id=uid AND u.deleted_at IS NULL AND u.active IS TRUE;
  IF user_branch IS NULL AND NOT is_admin THEN
    RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501';
  END IF;
  net := _subtotal-discount_value;
  INSERT INTO public.supplier_bills(
    supplier_id,branch_id,invoice_number,bill_date,due_date,subtotal,discount_amount,total_amount,paid_amount,status,notes,created_by
  ) VALUES (
    _supplier_id,user_branch,NULLIF(BTRIM(COALESCE(_invoice_number,'')),''),COALESCE(_bill_date,CURRENT_DATE),
    _due_date,_subtotal,discount_value,net,0,'unpaid',_notes,uid
  ) RETURNING id INTO bill_id;
  RETURN bill_id;
END;
$function$;

-- These five tables are written only through validated security-definer RPCs.
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.cashbox_transactions, public.expenses, public.payments,
           public.supplier_bills, public.supplier_payments
  FROM PUBLIC, anon, authenticated;

-- Retire the unused legacy cashbox RPC; the app calls post_cashbox_entry.
REVOKE EXECUTE ON FUNCTION public.add_cashbox_entry(text,numeric,text,text,text,text,timestamptz)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.post_cashbox_entry(text,numeric,text,text,text,timestamptz) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_cashbox_entry(text,numeric,text,text,text,timestamptz) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.post_expense(text,numeric,text,date,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_expense(text,numeric,text,date,text,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.post_invoice_payment(uuid,numeric,text,text,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_invoice_payment(uuid,numeric,text,text,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.post_supplier_bill(uuid,text,date,date,numeric,numeric,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_supplier_bill(uuid,text,date,date,numeric,numeric,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.post_supplier_payment(uuid,numeric,text,text,date,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.post_supplier_payment(uuid,numeric,text,text,date,text) TO authenticated;
REVOKE EXECUTE ON FUNCTION public.reverse_cashbox_entry(uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reverse_cashbox_entry(uuid,text) TO authenticated;
