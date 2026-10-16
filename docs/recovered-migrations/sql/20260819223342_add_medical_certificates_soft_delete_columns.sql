alter table public.medical_certificates
  add column if not exists deleted_at timestamptz;

alter table public.medical_certificates
  add column if not exists deleted_by uuid;

create index if not exists idx_medical_certificates_deleted_at
  on public.medical_certificates (deleted_at);
