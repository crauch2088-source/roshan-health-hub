CREATE OR REPLACE FUNCTION public.normalize_medicine_names()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
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
$$;

DROP TRIGGER IF EXISTS trg_normalize_medicine_names ON public.medicines;
CREATE TRIGGER trg_normalize_medicine_names
BEFORE INSERT OR UPDATE ON public.medicines
FOR EACH ROW
EXECUTE FUNCTION public.normalize_medicine_names();

REVOKE ALL ON FUNCTION public.normalize_medicine_names() FROM PUBLIC, anon, authenticated;
