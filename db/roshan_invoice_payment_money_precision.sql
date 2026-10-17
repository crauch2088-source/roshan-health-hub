-- Reject invoice payment inputs that would be silently rounded by payments.amount numeric(14,2).
BEGIN;
CREATE OR REPLACE FUNCTION public.post_invoice_payment(_invoice_id uuid, _amount numeric, _method text DEFAULT 'cash'::text, _reference text DEFAULT NULL::text, _idempotency_key text DEFAULT NULL::text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $function$
DECLARE
  net numeric; already numeric; outstanding numeric; pay_id uuid; uid uuid; invoice_branch uuid; user_branch uuid;
  existing_actor uuid; existing_invoice_id uuid; existing_amount numeric; existing_method text; existing_reference text;
BEGIN
  IF NOT public.app_has_perm('payments.create') AND NOT public.app_has_perm('billing.create') AND NOT public.app_has_perm('accounting.create') THEN
    RAISE EXCEPTION 'not authorised to record payments' USING ERRCODE = '42501';
  END IF;
  IF _amount IS NULL OR _amount::text IN ('NaN','Infinity','-Infinity') OR _amount <= 0 OR _amount <> pg_catalog.round(_amount, 2) THEN
    RAISE EXCEPTION 'payment amount must be finite, greater than zero, and have at most two decimal places' USING ERRCODE = '22023';
  END IF;
  IF _invoice_id IS NULL THEN RAISE EXCEPTION 'invoice is required' USING ERRCODE = '22023'; END IF;
  uid := public.current_app_user_id();
  SELECT branch_id INTO user_branch FROM public.users WHERE id=uid AND deleted_at IS NULL AND active IS TRUE;
  IF NOT public.is_super_admin() AND user_branch IS NULL THEN RAISE EXCEPTION 'user branch is not configured' USING ERRCODE = '42501'; END IF;
  IF _idempotency_key IS NOT NULL THEN
    PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('roshan.payment.idempotency:' || _idempotency_key,0));
    SELECT p.id,p.created_by,p.invoice_id,p.amount,COALESCE(p.payment_method,p.method,'cash'),NULLIF(BTRIM(COALESCE(p.reference_no,p.reference,'')),'')
      INTO pay_id,existing_actor,existing_invoice_id,existing_amount,existing_method,existing_reference
      FROM public.payments p WHERE p.idempotency_key=_idempotency_key;
    IF pay_id IS NOT NULL THEN
      IF existing_actor IS DISTINCT FROM uid OR existing_invoice_id IS DISTINCT FROM _invoice_id OR existing_amount IS DISTINCT FROM _amount
         OR existing_method IS DISTINCT FROM COALESCE(_method,'cash') OR existing_reference IS DISTINCT FROM NULLIF(BTRIM(COALESCE(_reference,'')),'') THEN
        RAISE EXCEPTION 'idempotency key reused with different payment request' USING ERRCODE = '22023';
      END IF;
      RETURN pay_id;
    END IF;
  END IF;
  SELECT COALESCE(i.net_amount,i.total_amount,0),COALESCE(i.paid_amount,0),i.branch_id
    INTO net,already,invoice_branch FROM public.invoices i WHERE i.id=_invoice_id AND i.deleted_at IS NULL FOR UPDATE;
  IF net IS NULL THEN RAISE EXCEPTION 'invoice not found' USING ERRCODE = '22023'; END IF;
  IF NOT public.is_super_admin() AND invoice_branch IS DISTINCT FROM user_branch THEN RAISE EXCEPTION 'cross_branch_access_denied' USING ERRCODE = '42501'; END IF;
  outstanding := GREATEST(net-already,0);
  IF _amount > outstanding THEN RAISE EXCEPTION 'payment (%) exceeds outstanding balance (%)',_amount,outstanding USING ERRCODE = '22023'; END IF;
  INSERT INTO public.payments(invoice_id,amount,payment_method,method,reference_no,reference,payment_date,received_at,received_by,created_by,branch_id,idempotency_key)
  VALUES (_invoice_id,_amount,COALESCE(_method,'cash'),COALESCE(_method,'cash'),NULLIF(BTRIM(COALESCE(_reference,'')),''),NULLIF(BTRIM(COALESCE(_reference,'')),''),CURRENT_DATE,now(),uid,uid,invoice_branch,_idempotency_key)
  RETURNING id INTO pay_id;
  RETURN pay_id;
END;
$function$;
COMMIT;
