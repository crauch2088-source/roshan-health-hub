create or replace function public.post_insurance_claim_payment(_claim_id uuid,_amount numeric,_method text default 'bank',_reference text default null)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare claim public.insurance_claims; pay_id uuid; uid uuid; outstanding numeric; new_paid numeric; claim_branch uuid;
begin
  if not public.app_has_perm('insurance.update') then raise exception 'not authorised to record insurance payments'; end if;
  if _amount is null or _amount<=0 then raise exception 'amount must be greater than zero'; end if;
  select c.*, i.branch_id into claim from public.insurance_claims c join public.invoices i on i.id=c.invoice_id where c.id=_claim_id and c.deleted_at is null for update;
  if claim.id is null then raise exception 'claim not found'; end if;
  select i.branch_id into claim_branch from public.invoices i where i.id=claim.invoice_id;
  if not public.is_super_admin() and not private.app_has_claim_branch(_claim_id) then raise exception 'cross-branch insurance claim access denied'; end if;
  if claim.status not in ('approved','partially_approved','paid') then raise exception 'claim must be approved before recording a payment (current status: %)',claim.status; end if;
  outstanding:=greatest(coalesce(claim.approved_amount,0)-coalesce(claim.paid_amount,0),0);
  if _amount>outstanding then raise exception 'payment (%) exceeds outstanding approved balance (%)',_amount,outstanding; end if;
  uid:=public.current_app_user_id();
  insert into public.insurance_claim_payments(claim_id,amount,payment_method,reference,created_by) values(_claim_id,_amount,coalesce(_method,'bank'),_reference,uid) returning id into pay_id;
  select coalesce(sum(amount),0) into new_paid from public.insurance_claim_payments where claim_id=_claim_id and deleted_at is null;
  update public.insurance_claims set paid_amount=new_paid,status=case when new_paid>=coalesce(approved_amount,0) and approved_amount is not null then 'paid' else status end,paid_at=case when new_paid>=coalesce(approved_amount,0) and approved_amount is not null then now() else paid_at end,updated_by=uid,updated_at=now() where id=_claim_id;
  perform public.fn_ledger_post('income',abs(_amount),coalesce(_method,'bank'),'insurance_settlement','Insurance claim payment — '||claim.claim_number,'insurance_claim_payment',pay_id,now(),claim_branch);
  return pay_id;
end; $$;
