BEGIN;

DO $phase63_assertions$
DECLARE
  v_id uuid;
  v_rejected boolean;
  v_value text;
BEGIN
  -- New writes are accepted when all clinical fields are explicit. The
  -- legacy dosage field is normalized to dose for consistent printing.
  INSERT INTO public.prescription_items (
    id,prescription_id,medication_name,dose,dosage,frequency,duration,
    quantity,dosage_form,route
  ) VALUES (
    '63000000-0000-0000-0000-000000000001',
    '63000000-0000-0000-0000-000000000101',
    'Synthetic medicine',NULL,'500 mg','twice daily','5 days',
    10,'tablet','oral'
  );
  SELECT dose INTO v_value FROM public.prescription_items
  WHERE id='63000000-0000-0000-0000-000000000001';
  IF v_value IS DISTINCT FROM '500 mg' THEN
    RAISE EXCEPTION 'legacy dosage was not normalized into dose';
  END IF;

  INSERT INTO public.prescription_items (
    id,prescription_id,medication_name,dose,dosage,frequency,duration,
    quantity,dosage_form,route
  ) VALUES (
    '63000000-0000-0000-0000-000000000002',
    '63000000-0000-0000-0000-000000000101',
    'Synthetic medicine','5 mL',NULL,'three times daily','3 days',
    9,'oral solution','oral'
  );
  SELECT dosage INTO v_value FROM public.prescription_items
  WHERE id='63000000-0000-0000-0000-000000000002';
  IF v_value IS DISTINCT FROM '5 mL' THEN
    RAISE EXCEPTION 'dose was not normalized into legacy dosage';
  END IF;

  -- Conflicting non-empty current/legacy dose fields must fail closed.
  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items (
      id,prescription_id,medication_name,dose,dosage,frequency,duration,
      quantity,dosage_form,route
    ) VALUES (
      '63000000-0000-0000-0000-000000000003',
      '63000000-0000-0000-0000-000000000101',
      'Synthetic medicine','500 mg','250 mg','twice daily','5 days',
      10,'tablet','oral'
    );
  EXCEPTION WHEN check_violation THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'conflicting dose and legacy dosage values were accepted';
  END IF;
  IF EXISTS (SELECT 1 FROM public.prescription_items
             WHERE id='63000000-0000-0000-0000-000000000003') THEN
    RAISE EXCEPTION 'conflicting dose insert left a persisted row';
  END IF;

  -- The same invariant applies when an existing prescription item is edited.
  v_rejected := false;
  BEGIN
    UPDATE public.prescription_items SET dosage='250 mg'
    WHERE id='63000000-0000-0000-0000-000000000001';
  EXCEPTION WHEN check_violation THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'conflicting dose update was accepted';
  END IF;
  SELECT dosage INTO v_value FROM public.prescription_items
  WHERE id='63000000-0000-0000-0000-000000000001';
  IF v_value IS DISTINCT FROM '500 mg' THEN
    RAISE EXCEPTION 'rejected dose update changed the persisted legacy value';
  END IF;

  -- Every required clinical field fails closed when missing.
  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000011','63000000-0000-0000-0000-000000000101','','500 mg','500 mg','daily','5 days',5,'tablet','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'missing medication name was accepted'; END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000012','63000000-0000-0000-0000-000000000101','Synthetic medicine','','','daily','5 days',5,'tablet','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'missing dose was accepted'; END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000013','63000000-0000-0000-0000-000000000101','Synthetic medicine','500 mg','500 mg','','5 days',5,'tablet','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'missing frequency was accepted'; END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000014','63000000-0000-0000-0000-000000000101','Synthetic medicine','500 mg','500 mg','daily','',5,'tablet','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'missing duration was accepted'; END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000015','63000000-0000-0000-0000-000000000101','Synthetic medicine','500 mg','500 mg','daily','5 days',5,'','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'missing dosage form was accepted'; END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000016','63000000-0000-0000-0000-000000000101','Synthetic medicine','500 mg','500 mg','daily','5 days',5,'tablet','');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'missing route was accepted'; END IF;

  -- Quantities must be positive whole values within the RPC integer range.
  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000021','63000000-0000-0000-0000-000000000101','Synthetic medicine','500 mg','500 mg','daily','5 days',NULL,'tablet','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'NULL quantity was accepted'; END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000022','63000000-0000-0000-0000-000000000101','Synthetic medicine','500 mg','500 mg','daily','5 days',0,'tablet','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'zero quantity was accepted'; END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000023','63000000-0000-0000-0000-000000000101','Synthetic medicine','500 mg','500 mg','daily','5 days',1.5,'tablet','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'fractional quantity was accepted'; END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.prescription_items(id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,dosage_form,route)
    VALUES('63000000-0000-0000-0000-000000000024','63000000-0000-0000-0000-000000000101','Synthetic medicine','500 mg','500 mg','daily','5 days',2147483648,'tablet','oral');
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'out-of-range quantity was accepted'; END IF;

  -- Patient-facing instructions are part of the persisted prescription payload.
  -- They must not be rewritten in the same UPDATE that archives the active item.
  UPDATE public.prescription_items
  SET instructions='Take with food'
  WHERE id='63000000-0000-0000-0000-000000000001';

  v_rejected := false;
  BEGIN
    UPDATE public.prescription_items
    SET deleted_at=now(), instructions='Stop taking this medicine'
    WHERE id='63000000-0000-0000-0000-000000000001';
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'patient-facing instructions were mutable during soft deletion';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_items
    WHERE id='63000000-0000-0000-0000-000000000001'
      AND deleted_at IS NULL AND instructions='Take with food'
  ) THEN
    RAISE EXCEPTION 'rejected instructions mutation changed the active prescription payload';
  END IF;

  -- An active row may be archived without changing its clinical payload,
  -- but the same UPDATE must not mutate prescription details while deleting it.
  v_rejected := false;
  BEGIN
    UPDATE public.prescription_items
    SET deleted_at=now(), dose='', dosage=''
    WHERE id='63000000-0000-0000-0000-000000000001';
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'active prescription clinical fields were mutable during soft deletion';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_items
    WHERE id='63000000-0000-0000-0000-000000000001'
      AND deleted_at IS NULL
      AND dose='500 mg' AND dosage='500 mg'
      AND frequency='twice daily' AND duration='5 days'
      AND quantity=10 AND dosage_form='tablet' AND route='oral'
  ) THEN
    RAISE EXCEPTION 'rejected soft-delete mutation changed the active prescription payload';
  END IF;

  -- Legacy soft-deleted rows remain readable even when historical clinical
  -- fields are incomplete; the guard must not retroactively validate them.
  INSERT INTO public.prescription_items(id,prescription_id,medication_name,quantity,deleted_at)
  VALUES('63000000-0000-0000-0000-000000000031','63000000-0000-0000-0000-000000000101',NULL,NULL,now());

  -- Historical soft-deleted prescription payloads are immutable too.
  v_rejected := false;
  BEGIN
    UPDATE public.prescription_items
       SET medication_name='Mutated archived medicine'
     WHERE id='63000000-0000-0000-0000-000000000031';
  EXCEPTION WHEN check_violation THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'historical soft-deleted clinical payload was mutable';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_items
     WHERE id='63000000-0000-0000-0000-000000000031'
       AND medication_name IS NULL
       AND instructions IS NULL
       AND deleted_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'rejected historical payload mutation changed the archived row';
  END IF;

  -- Restoring a deleted row must not be used to rewrite its historical clinical payload.
  INSERT INTO public.prescription_items(
    id,prescription_id,medication_name,dose,dosage,frequency,duration,quantity,
    dosage_form,route,instructions,deleted_at
  ) VALUES (
    '63000000-0000-0000-0000-000000000032',
    '63000000-0000-0000-0000-000000000101',
    'Archived complete medicine','500 mg','1 tablet','twice daily','5 days',10,
    'tablet','oral','Take with food',now()
  );
  v_rejected := false;
  BEGIN
    UPDATE public.prescription_items
       SET deleted_at=NULL, medication_name='Mutated during restore'
     WHERE id='63000000-0000-0000-0000-000000000032';
  EXCEPTION WHEN check_violation THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'restoring a soft-deleted row allowed clinical payload mutation';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_items
     WHERE id='63000000-0000-0000-0000-000000000032'
       AND deleted_at IS NOT NULL
       AND medication_name='Archived complete medicine'
  ) THEN
    RAISE EXCEPTION 'rejected restore mutation changed the historical prescription payload';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE public.prescription_items SET route='' WHERE id='63000000-0000-0000-0000-000000000001';
  EXCEPTION WHEN check_violation THEN v_rejected := true; END;
  IF NOT v_rejected THEN RAISE EXCEPTION 'clinical-field update to blank route was accepted'; END IF;

  -- Soft deletion without clinical-field mutation remains allowed.
  UPDATE public.prescription_items SET deleted_at=now()
  WHERE id='63000000-0000-0000-0000-000000000001';
  IF NOT EXISTS (
    SELECT 1 FROM public.prescription_items
    WHERE id='63000000-0000-0000-0000-000000000001'
      AND deleted_at IS NOT NULL AND dose='500 mg' AND dosage='500 mg'
  ) THEN
    RAISE EXCEPTION 'soft deletion without clinical mutation was not preserved';
  END IF;


  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger
    WHERE tgrelid='public.prescription_items'::regclass
      AND tgname='trg_prescription_item_completeness_guard'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION 'Phase 63 trigger is not attached to public.prescription_items';
  END IF;

  IF has_function_privilege('authenticated','private.validate_prescription_item_completeness()','EXECUTE') THEN
    RAISE EXCEPTION 'authenticated role can directly execute the private trigger function';
  END IF;
END;
$phase63_assertions$;

ROLLBACK;
