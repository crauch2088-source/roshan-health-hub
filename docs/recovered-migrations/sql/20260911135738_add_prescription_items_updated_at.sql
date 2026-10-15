ALTER TABLE public.prescription_items
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

UPDATE public.prescription_items
SET updated_at = COALESCE(created_at, now())
WHERE updated_at IS NULL;
