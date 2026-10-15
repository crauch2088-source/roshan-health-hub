-- Disposable PostgreSQL fixture for pharmacy dispense + consolidated invoicing.
ALTER TABLE public.visits ADD COLUMN branch_id uuid;

CREATE TABLE public.medicines (
  id uuid PRIMARY KEY,
  name text NOT NULL,
  selling_price numeric,
  stock_quantity integer NOT NULL DEFAULT 0,
  active boolean DEFAULT true,
  is_active boolean DEFAULT true,
  deleted_at timestamptz,
  updated_at timestamptz DEFAULT now(),
  updated_by uuid
);

CREATE TABLE public.prescriptions (
  id uuid PRIMARY KEY,
  patient_id uuid NOT NULL,
  visit_id uuid,
  status text NOT NULL DEFAULT 'pending',
  is_external boolean DEFAULT false,
  dispensed_by uuid,
  dispensed_at timestamptz,
  deleted_at timestamptz,
  updated_at timestamptz DEFAULT now(),
  updated_by uuid
);

CREATE TABLE public.prescription_items (
  id uuid PRIMARY KEY,
  prescription_id uuid NOT NULL,
  medicine_id uuid,
  medication_name text,
  quantity numeric,
  dosage text,
  frequency text,
  duration text,
  is_dispensed boolean DEFAULT false,
  dispensed_quantity integer DEFAULT 0,
  deleted_at timestamptz,
  updated_at timestamptz DEFAULT now(),
  updated_by uuid
);

CREATE TABLE public.pharmacy_inventory (
  id uuid PRIMARY KEY,
  medicine_id uuid NOT NULL,
  batch_number text,
  expiry_date date,
  quantity numeric,
  quantity_remaining numeric NOT NULL,
  branch_id uuid,
  deleted_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  updated_by uuid
);

CREATE TABLE public.stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  medicine_id uuid NOT NULL,
  batch_id uuid,
  movement_type text NOT NULL,
  quantity numeric NOT NULL,
  reference_id uuid,
  reference_table text,
  notes text,
  branch_id uuid,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE ON public.medicines, public.prescriptions,
  public.prescription_items, public.pharmacy_inventory, public.stock_movements TO authenticated;

-- The deployed legacy RPC is deliberately present so the migration must close its bypass.
CREATE FUNCTION public.fn_dispense_prescription(p_prescription_id uuid)
RETURNS TABLE(item_id uuid, medicine_id uuid, medicine_name text, batch_id uuid,
  batch_number text, expiry_date date, quantity_dispensed numeric,
  batch_quantity_remaining numeric, source text)
LANGUAGE plpgsql AS $$
BEGIN
  RAISE EXCEPTION 'legacy dispense RPC should be revoked';
END;
$$;
GRANT EXECUTE ON FUNCTION public.fn_dispense_prescription(uuid) TO authenticated;
