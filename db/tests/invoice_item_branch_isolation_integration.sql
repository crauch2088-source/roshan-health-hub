DO $test$
BEGIN
  IF has_function_privilege('anon','private.app_has_invoice_branch(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'anon must not execute invoice branch helper';
  END IF;
  IF NOT has_function_privilege('authenticated','private.app_has_invoice_branch(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'authenticated must execute invoice branch helper for RLS';
  END IF;
  IF private.app_has_invoice_branch('30000000-0000-0000-0000-000000000002') THEN
    RAISE EXCEPTION 'cross-branch invoice helper returned access';
  END IF;
  IF private.app_has_invoice_branch('ffffffff-ffff-ffff-ffff-ffffffffffff') THEN
    RAISE EXCEPTION 'nonexistent invoice helper returned access';
  END IF;
END
$test$;

SET ROLE authenticated;
DO $test$
DECLARE affected integer;
BEGIN
  IF (SELECT count(*) FROM public.invoice_items) <> 1 THEN
    RAISE EXCEPTION 'invoice_items SELECT leaked or hid a same-branch row';
  END IF;

  UPDATE public.invoice_items SET description='tampered'
    WHERE id='40000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch invoice item UPDATE was allowed'; END IF;

  UPDATE public.invoice_items SET description='updated local'
    WHERE id='40000000-0000-0000-0000-000000000001';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch invoice item UPDATE was denied'; END IF;

  BEGIN
    INSERT INTO public.invoice_items(id,invoice_id,description)
    VALUES ('40000000-0000-0000-0000-000000000003','30000000-0000-0000-0000-000000000002','cross branch');
    RAISE EXCEPTION 'cross-branch invoice item INSERT was allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  INSERT INTO public.invoice_items(id,invoice_id,description)
  VALUES ('40000000-0000-0000-0000-000000000004','30000000-0000-0000-0000-000000000001','same branch');
  
  DELETE FROM public.invoice_items WHERE id='40000000-0000-0000-0000-000000000002';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 0 THEN RAISE EXCEPTION 'cross-branch invoice item DELETE was allowed'; END IF;

  DELETE FROM public.invoice_items WHERE id='40000000-0000-0000-0000-000000000004';
  GET DIAGNOSTICS affected = ROW_COUNT;
  IF affected <> 1 THEN RAISE EXCEPTION 'same-branch invoice item DELETE was denied'; END IF;
END
$test$;
RESET ROLE;

DO $test$
BEGIN
  IF EXISTS (SELECT 1 FROM public.invoice_items WHERE id='40000000-0000-0000-0000-000000000002' AND description <> 'branch B item') THEN
    RAISE EXCEPTION 'branch B invoice item was mutated';
  END IF;
  IF EXISTS (SELECT 1 FROM public.invoice_items WHERE id='40000000-0000-0000-0000-000000000003') THEN
    RAISE EXCEPTION 'cross-branch invoice item INSERT left a row behind';
  END IF;
END
$test$;
