alter table public.medicines add column if not exists batch_number text;
create index if not exists idx_medicines_batch_number on public.medicines(batch_number) where deleted_at is null;
