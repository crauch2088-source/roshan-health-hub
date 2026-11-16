CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE ROLE authenticator NOLOGIN;

CREATE SCHEMA private;

CREATE TABLE public.prescription_items (
  id uuid PRIMARY KEY,
  prescription_id uuid NOT NULL,
  medicine_id uuid,
  medication_name text,
  dose text,
  dosage text,
  frequency text,
  duration text,
  quantity numeric,
  dosage_form text,
  route text,
  instructions text,
  deleted_at timestamptz
);

GRANT SELECT, INSERT, UPDATE ON public.prescription_items TO authenticated;
