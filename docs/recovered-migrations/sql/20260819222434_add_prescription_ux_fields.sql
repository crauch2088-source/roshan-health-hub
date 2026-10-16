alter table public.prescription_items
  add column if not exists dosage_form text;

alter table public.prescription_items
  add column if not exists route text;

alter table public.prescription_items
  add column if not exists instructions text;

create index if not exists idx_prescription_items_medicine_id
  on public.prescription_items (medicine_id);
