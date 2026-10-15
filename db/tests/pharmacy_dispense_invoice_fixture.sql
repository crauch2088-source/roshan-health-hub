-- Extend the shared invoice fixture with only the FEFO-specific tables/columns.
-- medicines, prescriptions, prescription_items and the legacy dispense RPC are already
-- defined by visit_invoice_consolidation_fixture.sql.
ALTER TABLE public.visits ADD COLUMN IF NOT EXISTS branch_id uuid;
ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS brand_name text;
ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS generic_name text;
ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS is_active boolean DEFAULT true;

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

GRANT SELECT, INSERT, UPDATE ON public.pharmacy_inventory, public.stock_movements TO authenticated;
