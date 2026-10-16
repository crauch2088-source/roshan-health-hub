ALTER TABLE public.prescriptions
ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

UPDATE public.prescriptions
SET updated_at = COALESCE(created_at, now())
WHERE updated_at IS NULL;
