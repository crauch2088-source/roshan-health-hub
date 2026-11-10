-- Disposable PostgreSQL 17 fixture for Phase 61 only. No hosted data is used.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticator') THEN CREATE ROLE authenticator NOLOGIN; END IF;
END
$roles$;
CREATE SCHEMA IF NOT EXISTS private;

CREATE TABLE public.branches(id uuid PRIMARY KEY);
CREATE TABLE public.users(
 id uuid PRIMARY KEY, branch_id uuid REFERENCES public.branches(id),
 active boolean DEFAULT true, deleted_at timestamptz
);
CREATE TABLE public.patients(id uuid PRIMARY KEY, branch_id uuid NOT NULL REFERENCES public.branches(id), deleted_at timestamptz);
CREATE TABLE public.visits(
 id uuid PRIMARY KEY, patient_id uuid NOT NULL REFERENCES public.patients(id),
 branch_id uuid NOT NULL REFERENCES public.branches(id), status text DEFAULT 'in_progress',
 deleted_at timestamptz
);
CREATE TABLE public.medicines(
 id uuid PRIMARY KEY, name text, generic_name text, selling_price numeric,
 active boolean DEFAULT true, is_active boolean DEFAULT true, deleted_at timestamptz
);
CREATE TABLE public.prescriptions(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), patient_id uuid NOT NULL REFERENCES public.patients(id),
 visit_id uuid REFERENCES public.visits(id), prescribed_by uuid REFERENCES public.users(id),
 doctor_id uuid REFERENCES public.users(id), branch_id uuid REFERENCES public.branches(id),
 status text DEFAULT 'pending', is_external boolean DEFAULT false, created_by uuid,
 created_at timestamptz DEFAULT now(), updated_by uuid, updated_at timestamptz DEFAULT now(),
 deleted_at timestamptz, deleted_by uuid
);
CREATE TABLE public.prescription_items(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), prescription_id uuid NOT NULL REFERENCES public.prescriptions(id) ON DELETE CASCADE,
 medicine_id uuid REFERENCES public.medicines(id), medication_name varchar, dose varchar, dosage text,
 frequency varchar, duration varchar, quantity numeric, instructions text, dosage_form text, route text,
 unit_price numeric DEFAULT 0, is_dispensed boolean DEFAULT false, dispensed_quantity integer DEFAULT 0,
 created_by uuid, updated_by uuid, created_at timestamptz DEFAULT now(), updated_at timestamptz DEFAULT now(),
 deleted_at timestamptz, deleted_by uuid
);
CREATE TABLE public.pharmacy_inventory(id uuid PRIMARY KEY, quantity_remaining numeric);
CREATE TABLE public.stock_movements(id uuid PRIMARY KEY, quantity numeric);
CREATE TABLE public.invoices(id uuid PRIMARY KEY, total numeric);
CREATE TABLE public.invoice_items(id uuid PRIMARY KEY, quantity numeric);
CREATE TABLE public.payments(id uuid PRIMARY KEY, amount numeric);
CREATE TABLE public.cashbox_transactions(id uuid PRIMARY KEY, amount numeric);

CREATE FUNCTION public.current_app_user_id() RETURNS uuid
LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT NULLIF(current_setting('test.user_id',true),'')::uuid $$;
CREATE FUNCTION public.app_has_perm(p_code text) RETURNS boolean
LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT p_code = ANY(string_to_array(COALESCE(current_setting('test.permissions',true),''),',')) $$;
CREATE FUNCTION public.is_super_admin() RETURNS boolean
LANGUAGE sql STABLE SET search_path TO ''
AS $$ SELECT COALESCE(current_setting('test.super_admin',true)='true',false) $$;
CREATE FUNCTION private.app_has_branch_access(p_branch uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $$ SELECT public.is_super_admin() OR EXISTS(SELECT 1 FROM public.users u WHERE u.id=public.current_app_user_id() AND u.branch_id=p_branch AND u.active AND u.deleted_at IS NULL) $$;

CREATE FUNCTION public.create_prescription_atomic(p_visit_id uuid,p_is_external boolean,p_items jsonb)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
DECLARE v_uid uuid:=public.current_app_user_id(); v_patient uuid; v_branch uuid; v_rx uuid; v_item jsonb;
BEGIN
 IF v_uid IS NULL OR NOT public.app_has_perm('emr.create') THEN RAISE EXCEPTION 'not authorised to create prescriptions'; END IF;
 SELECT patient_id,branch_id INTO v_patient,v_branch FROM public.visits WHERE id=p_visit_id AND deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
 INSERT INTO public.prescriptions(patient_id,visit_id,prescribed_by,doctor_id,branch_id,status,is_external,created_by)
 VALUES(v_patient,p_visit_id,v_uid,v_uid,v_branch,'pending',COALESCE(p_is_external,false),v_uid) RETURNING id INTO v_rx;
 FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) x(value) LOOP
   INSERT INTO public.prescription_items(prescription_id,medicine_id,medication_name,quantity,dose,dosage,frequency,duration,instructions,dosage_form,route,unit_price,created_by,updated_by)
   VALUES(v_rx,NULLIF(v_item->>'medicine_id','')::uuid,v_item->>'medication_name',(v_item->>'quantity')::numeric,
     v_item->>'dose',v_item->>'dose',v_item->>'frequency',v_item->>'duration',v_item->>'instructions',
     v_item->>'dosage_form',v_item->>'route',0,v_uid,v_uid);
 END LOOP;
 RETURN v_rx;
END $$;
GRANT USAGE ON SCHEMA public,private TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_app_user_id(),public.app_has_perm(text),public.is_super_admin() TO authenticated;
GRANT SELECT ON public.prescriptions,public.prescription_items,public.users,public.patients,public.visits,public.medicines TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_prescription_atomic(uuid,boolean,jsonb) TO authenticated;
