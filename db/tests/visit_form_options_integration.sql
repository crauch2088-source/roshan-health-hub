DO $test$
DECLARE
  options jsonb;
  doctor_count integer;
  department_count integer;
BEGIN
  INSERT INTO public.departments (id, name, name_ar, active, is_active, deleted_at) VALUES
    ('10000000-0000-0000-0000-000000000001', 'General Practice', 'الطب العام', true, true, null),
    ('10000000-0000-0000-0000-000000000002', 'Inactive', 'غير نشط', true, false, null),
    ('10000000-0000-0000-0000-000000000003', 'Deleted', 'محذوف', true, true, now());

  INSERT INTO public.roles (id, code, deleted_at) VALUES
    ('20000000-0000-0000-0000-000000000001', 'doctor', null),
    ('20000000-0000-0000-0000-000000000002', 'pharmacist', null),
    ('20000000-0000-0000-0000-000000000003', 'gp', null);

  INSERT INTO public.users (id, full_name, active, deleted_at, role_id, branch_id, email, phone) VALUES
    ('30000000-0000-0000-0000-000000000001', 'Same Branch Doctor', true, null, '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'private@example.invalid', '000'),
    ('30000000-0000-0000-0000-000000000002', 'Other Branch Doctor', true, null, '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000002', 'private2@example.invalid', '111'),
    ('30000000-0000-0000-0000-000000000003', 'Inactive Doctor', false, null, '20000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'private3@example.invalid', '222'),
    ('30000000-0000-0000-0000-000000000004', 'Pharmacist', true, null, '20000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'private4@example.invalid', '333'),
    ('30000000-0000-0000-0000-000000000005', 'Branchless Doctor', true, null, '20000000-0000-0000-0000-000000000003', null, 'private5@example.invalid', '444');

  SELECT set_config('test.visits_create', 'true', false);
  SELECT set_config('test.super_admin', 'false', false);
  SELECT set_config('test.admin_full', 'false', false);
  SELECT set_config('test.branch_id', '40000000-0000-0000-0000-000000000001', false);

  options := public.get_visit_form_options();
  department_count := jsonb_array_length(options -> 'departments');
  doctor_count := jsonb_array_length(options -> 'doctors');

  IF department_count <> 1 THEN
    RAISE EXCEPTION 'expected only one active department, got %', department_count;
  END IF;
  IF doctor_count <> 1 THEN
    RAISE EXCEPTION 'expected one same-branch active doctor, got %', doctor_count;
  END IF;
  IF options::text LIKE '%Other Branch Doctor%' OR options::text LIKE '%Inactive Doctor%' OR options::text LIKE '%Pharmacist%' OR options::text LIKE '%Branchless Doctor%' THEN
    RAISE EXCEPTION 'cross-branch, inactive, non-clinical, or branchless doctor leaked into receptionist options';
  END IF;
  IF options::text LIKE '%private@example.invalid%' OR options::text LIKE '%phone%' OR options::text LIKE '%email%' THEN
    RAISE EXCEPTION 'staff contact details leaked through the minimal options RPC';
  END IF;

  IF has_function_privilege('anon', 'public.get_visit_form_options()', 'EXECUTE') THEN
    RAISE EXCEPTION 'anonymous execution must be denied';
  END IF;
  IF NOT has_function_privilege('authenticated', 'public.get_visit_form_options()', 'EXECUTE') THEN
    RAISE EXCEPTION 'authenticated execution must be granted';
  END IF;

  SELECT set_config('test.visits_create', 'false', false);
  BEGIN
    PERFORM public.get_visit_form_options();
    RAISE EXCEPTION 'caller without visits.create should be denied';
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;
END;
$test$;
