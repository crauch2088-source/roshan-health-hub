-- Disposable PostgreSQL 17 fixture for Phase 46 UAT schema compatibility.
CREATE SCHEMA IF NOT EXISTS private;

DO $roles$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN;
  END IF;
END
$roles$;

CREATE TABLE public.branches (
  id uuid PRIMARY KEY
);

CREATE TABLE public.patients (
  id uuid PRIMARY KEY,
  full_name text NOT NULL
);

CREATE TABLE public.visits (
  id uuid PRIMARY KEY,
  patient_id uuid NOT NULL REFERENCES public.patients(id),
  branch_id uuid REFERENCES public.branches(id),
  status text NOT NULL DEFAULT 'waiting',
  deleted_at timestamptz
);

-- Intentionally model the pre-fix production schema: neither Phase 46 column exists.
CREATE TABLE public.prescriptions (
  id uuid PRIMARY KEY,
  patient_id uuid NOT NULL REFERENCES public.patients(id),
  visit_id uuid REFERENCES public.visits(id),
  status text NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

INSERT INTO public.branches(id) VALUES
  ('00000000-0000-0000-0000-000000046001'),
  ('00000000-0000-0000-0000-000000046002');

INSERT INTO public.patients(id, full_name) VALUES
  ('00000000-0000-0000-0000-000000046101', 'Synthetic Patient A'),
  ('00000000-0000-0000-0000-000000046102', 'Synthetic Patient B'),
  ('00000000-0000-0000-0000-000000046103', 'Synthetic Patient C');

INSERT INTO public.visits(id, patient_id, branch_id, status, deleted_at) VALUES
  ('00000000-0000-0000-0000-000000046201',
   '00000000-0000-0000-0000-000000046101',
   '00000000-0000-0000-0000-000000046001', 'waiting', NULL),
  ('00000000-0000-0000-0000-000000046202',
   '00000000-0000-0000-0000-000000046102',
   '00000000-0000-0000-0000-000000046002', 'waiting', NULL),
  ('00000000-0000-0000-0000-000000046203',
   '00000000-0000-0000-0000-000000046103',
   '00000000-0000-0000-0000-000000046001', 'completed',
   '2026-10-30T10:00:00Z');

INSERT INTO public.prescriptions(id, patient_id, visit_id, status) VALUES
  ('00000000-0000-0000-0000-000000046301',
   '00000000-0000-0000-0000-000000046101',
   '00000000-0000-0000-0000-000000046201', 'pending'),
  ('00000000-0000-0000-0000-000000046302',
   '00000000-0000-0000-0000-000000046102',
   '00000000-0000-0000-0000-000000046202', 'pending'),
  ('00000000-0000-0000-0000-000000046303',
   '00000000-0000-0000-0000-000000046103',
   NULL, 'external');
