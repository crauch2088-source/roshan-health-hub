ALTER TABLE public.medicines ADD COLUMN IF NOT EXISTS stock_quantity integer NOT NULL DEFAULT 0;

UPDATE public.medicines m
SET stock_quantity = COALESCE((
  SELECT SUM(pi.quantity)::integer
  FROM public.pharmacy_inventory pi
  WHERE pi.medicine_id = m.id
    AND pi.deleted_at IS NULL
), 0)
WHERE m.stock_quantity = 0;

NOTIFY pgrst, 'reload schema';
