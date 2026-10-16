ALTER TABLE public.medicines_2 ADD COLUMN IF NOT EXISTS stock_quantity integer NOT NULL DEFAULT 0;
UPDATE public.medicines_2 SET stock_quantity = COALESCE(stock, 0) WHERE stock_quantity IS DISTINCT FROM COALESCE(stock, 0);

CREATE OR REPLACE FUNCTION public.sync_medicines_2_stock_columns()
RETURNS trigger
LANGUAGE plpgsql
AS $$
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
$$;

DROP TRIGGER IF EXISTS trg_sync_medicines_2_stock_columns ON public.medicines_2;
CREATE TRIGGER trg_sync_medicines_2_stock_columns
BEFORE INSERT OR UPDATE OF stock, stock_quantity ON public.medicines_2
FOR EACH ROW EXECUTE FUNCTION public.sync_medicines_2_stock_columns();
