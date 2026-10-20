-- Disposable PostgreSQL 17 behavioral fixture for Phase 36 only.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
DO $roles$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END $roles$;
CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  table_name text NOT NULL,
  record_id uuid,
  action text NOT NULL,
  user_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE OR REPLACE FUNCTION public.audit_row_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
AS $audit$
BEGIN
  INSERT INTO public.audit_logs(table_name,record_id,action,old_data,new_data)
  VALUES (TG_TABLE_NAME, (CASE WHEN TG_OP='DELETE' THEN to_jsonb(OLD)->>'id' ELSE to_jsonb(NEW)->>'id' END)::uuid,
    TG_OP, CASE WHEN TG_OP='INSERT' THEN NULL ELSE to_jsonb(OLD) END,
    CASE WHEN TG_OP='DELETE' THEN NULL ELSE to_jsonb(NEW) END);
  RETURN CASE WHEN TG_OP='DELETE' THEN OLD ELSE NEW END;
END $audit$;
CREATE TABLE public.visits(id uuid PRIMARY KEY, status text NOT NULL);
CREATE TABLE public.lab_orders(id uuid PRIMARY KEY, patient_id uuid, visit_id uuid REFERENCES public.visits(id), branch_id uuid, status text, value text);
CREATE TABLE public.lab_order_items(id uuid PRIMARY KEY, patient_id uuid, visit_id uuid REFERENCES public.visits(id), order_id uuid REFERENCES public.lab_orders(id), value text);
CREATE TABLE public.prescriptions(id uuid PRIMARY KEY, patient_id uuid, visit_id uuid REFERENCES public.visits(id), branch_id uuid, value text);
CREATE TABLE public.prescription_items(id uuid PRIMARY KEY, patient_id uuid, visit_id uuid REFERENCES public.visits(id), prescription_id uuid REFERENCES public.prescriptions(id), value text);
CREATE TABLE public.medical_certificates(id uuid PRIMARY KEY, patient_id uuid, visit_id uuid REFERENCES public.visits(id), branch_id uuid, diagnosis text, value text);
CREATE TABLE public.insurance_prior_authorizations(id uuid PRIMARY KEY, value text);
CREATE TABLE public.patient_discounts(id uuid PRIMARY KEY, value text);

-- Seed active and cancelled parents before applying the Phase 36 triggers.
INSERT INTO public.visits(id,status) VALUES
 ('00000000-0000-0000-0000-000000009001','active'),
 ('00000000-0000-0000-0000-000000009002','cancelled');
INSERT INTO public.lab_orders(id,patient_id,visit_id,branch_id,status,value) VALUES
 ('00000000-0000-0000-0000-000000009101','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009001','00000000-0000-0000-0000-000000009301','ordered','active'),
 ('00000000-0000-0000-0000-000000009102','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009301','ordered','cancelled');
INSERT INTO public.lab_order_items(id,patient_id,visit_id,order_id,value) VALUES
 ('00000000-0000-0000-0000-000000009111','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009001','00000000-0000-0000-0000-000000009101','active'),
 ('00000000-0000-0000-0000-000000009112','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009102','cancelled');
INSERT INTO public.prescriptions(id,patient_id,visit_id,branch_id,value) VALUES
 ('00000000-0000-0000-0000-000000009121','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009001','00000000-0000-0000-0000-000000009301','active'),
 ('00000000-0000-0000-0000-000000009122','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009301','cancelled');
INSERT INTO public.prescription_items(id,patient_id,visit_id,prescription_id,value) VALUES
 ('00000000-0000-0000-0000-000000009131','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009001','00000000-0000-0000-0000-000000009121','active'),
 ('00000000-0000-0000-0000-000000009132','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009122','cancelled');
INSERT INTO public.medical_certificates(id,patient_id,visit_id,branch_id,diagnosis,value) VALUES
 ('00000000-0000-0000-0000-000000009141','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009001','00000000-0000-0000-0000-000000009301','active','active'),
 ('00000000-0000-0000-0000-000000009142','00000000-0000-0000-0000-000000009201','00000000-0000-0000-0000-000000009002','00000000-0000-0000-0000-000000009301','cancelled','cancelled');
