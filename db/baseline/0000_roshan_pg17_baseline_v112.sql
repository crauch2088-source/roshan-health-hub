-- Canonical application-schema baseline extracted read-only from Supabase PostgreSQL 17.6.
-- Snapshot target: schema state after migration 112 (20261019061315_roshan_phase32_medical_certificate_visit_index).
-- Disposable CI baseline only. Do NOT apply to production: this is a schema snapshot, not a production migration.
-- Includes the 56 public tables, 213 table constraints, 163 non-constraint indexes, 126 public/private functions,
-- 47 public triggers, 203 public RLS policies, table grants, and RLS activation.
-- Platform compatibility shims below are intentionally minimal; Supabase platform schemas/services are not exported.
BEGIN;
SET LOCAL check_function_bodies = off;
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE SCHEMA IF NOT EXISTS auth;
CREATE SCHEMA IF NOT EXISTS private;
DO $roles$ BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role NOLOGIN BYPASSRLS; END IF;
END $roles$;
CREATE TABLE IF NOT EXISTS auth.users (id uuid PRIMARY KEY);
CREATE OR REPLACE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $auth_uid$
 SELECT COALESCE(NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid,
   (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid)
$auth_uid$;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- Sequences
CREATE SEQUENCE public.insurance_claim_number_seq AS bigint INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1 NO CYCLE;
CREATE SEQUENCE public.medical_certificate_number_seq AS bigint INCREMENT BY 1 MINVALUE 1 MAXVALUE 9223372036854775807 START WITH 1 CACHE 1 NO CYCLE;
CREATE SEQUENCE public.medical_certificates_id_seq AS integer INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START WITH 1 CACHE 1 NO CYCLE;
CREATE SEQUENCE public.medicines_2_id_seq AS integer INCREMENT BY 1 MINVALUE 1 MAXVALUE 2147483647 START WITH 1 CACHE 1 NO CYCLE;

-- Tables
CREATE TABLE public.appointments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid,
  doctor_id uuid,
  appointment_date timestamp with time zone NOT NULL,
  status character varying(30) DEFAULT 'scheduled'::character varying,
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid DEFAULT current_app_user_id(),
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  appointment_time time without time zone,
  department_id uuid,
  branch_id uuid,
  visit_id uuid,
  reason text
);
CREATE TABLE public.attachments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid,
  visit_id uuid,
  file_name text,
  file_url text,
  uploaded_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  file_type text,
  file_size bigint,
  description text,
  storage_path text,
  uploaded_by uuid,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.audit_logs (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  table_name character varying(100) NOT NULL,
  record_id uuid,
  action character varying(20) NOT NULL,
  user_id uuid,
  old_data jsonb,
  new_data jsonb,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.branches (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  branch_code character varying(50),
  branch_name character varying(255),
  address text,
  phone character varying(50),
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  name text,
  code text,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  is_active boolean DEFAULT true
);
CREATE TABLE public.cashbox_transactions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  branch_id uuid,
  transaction_type text NOT NULL,
  amount numeric NOT NULL,
  payment_method text,
  category text,
  description text,
  source_type text,
  source_id uuid,
  transaction_date timestamp with time zone DEFAULT now() NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  is_reversed boolean DEFAULT false NOT NULL,
  reversal_of uuid,
  reversal_reason text
);
CREATE TABLE public.certificates (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid,
  visit_id uuid,
  certificate_type character varying(100),
  content text,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  certificate_number text,
  issued_by uuid,
  issue_date date DEFAULT CURRENT_DATE,
  valid_from date,
  valid_to date,
  notes text
);
CREATE TABLE public.clinical_notes (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  visit_id uuid NOT NULL,
  chief_complaint text,
  history_present_illness text,
  past_medical_history text,
  past_surgical_history text,
  drug_history text,
  allergy_history text,
  family_history text,
  social_history text,
  examination text,
  assessment text,
  plan text,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  hpi text,
  doctor_id uuid,
  lmp date,
  edd date,
  gestational_age_days integer
);
CREATE TABLE public.corporate_accounts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name character varying(255) NOT NULL,
  contact_person character varying(255),
  phone character varying(50),
  discount_percent numeric(5,2),
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  type text,
  agreement_notes text,
  email text,
  address text,
  is_active boolean DEFAULT true
);
CREATE TABLE public.departments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name character varying(255) NOT NULL,
  active boolean DEFAULT true,
  name_ar text,
  name_en text,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  code text,
  is_active boolean DEFAULT true
);
CREATE TABLE public.diagnoses (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  visit_id uuid NOT NULL,
  diagnosis_name character varying(255) NOT NULL,
  icd10_code character varying(20),
  diagnosis_type character varying(30),
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  is_primary boolean DEFAULT false,
  doctor_id uuid,
  notes text
);
CREATE TABLE public.employees (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  full_name character varying(255) NOT NULL,
  "position" character varying(100),
  salary numeric(14,2),
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.expenses (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  category character varying(100),
  description text,
  amount numeric(14,2) NOT NULL,
  expense_date date NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  notes text,
  payment_method text DEFAULT 'cash'::text,
  paid_to text,
  branch_id uuid
);
CREATE TABLE public.followups (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid,
  visit_id uuid,
  followup_date date,
  notes text,
  status character varying(30) DEFAULT 'pending'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  reason text,
  completed_at timestamp with time zone
);
CREATE TABLE public.insurance_claim_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  claim_id uuid NOT NULL,
  service_type text NOT NULL,
  reference_id uuid,
  description text NOT NULL,
  gross_amount numeric(14,2) DEFAULT 0 NOT NULL,
  covered_amount numeric(14,2) DEFAULT 0 NOT NULL,
  patient_amount numeric(14,2) DEFAULT 0 NOT NULL,
  coverage_rule_id uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.insurance_claim_payments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  claim_id uuid NOT NULL,
  amount numeric(14,2) NOT NULL,
  payment_method text DEFAULT 'bank'::text NOT NULL,
  reference text,
  received_at timestamp with time zone DEFAULT now() NOT NULL,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone
);
CREATE TABLE public.insurance_claims (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  claim_number text DEFAULT ((('CLM-'::text || to_char(now(), 'YYYY'::text)) || '-'::text) || lpad((nextval('insurance_claim_number_seq'::regclass))::text, 6, '0'::text)) NOT NULL,
  patient_insurance_id uuid NOT NULL,
  invoice_id uuid,
  status text DEFAULT 'draft'::text NOT NULL,
  submitted_amount numeric(14,2) DEFAULT 0 NOT NULL,
  approved_amount numeric(14,2),
  paid_amount numeric(14,2) DEFAULT 0 NOT NULL,
  submitted_at timestamp with time zone,
  decided_at timestamp with time zone,
  paid_at timestamp with time zone,
  notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone
);
CREATE TABLE public.insurance_companies (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name text NOT NULL,
  contact_person text,
  phone text,
  email text,
  address text,
  notes text,
  active boolean DEFAULT true NOT NULL,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone,
  deleted_by uuid
);
CREATE TABLE public.insurance_coverage_rules (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  plan_id uuid NOT NULL,
  service_type text NOT NULL,
  reference_id uuid,
  generic_name text,
  coverage_percent numeric(5,2),
  fixed_amount numeric(14,2),
  requires_prior_auth boolean DEFAULT false NOT NULL,
  excluded boolean DEFAULT false NOT NULL,
  notes text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone
);
CREATE TABLE public.insurance_plans (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  company_id uuid NOT NULL,
  name text NOT NULL,
  default_coverage_percent numeric(5,2) DEFAULT 0 NOT NULL,
  requires_prior_auth boolean DEFAULT false NOT NULL,
  notes text,
  active boolean DEFAULT true NOT NULL,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone,
  deleted_by uuid
);
CREATE TABLE public.insurance_prior_authorizations (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_insurance_id uuid NOT NULL,
  service_type text NOT NULL,
  reference_id uuid,
  description text,
  status text DEFAULT 'pending'::text NOT NULL,
  reference_number text,
  requested_at timestamp with time zone DEFAULT now() NOT NULL,
  decided_at timestamp with time zone,
  notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone
);
CREATE TABLE public.invoice_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  invoice_id uuid NOT NULL,
  item_type character varying(50),
  item_name character varying(255),
  quantity numeric(14,2),
  unit_price numeric(14,2),
  total_price numeric(14,2),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  item_id uuid,
  discount numeric DEFAULT 0,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.invoices (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  invoice_number character varying(50),
  patient_id uuid,
  visit_id uuid,
  total_amount numeric(14,2) DEFAULT 0,
  discount_amount numeric(14,2) DEFAULT 0,
  paid_amount numeric(14,2) DEFAULT 0,
  payment_status character varying(30) DEFAULT 'unpaid'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  status text DEFAULT 'open'::text,
  subtotal numeric DEFAULT 0,
  net_amount numeric DEFAULT 0,
  discount_type text,
  corporate_account_id uuid,
  branch_id uuid,
  updated_at timestamp with time zone DEFAULT now(),
  invoice_date date DEFAULT CURRENT_DATE,
  partner_id uuid,
  is_primary boolean DEFAULT true NOT NULL
);
CREATE TABLE public.lab_order_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_id uuid NOT NULL,
  test_id uuid NOT NULL,
  status character varying(30) DEFAULT 'pending'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  price numeric DEFAULT 0,
  completed_at timestamp with time zone
);
CREATE TABLE public.lab_orders (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid NOT NULL,
  visit_id uuid,
  ordered_by uuid,
  status character varying(30) DEFAULT 'ordered'::character varying,
  priority character varying(20) DEFAULT 'normal'::character varying,
  ordered_at timestamp with time zone DEFAULT now(),
  completed_at timestamp with time zone,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  notes text,
  branch_id uuid,
  sample_collected_at timestamp with time zone,
  collected_by uuid
);
CREATE TABLE public.lab_parameters (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  test_id uuid NOT NULL,
  name character varying(255) NOT NULL,
  code character varying(50),
  unit character varying(50),
  data_type character varying(30) DEFAULT 'numeric'::character varying,
  display_order integer DEFAULT 0,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  is_active boolean DEFAULT true,
  reference_text text
);
CREATE TABLE public.lab_reference_ranges (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  parameter_id uuid NOT NULL,
  gender character varying(20),
  min_age numeric,
  max_age numeric,
  lower_limit numeric,
  upper_limit numeric,
  text_reference text,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  min_value numeric,
  max_value numeric,
  age_min integer,
  age_max integer,
  text_value text,
  unit text
);
CREATE TABLE public.lab_results (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  order_item_id uuid NOT NULL,
  parameter_id uuid NOT NULL,
  result_value text,
  numeric_value numeric,
  flag character varying(20),
  comment text,
  entered_by uuid,
  verified_by uuid,
  entered_at timestamp with time zone DEFAULT now(),
  verified_at timestamp with time zone,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  is_abnormal boolean
);
CREATE TABLE public.lab_tests (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name character varying(255) NOT NULL,
  code character varying(50),
  category character varying(100),
  sample_type character varying(100),
  price numeric(14,2),
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  name_ar text,
  description text,
  is_active boolean DEFAULT true
);
CREATE TABLE public.medical_certificates (
  id integer DEFAULT nextval('medical_certificates_id_seq'::regclass) NOT NULL,
  patient_id uuid,
  doctor_id uuid,
  diagnosis text,
  start_date date,
  end_date date,
  created_at timestamp with time zone DEFAULT now(),
  deleted_at timestamp with time zone,
  deleted_by uuid,
  visit_id uuid NOT NULL,
  certificate_number bigint DEFAULT nextval('medical_certificate_number_seq'::regclass) NOT NULL
);
CREATE TABLE public.medicines (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  generic_name character varying(255) NOT NULL,
  brand_name character varying(255),
  strength character varying(100),
  dosage_form character varying(100),
  barcode character varying(100),
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  unit text,
  is_active boolean DEFAULT true,
  name text,
  selling_price numeric DEFAULT 0,
  cost_price numeric DEFAULT 0,
  stock_quantity integer DEFAULT 0 NOT NULL,
  reorder_level integer DEFAULT 0 NOT NULL,
  expiry_date date,
  batch_number text,
  updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.medicines_2 (
  id integer DEFAULT nextval('medicines_2_id_seq'::regclass) NOT NULL,
  name text NOT NULL,
  selling_price numeric(10,2) DEFAULT 0.00,
  cost_price numeric(10,2) DEFAULT 0.00,
  stock integer DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  stock_quantity integer DEFAULT 0 NOT NULL
);
CREATE TABLE public.partners (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name character varying(255) NOT NULL,
  discount_percent numeric(5,2),
  active boolean DEFAULT true,
  deleted_at timestamp with time zone
);
CREATE TABLE public.patient_discounts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid,
  partner_id uuid,
  discount_percent numeric(5,2)
);
CREATE TABLE public.patient_insurance (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid NOT NULL,
  company_id uuid NOT NULL,
  plan_id uuid NOT NULL,
  policy_number text,
  member_number text,
  is_primary boolean DEFAULT true NOT NULL,
  start_date date DEFAULT CURRENT_DATE NOT NULL,
  expiry_date date,
  status text DEFAULT 'active'::text NOT NULL,
  notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone,
  deleted_by uuid
);
CREATE TABLE public.patients (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  branch_id uuid,
  mrn character varying(30),
  full_name character varying(255) NOT NULL,
  gender character varying(20) NOT NULL,
  date_of_birth date,
  phone character varying(50),
  address text,
  occupation character varying(150),
  marital_status character varying(50),
  blood_group character varying(10),
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  email text,
  national_id text,
  emergency_contact text,
  notes text,
  registered_by uuid,
  age integer,
  dob date,
  patient_number character varying GENERATED ALWAYS AS (mrn) STORED
);
CREATE TABLE public.payments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  invoice_id uuid,
  payment_method character varying(30),
  amount numeric(14,2),
  reference_no character varying(100),
  received_at timestamp with time zone DEFAULT now(),
  payment_date timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  created_at timestamp with time zone DEFAULT now(),
  reference text,
  received_by uuid,
  branch_id uuid,
  notes text,
  idempotency_key text,
  method text DEFAULT 'cash'::text
);
CREATE TABLE public.permissions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  code character varying(100) NOT NULL,
  name character varying(255) NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  module text,
  action text
);
CREATE TABLE public.pharmacy_inventory (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  medicine_id uuid NOT NULL,
  batch_no character varying(100),
  expiry_date date,
  quantity numeric(14,2) DEFAULT 0,
  purchase_price numeric(14,2),
  selling_price numeric(14,2),
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  batch_number text,
  reorder_level integer DEFAULT 10,
  supplier_id uuid,
  branch_id uuid,
  updated_at timestamp with time zone DEFAULT now(),
  quantity_received numeric DEFAULT 0 NOT NULL,
  quantity_remaining numeric DEFAULT 0 NOT NULL,
  manufacture_date date,
  invoice_reference text,
  idempotency_key text
);
CREATE TABLE public.prescription_items (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  prescription_id uuid NOT NULL,
  medicine_id uuid,
  medication_name character varying(255),
  dose character varying(100),
  frequency character varying(100),
  duration character varying(100),
  quantity numeric(14,2),
  instructions text,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  dosage text,
  is_dispensed boolean DEFAULT false,
  dispensed_quantity integer DEFAULT 0,
  unit_price numeric DEFAULT 0,
  created_at timestamp with time zone DEFAULT now(),
  dosage_form text,
  route text,
  updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.prescriptions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid NOT NULL,
  visit_id uuid,
  prescribed_by uuid,
  prescription_type character varying(20) DEFAULT 'internal'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  doctor_id uuid,
  status text DEFAULT 'pending'::text,
  is_external boolean DEFAULT false,
  notes text,
  dispensed_at timestamp with time zone,
  dispensed_by uuid,
  updated_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.procedure_orders (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  patient_id uuid,
  visit_id uuid,
  procedure_id uuid,
  ordered_by uuid,
  status character varying(30) DEFAULT 'ordered'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  price numeric DEFAULT 0,
  performed_by uuid,
  performed_at timestamp with time zone,
  notes text
);
CREATE TABLE public.procedure_results (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  procedure_order_id uuid,
  findings text,
  impression text,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  verified_by uuid
);
CREATE TABLE public.procedures_catalog (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name character varying(255) NOT NULL,
  category character varying(100),
  price numeric(14,2),
  active boolean DEFAULT true,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  name_ar text,
  department_id uuid,
  is_active boolean DEFAULT true
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text,
  role text DEFAULT 'reception'::text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);
CREATE TABLE public.queue_tickets (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  visit_id uuid,
  queue_number text,
  status character varying(30) DEFAULT 'waiting'::character varying,
  created_at timestamp with time zone DEFAULT now(),
  visit_date date DEFAULT CURRENT_DATE,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  patient_id uuid,
  department_id uuid,
  called_at timestamp with time zone,
  completed_at timestamp with time zone
);
CREATE TABLE public.role_permissions (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  role_id uuid NOT NULL,
  permission_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE public.roles (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name character varying(100) NOT NULL,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  code text,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  name_ar text
);
CREATE TABLE public.services (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  service_name character varying(255) NOT NULL,
  service_type character varying(50),
  price numeric(14,2),
  active boolean DEFAULT true
);
CREATE TABLE public.stock_movements (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  medicine_id uuid NOT NULL,
  batch_id uuid,
  movement_type text NOT NULL,
  quantity numeric NOT NULL,
  reference_id uuid,
  reference_table text,
  notes text,
  branch_id uuid,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public.supplier_bills (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  supplier_id uuid NOT NULL,
  branch_id uuid,
  invoice_number text,
  bill_date date DEFAULT CURRENT_DATE NOT NULL,
  due_date date,
  subtotal numeric DEFAULT 0 NOT NULL,
  discount_amount numeric DEFAULT 0 NOT NULL,
  total_amount numeric DEFAULT 0 NOT NULL,
  paid_amount numeric DEFAULT 0 NOT NULL,
  status text DEFAULT 'unpaid'::text NOT NULL,
  notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone,
  deleted_by uuid
);
CREATE TABLE public.supplier_payments (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  supplier_bill_id uuid NOT NULL,
  supplier_id uuid NOT NULL,
  branch_id uuid,
  amount numeric NOT NULL,
  payment_method text DEFAULT 'cash'::text NOT NULL,
  reference text,
  payment_date timestamp with time zone DEFAULT now() NOT NULL,
  notes text,
  created_by uuid,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  deleted_at timestamp with time zone,
  deleted_by uuid
);
CREATE TABLE public.suppliers (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  name character varying(255) NOT NULL,
  phone character varying(50),
  address text,
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid
);
CREATE TABLE public.system_settings (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  setting_key character varying(100) NOT NULL,
  setting_value text,
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  description text,
  created_at timestamp with time zone DEFAULT now(),
  is_public boolean DEFAULT false NOT NULL
);
CREATE TABLE public.users (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  branch_id uuid,
  role_id uuid,
  full_name character varying(255) NOT NULL,
  username character varying(100),
  phone character varying(50),
  email character varying(255),
  active boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now(),
  auth_user_id uuid,
  role text DEFAULT 'staff'::text,
  department_id uuid,
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid
);
CREATE TABLE public.visits (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  branch_id uuid,
  patient_id uuid NOT NULL,
  doctor_id uuid,
  appointment_id uuid,
  visit_type character varying(50),
  department character varying(100),
  status character varying(30) DEFAULT 'waiting'::character varying,
  visit_date timestamp with time zone DEFAULT now(),
  created_at timestamp with time zone DEFAULT now(),
  department_id uuid,
  consultation_fee numeric DEFAULT 0,
  deleted_at timestamp with time zone,
  created_by uuid,
  updated_by uuid,
  deleted_by uuid,
  visit_number text,
  notes text,
  completed_at timestamp with time zone,
  is_locked boolean DEFAULT false,
  updated_at timestamp with time zone DEFAULT now(),
  queue_number integer,
  queue_date date
);
CREATE TABLE public.vitals (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  visit_id uuid NOT NULL,
  systolic_bp integer,
  diastolic_bp integer,
  pulse integer,
  respiratory_rate integer,
  temperature numeric(4,1),
  spo2 integer,
  weight numeric(5,2),
  height numeric(5,2),
  bmi numeric(5,2),
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_by uuid,
  deleted_at timestamp with time zone,
  deleted_by uuid,
  patient_id uuid,
  bp_systolic integer,
  bp_diastolic integer,
  lmp date,
  edd date,
  gestational_age_days integer,
  recorded_by uuid
);

-- Constraints
ALTER TABLE public.appointments ADD CONSTRAINT appointments_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES users(id);
ALTER TABLE public.appointments ADD CONSTRAINT appointments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE;
ALTER TABLE public.appointments ADD CONSTRAINT appointments_pkey PRIMARY KEY (id);
ALTER TABLE public.appointments ADD CONSTRAINT fk_appointments_department FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;
ALTER TABLE public.attachments ADD CONSTRAINT attachments_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.attachments ADD CONSTRAINT attachments_pkey PRIMARY KEY (id);
ALTER TABLE public.attachments ADD CONSTRAINT attachments_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_pkey PRIMARY KEY (id);
ALTER TABLE public.audit_logs ADD CONSTRAINT audit_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES users(id);
ALTER TABLE public.branches ADD CONSTRAINT branches_branch_code_key UNIQUE (branch_code);
ALTER TABLE public.branches ADD CONSTRAINT branches_pkey PRIMARY KEY (id);
ALTER TABLE public.cashbox_transactions ADD CONSTRAINT cashbox_transactions_amount_check CHECK ((amount <> (0)::numeric));
ALTER TABLE public.cashbox_transactions ADD CONSTRAINT cashbox_transactions_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL;
ALTER TABLE public.cashbox_transactions ADD CONSTRAINT cashbox_transactions_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE public.cashbox_transactions ADD CONSTRAINT cashbox_transactions_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE public.cashbox_transactions ADD CONSTRAINT cashbox_transactions_pkey PRIMARY KEY (id);
ALTER TABLE public.cashbox_transactions ADD CONSTRAINT cashbox_transactions_transaction_type_check CHECK ((transaction_type = ANY (ARRAY['customer_payment'::text, 'expense'::text, 'supplier_payment'::text, 'deposit'::text, 'withdrawal'::text, 'adjustment'::text, 'reversal'::text])));
ALTER TABLE public.certificates ADD CONSTRAINT certificates_issued_by_fkey FOREIGN KEY (issued_by) REFERENCES users(id);
ALTER TABLE public.certificates ADD CONSTRAINT certificates_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.certificates ADD CONSTRAINT certificates_pkey PRIMARY KEY (id);
ALTER TABLE public.certificates ADD CONSTRAINT certificates_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.clinical_notes ADD CONSTRAINT clinical_notes_pkey PRIMARY KEY (id);
ALTER TABLE public.clinical_notes ADD CONSTRAINT clinical_notes_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.clinical_notes ADD CONSTRAINT clinical_notes_visit_id_key UNIQUE (visit_id);
ALTER TABLE public.corporate_accounts ADD CONSTRAINT corporate_accounts_pkey PRIMARY KEY (id);
ALTER TABLE public.departments ADD CONSTRAINT departments_name_key UNIQUE (name);
ALTER TABLE public.departments ADD CONSTRAINT departments_pkey PRIMARY KEY (id);
ALTER TABLE public.diagnoses ADD CONSTRAINT diagnoses_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES users(id);
ALTER TABLE public.diagnoses ADD CONSTRAINT diagnoses_pkey PRIMARY KEY (id);
ALTER TABLE public.diagnoses ADD CONSTRAINT diagnoses_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.employees ADD CONSTRAINT employees_pkey PRIMARY KEY (id);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_amount_nonnegative CHECK (((amount IS NULL) OR (amount >= (0)::numeric)));
ALTER TABLE public.expenses ADD CONSTRAINT expenses_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id);
ALTER TABLE public.expenses ADD CONSTRAINT expenses_pkey PRIMARY KEY (id);
ALTER TABLE public.followups ADD CONSTRAINT followups_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id);
ALTER TABLE public.followups ADD CONSTRAINT followups_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.followups ADD CONSTRAINT followups_pkey PRIMARY KEY (id);
ALTER TABLE public.followups ADD CONSTRAINT followups_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id);
ALTER TABLE public.followups ADD CONSTRAINT followups_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.insurance_claim_items ADD CONSTRAINT insurance_claim_items_claim_id_fkey FOREIGN KEY (claim_id) REFERENCES insurance_claims(id);
ALTER TABLE public.insurance_claim_items ADD CONSTRAINT insurance_claim_items_coverage_rule_id_fkey FOREIGN KEY (coverage_rule_id) REFERENCES insurance_coverage_rules(id);
ALTER TABLE public.insurance_claim_items ADD CONSTRAINT insurance_claim_items_pkey PRIMARY KEY (id);
ALTER TABLE public.insurance_claim_items ADD CONSTRAINT insurance_claim_items_service_type_check CHECK ((service_type = ANY (ARRAY['consultation'::text, 'lab'::text, 'medicine'::text])));
ALTER TABLE public.insurance_claim_payments ADD CONSTRAINT insurance_claim_payments_claim_id_fkey FOREIGN KEY (claim_id) REFERENCES insurance_claims(id);
ALTER TABLE public.insurance_claim_payments ADD CONSTRAINT insurance_claim_payments_pkey PRIMARY KEY (id);
ALTER TABLE public.insurance_claims ADD CONSTRAINT insurance_claims_claim_number_key UNIQUE (claim_number);
ALTER TABLE public.insurance_claims ADD CONSTRAINT insurance_claims_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id);
ALTER TABLE public.insurance_claims ADD CONSTRAINT insurance_claims_patient_insurance_id_fkey FOREIGN KEY (patient_insurance_id) REFERENCES patient_insurance(id);
ALTER TABLE public.insurance_claims ADD CONSTRAINT insurance_claims_pkey PRIMARY KEY (id);
ALTER TABLE public.insurance_claims ADD CONSTRAINT insurance_claims_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'submitted'::text, 'under_review'::text, 'approved'::text, 'partially_approved'::text, 'rejected'::text, 'paid'::text])));
ALTER TABLE public.insurance_companies ADD CONSTRAINT insurance_companies_pkey PRIMARY KEY (id);
ALTER TABLE public.insurance_coverage_rules ADD CONSTRAINT insurance_coverage_rules_amount_ck CHECK (((excluded = true) OR (coverage_percent IS NOT NULL) OR (fixed_amount IS NOT NULL)));
ALTER TABLE public.insurance_coverage_rules ADD CONSTRAINT insurance_coverage_rules_coverage_percent_check CHECK (((coverage_percent >= (0)::numeric) AND (coverage_percent <= (100)::numeric)));
ALTER TABLE public.insurance_coverage_rules ADD CONSTRAINT insurance_coverage_rules_pkey PRIMARY KEY (id);
ALTER TABLE public.insurance_coverage_rules ADD CONSTRAINT insurance_coverage_rules_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES insurance_plans(id);
ALTER TABLE public.insurance_coverage_rules ADD CONSTRAINT insurance_coverage_rules_service_type_check CHECK ((service_type = ANY (ARRAY['consultation'::text, 'lab'::text, 'medicine'::text])));
ALTER TABLE public.insurance_plans ADD CONSTRAINT insurance_plans_company_id_fkey FOREIGN KEY (company_id) REFERENCES insurance_companies(id);
ALTER TABLE public.insurance_plans ADD CONSTRAINT insurance_plans_default_coverage_percent_check CHECK (((default_coverage_percent >= (0)::numeric) AND (default_coverage_percent <= (100)::numeric)));
ALTER TABLE public.insurance_plans ADD CONSTRAINT insurance_plans_pkey PRIMARY KEY (id);
ALTER TABLE public.insurance_prior_authorizations ADD CONSTRAINT insurance_prior_authorizations_patient_insurance_id_fkey FOREIGN KEY (patient_insurance_id) REFERENCES patient_insurance(id);
ALTER TABLE public.insurance_prior_authorizations ADD CONSTRAINT insurance_prior_authorizations_pkey PRIMARY KEY (id);
ALTER TABLE public.insurance_prior_authorizations ADD CONSTRAINT insurance_prior_authorizations_service_type_check CHECK ((service_type = ANY (ARRAY['consultation'::text, 'lab'::text, 'medicine'::text])));
ALTER TABLE public.insurance_prior_authorizations ADD CONSTRAINT insurance_prior_authorizations_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'expired'::text])));
ALTER TABLE public.invoice_items ADD CONSTRAINT invoice_items_discount_nonnegative CHECK ((COALESCE(discount, (0)::numeric) >= (0)::numeric));
ALTER TABLE public.invoice_items ADD CONSTRAINT invoice_items_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE;
ALTER TABLE public.invoice_items ADD CONSTRAINT invoice_items_pkey PRIMARY KEY (id);
ALTER TABLE public.invoice_items ADD CONSTRAINT invoice_items_quantity_nonnegative CHECK ((COALESCE(quantity, (0)::numeric) >= (0)::numeric));
ALTER TABLE public.invoices ADD CONSTRAINT invoices_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_corporate_account_id_fkey FOREIGN KEY (corporate_account_id) REFERENCES corporate_accounts(id);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_discount_amount_nonnegative CHECK (((discount_amount IS NULL) OR (discount_amount >= (0)::numeric)));
ALTER TABLE public.invoices ADD CONSTRAINT invoices_invoice_number_key UNIQUE (invoice_number);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_paid_amount_nonnegative CHECK (((paid_amount IS NULL) OR (paid_amount >= (0)::numeric)));
ALTER TABLE public.invoices ADD CONSTRAINT invoices_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES partners(id);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_pkey PRIMARY KEY (id);
ALTER TABLE public.invoices ADD CONSTRAINT invoices_total_amount_nonnegative CHECK (((total_amount IS NULL) OR (total_amount >= (0)::numeric)));
ALTER TABLE public.invoices ADD CONSTRAINT invoices_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.lab_order_items ADD CONSTRAINT lab_order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES lab_orders(id) ON DELETE CASCADE;
ALTER TABLE public.lab_order_items ADD CONSTRAINT lab_order_items_pkey PRIMARY KEY (id);
ALTER TABLE public.lab_order_items ADD CONSTRAINT lab_order_items_test_id_fkey FOREIGN KEY (test_id) REFERENCES lab_tests(id);
ALTER TABLE public.lab_orders ADD CONSTRAINT lab_orders_ordered_by_fkey FOREIGN KEY (ordered_by) REFERENCES users(id);
ALTER TABLE public.lab_orders ADD CONSTRAINT lab_orders_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.lab_orders ADD CONSTRAINT lab_orders_pkey PRIMARY KEY (id);
ALTER TABLE public.lab_orders ADD CONSTRAINT lab_orders_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.lab_parameters ADD CONSTRAINT lab_parameters_pkey PRIMARY KEY (id);
ALTER TABLE public.lab_parameters ADD CONSTRAINT lab_parameters_test_id_fkey FOREIGN KEY (test_id) REFERENCES lab_tests(id) ON DELETE CASCADE;
ALTER TABLE public.lab_reference_ranges ADD CONSTRAINT lab_reference_ranges_parameter_id_fkey FOREIGN KEY (parameter_id) REFERENCES lab_parameters(id) ON DELETE CASCADE;
ALTER TABLE public.lab_reference_ranges ADD CONSTRAINT lab_reference_ranges_pkey PRIMARY KEY (id);
ALTER TABLE public.lab_results ADD CONSTRAINT lab_results_entered_by_fkey FOREIGN KEY (entered_by) REFERENCES users(id);
ALTER TABLE public.lab_results ADD CONSTRAINT lab_results_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES lab_order_items(id) ON DELETE CASCADE;
ALTER TABLE public.lab_results ADD CONSTRAINT lab_results_parameter_id_fkey FOREIGN KEY (parameter_id) REFERENCES lab_parameters(id);
ALTER TABLE public.lab_results ADD CONSTRAINT lab_results_pkey PRIMARY KEY (id);
ALTER TABLE public.lab_results ADD CONSTRAINT lab_results_verified_by_fkey FOREIGN KEY (verified_by) REFERENCES users(id);
ALTER TABLE public.lab_tests ADD CONSTRAINT lab_tests_code_key UNIQUE (code);
ALTER TABLE public.lab_tests ADD CONSTRAINT lab_tests_pkey PRIMARY KEY (id);
ALTER TABLE public.lab_tests ADD CONSTRAINT lab_tests_price_nonnegative CHECK (((price IS NULL) OR (price >= (0)::numeric)));
ALTER TABLE public.medical_certificates ADD CONSTRAINT medical_certificates_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES users(id);
ALTER TABLE public.medical_certificates ADD CONSTRAINT medical_certificates_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.medical_certificates ADD CONSTRAINT medical_certificates_pkey PRIMARY KEY (id);
ALTER TABLE public.medical_certificates ADD CONSTRAINT medical_certificates_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id) ON DELETE RESTRICT;
ALTER TABLE public.medicines_2 ADD CONSTRAINT medicines_2_pkey PRIMARY KEY (id);
ALTER TABLE public.medicines ADD CONSTRAINT medicines_cost_price_nonnegative CHECK (((cost_price IS NULL) OR (cost_price >= (0)::numeric)));
ALTER TABLE public.medicines ADD CONSTRAINT medicines_pkey PRIMARY KEY (id);
ALTER TABLE public.medicines ADD CONSTRAINT medicines_selling_price_nonnegative CHECK (((selling_price IS NULL) OR (selling_price >= (0)::numeric)));
ALTER TABLE public.partners ADD CONSTRAINT partners_pkey PRIMARY KEY (id);
ALTER TABLE public.patient_discounts ADD CONSTRAINT patient_discounts_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES partners(id);
ALTER TABLE public.patient_discounts ADD CONSTRAINT patient_discounts_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.patient_discounts ADD CONSTRAINT patient_discounts_pkey PRIMARY KEY (id);
ALTER TABLE public.patient_insurance ADD CONSTRAINT patient_insurance_company_id_fkey FOREIGN KEY (company_id) REFERENCES insurance_companies(id);
ALTER TABLE public.patient_insurance ADD CONSTRAINT patient_insurance_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.patient_insurance ADD CONSTRAINT patient_insurance_pkey PRIMARY KEY (id);
ALTER TABLE public.patient_insurance ADD CONSTRAINT patient_insurance_plan_id_fkey FOREIGN KEY (plan_id) REFERENCES insurance_plans(id);
ALTER TABLE public.patient_insurance ADD CONSTRAINT patient_insurance_status_check CHECK ((status = ANY (ARRAY['active'::text, 'expired'::text, 'suspended'::text])));
ALTER TABLE public.patients ADD CONSTRAINT patients_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);
ALTER TABLE public.patients ADD CONSTRAINT patients_mrn_key UNIQUE (mrn);
ALTER TABLE public.patients ADD CONSTRAINT patients_pkey PRIMARY KEY (id);
ALTER TABLE public.payments ADD CONSTRAINT payments_amount_nonnegative CHECK (((amount IS NULL) OR (amount >= (0)::numeric)));
ALTER TABLE public.payments ADD CONSTRAINT payments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);
ALTER TABLE public.payments ADD CONSTRAINT payments_idempotency_key_key UNIQUE (idempotency_key);
ALTER TABLE public.payments ADD CONSTRAINT payments_invoice_id_fkey FOREIGN KEY (invoice_id) REFERENCES invoices(id);
ALTER TABLE public.payments ADD CONSTRAINT payments_pkey PRIMARY KEY (id);
ALTER TABLE public.payments ADD CONSTRAINT payments_received_by_fkey FOREIGN KEY (received_by) REFERENCES users(id);
ALTER TABLE public.permissions ADD CONSTRAINT permissions_code_key UNIQUE (code);
ALTER TABLE public.permissions ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_dates_check CHECK (((manufacture_date IS NULL) OR (expiry_date IS NULL) OR (manufacture_date <= expiry_date)));
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_medicine_id_fkey FOREIGN KEY (medicine_id) REFERENCES medicines(id);
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_pkey PRIMARY KEY (id);
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_quantity_nonneg CHECK ((quantity >= (0)::numeric));
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_quantity_nonnegative CHECK ((quantity >= (0)::numeric));
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_quantity_received_check CHECK ((quantity_received >= (0)::numeric));
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_quantity_remaining_bound_check CHECK ((quantity_remaining <= quantity_received));
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_quantity_remaining_check CHECK ((quantity_remaining >= (0)::numeric));
ALTER TABLE public.pharmacy_inventory ADD CONSTRAINT pharmacy_inventory_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id);
ALTER TABLE public.prescription_items ADD CONSTRAINT prescription_items_dispensed_quantity_nonnegative CHECK ((COALESCE(dispensed_quantity, 0) >= 0));
ALTER TABLE public.prescription_items ADD CONSTRAINT prescription_items_medicine_id_fkey FOREIGN KEY (medicine_id) REFERENCES medicines(id);
ALTER TABLE public.prescription_items ADD CONSTRAINT prescription_items_pkey PRIMARY KEY (id);
ALTER TABLE public.prescription_items ADD CONSTRAINT prescription_items_prescription_id_fkey FOREIGN KEY (prescription_id) REFERENCES prescriptions(id) ON DELETE CASCADE;
ALTER TABLE public.prescriptions ADD CONSTRAINT prescriptions_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.prescriptions ADD CONSTRAINT prescriptions_pkey PRIMARY KEY (id);
ALTER TABLE public.prescriptions ADD CONSTRAINT prescriptions_prescribed_by_fkey FOREIGN KEY (prescribed_by) REFERENCES users(id);
ALTER TABLE public.prescriptions ADD CONSTRAINT prescriptions_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.procedure_orders ADD CONSTRAINT procedure_orders_ordered_by_fkey FOREIGN KEY (ordered_by) REFERENCES users(id);
ALTER TABLE public.procedure_orders ADD CONSTRAINT procedure_orders_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.procedure_orders ADD CONSTRAINT procedure_orders_pkey PRIMARY KEY (id);
ALTER TABLE public.procedure_orders ADD CONSTRAINT procedure_orders_procedure_id_fkey FOREIGN KEY (procedure_id) REFERENCES procedures_catalog(id);
ALTER TABLE public.procedure_orders ADD CONSTRAINT procedure_orders_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.procedure_results ADD CONSTRAINT procedure_results_pkey PRIMARY KEY (id);
ALTER TABLE public.procedure_results ADD CONSTRAINT procedure_results_procedure_order_id_fkey FOREIGN KEY (procedure_order_id) REFERENCES procedure_orders(id);
ALTER TABLE public.procedures_catalog ADD CONSTRAINT procedures_catalog_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(id);
ALTER TABLE public.procedures_catalog ADD CONSTRAINT procedures_catalog_pkey PRIMARY KEY (id);
ALTER TABLE public.procedures_catalog ADD CONSTRAINT procedures_catalog_price_nonnegative CHECK (((price IS NULL) OR (price >= (0)::numeric)));
ALTER TABLE public.profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
ALTER TABLE public.queue_tickets ADD CONSTRAINT fk_queue_tickets_department FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL;
ALTER TABLE public.queue_tickets ADD CONSTRAINT fk_queue_tickets_patient FOREIGN KEY (patient_id) REFERENCES patients(id) ON DELETE CASCADE;
ALTER TABLE public.queue_tickets ADD CONSTRAINT queue_tickets_number_day_key UNIQUE (visit_date, queue_number);
ALTER TABLE public.queue_tickets ADD CONSTRAINT queue_tickets_pkey PRIMARY KEY (id);
ALTER TABLE public.queue_tickets ADD CONSTRAINT queue_tickets_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.role_permissions ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE CASCADE;
ALTER TABLE public.role_permissions ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);
ALTER TABLE public.role_permissions ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE CASCADE;
ALTER TABLE public.role_permissions ADD CONSTRAINT role_permissions_role_id_permission_id_key UNIQUE (role_id, permission_id);
ALTER TABLE public.roles ADD CONSTRAINT roles_code_key UNIQUE (code);
ALTER TABLE public.roles ADD CONSTRAINT roles_name_key UNIQUE (name);
ALTER TABLE public.roles ADD CONSTRAINT roles_pkey PRIMARY KEY (id);
ALTER TABLE public.services ADD CONSTRAINT services_pkey PRIMARY KEY (id);
ALTER TABLE public.stock_movements ADD CONSTRAINT stock_movements_batch_id_fkey FOREIGN KEY (batch_id) REFERENCES pharmacy_inventory(id);
ALTER TABLE public.stock_movements ADD CONSTRAINT stock_movements_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);
ALTER TABLE public.stock_movements ADD CONSTRAINT stock_movements_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id);
ALTER TABLE public.stock_movements ADD CONSTRAINT stock_movements_medicine_id_fkey FOREIGN KEY (medicine_id) REFERENCES medicines(id);
ALTER TABLE public.stock_movements ADD CONSTRAINT stock_movements_movement_type_check CHECK ((movement_type = ANY (ARRAY['purchase'::text, 'dispense'::text, 'adjustment'::text, 'return'::text, 'writeoff'::text])));
ALTER TABLE public.stock_movements ADD CONSTRAINT stock_movements_pkey PRIMARY KEY (id);
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL;
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_check CHECK ((paid_amount <= total_amount));
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_discount_amount_check CHECK ((discount_amount >= (0)::numeric));
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_paid_amount_check CHECK ((paid_amount >= (0)::numeric));
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_pkey PRIMARY KEY (id);
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_status_check CHECK ((status = ANY (ARRAY['unpaid'::text, 'partial'::text, 'paid'::text, 'cancelled'::text])));
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_subtotal_check CHECK ((subtotal >= (0)::numeric));
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT;
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_total_amount_check CHECK ((total_amount >= (0)::numeric));
ALTER TABLE public.supplier_bills ADD CONSTRAINT supplier_bills_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE public.supplier_payments ADD CONSTRAINT supplier_payments_amount_check CHECK ((amount > (0)::numeric));
ALTER TABLE public.supplier_payments ADD CONSTRAINT supplier_payments_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id) ON DELETE SET NULL;
ALTER TABLE public.supplier_payments ADD CONSTRAINT supplier_payments_created_by_fkey FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE public.supplier_payments ADD CONSTRAINT supplier_payments_deleted_by_fkey FOREIGN KEY (deleted_by) REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE public.supplier_payments ADD CONSTRAINT supplier_payments_pkey PRIMARY KEY (id);
ALTER TABLE public.supplier_payments ADD CONSTRAINT supplier_payments_supplier_bill_id_fkey FOREIGN KEY (supplier_bill_id) REFERENCES supplier_bills(id) ON DELETE RESTRICT;
ALTER TABLE public.supplier_payments ADD CONSTRAINT supplier_payments_supplier_id_fkey FOREIGN KEY (supplier_id) REFERENCES suppliers(id) ON DELETE RESTRICT;
ALTER TABLE public.suppliers ADD CONSTRAINT suppliers_pkey PRIMARY KEY (id);
ALTER TABLE public.system_settings ADD CONSTRAINT system_settings_pkey PRIMARY KEY (id);
ALTER TABLE public.system_settings ADD CONSTRAINT system_settings_setting_key_key UNIQUE (setting_key);
ALTER TABLE public.users ADD CONSTRAINT users_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE public.users ADD CONSTRAINT users_auth_user_id_key UNIQUE (auth_user_id);
ALTER TABLE public.users ADD CONSTRAINT users_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);
ALTER TABLE public.users ADD CONSTRAINT users_email_key UNIQUE (email);
ALTER TABLE public.users ADD CONSTRAINT users_pkey PRIMARY KEY (id);
ALTER TABLE public.users ADD CONSTRAINT users_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id);
ALTER TABLE public.users ADD CONSTRAINT users_username_key UNIQUE (username);
ALTER TABLE public.visits ADD CONSTRAINT visits_appointment_id_fkey FOREIGN KEY (appointment_id) REFERENCES appointments(id);
ALTER TABLE public.visits ADD CONSTRAINT visits_branch_id_fkey FOREIGN KEY (branch_id) REFERENCES branches(id);
ALTER TABLE public.visits ADD CONSTRAINT visits_consultation_fee_nonnegative CHECK (((consultation_fee IS NULL) OR (consultation_fee >= (0)::numeric)));
ALTER TABLE public.visits ADD CONSTRAINT visits_department_id_fkey FOREIGN KEY (department_id) REFERENCES departments(id);
ALTER TABLE public.visits ADD CONSTRAINT visits_doctor_id_fkey FOREIGN KEY (doctor_id) REFERENCES users(id);
ALTER TABLE public.visits ADD CONSTRAINT visits_patient_id_fkey FOREIGN KEY (patient_id) REFERENCES patients(id);
ALTER TABLE public.visits ADD CONSTRAINT visits_pkey PRIMARY KEY (id);
ALTER TABLE public.visits ADD CONSTRAINT visits_visit_number_day_key UNIQUE (visit_date, visit_number);
ALTER TABLE public.vitals ADD CONSTRAINT vitals_pkey PRIMARY KEY (id);
ALTER TABLE public.vitals ADD CONSTRAINT vitals_visit_id_fkey FOREIGN KEY (visit_id) REFERENCES visits(id);
ALTER TABLE public.vitals ADD CONSTRAINT vitals_visit_id_key UNIQUE (visit_id);

-- Indexes
CREATE INDEX appointments_date_active_idx ON public.appointments USING btree (appointment_date) WHERE (deleted_at IS NULL);
CREATE INDEX audit_logs_created_at_idx ON public.audit_logs USING btree (created_at DESC);
CREATE INDEX clinical_notes_visit_created_idx ON public.clinical_notes USING btree (visit_id, created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX diagnoses_visit_created_idx ON public.diagnoses USING btree (visit_id, created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_appointments_branch_id ON public.appointments USING btree (branch_id);
CREATE INDEX idx_appointments_department_id ON public.appointments USING btree (department_id);
CREATE INDEX idx_appointments_doctor_id ON public.appointments USING btree (doctor_id);
CREATE INDEX idx_appointments_patient_id ON public.appointments USING btree (patient_id);
CREATE INDEX idx_appointments_visit_id ON public.appointments USING btree (visit_id);
CREATE INDEX idx_attachments_patient_id ON public.attachments USING btree (patient_id);
CREATE INDEX idx_attachments_visit_id ON public.attachments USING btree (visit_id);
CREATE INDEX idx_audit_logs_user_id ON public.audit_logs USING btree (user_id);
CREATE INDEX idx_cashbox_branch_date ON public.cashbox_transactions USING btree (branch_id, transaction_date DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_cashbox_date ON public.cashbox_transactions USING btree (transaction_date DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_cashbox_transactions_created_by ON public.cashbox_transactions USING btree (created_by);
CREATE INDEX idx_cashbox_transactions_deleted_by ON public.cashbox_transactions USING btree (deleted_by);
CREATE INDEX idx_cashbox_transactions_reversal_of ON public.cashbox_transactions USING btree (reversal_of) WHERE (reversal_of IS NOT NULL);
CREATE INDEX idx_certificates_issued_by ON public.certificates USING btree (issued_by);
CREATE INDEX idx_certificates_patient_id ON public.certificates USING btree (patient_id);
CREATE INDEX idx_certificates_visit_id ON public.certificates USING btree (visit_id);
CREATE INDEX idx_clinical_notes_visit_active ON public.clinical_notes USING btree (visit_id) WHERE (deleted_at IS NULL);
CREATE INDEX idx_clinical_notes_visit_id ON public.clinical_notes USING btree (visit_id);
CREATE INDEX idx_diagnoses_doctor_id ON public.diagnoses USING btree (doctor_id);
CREATE INDEX idx_diagnoses_visit_id ON public.diagnoses USING btree (visit_id);
CREATE INDEX idx_expenses_branch_id ON public.expenses USING btree (branch_id);
CREATE INDEX idx_expenses_created_by ON public.expenses USING btree (created_by);
CREATE INDEX idx_followups_created_by ON public.followups USING btree (created_by);
CREATE INDEX idx_followups_patient_id ON public.followups USING btree (patient_id);
CREATE INDEX idx_followups_updated_by ON public.followups USING btree (updated_by);
CREATE INDEX idx_followups_visit_id ON public.followups USING btree (visit_id);
CREATE INDEX idx_insurance_claim_items_coverage_rule_id ON public.insurance_claim_items USING btree (coverage_rule_id);
CREATE INDEX idx_insurance_claims_invoice_id ON public.insurance_claims USING btree (invoice_id);
CREATE INDEX idx_insurance_prior_authorizations_patient_insurance_id ON public.insurance_prior_authorizations USING btree (patient_insurance_id);
CREATE INDEX idx_invoice_items_invoice_id ON public.invoice_items USING btree (invoice_id);
CREATE INDEX idx_invoices_branch_id ON public.invoices USING btree (branch_id);
CREATE INDEX idx_invoices_corporate_account_id ON public.invoices USING btree (corporate_account_id);
CREATE INDEX idx_invoices_partner_id ON public.invoices USING btree (partner_id);
CREATE INDEX idx_invoices_patient_id ON public.invoices USING btree (patient_id);
CREATE INDEX idx_invoices_payment_status ON public.invoices USING btree (payment_status);
CREATE INDEX idx_invoices_visit_date ON public.invoices USING btree (visit_id, invoice_date) WHERE (deleted_at IS NULL);
CREATE INDEX idx_invoices_visit_id ON public.invoices USING btree (visit_id);
CREATE INDEX idx_lab_order_items_order_id ON public.lab_order_items USING btree (order_id);
CREATE INDEX idx_lab_order_items_test_id ON public.lab_order_items USING btree (test_id);
CREATE INDEX idx_lab_orders_active ON public.lab_orders USING btree (patient_id, created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_lab_orders_branch_id ON public.lab_orders USING btree (branch_id);
CREATE INDEX idx_lab_orders_ordered_by ON public.lab_orders USING btree (ordered_by);
CREATE INDEX idx_lab_orders_patient_id ON public.lab_orders USING btree (patient_id);
CREATE INDEX idx_lab_orders_patient_visit ON public.lab_orders USING btree (patient_id, visit_id) WHERE (deleted_at IS NULL);
CREATE INDEX idx_lab_orders_visit_active ON public.lab_orders USING btree (visit_id, created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_lab_orders_visit_id ON public.lab_orders USING btree (visit_id);
CREATE INDEX idx_lab_parameters_test_active ON public.lab_parameters USING btree (test_id, active) WHERE (deleted_at IS NULL);
CREATE INDEX idx_lab_parameters_test_id ON public.lab_parameters USING btree (test_id);
CREATE INDEX idx_lab_reference_ranges_parameter_id ON public.lab_reference_ranges USING btree (parameter_id);
CREATE INDEX idx_lab_results_entered_by ON public.lab_results USING btree (entered_by);
CREATE INDEX idx_lab_results_order_item_id ON public.lab_results USING btree (order_item_id);
CREATE INDEX idx_lab_results_parameter_id ON public.lab_results USING btree (parameter_id);
CREATE INDEX idx_lab_results_verified_by ON public.lab_results USING btree (verified_by);
CREATE INDEX idx_medical_certificates_deleted_at ON public.medical_certificates USING btree (deleted_at);
CREATE INDEX idx_medical_certificates_doctor_id ON public.medical_certificates USING btree (doctor_id);
CREATE INDEX idx_medical_certificates_patient_id ON public.medical_certificates USING btree (patient_id);
CREATE INDEX idx_medicines_batch_number ON public.medicines USING btree (batch_number) WHERE (deleted_at IS NULL);
CREATE INDEX idx_patient_discounts_partner_id ON public.patient_discounts USING btree (partner_id);
CREATE INDEX idx_patient_discounts_patient_id ON public.patient_discounts USING btree (patient_id);
CREATE INDEX idx_patient_insurance_company_id ON public.patient_insurance USING btree (company_id);
CREATE INDEX idx_patient_insurance_plan_id ON public.patient_insurance USING btree (plan_id);
CREATE INDEX idx_patients_active ON public.patients USING btree (branch_id, full_name) WHERE (deleted_at IS NULL);
CREATE INDEX idx_patients_branch_id ON public.patients USING btree (branch_id);
CREATE INDEX idx_payments_branch_id ON public.payments USING btree (branch_id);
CREATE INDEX idx_payments_invoice_date ON public.payments USING btree (invoice_id, payment_date) WHERE (deleted_at IS NULL);
CREATE INDEX idx_payments_invoice_id ON public.payments USING btree (invoice_id);
CREATE INDEX idx_payments_received_by ON public.payments USING btree (received_by);
CREATE INDEX idx_pharmacy_inventory_branch_id ON public.pharmacy_inventory USING btree (branch_id);
CREATE INDEX idx_pharmacy_inventory_fefo ON public.pharmacy_inventory USING btree (medicine_id, expiry_date) WHERE (deleted_at IS NULL);
CREATE INDEX idx_pharmacy_inventory_medicine_id ON public.pharmacy_inventory USING btree (medicine_id);
CREATE INDEX idx_pharmacy_inventory_supplier ON public.pharmacy_inventory USING btree (supplier_id) WHERE (deleted_at IS NULL);
CREATE INDEX idx_pharmacy_inventory_supplier_id ON public.pharmacy_inventory USING btree (supplier_id);
CREATE INDEX idx_prescription_items_medicine_id ON public.prescription_items USING btree (medicine_id);
CREATE INDEX idx_prescription_items_prescription_id ON public.prescription_items USING btree (prescription_id);
CREATE INDEX idx_prescriptions_active ON public.prescriptions USING btree (patient_id, created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_prescriptions_patient_id ON public.prescriptions USING btree (patient_id);
CREATE INDEX idx_prescriptions_prescribed_by ON public.prescriptions USING btree (prescribed_by);
CREATE INDEX idx_prescriptions_visit_active ON public.prescriptions USING btree (visit_id, created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_prescriptions_visit_id ON public.prescriptions USING btree (visit_id);
CREATE INDEX idx_procedure_orders_ordered_by ON public.procedure_orders USING btree (ordered_by);
CREATE INDEX idx_procedure_orders_patient_id ON public.procedure_orders USING btree (patient_id);
CREATE INDEX idx_procedure_orders_procedure_id ON public.procedure_orders USING btree (procedure_id);
CREATE INDEX idx_procedure_orders_visit_id ON public.procedure_orders USING btree (visit_id);
CREATE INDEX idx_procedure_results_procedure_order_id ON public.procedure_results USING btree (procedure_order_id);
CREATE INDEX idx_procedures_catalog_department_id ON public.procedures_catalog USING btree (department_id);
CREATE INDEX idx_queue_tickets_department_id ON public.queue_tickets USING btree (department_id);
CREATE INDEX idx_queue_tickets_patient_id ON public.queue_tickets USING btree (patient_id);
CREATE INDEX idx_queue_tickets_visit_id ON public.queue_tickets USING btree (visit_id);
CREATE INDEX idx_role_permissions_permission_id ON public.role_permissions USING btree (permission_id);
CREATE INDEX idx_role_permissions_role_id ON public.role_permissions USING btree (role_id);
CREATE INDEX idx_stock_movements_batch ON public.stock_movements USING btree (batch_id);
CREATE INDEX idx_stock_movements_branch_id ON public.stock_movements USING btree (branch_id);
CREATE INDEX idx_stock_movements_created_by ON public.stock_movements USING btree (created_by);
CREATE INDEX idx_stock_movements_reference ON public.stock_movements USING btree (reference_id);
CREATE INDEX idx_supplier_bills_branch_id ON public.supplier_bills USING btree (branch_id);
CREATE INDEX idx_supplier_bills_created_by ON public.supplier_bills USING btree (created_by);
CREATE INDEX idx_supplier_bills_deleted_by ON public.supplier_bills USING btree (deleted_by);
CREATE INDEX idx_supplier_bills_status ON public.supplier_bills USING btree (status) WHERE (deleted_at IS NULL);
CREATE INDEX idx_supplier_bills_supplier_date ON public.supplier_bills USING btree (supplier_id, bill_date DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_supplier_bills_updated_by ON public.supplier_bills USING btree (updated_by);
CREATE INDEX idx_supplier_payments_bill_date ON public.supplier_payments USING btree (supplier_bill_id, payment_date DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_supplier_payments_branch_id ON public.supplier_payments USING btree (branch_id);
CREATE INDEX idx_supplier_payments_created_by ON public.supplier_payments USING btree (created_by);
CREATE INDEX idx_supplier_payments_deleted_by ON public.supplier_payments USING btree (deleted_by);
CREATE INDEX idx_supplier_payments_supplier_id ON public.supplier_payments USING btree (supplier_id);
CREATE INDEX idx_users_branch_id ON public.users USING btree (branch_id);
CREATE INDEX idx_users_department_id ON public.users USING btree (department_id);
CREATE INDEX idx_users_role_id ON public.users USING btree (role_id);
CREATE INDEX idx_visits_active ON public.visits USING btree (visit_date) WHERE (deleted_at IS NULL);
CREATE INDEX idx_visits_appointment_id ON public.visits USING btree (appointment_id);
CREATE INDEX idx_visits_branch_id ON public.visits USING btree (branch_id);
CREATE INDEX idx_visits_department_id ON public.visits USING btree (department_id);
CREATE INDEX idx_visits_doctor_id ON public.visits USING btree (doctor_id);
CREATE INDEX idx_visits_patient_active ON public.visits USING btree (patient_id, created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX idx_visits_patient_id ON public.visits USING btree (patient_id);
CREATE INDEX idx_visits_queue_date_active ON public.visits USING btree (queue_date, queue_number, created_at) WHERE (deleted_at IS NULL);
CREATE INDEX idx_visits_queue_date_number ON public.visits USING btree (queue_date, queue_number);
CREATE INDEX idx_visits_queue_day ON public.visits USING btree (queue_date, queue_number) WHERE (deleted_at IS NULL);
CREATE INDEX idx_vitals_patient_id ON public.vitals USING btree (patient_id);
CREATE UNIQUE INDEX insurance_claims_one_active_nonrejected_per_invoice_uq ON public.insurance_claims USING btree (invoice_id) WHERE ((deleted_at IS NULL) AND (invoice_id IS NOT NULL) AND (status IS DISTINCT FROM 'rejected'::text));
CREATE INDEX ix_claim_items_claim ON public.insurance_claim_items USING btree (claim_id);
CREATE INDEX ix_claim_payments_claim ON public.insurance_claim_payments USING btree (claim_id);
CREATE INDEX ix_claims_patient_insurance ON public.insurance_claims USING btree (patient_insurance_id);
CREATE INDEX ix_claims_status ON public.insurance_claims USING btree (status);
CREATE INDEX ix_coverage_rules_generic ON public.insurance_coverage_rules USING btree (generic_name) WHERE (generic_name IS NOT NULL);
CREATE INDEX ix_coverage_rules_plan ON public.insurance_coverage_rules USING btree (plan_id, service_type);
CREATE INDEX ix_ins_plans_company ON public.insurance_plans USING btree (company_id);
CREATE INDEX ix_patient_insurance_patient ON public.patient_insurance USING btree (patient_id);
CREATE INDEX ix_patient_insurance_status ON public.patient_insurance USING btree (status);
CREATE INDEX lab_order_items_order_created_idx ON public.lab_order_items USING btree (order_id, created_at) WHERE (deleted_at IS NULL);
CREATE INDEX lab_orders_status_created_idx ON public.lab_orders USING btree (status, created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX lab_results_order_item_parameter_idx ON public.lab_results USING btree (order_item_id, parameter_id);
CREATE INDEX lab_tests_active_category_name_idx ON public.lab_tests USING btree (category, name) WHERE ((deleted_at IS NULL) AND (active = true));
CREATE INDEX lab_tests_name_ar_trgm_idx ON public.lab_tests USING gin (name_ar gin_trgm_ops) WHERE (deleted_at IS NULL);
CREATE INDEX lab_tests_name_trgm_idx ON public.lab_tests USING gin (name gin_trgm_ops) WHERE (deleted_at IS NULL);
CREATE UNIQUE INDEX medical_certificates_certificate_number_uq ON public.medical_certificates USING btree (certificate_number);
CREATE INDEX medical_certificates_visit_id_idx ON public.medical_certificates USING btree (visit_id);
CREATE INDEX medicines_barcode_idx ON public.medicines USING btree (barcode) WHERE ((deleted_at IS NULL) AND (barcode IS NOT NULL));
CREATE INDEX medicines_brand_trgm_idx ON public.medicines USING gin (brand_name gin_trgm_ops) WHERE (deleted_at IS NULL);
CREATE INDEX medicines_generic_name_idx ON public.medicines USING btree (generic_name) WHERE ((deleted_at IS NULL) AND (generic_name IS NOT NULL));
CREATE INDEX medicines_generic_trgm_idx ON public.medicines USING gin (generic_name gin_trgm_ops) WHERE (deleted_at IS NULL);
CREATE INDEX medicines_search_trgm_idx ON public.medicines USING gin (name gin_trgm_ops) WHERE (deleted_at IS NULL);
CREATE UNIQUE INDEX patients_active_national_id_normalized_uq ON public.patients USING btree (lower(btrim(national_id))) WHERE ((deleted_at IS NULL) AND (national_id IS NOT NULL) AND (btrim(national_id) <> ''::text));
CREATE INDEX patients_created_at_idx ON public.patients USING btree (created_at DESC) WHERE (deleted_at IS NULL);
CREATE INDEX patients_full_name_trgm_idx ON public.patients USING gin (full_name gin_trgm_ops);
CREATE INDEX patients_mrn_idx ON public.patients USING btree (mrn);
CREATE INDEX patients_national_id_idx ON public.patients USING btree (national_id);
CREATE INDEX patients_phone_idx ON public.patients USING btree (phone);
CREATE INDEX pharmacy_inventory_fefo_idx ON public.pharmacy_inventory USING btree (medicine_id, expiry_date, created_at) WHERE ((deleted_at IS NULL) AND (quantity_remaining > (0)::numeric));
CREATE UNIQUE INDEX pharmacy_inventory_idempotency_key_unique ON public.pharmacy_inventory USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);
CREATE INDEX stock_movements_medicine_created_idx ON public.stock_movements USING btree (medicine_id, created_at DESC);
CREATE UNIQUE INDEX uq_cashbox_reversal_of ON public.cashbox_transactions USING btree (reversal_of) WHERE (reversal_of IS NOT NULL);
CREATE UNIQUE INDEX uq_cashbox_source ON public.cashbox_transactions USING btree (source_type, source_id) WHERE ((source_type IS NOT NULL) AND (source_id IS NOT NULL));
CREATE UNIQUE INDEX uq_claim_payment_source ON public.cashbox_transactions USING btree (source_type, source_id) WHERE (source_type = 'insurance_claim_payment'::text);
CREATE UNIQUE INDEX uq_invoices_visit_id ON public.invoices USING btree (visit_id) WHERE ((visit_id IS NOT NULL) AND (deleted_at IS NULL) AND (is_primary IS TRUE));
CREATE UNIQUE INDEX uq_lab_results_order_parameter ON public.lab_results USING btree (order_item_id, parameter_id) WHERE (deleted_at IS NULL);
CREATE UNIQUE INDEX uq_visits_queue_date_number ON public.visits USING btree (queue_date, queue_number) WHERE ((deleted_at IS NULL) AND (queue_number IS NOT NULL));
CREATE INDEX visits_doctor_date_status_idx ON public.visits USING btree (doctor_id, visit_date DESC, status) WHERE (deleted_at IS NULL);
CREATE INDEX visits_patient_date_idx ON public.visits USING btree (patient_id, visit_date DESC) WHERE (deleted_at IS NULL);

-- Function and procedure definitions
CREATE OR REPLACE FUNCTION private.app_has_attachment_branch_access(_patient_id uuid, _visit_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN private.is_super_admin() THEN true
    WHEN _patient_id IS NULL AND _visit_id IS NULL THEN false
    ELSE
      (
        _patient_id IS NULL
        OR EXISTS (
          SELECT 1 FROM public.patients AS p
          WHERE p.id = _patient_id
            AND private.app_has_branch_access(p.branch_id)
        )
      )
      AND
      (
        _visit_id IS NULL
        OR EXISTS (
          SELECT 1
          FROM public.visits AS v
          LEFT JOIN public.patients AS p ON p.id = v.patient_id
          WHERE v.id = _visit_id
            AND private.app_has_branch_access(COALESCE(v.branch_id, p.branch_id))
        )
      )
  END
$function$

CREATE OR REPLACE FUNCTION private.app_has_branch_access(_branch_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false)
    OR EXISTS (SELECT 1 FROM public.users AS u
      WHERE u.auth_user_id = auth.uid()
        AND COALESCE(u.active, true) = true
        AND u.deleted_at IS NULL
        AND u.branch_id = _branch_id)
$function$

CREATE OR REPLACE FUNCTION private.app_has_claim_branch(_claim_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false)
    OR EXISTS (
      SELECT 1 FROM public.insurance_claims AS c
      JOIN public.invoices AS i ON i.id = c.invoice_id
      WHERE c.id = _claim_id
        AND i.branch_id = (SELECT u.branch_id FROM public.users AS u
          WHERE u.auth_user_id = auth.uid()
            AND COALESCE(u.active, true) = true
            AND u.deleted_at IS NULL
          ORDER BY u.id LIMIT 1))
$function$

CREATE OR REPLACE FUNCTION private.app_has_invoice_branch(_invoice_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false)
    OR EXISTS (SELECT 1 FROM public.invoices AS i
      WHERE i.id = _invoice_id
        AND i.branch_id = (SELECT u.branch_id FROM public.users AS u
          WHERE u.auth_user_id = auth.uid()
            AND COALESCE(u.active, true) = true
            AND u.deleted_at IS NULL
          ORDER BY u.id LIMIT 1))
$function$

CREATE OR REPLACE FUNCTION private.app_has_lab_order_branch_access(_order_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.lab_orders AS lo
    LEFT JOIN public.visits AS v ON v.id = lo.visit_id
    LEFT JOIN public.patients AS p ON p.id = lo.patient_id
    WHERE lo.id = _order_id
      AND private.lab_order_parent_ids_match(lo.patient_id, lo.visit_id)
      -- Match the parent lab_orders RLS policy: a NULL explicit branch fails
      -- closed for branch-scoped users, even if a patient/visit has a branch.
      -- Super admins retain access through app_has_branch_access().
      AND private.app_has_branch_access(lo.branch_id)
  )
$function$

CREATE OR REPLACE FUNCTION private.app_has_lab_order_item_branch_access(_order_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
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
$function$

CREATE OR REPLACE FUNCTION private.app_has_lab_result_branch_access(_order_item_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.lab_order_items AS loi
    JOIN public.lab_orders AS lo ON lo.id = loi.order_id
    LEFT JOIN public.visits AS v ON v.id = lo.visit_id
    LEFT JOIN public.patients AS p ON p.id = lo.patient_id
    WHERE loi.id = _order_item_id
      AND private.app_has_branch_access(COALESCE(lo.branch_id, v.branch_id, p.branch_id))
  )
$function$

CREATE OR REPLACE FUNCTION private.app_has_patient_branch(_patient_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false)
    OR EXISTS (SELECT 1 FROM public.patients AS p
      WHERE p.id = _patient_id
        AND p.branch_id = (SELECT u.branch_id FROM public.users AS u
          WHERE u.auth_user_id = auth.uid()
            AND COALESCE(u.active, true) = true
            AND u.deleted_at IS NULL
          ORDER BY u.id LIMIT 1))
$function$

CREATE OR REPLACE FUNCTION private.app_has_patient_visit_branch_access(_patient_id uuid, _visit_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
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
$function$

CREATE OR REPLACE FUNCTION private.app_has_perm(_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
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
$function$

CREATE OR REPLACE FUNCTION private.app_has_prescription_branch_access(_prescription_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.prescriptions AS p
    WHERE p.id = _prescription_id
      AND private.app_has_prescription_parent_access(p.patient_id, p.visit_id)
  )
$function$

CREATE OR REPLACE FUNCTION private.app_has_prescription_parent_access(_patient_id uuid, _visit_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
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
$function$

CREATE OR REPLACE FUNCTION private.app_has_prescription_parent_branch_access(_patient_id uuid, _visit_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT private.app_has_attachment_branch_access(_patient_id, _visit_id)
    AND (
      _visit_id IS NULL OR _patient_id IS NULL
      OR EXISTS (SELECT 1 FROM public.visits v WHERE v.id=_visit_id AND v.patient_id=_patient_id)
    )
$function$

CREATE OR REPLACE FUNCTION private.app_has_prior_authorization_branch_access(_patient_insurance_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE(private.is_super_admin(), false)
    OR EXISTS (
      SELECT 1
      FROM public.patient_insurance AS pi
      WHERE pi.id = _patient_insurance_id
        AND private.app_has_patient_branch(pi.patient_id)
    )
$function$

CREATE OR REPLACE FUNCTION private.app_has_procedure_order_branch_access(_order_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.procedure_orders AS po
    WHERE po.id = _order_id
      AND private.app_has_patient_visit_branch_access(po.patient_id, po.visit_id)
  )
$function$

CREATE OR REPLACE FUNCTION private.app_has_visit_branch_access(_visit_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.visits AS v
    LEFT JOIN public.patients AS p ON p.id = v.patient_id
    WHERE v.id = _visit_id
      AND private.app_has_branch_access(COALESCE(v.branch_id, p.branch_id))
  )
$function$

CREATE OR REPLACE FUNCTION private.create_or_append_visit_invoice_atomic(p_visit_id uuid, p_invoice_date date, p_discount numeric, p_items jsonb, p_separate_invoice boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_user_branch uuid;
  v_patient_id uuid;
  v_patient_branch uuid;
  v_invoice_id uuid;
  v_invoice_number text;
  v_month_key text;
  v_next_no bigint;
  v_item jsonb;
  v_item_name text;
  v_item_type text;
  v_quantity numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_subtotal numeric := 0;
  v_discount numeric := 0;
  v_net numeric := 0;
  v_paid numeric := 0;
  v_existing_status text;
  v_existing_payment_status text;
  v_existing_net numeric := 0;
  v_type_count integer := 0;
  v_has_consultation boolean := false;
  v_has_lab boolean := false;
  v_has_pharmacy boolean := false;
  v_has_other boolean := false;
  v_existing boolean := false;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required' USING ERRCODE = '42501';
  END IF;
  IF p_visit_id IS NULL OR p_invoice_date IS NULL THEN
    RAISE EXCEPTION 'visit and invoice date are required';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'invoice items must be a non-empty JSON array';
  END IF;
  IF p_discount IS NULL OR p_discount::text IN ('NaN','Infinity','-Infinity')
     OR p_discount < 0 OR p_discount <> round(p_discount, 2) THEN
    RAISE EXCEPTION 'discount must be finite, non-negative, and have at most two decimal places';
  END IF;
  IF p_separate_invoice IS NULL THEN
    RAISE EXCEPTION 'separate-invoice choice must be explicit';
  END IF;

  SELECT u.branch_id INTO v_user_branch
    FROM public.users AS u
   WHERE u.id = v_uid AND u.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active application user not found' USING ERRCODE = '42501';
  END IF;

  SELECT v.patient_id INTO v_patient_id
    FROM public.visits AS v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;

  SELECT p.branch_id INTO v_patient_branch
    FROM public.patients AS p
   WHERE p.id = v_patient_id AND p.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active patient not found'; END IF;
  IF NOT public.is_super_admin()
     AND (v_user_branch IS NULL OR v_patient_branch IS DISTINCT FROM v_user_branch) THEN
    RAISE EXCEPTION 'cross-branch invoice access denied' USING ERRCODE = '42501';
  END IF;

  -- Validate incoming line items and derive the narrowest permission required.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'each invoice item must be an object';
    END IF;
    v_item_name := btrim(COALESCE(v_item->>'item_name',''));
    v_item_type := CASE WHEN v_item->>'item_type' = 'laboratory' THEN 'lab' ELSE v_item->>'item_type' END;
    IF v_item_name = '' THEN RAISE EXCEPTION 'invoice item description is required'; END IF;
    IF v_item_type IS NULL OR v_item_type NOT IN ('consultation','lab','pharmacy','procedure','other') THEN
      RAISE EXCEPTION 'unsupported invoice item type';
    END IF;
    IF jsonb_typeof(v_item->'quantity') IS DISTINCT FROM 'number'
       OR jsonb_typeof(v_item->'unit_price') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'invoice quantity and unit price must be JSON numbers';
    END IF;
    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_price := (v_item->>'unit_price')::numeric;
    IF v_quantity::text IN ('NaN','Infinity','-Infinity')
       OR v_quantity <= 0 OR v_quantity <> trunc(v_quantity) THEN
      RAISE EXCEPTION 'invoice quantity must be a finite positive whole number';
    END IF;
    IF v_unit_price::text IN ('NaN','Infinity','-Infinity')
       OR v_unit_price < 0 OR v_unit_price <> round(v_unit_price, 2) THEN
      RAISE EXCEPTION 'unit price must be finite, non-negative, and have at most two decimal places';
    END IF;
    v_line_total := round(v_quantity * v_unit_price, 2);
    IF v_line_total::text IN ('NaN','Infinity','-Infinity') THEN
      RAISE EXCEPTION 'invoice line total is outside the supported numeric range';
    END IF;
    v_subtotal := v_subtotal + v_line_total;
    IF v_item_type = 'consultation' THEN v_has_consultation := true;
    ELSIF v_item_type = 'lab' THEN v_has_lab := true;
    ELSIF v_item_type = 'pharmacy' THEN v_has_pharmacy := true;
    ELSE v_has_other := true;
    END IF;
  END LOOP;

  v_type_count := v_has_consultation::integer + v_has_lab::integer
    + v_has_pharmacy::integer + v_has_other::integer;
  IF p_separate_invoice AND NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'separate invoices require billing.create' USING ERRCODE = '42501';
  ELSIF v_type_count > 1 AND NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'mixed-service invoices require billing.create' USING ERRCODE = '42501';
  ELSIF v_has_consultation AND NOT (public.app_has_perm('visits.create') OR public.app_has_perm('billing.create')) THEN
    RAISE EXCEPTION 'consultation invoice permission denied' USING ERRCODE = '42501';
  ELSIF v_has_lab AND NOT (public.app_has_perm('lab.create') OR public.app_has_perm('billing.create')) THEN
    RAISE EXCEPTION 'laboratory invoice permission denied' USING ERRCODE = '42501';
  ELSIF v_has_pharmacy AND NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'pharmacy line items require the billing workflow RPC' USING ERRCODE = '42501';
  ELSIF v_has_other AND NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'billing permission denied' USING ERRCODE = '42501';
  END IF;

  -- Serialize invoice selection/creation per visit so simultaneous lab requests
  -- cannot create two primary invoices or race their totals.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('roshan:visit-invoice:' || p_visit_id::text));

  IF NOT p_separate_invoice THEN
    SELECT i.id, COALESCE(i.discount_amount,0), COALESCE(i.paid_amount,0),
           i.status, i.payment_status, COALESCE(i.net_amount,0)
      INTO v_invoice_id, v_discount, v_paid, v_existing_status, v_existing_payment_status, v_existing_net
      FROM public.invoices AS i
     WHERE i.visit_id = p_visit_id AND i.is_primary IS TRUE AND i.deleted_at IS NULL
     FOR UPDATE;
    v_existing := FOUND;
  END IF;

  IF v_existing THEN
    IF p_discount <> 0 THEN
      RAISE EXCEPTION 'discount cannot be changed while appending invoice items';
    END IF;
    -- Consultation creation can be retried after a network timeout; do not double-charge it.
    IF v_has_consultation AND v_type_count = 1 AND EXISTS (
      SELECT 1 FROM public.invoice_items AS ii
       WHERE ii.invoice_id = v_invoice_id
         AND ii.item_type = 'consultation'
         AND ii.deleted_at IS NULL
    ) THEN
      RETURN v_invoice_id;
    END IF;
    IF v_existing_status IN ('paid','closed','finalized')
       OR v_existing_payment_status = 'paid'
       OR (v_existing_net > 0 AND v_paid >= v_existing_net) THEN
      RAISE EXCEPTION 'invoice is finalized; choose a separate invoice';
    END IF;
    IF v_paid < 0 THEN RAISE EXCEPTION 'invalid existing paid amount'; END IF;
    -- Insert only after all authorization and invoice-state checks have passed.
    FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
    LOOP
      v_item_name := btrim(v_item->>'item_name');
      v_item_type := CASE WHEN v_item->>'item_type' = 'laboratory' THEN 'lab' ELSE v_item->>'item_type' END;
      v_quantity := (v_item->>'quantity')::numeric;
      v_unit_price := (v_item->>'unit_price')::numeric;
      v_line_total := round(v_quantity * v_unit_price, 2);
      INSERT INTO public.invoice_items (
        invoice_id, item_name, item_type, quantity, unit_price, total_price,
        item_id, created_by, updated_by
      ) VALUES (
        v_invoice_id, v_item_name, v_item_type, v_quantity, v_unit_price, v_line_total,
        NULLIF(v_item->>'item_id','')::uuid, v_uid, v_uid
      );
    END LOOP;
    SELECT COALESCE(sum(ii.total_price),0) INTO v_subtotal
      FROM public.invoice_items AS ii
     WHERE ii.invoice_id = v_invoice_id AND ii.deleted_at IS NULL;
    IF v_discount > v_subtotal THEN RAISE EXCEPTION 'existing discount exceeds updated subtotal'; END IF;
    v_net := round(v_subtotal - v_discount, 2);
    IF v_paid > v_net THEN RAISE EXCEPTION 'updated invoice total is below paid amount'; END IF;
    UPDATE public.invoices
       SET subtotal = v_subtotal,
           total_amount = v_subtotal,
           net_amount = v_net,
           status = CASE WHEN v_net > 0 AND v_paid >= v_net THEN 'paid'
                         WHEN v_paid > 0 THEN 'partial' ELSE 'unpaid' END,
           payment_status = CASE WHEN v_net > 0 AND v_paid >= v_net THEN 'paid'
                                 WHEN v_paid > 0 THEN 'partial' ELSE 'unpaid' END,
           updated_by = v_uid,
           updated_at = pg_catalog.now()
     WHERE id = v_invoice_id;
    RETURN v_invoice_id;
  END IF;

  IF p_discount > v_subtotal THEN RAISE EXCEPTION 'discount cannot exceed invoice subtotal'; END IF;
  v_net := round(v_subtotal - p_discount, 2);
  v_month_key := pg_catalog.to_char(pg_catalog.now(), 'YYYYMM');
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('roshan:invoice:' || v_month_key));
  SELECT COALESCE(max((pg_catalog.regexp_match(i.invoice_number, '^INV-[0-9]{6}-([0-9]+)$'))[1]::bigint),0) + 1
    INTO v_next_no
    FROM public.invoices AS i
   WHERE i.invoice_number LIKE 'INV-' || v_month_key || '-%';
  v_invoice_number := 'INV-' || v_month_key || '-' || pg_catalog.lpad(v_next_no::text, 5, '0');

  INSERT INTO public.invoices (
    invoice_number, patient_id, visit_id, invoice_date, total_amount, subtotal,
    discount_amount, net_amount, paid_amount, status, payment_status, branch_id,
    created_by, updated_by, is_primary
  ) VALUES (
    v_invoice_number, v_patient_id, p_visit_id, p_invoice_date, v_subtotal, v_subtotal,
    p_discount, v_net, 0, 'unpaid', 'unpaid', v_patient_branch,
    v_uid, v_uid, NOT p_separate_invoice
  ) RETURNING id INTO v_invoice_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    v_item_name := btrim(v_item->>'item_name');
    v_item_type := CASE WHEN v_item->>'item_type' = 'laboratory' THEN 'lab' ELSE v_item->>'item_type' END;
    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_price := (v_item->>'unit_price')::numeric;
    v_line_total := round(v_quantity * v_unit_price, 2);
    INSERT INTO public.invoice_items (
      invoice_id, item_name, item_type, quantity, unit_price, total_price,
      item_id, created_by, updated_by
    ) VALUES (
      v_invoice_id, v_item_name, v_item_type, v_quantity, v_unit_price, v_line_total,
      NULLIF(v_item->>'item_id','')::uuid, v_uid, v_uid
    );
  END LOOP;
  RETURN v_invoice_id;
END;
$function$

CREATE OR REPLACE FUNCTION private.create_queue_ticket()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  INSERT INTO public.queue_tickets
    (visit_id, patient_id, visit_date, queue_number, status, department_id)
  VALUES
    (
      new.id,
      new.patient_id,
      coalesce(
        new.queue_date,
        (new.visit_date AT TIME ZONE 'Africa/Khartoum')::date
      ),
      'Q' || new.queue_number::text,
      'waiting',
      new.department_id
    );

  RETURN new;
END;
$function$

CREATE OR REPLACE FUNCTION private.current_app_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT u.id FROM public.users AS u
  WHERE u.auth_user_id = auth.uid()
    AND COALESCE(u.active, true) = true
    AND u.deleted_at IS NULL
  ORDER BY u.id LIMIT 1
$function$

CREATE OR REPLACE FUNCTION private.current_role_code()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT r.code FROM public.users AS u
  JOIN public.roles AS r ON r.id = u.role_id
  WHERE u.auth_user_id = auth.uid()
    AND COALESCE(u.active, true) = true
    AND u.deleted_at IS NULL
  ORDER BY u.id LIMIT 1
$function$

CREATE OR REPLACE FUNCTION private.ensure_visit_queue()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  d date;
  next_number integer;
BEGIN
  d := coalesce(
    new.queue_date,
    (new.visit_date AT TIME ZONE 'Africa/Khartoum')::date,
    current_date
  );
  new.queue_date := d;

  IF new.queue_number IS NULL THEN
    PERFORM pg_advisory_xact_lock(
      hashtextextended('roshan.queue.' || d::text, 0)
    );

    SELECT coalesce(max(v.queue_number), 0) + 1
      INTO next_number
    FROM public.visits v
    WHERE v.queue_date = d
       OR (v.visit_date AT TIME ZONE 'Africa/Khartoum')::date = d;

    new.queue_number := next_number;
  END IF;

  new.visit_number := new.queue_number::text;
  RETURN new;
END;
$function$

CREATE OR REPLACE FUNCTION private.guard_super_admin_role_permissions()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if private.is_trusted_role_guard_context() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  if coalesce(private.is_super_admin(), false) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if private.is_super_admin_role(new.role_id) then
      raise exception 'Only a super admin can change super_admin permissions'
        using errcode = '42501';
    end if;
    return new;
  elsif tg_op = 'UPDATE' then
    if private.is_super_admin_role(old.role_id)
       or private.is_super_admin_role(new.role_id) then
      raise exception 'Only a super admin can change super_admin permissions'
        using errcode = '42501';
    end if;
    return new;
  else
    if private.is_super_admin_role(old.role_id) then
      raise exception 'Only a super admin can change super_admin permissions'
        using errcode = '42501';
    end if;
    return old;
  end if;
end
$function$

CREATE OR REPLACE FUNCTION private.guard_super_admin_roles()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if private.is_trusted_role_guard_context() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  if coalesce(private.is_super_admin(), false) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.code = 'super_admin' then
      raise exception 'Only a super admin can create the super_admin role'
        using errcode = '42501';
    end if;
    return new;
  elsif tg_op = 'UPDATE' then
    if old.code = 'super_admin' or new.code = 'super_admin' then
      raise exception 'Only a super admin can modify the super_admin role'
        using errcode = '42501';
    end if;
    return new;
  else
    if old.code = 'super_admin' then
      raise exception 'Only a super admin can delete the super_admin role'
        using errcode = '42501';
    end if;
    return old;
  end if;
end
$function$

CREATE OR REPLACE FUNCTION private.guard_super_admin_users()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  -- Trusted, non-end-user context (migrations, service_role).
  if private.is_trusted_role_guard_context() then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  -- A real super admin may do anything.
  if coalesce(private.is_super_admin(), false) then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if tg_op = 'INSERT' then
    if private.is_super_admin_role(new.role_id) then
      raise exception 'Only a super admin can assign the super_admin role'
        using errcode = '42501';
    end if;
    return new;

  elsif tg_op = 'UPDATE' then
    -- Cannot touch an existing super admin's row at all ...
    if private.is_super_admin_role(old.role_id) then
      raise exception 'Only a super admin can modify a super admin account'
        using errcode = '42501';
    end if;
    -- ... and cannot move anyone INTO the super_admin role.
    if new.role_id is distinct from old.role_id
       and private.is_super_admin_role(new.role_id) then
      raise exception 'Only a super admin can assign the super_admin role'
        using errcode = '42501';
    end if;
    return new;

  else -- DELETE
    if private.is_super_admin_role(old.role_id) then
      raise exception 'Only a super admin can delete a super admin account'
        using errcode = '42501';
    end if;
    return old;
  end if;
end
$function$

CREATE OR REPLACE FUNCTION private.is_super_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT COALESCE((SELECT private.current_role_code()) = 'super_admin', false)
$function$

CREATE OR REPLACE FUNCTION private.is_super_admin_role(_role_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce(
    (select r.code = 'super_admin' from public.roles r where r.id = _role_id),
    false
  )
$function$

CREATE OR REPLACE FUNCTION private.is_trusted_role_guard_context()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select coalesce(auth.role() = 'service_role', false)
      or (auth.role() is null and session_user in ('postgres', 'supabase_admin'))
$function$

CREATE OR REPLACE FUNCTION private.lab_order_parent_ids_match(_patient_id uuid, _visit_id uuid)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT CASE
    WHEN _visit_id IS NULL THEN true
    ELSE EXISTS (
      SELECT 1
      FROM public.visits AS v
      WHERE v.id = _visit_id
        AND (_patient_id IS NULL OR v.patient_id = _patient_id)
    )
  END
$function$

CREATE OR REPLACE FUNCTION private.next_queue_number(_visit_date date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE next_number integer;
BEGIN
  IF _visit_date IS NULL THEN RAISE EXCEPTION 'visit_date is required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('roshan.queue.' || _visit_date::text, 0));
  SELECT COALESCE(MAX(v.queue_number), 0) + 1 INTO next_number
    FROM public.visits AS v WHERE v.queue_date = _visit_date;
  RETURN next_number;
END;
$function$

CREATE OR REPLACE FUNCTION private.next_visit_number(_visit_date date)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE next_number integer;
BEGIN
  IF _visit_date IS NULL THEN RAISE EXCEPTION 'visit_date is required'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended('roshan.visit.' || _visit_date::text, 0));
  SELECT COALESCE(MAX(CASE WHEN v.visit_number ~ '^[0-9]+$' THEN v.visit_number::integer END), 0) + 1
    INTO next_number
    FROM public.visits AS v
   WHERE v.visit_date = _visit_date AND v.deleted_at IS NULL;
  RETURN lpad(next_number::text, 3, '0');
END;
$function$

CREATE OR REPLACE FUNCTION private.prevent_locked_visit_mutation()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if coalesce(old.is_locked, false) = true
     and not public.is_super_admin()
  then
    raise exception 'This visit is locked and cannot be modified.';
  end if;

  return coalesce(new, old);
end;
$function$

CREATE OR REPLACE FUNCTION private.setup_required()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  SELECT NOT EXISTS (SELECT 1 FROM public.users)
$function$

CREATE OR REPLACE FUNCTION private.sync_queue_ticket_number()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  q integer;
  d date;
  p uuid;
  dept uuid;
begin
  if new.visit_id is null then
    raise exception 'queue ticket requires visit_id';
  end if;

  select v.queue_number,
         v.queue_date,
         v.patient_id,
         v.department_id
    into q, d, p, dept
  from public.visits v
  where v.id = new.visit_id;

  if q is null then
    raise exception 'visit % has no queue number', new.visit_id;
  end if;

  new.queue_number := 'Q' || q::text;
  new.visit_date := coalesce(new.visit_date, d, current_date);
  new.patient_id := coalesce(new.patient_id, p);
  new.department_id := coalesce(new.department_id, dept);

  return new;
end;
$function$

CREATE OR REPLACE FUNCTION private.sync_user_role_text()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  IF NEW.role_id IS NOT NULL THEN
    SELECT r.code
      INTO NEW.role
      FROM public.roles AS r
     WHERE r.id = NEW.role_id;
  END IF;
  RETURN NEW;
END;
$function$

CREATE OR REPLACE FUNCTION public.add_cashbox_entry(_direction text, _amount numeric, _type text DEFAULT 'adjustment'::text, _method text DEFAULT 'cash'::text, _category text DEFAULT NULL::text, _description text DEFAULT NULL::text, _date timestamp with time zone DEFAULT now())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid; bid uuid; txid uuid;
begin
  if not public.app_has_perm('accounting.create') then raise exception 'Permission denied'; end if;
  if _direction not in ('in','out') then raise exception 'Invalid cashbox direction'; end if;
  if _amount is null or _amount<=0 then raise exception 'Amount must be greater than zero'; end if;
  if _type not in ('deposit','withdrawal','adjustment') then raise exception 'Invalid manual transaction type'; end if;
  uid:=public.current_app_user_id(); select branch_id into bid from public.users where id=uid;
  if not public.is_super_admin() and bid is null then raise exception 'user branch is not configured'; end if;
  insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,transaction_date,created_by)
  values(bid,_type,case when _direction='in' then _amount else -_amount end,coalesce(_method,'cash'),_category,_description,coalesce(_date,now()),uid) returning id into txid;
  return txid;
end; $function$

CREATE OR REPLACE FUNCTION public.app_has_perm(_code text)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ SELECT private.app_has_perm(_code) $function$

CREATE OR REPLACE FUNCTION public.audit_row_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare uid uuid;
begin
  select id into uid from public.users where auth_user_id = auth.uid() limit 1;
  insert into public.audit_logs (user_id, action, table_name, record_id, old_data, new_data)
  values (
    uid, tg_op, tg_table_name,
    (case when tg_op = 'DELETE' then to_jsonb(old)->>'id' else to_jsonb(new)->>'id' end)::uuid,
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end
  );
  return coalesce(new, old);
end $function$

CREATE OR REPLACE FUNCTION public.bootstrap_super_admin(_full_name text, _email text, _phone text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare new_id uuid; role_uuid uuid;
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to bootstrap';
  end if;
  if exists (select 1 from public.users) then
    raise exception 'Setup already completed';
  end if;
  select id into role_uuid from public.roles where code = 'super_admin';
  insert into public.users (auth_user_id, full_name, email, phone, role_id, active)
  values (auth.uid(), _full_name, _email, _phone, role_uuid, true)
  returning id into new_id;
  return new_id;
end $function$

CREATE OR REPLACE FUNCTION public.bootstrap_super_admin(p_auth_user_id uuid, p_full_name text, p_email text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
                                                                                                                    DECLARE
                                                                                                                        v_role_id UUID;
                                                                                                                            v_user_id UUID;
                                                                                                                            BEGIN
                                                                                                                                -- Check if Super Admin already exists
                                                                                                                                    IF NOT public.setup_required() THEN
                                                                                                                                            RAISE EXCEPTION 'Setup is already completed. Super Admin exists.';
                                                                                                                                                END IF;

                                                                                                                                                    -- Get or create Super Admin role
                                                                                                                                                        SELECT id INTO v_role_id FROM public.roles WHERE name IN ('Super Admin', 'super_admin') LIMIT 1;
                                                                                                                                                            IF v_role_id IS NULL THEN
                                                                                                                                                                    INSERT INTO public.roles (name, description) 
                                                                                                                                                                            VALUES ('Super Admin', 'Full system access') 
                                                                                                                                                                                    RETURNING id INTO v_role_id;
                                                                                                                                                                                        END IF;

                                                                                                                                                                                            -- Create or update public.users record
                                                                                                                                                                                                INSERT INTO public.users (auth_user_id, name, email, role_id)
                                                                                                                                                                                                    VALUES (p_auth_user_id, p_full_name, p_email, v_role_id)
                                                                                                                                                                                                        ON CONFLICT (auth_user_id) DO UPDATE 
                                                                                                                                                                                                            SET role_id = v_role_id, name = EXCLUDED.name, email = EXCLUDED.email
                                                                                                                                                                                                                RETURNING id INTO v_user_id;

                                                                                                                                                                                                                    RETURN v_user_id;
                                                                                                                                                                                                                    END;
                                                                                                                                                                                                                    $function$

CREATE OR REPLACE FUNCTION public.complete_lab_order_item(p_order_item_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
  IF v_status = 'completed' THEN
    RETURN;
  END IF;
  IF v_status = 'verified' THEN
    RAISE EXCEPTION 'verified lab result is immutable; reopen through the correction workflow'
      USING ERRCODE = '22023';
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
$function$

CREATE OR REPLACE FUNCTION public.complete_visit_atomic(p_visit_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
  IF v_status = 'completed' THEN
    RETURN;
  END IF;
  UPDATE public.visits
  SET status='completed', completed_at=COALESCE(completed_at, pg_catalog.now()),
      updated_by=v_user_id, updated_at=pg_catalog.now()
  WHERE id=p_visit_id AND deleted_at IS NULL;
  UPDATE public.queue_tickets
  SET status='completed', completed_at=COALESCE(completed_at, pg_catalog.now()), updated_by=v_user_id
  WHERE visit_id=p_visit_id AND deleted_at IS NULL AND status IN ('waiting','called','in_progress');
END;
$function$

CREATE OR REPLACE FUNCTION public.create_billing_invoice_atomic(p_patient_id uuid, p_visit_id uuid, p_partner_id uuid, p_invoice_date date, p_discount numeric, p_items jsonb, p_separate_invoice boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_visit_patient_id uuid;
  v_invoice_id uuid;
  v_existing_partner uuid;
  v_item jsonb;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'billing permission denied' USING ERRCODE = '42501';
  END IF;
  IF p_patient_id IS NULL OR p_invoice_date IS NULL THEN
    RAISE EXCEPTION 'patient and invoice date are required';
  END IF;
  IF p_separate_invoice IS NULL THEN
    RAISE EXCEPTION 'separate-invoice choice must be explicit';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array'
     OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'invoice items must be a non-empty JSON array';
  END IF;

  -- The manual screen is for services not already billed by clinical workflows.
  -- Consultation, lab, and pharmacy items must use their own validated RPCs.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object'
       OR COALESCE(v_item->>'item_type','') NOT IN ('procedure','other') THEN
      RAISE EXCEPTION 'manual billing supports procedure and other item types only';
    END IF;
  END LOOP;

  IF p_visit_id IS NULL THEN
    IF NOT p_separate_invoice THEN
      RAISE EXCEPTION 'standalone invoices must be explicitly selected';
    END IF;
    v_invoice_id := public.create_invoice_atomic(
      p_patient_id,p_partner_id,p_invoice_date,p_discount,p_items
    );
    UPDATE public.invoices
       SET is_primary = false, updated_by = v_uid, updated_at = pg_catalog.now()
     WHERE id = v_invoice_id;
    RETURN v_invoice_id;
  END IF;

  SELECT v.patient_id INTO v_visit_patient_id
    FROM public.visits AS v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
  IF v_visit_patient_id IS DISTINCT FROM p_patient_id THEN
    RAISE EXCEPTION 'selected visit does not belong to the selected patient';
  END IF;

  IF p_partner_id IS NOT NULL THEN
    PERFORM 1 FROM public.partners AS p
     WHERE p.id = p_partner_id AND p.deleted_at IS NULL AND p.active IS TRUE
     FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'active partner not found'; END IF;
  END IF;

  v_invoice_id := private.create_or_append_visit_invoice_atomic(
    p_visit_id,p_invoice_date,p_discount,p_items,p_separate_invoice
  );

  IF p_partner_id IS NOT NULL THEN
    SELECT i.partner_id INTO v_existing_partner
      FROM public.invoices AS i
     WHERE i.id = v_invoice_id AND i.deleted_at IS NULL
     FOR UPDATE;
    IF NOT FOUND THEN RAISE EXCEPTION 'invoice not found after creation'; END IF;
    IF v_existing_partner IS NOT NULL AND v_existing_partner IS DISTINCT FROM p_partner_id THEN
      RAISE EXCEPTION 'invoice partner mismatch; refusing to mix billing partners';
    END IF;
    UPDATE public.invoices
       SET partner_id = p_partner_id,
           updated_by = v_uid,
           updated_at = pg_catalog.now()
     WHERE id = v_invoice_id;
  END IF;

  RETURN v_invoice_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_billing_invoice_atomic(p_patient_id uuid, p_visit_id uuid, p_partner_id uuid, p_invoice_date date, p_discount numeric, p_items jsonb, p_separate_invoice boolean, p_request_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_uid uuid := public.current_app_user_id();
 v_payload jsonb;
 v_operation text := 'create_billing_invoice_atomic';
 v_old_operation text; v_old_actor uuid; v_old_payload jsonb; v_result uuid;
BEGIN
 IF v_uid IS NULL OR NOT public.app_has_perm('billing.create') THEN
  RAISE EXCEPTION 'billing permission denied' USING ERRCODE = '42501';
 END IF;
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'idempotency request id is required'; END IF;
 v_payload := pg_catalog.jsonb_build_object('patient_id',p_patient_id,'visit_id',p_visit_id,
  'partner_id',p_partner_id,'invoice_date',p_invoice_date,'discount',p_discount,
  'items',p_items,'separate_invoice',p_separate_invoice);
 INSERT INTO private.billing_rpc_idempotency(request_id,operation,actor_id,request_payload)
 VALUES(p_request_id,v_operation,v_uid,v_payload) ON CONFLICT(request_id) DO NOTHING;
 SELECT operation,actor_id,request_payload,result_id
 INTO v_old_operation,v_old_actor,v_old_payload,v_result
 FROM private.billing_rpc_idempotency WHERE request_id=p_request_id FOR UPDATE;
 IF v_old_operation IS DISTINCT FROM v_operation OR v_old_actor IS DISTINCT FROM v_uid OR v_old_payload IS DISTINCT FROM v_payload THEN
  RAISE EXCEPTION 'idempotency key reused with different request';
 END IF;
 IF v_result IS NOT NULL THEN RETURN v_result; END IF;
 v_result := public.create_billing_invoice_atomic(p_patient_id,p_visit_id,p_partner_id,p_invoice_date,p_discount,p_items,p_separate_invoice);
 UPDATE private.billing_rpc_idempotency SET result_id=v_result WHERE request_id=p_request_id;
 RETURN v_result;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_insurance_claim(_patient_insurance_id uuid, _invoice_id uuid, _items jsonb, _notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  claim_id uuid;
  uid uuid;
  total numeric := 0;
  item jsonb;
  pi_patient_id uuid;
  invoice_patient_id uuid;
  invoice_branch uuid;
  invoice_visit_id uuid;
  visit_patient_id uuid;
  visit_branch uuid;
  user_branch uuid;
  item_gross numeric;
  item_covered numeric;
  item_patient numeric;
  item_service_type text;
  item_description text;
BEGIN
  IF NOT public.app_has_perm('insurance.create') THEN
    RAISE EXCEPTION 'not authorised to create insurance claims';
  END IF;

  IF _items IS NULL OR jsonb_typeof(_items) <> 'array' THEN
    RAISE EXCEPTION 'claim items must be a JSON array';
  END IF;

  IF jsonb_array_length(_items) = 0 THEN
    RAISE EXCEPTION 'a claim needs at least one item';
  END IF;

  uid := public.current_app_user_id();

  SELECT pi.patient_id INTO pi_patient_id
  FROM public.patient_insurance pi
  JOIN public.insurance_plans p
    ON p.id = pi.plan_id
   AND p.company_id = pi.company_id
   AND p.active IS TRUE
   AND p.deleted_at IS NULL
  JOIN public.insurance_companies c
    ON c.id = pi.company_id
   AND c.active IS TRUE
   AND c.deleted_at IS NULL
  WHERE pi.id = _patient_insurance_id
    AND pi.deleted_at IS NULL
    AND pi.status = 'active'
    AND pi.start_date <= CURRENT_DATE
    AND (pi.expiry_date IS NULL OR pi.expiry_date >= CURRENT_DATE);

  IF pi_patient_id IS NULL THEN
    RAISE EXCEPTION 'active patient insurance not found';
  END IF;

  SELECT patient_id, branch_id, visit_id
    INTO invoice_patient_id, invoice_branch, invoice_visit_id
  FROM public.invoices
  WHERE id = _invoice_id AND deleted_at IS NULL;

  IF invoice_patient_id IS NULL THEN
    RAISE EXCEPTION 'invoice not found';
  END IF;

  IF pi_patient_id <> invoice_patient_id THEN
    RAISE EXCEPTION 'patient insurance does not belong to invoice patient';
  END IF;

  -- A visit-linked invoice must agree with its visit on both patient and branch.
  -- Otherwise an invoice can be crafted with a legitimate patient/branch but a
  -- different visit, bypassing the intended clinical/financial linkage.
  IF invoice_visit_id IS NOT NULL THEN
    SELECT v.patient_id, v.branch_id
      INTO visit_patient_id, visit_branch
      FROM public.visits v
     WHERE v.id = invoice_visit_id
       AND v.deleted_at IS NULL;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'invoice visit not found';
    END IF;

    IF visit_patient_id IS DISTINCT FROM invoice_patient_id THEN
      RAISE EXCEPTION 'invoice visit patient does not match invoice patient';
    END IF;

    IF visit_branch IS DISTINCT FROM invoice_branch THEN
      RAISE EXCEPTION 'invoice visit branch does not match invoice branch';
    END IF;
  END IF;

  SELECT branch_id INTO user_branch
  FROM public.users
  WHERE id = uid;

  IF NOT public.is_super_admin()
     AND (user_branch IS NULL OR invoice_branch IS DISTINCT FROM user_branch) THEN
    RAISE EXCEPTION 'cross-branch insurance claim access denied';
  END IF;

  -- Validate every item before inserting the parent claim. The function call is
  -- atomic, but validating first makes the intended financial invariant explicit.
  FOR item IN SELECT value FROM jsonb_array_elements(_items) AS x(value)
  LOOP
    IF jsonb_typeof(item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'each claim item must be a JSON object';
    END IF;

    IF jsonb_typeof(item->'gross_amount') IS DISTINCT FROM 'number'
       OR jsonb_typeof(item->'covered_amount') IS DISTINCT FROM 'number'
       OR jsonb_typeof(item->'patient_amount') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'claim item amounts must be JSON numbers';
    END IF;

    item_service_type := item->>'service_type';
    item_description := btrim(COALESCE(item->>'description', ''));

    IF item_service_type IS NULL
       OR item_service_type NOT IN ('consultation', 'lab', 'medicine') THEN
      RAISE EXCEPTION 'unsupported insurance claim service type';
    END IF;

    IF item_description = '' THEN
      RAISE EXCEPTION 'claim item description is required';
    END IF;

    BEGIN
      item_gross := (item->>'gross_amount')::numeric;
      item_covered := (item->>'covered_amount')::numeric;
      item_patient := (item->>'patient_amount')::numeric;
    EXCEPTION WHEN invalid_text_representation OR numeric_value_out_of_range THEN
      RAISE EXCEPTION 'invalid claim item amount';
    END;

    -- Reject special numeric values and precision that would be silently
    -- rounded when persisted as monetary amounts.
    IF item_gross::text IN ('NaN', 'Infinity', '-Infinity')
       OR item_covered::text IN ('NaN', 'Infinity', '-Infinity')
       OR item_patient::text IN ('NaN', 'Infinity', '-Infinity') THEN
      RAISE EXCEPTION 'claim item amounts must be finite';
    END IF;

    IF item_gross <= 0 OR item_covered < 0 OR item_patient < 0 THEN
      RAISE EXCEPTION 'claim gross amount must be positive and split amounts non-negative';
    END IF;

    IF item_gross <> round(item_gross, 2)
       OR item_covered <> round(item_covered, 2)
       OR item_patient <> round(item_patient, 2) THEN
      RAISE EXCEPTION 'claim item amounts must have at most two decimal places';
    END IF;

    IF item_covered > item_gross OR item_patient > item_gross THEN
      RAISE EXCEPTION 'claim covered and patient amounts cannot exceed gross amount';
    END IF;

    IF item_covered + item_patient <> item_gross THEN
      RAISE EXCEPTION 'claim item covered and patient amounts must equal gross amount';
    END IF;

    total := total + item_gross;
  END LOOP;

  INSERT INTO public.insurance_claims (
    patient_insurance_id, invoice_id, status, submitted_amount, notes, created_by
  )
  VALUES (_patient_insurance_id, _invoice_id, 'draft', total, _notes, uid)
  RETURNING id INTO claim_id;

  FOR item IN SELECT value FROM jsonb_array_elements(_items) AS x(value)
  LOOP
    INSERT INTO public.insurance_claim_items (
      claim_id, service_type, reference_id, description,
      gross_amount, covered_amount, patient_amount, coverage_rule_id
    )
    VALUES (
      claim_id,
      item->>'service_type',
      NULLIF(item->>'reference_id', '')::uuid,
      btrim(COALESCE(item->>'description', '')),
      (item->>'gross_amount')::numeric,
      (item->>'covered_amount')::numeric,
      (item->>'patient_amount')::numeric,
      NULLIF(item->>'coverage_rule_id', '')::uuid
    );
  END LOOP;

  RETURN claim_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_invoice_atomic(p_patient_id uuid, p_partner_id uuid, p_invoice_date date, p_discount numeric, p_items jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_user_branch uuid;
  v_patient_branch uuid;
  v_invoice_id uuid;
  v_invoice_number text;
  v_item jsonb;
  v_item_name text;
  v_item_type text;
  v_quantity numeric;
  v_unit_price numeric;
  v_line_total numeric;
  v_subtotal numeric := 0;
  v_net numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required' USING ERRCODE = '42501';
  END IF;
  IF NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'not authorised to create invoices' USING ERRCODE = '42501';
  END IF;
  IF p_patient_id IS NULL OR p_invoice_date IS NULL THEN
    RAISE EXCEPTION 'patient and invoice date are required';
  END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'invoice items must be a JSON array';
  END IF;
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'invoice must contain at least one item';
  END IF;
  IF p_discount IS NULL OR p_discount::text IN ('NaN','Infinity','-Infinity')
     OR p_discount < 0 OR p_discount <> round(p_discount, 2) THEN
    RAISE EXCEPTION 'discount must be finite, non-negative, and have at most two decimal places';
  END IF;

  SELECT u.branch_id INTO v_user_branch
    FROM public.users u
   WHERE u.id = v_uid AND u.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active application user not found' USING ERRCODE = '42501';
  END IF;

  SELECT p.branch_id INTO v_patient_branch
    FROM public.patients p
   WHERE p.id = p_patient_id AND p.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active patient not found';
  END IF;
  IF NOT public.is_super_admin()
     AND (v_user_branch IS NULL OR v_patient_branch IS DISTINCT FROM v_user_branch) THEN
    RAISE EXCEPTION 'cross-branch invoice access denied' USING ERRCODE = '42501';
  END IF;

  IF p_partner_id IS NOT NULL THEN
    PERFORM 1 FROM public.partners p
     WHERE p.id = p_partner_id AND p.deleted_at IS NULL AND p.active IS TRUE
     FOR SHARE;
    IF NOT FOUND THEN RAISE EXCEPTION 'active partner not found'; END IF;
  END IF;

  -- Validate all line items and calculate totals before creating the header.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'each invoice item must be an object';
    END IF;
    v_item_name := btrim(COALESCE(v_item->>'item_name',''));
    v_item_type := v_item->>'item_type';
    IF v_item_name = '' THEN RAISE EXCEPTION 'invoice item description is required'; END IF;
    IF v_item_type IS NULL OR v_item_type NOT IN ('consultation','lab','pharmacy','procedure','other') THEN
      RAISE EXCEPTION 'unsupported invoice item type';
    END IF;
    IF jsonb_typeof(v_item->'quantity') IS DISTINCT FROM 'number'
       OR jsonb_typeof(v_item->'unit_price') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'invoice quantity and unit price must be JSON numbers';
    END IF;

    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_price := (v_item->>'unit_price')::numeric;
    IF v_quantity::text IN ('NaN','Infinity','-Infinity')
       OR v_quantity <= 0 OR v_quantity <> trunc(v_quantity) THEN
      RAISE EXCEPTION 'invoice quantity must be a finite positive whole number';
    END IF;
    IF v_unit_price::text IN ('NaN','Infinity','-Infinity')
       OR v_unit_price < 0 OR v_unit_price <> round(v_unit_price, 2) THEN
      RAISE EXCEPTION 'unit price must be finite, non-negative, and have at most two decimal places';
    END IF;
    v_line_total := round(v_quantity * v_unit_price, 2);
    IF v_line_total::text IN ('NaN','Infinity','-Infinity') THEN
      RAISE EXCEPTION 'invoice line total is outside the supported numeric range';
    END IF;
    v_subtotal := v_subtotal + v_line_total;
  END LOOP;

  IF v_subtotal::text IN ('NaN','Infinity','-Infinity') OR p_discount > v_subtotal THEN
    RAISE EXCEPTION 'discount cannot exceed invoice subtotal';
  END IF;
  v_net := round(v_subtotal - p_discount, 2);

  v_invoice_number := public.next_invoice_number();
  INSERT INTO public.invoices (
    invoice_number, patient_id, partner_id, invoice_date, total_amount,
    subtotal, discount_amount, net_amount, paid_amount, status,
    payment_status, branch_id, created_by, updated_by
  )
  VALUES (
    v_invoice_number, p_patient_id, p_partner_id, p_invoice_date, v_subtotal,
    v_subtotal, p_discount, v_net, 0, 'unpaid',
    'unpaid', v_patient_branch, v_uid, v_uid
  )
  RETURNING id INTO v_invoice_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    v_item_name := btrim(v_item->>'item_name');
    v_item_type := v_item->>'item_type';
    v_quantity := (v_item->>'quantity')::numeric;
    v_unit_price := (v_item->>'unit_price')::numeric;
    v_line_total := round(v_quantity * v_unit_price, 2);
    INSERT INTO public.invoice_items (
      invoice_id, item_name, item_type, quantity, unit_price, total_price, created_by, updated_by
    )
    VALUES (
      v_invoice_id, v_item_name, v_item_type, v_quantity, v_unit_price, v_line_total, v_uid, v_uid
    );
  END LOOP;

  RETURN v_invoice_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_lab_order_with_invoice_atomic(p_visit_id uuid, p_priority text, p_notes text, p_test_ids uuid[], p_separate_invoice boolean)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_patient_id uuid;
  v_patient_branch uuid;
  v_order_id uuid;
  v_count integer;
  v_invoice_items jsonb;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('lab.create') THEN
    RAISE EXCEPTION 'laboratory order permission denied' USING ERRCODE = '42501';
  END IF;
  IF p_priority IS NULL OR p_priority NOT IN ('normal','urgent','stat') THEN RAISE EXCEPTION 'invalid laboratory priority'; END IF;
  IF p_test_ids IS NULL OR cardinality(p_test_ids) = 0 THEN
    RAISE EXCEPTION 'at least one laboratory test is required';
  END IF;
  IF cardinality(p_test_ids) <> (SELECT count(DISTINCT test_id) FROM unnest(p_test_ids) AS ids(test_id)) THEN
    RAISE EXCEPTION 'duplicate laboratory test ids are not allowed';
  END IF;
  SELECT v.patient_id INTO v_patient_id
    FROM public.visits AS v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
  SELECT p.branch_id INTO v_patient_branch
    FROM public.patients AS p
   WHERE p.id = v_patient_id AND p.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active patient not found'; END IF;
  IF NOT public.is_super_admin() AND NOT EXISTS (
    SELECT 1 FROM public.users AS u
     WHERE u.id = v_uid AND u.deleted_at IS NULL
       AND u.branch_id IS NOT DISTINCT FROM v_patient_branch
  ) THEN
    RAISE EXCEPTION 'cross-branch laboratory order denied' USING ERRCODE = '42501';
  END IF;

  SELECT count(*) INTO v_count
    FROM public.lab_tests AS t
   WHERE t.id = ANY(p_test_ids) AND t.active IS TRUE AND t.deleted_at IS NULL;
  IF v_count <> cardinality(p_test_ids) THEN
    RAISE EXCEPTION 'one or more laboratory tests are inactive or missing';
  END IF;

  INSERT INTO public.lab_orders (
    patient_id, visit_id, ordered_by, status, priority, notes, created_by, branch_id
  ) VALUES (
    v_patient_id, p_visit_id, v_uid, 'ordered', p_priority, NULLIF(btrim(p_notes),''), v_uid, v_patient_branch
  ) RETURNING id INTO v_order_id;

  INSERT INTO public.lab_order_items (order_id, test_id, price, created_by)
  SELECT v_order_id, t.id, t.price, v_uid
    FROM unnest(p_test_ids) WITH ORDINALITY AS x(test_id, ordinality)
    JOIN public.lab_tests AS t ON t.id = x.test_id
   ORDER BY x.ordinality;

  SELECT jsonb_agg(jsonb_build_object(
    'item_name', t.name, 'item_type', 'lab', 'quantity', 1,
    'unit_price', t.price, 'item_id', t.id
  ) ORDER BY x.ordinality)
    INTO v_invoice_items
    FROM unnest(p_test_ids) WITH ORDINALITY AS x(test_id, ordinality)
    JOIN public.lab_tests AS t ON t.id = x.test_id;

  PERFORM private.create_or_append_visit_invoice_atomic(
    p_visit_id, CURRENT_DATE, 0, v_invoice_items, p_separate_invoice
  );
  RETURN v_order_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_lab_order_with_invoice_atomic(p_visit_id uuid, p_priority text, p_notes text, p_test_ids uuid[], p_separate_invoice boolean, p_request_id uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
 v_uid uuid := public.current_app_user_id(); v_payload jsonb;
 v_operation text := 'create_lab_order_with_invoice_atomic';
 v_old_operation text; v_old_actor uuid; v_old_payload jsonb; v_result uuid;
BEGIN
 IF v_uid IS NULL OR NOT public.app_has_perm('lab.create') THEN RAISE EXCEPTION 'laboratory order permission denied' USING ERRCODE = '42501'; END IF;
 IF p_request_id IS NULL THEN RAISE EXCEPTION 'idempotency request id is required'; END IF;
 v_payload := pg_catalog.jsonb_build_object('visit_id',p_visit_id,'priority',p_priority,'notes',p_notes,'test_ids',pg_catalog.to_jsonb(p_test_ids),'separate_invoice',p_separate_invoice);
 INSERT INTO private.billing_rpc_idempotency(request_id,operation,actor_id,request_payload) VALUES(p_request_id,v_operation,v_uid,v_payload) ON CONFLICT(request_id) DO NOTHING;
 SELECT operation,actor_id,request_payload,result_id INTO v_old_operation,v_old_actor,v_old_payload,v_result FROM private.billing_rpc_idempotency WHERE request_id=p_request_id FOR UPDATE;
 IF v_old_operation IS DISTINCT FROM v_operation OR v_old_actor IS DISTINCT FROM v_uid OR v_old_payload IS DISTINCT FROM v_payload THEN RAISE EXCEPTION 'idempotency key reused with different request'; END IF;
 IF v_result IS NOT NULL THEN RETURN v_result; END IF;
 v_result := public.create_lab_order_with_invoice_atomic(p_visit_id,p_priority,p_notes,p_test_ids,p_separate_invoice);
 UPDATE private.billing_rpc_idempotency SET result_id=v_result WHERE request_id=p_request_id;
 RETURN v_result;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_medical_certificate(p_patient_id uuid, p_diagnosis text, p_start_date date, p_end_date date)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
BEGIN
  RAISE EXCEPTION 'certificate issuance requires a linked visit; refresh the application'
    USING ERRCODE = '55000';
END;
$function$

CREATE OR REPLACE FUNCTION public.create_medical_certificate(p_patient_id uuid, p_diagnosis text, p_start_date date, p_end_date date, p_visit_id uuid)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_user_id uuid; v_certificate_id integer; v_visit_patient_id uuid; v_visit_status text; v_visit_branch_id uuid; v_patient_branch_id uuid;
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
  SELECT p.branch_id INTO v_patient_branch_id
  FROM public.patients AS p
  WHERE p.id=p_patient_id AND p.deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active patient not found' USING ERRCODE = 'P0002';
  END IF;
  SELECT v.patient_id, v.status, v.branch_id
  INTO v_visit_patient_id, v_visit_status, v_visit_branch_id
  FROM public.visits AS v WHERE v.id=p_visit_id AND v.deleted_at IS NULL;
  IF NOT FOUND OR v_visit_patient_id IS DISTINCT FROM p_patient_id THEN
    RAISE EXCEPTION 'visit does not belong to the selected patient' USING ERRCODE = '22023';
  END IF;
  IF v_visit_status = 'cancelled' THEN
    RAISE EXCEPTION 'cancelled visit cannot be used for a medical certificate' USING ERRCODE = '22023';
  END IF;
  IF v_visit_branch_id IS DISTINCT FROM v_patient_branch_id THEN
    RAISE EXCEPTION 'visit and patient branch mismatch' USING ERRCODE = '42501';
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
$function$

CREATE OR REPLACE FUNCTION public.create_patient_atomic(_full_name text, _gender text, _date_of_birth date, _phone text, _national_id text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  uid uuid;
  bid uuid;
  next_no bigint;
  patient_id uuid;
  new_mrn text;
BEGIN
  IF NOT public.app_has_perm('patients.create') THEN
    RAISE EXCEPTION 'not authorised to register patients'
      USING ERRCODE = '42501';
  END IF;

  uid := public.current_app_user_id();
  IF uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required'
      USING ERRCODE = '42501';
  END IF;

  SELECT u.branch_id
    INTO bid
    FROM public.users AS u
   WHERE u.id = uid
     AND COALESCE(u.active, true) IS TRUE
     AND u.deleted_at IS NULL;

  IF bid IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured; patient registration requires a branch context'
      USING ERRCODE = '42501';
  END IF;

  IF NULLIF(BTRIM(COALESCE(_full_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'patient full name is required'
      USING ERRCODE = '22023';
  END IF;

  IF NULLIF(BTRIM(COALESCE(_gender, '')), '') IS NULL THEN
    RAISE EXCEPTION 'patient gender is required'
      USING ERRCODE = '22023';
  END IF;

  -- Use the same transaction-scoped lock key as the hardened next_mrn() RPC,
  -- but keep the lock until the patient row is inserted and the transaction ends.
  PERFORM pg_advisory_xact_lock(hashtext('roshan:mrn'));

  SELECT COALESCE(
           MAX(NULLIF(regexp_replace(p.mrn, '[^0-9]', '', 'g'), '')::bigint),
           0
         ) + 1
    INTO next_no
    FROM public.patients AS p
   WHERE p.mrn ~ '^RMC[0-9]+$';

  new_mrn := 'RMC' || lpad(next_no::text, 6, '0');

  INSERT INTO public.patients (
    branch_id, mrn, full_name, gender, date_of_birth, phone, national_id,
    created_by, registered_by, updated_by
  )
  VALUES (
    bid, new_mrn, BTRIM(_full_name), BTRIM(_gender), _date_of_birth,
    NULLIF(BTRIM(COALESCE(_phone, '')), ''),
    NULLIF(BTRIM(COALESCE(_national_id, '')), ''),
    uid, uid, uid
  )
  RETURNING id INTO patient_id;

  RETURN patient_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_prescription_atomic(p_visit_id uuid, p_is_external boolean, p_items jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_branch uuid;
  v_visit_patient uuid;
  v_visit_branch uuid;
  v_rx_id uuid;
  v_item jsonb;
  v_medicine_id uuid;
  v_medicine_name text;
  v_catalog_name text;
  v_generic_name text;
  v_unit_price numeric;
  v_quantity numeric;
  v_item_count integer := 0;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated application user is required' USING ERRCODE = '42501';
  END IF;

  IF NOT (public.app_has_perm('pharmacy.create') OR public.app_has_perm('emr.create')) THEN
    RAISE EXCEPTION 'not authorised to create prescriptions' USING ERRCODE = '42501';
  END IF;

  IF p_visit_id IS NULL OR p_items IS NULL OR jsonb_typeof(p_items) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'visit and prescription item array are required';
  END IF;
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'prescription must contain at least one item';
  END IF;

  SELECT v.patient_id, v.branch_id
    INTO v_visit_patient, v_visit_branch
    FROM public.visits v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL;
  IF v_visit_patient IS NULL THEN
    RAISE EXCEPTION 'active visit not found';
  END IF;

  SELECT u.branch_id INTO v_branch
    FROM public.users u
   WHERE u.id = v_uid AND u.deleted_at IS NULL;
  IF NOT public.is_super_admin()
     AND (v_branch IS NULL OR v_visit_branch IS DISTINCT FROM v_branch) THEN
    RAISE EXCEPTION 'cross-branch prescription access denied' USING ERRCODE = '42501';
  END IF;

  -- Validate all payloads before inserting the parent record.
  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    IF jsonb_typeof(v_item) IS DISTINCT FROM 'object' THEN
      RAISE EXCEPTION 'each prescription item must be an object';
    END IF;
    IF jsonb_typeof(v_item->'quantity') IS DISTINCT FROM 'number' THEN
      RAISE EXCEPTION 'prescription quantity must be a JSON number';
    END IF;
    v_quantity := (v_item->>'quantity')::numeric;
    IF v_quantity::text IN ('NaN', 'Infinity', '-Infinity') OR v_quantity <= 0 OR v_quantity <> trunc(v_quantity) THEN
      RAISE EXCEPTION 'prescription quantity must be a finite positive whole number';
    END IF;
    IF btrim(COALESCE(v_item->>'medication_name', '')) = '' THEN
      RAISE EXCEPTION 'medication name is required';
    END IF;

    v_medicine_id := NULLIF(v_item->>'medicine_id', '')::uuid;
    IF v_medicine_id IS NOT NULL THEN
      SELECT m.name, m.generic_name, COALESCE(m.selling_price, 0)
        INTO v_catalog_name, v_generic_name, v_unit_price
        FROM public.medicines m
       WHERE m.id = v_medicine_id
         AND m.deleted_at IS NULL
         AND m.active IS TRUE
         AND m.is_active IS TRUE
       FOR SHARE;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'active catalog medicine not found';
      END IF;
      IF v_unit_price::text IN ('NaN', 'Infinity', '-Infinity') OR v_unit_price < 0 THEN
        RAISE EXCEPTION 'catalog medicine price must be finite and non-negative';
      END IF;
      IF btrim(COALESCE(v_catalog_name, '')) = '' AND btrim(COALESCE(v_generic_name, '')) = '' THEN
        RAISE EXCEPTION 'catalog medicine has no usable name';
      END IF;
    END IF;
    v_item_count := v_item_count + 1;
  END LOOP;

  INSERT INTO public.prescriptions (
    patient_id, visit_id, prescribed_by, doctor_id, prescription_type,
    is_external, status, created_by
  )
  VALUES (
    v_visit_patient, p_visit_id, v_uid, v_uid,
    CASE WHEN p_is_external THEN 'external' ELSE 'internal' END,
    COALESCE(p_is_external, false), 'pending', v_uid
  )
  RETURNING id INTO v_rx_id;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items) AS x(value)
  LOOP
    v_medicine_id := NULLIF(v_item->>'medicine_id', '')::uuid;
    v_unit_price := 0;
    IF v_medicine_id IS NOT NULL THEN
      SELECT COALESCE(m.selling_price, 0), COALESCE(NULLIF(btrim(m.name), ''), NULLIF(btrim(m.generic_name), ''))
        INTO v_unit_price, v_medicine_name
        FROM public.medicines m
       WHERE m.id = v_medicine_id
         AND m.deleted_at IS NULL
         AND m.active IS TRUE
         AND m.is_active IS TRUE
       FOR SHARE;
    ELSE
      v_medicine_name := btrim(v_item->>'medication_name');
    END IF;

    INSERT INTO public.prescription_items (
      prescription_id, medicine_id, medication_name, dose, dosage, frequency,
      duration, quantity, instructions, dosage_form, route, unit_price, created_by, updated_by
    )
    VALUES (
      v_rx_id,
      v_medicine_id,
      v_medicine_name,
      NULLIF(btrim(COALESCE(v_item->>'dose', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'dose', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'frequency', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'duration', '')), ''),
      (v_item->>'quantity')::numeric,
      NULLIF(btrim(COALESCE(v_item->>'instructions', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'dosage_form', '')), ''),
      NULLIF(btrim(COALESCE(v_item->>'route', '')), ''),
      v_unit_price,
      v_uid,
      v_uid
    );
  END LOOP;

  RETURN v_rx_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.create_staff_user(_email text, _password text, _full_name text, _role_code text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_auth_id uuid;
  v_role_id uuid;
  v_user_id uuid;
begin
  select id into v_role_id
  from public.roles
  where code = _role_code
     or lower(name) = lower(_role_code)
     or lower(replace(name, ' ', '_')) = lower(_role_code)
  limit 1;

  if v_role_id is null then
    raise exception 'الدور % غير موجود في جدول الأدوار', _role_code;
  end if;

  select id into v_auth_id from auth.users where email = _email;

  if v_auth_id is null then
    v_auth_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at
    ) values (
      '00000000-0000-0000-0000-000000000000', v_auth_id, 'authenticated', 'authenticated',
      _email, crypt(_password, gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', _full_name),
      now(), now()
    );
  end if;

  insert into public.users (auth_user_id, full_name, email, role_id, active)
  values (v_auth_id, _full_name, _email, v_role_id, true)
  on conflict (auth_user_id) do update
  set role_id = v_role_id,
      active = true
  returning id into v_user_id;

  return v_user_id;
end $function$

CREATE OR REPLACE FUNCTION public.create_visit_consultation_invoice_atomic(p_visit_id uuid, p_invoice_date date)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_fee numeric;
BEGIN
  IF v_uid IS NULL OR NOT (
    public.app_has_perm('visits.create') OR public.app_has_perm('billing.create')
  ) THEN
    RAISE EXCEPTION 'consultation invoice permission denied' USING ERRCODE = '42501';
  END IF;
  IF p_visit_id IS NULL OR p_invoice_date IS NULL THEN
    RAISE EXCEPTION 'visit and invoice date are required';
  END IF;
  SELECT v.consultation_fee INTO v_fee
    FROM public.visits AS v
   WHERE v.id = p_visit_id AND v.deleted_at IS NULL
   FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
  IF v_fee IS NULL OR v_fee::text IN ('NaN','Infinity','-Infinity')
     OR v_fee < 0 OR v_fee <> round(v_fee, 2) THEN
    RAISE EXCEPTION 'visit consultation fee is invalid';
  END IF;
  IF v_fee = 0 THEN RAISE EXCEPTION 'consultation fee is zero'; END IF;

  RETURN private.create_or_append_visit_invoice_atomic(
    p_visit_id, p_invoice_date, 0,
    jsonb_build_array(jsonb_build_object(
      'item_name','Consultation','item_type','consultation','quantity',1,'unit_price',v_fee
    )),
    false
  );
END;
$function$

CREATE OR REPLACE FUNCTION public.current_app_user_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ SELECT private.current_app_user_id() $function$

CREATE OR REPLACE FUNCTION public.current_role_code()
 RETURNS text
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ SELECT private.current_role_code() $function$

CREATE OR REPLACE FUNCTION public.current_role_name()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
                        SELECT r.name 
                            FROM public.users u
                                JOIN public.roles r ON u.role_id = r.id
                                    WHERE u.auth_user_id = auth.uid()
                                        LIMIT 1;
                                        $function$

CREATE OR REPLACE FUNCTION public.enforce_public_system_setting_keys()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if new.is_public is null then
    new.is_public := false;
  end if;

  if new.is_public = true
     and new.setting_key not in (
       'center_name',
       'center_name_ar',
       'currency',
       'phone',
       'address',
       'invoice_footer',
       'receipt_footer',
       'tax_percent',
       'pharmacy_expiry_threshold_days'
     ) then
    raise exception 'Security violation: Setting key "%" is not allowed to be public.', new.setting_key
      using errcode = '42501';
  end if;

  return new;
end;
$function$

CREATE OR REPLACE FUNCTION public.fn_calculate_insurance_coverage(_patient_insurance_id uuid, _service_type text, _reference_id uuid, _generic_name text, _gross_amount numeric)
 RETURNS TABLE(covered_amount numeric, patient_amount numeric, requires_prior_auth boolean, excluded boolean, coverage_rule_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_plan_id uuid;
  v_policy_company_id uuid;
  v_patient_id uuid;
  v_policy_status text;
  v_policy_start date;
  v_policy_expiry date;
  v_patient_branch uuid;
  v_user_branch uuid;
  v_plan_company_id uuid;
  v_plan_default numeric := 0;
  v_plan_requires_prior_auth boolean := false;
  v_rule_id uuid;
  v_rule_percent numeric;
  v_rule_fixed numeric;
  v_rule_requires_prior_auth boolean;
  v_rule_excluded boolean;
  v_covered numeric := 0;
  v_requires_prior_auth boolean := false;
  v_excluded boolean := false;
BEGIN
  IF NOT COALESCE(private.app_has_perm('insurance.read'), false) THEN
    RAISE EXCEPTION 'Permission denied' USING ERRCODE = '42501';
  END IF;

  IF _gross_amount IS NULL
     OR _gross_amount::text IN ('NaN', 'Infinity', '-Infinity')
     OR _gross_amount < 0 THEN
    RAISE EXCEPTION 'gross amount must be finite and non-negative'
      USING ERRCODE = '22023';
  END IF;

  IF _service_type IS NULL
     OR _service_type NOT IN ('consultation', 'lab', 'medicine') THEN
    RAISE EXCEPTION 'unsupported insurance coverage service type'
      USING ERRCODE = '22023';
  END IF;

  IF _gross_amount <> round(_gross_amount, 2) THEN
    RAISE EXCEPTION 'gross amount must have at most two decimal places'
      USING ERRCODE = '22023';
  END IF;

  -- A policy is usable only during its validity window and while active.
  SELECT pi.plan_id, pi.company_id, pi.patient_id, pi.status, pi.start_date, pi.expiry_date
    INTO v_plan_id, v_policy_company_id, v_patient_id, v_policy_status, v_policy_start, v_policy_expiry
    FROM public.patient_insurance pi
   WHERE pi.id = _patient_insurance_id
     AND pi.deleted_at IS NULL;

  IF NOT FOUND THEN
    covered_amount := 0;
    patient_amount := _gross_amount;
    requires_prior_auth := false;
    excluded := false;
    coverage_rule_id := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  IF NOT COALESCE(private.is_super_admin(), false) THEN
    SELECT p.branch_id
      INTO v_patient_branch
      FROM public.patients p
     WHERE p.id = v_patient_id
       AND p.deleted_at IS NULL;

    SELECT u.branch_id
      INTO v_user_branch
      FROM public.users u
     WHERE u.auth_user_id = auth.uid()
       AND COALESCE(u.active, true) = true
       AND u.deleted_at IS NULL
     LIMIT 1;

    IF v_patient_branch IS NULL
       OR v_user_branch IS NULL
       OR v_patient_branch IS DISTINCT FROM v_user_branch THEN
      RAISE EXCEPTION 'cross-branch insurance coverage access denied'
        USING ERRCODE = '42501';
    END IF;
  END IF;

  IF v_policy_status IS DISTINCT FROM 'active'
     OR v_policy_start > CURRENT_DATE
     OR (v_policy_expiry IS NOT NULL AND v_policy_expiry < CURRENT_DATE) THEN
    covered_amount := 0;
    patient_amount := _gross_amount;
    requires_prior_auth := false;
    excluded := false;
    coverage_rule_id := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  -- Require the plan and company to be active, and require the selected plan
  -- to belong to the company recorded on this patient's policy.
  SELECT p.company_id, p.default_coverage_percent, p.requires_prior_auth
    INTO v_plan_company_id, v_plan_default, v_plan_requires_prior_auth
    FROM public.insurance_plans p
    JOIN public.insurance_companies c
      ON c.id = p.company_id
     AND c.active IS TRUE
     AND c.deleted_at IS NULL
   WHERE p.id = v_plan_id
     AND p.company_id = v_policy_company_id
     AND p.active IS TRUE
     AND p.deleted_at IS NULL;

  IF NOT FOUND OR v_plan_company_id IS DISTINCT FROM v_policy_company_id THEN
    covered_amount := 0;
    patient_amount := _gross_amount;
    requires_prior_auth := false;
    excluded := false;
    coverage_rule_id := NULL;
    RETURN NEXT;
    RETURN;
  END IF;

  -- 1) Most-specific service/reference rule.
  IF _reference_id IS NOT NULL THEN
    SELECT r.id, r.coverage_percent, r.fixed_amount,
           r.requires_prior_auth, r.excluded
      INTO v_rule_id, v_rule_percent, v_rule_fixed,
           v_rule_requires_prior_auth, v_rule_excluded
      FROM public.insurance_coverage_rules r
     WHERE r.plan_id = v_plan_id
       AND r.service_type = _service_type
       AND r.reference_id = _reference_id
       AND r.deleted_at IS NULL
     LIMIT 1;
  END IF;

  -- 2) Generic-name medicine rule.
  IF v_rule_id IS NULL
     AND _service_type = 'medicine'
     AND NULLIF(btrim(_generic_name), '') IS NOT NULL THEN
    SELECT r.id, r.coverage_percent, r.fixed_amount,
           r.requires_prior_auth, r.excluded
      INTO v_rule_id, v_rule_percent, v_rule_fixed,
           v_rule_requires_prior_auth, v_rule_excluded
      FROM public.insurance_coverage_rules r
     WHERE r.plan_id = v_plan_id
       AND r.service_type = 'medicine'
       AND r.generic_name IS NOT NULL
       AND lower(r.generic_name) = lower(btrim(_generic_name))
       AND r.reference_id IS NULL
       AND r.deleted_at IS NULL
     LIMIT 1;
  END IF;

  -- 3) Plan-wide default for the service type.
  IF v_rule_id IS NULL THEN
    SELECT r.id, r.coverage_percent, r.fixed_amount,
           r.requires_prior_auth, r.excluded
      INTO v_rule_id, v_rule_percent, v_rule_fixed,
           v_rule_requires_prior_auth, v_rule_excluded
      FROM public.insurance_coverage_rules r
     WHERE r.plan_id = v_plan_id
       AND r.service_type = _service_type
       AND r.reference_id IS NULL
       AND r.generic_name IS NULL
       AND r.deleted_at IS NULL
     LIMIT 1;
  END IF;

  IF v_rule_id IS NOT NULL THEN
    v_requires_prior_auth := COALESCE(v_rule_requires_prior_auth, false);
    IF COALESCE(v_rule_excluded, false) THEN
      v_excluded := true;
      v_covered := 0;
    ELSIF v_rule_fixed IS NOT NULL THEN
      IF v_rule_fixed::text IN ('NaN', 'Infinity', '-Infinity') OR v_rule_fixed < 0 THEN
        RAISE EXCEPTION 'fixed insurance coverage must be finite and non-negative';
      END IF;
      v_covered := LEAST(v_rule_fixed, _gross_amount);
    ELSE
      v_covered := ROUND(_gross_amount * COALESCE(v_rule_percent, 0) / 100, 2);
    END IF;
  ELSE
    v_requires_prior_auth := COALESCE(v_plan_requires_prior_auth, false);
    v_covered := ROUND(_gross_amount * COALESCE(v_plan_default, 0) / 100, 2);
  END IF;

  v_covered := GREATEST(0, LEAST(v_covered, _gross_amount));
  covered_amount := v_covered;
  patient_amount := _gross_amount - v_covered;
  requires_prior_auth := v_requires_prior_auth;
  excluded := v_excluded;
  coverage_rule_id := v_rule_id;
  RETURN NEXT;
END;
$function$

CREATE OR REPLACE FUNCTION public.fn_cashbox_immutable()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(current_setting('roshan.cashbox_write', true), '') = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  raise exception 'posted cashbox transactions cannot be % — use reverse_cashbox_entry() instead', lower(tg_op);
end $function$

CREATE OR REPLACE FUNCTION public.fn_dispense_prescription(p_prescription_id uuid)
 RETURNS TABLE(item_id uuid, medicine_id uuid, medicine_name text, batch_id uuid, batch_number text, expiry_date date, quantity_dispensed numeric, batch_quantity_remaining numeric, source text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_item record; v_batch record; v_needed numeric; v_take numeric; v_shortfall numeric; v_stock numeric;
  v_uid uuid := public.current_app_user_id(); v_branch uuid; v_prescription_branch uuid;
begin
  if not public.app_has_perm('pharmacy.update') then raise exception 'insufficient_permission' using errcode='42501'; end if;
  select u.branch_id into v_branch from public.users u where u.id=v_uid and u.deleted_at is null;
  if v_branch is null and not public.is_super_admin() then raise exception 'user branch is not configured'; end if;

  perform 1 from public.prescriptions p
  where p.id=p_prescription_id and p.deleted_at is null and p.status='pending'
  for update;
  if not found then raise exception 'prescription_not_pending'; end if;

  select v.branch_id into v_prescription_branch
  from public.prescriptions p join public.visits v on v.id=p.visit_id
  where p.id=p_prescription_id;
  if not public.is_super_admin() and v_prescription_branch is distinct from v_branch then raise exception 'cross_branch_access_denied'; end if;

  for v_item in
    select pi.id, pi.medicine_id, coalesce(pi.quantity,1) as qty, m.name
    from public.prescription_items pi join public.medicines m on m.id=pi.medicine_id
    where pi.prescription_id=p_prescription_id and pi.deleted_at is null and pi.medicine_id is not null
    order by pi.id
  loop
    v_needed := v_item.qty;
    for v_batch in
      select inv.id, inv.batch_number, inv.expiry_date, inv.quantity_remaining
      from public.pharmacy_inventory inv
      where inv.medicine_id=v_item.medicine_id and inv.quantity_remaining>0 and inv.deleted_at is null
        and (inv.expiry_date is null or inv.expiry_date>=current_date)
        and (public.is_super_admin() or inv.branch_id=v_branch)
      order by inv.expiry_date asc nulls last, inv.created_at asc
      for update
    loop
      exit when v_needed<=0;
      v_take := least(v_needed, v_batch.quantity_remaining);
      update public.pharmacy_inventory inv
      set quantity_remaining=inv.quantity_remaining-v_take, quantity=inv.quantity_remaining-v_take,
          updated_at=now(), updated_by=v_uid where inv.id=v_batch.id;
      insert into public.stock_movements (medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by)
      values (v_item.medicine_id,v_batch.id,'dispense',-v_take,p_prescription_id,'prescriptions',coalesce(v_prescription_branch,v_branch),v_uid);
      item_id:=v_item.id; medicine_id:=v_item.medicine_id; medicine_name:=v_item.name; batch_id:=v_batch.id;
      batch_number:=v_batch.batch_number; expiry_date:=v_batch.expiry_date; quantity_dispensed:=v_take;
      batch_quantity_remaining:=v_batch.quantity_remaining-v_take; source:='batch'; return next;
      v_needed := v_needed-v_take;
    end loop;

    v_shortfall := greatest(v_needed,0);
    if v_shortfall>0 then
      select m.stock_quantity into v_stock from public.medicines m where m.id=v_item.medicine_id and m.deleted_at is null for update;
      if coalesce(v_stock,0)<v_shortfall then raise exception 'insufficient_stock: %',v_item.name; end if;
      insert into public.stock_movements (medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by)
      values (v_item.medicine_id,null,'dispense',-v_shortfall,p_prescription_id,'prescriptions',coalesce(v_prescription_branch,v_branch),v_uid);
      item_id:=v_item.id; medicine_id:=v_item.medicine_id; medicine_name:=v_item.name; batch_id:=null;
      batch_number:=null; expiry_date:=null; quantity_dispensed:=v_shortfall; batch_quantity_remaining:=null; source:='legacy'; return next;
    end if;

    update public.medicines m set stock_quantity=m.stock_quantity-v_item.qty::integer, updated_at=now(), updated_by=v_uid
    where m.id=v_item.medicine_id;
    update public.prescription_items pi set is_dispensed=true, dispensed_quantity=v_item.qty, updated_at=now(), updated_by=v_uid
    where pi.id=v_item.id;
  end loop;
  update public.prescriptions p set status='dispensed', dispensed_by=v_uid, dispensed_at=now(), updated_at=now(), updated_by=v_uid
  where p.id=p_prescription_id;
  return;
end;
$function$

CREATE OR REPLACE FUNCTION public.fn_dispense_prescription_with_invoice(p_prescription_id uuid, p_separate_invoice boolean)
 RETURNS TABLE(item_id uuid, medicine_id uuid, medicine_name text, batch_id uuid, batch_number text, expiry_date date, quantity_dispensed numeric, batch_quantity_remaining numeric, source text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_item record;
  v_batch record;
  v_needed numeric;
  v_take numeric;
  v_shortfall numeric;
  v_stock numeric;
  v_uid uuid := public.current_app_user_id();
  v_branch uuid;
  v_patient_id uuid;
  v_patient_branch uuid;
  v_visit_id uuid;
  v_visit_branch uuid;
  v_status text;
  v_invoice_items jsonb := '[]'::jsonb;
  v_item_count integer := 0;
BEGIN
  IF v_uid IS NULL OR NOT public.app_has_perm('pharmacy.update') THEN
    RAISE EXCEPTION 'insufficient_permission' USING ERRCODE = '42501';
  END IF;
  IF NOT public.app_has_perm('billing.create') THEN
    RAISE EXCEPTION 'pharmacy billing permission denied' USING ERRCODE = '42501';
  END IF;
  IF p_prescription_id IS NULL OR p_separate_invoice IS NULL THEN
    RAISE EXCEPTION 'prescription and explicit invoice choice are required';
  END IF;

  SELECT u.branch_id INTO v_branch
    FROM public.users AS u
   WHERE u.id = v_uid AND u.deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active application user not found' USING ERRCODE = '42501';
  END IF;
  IF v_branch IS NULL AND NOT public.is_super_admin() THEN
    RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501';
  END IF;

  SELECT p.patient_id, p.visit_id, p.status
    INTO v_patient_id, v_visit_id, v_status
    FROM public.prescriptions AS p
   WHERE p.id = p_prescription_id AND p.deleted_at IS NULL
   FOR UPDATE;
  IF NOT FOUND OR v_status IS DISTINCT FROM 'pending' THEN
    RAISE EXCEPTION 'prescription_not_pending';
  END IF;

  SELECT p.branch_id INTO v_patient_branch
    FROM public.patients AS p
   WHERE p.id = v_patient_id AND p.deleted_at IS NULL;
  IF NOT FOUND THEN RAISE EXCEPTION 'active patient not found'; END IF;

  IF v_visit_id IS NOT NULL THEN
    SELECT v.branch_id INTO v_visit_branch
      FROM public.visits AS v
     WHERE v.id = v_visit_id AND v.patient_id = v_patient_id AND v.deleted_at IS NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'active visit not found'; END IF;
  END IF;

  IF NOT public.is_super_admin()
     AND (v_branch IS NULL
       OR v_patient_branch IS DISTINCT FROM v_branch
       OR v_visit_branch IS DISTINCT FROM v_branch) THEN
    RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501';
  END IF;

  IF EXISTS (
    SELECT 1
      FROM public.prescription_items AS pi
      LEFT JOIN public.medicines AS m ON m.id = pi.medicine_id
     WHERE pi.prescription_id = p_prescription_id
       AND pi.deleted_at IS NULL
       AND pi.medicine_id IS NOT NULL
       AND (m.id IS NULL OR m.deleted_at IS NOT NULL
         OR COALESCE(m.active,true) IS NOT TRUE
         OR COALESCE(m.is_active,true) IS NOT TRUE)
  ) THEN
    RAISE EXCEPTION 'prescription contains an inactive or missing catalog medicine';
  END IF;

  -- Build invoice lines from the active medicine catalog before any stock mutation.
  -- Only catalog-linked items that will actually be dispensed can be billed.
  FOR v_item IN
    SELECT pi.id, pi.medicine_id, COALESCE(pi.quantity,1) AS qty,
           COALESCE(NULLIF(btrim(m.name),''),NULLIF(btrim(m.brand_name),''),NULLIF(btrim(m.generic_name),'')) AS name,
           m.selling_price, m.stock_quantity
      FROM public.prescription_items AS pi
      JOIN public.medicines AS m ON m.id = pi.medicine_id
     WHERE pi.prescription_id = p_prescription_id
       AND pi.deleted_at IS NULL
       AND pi.medicine_id IS NOT NULL
       AND m.deleted_at IS NULL
       AND COALESCE(m.active,true) IS TRUE
       AND COALESCE(m.is_active,true) IS TRUE
     ORDER BY pi.id
     FOR UPDATE OF pi, m
  LOOP
    IF v_item.qty::text IN ('NaN','Infinity','-Infinity')
       OR v_item.qty <= 0 OR v_item.qty <> trunc(v_item.qty)
       OR v_item.qty > 2147483647 THEN
      RAISE EXCEPTION 'prescription quantity must be a finite positive whole number';
    END IF;
    IF v_item.name IS NULL THEN RAISE EXCEPTION 'medicine catalog name is required'; END IF;
    IF COALESCE(v_item.stock_quantity,0) < v_item.qty THEN
      RAISE EXCEPTION 'medicine aggregate stock is insufficient or inconsistent';
    END IF;
    IF v_item.selling_price IS NULL
       OR v_item.selling_price::text IN ('NaN','Infinity','-Infinity')
       OR v_item.selling_price < 0
       OR v_item.selling_price <> round(v_item.selling_price,2) THEN
      RAISE EXCEPTION 'medicine selling price must be configured with at most two decimal places';
    END IF;
    v_invoice_items := v_invoice_items || jsonb_build_array(jsonb_build_object(
      'item_name',v_item.name,
      'item_type','pharmacy',
      'quantity',v_item.qty,
      'unit_price',v_item.selling_price,
      'item_id',v_item.medicine_id
    ));
    v_item_count := v_item_count + 1;
  END LOOP;

  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'prescription has no active catalog-linked medicines to dispense';
  END IF;

  -- Aggregate duplicate prescription lines by medicine before changing any stock.
  -- A per-line check alone could allow two individually valid lines to drive the
  -- shared medicine stock_quantity below zero.
  IF EXISTS (
    SELECT 1
      FROM (
        SELECT pi.medicine_id, SUM(COALESCE(pi.quantity,1)) AS required_qty
          FROM public.prescription_items AS pi
         WHERE pi.prescription_id = p_prescription_id
           AND pi.deleted_at IS NULL
           AND pi.medicine_id IS NOT NULL
         GROUP BY pi.medicine_id
      ) AS required
      JOIN public.medicines AS m ON m.id = required.medicine_id
     WHERE required.required_qty > m.stock_quantity
  ) THEN
    RAISE EXCEPTION 'medicine aggregate stock is insufficient or inconsistent';
  END IF;

  -- Consume only branch-assigned, unexpired batches in FEFO order. The legacy
  -- medicine stock balance has no branch owner and must never be used as fallback.
  FOR v_item IN
    SELECT pi.id, pi.medicine_id, COALESCE(pi.quantity,1) AS qty,
           COALESCE(NULLIF(btrim(m.name),''),NULLIF(btrim(m.brand_name),''),NULLIF(btrim(m.generic_name),'')) AS name
      FROM public.prescription_items AS pi
      JOIN public.medicines AS m ON m.id = pi.medicine_id
     WHERE pi.prescription_id = p_prescription_id
       AND pi.deleted_at IS NULL
       AND pi.medicine_id IS NOT NULL
       AND m.deleted_at IS NULL
       AND COALESCE(m.active,true) IS TRUE
       AND COALESCE(m.is_active,true) IS TRUE
     ORDER BY pi.id
     FOR UPDATE OF pi, m
  LOOP
    v_needed := v_item.qty;
    FOR v_batch IN
      SELECT inv.id, inv.batch_number, inv.expiry_date, inv.quantity_remaining
        FROM public.pharmacy_inventory AS inv
       WHERE inv.medicine_id = v_item.medicine_id
         AND inv.quantity_remaining > 0
         AND inv.deleted_at IS NULL
         AND (inv.expiry_date IS NULL OR inv.expiry_date >= CURRENT_DATE)
         AND (public.is_super_admin() OR inv.branch_id = v_branch)
       ORDER BY inv.expiry_date ASC NULLS LAST, inv.created_at ASC
       FOR UPDATE
    LOOP
      EXIT WHEN v_needed <= 0;
      v_take := LEAST(v_needed, v_batch.quantity_remaining);
      UPDATE public.pharmacy_inventory AS inv
         SET quantity_remaining = inv.quantity_remaining - v_take,
             quantity = inv.quantity_remaining - v_take,
             updated_at = now(),
             updated_by = v_uid
       WHERE inv.id = v_batch.id;
      INSERT INTO public.stock_movements (
        medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by
      ) VALUES (
        v_item.medicine_id,v_batch.id,'dispense',-v_take,p_prescription_id,'prescriptions',
        COALESCE(v_visit_branch,v_branch),v_uid
      );
      item_id := v_item.id;
      medicine_id := v_item.medicine_id;
      medicine_name := v_item.name;
      batch_id := v_batch.id;
      batch_number := v_batch.batch_number;
      expiry_date := v_batch.expiry_date;
      quantity_dispensed := v_take;
      batch_quantity_remaining := v_batch.quantity_remaining - v_take;
      source := 'batch';
      RETURN NEXT;
      v_needed := v_needed - v_take;
    END LOOP;

    v_shortfall := GREATEST(v_needed,0);
    IF v_shortfall > 0 THEN
      -- Legacy medicine.stock_quantity has no branch ownership. Never use it as
      -- a substitute for an assigned, unexpired batch: doing so can consume
      -- another branch's stock or stock with no expiry/audit trail.
      RAISE EXCEPTION 'insufficient_branch_batch_stock: %',v_item.name;
    END IF;

    UPDATE public.medicines AS m
       SET stock_quantity = m.stock_quantity - v_item.qty::integer,
           updated_at = now(),
           updated_by = v_uid
     WHERE m.id = v_item.medicine_id;
    UPDATE public.prescription_items AS pi
       SET is_dispensed = true,
           dispensed_quantity = v_item.qty::integer,
           updated_at = now(),
           updated_by = v_uid
     WHERE pi.id = v_item.id;
  END LOOP;

  -- A visit uses the single primary invoice by default; a finalized primary
  -- invoice requires an explicit secondary invoice choice. A no-visit prescription
  -- (super-admin-only under the branch guard above) receives a standalone invoice.
  IF v_visit_id IS NOT NULL THEN
    PERFORM private.create_or_append_visit_invoice_atomic(
      v_visit_id,CURRENT_DATE,0,v_invoice_items,p_separate_invoice
    );
  ELSE
    PERFORM public.create_invoice_atomic(
      v_patient_id,NULL,CURRENT_DATE,0,v_invoice_items
    );
  END IF;

  UPDATE public.prescriptions AS p
     SET status = 'dispensed',
         dispensed_by = v_uid,
         dispensed_at = now(),
         updated_at = now(),
         updated_by = v_uid
   WHERE p.id = p_prescription_id;

  RETURN;
END;
$function$

CREATE OR REPLACE FUNCTION public.fn_finance_audit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare uid uuid;
begin
  begin
    uid := public.current_app_user_id();
  exception when others then uid := null;
  end;
  insert into public.audit_logs (table_name, record_id, action, user_id, old_data, new_data)
  values (
    tg_table_name,
    coalesce((case when tg_op = 'DELETE' then old.id else new.id end), gen_random_uuid()),
    tg_op, uid,
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end
  );
  return case when tg_op = 'DELETE' then old else new end;
end $function$

CREATE OR REPLACE FUNCTION public.fn_ledger_from_expense()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.fn_ledger_post(
    'expense', -abs(new.amount), coalesce(new.payment_method, 'cash'),
    coalesce(new.category, 'other'), coalesce(new.description, 'Expense'), 'expense', new.id,
    coalesce(new.expense_date::timestamptz, now()), new.branch_id);
  return new;
end $function$

CREATE OR REPLACE FUNCTION public.fn_ledger_from_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.fn_ledger_post(
    'customer_payment', abs(new.amount), coalesce(new.payment_method, new.method, 'cash'),
    'patient_payment', 'Invoice payment', 'payment', new.id,
    coalesce(new.payment_date::timestamptz, new.received_at, now()), new.branch_id
  );
  return new;
end
$function$

CREATE OR REPLACE FUNCTION public.fn_ledger_from_supplier_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  perform public.fn_ledger_post(
    'supplier_payment', -abs(new.amount), coalesce(new.payment_method, 'cash'),
    'supplier', coalesce(new.notes, 'Supplier payment'), 'supplier_payment', new.id,
    coalesce(new.payment_date::timestamptz, now()), new.branch_id);
  return new;
end $function$

CREATE OR REPLACE FUNCTION public.fn_ledger_post(_type text, _amount numeric, _method text, _category text, _description text, _source_type text, _source_id uuid, _date timestamp with time zone, _branch uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare new_id uuid; uid uuid;
begin
  if _amount is null or _amount = 0 then
    return null;
  end if;
  begin
    uid := public.current_app_user_id();
  exception when others then uid := null;
  end;
  insert into public.cashbox_transactions (
    branch_id, transaction_type, amount, payment_method, category,
    description, source_type, source_id, transaction_date, created_by
  ) values (
    _branch, _type, _amount, coalesce(_method, 'cash'), _category,
    _description, _source_type, _source_id, coalesce(_date, now()), uid
  )
  on conflict (source_type, source_id) where source_type is not null and source_id is not null
  do nothing
  returning id into new_id;
  return new_id;
end $function$

CREATE OR REPLACE FUNCTION public.fn_receive_pharmacy_batch(p_medicine_id uuid, p_quantity numeric, p_batch_number text DEFAULT NULL::text, p_expiry_date date DEFAULT NULL::date, p_manufacture_date date DEFAULT NULL::date, p_purchase_price numeric DEFAULT 0, p_selling_price numeric DEFAULT NULL::numeric, p_supplier_id uuid DEFAULT NULL::uuid, p_invoice_reference text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE v_uid uuid:=public.current_app_user_id(); v_branch uuid; v_batch_id uuid; v_sell numeric;
BEGIN
 IF NOT public.app_has_perm('pharmacy.update') THEN RAISE EXCEPTION 'insufficient_permission' USING ERRCODE='42501'; END IF;
 IF p_quantity IS NULL OR p_quantity::text IN ('NaN','Infinity','-Infinity') OR p_quantity<>pg_catalog.trunc(p_quantity) OR p_quantity<=0 THEN RAISE EXCEPTION 'invalid_quantity' USING ERRCODE='22023'; END IF;
 IF p_purchase_price IS NULL OR p_purchase_price::text IN ('NaN','Infinity','-Infinity') OR p_purchase_price<0 OR p_purchase_price<>pg_catalog.round(p_purchase_price,2) THEN RAISE EXCEPTION 'invalid_purchase_price' USING ERRCODE='22023'; END IF;
 IF p_expiry_date IS NOT NULL AND p_manufacture_date IS NOT NULL AND p_manufacture_date>p_expiry_date THEN RAISE EXCEPTION 'manufacture_after_expiry'; END IF;
 SELECT u.branch_id INTO v_branch FROM public.users u WHERE u.id=v_uid AND u.deleted_at IS NULL;
 IF NOT public.is_super_admin() AND v_branch IS NULL THEN RAISE EXCEPTION 'user_branch_not_configured' USING ERRCODE='42501'; END IF;
 SELECT COALESCE(p_selling_price,m.selling_price,0) INTO v_sell FROM public.medicines m WHERE m.id=p_medicine_id AND m.deleted_at IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'medicine_not_found'; END IF;
 IF v_sell::text IN ('NaN','Infinity','-Infinity') OR v_sell<0 OR v_sell<>pg_catalog.round(v_sell,2) THEN RAISE EXCEPTION 'invalid_selling_price' USING ERRCODE='22023'; END IF;
 INSERT INTO public.pharmacy_inventory(medicine_id,batch_number,batch_no,expiry_date,manufacture_date,quantity,quantity_received,quantity_remaining,purchase_price,selling_price,supplier_id,invoice_reference,branch_id,created_by,updated_by)
 VALUES(p_medicine_id,NULLIF(pg_catalog.btrim(p_batch_number),''),NULLIF(pg_catalog.btrim(p_batch_number),''),p_expiry_date,p_manufacture_date,p_quantity,p_quantity,p_quantity,p_purchase_price,v_sell,p_supplier_id,NULLIF(pg_catalog.btrim(p_invoice_reference),''),v_branch,v_uid,v_uid) RETURNING id INTO v_batch_id;
 UPDATE public.medicines SET stock_quantity=COALESCE(stock_quantity,0)+p_quantity::integer,cost_price=p_purchase_price,selling_price=v_sell,updated_at=pg_catalog.now(),updated_by=v_uid WHERE id=p_medicine_id;
 INSERT INTO public.stock_movements(medicine_id,batch_id,movement_type,quantity,reference_id,reference_table,branch_id,created_by) VALUES(p_medicine_id,v_batch_id,'purchase',p_quantity,v_batch_id,'pharmacy_inventory',v_branch,v_uid);
 RETURN v_batch_id;
END; $function$

CREATE OR REPLACE FUNCTION public.fn_receive_pharmacy_batch_atomic(p_medicine_id uuid, p_quantity numeric, p_batch_number text, p_expiry_date date, p_manufacture_date date, p_purchase_price numeric, p_selling_price numeric, p_supplier_id uuid, p_invoice_reference text, p_idempotency_key text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_uid uuid := public.current_app_user_id();
  v_branch uuid;
  v_batch_id uuid;
  v_sell numeric;
  v_key text;
  v_existing_stock bigint;
  v_active_branch_count bigint;
  existing public.pharmacy_inventory;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authenticated_application_user_required' USING ERRCODE = '42501';
  END IF;
  IF NOT COALESCE(public.app_has_perm('pharmacy.update'), false) THEN
    RAISE EXCEPTION 'insufficient_permission' USING ERRCODE = '42501';
  END IF;

  IF p_idempotency_key IS NULL
     OR pg_catalog.length(pg_catalog.btrim(p_idempotency_key)) = 0
     OR pg_catalog.length(pg_catalog.btrim(p_idempotency_key)) > 128 THEN
    RAISE EXCEPTION 'invalid_idempotency_key' USING ERRCODE = '22023';
  END IF;
  v_key := pg_catalog.btrim(p_idempotency_key);

  IF p_quantity IS NULL
     OR p_quantity::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_quantity <> pg_catalog.trunc(p_quantity)
     OR p_quantity <= 0
     OR p_quantity > 2147483647 THEN
    RAISE EXCEPTION 'invalid_quantity' USING ERRCODE = '22023';
  END IF;

  IF p_purchase_price IS NULL
     OR p_purchase_price::text IN ('NaN', 'Infinity', '-Infinity')
     OR p_purchase_price < 0
     OR p_purchase_price <> pg_catalog.round(p_purchase_price, 2) THEN
    RAISE EXCEPTION 'invalid_purchase_price' USING ERRCODE = '22023';
  END IF;

  IF p_selling_price IS NOT NULL
     AND (p_selling_price::text IN ('NaN', 'Infinity', '-Infinity')
       OR p_selling_price < 0
       OR p_selling_price <> pg_catalog.round(p_selling_price, 2)) THEN
    RAISE EXCEPTION 'invalid_selling_price' USING ERRCODE = '22023';
  END IF;

  IF p_expiry_date IS NOT NULL
     AND p_manufacture_date IS NOT NULL
     AND p_manufacture_date > p_expiry_date THEN
    RAISE EXCEPTION 'manufacture_after_expiry' USING ERRCODE = '22023';
  END IF;
  SELECT u.branch_id INTO v_branch
    FROM public.users AS u
   WHERE u.id = v_uid
     AND u.deleted_at IS NULL
     AND u.active IS TRUE
   FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'active_application_user_not_found' USING ERRCODE = '42501';
  END IF;
  -- Branch-scoped dispensing must never receive an orphan batch. A global
  -- super-admin without a profile branch may use the sole active branch; if
  -- zero or multiple branches are active, fail closed because this RPC has no
  -- explicit target-branch argument.
  IF v_branch IS NULL AND public.is_super_admin() THEN
    SELECT count(*), (array_agg(b.id ORDER BY b.id))[1]
      INTO v_active_branch_count, v_branch
      FROM public.branches AS b
     WHERE COALESCE(b.is_active, b.active, false)
       AND b.deleted_at IS NULL;
    IF v_active_branch_count <> 1 THEN
      v_branch := NULL;
    END IF;
  END IF;
  IF v_branch IS NULL THEN
    RAISE EXCEPTION 'user_branch_not_configured' USING ERRCODE = '42501';
  END IF;

  PERFORM 1
    FROM public.branches AS b
   WHERE b.id = v_branch
     AND COALESCE(b.is_active, b.active, false)
     AND b.deleted_at IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'user_branch_not_configured' USING ERRCODE = '42501';
  END IF;

  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('roshan.pharmacy.receive:' || v_key, 0)
  );

  SELECT b.* INTO existing
    FROM public.pharmacy_inventory AS b
   WHERE b.idempotency_key = v_key;

  IF FOUND THEN
    IF existing.medicine_id IS DISTINCT FROM p_medicine_id
       OR existing.quantity_received IS DISTINCT FROM p_quantity
       OR existing.batch_number IS DISTINCT FROM NULLIF(pg_catalog.btrim(p_batch_number), '')
       OR existing.expiry_date IS DISTINCT FROM p_expiry_date
       OR existing.manufacture_date IS DISTINCT FROM p_manufacture_date
       OR existing.purchase_price IS DISTINCT FROM p_purchase_price
       OR (p_selling_price IS NOT NULL AND existing.selling_price IS DISTINCT FROM p_selling_price)
       OR existing.supplier_id IS DISTINCT FROM p_supplier_id
       OR existing.invoice_reference IS DISTINCT FROM NULLIF(pg_catalog.btrim(p_invoice_reference), '')
       OR existing.branch_id IS DISTINCT FROM v_branch
       OR existing.created_by IS DISTINCT FROM v_uid THEN
      RAISE EXCEPTION 'idempotency_key_reused_with_different_receipt'
        USING ERRCODE = '22023';
    END IF;
    RETURN existing.id;
  END IF;

  IF p_expiry_date IS NOT NULL AND p_expiry_date < CURRENT_DATE THEN
    RAISE EXCEPTION 'expired_batch' USING ERRCODE = '22023';
  END IF;
  IF p_manufacture_date IS NOT NULL AND p_manufacture_date > CURRENT_DATE THEN
    RAISE EXCEPTION 'future_manufacture_date' USING ERRCODE = '22023';
  END IF;

  IF p_supplier_id IS NOT NULL THEN
    PERFORM 1
      FROM public.suppliers AS s
     WHERE s.id = p_supplier_id
       AND s.active IS TRUE
       AND s.deleted_at IS NULL
     FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'active_supplier_not_found' USING ERRCODE = '22023';
    END IF;
  END IF;

  SELECT COALESCE(m.stock_quantity, 0)::bigint,
         COALESCE(p_selling_price, m.selling_price, 0)
    INTO v_existing_stock, v_sell
    FROM public.medicines AS m
   WHERE m.id = p_medicine_id
     AND m.deleted_at IS NULL
     AND m.active IS TRUE
   FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'active_medicine_not_found' USING ERRCODE = '22023';
  END IF;

  IF v_sell IS NULL
     OR v_sell::text IN ('NaN', 'Infinity', '-Infinity')
     OR v_sell < 0
     OR v_sell <> pg_catalog.round(v_sell, 2) THEN
    RAISE EXCEPTION 'invalid_selling_price' USING ERRCODE = '22023';
  END IF;
  IF v_existing_stock + p_quantity > 2147483647 THEN
    RAISE EXCEPTION 'stock_quantity_overflow' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.pharmacy_inventory (
    medicine_id, batch_number, batch_no, expiry_date, manufacture_date,
    quantity, quantity_received, quantity_remaining, purchase_price, selling_price,
    supplier_id, invoice_reference, branch_id, created_by, updated_by, idempotency_key
  )
  VALUES (
    p_medicine_id,
    NULLIF(pg_catalog.btrim(p_batch_number), ''),
    NULLIF(pg_catalog.btrim(p_batch_number), ''),
    p_expiry_date, p_manufacture_date,
    p_quantity, p_quantity, p_quantity, p_purchase_price, v_sell,
    p_supplier_id, NULLIF(pg_catalog.btrim(p_invoice_reference), ''),
    v_branch, v_uid, v_uid, v_key
  )
  RETURNING id INTO v_batch_id;

  UPDATE public.medicines
     SET stock_quantity = (v_existing_stock + p_quantity)::integer,
         cost_price = p_purchase_price,
         selling_price = v_sell,
         updated_at = pg_catalog.now(),
         updated_by = v_uid
   WHERE id = p_medicine_id;

  INSERT INTO public.stock_movements (
    medicine_id, batch_id, movement_type, quantity, reference_id,
    reference_table, branch_id, created_by
  )
  VALUES (
    p_medicine_id, v_batch_id, 'purchase', p_quantity, v_batch_id,
    'pharmacy_inventory', v_branch, v_uid
  );

  RETURN v_batch_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.fn_recompute_invoice_paid()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare inv uuid; total numeric; net numeric;
begin
  inv := coalesce(new.invoice_id, old.invoice_id);
  if inv is null then
    return coalesce(new, old);
  end if;
  select coalesce(sum(amount), 0) into total from public.payments where invoice_id = inv and deleted_at is null;
  select coalesce(i.net_amount, i.total_amount, 0) into net from public.invoices i where i.id = inv;
  update public.invoices
     set paid_amount = total,
         status = case when total <= 0 then 'unpaid' when total >= net then 'paid' else 'partial' end,
         payment_status = case when total <= 0 then 'unpaid' when total >= net then 'paid' else 'partial' end,
         updated_at = now()
   where id = inv;
  return coalesce(new, old);
end $function$

CREATE OR REPLACE FUNCTION public.fn_recompute_supplier_bill()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare bill uuid; total numeric; due numeric;
begin
  bill := coalesce(new.supplier_bill_id, old.supplier_bill_id);
  if bill is null then
    return coalesce(new, old);
  end if;
  select coalesce(sum(amount), 0) into total from public.supplier_payments where supplier_bill_id = bill and deleted_at is null;
  select coalesce(total_amount, 0) into due from public.supplier_bills where id = bill;
  update public.supplier_bills
     set paid_amount = total,
         status = case when total <= 0 then 'unpaid' when total >= due then 'paid' else 'partial' end,
         updated_at = now()
   where id = bill;
  return coalesce(new, old);
end $function$

CREATE OR REPLACE FUNCTION public.get_current_user_profile()
 RETURNS TABLE(user_id uuid, full_name text, email text, role_code text, role_name text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
          begin
            return query
              select 
                  u.id as user_id,
                      u.full_name,
                          u.email,
                              r.code as role_code,
                                  r.name as role_name
                                    from public.users u
                                      left join public.roles r on u.role_id = r.id
                                        where u.auth_user_id = auth.uid();
                                        end;
                                        $function$

CREATE OR REPLACE FUNCTION public.get_my_app_profile()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_user_id uuid;
  v_full_name text;
  v_email text;
  v_phone text;
  v_role_id uuid;
  v_active boolean;
  v_role_code text;
  v_role_name text;
  v_permissions jsonb := '[]'::jsonb;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT
    u.id,
    u.full_name,
    u.email,
    u.phone,
    u.role_id,
    u.active,
    r.code,
    r.name
  INTO
    v_user_id,
    v_full_name,
    v_email,
    v_phone,
    v_role_id,
    v_active,
    v_role_code,
    v_role_name
  FROM public.users AS u
  LEFT JOIN public.roles AS r
    ON r.id = u.role_id
   AND r.deleted_at IS NULL
  WHERE u.auth_user_id = auth.uid()
    AND u.deleted_at IS NULL
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_active IS TRUE
     AND v_role_code IS NOT NULL
     AND v_role_code <> 'super_admin'
     AND v_role_id IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(p.code ORDER BY p.code), '[]'::jsonb)
      INTO v_permissions
    FROM public.role_permissions AS rp
    JOIN public.permissions AS p ON p.id = rp.permission_id
    WHERE rp.role_id = v_role_id;
  END IF;

  RETURN jsonb_build_object(
    'user', jsonb_build_object(
      'id', v_user_id,
      'full_name', v_full_name,
      'email', v_email,
      'phone', v_phone,
      'role_id', v_role_id,
      'active', coalesce(v_active, false),
      'role_code', v_role_code,
      'role_name', v_role_name
    ),
    'permissions', coalesce(v_permissions, '[]'::jsonb)
  );
END;
$function$

CREATE OR REPLACE FUNCTION public.get_visit_form_options()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  v_departments jsonb;
  v_doctors jsonb;
BEGIN
  IF NOT public.app_has_perm('visits.create') THEN
    RAISE EXCEPTION 'visit creation permission required' USING ERRCODE = '42501';
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('id', d.id, 'name', d.name, 'name_ar', d.name_ar)
      ORDER BY coalesce(d.name_ar, d.name), d.id
    ),
    '[]'::jsonb
  )
  INTO v_departments
  FROM public.departments AS d
  WHERE d.active IS TRUE
    AND d.is_active IS TRUE
    AND d.deleted_at IS NULL;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object('id', u.id, 'full_name', u.full_name)
      ORDER BY u.full_name, u.id
    ),
    '[]'::jsonb
  )
  INTO v_doctors
  FROM public.users AS u
  JOIN public.roles AS r ON r.id = u.role_id
  WHERE u.active IS TRUE
    AND u.deleted_at IS NULL
    AND r.deleted_at IS NULL
    AND r.code = ANY (ARRAY['gp', 'dentist', 'specialist', 'doctor', 'physician']::text[])
    AND private.app_has_branch_access(u.branch_id);

  RETURN jsonb_build_object(
    'departments', v_departments,
    'doctors', v_doctors
  );
END;
$function$

CREATE OR REPLACE FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_query_trgm$function$

CREATE OR REPLACE FUNCTION public.gin_extract_value_trgm(text, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_value_trgm$function$

CREATE OR REPLACE FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_consistent$function$

CREATE OR REPLACE FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal)
 RETURNS "char"
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_triconsistent$function$

CREATE OR REPLACE FUNCTION public.gtrgm_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_compress$function$

CREATE OR REPLACE FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_consistent$function$

CREATE OR REPLACE FUNCTION public.gtrgm_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_decompress$function$

CREATE OR REPLACE FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_distance$function$

CREATE OR REPLACE FUNCTION public.gtrgm_in(cstring)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_in$function$

CREATE OR REPLACE FUNCTION public.gtrgm_options(internal)
 RETURNS void
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE
AS '$libdir/pg_trgm', $function$gtrgm_options$function$

CREATE OR REPLACE FUNCTION public.gtrgm_out(gtrgm)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_out$function$

CREATE OR REPLACE FUNCTION public.gtrgm_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_penalty$function$

CREATE OR REPLACE FUNCTION public.gtrgm_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_picksplit$function$

CREATE OR REPLACE FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_same$function$

CREATE OR REPLACE FUNCTION public.gtrgm_union(internal, internal)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_union$function$

CREATE OR REPLACE FUNCTION public.is_super_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ SELECT private.is_super_admin() $function$

CREATE OR REPLACE FUNCTION public.next_invoice_number()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  month_key text := to_char(now(), 'YYYYMM');
  next_no bigint;
begin
  if not private.app_has_perm('billing.create') then
    raise exception 'Permission denied' using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('roshan:invoice:' || month_key));

  select coalesce(max((pg_catalog.regexp_match(invoice_number, '^INV-[0-9]{6}-([0-9]+)$'))[1]::bigint), 0) + 1
    into next_no
  from public.invoices
  where invoice_number like 'INV-' || month_key || '-%';

  return 'INV-' || month_key || '-' || pg_catalog.lpad(next_no::text, 5, '0');
end;
$function$

CREATE OR REPLACE FUNCTION public.next_mrn()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  next_no bigint;
begin
  if not private.app_has_perm('patients.create') then
    raise exception 'Permission denied' using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtext('roshan:mrn'));

  select coalesce(max(nullif(pg_catalog.regexp_replace(mrn, '[^0-9]', '', 'g'), '')::bigint), 0) + 1
    into next_no
  from public.patients
  where mrn ~ '^RMC[0-9]+$';

  return 'RMC' || pg_catalog.lpad(next_no::text, 6, '0');
end;
$function$

CREATE OR REPLACE FUNCTION public.next_queue_number(_visit_date date)
 RETURNS integer
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.next_queue_number(_visit_date) $function$

CREATE OR REPLACE FUNCTION public.next_visit_number(_visit_date date)
 RETURNS text
 LANGUAGE sql
 SET search_path TO ''
AS $function$ SELECT private.next_visit_number(_visit_date) $function$

CREATE OR REPLACE FUNCTION public.normalize_medicine_names()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
  -- The current medicines table requires generic_name, while some existing
  -- pharmacy UI flows send the legacy `name` field only. Normalize that
  -- payload at the database boundary instead of weakening the NOT NULL rule.
  IF NULLIF(BTRIM(NEW.generic_name), '') IS NULL THEN
    NEW.generic_name := NULLIF(BTRIM(NEW.name), '');
  END IF;

  IF NULLIF(BTRIM(NEW.generic_name), '') IS NULL THEN
    NEW.generic_name := NULLIF(BTRIM(NEW.brand_name), '');
  END IF;

  IF NULLIF(BTRIM(NEW.generic_name), '') IS NULL THEN
    RAISE EXCEPTION 'Medicine generic name is required (provide generic_name or name)'
      USING ERRCODE = '23502';
  END IF;

  IF NEW.updated_at IS NULL THEN
    NEW.updated_at := now();
  END IF;

  RETURN NEW;
END;
$function$

CREATE OR REPLACE FUNCTION public.post_cashbox_entry(_direction text, _amount numeric, _method text DEFAULT 'cash'::text, _category text DEFAULT 'manual'::text, _description text DEFAULT NULL::text, _date timestamp with time zone DEFAULT now())
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
$function$

CREATE OR REPLACE FUNCTION public.post_expense(_category text, _amount numeric, _description text DEFAULT NULL::text, _expense_date date DEFAULT CURRENT_DATE, _method text DEFAULT 'cash'::text, _paid_to text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  exp_id uuid;
  uid uuid;
  bid uuid;
BEGIN
  IF NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to record expenses';
  END IF;

  IF _amount IS NULL
     OR _amount::text IN ('NaN', 'Infinity', '-Infinity')
     OR _amount <= 0
     OR _amount <> round(_amount, 2) THEN
    RAISE EXCEPTION 'expense amount must be finite, positive, and have at most two decimal places'
      USING ERRCODE = '22023';
  END IF;

  uid := public.current_app_user_id();
  SELECT branch_id INTO bid FROM public.users WHERE id = uid;

  IF NOT public.is_super_admin() AND bid IS NULL THEN
    RAISE EXCEPTION 'user branch is not configured';
  END IF;

  INSERT INTO public.expenses (
    branch_id, category, amount, description, expense_date,
    payment_method, paid_to, created_by
  )
  VALUES (
    bid, COALESCE(_category, 'other'), _amount, _description,
    COALESCE(_expense_date, CURRENT_DATE), COALESCE(_method, 'cash'),
    _paid_to, uid
  )
  RETURNING id INTO exp_id;

  RETURN exp_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.post_insurance_claim_payment(_claim_id uuid, _amount numeric, _method text DEFAULT 'bank'::text, _reference text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  claim public.insurance_claims;
  pay_id uuid;
  uid uuid;
  outstanding numeric;
  new_paid numeric;
  claim_branch uuid;
BEGIN
  IF NOT public.app_has_perm('insurance.update') THEN
    RAISE EXCEPTION 'not authorised to record insurance payments';
  END IF;

  IF _amount IS NULL
     OR _amount::text IN ('NaN','Infinity','-Infinity')
     OR _amount <= 0
     OR _amount <> round(_amount, 2) THEN
    RAISE EXCEPTION 'payment amount must be finite, positive, and have at most two decimal places'
      USING ERRCODE = '22023';
  END IF;

  SELECT c.* INTO claim
    FROM public.insurance_claims AS c
    JOIN public.invoices AS i ON i.id = c.invoice_id
   WHERE c.id = _claim_id AND c.deleted_at IS NULL
   FOR UPDATE OF c;
  IF claim.id IS NULL THEN RAISE EXCEPTION 'claim not found'; END IF;

  SELECT i.branch_id INTO claim_branch FROM public.invoices AS i WHERE i.id = claim.invoice_id;
  IF NOT public.is_super_admin() AND NOT private.app_has_claim_branch(_claim_id) THEN
    RAISE EXCEPTION 'cross-branch insurance claim access denied';
  END IF;
  IF claim.status NOT IN ('approved','partially_approved','paid') THEN
    RAISE EXCEPTION 'claim must be approved before recording a payment (current status: %)', claim.status;
  END IF;

  outstanding := GREATEST(COALESCE(claim.approved_amount, 0) - COALESCE(claim.paid_amount, 0), 0);
  IF _amount > outstanding THEN
    RAISE EXCEPTION 'payment (%) exceeds outstanding approved balance (%)', _amount, outstanding;
  END IF;

  uid := public.current_app_user_id();
  INSERT INTO public.insurance_claim_payments(claim_id, amount, payment_method, reference, created_by)
  VALUES (_claim_id, _amount, COALESCE(_method, 'bank'), _reference, uid)
  RETURNING id INTO pay_id;

  SELECT COALESCE(SUM(amount), 0) INTO new_paid
    FROM public.insurance_claim_payments WHERE claim_id = _claim_id AND deleted_at IS NULL;
  UPDATE public.insurance_claims
     SET paid_amount = new_paid,
         status = CASE WHEN new_paid >= COALESCE(approved_amount, 0) AND approved_amount IS NOT NULL THEN 'paid' ELSE status END,
         paid_at = CASE WHEN new_paid >= COALESCE(approved_amount, 0) AND approved_amount IS NOT NULL THEN now() ELSE paid_at END,
         updated_by = uid, updated_at = now()
   WHERE id = _claim_id;

  PERFORM public.fn_ledger_post(
    'income', abs(_amount), COALESCE(_method, 'bank'), 'insurance_settlement',
    'Insurance claim payment — ' || claim.claim_number, 'insurance_claim_payment', pay_id, now(), claim_branch
  );
  RETURN pay_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.post_invoice_payment(_invoice_id uuid, _amount numeric, _method text DEFAULT 'cash'::text, _reference text DEFAULT NULL::text, _idempotency_key text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  net numeric; already numeric; outstanding numeric; pay_id uuid; uid uuid; invoice_branch uuid; user_branch uuid;
  existing_actor uuid; existing_invoice_id uuid; existing_amount numeric; existing_method text; existing_reference text;
BEGIN
  IF NOT public.app_has_perm('payments.create') AND NOT public.app_has_perm('billing.create') AND NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to record payments' USING ERRCODE = '42501';
  END IF;
  IF _amount IS NULL OR _amount::text IN ('NaN','Infinity','-Infinity') OR _amount <= 0 OR _amount <> pg_catalog.round(_amount, 2) THEN
    RAISE EXCEPTION 'payment amount must be finite, greater than zero, and have at most two decimal places' USING ERRCODE = '22023';
  END IF;
  IF _invoice_id IS NULL THEN RAISE EXCEPTION 'invoice is required' USING ERRCODE = '22023'; END IF;
  uid := public.current_app_user_id();
  SELECT branch_id INTO user_branch FROM public.users WHERE id=uid AND deleted_at IS NULL AND active IS TRUE;
  IF NOT public.is_super_admin() AND user_branch IS NULL THEN RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501'; END IF;
  IF _idempotency_key IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('roshan.payment.idempotency:' || _idempotency_key,0));
    SELECT p.id,p.created_by,p.invoice_id,p.amount,COALESCE(p.payment_method,p.method,'cash'),NULLIF(BTRIM(COALESCE(p.reference_no,p.reference,'')),'')
      INTO pay_id,existing_actor,existing_invoice_id,existing_amount,existing_method,existing_reference
      FROM public.payments p WHERE p.idempotency_key=_idempotency_key;
    IF pay_id IS NOT NULL THEN
      IF existing_actor IS DISTINCT FROM uid OR existing_invoice_id IS DISTINCT FROM _invoice_id OR existing_amount IS DISTINCT FROM _amount
         OR existing_method IS DISTINCT FROM COALESCE(_method,'cash') OR existing_reference IS DISTINCT FROM NULLIF(BTRIM(COALESCE(_reference,'')),'') THEN
        RAISE EXCEPTION 'idempotency key reused with different payment request' USING ERRCODE = '22023';
      END IF;
      RETURN pay_id;
    END IF;
  END IF;
  SELECT COALESCE(i.net_amount,i.total_amount,0),COALESCE(i.paid_amount,0),i.branch_id
    INTO net,already,invoice_branch FROM public.invoices i WHERE i.id=_invoice_id AND i.deleted_at IS NULL FOR UPDATE;
  IF net IS NULL THEN RAISE EXCEPTION 'invoice not found' USING ERRCODE = '22023'; END IF;
  IF NOT public.is_super_admin() AND invoice_branch IS DISTINCT FROM user_branch THEN RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501'; END IF;
  outstanding := GREATEST(net-already,0);
  IF _amount > outstanding THEN RAISE EXCEPTION 'payment (%) exceeds outstanding balance (%)',_amount,outstanding USING ERRCODE = '22023'; END IF;
  INSERT INTO public.payments(invoice_id,amount,payment_method,method,reference_no,reference,payment_date,received_at,received_by,created_by,branch_id,idempotency_key)
  VALUES (_invoice_id,_amount,COALESCE(_method,'cash'),COALESCE(_method,'cash'),NULLIF(BTRIM(COALESCE(_reference,'')),''),NULLIF(BTRIM(COALESCE(_reference,'')),''),CURRENT_DATE,now(),uid,uid,invoice_branch,_idempotency_key)
  RETURNING id INTO pay_id;
  RETURN pay_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.post_supplier_bill(_supplier_id uuid, _invoice_number text, _bill_date date, _due_date date, _subtotal numeric, _discount numeric DEFAULT 0, _notes text DEFAULT NULL::text)
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
$function$

CREATE OR REPLACE FUNCTION public.post_supplier_payment(_bill_id uuid, _amount numeric, _method text DEFAULT 'cash'::text, _reference text DEFAULT NULL::text, _payment_date date DEFAULT CURRENT_DATE, _notes text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
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
$function$

CREATE OR REPLACE FUNCTION public.record_cashbox_expense()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(new.deleted_at is null, true) and coalesce(new.amount,0) > 0 then
    insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,category,description,source_type,source_id,transaction_date,created_by)
    values(new.branch_id,'expense',-new.amount,coalesce(new.payment_method,'cash'),new.category,new.description,'expense',new.id,(new.expense_date::timestamp at time zone 'UTC'),coalesce(new.created_by,public.current_app_user_id()))
    on conflict (source_type,source_id) where source_type is not null and source_id is not null do nothing;
  end if;
  return new;
end; $function$

CREATE OR REPLACE FUNCTION public.record_cashbox_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(new.deleted_at is null, true) and coalesce(new.amount,0) > 0 then
    insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,description,source_type,source_id,transaction_date,created_by)
    values(new.branch_id,'customer_payment',new.amount,coalesce(new.payment_method,new.method,'cash'),'Customer invoice payment', 'payment', new.id, coalesce(new.payment_date,new.received_at,now()), coalesce(new.received_by,public.current_app_user_id()))
    on conflict (source_type,source_id) where source_type is not null and source_id is not null do nothing;
  end if;
  return new;
end; $function$

CREATE OR REPLACE FUNCTION public.record_cashbox_supplier_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if coalesce(new.deleted_at is null, true) and coalesce(new.amount,0) > 0 then
    insert into public.cashbox_transactions(branch_id,transaction_type,amount,payment_method,description,source_type,source_id,transaction_date,created_by)
    values(new.branch_id,'supplier_payment',-new.amount,new.payment_method,'Supplier bill payment','supplier_payment',new.id,new.payment_date,coalesce(new.created_by,public.current_app_user_id()))
    on conflict (source_type,source_id) where source_type is not null and source_id is not null do nothing;
  end if;
  return new;
end; $function$

CREATE OR REPLACE FUNCTION public.reverse_cashbox_entry(_transaction_id uuid, _reason text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare orig public.cashbox_transactions; new_id uuid; uid uuid; bid uuid;
begin
  if not public.app_has_perm('cashbox.update') and not public.is_super_admin() then raise exception 'not authorised to reverse cashbox entries'; end if;
  if _reason is null or btrim(_reason) = '' then raise exception 'a reversal reason is required'; end if;
  select * into orig from public.cashbox_transactions where id = _transaction_id for update;
  if orig.id is null then raise exception 'transaction not found'; end if;
  if orig.is_reversed then raise exception 'transaction already reversed'; end if;
  if orig.reversal_of is not null then raise exception 'a reversal entry cannot itself be reversed'; end if;
  uid := public.current_app_user_id();
  select branch_id into bid from public.users where id = uid;
  if not public.is_super_admin() and (bid is null or orig.branch_id is distinct from bid) then raise exception 'cross-branch cashbox access denied'; end if;
  insert into public.cashbox_transactions (branch_id, transaction_type, amount, payment_method, category, description, source_type, transaction_date, created_by, reversal_of, reversal_reason)
  values (orig.branch_id, 'adjustment', -orig.amount, orig.payment_method, orig.category, coalesce(orig.description, '') || ' — reversal: ' || _reason, 'reversal', now(), uid, orig.id, _reason) returning id into new_id;
  perform pg_catalog.set_config('roshan.cashbox_write', 'on', true);
  update public.cashbox_transactions set is_reversed = true, reversal_reason = _reason where id = orig.id;
  perform pg_catalog.set_config('roshan.cashbox_write', 'off', true);
  return new_id;
end $function$

CREATE OR REPLACE FUNCTION public.set_limit(real)
 RETURNS real
 LANGUAGE c
 STRICT
AS '$libdir/pg_trgm', $function$set_limit$function$

CREATE OR REPLACE FUNCTION public.setup_required()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$ SELECT private.setup_required() $function$

CREATE OR REPLACE FUNCTION public.show_limit()
 RETURNS real
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_limit$function$

CREATE OR REPLACE FUNCTION public.show_trgm(text)
 RETURNS text[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_trgm$function$

CREATE OR REPLACE FUNCTION public.similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity$function$

CREATE OR REPLACE FUNCTION public.similarity_dist(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_dist$function$

CREATE OR REPLACE FUNCTION public.similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_op$function$

CREATE OR REPLACE FUNCTION public.strict_word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity$function$

CREATE OR REPLACE FUNCTION public.strict_word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_commutator_op$function$

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_commutator_op$function$

CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_op$function$

CREATE OR REPLACE FUNCTION public.strict_word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_op$function$

CREATE OR REPLACE FUNCTION public.sync_medicines_2_stock_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  IF NEW.stock_quantity IS DISTINCT FROM OLD.stock_quantity
     AND NEW.stock IS NOT DISTINCT FROM OLD.stock THEN
    NEW.stock := NEW.stock_quantity;
  ELSIF NEW.stock IS DISTINCT FROM OLD.stock
        AND NEW.stock_quantity IS NOT DISTINCT FROM OLD.stock_quantity THEN
    NEW.stock_quantity := NEW.stock;
  END IF;
  RETURN NEW;
END;
$function$

CREATE OR REPLACE FUNCTION public.sync_pharmacy_inventory_legacy_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  if new.quantity_remaining is not null then
    new.quantity := new.quantity_remaining;
  elsif new.quantity is not null then
    new.quantity_remaining := new.quantity;
  end if;

  if new.batch_number is not null and new.batch_number <> '' then
    new.batch_no := new.batch_number;
  elsif new.batch_no is not null and new.batch_no <> '' then
    new.batch_number := new.batch_no;
  end if;

  new.updated_at := now();
  return new;
end;
$function$

CREATE OR REPLACE FUNCTION public.sync_supplier_bill_payment()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare new_paid numeric;
begin
  if new.deleted_at is not null then return new; end if;
  select coalesce(sum(amount),0) into new_paid from public.supplier_payments where supplier_bill_id=new.supplier_bill_id and deleted_at is null;
  update public.supplier_bills
    set paid_amount=least(new_paid,total_amount),
        status=case when new_paid >= total_amount then 'paid' when new_paid > 0 then 'partial' else 'unpaid' end,
        updated_at=now(), updated_by=coalesce(new.created_by,public.current_app_user_id())
    where id=new.supplier_bill_id;
  return new;
end; $function$

CREATE OR REPLACE FUNCTION public.update_insurance_claim_status(_claim_id uuid, _new_status text, _approved_amount numeric DEFAULT NULL::numeric, _notes text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
DECLARE
  claim public.insurance_claims;
  uid uuid;
BEGIN
  IF NOT public.app_has_perm('insurance.update') THEN
    RAISE EXCEPTION 'not authorised to update insurance claims';
  END IF;

  SELECT * INTO claim FROM public.insurance_claims
   WHERE id = _claim_id AND deleted_at IS NULL FOR UPDATE;
  IF claim.id IS NULL THEN RAISE EXCEPTION 'claim not found'; END IF;
  IF NOT public.is_super_admin() AND NOT private.app_has_claim_branch(_claim_id) THEN
    RAISE EXCEPTION 'cross-branch insurance claim access denied';
  END IF;

  IF (claim.status, _new_status) NOT IN (
    ('draft','submitted'), ('submitted','under_review'),
    ('under_review','approved'), ('under_review','partially_approved'),
    ('under_review','rejected'), ('approved','paid'), ('partially_approved','paid')
  ) THEN
    RAISE EXCEPTION 'invalid claim status transition: % -> %', claim.status, _new_status;
  END IF;

  IF _new_status IN ('approved','partially_approved') AND _approved_amount IS NULL THEN
    RAISE EXCEPTION 'approved_amount is required when approving a claim';
  END IF;

  IF _new_status IN ('approved','partially_approved') AND (
       _approved_amount::text IN ('NaN','Infinity','-Infinity')
       OR _approved_amount < 0
       OR _approved_amount > claim.submitted_amount
       OR _approved_amount <> round(_approved_amount, 2)
  ) THEN
    RAISE EXCEPTION 'approved amount must be finite, within submitted amount, and have at most two decimal places'
      USING ERRCODE = '22023';
  END IF;

  uid := public.current_app_user_id();
  UPDATE public.insurance_claims
     SET status = _new_status,
         approved_amount = CASE WHEN _new_status IN ('approved','partially_approved') THEN _approved_amount ELSE approved_amount END,
         submitted_at = CASE WHEN _new_status = 'submitted' THEN now() ELSE submitted_at END,
         decided_at = CASE WHEN _new_status IN ('approved','partially_approved','rejected') THEN now() ELSE decided_at END,
         notes = COALESCE(_notes, notes),
         updated_by = uid,
         updated_at = now()
   WHERE id = _claim_id;
END;
$function$

CREATE OR REPLACE FUNCTION public.users(follow_ups)
 RETURNS SETOF users
 LANGUAGE sql
 STABLE ROWS 1
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT u.*
  FROM public.users AS u
  WHERE u.id = $1.created_by
$function$

CREATE OR REPLACE FUNCTION public.word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity$function$

CREATE OR REPLACE FUNCTION public.word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_commutator_op$function$

CREATE OR REPLACE FUNCTION public.word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_commutator_op$function$

CREATE OR REPLACE FUNCTION public.word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_op$function$

CREATE OR REPLACE FUNCTION public.word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_op$function$


-- Table grants
GRANT DELETE ON TABLE public.appointments TO authenticated;
GRANT DELETE ON TABLE public.appointments TO authenticator;
GRANT DELETE ON TABLE public.appointments TO service_role;
GRANT DELETE ON TABLE public.appointments TO supabase_auth_admin;
GRANT INSERT ON TABLE public.appointments TO authenticated;
GRANT INSERT ON TABLE public.appointments TO authenticator;
GRANT INSERT ON TABLE public.appointments TO service_role;
GRANT INSERT ON TABLE public.appointments TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.appointments TO authenticated;
GRANT MAINTAIN ON TABLE public.appointments TO authenticator;
GRANT MAINTAIN ON TABLE public.appointments TO service_role;
GRANT MAINTAIN ON TABLE public.appointments TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.appointments TO authenticated;
GRANT REFERENCES ON TABLE public.appointments TO authenticator;
GRANT REFERENCES ON TABLE public.appointments TO service_role;
GRANT REFERENCES ON TABLE public.appointments TO supabase_auth_admin;
GRANT SELECT ON TABLE public.appointments TO authenticated;
GRANT SELECT ON TABLE public.appointments TO authenticator;
GRANT SELECT ON TABLE public.appointments TO service_role;
GRANT SELECT ON TABLE public.appointments TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.appointments TO authenticated;
GRANT TRIGGER ON TABLE public.appointments TO authenticator;
GRANT TRIGGER ON TABLE public.appointments TO service_role;
GRANT TRIGGER ON TABLE public.appointments TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.appointments TO authenticator;
GRANT TRUNCATE ON TABLE public.appointments TO service_role;
GRANT TRUNCATE ON TABLE public.appointments TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.appointments TO authenticated;
GRANT UPDATE ON TABLE public.appointments TO authenticator;
GRANT UPDATE ON TABLE public.appointments TO service_role;
GRANT UPDATE ON TABLE public.appointments TO supabase_auth_admin;
GRANT DELETE ON TABLE public.attachments TO authenticated;
GRANT DELETE ON TABLE public.attachments TO authenticator;
GRANT DELETE ON TABLE public.attachments TO service_role;
GRANT DELETE ON TABLE public.attachments TO supabase_auth_admin;
GRANT INSERT ON TABLE public.attachments TO authenticated;
GRANT INSERT ON TABLE public.attachments TO authenticator;
GRANT INSERT ON TABLE public.attachments TO service_role;
GRANT INSERT ON TABLE public.attachments TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.attachments TO authenticated;
GRANT MAINTAIN ON TABLE public.attachments TO authenticator;
GRANT MAINTAIN ON TABLE public.attachments TO service_role;
GRANT MAINTAIN ON TABLE public.attachments TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.attachments TO authenticated;
GRANT REFERENCES ON TABLE public.attachments TO authenticator;
GRANT REFERENCES ON TABLE public.attachments TO service_role;
GRANT REFERENCES ON TABLE public.attachments TO supabase_auth_admin;
GRANT SELECT ON TABLE public.attachments TO authenticated;
GRANT SELECT ON TABLE public.attachments TO authenticator;
GRANT SELECT ON TABLE public.attachments TO service_role;
GRANT SELECT ON TABLE public.attachments TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.attachments TO authenticated;
GRANT TRIGGER ON TABLE public.attachments TO authenticator;
GRANT TRIGGER ON TABLE public.attachments TO service_role;
GRANT TRIGGER ON TABLE public.attachments TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.attachments TO authenticator;
GRANT TRUNCATE ON TABLE public.attachments TO service_role;
GRANT TRUNCATE ON TABLE public.attachments TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.attachments TO authenticated;
GRANT UPDATE ON TABLE public.attachments TO authenticator;
GRANT UPDATE ON TABLE public.attachments TO service_role;
GRANT UPDATE ON TABLE public.attachments TO supabase_auth_admin;
GRANT DELETE ON TABLE public.audit_logs TO authenticator;
GRANT DELETE ON TABLE public.audit_logs TO service_role;
GRANT DELETE ON TABLE public.audit_logs TO supabase_auth_admin;
GRANT INSERT ON TABLE public.audit_logs TO authenticator;
GRANT INSERT ON TABLE public.audit_logs TO service_role;
GRANT INSERT ON TABLE public.audit_logs TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.audit_logs TO authenticated;
GRANT MAINTAIN ON TABLE public.audit_logs TO authenticator;
GRANT MAINTAIN ON TABLE public.audit_logs TO service_role;
GRANT MAINTAIN ON TABLE public.audit_logs TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.audit_logs TO authenticated;
GRANT REFERENCES ON TABLE public.audit_logs TO authenticator;
GRANT REFERENCES ON TABLE public.audit_logs TO service_role;
GRANT REFERENCES ON TABLE public.audit_logs TO supabase_auth_admin;
GRANT SELECT ON TABLE public.audit_logs TO authenticated;
GRANT SELECT ON TABLE public.audit_logs TO authenticator;
GRANT SELECT ON TABLE public.audit_logs TO service_role;
GRANT SELECT ON TABLE public.audit_logs TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.audit_logs TO authenticated;
GRANT TRIGGER ON TABLE public.audit_logs TO authenticator;
GRANT TRIGGER ON TABLE public.audit_logs TO service_role;
GRANT TRIGGER ON TABLE public.audit_logs TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.audit_logs TO authenticator;
GRANT TRUNCATE ON TABLE public.audit_logs TO service_role;
GRANT TRUNCATE ON TABLE public.audit_logs TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.audit_logs TO authenticator;
GRANT UPDATE ON TABLE public.audit_logs TO service_role;
GRANT UPDATE ON TABLE public.audit_logs TO supabase_auth_admin;
GRANT DELETE ON TABLE public.branches TO authenticated;
GRANT DELETE ON TABLE public.branches TO authenticator;
GRANT DELETE ON TABLE public.branches TO service_role;
GRANT DELETE ON TABLE public.branches TO supabase_auth_admin;
GRANT INSERT ON TABLE public.branches TO authenticated;
GRANT INSERT ON TABLE public.branches TO authenticator;
GRANT INSERT ON TABLE public.branches TO service_role;
GRANT INSERT ON TABLE public.branches TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.branches TO authenticated;
GRANT MAINTAIN ON TABLE public.branches TO authenticator;
GRANT MAINTAIN ON TABLE public.branches TO service_role;
GRANT MAINTAIN ON TABLE public.branches TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.branches TO authenticated;
GRANT REFERENCES ON TABLE public.branches TO authenticator;
GRANT REFERENCES ON TABLE public.branches TO service_role;
GRANT REFERENCES ON TABLE public.branches TO supabase_auth_admin;
GRANT SELECT ON TABLE public.branches TO authenticated;
GRANT SELECT ON TABLE public.branches TO authenticator;
GRANT SELECT ON TABLE public.branches TO service_role;
GRANT SELECT ON TABLE public.branches TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.branches TO authenticated;
GRANT TRIGGER ON TABLE public.branches TO authenticator;
GRANT TRIGGER ON TABLE public.branches TO service_role;
GRANT TRIGGER ON TABLE public.branches TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.branches TO authenticator;
GRANT TRUNCATE ON TABLE public.branches TO service_role;
GRANT TRUNCATE ON TABLE public.branches TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.branches TO authenticated;
GRANT UPDATE ON TABLE public.branches TO authenticator;
GRANT UPDATE ON TABLE public.branches TO service_role;
GRANT UPDATE ON TABLE public.branches TO supabase_auth_admin;
GRANT DELETE ON TABLE public.cashbox_transactions TO authenticator;
GRANT DELETE ON TABLE public.cashbox_transactions TO service_role;
GRANT INSERT ON TABLE public.cashbox_transactions TO authenticator;
GRANT INSERT ON TABLE public.cashbox_transactions TO service_role;
GRANT MAINTAIN ON TABLE public.cashbox_transactions TO service_role;
GRANT REFERENCES ON TABLE public.cashbox_transactions TO service_role;
GRANT SELECT ON TABLE public.cashbox_transactions TO authenticated;
GRANT SELECT ON TABLE public.cashbox_transactions TO authenticator;
GRANT SELECT ON TABLE public.cashbox_transactions TO service_role;
GRANT TRIGGER ON TABLE public.cashbox_transactions TO service_role;
GRANT TRUNCATE ON TABLE public.cashbox_transactions TO service_role;
GRANT UPDATE ON TABLE public.cashbox_transactions TO authenticator;
GRANT UPDATE ON TABLE public.cashbox_transactions TO service_role;
GRANT DELETE ON TABLE public.certificates TO authenticated;
GRANT DELETE ON TABLE public.certificates TO authenticator;
GRANT DELETE ON TABLE public.certificates TO service_role;
GRANT DELETE ON TABLE public.certificates TO supabase_auth_admin;
GRANT INSERT ON TABLE public.certificates TO authenticated;
GRANT INSERT ON TABLE public.certificates TO authenticator;
GRANT INSERT ON TABLE public.certificates TO service_role;
GRANT INSERT ON TABLE public.certificates TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.certificates TO authenticated;
GRANT MAINTAIN ON TABLE public.certificates TO authenticator;
GRANT MAINTAIN ON TABLE public.certificates TO service_role;
GRANT MAINTAIN ON TABLE public.certificates TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.certificates TO authenticated;
GRANT REFERENCES ON TABLE public.certificates TO authenticator;
GRANT REFERENCES ON TABLE public.certificates TO service_role;
GRANT REFERENCES ON TABLE public.certificates TO supabase_auth_admin;
GRANT SELECT ON TABLE public.certificates TO authenticated;
GRANT SELECT ON TABLE public.certificates TO authenticator;
GRANT SELECT ON TABLE public.certificates TO service_role;
GRANT SELECT ON TABLE public.certificates TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.certificates TO authenticated;
GRANT TRIGGER ON TABLE public.certificates TO authenticator;
GRANT TRIGGER ON TABLE public.certificates TO service_role;
GRANT TRIGGER ON TABLE public.certificates TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.certificates TO authenticator;
GRANT TRUNCATE ON TABLE public.certificates TO service_role;
GRANT TRUNCATE ON TABLE public.certificates TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.certificates TO authenticated;
GRANT UPDATE ON TABLE public.certificates TO authenticator;
GRANT UPDATE ON TABLE public.certificates TO service_role;
GRANT UPDATE ON TABLE public.certificates TO supabase_auth_admin;
GRANT DELETE ON TABLE public.clinical_notes TO authenticated;
GRANT DELETE ON TABLE public.clinical_notes TO authenticator;
GRANT DELETE ON TABLE public.clinical_notes TO service_role;
GRANT DELETE ON TABLE public.clinical_notes TO supabase_auth_admin;
GRANT INSERT ON TABLE public.clinical_notes TO authenticated;
GRANT INSERT ON TABLE public.clinical_notes TO authenticator;
GRANT INSERT ON TABLE public.clinical_notes TO service_role;
GRANT INSERT ON TABLE public.clinical_notes TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.clinical_notes TO authenticated;
GRANT MAINTAIN ON TABLE public.clinical_notes TO authenticator;
GRANT MAINTAIN ON TABLE public.clinical_notes TO service_role;
GRANT MAINTAIN ON TABLE public.clinical_notes TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.clinical_notes TO authenticated;
GRANT REFERENCES ON TABLE public.clinical_notes TO authenticator;
GRANT REFERENCES ON TABLE public.clinical_notes TO service_role;
GRANT REFERENCES ON TABLE public.clinical_notes TO supabase_auth_admin;
GRANT SELECT ON TABLE public.clinical_notes TO authenticated;
GRANT SELECT ON TABLE public.clinical_notes TO authenticator;
GRANT SELECT ON TABLE public.clinical_notes TO service_role;
GRANT SELECT ON TABLE public.clinical_notes TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.clinical_notes TO authenticated;
GRANT TRIGGER ON TABLE public.clinical_notes TO authenticator;
GRANT TRIGGER ON TABLE public.clinical_notes TO service_role;
GRANT TRIGGER ON TABLE public.clinical_notes TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.clinical_notes TO authenticator;
GRANT TRUNCATE ON TABLE public.clinical_notes TO service_role;
GRANT TRUNCATE ON TABLE public.clinical_notes TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.clinical_notes TO authenticated;
GRANT UPDATE ON TABLE public.clinical_notes TO authenticator;
GRANT UPDATE ON TABLE public.clinical_notes TO service_role;
GRANT UPDATE ON TABLE public.clinical_notes TO supabase_auth_admin;
GRANT DELETE ON TABLE public.corporate_accounts TO authenticated;
GRANT DELETE ON TABLE public.corporate_accounts TO authenticator;
GRANT DELETE ON TABLE public.corporate_accounts TO service_role;
GRANT DELETE ON TABLE public.corporate_accounts TO supabase_auth_admin;
GRANT INSERT ON TABLE public.corporate_accounts TO authenticated;
GRANT INSERT ON TABLE public.corporate_accounts TO authenticator;
GRANT INSERT ON TABLE public.corporate_accounts TO service_role;
GRANT INSERT ON TABLE public.corporate_accounts TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.corporate_accounts TO authenticated;
GRANT MAINTAIN ON TABLE public.corporate_accounts TO authenticator;
GRANT MAINTAIN ON TABLE public.corporate_accounts TO service_role;
GRANT MAINTAIN ON TABLE public.corporate_accounts TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.corporate_accounts TO authenticated;
GRANT REFERENCES ON TABLE public.corporate_accounts TO authenticator;
GRANT REFERENCES ON TABLE public.corporate_accounts TO service_role;
GRANT REFERENCES ON TABLE public.corporate_accounts TO supabase_auth_admin;
GRANT SELECT ON TABLE public.corporate_accounts TO authenticated;
GRANT SELECT ON TABLE public.corporate_accounts TO authenticator;
GRANT SELECT ON TABLE public.corporate_accounts TO service_role;
GRANT SELECT ON TABLE public.corporate_accounts TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.corporate_accounts TO authenticated;
GRANT TRIGGER ON TABLE public.corporate_accounts TO authenticator;
GRANT TRIGGER ON TABLE public.corporate_accounts TO service_role;
GRANT TRIGGER ON TABLE public.corporate_accounts TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.corporate_accounts TO authenticator;
GRANT TRUNCATE ON TABLE public.corporate_accounts TO service_role;
GRANT TRUNCATE ON TABLE public.corporate_accounts TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.corporate_accounts TO authenticated;
GRANT UPDATE ON TABLE public.corporate_accounts TO authenticator;
GRANT UPDATE ON TABLE public.corporate_accounts TO service_role;
GRANT UPDATE ON TABLE public.corporate_accounts TO supabase_auth_admin;
GRANT DELETE ON TABLE public.departments TO authenticated;
GRANT DELETE ON TABLE public.departments TO authenticator;
GRANT DELETE ON TABLE public.departments TO service_role;
GRANT DELETE ON TABLE public.departments TO supabase_auth_admin;
GRANT INSERT ON TABLE public.departments TO authenticated;
GRANT INSERT ON TABLE public.departments TO authenticator;
GRANT INSERT ON TABLE public.departments TO service_role;
GRANT INSERT ON TABLE public.departments TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.departments TO authenticated;
GRANT MAINTAIN ON TABLE public.departments TO authenticator;
GRANT MAINTAIN ON TABLE public.departments TO service_role;
GRANT MAINTAIN ON TABLE public.departments TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.departments TO authenticated;
GRANT REFERENCES ON TABLE public.departments TO authenticator;
GRANT REFERENCES ON TABLE public.departments TO service_role;
GRANT REFERENCES ON TABLE public.departments TO supabase_auth_admin;
GRANT SELECT ON TABLE public.departments TO authenticated;
GRANT SELECT ON TABLE public.departments TO authenticator;
GRANT SELECT ON TABLE public.departments TO service_role;
GRANT SELECT ON TABLE public.departments TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.departments TO authenticated;
GRANT TRIGGER ON TABLE public.departments TO authenticator;
GRANT TRIGGER ON TABLE public.departments TO service_role;
GRANT TRIGGER ON TABLE public.departments TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.departments TO authenticator;
GRANT TRUNCATE ON TABLE public.departments TO service_role;
GRANT TRUNCATE ON TABLE public.departments TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.departments TO authenticated;
GRANT UPDATE ON TABLE public.departments TO authenticator;
GRANT UPDATE ON TABLE public.departments TO service_role;
GRANT UPDATE ON TABLE public.departments TO supabase_auth_admin;
GRANT DELETE ON TABLE public.diagnoses TO authenticated;
GRANT DELETE ON TABLE public.diagnoses TO authenticator;
GRANT DELETE ON TABLE public.diagnoses TO service_role;
GRANT DELETE ON TABLE public.diagnoses TO supabase_auth_admin;
GRANT INSERT ON TABLE public.diagnoses TO authenticated;
GRANT INSERT ON TABLE public.diagnoses TO authenticator;
GRANT INSERT ON TABLE public.diagnoses TO service_role;
GRANT INSERT ON TABLE public.diagnoses TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.diagnoses TO authenticated;
GRANT MAINTAIN ON TABLE public.diagnoses TO authenticator;
GRANT MAINTAIN ON TABLE public.diagnoses TO service_role;
GRANT MAINTAIN ON TABLE public.diagnoses TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.diagnoses TO authenticated;
GRANT REFERENCES ON TABLE public.diagnoses TO authenticator;
GRANT REFERENCES ON TABLE public.diagnoses TO service_role;
GRANT REFERENCES ON TABLE public.diagnoses TO supabase_auth_admin;
GRANT SELECT ON TABLE public.diagnoses TO authenticated;
GRANT SELECT ON TABLE public.diagnoses TO authenticator;
GRANT SELECT ON TABLE public.diagnoses TO service_role;
GRANT SELECT ON TABLE public.diagnoses TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.diagnoses TO authenticated;
GRANT TRIGGER ON TABLE public.diagnoses TO authenticator;
GRANT TRIGGER ON TABLE public.diagnoses TO service_role;
GRANT TRIGGER ON TABLE public.diagnoses TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.diagnoses TO authenticator;
GRANT TRUNCATE ON TABLE public.diagnoses TO service_role;
GRANT TRUNCATE ON TABLE public.diagnoses TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.diagnoses TO authenticated;
GRANT UPDATE ON TABLE public.diagnoses TO authenticator;
GRANT UPDATE ON TABLE public.diagnoses TO service_role;
GRANT UPDATE ON TABLE public.diagnoses TO supabase_auth_admin;
GRANT DELETE ON TABLE public.employees TO authenticated;
GRANT DELETE ON TABLE public.employees TO authenticator;
GRANT DELETE ON TABLE public.employees TO service_role;
GRANT DELETE ON TABLE public.employees TO supabase_auth_admin;
GRANT INSERT ON TABLE public.employees TO authenticated;
GRANT INSERT ON TABLE public.employees TO authenticator;
GRANT INSERT ON TABLE public.employees TO service_role;
GRANT INSERT ON TABLE public.employees TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.employees TO authenticated;
GRANT MAINTAIN ON TABLE public.employees TO authenticator;
GRANT MAINTAIN ON TABLE public.employees TO service_role;
GRANT MAINTAIN ON TABLE public.employees TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.employees TO authenticated;
GRANT REFERENCES ON TABLE public.employees TO authenticator;
GRANT REFERENCES ON TABLE public.employees TO service_role;
GRANT REFERENCES ON TABLE public.employees TO supabase_auth_admin;
GRANT SELECT ON TABLE public.employees TO authenticated;
GRANT SELECT ON TABLE public.employees TO authenticator;
GRANT SELECT ON TABLE public.employees TO service_role;
GRANT SELECT ON TABLE public.employees TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.employees TO authenticated;
GRANT TRIGGER ON TABLE public.employees TO authenticator;
GRANT TRIGGER ON TABLE public.employees TO service_role;
GRANT TRIGGER ON TABLE public.employees TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.employees TO authenticator;
GRANT TRUNCATE ON TABLE public.employees TO service_role;
GRANT TRUNCATE ON TABLE public.employees TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.employees TO authenticated;
GRANT UPDATE ON TABLE public.employees TO authenticator;
GRANT UPDATE ON TABLE public.employees TO service_role;
GRANT UPDATE ON TABLE public.employees TO supabase_auth_admin;
GRANT DELETE ON TABLE public.expenses TO authenticator;
GRANT DELETE ON TABLE public.expenses TO service_role;
GRANT DELETE ON TABLE public.expenses TO supabase_auth_admin;
GRANT INSERT ON TABLE public.expenses TO authenticator;
GRANT INSERT ON TABLE public.expenses TO service_role;
GRANT INSERT ON TABLE public.expenses TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.expenses TO authenticated;
GRANT MAINTAIN ON TABLE public.expenses TO authenticator;
GRANT MAINTAIN ON TABLE public.expenses TO service_role;
GRANT MAINTAIN ON TABLE public.expenses TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.expenses TO authenticator;
GRANT REFERENCES ON TABLE public.expenses TO service_role;
GRANT REFERENCES ON TABLE public.expenses TO supabase_auth_admin;
GRANT SELECT ON TABLE public.expenses TO authenticated;
GRANT SELECT ON TABLE public.expenses TO authenticator;
GRANT SELECT ON TABLE public.expenses TO service_role;
GRANT SELECT ON TABLE public.expenses TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.expenses TO authenticator;
GRANT TRIGGER ON TABLE public.expenses TO service_role;
GRANT TRIGGER ON TABLE public.expenses TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.expenses TO authenticator;
GRANT TRUNCATE ON TABLE public.expenses TO service_role;
GRANT TRUNCATE ON TABLE public.expenses TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.expenses TO authenticator;
GRANT UPDATE ON TABLE public.expenses TO service_role;
GRANT UPDATE ON TABLE public.expenses TO supabase_auth_admin;
GRANT DELETE ON TABLE public.followups TO authenticated;
GRANT DELETE ON TABLE public.followups TO authenticator;
GRANT DELETE ON TABLE public.followups TO service_role;
GRANT DELETE ON TABLE public.followups TO supabase_auth_admin;
GRANT INSERT ON TABLE public.followups TO authenticated;
GRANT INSERT ON TABLE public.followups TO authenticator;
GRANT INSERT ON TABLE public.followups TO service_role;
GRANT INSERT ON TABLE public.followups TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.followups TO authenticated;
GRANT MAINTAIN ON TABLE public.followups TO authenticator;
GRANT MAINTAIN ON TABLE public.followups TO service_role;
GRANT MAINTAIN ON TABLE public.followups TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.followups TO authenticated;
GRANT REFERENCES ON TABLE public.followups TO authenticator;
GRANT REFERENCES ON TABLE public.followups TO service_role;
GRANT REFERENCES ON TABLE public.followups TO supabase_auth_admin;
GRANT SELECT ON TABLE public.followups TO authenticated;
GRANT SELECT ON TABLE public.followups TO authenticator;
GRANT SELECT ON TABLE public.followups TO service_role;
GRANT SELECT ON TABLE public.followups TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.followups TO authenticated;
GRANT TRIGGER ON TABLE public.followups TO authenticator;
GRANT TRIGGER ON TABLE public.followups TO service_role;
GRANT TRIGGER ON TABLE public.followups TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.followups TO authenticator;
GRANT TRUNCATE ON TABLE public.followups TO service_role;
GRANT TRUNCATE ON TABLE public.followups TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.followups TO authenticated;
GRANT UPDATE ON TABLE public.followups TO authenticator;
GRANT UPDATE ON TABLE public.followups TO service_role;
GRANT UPDATE ON TABLE public.followups TO supabase_auth_admin;
GRANT DELETE ON TABLE public.insurance_claim_items TO authenticator;
GRANT DELETE ON TABLE public.insurance_claim_items TO service_role;
GRANT INSERT ON TABLE public.insurance_claim_items TO authenticator;
GRANT INSERT ON TABLE public.insurance_claim_items TO service_role;
GRANT MAINTAIN ON TABLE public.insurance_claim_items TO service_role;
GRANT REFERENCES ON TABLE public.insurance_claim_items TO service_role;
GRANT SELECT ON TABLE public.insurance_claim_items TO authenticated;
GRANT SELECT ON TABLE public.insurance_claim_items TO authenticator;
GRANT SELECT ON TABLE public.insurance_claim_items TO service_role;
GRANT TRIGGER ON TABLE public.insurance_claim_items TO service_role;
GRANT TRUNCATE ON TABLE public.insurance_claim_items TO service_role;
GRANT UPDATE ON TABLE public.insurance_claim_items TO authenticator;
GRANT UPDATE ON TABLE public.insurance_claim_items TO service_role;
GRANT DELETE ON TABLE public.insurance_claim_payments TO authenticator;
GRANT DELETE ON TABLE public.insurance_claim_payments TO service_role;
GRANT INSERT ON TABLE public.insurance_claim_payments TO authenticator;
GRANT INSERT ON TABLE public.insurance_claim_payments TO service_role;
GRANT MAINTAIN ON TABLE public.insurance_claim_payments TO service_role;
GRANT REFERENCES ON TABLE public.insurance_claim_payments TO service_role;
GRANT SELECT ON TABLE public.insurance_claim_payments TO authenticated;
GRANT SELECT ON TABLE public.insurance_claim_payments TO authenticator;
GRANT SELECT ON TABLE public.insurance_claim_payments TO service_role;
GRANT TRIGGER ON TABLE public.insurance_claim_payments TO service_role;
GRANT TRUNCATE ON TABLE public.insurance_claim_payments TO service_role;
GRANT UPDATE ON TABLE public.insurance_claim_payments TO authenticator;
GRANT UPDATE ON TABLE public.insurance_claim_payments TO service_role;
GRANT DELETE ON TABLE public.insurance_claims TO authenticator;
GRANT DELETE ON TABLE public.insurance_claims TO service_role;
GRANT INSERT ON TABLE public.insurance_claims TO authenticator;
GRANT INSERT ON TABLE public.insurance_claims TO service_role;
GRANT MAINTAIN ON TABLE public.insurance_claims TO service_role;
GRANT REFERENCES ON TABLE public.insurance_claims TO service_role;
GRANT SELECT ON TABLE public.insurance_claims TO authenticated;
GRANT SELECT ON TABLE public.insurance_claims TO authenticator;
GRANT SELECT ON TABLE public.insurance_claims TO service_role;
GRANT TRIGGER ON TABLE public.insurance_claims TO service_role;
GRANT TRUNCATE ON TABLE public.insurance_claims TO service_role;
GRANT UPDATE ON TABLE public.insurance_claims TO authenticator;
GRANT UPDATE ON TABLE public.insurance_claims TO service_role;
GRANT DELETE ON TABLE public.insurance_companies TO authenticator;
GRANT DELETE ON TABLE public.insurance_companies TO service_role;
GRANT INSERT ON TABLE public.insurance_companies TO authenticated;
GRANT INSERT ON TABLE public.insurance_companies TO authenticator;
GRANT INSERT ON TABLE public.insurance_companies TO service_role;
GRANT MAINTAIN ON TABLE public.insurance_companies TO service_role;
GRANT REFERENCES ON TABLE public.insurance_companies TO service_role;
GRANT SELECT ON TABLE public.insurance_companies TO authenticated;
GRANT SELECT ON TABLE public.insurance_companies TO authenticator;
GRANT SELECT ON TABLE public.insurance_companies TO service_role;
GRANT TRIGGER ON TABLE public.insurance_companies TO service_role;
GRANT TRUNCATE ON TABLE public.insurance_companies TO service_role;
GRANT UPDATE ON TABLE public.insurance_companies TO authenticated;
GRANT UPDATE ON TABLE public.insurance_companies TO authenticator;
GRANT UPDATE ON TABLE public.insurance_companies TO service_role;
GRANT DELETE ON TABLE public.insurance_coverage_rules TO authenticator;
GRANT DELETE ON TABLE public.insurance_coverage_rules TO service_role;
GRANT INSERT ON TABLE public.insurance_coverage_rules TO authenticated;
GRANT INSERT ON TABLE public.insurance_coverage_rules TO authenticator;
GRANT INSERT ON TABLE public.insurance_coverage_rules TO service_role;
GRANT MAINTAIN ON TABLE public.insurance_coverage_rules TO service_role;
GRANT REFERENCES ON TABLE public.insurance_coverage_rules TO service_role;
GRANT SELECT ON TABLE public.insurance_coverage_rules TO authenticated;
GRANT SELECT ON TABLE public.insurance_coverage_rules TO authenticator;
GRANT SELECT ON TABLE public.insurance_coverage_rules TO service_role;
GRANT TRIGGER ON TABLE public.insurance_coverage_rules TO service_role;
GRANT TRUNCATE ON TABLE public.insurance_coverage_rules TO service_role;
GRANT UPDATE ON TABLE public.insurance_coverage_rules TO authenticated;
GRANT UPDATE ON TABLE public.insurance_coverage_rules TO authenticator;
GRANT UPDATE ON TABLE public.insurance_coverage_rules TO service_role;
GRANT DELETE ON TABLE public.insurance_plans TO authenticator;
GRANT DELETE ON TABLE public.insurance_plans TO service_role;
GRANT INSERT ON TABLE public.insurance_plans TO authenticated;
GRANT INSERT ON TABLE public.insurance_plans TO authenticator;
GRANT INSERT ON TABLE public.insurance_plans TO service_role;
GRANT MAINTAIN ON TABLE public.insurance_plans TO service_role;
GRANT REFERENCES ON TABLE public.insurance_plans TO service_role;
GRANT SELECT ON TABLE public.insurance_plans TO authenticated;
GRANT SELECT ON TABLE public.insurance_plans TO authenticator;
GRANT SELECT ON TABLE public.insurance_plans TO service_role;
GRANT TRIGGER ON TABLE public.insurance_plans TO service_role;
GRANT TRUNCATE ON TABLE public.insurance_plans TO service_role;
GRANT UPDATE ON TABLE public.insurance_plans TO authenticated;
GRANT UPDATE ON TABLE public.insurance_plans TO authenticator;
GRANT UPDATE ON TABLE public.insurance_plans TO service_role;
GRANT DELETE ON TABLE public.insurance_prior_authorizations TO authenticator;
GRANT DELETE ON TABLE public.insurance_prior_authorizations TO service_role;
GRANT INSERT ON TABLE public.insurance_prior_authorizations TO authenticator;
GRANT INSERT ON TABLE public.insurance_prior_authorizations TO service_role;
GRANT MAINTAIN ON TABLE public.insurance_prior_authorizations TO service_role;
GRANT REFERENCES ON TABLE public.insurance_prior_authorizations TO service_role;
GRANT SELECT ON TABLE public.insurance_prior_authorizations TO authenticated;
GRANT SELECT ON TABLE public.insurance_prior_authorizations TO authenticator;
GRANT SELECT ON TABLE public.insurance_prior_authorizations TO service_role;
GRANT TRIGGER ON TABLE public.insurance_prior_authorizations TO service_role;
GRANT TRUNCATE ON TABLE public.insurance_prior_authorizations TO service_role;
GRANT UPDATE ON TABLE public.insurance_prior_authorizations TO authenticator;
GRANT UPDATE ON TABLE public.insurance_prior_authorizations TO service_role;
GRANT DELETE ON TABLE public.invoice_items TO authenticator;
GRANT DELETE ON TABLE public.invoice_items TO service_role;
GRANT DELETE ON TABLE public.invoice_items TO supabase_auth_admin;
GRANT INSERT ON TABLE public.invoice_items TO authenticator;
GRANT INSERT ON TABLE public.invoice_items TO service_role;
GRANT INSERT ON TABLE public.invoice_items TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.invoice_items TO authenticated;
GRANT MAINTAIN ON TABLE public.invoice_items TO authenticator;
GRANT MAINTAIN ON TABLE public.invoice_items TO service_role;
GRANT MAINTAIN ON TABLE public.invoice_items TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.invoice_items TO authenticator;
GRANT REFERENCES ON TABLE public.invoice_items TO service_role;
GRANT REFERENCES ON TABLE public.invoice_items TO supabase_auth_admin;
GRANT SELECT ON TABLE public.invoice_items TO authenticated;
GRANT SELECT ON TABLE public.invoice_items TO authenticator;
GRANT SELECT ON TABLE public.invoice_items TO service_role;
GRANT SELECT ON TABLE public.invoice_items TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.invoice_items TO authenticator;
GRANT TRIGGER ON TABLE public.invoice_items TO service_role;
GRANT TRIGGER ON TABLE public.invoice_items TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.invoice_items TO authenticator;
GRANT TRUNCATE ON TABLE public.invoice_items TO service_role;
GRANT TRUNCATE ON TABLE public.invoice_items TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.invoice_items TO authenticator;
GRANT UPDATE ON TABLE public.invoice_items TO service_role;
GRANT UPDATE ON TABLE public.invoice_items TO supabase_auth_admin;
GRANT DELETE ON TABLE public.invoices TO authenticator;
GRANT DELETE ON TABLE public.invoices TO service_role;
GRANT DELETE ON TABLE public.invoices TO supabase_auth_admin;
GRANT INSERT ON TABLE public.invoices TO authenticator;
GRANT INSERT ON TABLE public.invoices TO service_role;
GRANT INSERT ON TABLE public.invoices TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.invoices TO authenticated;
GRANT MAINTAIN ON TABLE public.invoices TO authenticator;
GRANT MAINTAIN ON TABLE public.invoices TO service_role;
GRANT MAINTAIN ON TABLE public.invoices TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.invoices TO authenticator;
GRANT REFERENCES ON TABLE public.invoices TO service_role;
GRANT REFERENCES ON TABLE public.invoices TO supabase_auth_admin;
GRANT SELECT ON TABLE public.invoices TO authenticated;
GRANT SELECT ON TABLE public.invoices TO authenticator;
GRANT SELECT ON TABLE public.invoices TO service_role;
GRANT SELECT ON TABLE public.invoices TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.invoices TO authenticator;
GRANT TRIGGER ON TABLE public.invoices TO service_role;
GRANT TRIGGER ON TABLE public.invoices TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.invoices TO authenticator;
GRANT TRUNCATE ON TABLE public.invoices TO service_role;
GRANT TRUNCATE ON TABLE public.invoices TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.invoices TO authenticator;
GRANT UPDATE ON TABLE public.invoices TO service_role;
GRANT UPDATE ON TABLE public.invoices TO supabase_auth_admin;
GRANT DELETE ON TABLE public.lab_order_items TO authenticator;
GRANT DELETE ON TABLE public.lab_order_items TO service_role;
GRANT DELETE ON TABLE public.lab_order_items TO supabase_auth_admin;
GRANT INSERT ON TABLE public.lab_order_items TO authenticator;
GRANT INSERT ON TABLE public.lab_order_items TO service_role;
GRANT INSERT ON TABLE public.lab_order_items TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.lab_order_items TO authenticated;
GRANT MAINTAIN ON TABLE public.lab_order_items TO authenticator;
GRANT MAINTAIN ON TABLE public.lab_order_items TO service_role;
GRANT MAINTAIN ON TABLE public.lab_order_items TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.lab_order_items TO authenticator;
GRANT REFERENCES ON TABLE public.lab_order_items TO service_role;
GRANT REFERENCES ON TABLE public.lab_order_items TO supabase_auth_admin;
GRANT SELECT ON TABLE public.lab_order_items TO authenticated;
GRANT SELECT ON TABLE public.lab_order_items TO authenticator;
GRANT SELECT ON TABLE public.lab_order_items TO service_role;
GRANT SELECT ON TABLE public.lab_order_items TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.lab_order_items TO authenticator;
GRANT TRIGGER ON TABLE public.lab_order_items TO service_role;
GRANT TRIGGER ON TABLE public.lab_order_items TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.lab_order_items TO authenticator;
GRANT TRUNCATE ON TABLE public.lab_order_items TO service_role;
GRANT TRUNCATE ON TABLE public.lab_order_items TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.lab_order_items TO authenticator;
GRANT UPDATE ON TABLE public.lab_order_items TO service_role;
GRANT UPDATE ON TABLE public.lab_order_items TO supabase_auth_admin;
GRANT DELETE ON TABLE public.lab_orders TO authenticated;
GRANT DELETE ON TABLE public.lab_orders TO authenticator;
GRANT DELETE ON TABLE public.lab_orders TO service_role;
GRANT DELETE ON TABLE public.lab_orders TO supabase_auth_admin;
GRANT INSERT ON TABLE public.lab_orders TO authenticated;
GRANT INSERT ON TABLE public.lab_orders TO authenticator;
GRANT INSERT ON TABLE public.lab_orders TO service_role;
GRANT INSERT ON TABLE public.lab_orders TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.lab_orders TO authenticated;
GRANT MAINTAIN ON TABLE public.lab_orders TO authenticator;
GRANT MAINTAIN ON TABLE public.lab_orders TO service_role;
GRANT MAINTAIN ON TABLE public.lab_orders TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.lab_orders TO authenticated;
GRANT REFERENCES ON TABLE public.lab_orders TO authenticator;
GRANT REFERENCES ON TABLE public.lab_orders TO service_role;
GRANT REFERENCES ON TABLE public.lab_orders TO supabase_auth_admin;
GRANT SELECT ON TABLE public.lab_orders TO authenticated;
GRANT SELECT ON TABLE public.lab_orders TO authenticator;
GRANT SELECT ON TABLE public.lab_orders TO service_role;
GRANT SELECT ON TABLE public.lab_orders TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.lab_orders TO authenticated;
GRANT TRIGGER ON TABLE public.lab_orders TO authenticator;
GRANT TRIGGER ON TABLE public.lab_orders TO service_role;
GRANT TRIGGER ON TABLE public.lab_orders TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.lab_orders TO authenticator;
GRANT TRUNCATE ON TABLE public.lab_orders TO service_role;
GRANT TRUNCATE ON TABLE public.lab_orders TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.lab_orders TO authenticated;
GRANT UPDATE ON TABLE public.lab_orders TO authenticator;
GRANT UPDATE ON TABLE public.lab_orders TO service_role;
GRANT UPDATE ON TABLE public.lab_orders TO supabase_auth_admin;
GRANT DELETE ON TABLE public.lab_parameters TO authenticated;
GRANT DELETE ON TABLE public.lab_parameters TO authenticator;
GRANT DELETE ON TABLE public.lab_parameters TO service_role;
GRANT DELETE ON TABLE public.lab_parameters TO supabase_auth_admin;
GRANT INSERT ON TABLE public.lab_parameters TO authenticated;
GRANT INSERT ON TABLE public.lab_parameters TO authenticator;
GRANT INSERT ON TABLE public.lab_parameters TO service_role;
GRANT INSERT ON TABLE public.lab_parameters TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.lab_parameters TO authenticated;
GRANT MAINTAIN ON TABLE public.lab_parameters TO authenticator;
GRANT MAINTAIN ON TABLE public.lab_parameters TO service_role;
GRANT MAINTAIN ON TABLE public.lab_parameters TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.lab_parameters TO authenticated;
GRANT REFERENCES ON TABLE public.lab_parameters TO authenticator;
GRANT REFERENCES ON TABLE public.lab_parameters TO service_role;
GRANT REFERENCES ON TABLE public.lab_parameters TO supabase_auth_admin;
GRANT SELECT ON TABLE public.lab_parameters TO authenticated;
GRANT SELECT ON TABLE public.lab_parameters TO authenticator;
GRANT SELECT ON TABLE public.lab_parameters TO service_role;
GRANT SELECT ON TABLE public.lab_parameters TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.lab_parameters TO authenticated;
GRANT TRIGGER ON TABLE public.lab_parameters TO authenticator;
GRANT TRIGGER ON TABLE public.lab_parameters TO service_role;
GRANT TRIGGER ON TABLE public.lab_parameters TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.lab_parameters TO authenticator;
GRANT TRUNCATE ON TABLE public.lab_parameters TO service_role;
GRANT TRUNCATE ON TABLE public.lab_parameters TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.lab_parameters TO authenticated;
GRANT UPDATE ON TABLE public.lab_parameters TO authenticator;
GRANT UPDATE ON TABLE public.lab_parameters TO service_role;
GRANT UPDATE ON TABLE public.lab_parameters TO supabase_auth_admin;
GRANT DELETE ON TABLE public.lab_reference_ranges TO authenticated;
GRANT DELETE ON TABLE public.lab_reference_ranges TO authenticator;
GRANT DELETE ON TABLE public.lab_reference_ranges TO service_role;
GRANT DELETE ON TABLE public.lab_reference_ranges TO supabase_auth_admin;
GRANT INSERT ON TABLE public.lab_reference_ranges TO authenticated;
GRANT INSERT ON TABLE public.lab_reference_ranges TO authenticator;
GRANT INSERT ON TABLE public.lab_reference_ranges TO service_role;
GRANT INSERT ON TABLE public.lab_reference_ranges TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.lab_reference_ranges TO authenticated;
GRANT MAINTAIN ON TABLE public.lab_reference_ranges TO authenticator;
GRANT MAINTAIN ON TABLE public.lab_reference_ranges TO service_role;
GRANT MAINTAIN ON TABLE public.lab_reference_ranges TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.lab_reference_ranges TO authenticated;
GRANT REFERENCES ON TABLE public.lab_reference_ranges TO authenticator;
GRANT REFERENCES ON TABLE public.lab_reference_ranges TO service_role;
GRANT REFERENCES ON TABLE public.lab_reference_ranges TO supabase_auth_admin;
GRANT SELECT ON TABLE public.lab_reference_ranges TO authenticated;
GRANT SELECT ON TABLE public.lab_reference_ranges TO authenticator;
GRANT SELECT ON TABLE public.lab_reference_ranges TO service_role;
GRANT SELECT ON TABLE public.lab_reference_ranges TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.lab_reference_ranges TO authenticated;
GRANT TRIGGER ON TABLE public.lab_reference_ranges TO authenticator;
GRANT TRIGGER ON TABLE public.lab_reference_ranges TO service_role;
GRANT TRIGGER ON TABLE public.lab_reference_ranges TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.lab_reference_ranges TO authenticator;
GRANT TRUNCATE ON TABLE public.lab_reference_ranges TO service_role;
GRANT TRUNCATE ON TABLE public.lab_reference_ranges TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.lab_reference_ranges TO authenticated;
GRANT UPDATE ON TABLE public.lab_reference_ranges TO authenticator;
GRANT UPDATE ON TABLE public.lab_reference_ranges TO service_role;
GRANT UPDATE ON TABLE public.lab_reference_ranges TO supabase_auth_admin;
GRANT DELETE ON TABLE public.lab_results TO authenticated;
GRANT DELETE ON TABLE public.lab_results TO authenticator;
GRANT DELETE ON TABLE public.lab_results TO service_role;
GRANT DELETE ON TABLE public.lab_results TO supabase_auth_admin;
GRANT INSERT ON TABLE public.lab_results TO authenticated;
GRANT INSERT ON TABLE public.lab_results TO authenticator;
GRANT INSERT ON TABLE public.lab_results TO service_role;
GRANT INSERT ON TABLE public.lab_results TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.lab_results TO authenticated;
GRANT MAINTAIN ON TABLE public.lab_results TO authenticator;
GRANT MAINTAIN ON TABLE public.lab_results TO service_role;
GRANT MAINTAIN ON TABLE public.lab_results TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.lab_results TO authenticated;
GRANT REFERENCES ON TABLE public.lab_results TO authenticator;
GRANT REFERENCES ON TABLE public.lab_results TO service_role;
GRANT REFERENCES ON TABLE public.lab_results TO supabase_auth_admin;
GRANT SELECT ON TABLE public.lab_results TO authenticated;
GRANT SELECT ON TABLE public.lab_results TO authenticator;
GRANT SELECT ON TABLE public.lab_results TO service_role;
GRANT SELECT ON TABLE public.lab_results TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.lab_results TO authenticated;
GRANT TRIGGER ON TABLE public.lab_results TO authenticator;
GRANT TRIGGER ON TABLE public.lab_results TO service_role;
GRANT TRIGGER ON TABLE public.lab_results TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.lab_results TO authenticator;
GRANT TRUNCATE ON TABLE public.lab_results TO service_role;
GRANT TRUNCATE ON TABLE public.lab_results TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.lab_results TO authenticated;
GRANT UPDATE ON TABLE public.lab_results TO authenticator;
GRANT UPDATE ON TABLE public.lab_results TO service_role;
GRANT UPDATE ON TABLE public.lab_results TO supabase_auth_admin;
GRANT DELETE ON TABLE public.lab_tests TO authenticated;
GRANT DELETE ON TABLE public.lab_tests TO authenticator;
GRANT DELETE ON TABLE public.lab_tests TO service_role;
GRANT DELETE ON TABLE public.lab_tests TO supabase_auth_admin;
GRANT INSERT ON TABLE public.lab_tests TO authenticated;
GRANT INSERT ON TABLE public.lab_tests TO authenticator;
GRANT INSERT ON TABLE public.lab_tests TO service_role;
GRANT INSERT ON TABLE public.lab_tests TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.lab_tests TO authenticated;
GRANT MAINTAIN ON TABLE public.lab_tests TO authenticator;
GRANT MAINTAIN ON TABLE public.lab_tests TO service_role;
GRANT MAINTAIN ON TABLE public.lab_tests TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.lab_tests TO authenticated;
GRANT REFERENCES ON TABLE public.lab_tests TO authenticator;
GRANT REFERENCES ON TABLE public.lab_tests TO service_role;
GRANT REFERENCES ON TABLE public.lab_tests TO supabase_auth_admin;
GRANT SELECT ON TABLE public.lab_tests TO authenticated;
GRANT SELECT ON TABLE public.lab_tests TO authenticator;
GRANT SELECT ON TABLE public.lab_tests TO service_role;
GRANT SELECT ON TABLE public.lab_tests TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.lab_tests TO authenticated;
GRANT TRIGGER ON TABLE public.lab_tests TO authenticator;
GRANT TRIGGER ON TABLE public.lab_tests TO service_role;
GRANT TRIGGER ON TABLE public.lab_tests TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.lab_tests TO authenticator;
GRANT TRUNCATE ON TABLE public.lab_tests TO service_role;
GRANT TRUNCATE ON TABLE public.lab_tests TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.lab_tests TO authenticated;
GRANT UPDATE ON TABLE public.lab_tests TO authenticator;
GRANT UPDATE ON TABLE public.lab_tests TO service_role;
GRANT UPDATE ON TABLE public.lab_tests TO supabase_auth_admin;
GRANT DELETE ON TABLE public.medical_certificates TO authenticator;
GRANT DELETE ON TABLE public.medical_certificates TO service_role;
GRANT INSERT ON TABLE public.medical_certificates TO authenticator;
GRANT INSERT ON TABLE public.medical_certificates TO service_role;
GRANT MAINTAIN ON TABLE public.medical_certificates TO authenticated;
GRANT MAINTAIN ON TABLE public.medical_certificates TO service_role;
GRANT REFERENCES ON TABLE public.medical_certificates TO service_role;
GRANT SELECT ON TABLE public.medical_certificates TO authenticated;
GRANT SELECT ON TABLE public.medical_certificates TO authenticator;
GRANT SELECT ON TABLE public.medical_certificates TO service_role;
GRANT TRIGGER ON TABLE public.medical_certificates TO service_role;
GRANT TRUNCATE ON TABLE public.medical_certificates TO service_role;
GRANT UPDATE ON TABLE public.medical_certificates TO authenticator;
GRANT UPDATE ON TABLE public.medical_certificates TO service_role;
GRANT DELETE ON TABLE public.medicines TO authenticated;
GRANT DELETE ON TABLE public.medicines TO authenticator;
GRANT DELETE ON TABLE public.medicines TO service_role;
GRANT DELETE ON TABLE public.medicines TO supabase_auth_admin;
GRANT INSERT ON TABLE public.medicines TO authenticated;
GRANT INSERT ON TABLE public.medicines TO authenticator;
GRANT INSERT ON TABLE public.medicines TO service_role;
GRANT INSERT ON TABLE public.medicines TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.medicines TO authenticated;
GRANT MAINTAIN ON TABLE public.medicines TO authenticator;
GRANT MAINTAIN ON TABLE public.medicines TO service_role;
GRANT MAINTAIN ON TABLE public.medicines TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.medicines TO authenticated;
GRANT REFERENCES ON TABLE public.medicines TO authenticator;
GRANT REFERENCES ON TABLE public.medicines TO service_role;
GRANT REFERENCES ON TABLE public.medicines TO supabase_auth_admin;
GRANT SELECT ON TABLE public.medicines TO authenticated;
GRANT SELECT ON TABLE public.medicines TO authenticator;
GRANT SELECT ON TABLE public.medicines TO service_role;
GRANT SELECT ON TABLE public.medicines TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.medicines TO authenticated;
GRANT TRIGGER ON TABLE public.medicines TO authenticator;
GRANT TRIGGER ON TABLE public.medicines TO service_role;
GRANT TRIGGER ON TABLE public.medicines TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.medicines TO authenticator;
GRANT TRUNCATE ON TABLE public.medicines TO service_role;
GRANT TRUNCATE ON TABLE public.medicines TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.medicines TO authenticated;
GRANT UPDATE ON TABLE public.medicines TO authenticator;
GRANT UPDATE ON TABLE public.medicines TO service_role;
GRANT UPDATE ON TABLE public.medicines TO supabase_auth_admin;
GRANT DELETE ON TABLE public.medicines_2 TO authenticated;
GRANT DELETE ON TABLE public.medicines_2 TO authenticator;
GRANT DELETE ON TABLE public.medicines_2 TO service_role;
GRANT INSERT ON TABLE public.medicines_2 TO authenticated;
GRANT INSERT ON TABLE public.medicines_2 TO authenticator;
GRANT INSERT ON TABLE public.medicines_2 TO service_role;
GRANT MAINTAIN ON TABLE public.medicines_2 TO authenticated;
GRANT MAINTAIN ON TABLE public.medicines_2 TO service_role;
GRANT REFERENCES ON TABLE public.medicines_2 TO authenticated;
GRANT REFERENCES ON TABLE public.medicines_2 TO service_role;
GRANT SELECT ON TABLE public.medicines_2 TO authenticated;
GRANT SELECT ON TABLE public.medicines_2 TO authenticator;
GRANT SELECT ON TABLE public.medicines_2 TO service_role;
GRANT TRIGGER ON TABLE public.medicines_2 TO authenticated;
GRANT TRIGGER ON TABLE public.medicines_2 TO service_role;
GRANT TRUNCATE ON TABLE public.medicines_2 TO service_role;
GRANT UPDATE ON TABLE public.medicines_2 TO authenticated;
GRANT UPDATE ON TABLE public.medicines_2 TO authenticator;
GRANT UPDATE ON TABLE public.medicines_2 TO service_role;
GRANT DELETE ON TABLE public.partners TO authenticated;
GRANT DELETE ON TABLE public.partners TO authenticator;
GRANT DELETE ON TABLE public.partners TO service_role;
GRANT DELETE ON TABLE public.partners TO supabase_auth_admin;
GRANT INSERT ON TABLE public.partners TO authenticated;
GRANT INSERT ON TABLE public.partners TO authenticator;
GRANT INSERT ON TABLE public.partners TO service_role;
GRANT INSERT ON TABLE public.partners TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.partners TO authenticated;
GRANT MAINTAIN ON TABLE public.partners TO authenticator;
GRANT MAINTAIN ON TABLE public.partners TO service_role;
GRANT MAINTAIN ON TABLE public.partners TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.partners TO authenticated;
GRANT REFERENCES ON TABLE public.partners TO authenticator;
GRANT REFERENCES ON TABLE public.partners TO service_role;
GRANT REFERENCES ON TABLE public.partners TO supabase_auth_admin;
GRANT SELECT ON TABLE public.partners TO authenticated;
GRANT SELECT ON TABLE public.partners TO authenticator;
GRANT SELECT ON TABLE public.partners TO service_role;
GRANT SELECT ON TABLE public.partners TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.partners TO authenticated;
GRANT TRIGGER ON TABLE public.partners TO authenticator;
GRANT TRIGGER ON TABLE public.partners TO service_role;
GRANT TRIGGER ON TABLE public.partners TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.partners TO authenticator;
GRANT TRUNCATE ON TABLE public.partners TO service_role;
GRANT TRUNCATE ON TABLE public.partners TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.partners TO authenticated;
GRANT UPDATE ON TABLE public.partners TO authenticator;
GRANT UPDATE ON TABLE public.partners TO service_role;
GRANT UPDATE ON TABLE public.partners TO supabase_auth_admin;
GRANT DELETE ON TABLE public.patient_discounts TO authenticator;
GRANT DELETE ON TABLE public.patient_discounts TO service_role;
GRANT DELETE ON TABLE public.patient_discounts TO supabase_auth_admin;
GRANT INSERT ON TABLE public.patient_discounts TO authenticator;
GRANT INSERT ON TABLE public.patient_discounts TO service_role;
GRANT INSERT ON TABLE public.patient_discounts TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.patient_discounts TO authenticated;
GRANT MAINTAIN ON TABLE public.patient_discounts TO authenticator;
GRANT MAINTAIN ON TABLE public.patient_discounts TO service_role;
GRANT MAINTAIN ON TABLE public.patient_discounts TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.patient_discounts TO authenticator;
GRANT REFERENCES ON TABLE public.patient_discounts TO service_role;
GRANT REFERENCES ON TABLE public.patient_discounts TO supabase_auth_admin;
GRANT SELECT ON TABLE public.patient_discounts TO authenticated;
GRANT SELECT ON TABLE public.patient_discounts TO authenticator;
GRANT SELECT ON TABLE public.patient_discounts TO service_role;
GRANT SELECT ON TABLE public.patient_discounts TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.patient_discounts TO authenticator;
GRANT TRIGGER ON TABLE public.patient_discounts TO service_role;
GRANT TRIGGER ON TABLE public.patient_discounts TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.patient_discounts TO authenticator;
GRANT TRUNCATE ON TABLE public.patient_discounts TO service_role;
GRANT TRUNCATE ON TABLE public.patient_discounts TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.patient_discounts TO authenticator;
GRANT UPDATE ON TABLE public.patient_discounts TO service_role;
GRANT UPDATE ON TABLE public.patient_discounts TO supabase_auth_admin;
GRANT DELETE ON TABLE public.patient_insurance TO authenticator;
GRANT DELETE ON TABLE public.patient_insurance TO service_role;
GRANT INSERT ON TABLE public.patient_insurance TO authenticated;
GRANT INSERT ON TABLE public.patient_insurance TO authenticator;
GRANT INSERT ON TABLE public.patient_insurance TO service_role;
GRANT MAINTAIN ON TABLE public.patient_insurance TO service_role;
GRANT REFERENCES ON TABLE public.patient_insurance TO service_role;
GRANT SELECT ON TABLE public.patient_insurance TO authenticated;
GRANT SELECT ON TABLE public.patient_insurance TO authenticator;
GRANT SELECT ON TABLE public.patient_insurance TO service_role;
GRANT TRIGGER ON TABLE public.patient_insurance TO service_role;
GRANT TRUNCATE ON TABLE public.patient_insurance TO service_role;
GRANT UPDATE ON TABLE public.patient_insurance TO authenticated;
GRANT UPDATE ON TABLE public.patient_insurance TO authenticator;
GRANT UPDATE ON TABLE public.patient_insurance TO service_role;
GRANT DELETE ON TABLE public.patients TO authenticated;
GRANT DELETE ON TABLE public.patients TO authenticator;
GRANT DELETE ON TABLE public.patients TO service_role;
GRANT DELETE ON TABLE public.patients TO supabase_auth_admin;
GRANT INSERT ON TABLE public.patients TO authenticator;
GRANT INSERT ON TABLE public.patients TO service_role;
GRANT INSERT ON TABLE public.patients TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.patients TO authenticated;
GRANT MAINTAIN ON TABLE public.patients TO authenticator;
GRANT MAINTAIN ON TABLE public.patients TO service_role;
GRANT MAINTAIN ON TABLE public.patients TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.patients TO authenticated;
GRANT REFERENCES ON TABLE public.patients TO authenticator;
GRANT REFERENCES ON TABLE public.patients TO service_role;
GRANT REFERENCES ON TABLE public.patients TO supabase_auth_admin;
GRANT SELECT ON TABLE public.patients TO authenticated;
GRANT SELECT ON TABLE public.patients TO authenticator;
GRANT SELECT ON TABLE public.patients TO service_role;
GRANT SELECT ON TABLE public.patients TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.patients TO authenticated;
GRANT TRIGGER ON TABLE public.patients TO authenticator;
GRANT TRIGGER ON TABLE public.patients TO service_role;
GRANT TRIGGER ON TABLE public.patients TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.patients TO authenticator;
GRANT TRUNCATE ON TABLE public.patients TO service_role;
GRANT TRUNCATE ON TABLE public.patients TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.patients TO authenticated;
GRANT UPDATE ON TABLE public.patients TO authenticator;
GRANT UPDATE ON TABLE public.patients TO service_role;
GRANT UPDATE ON TABLE public.patients TO supabase_auth_admin;
GRANT DELETE ON TABLE public.payments TO authenticator;
GRANT DELETE ON TABLE public.payments TO service_role;
GRANT DELETE ON TABLE public.payments TO supabase_auth_admin;
GRANT INSERT ON TABLE public.payments TO authenticator;
GRANT INSERT ON TABLE public.payments TO service_role;
GRANT INSERT ON TABLE public.payments TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.payments TO authenticated;
GRANT MAINTAIN ON TABLE public.payments TO authenticator;
GRANT MAINTAIN ON TABLE public.payments TO service_role;
GRANT MAINTAIN ON TABLE public.payments TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.payments TO authenticator;
GRANT REFERENCES ON TABLE public.payments TO service_role;
GRANT REFERENCES ON TABLE public.payments TO supabase_auth_admin;
GRANT SELECT ON TABLE public.payments TO authenticated;
GRANT SELECT ON TABLE public.payments TO authenticator;
GRANT SELECT ON TABLE public.payments TO service_role;
GRANT SELECT ON TABLE public.payments TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.payments TO authenticator;
GRANT TRIGGER ON TABLE public.payments TO service_role;
GRANT TRIGGER ON TABLE public.payments TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.payments TO authenticator;
GRANT TRUNCATE ON TABLE public.payments TO service_role;
GRANT TRUNCATE ON TABLE public.payments TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.payments TO authenticator;
GRANT UPDATE ON TABLE public.payments TO service_role;
GRANT UPDATE ON TABLE public.payments TO supabase_auth_admin;
GRANT DELETE ON TABLE public.permissions TO authenticated;
GRANT DELETE ON TABLE public.permissions TO authenticator;
GRANT DELETE ON TABLE public.permissions TO service_role;
GRANT DELETE ON TABLE public.permissions TO supabase_auth_admin;
GRANT INSERT ON TABLE public.permissions TO authenticated;
GRANT INSERT ON TABLE public.permissions TO authenticator;
GRANT INSERT ON TABLE public.permissions TO service_role;
GRANT INSERT ON TABLE public.permissions TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.permissions TO authenticated;
GRANT MAINTAIN ON TABLE public.permissions TO authenticator;
GRANT MAINTAIN ON TABLE public.permissions TO service_role;
GRANT MAINTAIN ON TABLE public.permissions TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.permissions TO authenticated;
GRANT REFERENCES ON TABLE public.permissions TO authenticator;
GRANT REFERENCES ON TABLE public.permissions TO service_role;
GRANT REFERENCES ON TABLE public.permissions TO supabase_auth_admin;
GRANT SELECT ON TABLE public.permissions TO authenticated;
GRANT SELECT ON TABLE public.permissions TO authenticator;
GRANT SELECT ON TABLE public.permissions TO service_role;
GRANT SELECT ON TABLE public.permissions TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.permissions TO authenticated;
GRANT TRIGGER ON TABLE public.permissions TO authenticator;
GRANT TRIGGER ON TABLE public.permissions TO service_role;
GRANT TRIGGER ON TABLE public.permissions TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.permissions TO authenticator;
GRANT TRUNCATE ON TABLE public.permissions TO service_role;
GRANT TRUNCATE ON TABLE public.permissions TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.permissions TO authenticated;
GRANT UPDATE ON TABLE public.permissions TO authenticator;
GRANT UPDATE ON TABLE public.permissions TO service_role;
GRANT UPDATE ON TABLE public.permissions TO supabase_auth_admin;
GRANT DELETE ON TABLE public.pharmacy_inventory TO authenticated;
GRANT DELETE ON TABLE public.pharmacy_inventory TO authenticator;
GRANT DELETE ON TABLE public.pharmacy_inventory TO service_role;
GRANT DELETE ON TABLE public.pharmacy_inventory TO supabase_auth_admin;
GRANT INSERT ON TABLE public.pharmacy_inventory TO authenticated;
GRANT INSERT ON TABLE public.pharmacy_inventory TO authenticator;
GRANT INSERT ON TABLE public.pharmacy_inventory TO service_role;
GRANT INSERT ON TABLE public.pharmacy_inventory TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.pharmacy_inventory TO authenticated;
GRANT MAINTAIN ON TABLE public.pharmacy_inventory TO authenticator;
GRANT MAINTAIN ON TABLE public.pharmacy_inventory TO service_role;
GRANT MAINTAIN ON TABLE public.pharmacy_inventory TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.pharmacy_inventory TO authenticated;
GRANT REFERENCES ON TABLE public.pharmacy_inventory TO authenticator;
GRANT REFERENCES ON TABLE public.pharmacy_inventory TO service_role;
GRANT REFERENCES ON TABLE public.pharmacy_inventory TO supabase_auth_admin;
GRANT SELECT ON TABLE public.pharmacy_inventory TO authenticated;
GRANT SELECT ON TABLE public.pharmacy_inventory TO authenticator;
GRANT SELECT ON TABLE public.pharmacy_inventory TO service_role;
GRANT SELECT ON TABLE public.pharmacy_inventory TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.pharmacy_inventory TO authenticated;
GRANT TRIGGER ON TABLE public.pharmacy_inventory TO authenticator;
GRANT TRIGGER ON TABLE public.pharmacy_inventory TO service_role;
GRANT TRIGGER ON TABLE public.pharmacy_inventory TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.pharmacy_inventory TO authenticator;
GRANT TRUNCATE ON TABLE public.pharmacy_inventory TO service_role;
GRANT TRUNCATE ON TABLE public.pharmacy_inventory TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.pharmacy_inventory TO authenticated;
GRANT UPDATE ON TABLE public.pharmacy_inventory TO authenticator;
GRANT UPDATE ON TABLE public.pharmacy_inventory TO service_role;
GRANT UPDATE ON TABLE public.pharmacy_inventory TO supabase_auth_admin;
GRANT DELETE ON TABLE public.prescription_items TO authenticator;
GRANT DELETE ON TABLE public.prescription_items TO service_role;
GRANT DELETE ON TABLE public.prescription_items TO supabase_auth_admin;
GRANT INSERT ON TABLE public.prescription_items TO authenticator;
GRANT INSERT ON TABLE public.prescription_items TO service_role;
GRANT INSERT ON TABLE public.prescription_items TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.prescription_items TO authenticated;
GRANT MAINTAIN ON TABLE public.prescription_items TO authenticator;
GRANT MAINTAIN ON TABLE public.prescription_items TO service_role;
GRANT MAINTAIN ON TABLE public.prescription_items TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.prescription_items TO authenticator;
GRANT REFERENCES ON TABLE public.prescription_items TO service_role;
GRANT REFERENCES ON TABLE public.prescription_items TO supabase_auth_admin;
GRANT SELECT ON TABLE public.prescription_items TO authenticated;
GRANT SELECT ON TABLE public.prescription_items TO authenticator;
GRANT SELECT ON TABLE public.prescription_items TO service_role;
GRANT SELECT ON TABLE public.prescription_items TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.prescription_items TO authenticator;
GRANT TRIGGER ON TABLE public.prescription_items TO service_role;
GRANT TRIGGER ON TABLE public.prescription_items TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.prescription_items TO authenticator;
GRANT TRUNCATE ON TABLE public.prescription_items TO service_role;
GRANT TRUNCATE ON TABLE public.prescription_items TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.prescription_items TO authenticator;
GRANT UPDATE ON TABLE public.prescription_items TO service_role;
GRANT UPDATE ON TABLE public.prescription_items TO supabase_auth_admin;
GRANT DELETE ON TABLE public.prescriptions TO authenticator;
GRANT DELETE ON TABLE public.prescriptions TO service_role;
GRANT DELETE ON TABLE public.prescriptions TO supabase_auth_admin;
GRANT INSERT ON TABLE public.prescriptions TO authenticator;
GRANT INSERT ON TABLE public.prescriptions TO service_role;
GRANT INSERT ON TABLE public.prescriptions TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.prescriptions TO authenticated;
GRANT MAINTAIN ON TABLE public.prescriptions TO authenticator;
GRANT MAINTAIN ON TABLE public.prescriptions TO service_role;
GRANT MAINTAIN ON TABLE public.prescriptions TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.prescriptions TO authenticator;
GRANT REFERENCES ON TABLE public.prescriptions TO service_role;
GRANT REFERENCES ON TABLE public.prescriptions TO supabase_auth_admin;
GRANT SELECT ON TABLE public.prescriptions TO authenticated;
GRANT SELECT ON TABLE public.prescriptions TO authenticator;
GRANT SELECT ON TABLE public.prescriptions TO service_role;
GRANT SELECT ON TABLE public.prescriptions TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.prescriptions TO authenticator;
GRANT TRIGGER ON TABLE public.prescriptions TO service_role;
GRANT TRIGGER ON TABLE public.prescriptions TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.prescriptions TO authenticator;
GRANT TRUNCATE ON TABLE public.prescriptions TO service_role;
GRANT TRUNCATE ON TABLE public.prescriptions TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.prescriptions TO authenticator;
GRANT UPDATE ON TABLE public.prescriptions TO service_role;
GRANT UPDATE ON TABLE public.prescriptions TO supabase_auth_admin;
GRANT DELETE ON TABLE public.procedure_orders TO authenticated;
GRANT DELETE ON TABLE public.procedure_orders TO authenticator;
GRANT DELETE ON TABLE public.procedure_orders TO service_role;
GRANT DELETE ON TABLE public.procedure_orders TO supabase_auth_admin;
GRANT INSERT ON TABLE public.procedure_orders TO authenticated;
GRANT INSERT ON TABLE public.procedure_orders TO authenticator;
GRANT INSERT ON TABLE public.procedure_orders TO service_role;
GRANT INSERT ON TABLE public.procedure_orders TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.procedure_orders TO authenticated;
GRANT MAINTAIN ON TABLE public.procedure_orders TO authenticator;
GRANT MAINTAIN ON TABLE public.procedure_orders TO service_role;
GRANT MAINTAIN ON TABLE public.procedure_orders TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.procedure_orders TO authenticated;
GRANT REFERENCES ON TABLE public.procedure_orders TO authenticator;
GRANT REFERENCES ON TABLE public.procedure_orders TO service_role;
GRANT REFERENCES ON TABLE public.procedure_orders TO supabase_auth_admin;
GRANT SELECT ON TABLE public.procedure_orders TO authenticated;
GRANT SELECT ON TABLE public.procedure_orders TO authenticator;
GRANT SELECT ON TABLE public.procedure_orders TO service_role;
GRANT SELECT ON TABLE public.procedure_orders TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.procedure_orders TO authenticated;
GRANT TRIGGER ON TABLE public.procedure_orders TO authenticator;
GRANT TRIGGER ON TABLE public.procedure_orders TO service_role;
GRANT TRIGGER ON TABLE public.procedure_orders TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.procedure_orders TO authenticator;
GRANT TRUNCATE ON TABLE public.procedure_orders TO service_role;
GRANT TRUNCATE ON TABLE public.procedure_orders TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.procedure_orders TO authenticated;
GRANT UPDATE ON TABLE public.procedure_orders TO authenticator;
GRANT UPDATE ON TABLE public.procedure_orders TO service_role;
GRANT UPDATE ON TABLE public.procedure_orders TO supabase_auth_admin;
GRANT DELETE ON TABLE public.procedure_results TO authenticated;
GRANT DELETE ON TABLE public.procedure_results TO authenticator;
GRANT DELETE ON TABLE public.procedure_results TO service_role;
GRANT DELETE ON TABLE public.procedure_results TO supabase_auth_admin;
GRANT INSERT ON TABLE public.procedure_results TO authenticated;
GRANT INSERT ON TABLE public.procedure_results TO authenticator;
GRANT INSERT ON TABLE public.procedure_results TO service_role;
GRANT INSERT ON TABLE public.procedure_results TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.procedure_results TO authenticated;
GRANT MAINTAIN ON TABLE public.procedure_results TO authenticator;
GRANT MAINTAIN ON TABLE public.procedure_results TO service_role;
GRANT MAINTAIN ON TABLE public.procedure_results TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.procedure_results TO authenticated;
GRANT REFERENCES ON TABLE public.procedure_results TO authenticator;
GRANT REFERENCES ON TABLE public.procedure_results TO service_role;
GRANT REFERENCES ON TABLE public.procedure_results TO supabase_auth_admin;
GRANT SELECT ON TABLE public.procedure_results TO authenticated;
GRANT SELECT ON TABLE public.procedure_results TO authenticator;
GRANT SELECT ON TABLE public.procedure_results TO service_role;
GRANT SELECT ON TABLE public.procedure_results TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.procedure_results TO authenticated;
GRANT TRIGGER ON TABLE public.procedure_results TO authenticator;
GRANT TRIGGER ON TABLE public.procedure_results TO service_role;
GRANT TRIGGER ON TABLE public.procedure_results TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.procedure_results TO authenticator;
GRANT TRUNCATE ON TABLE public.procedure_results TO service_role;
GRANT TRUNCATE ON TABLE public.procedure_results TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.procedure_results TO authenticated;
GRANT UPDATE ON TABLE public.procedure_results TO authenticator;
GRANT UPDATE ON TABLE public.procedure_results TO service_role;
GRANT UPDATE ON TABLE public.procedure_results TO supabase_auth_admin;
GRANT DELETE ON TABLE public.procedures_catalog TO authenticated;
GRANT DELETE ON TABLE public.procedures_catalog TO authenticator;
GRANT DELETE ON TABLE public.procedures_catalog TO service_role;
GRANT DELETE ON TABLE public.procedures_catalog TO supabase_auth_admin;
GRANT INSERT ON TABLE public.procedures_catalog TO authenticated;
GRANT INSERT ON TABLE public.procedures_catalog TO authenticator;
GRANT INSERT ON TABLE public.procedures_catalog TO service_role;
GRANT INSERT ON TABLE public.procedures_catalog TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.procedures_catalog TO authenticated;
GRANT MAINTAIN ON TABLE public.procedures_catalog TO authenticator;
GRANT MAINTAIN ON TABLE public.procedures_catalog TO service_role;
GRANT MAINTAIN ON TABLE public.procedures_catalog TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.procedures_catalog TO authenticated;
GRANT REFERENCES ON TABLE public.procedures_catalog TO authenticator;
GRANT REFERENCES ON TABLE public.procedures_catalog TO service_role;
GRANT REFERENCES ON TABLE public.procedures_catalog TO supabase_auth_admin;
GRANT SELECT ON TABLE public.procedures_catalog TO authenticated;
GRANT SELECT ON TABLE public.procedures_catalog TO authenticator;
GRANT SELECT ON TABLE public.procedures_catalog TO service_role;
GRANT SELECT ON TABLE public.procedures_catalog TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.procedures_catalog TO authenticated;
GRANT TRIGGER ON TABLE public.procedures_catalog TO authenticator;
GRANT TRIGGER ON TABLE public.procedures_catalog TO service_role;
GRANT TRIGGER ON TABLE public.procedures_catalog TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.procedures_catalog TO authenticator;
GRANT TRUNCATE ON TABLE public.procedures_catalog TO service_role;
GRANT TRUNCATE ON TABLE public.procedures_catalog TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.procedures_catalog TO authenticated;
GRANT UPDATE ON TABLE public.procedures_catalog TO authenticator;
GRANT UPDATE ON TABLE public.procedures_catalog TO service_role;
GRANT UPDATE ON TABLE public.procedures_catalog TO supabase_auth_admin;
GRANT DELETE ON TABLE public.profiles TO authenticated;
GRANT DELETE ON TABLE public.profiles TO authenticator;
GRANT DELETE ON TABLE public.profiles TO service_role;
GRANT INSERT ON TABLE public.profiles TO authenticated;
GRANT INSERT ON TABLE public.profiles TO authenticator;
GRANT INSERT ON TABLE public.profiles TO service_role;
GRANT MAINTAIN ON TABLE public.profiles TO authenticated;
GRANT MAINTAIN ON TABLE public.profiles TO service_role;
GRANT REFERENCES ON TABLE public.profiles TO authenticated;
GRANT REFERENCES ON TABLE public.profiles TO service_role;
GRANT SELECT ON TABLE public.profiles TO authenticated;
GRANT SELECT ON TABLE public.profiles TO authenticator;
GRANT SELECT ON TABLE public.profiles TO service_role;
GRANT TRIGGER ON TABLE public.profiles TO authenticated;
GRANT TRIGGER ON TABLE public.profiles TO service_role;
GRANT TRUNCATE ON TABLE public.profiles TO service_role;
GRANT UPDATE ON TABLE public.profiles TO authenticated;
GRANT UPDATE ON TABLE public.profiles TO authenticator;
GRANT UPDATE ON TABLE public.profiles TO service_role;
GRANT DELETE ON TABLE public.queue_tickets TO authenticated;
GRANT DELETE ON TABLE public.queue_tickets TO authenticator;
GRANT DELETE ON TABLE public.queue_tickets TO service_role;
GRANT DELETE ON TABLE public.queue_tickets TO supabase_auth_admin;
GRANT INSERT ON TABLE public.queue_tickets TO authenticated;
GRANT INSERT ON TABLE public.queue_tickets TO authenticator;
GRANT INSERT ON TABLE public.queue_tickets TO service_role;
GRANT INSERT ON TABLE public.queue_tickets TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.queue_tickets TO authenticated;
GRANT MAINTAIN ON TABLE public.queue_tickets TO authenticator;
GRANT MAINTAIN ON TABLE public.queue_tickets TO service_role;
GRANT MAINTAIN ON TABLE public.queue_tickets TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.queue_tickets TO authenticated;
GRANT REFERENCES ON TABLE public.queue_tickets TO authenticator;
GRANT REFERENCES ON TABLE public.queue_tickets TO service_role;
GRANT REFERENCES ON TABLE public.queue_tickets TO supabase_auth_admin;
GRANT SELECT ON TABLE public.queue_tickets TO authenticated;
GRANT SELECT ON TABLE public.queue_tickets TO authenticator;
GRANT SELECT ON TABLE public.queue_tickets TO service_role;
GRANT SELECT ON TABLE public.queue_tickets TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.queue_tickets TO authenticated;
GRANT TRIGGER ON TABLE public.queue_tickets TO authenticator;
GRANT TRIGGER ON TABLE public.queue_tickets TO service_role;
GRANT TRIGGER ON TABLE public.queue_tickets TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.queue_tickets TO authenticator;
GRANT TRUNCATE ON TABLE public.queue_tickets TO service_role;
GRANT TRUNCATE ON TABLE public.queue_tickets TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.queue_tickets TO authenticated;
GRANT UPDATE ON TABLE public.queue_tickets TO authenticator;
GRANT UPDATE ON TABLE public.queue_tickets TO service_role;
GRANT UPDATE ON TABLE public.queue_tickets TO supabase_auth_admin;
GRANT DELETE ON TABLE public.role_permissions TO authenticated;
GRANT DELETE ON TABLE public.role_permissions TO authenticator;
GRANT DELETE ON TABLE public.role_permissions TO service_role;
GRANT DELETE ON TABLE public.role_permissions TO supabase_auth_admin;
GRANT INSERT ON TABLE public.role_permissions TO authenticated;
GRANT INSERT ON TABLE public.role_permissions TO authenticator;
GRANT INSERT ON TABLE public.role_permissions TO service_role;
GRANT INSERT ON TABLE public.role_permissions TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.role_permissions TO authenticated;
GRANT MAINTAIN ON TABLE public.role_permissions TO authenticator;
GRANT MAINTAIN ON TABLE public.role_permissions TO service_role;
GRANT MAINTAIN ON TABLE public.role_permissions TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.role_permissions TO authenticated;
GRANT REFERENCES ON TABLE public.role_permissions TO authenticator;
GRANT REFERENCES ON TABLE public.role_permissions TO service_role;
GRANT REFERENCES ON TABLE public.role_permissions TO supabase_auth_admin;
GRANT SELECT ON TABLE public.role_permissions TO authenticated;
GRANT SELECT ON TABLE public.role_permissions TO authenticator;
GRANT SELECT ON TABLE public.role_permissions TO service_role;
GRANT SELECT ON TABLE public.role_permissions TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.role_permissions TO authenticated;
GRANT TRIGGER ON TABLE public.role_permissions TO authenticator;
GRANT TRIGGER ON TABLE public.role_permissions TO service_role;
GRANT TRIGGER ON TABLE public.role_permissions TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.role_permissions TO authenticator;
GRANT TRUNCATE ON TABLE public.role_permissions TO service_role;
GRANT TRUNCATE ON TABLE public.role_permissions TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.role_permissions TO authenticated;
GRANT UPDATE ON TABLE public.role_permissions TO authenticator;
GRANT UPDATE ON TABLE public.role_permissions TO service_role;
GRANT UPDATE ON TABLE public.role_permissions TO supabase_auth_admin;
GRANT DELETE ON TABLE public.roles TO authenticated;
GRANT DELETE ON TABLE public.roles TO authenticator;
GRANT DELETE ON TABLE public.roles TO service_role;
GRANT DELETE ON TABLE public.roles TO supabase_auth_admin;
GRANT INSERT ON TABLE public.roles TO authenticated;
GRANT INSERT ON TABLE public.roles TO authenticator;
GRANT INSERT ON TABLE public.roles TO service_role;
GRANT INSERT ON TABLE public.roles TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.roles TO authenticated;
GRANT MAINTAIN ON TABLE public.roles TO authenticator;
GRANT MAINTAIN ON TABLE public.roles TO service_role;
GRANT MAINTAIN ON TABLE public.roles TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.roles TO authenticated;
GRANT REFERENCES ON TABLE public.roles TO authenticator;
GRANT REFERENCES ON TABLE public.roles TO service_role;
GRANT REFERENCES ON TABLE public.roles TO supabase_auth_admin;
GRANT SELECT ON TABLE public.roles TO authenticated;
GRANT SELECT ON TABLE public.roles TO authenticator;
GRANT SELECT ON TABLE public.roles TO service_role;
GRANT SELECT ON TABLE public.roles TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.roles TO authenticated;
GRANT TRIGGER ON TABLE public.roles TO authenticator;
GRANT TRIGGER ON TABLE public.roles TO service_role;
GRANT TRIGGER ON TABLE public.roles TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.roles TO authenticator;
GRANT TRUNCATE ON TABLE public.roles TO service_role;
GRANT TRUNCATE ON TABLE public.roles TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.roles TO authenticated;
GRANT UPDATE ON TABLE public.roles TO authenticator;
GRANT UPDATE ON TABLE public.roles TO service_role;
GRANT UPDATE ON TABLE public.roles TO supabase_auth_admin;
GRANT DELETE ON TABLE public.services TO authenticated;
GRANT DELETE ON TABLE public.services TO authenticator;
GRANT DELETE ON TABLE public.services TO service_role;
GRANT DELETE ON TABLE public.services TO supabase_auth_admin;
GRANT INSERT ON TABLE public.services TO authenticated;
GRANT INSERT ON TABLE public.services TO authenticator;
GRANT INSERT ON TABLE public.services TO service_role;
GRANT INSERT ON TABLE public.services TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.services TO authenticated;
GRANT MAINTAIN ON TABLE public.services TO authenticator;
GRANT MAINTAIN ON TABLE public.services TO service_role;
GRANT MAINTAIN ON TABLE public.services TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.services TO authenticated;
GRANT REFERENCES ON TABLE public.services TO authenticator;
GRANT REFERENCES ON TABLE public.services TO service_role;
GRANT REFERENCES ON TABLE public.services TO supabase_auth_admin;
GRANT SELECT ON TABLE public.services TO authenticated;
GRANT SELECT ON TABLE public.services TO authenticator;
GRANT SELECT ON TABLE public.services TO service_role;
GRANT SELECT ON TABLE public.services TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.services TO authenticated;
GRANT TRIGGER ON TABLE public.services TO authenticator;
GRANT TRIGGER ON TABLE public.services TO service_role;
GRANT TRIGGER ON TABLE public.services TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.services TO authenticator;
GRANT TRUNCATE ON TABLE public.services TO service_role;
GRANT TRUNCATE ON TABLE public.services TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.services TO authenticated;
GRANT UPDATE ON TABLE public.services TO authenticator;
GRANT UPDATE ON TABLE public.services TO service_role;
GRANT UPDATE ON TABLE public.services TO supabase_auth_admin;
GRANT DELETE ON TABLE public.stock_movements TO authenticator;
GRANT INSERT ON TABLE public.stock_movements TO authenticator;
GRANT SELECT ON TABLE public.stock_movements TO authenticated;
GRANT SELECT ON TABLE public.stock_movements TO authenticator;
GRANT UPDATE ON TABLE public.stock_movements TO authenticator;
GRANT DELETE ON TABLE public.supplier_bills TO authenticator;
GRANT DELETE ON TABLE public.supplier_bills TO service_role;
GRANT INSERT ON TABLE public.supplier_bills TO authenticator;
GRANT INSERT ON TABLE public.supplier_bills TO service_role;
GRANT MAINTAIN ON TABLE public.supplier_bills TO service_role;
GRANT REFERENCES ON TABLE public.supplier_bills TO service_role;
GRANT SELECT ON TABLE public.supplier_bills TO authenticated;
GRANT SELECT ON TABLE public.supplier_bills TO authenticator;
GRANT SELECT ON TABLE public.supplier_bills TO service_role;
GRANT TRIGGER ON TABLE public.supplier_bills TO service_role;
GRANT TRUNCATE ON TABLE public.supplier_bills TO service_role;
GRANT UPDATE ON TABLE public.supplier_bills TO authenticator;
GRANT UPDATE ON TABLE public.supplier_bills TO service_role;
GRANT DELETE ON TABLE public.supplier_payments TO authenticator;
GRANT DELETE ON TABLE public.supplier_payments TO service_role;
GRANT INSERT ON TABLE public.supplier_payments TO authenticator;
GRANT INSERT ON TABLE public.supplier_payments TO service_role;
GRANT MAINTAIN ON TABLE public.supplier_payments TO service_role;
GRANT REFERENCES ON TABLE public.supplier_payments TO service_role;
GRANT SELECT ON TABLE public.supplier_payments TO authenticated;
GRANT SELECT ON TABLE public.supplier_payments TO authenticator;
GRANT SELECT ON TABLE public.supplier_payments TO service_role;
GRANT TRIGGER ON TABLE public.supplier_payments TO service_role;
GRANT TRUNCATE ON TABLE public.supplier_payments TO service_role;
GRANT UPDATE ON TABLE public.supplier_payments TO authenticator;
GRANT UPDATE ON TABLE public.supplier_payments TO service_role;
GRANT DELETE ON TABLE public.suppliers TO authenticated;
GRANT DELETE ON TABLE public.suppliers TO authenticator;
GRANT DELETE ON TABLE public.suppliers TO service_role;
GRANT DELETE ON TABLE public.suppliers TO supabase_auth_admin;
GRANT INSERT ON TABLE public.suppliers TO authenticated;
GRANT INSERT ON TABLE public.suppliers TO authenticator;
GRANT INSERT ON TABLE public.suppliers TO service_role;
GRANT INSERT ON TABLE public.suppliers TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.suppliers TO authenticated;
GRANT MAINTAIN ON TABLE public.suppliers TO authenticator;
GRANT MAINTAIN ON TABLE public.suppliers TO service_role;
GRANT MAINTAIN ON TABLE public.suppliers TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.suppliers TO authenticated;
GRANT REFERENCES ON TABLE public.suppliers TO authenticator;
GRANT REFERENCES ON TABLE public.suppliers TO service_role;
GRANT REFERENCES ON TABLE public.suppliers TO supabase_auth_admin;
GRANT SELECT ON TABLE public.suppliers TO authenticated;
GRANT SELECT ON TABLE public.suppliers TO authenticator;
GRANT SELECT ON TABLE public.suppliers TO service_role;
GRANT SELECT ON TABLE public.suppliers TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.suppliers TO authenticated;
GRANT TRIGGER ON TABLE public.suppliers TO authenticator;
GRANT TRIGGER ON TABLE public.suppliers TO service_role;
GRANT TRIGGER ON TABLE public.suppliers TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.suppliers TO authenticator;
GRANT TRUNCATE ON TABLE public.suppliers TO service_role;
GRANT TRUNCATE ON TABLE public.suppliers TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.suppliers TO authenticated;
GRANT UPDATE ON TABLE public.suppliers TO authenticator;
GRANT UPDATE ON TABLE public.suppliers TO service_role;
GRANT UPDATE ON TABLE public.suppliers TO supabase_auth_admin;
GRANT DELETE ON TABLE public.system_settings TO authenticated;
GRANT DELETE ON TABLE public.system_settings TO authenticator;
GRANT DELETE ON TABLE public.system_settings TO service_role;
GRANT DELETE ON TABLE public.system_settings TO supabase_auth_admin;
GRANT INSERT ON TABLE public.system_settings TO authenticated;
GRANT INSERT ON TABLE public.system_settings TO authenticator;
GRANT INSERT ON TABLE public.system_settings TO service_role;
GRANT INSERT ON TABLE public.system_settings TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.system_settings TO authenticated;
GRANT MAINTAIN ON TABLE public.system_settings TO authenticator;
GRANT MAINTAIN ON TABLE public.system_settings TO service_role;
GRANT MAINTAIN ON TABLE public.system_settings TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.system_settings TO authenticated;
GRANT REFERENCES ON TABLE public.system_settings TO authenticator;
GRANT REFERENCES ON TABLE public.system_settings TO service_role;
GRANT REFERENCES ON TABLE public.system_settings TO supabase_auth_admin;
GRANT SELECT ON TABLE public.system_settings TO authenticated;
GRANT SELECT ON TABLE public.system_settings TO authenticator;
GRANT SELECT ON TABLE public.system_settings TO service_role;
GRANT SELECT ON TABLE public.system_settings TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.system_settings TO authenticated;
GRANT TRIGGER ON TABLE public.system_settings TO authenticator;
GRANT TRIGGER ON TABLE public.system_settings TO service_role;
GRANT TRIGGER ON TABLE public.system_settings TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.system_settings TO authenticator;
GRANT TRUNCATE ON TABLE public.system_settings TO service_role;
GRANT TRUNCATE ON TABLE public.system_settings TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.system_settings TO authenticated;
GRANT UPDATE ON TABLE public.system_settings TO authenticator;
GRANT UPDATE ON TABLE public.system_settings TO service_role;
GRANT UPDATE ON TABLE public.system_settings TO supabase_auth_admin;
GRANT DELETE ON TABLE public.users TO authenticated;
GRANT DELETE ON TABLE public.users TO authenticator;
GRANT DELETE ON TABLE public.users TO service_role;
GRANT DELETE ON TABLE public.users TO supabase_auth_admin;
GRANT INSERT ON TABLE public.users TO authenticated;
GRANT INSERT ON TABLE public.users TO authenticator;
GRANT INSERT ON TABLE public.users TO service_role;
GRANT INSERT ON TABLE public.users TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.users TO authenticated;
GRANT MAINTAIN ON TABLE public.users TO authenticator;
GRANT MAINTAIN ON TABLE public.users TO service_role;
GRANT MAINTAIN ON TABLE public.users TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.users TO authenticated;
GRANT REFERENCES ON TABLE public.users TO authenticator;
GRANT REFERENCES ON TABLE public.users TO service_role;
GRANT REFERENCES ON TABLE public.users TO supabase_auth_admin;
GRANT SELECT ON TABLE public.users TO authenticated;
GRANT SELECT ON TABLE public.users TO authenticator;
GRANT SELECT ON TABLE public.users TO service_role;
GRANT SELECT ON TABLE public.users TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.users TO authenticated;
GRANT TRIGGER ON TABLE public.users TO authenticator;
GRANT TRIGGER ON TABLE public.users TO service_role;
GRANT TRIGGER ON TABLE public.users TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.users TO authenticator;
GRANT TRUNCATE ON TABLE public.users TO service_role;
GRANT TRUNCATE ON TABLE public.users TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.users TO authenticated;
GRANT UPDATE ON TABLE public.users TO authenticator;
GRANT UPDATE ON TABLE public.users TO service_role;
GRANT UPDATE ON TABLE public.users TO supabase_auth_admin;
GRANT DELETE ON TABLE public.visits TO authenticated;
GRANT DELETE ON TABLE public.visits TO authenticator;
GRANT DELETE ON TABLE public.visits TO service_role;
GRANT DELETE ON TABLE public.visits TO supabase_auth_admin;
GRANT INSERT ON TABLE public.visits TO authenticated;
GRANT INSERT ON TABLE public.visits TO authenticator;
GRANT INSERT ON TABLE public.visits TO service_role;
GRANT INSERT ON TABLE public.visits TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.visits TO authenticated;
GRANT MAINTAIN ON TABLE public.visits TO authenticator;
GRANT MAINTAIN ON TABLE public.visits TO service_role;
GRANT MAINTAIN ON TABLE public.visits TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.visits TO authenticated;
GRANT REFERENCES ON TABLE public.visits TO authenticator;
GRANT REFERENCES ON TABLE public.visits TO service_role;
GRANT REFERENCES ON TABLE public.visits TO supabase_auth_admin;
GRANT SELECT ON TABLE public.visits TO authenticated;
GRANT SELECT ON TABLE public.visits TO authenticator;
GRANT SELECT ON TABLE public.visits TO service_role;
GRANT SELECT ON TABLE public.visits TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.visits TO authenticated;
GRANT TRIGGER ON TABLE public.visits TO authenticator;
GRANT TRIGGER ON TABLE public.visits TO service_role;
GRANT TRIGGER ON TABLE public.visits TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.visits TO authenticator;
GRANT TRUNCATE ON TABLE public.visits TO service_role;
GRANT TRUNCATE ON TABLE public.visits TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.visits TO authenticated;
GRANT UPDATE ON TABLE public.visits TO authenticator;
GRANT UPDATE ON TABLE public.visits TO service_role;
GRANT UPDATE ON TABLE public.visits TO supabase_auth_admin;
GRANT DELETE ON TABLE public.vitals TO authenticated;
GRANT DELETE ON TABLE public.vitals TO authenticator;
GRANT DELETE ON TABLE public.vitals TO service_role;
GRANT DELETE ON TABLE public.vitals TO supabase_auth_admin;
GRANT INSERT ON TABLE public.vitals TO authenticated;
GRANT INSERT ON TABLE public.vitals TO authenticator;
GRANT INSERT ON TABLE public.vitals TO service_role;
GRANT INSERT ON TABLE public.vitals TO supabase_auth_admin;
GRANT MAINTAIN ON TABLE public.vitals TO authenticated;
GRANT MAINTAIN ON TABLE public.vitals TO authenticator;
GRANT MAINTAIN ON TABLE public.vitals TO service_role;
GRANT MAINTAIN ON TABLE public.vitals TO supabase_auth_admin;
GRANT REFERENCES ON TABLE public.vitals TO authenticated;
GRANT REFERENCES ON TABLE public.vitals TO authenticator;
GRANT REFERENCES ON TABLE public.vitals TO service_role;
GRANT REFERENCES ON TABLE public.vitals TO supabase_auth_admin;
GRANT SELECT ON TABLE public.vitals TO authenticated;
GRANT SELECT ON TABLE public.vitals TO authenticator;
GRANT SELECT ON TABLE public.vitals TO service_role;
GRANT SELECT ON TABLE public.vitals TO supabase_auth_admin;
GRANT TRIGGER ON TABLE public.vitals TO authenticated;
GRANT TRIGGER ON TABLE public.vitals TO authenticator;
GRANT TRIGGER ON TABLE public.vitals TO service_role;
GRANT TRIGGER ON TABLE public.vitals TO supabase_auth_admin;
GRANT TRUNCATE ON TABLE public.vitals TO authenticator;
GRANT TRUNCATE ON TABLE public.vitals TO service_role;
GRANT TRUNCATE ON TABLE public.vitals TO supabase_auth_admin;
GRANT UPDATE ON TABLE public.vitals TO authenticated;
GRANT UPDATE ON TABLE public.vitals TO authenticator;
GRANT UPDATE ON TABLE public.vitals TO service_role;
GRANT UPDATE ON TABLE public.vitals TO supabase_auth_admin;

-- RLS enablement
ALTER TABLE public.appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.appointments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.branches FORCE ROW LEVEL SECURITY;
ALTER TABLE public.cashbox_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificates FORCE ROW LEVEL SECURITY;
ALTER TABLE public.clinical_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clinical_notes FORCE ROW LEVEL SECURITY;
ALTER TABLE public.corporate_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.corporate_accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.departments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.diagnoses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.diagnoses FORCE ROW LEVEL SECURITY;
ALTER TABLE public.employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.employees FORCE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses FORCE ROW LEVEL SECURITY;
ALTER TABLE public.followups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.followups FORCE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_claim_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_claim_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_coverage_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.insurance_prior_authorizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lab_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_order_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lab_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lab_parameters ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_parameters FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lab_reference_ranges ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_reference_ranges FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lab_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_results FORCE ROW LEVEL SECURITY;
ALTER TABLE public.lab_tests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lab_tests FORCE ROW LEVEL SECURITY;
ALTER TABLE public.medical_certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_certificates FORCE ROW LEVEL SECURITY;
ALTER TABLE public.medicines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicines FORCE ROW LEVEL SECURITY;
ALTER TABLE public.medicines_2 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medicines_2 FORCE ROW LEVEL SECURITY;
ALTER TABLE public.partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.partners FORCE ROW LEVEL SECURITY;
ALTER TABLE public.patient_discounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patient_discounts FORCE ROW LEVEL SECURITY;
ALTER TABLE public.patient_insurance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.patients FORCE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments FORCE ROW LEVEL SECURITY;
ALTER TABLE public.permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_inventory ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pharmacy_inventory FORCE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescription_items FORCE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.prescriptions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.procedure_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procedure_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE public.procedure_results ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procedure_results FORCE ROW LEVEL SECURITY;
ALTER TABLE public.procedures_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.procedures_catalog FORCE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.queue_tickets FORCE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.role_permissions FORCE ROW LEVEL SECURITY;
ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roles FORCE ROW LEVEL SECURITY;
ALTER TABLE public.services ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.services FORCE ROW LEVEL SECURITY;
ALTER TABLE public.stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supplier_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.suppliers FORCE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings FORCE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users FORCE ROW LEVEL SECURITY;
ALTER TABLE public.visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visits FORCE ROW LEVEL SECURITY;
ALTER TABLE public.vitals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vitals FORCE ROW LEVEL SECURITY;

-- RLS policies
CREATE POLICY appointments_delete ON public.appointments AS PERMISSIVE FOR DELETE TO authenticated USING ((app_has_perm('appointments.delete'::text) AND ( SELECT private.app_has_branch_access(appointments.branch_id) AS app_has_branch_access)));
CREATE POLICY appointments_insert ON public.appointments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((app_has_perm('appointments.create'::text) AND (created_by = current_app_user_id()) AND ( SELECT private.app_has_branch_access(appointments.branch_id) AS app_has_branch_access)));
CREATE POLICY appointments_select ON public.appointments AS PERMISSIVE FOR SELECT TO authenticated USING ((app_has_perm('appointments.read'::text) AND ( SELECT private.app_has_branch_access(appointments.branch_id) AS app_has_branch_access)));
CREATE POLICY appointments_update ON public.appointments AS PERMISSIVE FOR UPDATE TO authenticated USING ((app_has_perm('appointments.update'::text) AND ( SELECT private.app_has_branch_access(appointments.branch_id) AS app_has_branch_access))) WITH CHECK ((app_has_perm('appointments.update'::text) AND ( SELECT private.app_has_branch_access(appointments.branch_id) AS app_has_branch_access)));
CREATE POLICY attachments_delete ON public.attachments AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('attachments.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id) AS app_has_attachment_branch_access)));
CREATE POLICY attachments_insert ON public.attachments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('attachments.create'::text) AS app_has_perm) AND ( SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id) AS app_has_attachment_branch_access)));
CREATE POLICY attachments_select ON public.attachments AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('attachments.read'::text) AS app_has_perm) AND ( SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id) AS app_has_attachment_branch_access)));
CREATE POLICY attachments_update ON public.attachments AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('attachments.update'::text) AS app_has_perm) AND ( SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id) AS app_has_attachment_branch_access))) WITH CHECK ((( SELECT app_has_perm('attachments.update'::text) AS app_has_perm) AND ( SELECT private.app_has_attachment_branch_access(attachments.patient_id, attachments.visit_id) AS app_has_attachment_branch_access)));
CREATE POLICY audit_logs_select ON public.audit_logs AS PERMISSIVE FOR SELECT TO authenticated USING (app_has_perm('audit.read'::text));
CREATE POLICY branches_delete ON public.branches AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY branches_insert ON public.branches AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY branches_select ON public.branches AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY branches_update ON public.branches AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY cashbox_del ON public.cashbox_transactions AS PERMISSIVE FOR DELETE TO authenticated USING ((is_super_admin() AND ( SELECT private.app_has_branch_access(cashbox_transactions.branch_id) AS app_has_branch_access)));
CREATE POLICY cashbox_ins ON public.cashbox_transactions AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((( SELECT app_has_perm('accounting.create'::text) AS app_has_perm) OR ( SELECT app_has_perm('cashbox.create'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(cashbox_transactions.branch_id) AS app_has_branch_access)));
CREATE POLICY cashbox_sel ON public.cashbox_transactions AS PERMISSIVE FOR SELECT TO authenticated USING (((( SELECT app_has_perm('accounting.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('cashbox.read'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(cashbox_transactions.branch_id) AS app_has_branch_access)));
CREATE POLICY cashbox_upd ON public.cashbox_transactions AS PERMISSIVE FOR UPDATE TO authenticated USING ((is_super_admin() AND ( SELECT private.app_has_branch_access(cashbox_transactions.branch_id) AS app_has_branch_access))) WITH CHECK ((is_super_admin() AND ( SELECT private.app_has_branch_access(cashbox_transactions.branch_id) AS app_has_branch_access)));
CREATE POLICY certificates_delete ON public.certificates AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('certificates.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY certificates_insert ON public.certificates AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('certificates.create'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY certificates_select ON public.certificates AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('certificates.read'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY certificates_update ON public.certificates AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('certificates.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id) AS app_has_patient_visit_branch_access))) WITH CHECK ((( SELECT app_has_perm('certificates.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(certificates.patient_id, certificates.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY clinical_notes_delete ON public.clinical_notes AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('emr.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(clinical_notes.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY clinical_notes_insert ON public.clinical_notes AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('emr.create'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(clinical_notes.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY clinical_notes_select ON public.clinical_notes AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('emr.read'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(clinical_notes.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY clinical_notes_update ON public.clinical_notes AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('emr.update'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(clinical_notes.visit_id) AS app_has_visit_branch_access))) WITH CHECK ((( SELECT app_has_perm('emr.update'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(clinical_notes.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY corporate_accounts_delete ON public.corporate_accounts AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('billing.delete'::text) AS app_has_perm));
CREATE POLICY corporate_accounts_insert ON public.corporate_accounts AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('billing.create'::text) AS app_has_perm));
CREATE POLICY corporate_accounts_select ON public.corporate_accounts AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('billing.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.view'::text) AS app_has_perm)));
CREATE POLICY corporate_accounts_update ON public.corporate_accounts AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('billing.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.edit'::text) AS app_has_perm))) WITH CHECK ((( SELECT app_has_perm('billing.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.edit'::text) AS app_has_perm)));
CREATE POLICY departments_delete ON public.departments AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY departments_insert ON public.departments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY departments_select ON public.departments AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY departments_update ON public.departments AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY diagnoses_delete ON public.diagnoses AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('emr.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(diagnoses.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY diagnoses_insert ON public.diagnoses AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('emr.create'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(diagnoses.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY diagnoses_select ON public.diagnoses AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('emr.read'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(diagnoses.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY diagnoses_update ON public.diagnoses AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('emr.update'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(diagnoses.visit_id) AS app_has_visit_branch_access))) WITH CHECK ((( SELECT app_has_perm('emr.update'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(diagnoses.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY employees_delete ON public.employees AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('users.delete'::text) AS app_has_perm));
CREATE POLICY employees_insert ON public.employees AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('users.create'::text) AS app_has_perm));
CREATE POLICY employees_select ON public.employees AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('users.read'::text) AS app_has_perm));
CREATE POLICY employees_update ON public.employees AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('users.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('users.update'::text) AS app_has_perm));
CREATE POLICY expenses_delete ON public.expenses AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('accounting.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(expenses.branch_id) AS app_has_branch_access)));
CREATE POLICY expenses_insert ON public.expenses AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('accounting.create'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(expenses.branch_id) AS app_has_branch_access)));
CREATE POLICY expenses_select ON public.expenses AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('accounting.read'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(expenses.branch_id) AS app_has_branch_access)));
CREATE POLICY expenses_update ON public.expenses AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('accounting.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(expenses.branch_id) AS app_has_branch_access))) WITH CHECK ((( SELECT app_has_perm('accounting.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(expenses.branch_id) AS app_has_branch_access)));
CREATE POLICY followups_delete ON public.followups AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('followups.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY followups_insert ON public.followups AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('followups.create'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY followups_select ON public.followups AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('followups.read'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY followups_update ON public.followups AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('followups.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id) AS app_has_patient_visit_branch_access))) WITH CHECK ((( SELECT app_has_perm('followups.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(followups.patient_id, followups.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY insurance_claim_items_ins ON public.insurance_claim_items AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((app_has_perm('insurance.create'::text) AND ( SELECT private.app_has_claim_branch(insurance_claim_items.claim_id) AS app_has_claim_branch)));
CREATE POLICY insurance_claim_items_sel ON public.insurance_claim_items AS PERMISSIVE FOR SELECT TO authenticated USING ((app_has_perm('insurance.read'::text) AND ( SELECT private.app_has_claim_branch(insurance_claim_items.claim_id) AS app_has_claim_branch)));
CREATE POLICY insurance_claim_payments_ins ON public.insurance_claim_payments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((app_has_perm('insurance.create'::text) AND ( SELECT private.app_has_claim_branch(insurance_claim_payments.claim_id) AS app_has_claim_branch)));
CREATE POLICY insurance_claim_payments_sel ON public.insurance_claim_payments AS PERMISSIVE FOR SELECT TO authenticated USING ((app_has_perm('insurance.read'::text) AND ( SELECT private.app_has_claim_branch(insurance_claim_payments.claim_id) AS app_has_claim_branch)));
CREATE POLICY insurance_claims_ins ON public.insurance_claims AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((app_has_perm('insurance.create'::text) AND ( SELECT private.app_has_invoice_branch(insurance_claims.invoice_id) AS app_has_invoice_branch)));
CREATE POLICY insurance_claims_sel ON public.insurance_claims AS PERMISSIVE FOR SELECT TO authenticated USING ((app_has_perm('insurance.read'::text) AND ( SELECT private.app_has_invoice_branch(insurance_claims.invoice_id) AS app_has_invoice_branch)));
CREATE POLICY insurance_claims_upd ON public.insurance_claims AS PERMISSIVE FOR UPDATE TO authenticated USING ((app_has_perm('insurance.update'::text) AND ( SELECT private.app_has_invoice_branch(insurance_claims.invoice_id) AS app_has_invoice_branch))) WITH CHECK ((app_has_perm('insurance.update'::text) AND ( SELECT private.app_has_invoice_branch(insurance_claims.invoice_id) AS app_has_invoice_branch)));
CREATE POLICY insurance_companies_ins ON public.insurance_companies AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (app_has_perm('insurance.create'::text));
CREATE POLICY insurance_companies_sel ON public.insurance_companies AS PERMISSIVE FOR SELECT TO authenticated USING (app_has_perm('insurance.read'::text));
CREATE POLICY insurance_companies_upd ON public.insurance_companies AS PERMISSIVE FOR UPDATE TO authenticated USING (app_has_perm('insurance.update'::text)) WITH CHECK (app_has_perm('insurance.update'::text));
CREATE POLICY insurance_coverage_rules_ins ON public.insurance_coverage_rules AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (app_has_perm('insurance.create'::text));
CREATE POLICY insurance_coverage_rules_sel ON public.insurance_coverage_rules AS PERMISSIVE FOR SELECT TO authenticated USING (app_has_perm('insurance.read'::text));
CREATE POLICY insurance_coverage_rules_upd ON public.insurance_coverage_rules AS PERMISSIVE FOR UPDATE TO authenticated USING (app_has_perm('insurance.update'::text)) WITH CHECK (app_has_perm('insurance.update'::text));
CREATE POLICY insurance_plans_ins ON public.insurance_plans AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (app_has_perm('insurance.create'::text));
CREATE POLICY insurance_plans_sel ON public.insurance_plans AS PERMISSIVE FOR SELECT TO authenticated USING (app_has_perm('insurance.read'::text));
CREATE POLICY insurance_plans_upd ON public.insurance_plans AS PERMISSIVE FOR UPDATE TO authenticated USING (app_has_perm('insurance.update'::text)) WITH CHECK (app_has_perm('insurance.update'::text));
CREATE POLICY insurance_prior_authorizations_ins ON public.insurance_prior_authorizations AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('insurance.create'::text) AS app_has_perm) AND ( SELECT private.app_has_prior_authorization_branch_access(insurance_prior_authorizations.patient_insurance_id) AS app_has_prior_authorization_branch_access)));
CREATE POLICY insurance_prior_authorizations_sel ON public.insurance_prior_authorizations AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('insurance.read'::text) AS app_has_perm) AND ( SELECT private.app_has_prior_authorization_branch_access(insurance_prior_authorizations.patient_insurance_id) AS app_has_prior_authorization_branch_access)));
CREATE POLICY insurance_prior_authorizations_upd ON public.insurance_prior_authorizations AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('insurance.update'::text) AS app_has_perm) AND ( SELECT private.app_has_prior_authorization_branch_access(insurance_prior_authorizations.patient_insurance_id) AS app_has_prior_authorization_branch_access))) WITH CHECK ((( SELECT app_has_perm('insurance.update'::text) AS app_has_perm) AND ( SELECT private.app_has_prior_authorization_branch_access(insurance_prior_authorizations.patient_insurance_id) AS app_has_prior_authorization_branch_access)));
CREATE POLICY invoice_items_delete ON public.invoice_items AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('billing.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_invoice_branch(invoice_items.invoice_id) AS app_has_invoice_branch)));
CREATE POLICY invoice_items_insert ON public.invoice_items AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('billing.create'::text) AS app_has_perm) AND ( SELECT private.app_has_invoice_branch(invoice_items.invoice_id) AS app_has_invoice_branch)));
CREATE POLICY invoice_items_select ON public.invoice_items AS PERMISSIVE FOR SELECT TO authenticated USING (((( SELECT app_has_perm('billing.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.view'::text) AS app_has_perm)) AND (EXISTS ( SELECT 1
   FROM invoices i
  WHERE ((i.id = invoice_items.invoice_id) AND ( SELECT private.app_has_branch_access(i.branch_id) AS app_has_branch_access))))));
CREATE POLICY invoice_items_update ON public.invoice_items AS PERMISSIVE FOR UPDATE TO authenticated USING (((( SELECT app_has_perm('billing.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.edit'::text) AS app_has_perm)) AND ( SELECT private.app_has_invoice_branch(invoice_items.invoice_id) AS app_has_invoice_branch))) WITH CHECK (((( SELECT app_has_perm('billing.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.edit'::text) AS app_has_perm)) AND ( SELECT private.app_has_invoice_branch(invoice_items.invoice_id) AS app_has_invoice_branch)));
CREATE POLICY invoices_delete ON public.invoices AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('billing.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(invoices.branch_id) AS app_has_branch_access)));
CREATE POLICY invoices_insert ON public.invoices AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('billing.create'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(invoices.branch_id) AS app_has_branch_access)));
CREATE POLICY invoices_select ON public.invoices AS PERMISSIVE FOR SELECT TO authenticated USING (((( SELECT app_has_perm('billing.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.view'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(invoices.branch_id) AS app_has_branch_access)));
CREATE POLICY invoices_update ON public.invoices AS PERMISSIVE FOR UPDATE TO authenticated USING (((( SELECT app_has_perm('billing.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.edit'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(invoices.branch_id) AS app_has_branch_access))) WITH CHECK (((( SELECT app_has_perm('billing.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.edit'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(invoices.branch_id) AS app_has_branch_access)));
CREATE POLICY lab_order_items_delete ON public.lab_order_items AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('lab.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id) AS app_has_lab_order_branch_access)));
CREATE POLICY lab_order_items_insert ON public.lab_order_items AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('lab.create'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id) AS app_has_lab_order_branch_access)));
CREATE POLICY lab_order_items_select ON public.lab_order_items AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('lab.read'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id) AS app_has_lab_order_branch_access)));
CREATE POLICY lab_order_items_update ON public.lab_order_items AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('lab.update'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id) AS app_has_lab_order_branch_access))) WITH CHECK ((( SELECT app_has_perm('lab.update'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_order_branch_access(lab_order_items.order_id) AS app_has_lab_order_branch_access)));
CREATE POLICY lab_orders_delete ON public.lab_orders AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('lab.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(lab_orders.branch_id) AS app_has_branch_access) AND ( SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id) AS lab_order_parent_ids_match)));
CREATE POLICY lab_orders_insert ON public.lab_orders AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('lab.create'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(lab_orders.branch_id) AS app_has_branch_access) AND ( SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id) AS lab_order_parent_ids_match)));
CREATE POLICY lab_orders_select ON public.lab_orders AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('lab.read'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(lab_orders.branch_id) AS app_has_branch_access) AND ( SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id) AS lab_order_parent_ids_match)));
CREATE POLICY lab_orders_update ON public.lab_orders AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('lab.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(lab_orders.branch_id) AS app_has_branch_access) AND ( SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id) AS lab_order_parent_ids_match))) WITH CHECK ((( SELECT app_has_perm('lab.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(lab_orders.branch_id) AS app_has_branch_access) AND ( SELECT private.lab_order_parent_ids_match(lab_orders.patient_id, lab_orders.visit_id) AS lab_order_parent_ids_match)));
CREATE POLICY lab_parameters_delete ON public.lab_parameters AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('lab_admin.delete'::text) AS app_has_perm));
CREATE POLICY lab_parameters_insert ON public.lab_parameters AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('lab_admin.create'::text) AS app_has_perm));
CREATE POLICY lab_parameters_select ON public.lab_parameters AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('lab.read'::text) AS app_has_perm));
CREATE POLICY lab_parameters_update ON public.lab_parameters AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('lab_admin.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('lab_admin.update'::text) AS app_has_perm));
CREATE POLICY lab_reference_ranges_delete ON public.lab_reference_ranges AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('lab_admin.delete'::text) AS app_has_perm));
CREATE POLICY lab_reference_ranges_insert ON public.lab_reference_ranges AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('lab_admin.create'::text) AS app_has_perm));
CREATE POLICY lab_reference_ranges_select ON public.lab_reference_ranges AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('lab.read'::text) AS app_has_perm));
CREATE POLICY lab_reference_ranges_update ON public.lab_reference_ranges AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('lab_admin.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('lab_admin.update'::text) AS app_has_perm));
CREATE POLICY lab_results_delete ON public.lab_results AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('lab.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id) AS app_has_lab_result_branch_access)));
CREATE POLICY lab_results_insert ON public.lab_results AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('lab.create'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id) AS app_has_lab_result_branch_access)));
CREATE POLICY lab_results_select ON public.lab_results AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('lab.read'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id) AS app_has_lab_result_branch_access)));
CREATE POLICY lab_results_update ON public.lab_results AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('lab.update'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id) AS app_has_lab_result_branch_access))) WITH CHECK ((( SELECT app_has_perm('lab.update'::text) AS app_has_perm) AND ( SELECT private.app_has_lab_result_branch_access(lab_results.order_item_id) AS app_has_lab_result_branch_access)));
CREATE POLICY lab_tests_delete ON public.lab_tests AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('lab_admin.delete'::text) AS app_has_perm));
CREATE POLICY lab_tests_insert ON public.lab_tests AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('lab_admin.create'::text) AS app_has_perm));
CREATE POLICY lab_tests_select ON public.lab_tests AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('lab.read'::text) AS app_has_perm));
CREATE POLICY lab_tests_update ON public.lab_tests AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('lab_admin.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('lab_admin.update'::text) AS app_has_perm));
CREATE POLICY medical_certificates_delete ON public.medical_certificates AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('certificates.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_branch(medical_certificates.patient_id) AS app_has_patient_branch)));
CREATE POLICY medical_certificates_insert ON public.medical_certificates AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('certificates.create'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_branch(medical_certificates.patient_id) AS app_has_patient_branch)));
CREATE POLICY medical_certificates_select ON public.medical_certificates AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('certificates.read'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_branch(medical_certificates.patient_id) AS app_has_patient_branch)));
CREATE POLICY medical_certificates_update ON public.medical_certificates AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('certificates.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_branch(medical_certificates.patient_id) AS app_has_patient_branch))) WITH CHECK ((( SELECT app_has_perm('certificates.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_branch(medical_certificates.patient_id) AS app_has_patient_branch)));
CREATE POLICY medicines_delete ON public.medicines AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('pharmacy.delete'::text) AS app_has_perm));
CREATE POLICY medicines_insert ON public.medicines AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('pharmacy.create'::text) AS app_has_perm));
CREATE POLICY medicines_select ON public.medicines AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('pharmacy.read'::text) AS app_has_perm));
CREATE POLICY medicines_update ON public.medicines AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm));
CREATE POLICY medicines_2_admin_only ON public.medicines_2 AS PERMISSIVE FOR ALL TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY partners_delete ON public.partners AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('partners.delete'::text) AS app_has_perm));
CREATE POLICY partners_insert ON public.partners AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('partners.create'::text) AS app_has_perm));
CREATE POLICY partners_select ON public.partners AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('partners.read'::text) AS app_has_perm));
CREATE POLICY partners_update ON public.partners AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('partners.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('partners.update'::text) AS app_has_perm));
CREATE POLICY patient_discounts_delete ON public.patient_discounts AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('billing.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_branch(patient_discounts.patient_id) AS app_has_patient_branch)));
CREATE POLICY patient_discounts_insert ON public.patient_discounts AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('billing.create'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_branch(patient_discounts.patient_id) AS app_has_patient_branch)));
CREATE POLICY patient_discounts_select ON public.patient_discounts AS PERMISSIVE FOR SELECT TO authenticated USING (((( SELECT app_has_perm('billing.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('patients.read'::text) AS app_has_perm)) AND ( SELECT private.app_has_patient_branch(patient_discounts.patient_id) AS app_has_patient_branch)));
CREATE POLICY patient_discounts_update ON public.patient_discounts AS PERMISSIVE FOR UPDATE TO authenticated USING (((( SELECT app_has_perm('billing.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.edit'::text) AS app_has_perm)) AND ( SELECT private.app_has_patient_branch(patient_discounts.patient_id) AS app_has_patient_branch))) WITH CHECK (((( SELECT app_has_perm('billing.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('billing.edit'::text) AS app_has_perm)) AND ( SELECT private.app_has_patient_branch(patient_discounts.patient_id) AS app_has_patient_branch)));
CREATE POLICY patient_insurance_ins ON public.patient_insurance AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((app_has_perm('insurance.create'::text) AND ( SELECT private.app_has_patient_branch(patient_insurance.patient_id) AS app_has_patient_branch)));
CREATE POLICY patient_insurance_sel ON public.patient_insurance AS PERMISSIVE FOR SELECT TO authenticated USING ((app_has_perm('insurance.read'::text) AND ( SELECT private.app_has_patient_branch(patient_insurance.patient_id) AS app_has_patient_branch)));
CREATE POLICY patient_insurance_upd ON public.patient_insurance AS PERMISSIVE FOR UPDATE TO authenticated USING ((app_has_perm('insurance.update'::text) AND ( SELECT private.app_has_patient_branch(patient_insurance.patient_id) AS app_has_patient_branch))) WITH CHECK ((app_has_perm('insurance.update'::text) AND ( SELECT private.app_has_patient_branch(patient_insurance.patient_id) AS app_has_patient_branch)));
CREATE POLICY patients_delete ON public.patients AS PERMISSIVE FOR DELETE TO authenticated USING ((app_has_perm('patients.delete'::text) AND ( SELECT private.app_has_branch_access(patients.branch_id) AS app_has_branch_access)));
CREATE POLICY patients_insert ON public.patients AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((app_has_perm('patients.create'::text) AND ( SELECT private.app_has_branch_access(patients.branch_id) AS app_has_branch_access)));
CREATE POLICY patients_select ON public.patients AS PERMISSIVE FOR SELECT TO authenticated USING ((app_has_perm('patients.read'::text) AND ( SELECT private.app_has_branch_access(patients.branch_id) AS app_has_branch_access)));
CREATE POLICY patients_update ON public.patients AS PERMISSIVE FOR UPDATE TO authenticated USING ((app_has_perm('patients.update'::text) AND ( SELECT private.app_has_branch_access(patients.branch_id) AS app_has_branch_access))) WITH CHECK ((app_has_perm('patients.update'::text) AND ( SELECT private.app_has_branch_access(patients.branch_id) AS app_has_branch_access)));
CREATE POLICY payments_delete ON public.payments AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('payments.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(payments.branch_id) AS app_has_branch_access)));
CREATE POLICY payments_insert ON public.payments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('payments.create'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(payments.branch_id) AS app_has_branch_access)));
CREATE POLICY payments_select ON public.payments AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('payments.read'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(payments.branch_id) AS app_has_branch_access)));
CREATE POLICY payments_update ON public.payments AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('payments.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(payments.branch_id) AS app_has_branch_access))) WITH CHECK ((( SELECT app_has_perm('payments.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(payments.branch_id) AS app_has_branch_access)));
CREATE POLICY permissions_delete ON public.permissions AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY permissions_insert ON public.permissions AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY permissions_select ON public.permissions AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY permissions_update ON public.permissions AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY pharmacy_inventory_delete ON public.pharmacy_inventory AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('pharmacy.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(pharmacy_inventory.branch_id) AS app_has_branch_access)));
CREATE POLICY pharmacy_inventory_insert ON public.pharmacy_inventory AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('pharmacy.create'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(pharmacy_inventory.branch_id) AS app_has_branch_access)));
CREATE POLICY pharmacy_inventory_select ON public.pharmacy_inventory AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('pharmacy.read'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(pharmacy_inventory.branch_id) AS app_has_branch_access)));
CREATE POLICY pharmacy_inventory_update ON public.pharmacy_inventory AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(pharmacy_inventory.branch_id) AS app_has_branch_access))) WITH CHECK ((( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(pharmacy_inventory.branch_id) AS app_has_branch_access)));
CREATE POLICY prescription_items_delete ON public.prescription_items AS PERMISSIVE FOR DELETE TO authenticated USING (((( SELECT app_has_perm('pharmacy.delete'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.delete'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id) AS app_has_prescription_branch_access)));
CREATE POLICY prescription_items_insert ON public.prescription_items AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((( SELECT app_has_perm('pharmacy.create'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.create'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id) AS app_has_prescription_branch_access)));
CREATE POLICY prescription_items_select ON public.prescription_items AS PERMISSIVE FOR SELECT TO authenticated USING (((( SELECT app_has_perm('pharmacy.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.read'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id) AS app_has_prescription_branch_access)));
CREATE POLICY prescription_items_update ON public.prescription_items AS PERMISSIVE FOR UPDATE TO authenticated USING (((( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.update'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id) AS app_has_prescription_branch_access))) WITH CHECK (((( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.update'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_branch_access(prescription_items.prescription_id) AS app_has_prescription_branch_access)));
CREATE POLICY prescriptions_delete ON public.prescriptions AS PERMISSIVE FOR DELETE TO authenticated USING (((( SELECT app_has_perm('pharmacy.delete'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.delete'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_parent_access(prescriptions.patient_id, prescriptions.visit_id) AS app_has_prescription_parent_access)));
CREATE POLICY prescriptions_insert ON public.prescriptions AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((( SELECT app_has_perm('pharmacy.create'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.create'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_parent_access(prescriptions.patient_id, prescriptions.visit_id) AS app_has_prescription_parent_access)));
CREATE POLICY prescriptions_select ON public.prescriptions AS PERMISSIVE FOR SELECT TO authenticated USING (((( SELECT app_has_perm('pharmacy.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.read'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_parent_access(prescriptions.patient_id, prescriptions.visit_id) AS app_has_prescription_parent_access)));
CREATE POLICY prescriptions_update ON public.prescriptions AS PERMISSIVE FOR UPDATE TO authenticated USING (((( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.update'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_parent_access(prescriptions.patient_id, prescriptions.visit_id) AS app_has_prescription_parent_access))) WITH CHECK (((( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('emr.update'::text) AS app_has_perm)) AND ( SELECT private.app_has_prescription_parent_access(prescriptions.patient_id, prescriptions.visit_id) AS app_has_prescription_parent_access)));
CREATE POLICY procedure_orders_delete ON public.procedure_orders AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('procedures.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY procedure_orders_insert ON public.procedure_orders AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('procedures.create'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY procedure_orders_select ON public.procedure_orders AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('procedures.read'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY procedure_orders_update ON public.procedure_orders AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('procedures.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id) AS app_has_patient_visit_branch_access))) WITH CHECK ((( SELECT app_has_perm('procedures.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(procedure_orders.patient_id, procedure_orders.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY procedure_results_delete ON public.procedure_results AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('procedures.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id) AS app_has_procedure_order_branch_access)));
CREATE POLICY procedure_results_insert ON public.procedure_results AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('procedures.create'::text) AS app_has_perm) AND ( SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id) AS app_has_procedure_order_branch_access)));
CREATE POLICY procedure_results_select ON public.procedure_results AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('procedures.read'::text) AS app_has_perm) AND ( SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id) AS app_has_procedure_order_branch_access)));
CREATE POLICY procedure_results_update ON public.procedure_results AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('procedures.update'::text) AS app_has_perm) AND ( SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id) AS app_has_procedure_order_branch_access))) WITH CHECK ((( SELECT app_has_perm('procedures.update'::text) AS app_has_perm) AND ( SELECT private.app_has_procedure_order_branch_access(procedure_results.procedure_order_id) AS app_has_procedure_order_branch_access)));
CREATE POLICY procedures_catalog_delete ON public.procedures_catalog AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('procedures.delete'::text) AS app_has_perm));
CREATE POLICY procedures_catalog_insert ON public.procedures_catalog AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('procedures.create'::text) AS app_has_perm));
CREATE POLICY procedures_catalog_select ON public.procedures_catalog AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('procedures.read'::text) AS app_has_perm));
CREATE POLICY procedures_catalog_update ON public.procedures_catalog AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('procedures.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('procedures.update'::text) AS app_has_perm));
CREATE POLICY profiles_select_own ON public.profiles AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT auth.uid() AS uid) = id));
CREATE POLICY profiles_update_own ON public.profiles AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT auth.uid() AS uid) = id)) WITH CHECK ((( SELECT auth.uid() AS uid) = id));
CREATE POLICY queue_tickets_del ON public.queue_tickets AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT is_super_admin() AS is_super_admin) AND ( SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY queue_tickets_ins ON public.queue_tickets AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('queue.create'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY queue_tickets_sel ON public.queue_tickets AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('queue.read'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY queue_tickets_upd ON public.queue_tickets AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('queue.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id) AS app_has_patient_visit_branch_access))) WITH CHECK ((( SELECT app_has_perm('queue.update'::text) AS app_has_perm) AND ( SELECT private.app_has_patient_visit_branch_access(queue_tickets.patient_id, queue_tickets.visit_id) AS app_has_patient_visit_branch_access)));
CREATE POLICY role_permissions_delete ON public.role_permissions AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY role_permissions_insert ON public.role_permissions AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY role_permissions_select ON public.role_permissions AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY role_permissions_update ON public.role_permissions AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY roles_delete ON public.roles AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY roles_insert ON public.roles AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY roles_select ON public.roles AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY roles_update ON public.roles AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('admin.full'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('admin.full'::text) AS app_has_perm));
CREATE POLICY services_delete ON public.services AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('settings.delete'::text) AS app_has_perm));
CREATE POLICY services_insert ON public.services AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('settings.create'::text) AS app_has_perm));
CREATE POLICY services_select ON public.services AS PERMISSIVE FOR SELECT TO authenticated USING (( SELECT app_has_perm('settings.read'::text) AS app_has_perm));
CREATE POLICY services_update ON public.services AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('settings.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('settings.update'::text) AS app_has_perm));
CREATE POLICY stock_movements_select ON public.stock_movements AS PERMISSIVE FOR SELECT TO public USING ((app_has_perm('pharmacy.read'::text) AND ( SELECT private.app_has_branch_access(stock_movements.branch_id) AS app_has_branch_access)));
CREATE POLICY supplier_bills_del ON public.supplier_bills AS PERMISSIVE FOR DELETE TO authenticated USING ((is_super_admin() AND ( SELECT private.app_has_branch_access(supplier_bills.branch_id) AS app_has_branch_access)));
CREATE POLICY supplier_bills_ins ON public.supplier_bills AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((( SELECT app_has_perm('debts.create'::text) AS app_has_perm) OR ( SELECT app_has_perm('accounting.create'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(supplier_bills.branch_id) AS app_has_branch_access)));
CREATE POLICY supplier_bills_sel ON public.supplier_bills AS PERMISSIVE FOR SELECT TO authenticated USING (((( SELECT app_has_perm('debts.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('accounting.read'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(supplier_bills.branch_id) AS app_has_branch_access)));
CREATE POLICY supplier_bills_upd ON public.supplier_bills AS PERMISSIVE FOR UPDATE TO authenticated USING (((( SELECT app_has_perm('debts.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('accounting.update'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(supplier_bills.branch_id) AS app_has_branch_access))) WITH CHECK (((( SELECT app_has_perm('debts.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('accounting.update'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(supplier_bills.branch_id) AS app_has_branch_access)));
CREATE POLICY supplier_payments_del ON public.supplier_payments AS PERMISSIVE FOR DELETE TO authenticated USING ((is_super_admin() AND ( SELECT private.app_has_branch_access(supplier_payments.branch_id) AS app_has_branch_access)));
CREATE POLICY supplier_payments_ins ON public.supplier_payments AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (((( SELECT app_has_perm('debts.create'::text) AS app_has_perm) OR ( SELECT app_has_perm('accounting.create'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(supplier_payments.branch_id) AS app_has_branch_access)));
CREATE POLICY supplier_payments_sel ON public.supplier_payments AS PERMISSIVE FOR SELECT TO authenticated USING (((( SELECT app_has_perm('debts.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('accounting.read'::text) AS app_has_perm)) AND ( SELECT private.app_has_branch_access(supplier_payments.branch_id) AS app_has_branch_access)));
CREATE POLICY supplier_payments_upd ON public.supplier_payments AS PERMISSIVE FOR UPDATE TO authenticated USING ((app_has_perm('accounting.update'::text) AND ( SELECT private.app_has_branch_access(supplier_payments.branch_id) AS app_has_branch_access))) WITH CHECK ((app_has_perm('accounting.update'::text) AND ( SELECT private.app_has_branch_access(supplier_payments.branch_id) AS app_has_branch_access)));
CREATE POLICY suppliers_delete ON public.suppliers AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('pharmacy.delete'::text) AS app_has_perm));
CREATE POLICY suppliers_insert ON public.suppliers AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('suppliers.create'::text) AS app_has_perm) OR ( SELECT app_has_perm('pharmacy.create'::text) AS app_has_perm)));
CREATE POLICY suppliers_select ON public.suppliers AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('suppliers.read'::text) AS app_has_perm) OR ( SELECT app_has_perm('pharmacy.read'::text) AS app_has_perm)));
CREATE POLICY suppliers_update ON public.suppliers AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('suppliers.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm))) WITH CHECK ((( SELECT app_has_perm('suppliers.update'::text) AS app_has_perm) OR ( SELECT app_has_perm('pharmacy.update'::text) AS app_has_perm)));
CREATE POLICY system_settings_delete ON public.system_settings AS PERMISSIVE FOR DELETE TO authenticated USING (( SELECT app_has_perm('settings.delete'::text) AS app_has_perm));
CREATE POLICY system_settings_insert ON public.system_settings AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK (( SELECT app_has_perm('settings.create'::text) AS app_has_perm));
CREATE POLICY system_settings_sel ON public.system_settings AS PERMISSIVE FOR SELECT TO authenticated USING (((is_public = true) OR app_has_perm('settings.read'::text)));
CREATE POLICY system_settings_update ON public.system_settings AS PERMISSIVE FOR UPDATE TO authenticated USING (( SELECT app_has_perm('settings.update'::text) AS app_has_perm)) WITH CHECK (( SELECT app_has_perm('settings.update'::text) AS app_has_perm));
CREATE POLICY users_delete ON public.users AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('users.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(users.branch_id) AS app_has_branch_access)));
CREATE POLICY users_insert ON public.users AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('users.create'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(users.branch_id) AS app_has_branch_access)));
CREATE POLICY users_select ON public.users AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('users.read'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(users.branch_id) AS app_has_branch_access)));
CREATE POLICY users_update ON public.users AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('users.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(users.branch_id) AS app_has_branch_access))) WITH CHECK ((( SELECT app_has_perm('users.update'::text) AS app_has_perm) AND ( SELECT private.app_has_branch_access(users.branch_id) AS app_has_branch_access)));
CREATE POLICY visits_del ON public.visits AS PERMISSIVE FOR DELETE TO authenticated USING ((is_super_admin() AND ( SELECT private.app_has_branch_access(visits.branch_id) AS app_has_branch_access)));
CREATE POLICY visits_ins ON public.visits AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((app_has_perm('visits.create'::text) AND ( SELECT private.app_has_branch_access(visits.branch_id) AS app_has_branch_access)));
CREATE POLICY visits_sel ON public.visits AS PERMISSIVE FOR SELECT TO authenticated USING ((app_has_perm('visits.read'::text) AND ( SELECT private.app_has_branch_access(visits.branch_id) AS app_has_branch_access)));
CREATE POLICY visits_upd ON public.visits AS PERMISSIVE FOR UPDATE TO authenticated USING ((app_has_perm('visits.update'::text) AND ( SELECT private.app_has_branch_access(visits.branch_id) AS app_has_branch_access))) WITH CHECK ((app_has_perm('visits.update'::text) AND ( SELECT private.app_has_branch_access(visits.branch_id) AS app_has_branch_access)));
CREATE POLICY vitals_delete ON public.vitals AS PERMISSIVE FOR DELETE TO authenticated USING ((( SELECT app_has_perm('emr.delete'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(vitals.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY vitals_insert ON public.vitals AS PERMISSIVE FOR INSERT TO authenticated WITH CHECK ((( SELECT app_has_perm('emr.create'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(vitals.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY vitals_select ON public.vitals AS PERMISSIVE FOR SELECT TO authenticated USING ((( SELECT app_has_perm('emr.read'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(vitals.visit_id) AS app_has_visit_branch_access)));
CREATE POLICY vitals_update ON public.vitals AS PERMISSIVE FOR UPDATE TO authenticated USING ((( SELECT app_has_perm('emr.update'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(vitals.visit_id) AS app_has_visit_branch_access))) WITH CHECK ((( SELECT app_has_perm('emr.update'::text) AS app_has_perm) AND ( SELECT private.app_has_visit_branch_access(vitals.visit_id) AS app_has_visit_branch_access)));

-- Views
CREATE OR REPLACE VIEW public.cashbox_balance AS  SELECT COALESCE(sum(amount), 0::numeric)::numeric(14,2) AS balance,
    COALESCE(sum(
        CASE
            WHEN amount > 0::numeric THEN amount
            ELSE 0::numeric
        END), 0::numeric)::numeric(14,2) AS total_in,
    COALESCE(sum(
        CASE
            WHEN amount < 0::numeric THEN - amount
            ELSE 0::numeric
        END), 0::numeric)::numeric(14,2) AS total_out
   FROM cashbox_transactions
  WHERE deleted_at IS NULL;;
CREATE OR REPLACE VIEW public.follow_ups AS  SELECT f.id,
    f.patient_id,
    f.visit_id,
    f.followup_date,
    f.followup_date AS follow_up_date,
    p.mrn AS patient_number,
    f.notes,
    f.status,
    f.reason,
    f.completed_at,
    f.created_at,
    f.created_by,
    f.updated_by,
    f.deleted_at,
    f.deleted_by
   FROM followups f
     LEFT JOIN patients p ON p.id = f.patient_id
  WHERE f.deleted_at IS NULL;;
CREATE OR REPLACE VIEW public.followups_with_creator AS  SELECT f.id,
    f.patient_id,
    f.visit_id,
    f.followup_date,
    f.notes,
    f.status,
    f.created_at,
    f.created_by,
    f.updated_by,
    f.deleted_at,
    f.deleted_by,
    f.reason,
    f.completed_at,
    u.full_name AS creator_full_name
   FROM followups f
     LEFT JOIN users u ON u.id = f.created_by;;
CREATE OR REPLACE VIEW public.v_patient_receivables AS  SELECT i.id AS invoice_id,
    i.invoice_number,
    i.invoice_date,
    i.patient_id,
    p.full_name AS patient_name,
    p.mrn,
    p.phone,
    COALESCE(i.net_amount, i.total_amount, 0::numeric)::numeric(14,2) AS net_amount,
    COALESCE(i.paid_amount, 0::numeric)::numeric(14,2) AS paid_amount,
    GREATEST(COALESCE(i.net_amount, i.total_amount, 0::numeric) - COALESCE(i.paid_amount, 0::numeric), 0::numeric)::numeric(14,2) AS outstanding,
    COALESCE(i.status, i.payment_status::text, 'unpaid'::text) AS status
   FROM invoices i
     LEFT JOIN patients p ON p.id = i.patient_id
  WHERE i.deleted_at IS NULL AND GREATEST(COALESCE(i.net_amount, i.total_amount, 0::numeric) - COALESCE(i.paid_amount, 0::numeric), 0::numeric) > 0::numeric;;
CREATE OR REPLACE VIEW public.v_supplier_outstanding AS  SELECT s.id AS supplier_id,
    s.name,
    s.phone,
    count(b.id) FILTER (WHERE b.id IS NOT NULL) AS bills_count,
    COALESCE(sum(b.total_amount), 0::numeric)::numeric(14,2) AS total_billed,
    COALESCE(sum(b.paid_amount), 0::numeric)::numeric(14,2) AS total_paid,
    COALESCE(sum(GREATEST(b.total_amount - b.paid_amount, 0::numeric)), 0::numeric)::numeric(14,2) AS outstanding
   FROM suppliers s
     LEFT JOIN supplier_bills b ON b.supplier_id = s.id AND b.deleted_at IS NULL
  WHERE s.deleted_at IS NULL
  GROUP BY s.id, s.name, s.phone;;


-- Triggers
CREATE TRIGGER trg_cashbox_immutable BEFORE DELETE OR UPDATE ON public.cashbox_transactions FOR EACH ROW EXECUTE FUNCTION fn_cashbox_immutable();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.cashbox_transactions FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_audit_certificates AFTER INSERT OR DELETE OR UPDATE ON public.certificates FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_clinical_notes AFTER INSERT OR DELETE OR UPDATE ON public.clinical_notes FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_diagnoses AFTER INSERT OR DELETE OR UPDATE ON public.diagnoses FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_ledger_from_expense AFTER INSERT ON public.expenses FOR EACH ROW EXECUTE FUNCTION fn_ledger_from_expense();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.insurance_claims FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.insurance_companies FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.insurance_plans FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_audit_invoice_items AFTER INSERT OR DELETE OR UPDATE ON public.invoice_items FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_invoices AFTER INSERT OR DELETE OR UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_lab_order_items AFTER INSERT OR DELETE OR UPDATE ON public.lab_order_items FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_lab_orders AFTER INSERT OR DELETE OR UPDATE ON public.lab_orders FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_lab_results AFTER INSERT OR DELETE OR UPDATE ON public.lab_results FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_sync_medicines_2_stock_columns BEFORE INSERT OR UPDATE OF stock, stock_quantity ON public.medicines_2 FOR EACH ROW EXECUTE FUNCTION sync_medicines_2_stock_columns();
CREATE TRIGGER trg_normalize_medicine_names BEFORE INSERT OR UPDATE ON public.medicines FOR EACH ROW EXECUTE FUNCTION normalize_medicine_names();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.patient_insurance FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_audit_patients AFTER INSERT OR DELETE OR UPDATE ON public.patients FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_ledger_from_payment AFTER INSERT ON public.payments FOR EACH ROW EXECUTE FUNCTION fn_ledger_from_payment();
CREATE TRIGGER trg_recompute_invoice_paid AFTER INSERT OR DELETE OR UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION fn_recompute_invoice_paid();
CREATE TRIGGER trg_audit_pharmacy_inventory AFTER INSERT OR DELETE OR UPDATE ON public.pharmacy_inventory FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_sync_pharmacy_inventory_legacy BEFORE INSERT OR UPDATE ON public.pharmacy_inventory FOR EACH ROW EXECUTE FUNCTION sync_pharmacy_inventory_legacy_columns();
CREATE TRIGGER trg_audit_prescription_items AFTER INSERT OR DELETE OR UPDATE ON public.prescription_items FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_prescriptions AFTER INSERT OR DELETE OR UPDATE ON public.prescriptions FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_procedure_orders AFTER INSERT OR DELETE OR UPDATE ON public.procedure_orders FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_queue_ticket_sync_number BEFORE INSERT OR UPDATE OF visit_id, queue_number ON public.queue_tickets FOR EACH ROW EXECUTE FUNCTION private.sync_queue_ticket_number();
CREATE TRIGGER trg_audit_role_permissions AFTER INSERT OR DELETE OR UPDATE ON public.role_permissions FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_guard_super_admin_role_permissions BEFORE INSERT OR DELETE OR UPDATE ON public.role_permissions FOR EACH ROW EXECUTE FUNCTION private.guard_super_admin_role_permissions();
CREATE TRIGGER trg_guard_super_admin_roles BEFORE INSERT OR DELETE OR UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION private.guard_super_admin_roles();
CREATE TRIGGER trg_audit_stock_movements AFTER INSERT OR DELETE OR UPDATE ON public.stock_movements FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.supplier_bills FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_finance_audit AFTER INSERT OR DELETE OR UPDATE ON public.supplier_payments FOR EACH ROW EXECUTE FUNCTION fn_finance_audit();
CREATE TRIGGER trg_ledger_from_supplier_payment AFTER INSERT ON public.supplier_payments FOR EACH ROW EXECUTE FUNCTION fn_ledger_from_supplier_payment();
CREATE TRIGGER trg_recompute_supplier_bill AFTER INSERT OR DELETE OR UPDATE ON public.supplier_payments FOR EACH ROW EXECUTE FUNCTION fn_recompute_supplier_bill();
CREATE TRIGGER trg_sync_supplier_bill_payment AFTER INSERT OR UPDATE ON public.supplier_payments FOR EACH ROW EXECUTE FUNCTION sync_supplier_bill_payment();
CREATE TRIGGER tr_enforce_public_system_setting_keys BEFORE INSERT OR UPDATE ON public.system_settings FOR EACH ROW EXECUTE FUNCTION enforce_public_system_setting_keys();
CREATE TRIGGER trg_audit_system_settings AFTER INSERT OR DELETE OR UPDATE ON public.system_settings FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_audit_users AFTER INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_guard_super_admin_users BEFORE INSERT OR DELETE OR UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION private.guard_super_admin_users();
CREATE TRIGGER trg_sync_user_role_text BEFORE INSERT OR UPDATE OF role_id ON public.users FOR EACH ROW EXECUTE FUNCTION private.sync_user_role_text();
CREATE TRIGGER on_visit_created AFTER INSERT ON public.visits FOR EACH ROW EXECUTE FUNCTION private.create_queue_ticket();
CREATE TRIGGER trg_audit_visits AFTER INSERT OR DELETE OR UPDATE ON public.visits FOR EACH ROW EXECUTE FUNCTION audit_row_change();
CREATE TRIGGER trg_prevent_locked_visit_mutation BEFORE DELETE OR UPDATE ON public.visits FOR EACH ROW EXECUTE FUNCTION private.prevent_locked_visit_mutation();
CREATE TRIGGER trg_visits_ensure_queue BEFORE INSERT ON public.visits FOR EACH ROW EXECUTE FUNCTION private.ensure_visit_queue();
CREATE TRIGGER trg_audit_vitals AFTER INSERT OR DELETE OR UPDATE ON public.vitals FOR EACH ROW EXECUTE FUNCTION audit_row_change();

-- Canonical catalog count assertions.
DO $baseline_assertions$ BEGIN
 IF (SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE') <> 56 THEN RAISE EXCEPTION 'baseline table count mismatch'; END IF;
 IF (SELECT count(*) FROM pg_policies WHERE schemaname='public') <> 203 THEN RAISE EXCEPTION 'baseline RLS policy count mismatch'; END IF;
 IF (SELECT count(*) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname='public' AND NOT t.tgisinternal) <> 47 THEN RAISE EXCEPTION 'baseline trigger count mismatch'; END IF;
END $baseline_assertions$;
COMMIT;
