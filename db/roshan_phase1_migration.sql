-- =====================================================================
-- ROSHAN MEDICAL CENTER — PHASE 1 MIGRATION
-- Project: jewzonxplxhogqrnhosl
--
-- ADDITIVE ONLY. No table is created, renamed or dropped.
-- No existing column is renamed or dropped.
-- Run ONCE in: Supabase Dashboard -> SQL Editor -> New query -> Run.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. AUTH LINKAGE + AUDIT / SOFT-DELETE PATTERN
-- ---------------------------------------------------------------------

alter table public.users add column if not exists auth_user_id uuid;
alter table public.users add column if not exists department_id uuid;
do $$ begin
  alter table public.users add constraint users_auth_user_id_key unique (auth_user_id);
exception when duplicate_table or duplicate_object then null; end $$;
do $$ begin
  alter table public.users add constraint users_auth_user_id_fkey
    foreign key (auth_user_id) references auth.users(id) on delete set null;
exception when duplicate_object then null; end $$;

alter table public.roles add column if not exists code text;
do $$ begin
  alter table public.roles add constraint roles_code_key unique (code);
exception when duplicate_table or duplicate_object then null; end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'users','roles','patients','visits','vitals','clinical_notes','diagnoses',
    'followups','certificates','appointments','queue_tickets','lab_tests',
    'lab_parameters','lab_reference_ranges','lab_orders','lab_order_items',
    'lab_results','medicines','pharmacy_inventory','prescriptions',
    'prescription_items','suppliers','procedures_catalog','procedure_orders',
    'procedure_results','invoices','invoice_items','payments','expenses',
    'corporate_accounts','attachments','system_settings','branches','departments'
  ]
  loop
    execute format('alter table public.%I add column if not exists created_by uuid', t);
    execute format('alter table public.%I add column if not exists updated_by uuid', t);
    execute format('alter table public.%I add column if not exists deleted_at timestamptz', t);
    execute format('alter table public.%I add column if not exists deleted_by uuid', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------
-- 2. MISSING WORKFLOW COLUMNS
-- ---------------------------------------------------------------------

alter table public.branches      add column if not exists name text;
alter table public.branches      add column if not exists code text;
alter table public.branches      add column if not exists is_active boolean default true;

alter table public.departments   add column if not exists name_ar text;
alter table public.departments   add column if not exists code text;
alter table public.departments   add column if not exists is_active boolean default true;

alter table public.patients      add column if not exists email text;
alter table public.patients      add column if not exists national_id text;
alter table public.patients      add column if not exists emergency_contact text;
alter table public.patients      add column if not exists notes text;
alter table public.patients      add column if not exists registered_by uuid;
do $$ begin
  alter table public.patients add constraint patients_mrn_key unique (mrn);
exception when duplicate_table or duplicate_object then null; end $$;

alter table public.visits        add column if not exists visit_number text;
alter table public.visits        add column if not exists consultation_fee numeric default 0;
alter table public.visits        add column if not exists notes text;
alter table public.visits        add column if not exists completed_at timestamptz;
alter table public.visits        add column if not exists is_locked boolean default false;
alter table public.visits        add column if not exists updated_at timestamptz default now();

alter table public.vitals        add column if not exists patient_id uuid;
alter table public.vitals        add column if not exists bp_systolic integer;
alter table public.vitals        add column if not exists bp_diastolic integer;
alter table public.vitals        add column if not exists lmp date;
alter table public.vitals        add column if not exists edd date;
alter table public.vitals        add column if not exists gestational_age_days integer;
alter table public.vitals        add column if not exists recorded_by uuid;

alter table public.clinical_notes add column if not exists hpi text;
alter table public.clinical_notes add column if not exists doctor_id uuid;
alter table public.clinical_notes add column if not exists lmp date;
alter table public.clinical_notes add column if not exists edd date;
alter table public.clinical_notes add column if not exists gestational_age_days integer;

alter table public.diagnoses     add column if not exists is_primary boolean default false;
alter table public.diagnoses     add column if not exists doctor_id uuid;
alter table public.diagnoses     add column if not exists notes text;

alter table public.appointments  add column if not exists appointment_time time;
alter table public.appointments  add column if not exists department_id uuid;
alter table public.appointments  add column if not exists branch_id uuid;
alter table public.appointments  add column if not exists visit_id uuid;
alter table public.appointments  add column if not exists reason text;

alter table public.queue_tickets add column if not exists patient_id uuid;
alter table public.queue_tickets add column if not exists department_id uuid;
alter table public.queue_tickets add column if not exists called_at timestamptz;
alter table public.queue_tickets add column if not exists completed_at timestamptz;

alter table public.lab_tests     add column if not exists name_ar text;
alter table public.lab_tests     add column if not exists description text;
alter table public.lab_tests     add column if not exists is_active boolean default true;

alter table public.lab_parameters add column if not exists is_active boolean default true;
alter table public.lab_parameters add column if not exists reference_text text;

alter table public.lab_reference_ranges add column if not exists min_value numeric;
alter table public.lab_reference_ranges add column if not exists max_value numeric;
alter table public.lab_reference_ranges add column if not exists age_min integer;
alter table public.lab_reference_ranges add column if not exists age_max integer;
alter table public.lab_reference_ranges add column if not exists text_value text;
alter table public.lab_reference_ranges add column if not exists unit text;

alter table public.lab_orders    add column if not exists created_at timestamptz default now();
alter table public.lab_orders    add column if not exists notes text;
alter table public.lab_orders    add column if not exists branch_id uuid;
alter table public.lab_orders    add column if not exists sample_collected_at timestamptz;
alter table public.lab_orders    add column if not exists collected_by uuid;

alter table public.lab_order_items add column if not exists price numeric default 0;
alter table public.lab_order_items add column if not exists completed_at timestamptz;

alter table public.lab_results   add column if not exists created_at timestamptz default now();
alter table public.lab_results   add column if not exists is_abnormal boolean;

alter table public.medicines     add column if not exists unit text;
alter table public.medicines     add column if not exists is_active boolean default true;

alter table public.pharmacy_inventory add column if not exists batch_number text;
alter table public.pharmacy_inventory add column if not exists reorder_level integer default 10;
alter table public.pharmacy_inventory add column if not exists supplier_id uuid;
alter table public.pharmacy_inventory add column if not exists branch_id uuid;
alter table public.pharmacy_inventory add column if not exists updated_at timestamptz default now();

alter table public.prescriptions add column if not exists doctor_id uuid;
alter table public.prescriptions add column if not exists status text default 'pending';
alter table public.prescriptions add column if not exists is_external boolean default false;
alter table public.prescriptions add column if not exists notes text;
alter table public.prescriptions add column if not exists dispensed_at timestamptz;
alter table public.prescriptions add column if not exists dispensed_by uuid;

alter table public.prescription_items add column if not exists dosage text;
alter table public.prescription_items add column if not exists is_dispensed boolean default false;
alter table public.prescription_items add column if not exists dispensed_quantity integer default 0;
alter table public.prescription_items add column if not exists unit_price numeric default 0;
alter table public.prescription_items add column if not exists created_at timestamptz default now();

alter table public.procedures_catalog add column if not exists name_ar text;
alter table public.procedures_catalog add column if not exists department_id uuid;
alter table public.procedures_catalog add column if not exists is_active boolean default true;

alter table public.procedure_orders add column if not exists price numeric default 0;
alter table public.procedure_orders add column if not exists performed_by uuid;
alter table public.procedure_orders add column if not exists performed_at timestamptz;
alter table public.procedure_orders add column if not exists notes text;

alter table public.procedure_results add column if not exists verified_by uuid;

alter table public.invoices      add column if not exists status text default 'open';
alter table public.invoices      add column if not exists subtotal numeric default 0;
alter table public.invoices      add column if not exists net_amount numeric default 0;
alter table public.invoices      add column if not exists discount_type text;
alter table public.invoices      add column if not exists corporate_account_id uuid;
alter table public.invoices      add column if not exists branch_id uuid;
alter table public.invoices      add column if not exists updated_at timestamptz default now();
do $$ begin
  alter table public.invoices add constraint invoices_invoice_number_key unique (invoice_number);
exception when duplicate_table or duplicate_object then null; end $$;

alter table public.invoice_items add column if not exists item_id uuid;
alter table public.invoice_items add column if not exists discount numeric default 0;
alter table public.invoice_items add column if not exists created_at timestamptz default now();

alter table public.payments      add column if not exists created_at timestamptz default now();
alter table public.payments      add column if not exists payment_date date default current_date;
alter table public.payments      add column if not exists reference text;
alter table public.payments      add column if not exists received_by uuid;
alter table public.payments      add column if not exists branch_id uuid;
alter table public.payments      add column if not exists notes text;
alter table public.payments      add column if not exists idempotency_key text;
do $$ begin
  alter table public.payments add constraint payments_idempotency_key_key unique (idempotency_key);
exception when duplicate_table or duplicate_object then null; end $$;

alter table public.expenses      add column if not exists notes text;
alter table public.expenses      add column if not exists payment_method text default 'cash';
alter table public.expenses      add column if not exists paid_to text;
alter table public.expenses      add column if not exists branch_id uuid;

alter table public.corporate_accounts add column if not exists type text;
alter table public.corporate_accounts add column if not exists agreement_notes text;
alter table public.corporate_accounts add column if not exists email text;
alter table public.corporate_accounts add column if not exists address text;
alter table public.corporate_accounts add column if not exists is_active boolean default true;

alter table public.attachments   add column if not exists file_type text;
alter table public.attachments   add column if not exists file_size bigint;
alter table public.attachments   add column if not exists description text;
alter table public.attachments   add column if not exists storage_path text;
alter table public.attachments   add column if not exists uploaded_by uuid;
alter table public.attachments   add column if not exists created_at timestamptz default now();

alter table public.certificates  add column if not exists certificate_number text;
alter table public.certificates  add column if not exists issued_by uuid;
alter table public.certificates  add column if not exists issue_date date default current_date;
alter table public.certificates  add column if not exists valid_from date;
alter table public.certificates  add column if not exists valid_to date;
alter table public.certificates  add column if not exists notes text;

alter table public.followups     add column if not exists reason text;
alter table public.followups     add column if not exists completed_at timestamptz;

alter table public.system_settings add column if not exists description text;
alter table public.system_settings add column if not exists created_at timestamptz default now();
do $$ begin
  alter table public.system_settings
    add constraint system_settings_setting_key_key unique (setting_key);
exception when duplicate_table or duplicate_object then null; end $$;

alter table public.permissions   add column if not exists module text;
alter table public.permissions   add column if not exists action text;
do $$ begin
  alter table public.permissions add constraint permissions_code_key unique (code);
exception when duplicate_table or duplicate_object then null; end $$;
do $$ begin
  alter table public.role_permissions
    add constraint role_permissions_role_permission_key unique (role_id, permission_id);
exception when duplicate_table or duplicate_object then null; end $$;
do $$ begin
  alter table public.queue_tickets
    add constraint queue_tickets_number_day_key unique (visit_date, queue_number);
exception when duplicate_table or duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 3. SECURITY DEFINER HELPERS (no recursion inside policies)
-- ---------------------------------------------------------------------

create or replace function public.current_app_user_id()
returns uuid language sql stable security definer set search_path = public as $$
  select u.id from public.users u where u.auth_user_id = auth.uid() limit 1
$$;

create or replace function public.current_role_code()
returns text language sql stable security definer set search_path = public as $$
  select r.code from public.users u
  join public.roles r on r.id = u.role_id
  where u.auth_user_id = auth.uid() limit 1
$$;

create or replace function public.is_super_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(public.current_role_code() = 'super_admin', false)
$$;

create or replace function public.app_has_perm(_code text)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_super_admin() or exists (
    select 1
    from public.users u
    join public.role_permissions rp on rp.role_id = u.role_id
    join public.permissions p on p.id = rp.permission_id
    where u.auth_user_id = auth.uid()
      and coalesce(u.active, true)
      and p.code = _code
  )
$$;

grant execute on function public.app_has_perm(text) to authenticated;
grant execute on function public.current_app_user_id() to authenticated;
grant execute on function public.current_role_code() to authenticated;
grant execute on function public.is_super_admin() to authenticated;

-- ---------------------------------------------------------------------
-- 4. AUDIT TRIGGER + STOCK GUARD
-- ---------------------------------------------------------------------

create or replace function public.audit_row_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare uid uuid;
begin
  select id into uid from public.users where auth_user_id = auth.uid() limit 1;
  insert into public.audit_logs (user_id, action, table_name, record_id, old_data, new_data)
  values (
    uid, tg_op, tg_table_name,
    (case when tg_op = 'DELETE' then to_jsonb(old)->>'id' else to_jsonb(new)->>'id' end)::uuid,
    case when tg_op = 'INSERT' then null else to_jsonb(old) end,
    case when tg_op = 'DELETE' then null else to_jsonb(new) end
  );
  return coalesce(new, old);
end $$;

do $$
declare t text;
begin
  foreach t in array array[
    'patients','visits','vitals','clinical_notes','diagnoses','prescriptions',
    'prescription_items','lab_orders','lab_order_items','lab_results',
    'pharmacy_inventory','invoices','invoice_items','payments','expenses',
    'users','role_permissions','system_settings','certificates','procedure_orders'
  ]
  loop
    execute format('drop trigger if exists trg_audit_%1$s on public.%1$I', t);
    execute format(
      'create trigger trg_audit_%1$s after insert or update or delete on public.%1$I
       for each row execute function public.audit_row_change()', t);
  end loop;
end $$;

do $$ begin
  alter table public.pharmacy_inventory
    add constraint pharmacy_inventory_quantity_nonneg check (quantity >= 0);
exception when duplicate_table or duplicate_object then null; end $$;

-- ---------------------------------------------------------------------
-- 5. SEED ROLES / PERMISSIONS / CATALOGUES (configuration, not demo data)
-- ---------------------------------------------------------------------

insert into public.roles (code, name, description) values
  ('super_admin','Super Admin','Full system access'),
  ('admin','Admin','Administration and reports'),
  ('reception','Reception','Front desk, patients, visits, billing'),
  ('gp','GP','General practitioner'),
  ('dentist','Dentist','Dental workflows'),
  ('specialist','Specialist','Specialist clinics'),
  ('lab_doctor','Lab Doctor','Laboratory supervision'),
  ('lab_assistant','Lab Assistant','Sample handling and result entry'),
  ('pharmacist','Pharmacist','Pharmacy and dispensing')
on conflict (code) do nothing;

insert into public.permissions (code, name, module, action)
select m || '.' || a, initcap(replace(m,'_',' ')) || ' ' || a, m, a
from unnest(array[
  'dashboard','patients','visits','queue','appointments','emr','procedures',
  'lab','lab_admin','pharmacy','billing','payments','accounting','partners',
  'reports','users','settings','audit','attachments','certificates','followups'
]) m
cross join unnest(array['read','create','update','delete']) a
on conflict (code) do nothing;

do $$
declare
  spec jsonb := '{
    "admin":        ["dashboard","patients","visits","queue","appointments","emr","procedures","lab","lab_admin","pharmacy","billing","payments","accounting","partners","reports","users","settings","audit","attachments","certificates","followups"],
    "reception":    ["dashboard","patients","visits","queue","appointments","billing","payments","attachments","followups"],
    "gp":           ["dashboard","patients","visits","queue","emr","procedures","lab","certificates","attachments","followups"],
    "specialist":   ["dashboard","patients","visits","queue","emr","procedures","lab","certificates","attachments","followups"],
    "dentist":      ["dashboard","patients","visits","queue","emr","procedures","certificates","attachments","followups"],
    "lab_doctor":   ["dashboard","patients","lab","lab_admin"],
    "lab_assistant":["dashboard","patients","lab"],
    "pharmacist":   ["dashboard","patients","pharmacy","billing"]
  }'::jsonb;
  role_code text; mod text;
begin
  for role_code in select jsonb_object_keys(spec) loop
    for mod in select jsonb_array_elements_text(spec -> role_code) loop
      insert into public.role_permissions (role_id, permission_id)
      select r.id, p.id
      from public.roles r, public.permissions p
      where r.code = role_code and p.module = mod
        and (p.action <> 'delete' or role_code = 'admin')
      on conflict (role_id, permission_id) do nothing;
    end loop;
  end loop;
end $$;

insert into public.departments (name, name_ar, code) values
  ('General Practice','الطب العام','GP'),
  ('Dental','الأسنان','DEN'),
  ('Specialist Clinic','العيادات التخصصية','SPC'),
  ('Laboratory','المختبر','LAB'),
  ('Pharmacy','الصيدلية','PHM')
on conflict do nothing;

insert into public.system_settings (setting_key, setting_value, description) values
  ('center_name','Roshan Medical Center','Center name'),
  ('center_name_ar','مركز روشان الطبي','Center name (Arabic)'),
  ('currency','SDG','Currency code'),
  ('phone','','Contact phone'),
  ('address','','Address'),
  ('invoice_footer','Thank you for choosing Roshan Medical Center','Invoice footer'),
  ('receipt_footer','This receipt is computer generated','Receipt footer')
on conflict (setting_key) do nothing;

insert into public.lab_tests (code, name, name_ar, category, sample_type, price) values
  ('CBC','Complete Blood Count','تحليل الدم الكامل','Haematology','Blood',0),
  ('RBS','Blood Glucose','سكر الدم','Chemistry','Blood',0),
  ('URINE','Urinalysis','تحليل البول','Microscopy','Urine',0),
  ('MP','Malaria Parasite','طفيل الملاريا','Parasitology','Blood',0),
  ('PT','Pregnancy Test','اختبار الحمل','Serology','Urine',0),
  ('CREAT','Creatinine','الكرياتينين','Chemistry','Blood',0),
  ('UREA','Urea','اليوريا','Chemistry','Blood',0),
  ('ALT','ALT','ناقلة الأمين ALT','Chemistry','Blood',0),
  ('AST','AST','ناقلة الأمين AST','Chemistry','Blood',0)
on conflict do nothing;

insert into public.lab_parameters (test_id, code, name, unit, data_type, display_order)
select t.id, x.code, x.name, x.unit, 'numeric', x.ord
from public.lab_tests t
join (values
  ('HB','Haemoglobin','g/dL',1),
  ('WBC','WBC','10^3/uL',2),
  ('RBC','RBC','10^6/uL',3),
  ('PLT','Platelets','10^3/uL',4),
  ('MCV','MCV','fL',5),
  ('MCH','MCH','pg',6),
  ('MCHC','MCHC','g/dL',7)
) as x(code,name,unit,ord) on true
where t.code = 'CBC'
  and not exists (
    select 1 from public.lab_parameters p where p.test_id = t.id and p.code = x.code);

insert into public.procedures_catalog (name, name_ar, category, price) values
  ('ECG','رسم القلب','Medical',0),
  ('Ultrasound','الموجات فوق الصوتية','Medical',0),
  ('Nebulization','جلسة استنشاق','Medical',0),
  ('Injection','حقنة','Medical',0),
  ('Dressing','تضميد','Medical',0),
  ('Extraction','خلع','Dental',0),
  ('Filling','حشو','Dental',0),
  ('Root Canal Treatment','علاج عصب','Dental',0),
  ('Scaling & Polishing','تنظيف وتلميع','Dental',0),
  ('Crown','تاج','Dental',0),
  ('Bridge','جسر','Dental',0),
  ('Denture','طقم أسنان','Dental',0)
on conflict do nothing;

-- ---------------------------------------------------------------------
-- 6. ROW LEVEL SECURITY — revoke anon, permission-scoped authenticated
-- ---------------------------------------------------------------------

do $$
declare
  map jsonb := '{
    "patients":"patients","visits":"visits","vitals":"emr","clinical_notes":"emr",
    "diagnoses":"emr","followups":"followups","certificates":"certificates",
    "appointments":"appointments","queue_tickets":"queue",
    "lab_tests":"lab_admin","lab_parameters":"lab_admin","lab_reference_ranges":"lab_admin",
    "lab_orders":"lab","lab_order_items":"lab","lab_results":"lab",
    "medicines":"pharmacy","pharmacy_inventory":"pharmacy","suppliers":"pharmacy",
    "prescriptions":"pharmacy","prescription_items":"pharmacy",
    "procedures_catalog":"procedures","procedure_orders":"procedures",
    "procedure_results":"procedures",
    "invoices":"billing","invoice_items":"billing","payments":"payments",
    "expenses":"accounting","corporate_accounts":"partners",
    "attachments":"attachments","audit_logs":"audit","system_settings":"settings",
    "users":"users","roles":"users","permissions":"users","role_permissions":"users",
    "branches":"settings","departments":"settings"
  }'::jsonb;
  tbl text; modu text;
begin
  for tbl in select jsonb_object_keys(map) loop
    modu := map ->> tbl;
    execute format('revoke all on public.%I from anon', tbl);
    execute format('grant select, insert, update, delete on public.%I to authenticated', tbl);
    execute format('grant all on public.%I to service_role', tbl);
    execute format('alter table public.%I enable row level security', tbl);

    execute format('drop policy if exists %I on public.%I', tbl || '_sel', tbl);
    execute format('drop policy if exists %I on public.%I', tbl || '_ins', tbl);
    execute format('drop policy if exists %I on public.%I', tbl || '_upd', tbl);
    execute format('drop policy if exists %I on public.%I', tbl || '_del', tbl);

    execute format(
      'create policy %I on public.%I for select to authenticated using (public.app_has_perm(%L))',
      tbl || '_sel', tbl, modu || '.read');
    execute format(
      'create policy %I on public.%I for insert to authenticated with check (public.app_has_perm(%L))',
      tbl || '_ins', tbl, modu || '.create');
    execute format(
      'create policy %I on public.%I for update to authenticated using (public.app_has_perm(%L)) with check (public.app_has_perm(%L))',
      tbl || '_upd', tbl, modu || '.update', modu || '.update');
    execute format(
      'create policy %I on public.%I for delete to authenticated using (public.is_super_admin())',
      tbl || '_del', tbl);
  end loop;
end $$;

-- Reference data every signed-in user needs so role/menu resolution works.
drop policy if exists roles_sel on public.roles;
create policy roles_sel on public.roles for select to authenticated using (true);
drop policy if exists permissions_sel on public.permissions;
create policy permissions_sel on public.permissions for select to authenticated using (true);
drop policy if exists role_permissions_sel on public.role_permissions;
create policy role_permissions_sel on public.role_permissions for select to authenticated using (true);
drop policy if exists departments_sel on public.departments;
create policy departments_sel on public.departments for select to authenticated using (true);
drop policy if exists branches_sel on public.branches;
create policy branches_sel on public.branches for select to authenticated using (true);
drop policy if exists system_settings_sel on public.system_settings;
create policy system_settings_sel on public.system_settings for select to authenticated using (true);

drop policy if exists users_sel on public.users;
create policy users_sel on public.users for select to authenticated
  using (auth_user_id = auth.uid() or public.app_has_perm('users.read'));

-- Doctors need to read their own prescriptions/catalogue while prescribing.
drop policy if exists prescriptions_sel on public.prescriptions;
create policy prescriptions_sel on public.prescriptions for select to authenticated
  using (public.app_has_perm('pharmacy.read') or public.app_has_perm('emr.read'));
drop policy if exists prescriptions_ins on public.prescriptions;
create policy prescriptions_ins on public.prescriptions for insert to authenticated
  with check (public.app_has_perm('pharmacy.create') or public.app_has_perm('emr.create'));
drop policy if exists prescription_items_sel on public.prescription_items;
create policy prescription_items_sel on public.prescription_items for select to authenticated
  using (public.app_has_perm('pharmacy.read') or public.app_has_perm('emr.read'));
drop policy if exists prescription_items_ins on public.prescription_items;
create policy prescription_items_ins on public.prescription_items for insert to authenticated
  with check (public.app_has_perm('pharmacy.create') or public.app_has_perm('emr.create'));
drop policy if exists medicines_sel on public.medicines;
create policy medicines_sel on public.medicines for select to authenticated
  using (public.app_has_perm('pharmacy.read') or public.app_has_perm('emr.read'));

-- Doctors order laboratory tests; lab staff process them.
drop policy if exists lab_orders_ins on public.lab_orders;
create policy lab_orders_ins on public.lab_orders for insert to authenticated
  with check (public.app_has_perm('lab.create') or public.app_has_perm('emr.create'));
drop policy if exists lab_order_items_ins on public.lab_order_items;
create policy lab_order_items_ins on public.lab_order_items for insert to authenticated
  with check (public.app_has_perm('lab.create') or public.app_has_perm('emr.create'));
drop policy if exists lab_tests_sel on public.lab_tests;
create policy lab_tests_sel on public.lab_tests for select to authenticated
  using (public.app_has_perm('lab_admin.read') or public.app_has_perm('lab.read')
         or public.app_has_perm('emr.read'));
drop policy if exists lab_parameters_sel on public.lab_parameters;
create policy lab_parameters_sel on public.lab_parameters for select to authenticated
  using (public.app_has_perm('lab_admin.read') or public.app_has_perm('lab.read'));
drop policy if exists lab_reference_ranges_sel on public.lab_reference_ranges;
create policy lab_reference_ranges_sel on public.lab_reference_ranges for select to authenticated
  using (public.app_has_perm('lab_admin.read') or public.app_has_perm('lab.read'));
drop policy if exists procedures_catalog_sel on public.procedures_catalog;
create policy procedures_catalog_sel on public.procedures_catalog for select to authenticated
  using (public.app_has_perm('procedures.read') or public.app_has_perm('emr.read')
         or public.app_has_perm('billing.read'));

-- Audit log: append-only, no update/delete policies at all.
drop policy if exists audit_logs_ins on public.audit_logs;
create policy audit_logs_ins on public.audit_logs for insert to authenticated with check (true);
drop policy if exists audit_logs_upd on public.audit_logs;
drop policy if exists audit_logs_del on public.audit_logs;

-- ---------------------------------------------------------------------
-- 7. FIRST-RUN BOOTSTRAP (no-op forever once one user exists)
-- ---------------------------------------------------------------------

create or replace function public.setup_required()
returns boolean language sql security definer set search_path = public as $$
  select not exists (select 1 from public.users)
$$;

create or replace function public.bootstrap_super_admin(_full_name text, _email text, _phone text)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid; role_uuid uuid;
begin
  if auth.uid() is null then
    raise exception 'Must be signed in to bootstrap';
  end if;
  if exists (select 1 from public.users) then
    raise exception 'Setup already completed';
  end if;
  select id into role_uuid from public.roles where code = 'super_admin';
  insert into public.users (auth_user_id, full_name, email, phone, role_id, active)
  values (auth.uid(), _full_name, _email, _phone, role_uuid, true)
  returning id into new_id;
  return new_id;
end $$;

grant execute on function public.setup_required() to anon, authenticated;
grant execute on function public.bootstrap_super_admin(text,text,text) to authenticated;

-- ---------------------------------------------------------------------
-- 8. NUMBERING HELPERS
-- ---------------------------------------------------------------------

create or replace function public.next_invoice_number()
returns text language sql security definer set search_path = public as $$
  select 'INV-' || to_char(now(),'YYYYMM') || '-' ||
    lpad((coalesce(count(*),0) + 1)::text, 5, '0')
  from public.invoices
  where invoice_number like 'INV-' || to_char(now(),'YYYYMM') || '-%'
$$;

create or replace function public.next_queue_number(_date date)
returns text language sql security definer set search_path = public as $$
  select 'Q' || lpad((coalesce(count(*),0) + 1)::text, 3, '0')
  from public.queue_tickets where visit_date = _date
$$;

create or replace function public.next_mrn()
returns text language sql security definer set search_path = public as $$
  select 'RMC' || lpad((coalesce(count(*),0) + 1)::text, 6, '0') from public.patients
$$;

grant execute on function public.next_invoice_number() to authenticated;
grant execute on function public.next_queue_number(date) to authenticated;
grant execute on function public.next_mrn() to authenticated;
