-- Disposable PostgreSQL 17 fixture for Phase 47 visit/queue branch attribution.
CREATE SCHEMA IF NOT EXISTS private;
DO $roles$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF;
END
$roles$;

CREATE TABLE public.branches(
 id uuid PRIMARY KEY, active boolean NOT NULL DEFAULT true,
 is_active boolean NOT NULL DEFAULT true, deleted_at timestamptz
);
CREATE TABLE public.patients(
 id uuid PRIMARY KEY, branch_id uuid REFERENCES public.branches(id),
 full_name text NOT NULL, gender text NOT NULL, deleted_at timestamptz
);
CREATE TABLE public.visits(
 id uuid PRIMARY KEY, patient_id uuid NOT NULL REFERENCES public.patients(id),
 branch_id uuid REFERENCES public.branches(id), status text NOT NULL DEFAULT 'waiting',
 visit_date date NOT NULL DEFAULT current_date, deleted_at timestamptz
);
CREATE TABLE public.queue_tickets(
 id uuid PRIMARY KEY, visit_id uuid REFERENCES public.visits(id),
 patient_id uuid REFERENCES public.patients(id), queue_number text,
 status text, visit_date date, created_at timestamptz DEFAULT now(),
 deleted_at timestamptz, called_at timestamptz, completed_at timestamptz
);

INSERT INTO public.branches(id,active,is_active) VALUES
 ('00000000-0000-0000-0000-000000047001',true,true),
 ('00000000-0000-0000-0000-000000047002',false,false);
INSERT INTO public.patients(id,branch_id,full_name,gender) VALUES
 ('00000000-0000-0000-0000-000000047101','00000000-0000-0000-0000-000000047001','Synthetic patient A','male'),
 ('00000000-0000-0000-0000-000000047102','00000000-0000-0000-0000-000000047002','Synthetic patient B','female'),
 ('00000000-0000-0000-0000-000000047103',NULL,'Synthetic patient C','other');
-- Legacy visit has no branch, but its patient belongs to the only active branch.
INSERT INTO public.visits(id,patient_id,branch_id,status) VALUES
 ('00000000-0000-0000-0000-000000047201','00000000-0000-0000-0000-000000047101',NULL,'waiting'),
 ('00000000-0000-0000-0000-000000047202','00000000-0000-0000-0000-000000047102',NULL,'waiting'),
 ('00000000-0000-0000-0000-000000047203','00000000-0000-0000-0000-000000047101','00000000-0000-0000-0000-000000047001','completed'),
 ('00000000-0000-0000-0000-000000047204','00000000-0000-0000-0000-000000047103',NULL,'waiting');
UPDATE public.visits SET deleted_at=now() WHERE id='00000000-0000-0000-0000-000000047203';
INSERT INTO public.queue_tickets(id,visit_id,patient_id,queue_number,status,visit_date)
VALUES ('00000000-0000-0000-0000-000000047301','00000000-0000-0000-0000-000000047201','00000000-0000-0000-0000-000000047101','Q001','waiting',current_date),
       ('00000000-0000-0000-0000-000000047302',NULL,NULL,'QLEG','waiting',current_date);
