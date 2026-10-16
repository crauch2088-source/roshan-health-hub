create or replace function private.app_has_patient_branch(_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(private.is_super_admin(), false)
    or exists (
      select 1 from public.patients p
      where p.id = _patient_id
        and p.branch_id = (select u.branch_id from public.users u where u.auth_user_id = auth.uid() and coalesce(u.active,true)=true limit 1)
    )
$$;

create or replace function private.app_has_invoice_branch(_invoice_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(private.is_super_admin(), false)
    or exists (
      select 1 from public.invoices i
      where i.id = _invoice_id
        and i.branch_id = (select u.branch_id from public.users u where u.auth_user_id = auth.uid() and coalesce(u.active,true)=true limit 1)
    )
$$;

create or replace function private.app_has_claim_branch(_claim_id uuid)
returns boolean
language sql
stable
security definer
set search_path to ''
as $$
  select coalesce(private.is_super_admin(), false)
    or exists (
      select 1
      from public.insurance_claims c
      join public.invoices i on i.id = c.invoice_id
      where c.id = _claim_id
        and i.branch_id = (select u.branch_id from public.users u where u.auth_user_id = auth.uid() and coalesce(u.active,true)=true limit 1)
    )
$$;

alter policy patient_insurance_sel on public.patient_insurance
  using ((app_has_perm('insurance.read'::text)) and (select private.app_has_patient_branch(patient_id)));
alter policy patient_insurance_ins on public.patient_insurance
  with check ((app_has_perm('insurance.create'::text)) and (select private.app_has_patient_branch(patient_id)));
alter policy patient_insurance_upd on public.patient_insurance
  using ((app_has_perm('insurance.update'::text)) and (select private.app_has_patient_branch(patient_id)))
  with check ((app_has_perm('insurance.update'::text)) and (select private.app_has_patient_branch(patient_id)));

alter policy insurance_claims_sel on public.insurance_claims
  using ((app_has_perm('insurance.read'::text)) and (select private.app_has_invoice_branch(invoice_id)));
alter policy insurance_claims_ins on public.insurance_claims
  with check ((app_has_perm('insurance.create'::text)) and (select private.app_has_invoice_branch(invoice_id)));
alter policy insurance_claims_upd on public.insurance_claims
  using ((app_has_perm('insurance.update'::text)) and (select private.app_has_invoice_branch(invoice_id)))
  with check ((app_has_perm('insurance.update'::text)) and (select private.app_has_invoice_branch(invoice_id)));

alter policy insurance_claim_items_sel on public.insurance_claim_items
  using ((app_has_perm('insurance.read'::text)) and (select private.app_has_claim_branch(claim_id)));
alter policy insurance_claim_items_ins on public.insurance_claim_items
  with check ((app_has_perm('insurance.create'::text)) and (select private.app_has_claim_branch(claim_id)));

alter policy insurance_claim_payments_sel on public.insurance_claim_payments
  using ((app_has_perm('insurance.read'::text)) and (select private.app_has_claim_branch(claim_id)));
alter policy insurance_claim_payments_ins on public.insurance_claim_payments
  with check ((app_has_perm('insurance.create'::text)) and (select private.app_has_claim_branch(claim_id)));

create or replace function public.create_insurance_claim(_patient_insurance_id uuid, _invoice_id uuid, _items jsonb, _notes text default null)
returns uuid
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  claim_id uuid;
  uid uuid;
  total numeric := 0;
  item jsonb;
  pi_patient_id uuid;
  invoice_patient_id uuid;
  invoice_branch uuid;
  user_branch uuid;
begin
  if not public.app_has_perm('insurance.create') then raise exception 'not authorised to create insurance claims'; end if;
  if _items is null or jsonb_array_length(_items)=0 then raise exception 'a claim needs at least one item'; end if;
  uid := public.current_app_user_id();
  select patient_id into pi_patient_id from public.patient_insurance where id=_patient_insurance_id and deleted_at is null;
  if pi_patient_id is null then raise exception 'patient insurance not found'; end if;
  select patient_id, branch_id into invoice_patient_id, invoice_branch from public.invoices where id=_invoice_id and deleted_at is null;
  if invoice_patient_id is null then raise exception 'invoice not found'; end if;
  if pi_patient_id <> invoice_patient_id then raise exception 'patient insurance does not belong to invoice patient'; end if;
  select branch_id into user_branch from public.users where id=uid;
  if not public.is_super_admin() and (user_branch is null or invoice_branch is distinct from user_branch) then raise exception 'cross-branch insurance claim access denied'; end if;
  select coalesce(sum(coalesce((i->>'gross_amount')::numeric,0)),0) into total from jsonb_array_elements(_items) i;
  if total < 0 then raise exception 'invalid claim amount'; end if;
  insert into public.insurance_claims(patient_insurance_id,invoice_id,status,submitted_amount,notes,created_by)
  values(_patient_insurance_id,_invoice_id,'draft',total,_notes,uid) returning id into claim_id;
  for item in select * from jsonb_array_elements(_items) loop
    if coalesce((item->>'gross_amount')::numeric,0) < 0 or coalesce((item->>'covered_amount')::numeric,0) < 0 or coalesce((item->>'patient_amount')::numeric,0) < 0 then raise exception 'invalid claim item amount'; end if;
    insert into public.insurance_claim_items(claim_id,service_type,reference_id,description,gross_amount,covered_amount,patient_amount,coverage_rule_id)
    values(claim_id,item->>'service_type',nullif(item->>'reference_id','')::uuid,coalesce(item->>'description',''),coalesce((item->>'gross_amount')::numeric,0),coalesce((item->>'covered_amount')::numeric,0),coalesce((item->>'patient_amount')::numeric,0),nullif(item->>'coverage_rule_id','')::uuid);
  end loop;
  return claim_id;
end;
$$;

create or replace function public.update_insurance_claim_status(_claim_id uuid,_new_status text,_approved_amount numeric default null,_notes text default null)
returns void language plpgsql security definer set search_path to 'public' as $$
declare claim public.insurance_claims; uid uuid;
begin
  if not public.app_has_perm('insurance.update') then raise exception 'not authorised to update insurance claims'; end if;
  select * into claim from public.insurance_claims where id=_claim_id and deleted_at is null for update;
  if claim.id is null then raise exception 'claim not found'; end if;
  if not public.is_super_admin() and not private.app_has_claim_branch(_claim_id) then raise exception 'cross-branch insurance claim access denied'; end if;
  if (claim.status,_new_status) not in (('draft','submitted'),('submitted','under_review'),('under_review','approved'),('under_review','partially_approved'),('under_review','rejected'),('approved','paid'),('partially_approved','paid')) then raise exception 'invalid claim status transition: % -> %',claim.status,_new_status; end if;
  if _new_status in ('approved','partially_approved') and _approved_amount is null then raise exception 'approved_amount is required when approving a claim'; end if;
  if _new_status in ('approved','partially_approved') and (_approved_amount < 0 or _approved_amount > claim.submitted_amount) then raise exception 'approved amount must be between zero and submitted amount'; end if;
  uid:=public.current_app_user_id();
  update public.insurance_claims set status=_new_status,approved_amount=case when _new_status in ('approved','partially_approved') then _approved_amount else approved_amount end,submitted_at=case when _new_status='submitted' then now() else submitted_at end,decided_at=case when _new_status in ('approved','partially_approved','rejected') then now() else decided_at end,notes=coalesce(_notes,notes),updated_by=uid,updated_at=now() where id=_claim_id;
end; $$;

create or replace function public.post_insurance_claim_payment(_claim_id uuid,_amount numeric,_method text default 'bank',_reference text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare claim public.insurance_claims; pay_id uuid; uid uuid; outstanding numeric; new_paid numeric;
begin
  if not public.app_has_perm('insurance.update') then raise exception 'not authorised to record insurance payments'; end if;
  if _amount is null or _amount <= 0 then raise exception 'amount must be greater than zero'; end if;
  select * into claim from public.insurance_claims where id=_claim_id and deleted_at is null for update;
  if claim.id is null then raise exception 'claim not found'; end if;
  if not public.is_super_admin() and not private.app_has_claim_branch(_claim_id) then raise exception 'cross-branch insurance claim access denied'; end if;
  if claim.status not in ('approved','partially_approved','paid') then raise exception 'claim must be approved before recording a payment (current status: %)',claim.status; end if;
  outstanding:=greatest(coalesce(claim.approved_amount,0)-coalesce(claim.paid_amount,0),0);
  if _amount > outstanding then raise exception 'payment (%) exceeds outstanding approved balance (%)',_amount,outstanding; end if;
  uid:=public.current_app_user_id();
  insert into public.insurance_claim_payments(claim_id,amount,payment_method,reference,created_by) values(_claim_id,_amount,coalesce(_method,'bank'),_reference,uid) returning id into pay_id;
  select coalesce(sum(amount),0) into new_paid from public.insurance_claim_payments where claim_id=_claim_id and deleted_at is null;
  update public.insurance_claims set paid_amount=new_paid,status=case when new_paid>=coalesce(approved_amount,0) and approved_amount is not null then 'paid' else status end,paid_at=case when new_paid>=coalesce(approved_amount,0) and approved_amount is not null then now() else paid_at end,updated_by=uid,updated_at=now() where id=_claim_id;
  perform public.fn_ledger_post('income',abs(_amount),coalesce(_method,'bank'),'insurance_settlement','Insurance claim payment — '||claim.claim_number,'insurance_claim_payment',pay_id,now(),null);
  return pay_id;
end; $$;
