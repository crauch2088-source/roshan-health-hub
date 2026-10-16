-- ROSHAN workflow performance/security cleanup
-- Keep only the hardened system_settings SELECT policy; the duplicate policy was
-- reported by Supabase's performance advisor.
drop policy if exists system_settings_select on public.system_settings;

-- High-value indexes for the actual clinical workflows.
create index if not exists clinical_notes_visit_created_idx
  on public.clinical_notes (visit_id, created_at desc)
  where deleted_at is null;

create index if not exists diagnoses_visit_created_idx
  on public.diagnoses (visit_id, created_at desc)
  where deleted_at is null;

create index if not exists lab_tests_active_category_name_idx
  on public.lab_tests (category, name)
  where deleted_at is null and active = true;

create index if not exists lab_tests_name_trgm_idx
  on public.lab_tests using gin (name gin_trgm_ops)
  where deleted_at is null;

create index if not exists lab_tests_name_ar_trgm_idx
  on public.lab_tests using gin (name_ar gin_trgm_ops)
  where deleted_at is null;

create index if not exists lab_orders_status_created_idx
  on public.lab_orders (status, created_at desc)
  where deleted_at is null;

create index if not exists lab_order_items_order_created_idx
  on public.lab_order_items (order_id, created_at)
  where deleted_at is null;

create index if not exists lab_results_order_item_parameter_idx
  on public.lab_results (order_item_id, parameter_id);

create index if not exists medicines_search_trgm_idx
  on public.medicines using gin (name gin_trgm_ops)
  where deleted_at is null;

create index if not exists medicines_generic_trgm_idx
  on public.medicines using gin (generic_name gin_trgm_ops)
  where deleted_at is null;

create index if not exists medicines_brand_trgm_idx
  on public.medicines using gin (brand_name gin_trgm_ops)
  where deleted_at is null;

create index if not exists prescriptions_visit_created_idx
  on public.prescriptions (visit_id, created_at desc)
  where deleted_at is null;

create index if not exists visits_doctor_date_status_idx
  on public.visits (doctor_id, visit_date desc, status)
  where deleted_at is null;

create index if not exists visits_patient_date_idx
  on public.visits (patient_id, visit_date desc)
  where deleted_at is null;
