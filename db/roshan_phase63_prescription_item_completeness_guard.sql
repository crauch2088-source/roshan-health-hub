BEGIN;

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.validate_prescription_item_completeness()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_dose text;
BEGIN
  -- Preserve historical incomplete rows and allow them to be soft-deleted.
  IF NEW.deleted_at IS NOT NULL THEN
    RETURN NEW;
  END IF;

  IF NULLIF(btrim(COALESCE(NEW.medication_name, '')), '') IS NULL THEN
    RAISE EXCEPTION 'prescription item medication name is required'
      USING ERRCODE = '23514';
  END IF;

  -- Older rows may have populated only the legacy dosage field. Normalize
  -- whichever non-empty value exists into the other field for new writes.
  v_dose := COALESCE(
    NULLIF(btrim(COALESCE(NEW.dose, '')), ''),
    NULLIF(btrim(COALESCE(NEW.dosage, '')), '')
  );
  IF v_dose IS NULL THEN
    RAISE EXCEPTION 'prescription item dose is required'
      USING ERRCODE = '23514';
  END IF;
  IF NULLIF(btrim(COALESCE(NEW.dose, '')), '') IS NULL THEN
    NEW.dose := v_dose;
  END IF;
  IF NULLIF(btrim(COALESCE(NEW.dosage, '')), '') IS NULL THEN
    NEW.dosage := v_dose;
  END IF;

  -- The legacy and current fields represent the same prescribed dose. Do not
  -- let conflicting values produce different displays across old/new clients.
  IF btrim(NEW.dose) IS DISTINCT FROM btrim(NEW.dosage) THEN
    RAISE EXCEPTION 'prescription item dose and legacy dosage must match'
      USING ERRCODE = '23514';
  END IF;

  IF NULLIF(btrim(COALESCE(NEW.frequency, '')), '') IS NULL THEN
    RAISE EXCEPTION 'prescription item frequency is required'
      USING ERRCODE = '23514';
  END IF;

  IF NULLIF(btrim(COALESCE(NEW.duration, '')), '') IS NULL THEN
    RAISE EXCEPTION 'prescription item duration is required'
      USING ERRCODE = '23514';
  END IF;

  IF NULLIF(btrim(COALESCE(NEW.dosage_form, '')), '') IS NULL THEN
    RAISE EXCEPTION 'prescription item dosage form is required'
      USING ERRCODE = '23514';
  END IF;

  IF NULLIF(btrim(COALESCE(NEW.route, '')), '') IS NULL THEN
    RAISE EXCEPTION 'prescription item administration route is required'
      USING ERRCODE = '23514';
  END IF;

  IF NEW.quantity IS NULL
     OR NEW.quantity::text IN ('NaN', 'Infinity', '-Infinity')
     OR NEW.quantity <= 0
     OR NEW.quantity <> trunc(NEW.quantity)
     OR NEW.quantity > 2147483647 THEN
    RAISE EXCEPTION 'prescription item quantity must be a positive whole number'
      USING ERRCODE = '23514';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION private.validate_prescription_item_completeness()
  FROM PUBLIC, anon, authenticated, service_role, authenticator;

COMMENT ON FUNCTION private.validate_prescription_item_completeness() IS
  'Phase 63: server-side completeness guard for new/edited prescription items. It does not infer dose, frequency, duration, form, route, or quantity; historical soft-deleted rows are preserved.';

DROP TRIGGER IF EXISTS trg_prescription_item_completeness_guard
  ON public.prescription_items;

CREATE TRIGGER trg_prescription_item_completeness_guard
BEFORE INSERT OR UPDATE OF
  medication_name, dose, dosage, frequency, duration, quantity,
  dosage_form, route, deleted_at
ON public.prescription_items
FOR EACH ROW
EXECUTE FUNCTION private.validate_prescription_item_completeness();

COMMIT;
