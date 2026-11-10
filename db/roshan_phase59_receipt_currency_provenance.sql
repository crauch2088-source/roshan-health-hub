-- Phase 59: receipt status must expose persisted currency provenance.
-- Requires Phase 58 SDG currency columns. Candidate only; hosted rollout is separately gated.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_invoice_payment_receipt_status_v2(
  _payment_ids uuid[]
)
RETURNS TABLE (
  payment_id uuid,
  ledger_found boolean,
  ledger_matches boolean,
  ledger_is_reversed boolean,
  reversal_reason text,
  reversal_at timestamptz,
  payment_currency_code text,
  invoice_currency_code text,
  ledger_currency_code text,
  reversal_currency_code text,
  currency_matches boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
BEGIN
  IF NOT public.app_has_perm('payments.read')
     OR NOT public.app_has_perm('billing.read') THEN
    RAISE EXCEPTION 'not authorised to read invoice payment receipt status'
      USING ERRCODE = '42501';
  END IF;
  IF _payment_ids IS NULL OR pg_catalog.cardinality(_payment_ids) = 0 THEN
    RETURN;
  END IF;
  IF pg_catalog.cardinality(_payment_ids) > 200 THEN
    RAISE EXCEPTION 'at most 200 payment ids may be checked at once'
      USING ERRCODE = '22023';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    COALESCE(c.ledger_count, 0) = 1,
    integrity.ledger_matches,
    CASE WHEN integrity.ledger_matches THEN COALESCE(c.is_reversed, false) ELSE false END,
    CASE
      WHEN integrity.ledger_matches AND c.is_reversed THEN c.reversal_reason
      ELSE NULL
    END,
    CASE
      WHEN integrity.ledger_matches AND c.is_reversed THEN r.transaction_date
      ELSE NULL
    END,
    p.currency_code,
    i.currency_code,
    CASE WHEN integrity.ledger_matches THEN c.currency_code ELSE NULL END,
    CASE
      WHEN integrity.ledger_matches AND c.is_reversed THEN r.currency_code
      ELSE NULL
    END,
    COALESCE(
      integrity.ledger_matches
        AND p.currency_code = 'SDG'
        AND i.currency_code = 'SDG'
        AND c.currency_code = 'SDG'
        AND (
          (
            NOT COALESCE(c.is_reversed, false)
            AND COALESCE(r.reversal_count, 0) = 0
          )
          OR (
            c.is_reversed
            AND r.reversal_count = 1
            AND r.currency_code = 'SDG'
          )
        ),
      false
    )
  FROM public.payments p
  JOIN public.invoices i
    ON i.id = p.invoice_id
   AND i.deleted_at IS NULL
  LEFT JOIN LATERAL (
    SELECT
      pg_catalog.count(*) AS ledger_count,
      pg_catalog.min(c.id::text)::uuid AS id,
      pg_catalog.min(c.branch_id::text)::uuid AS branch_id,
      pg_catalog.min(c.amount) AS amount,
      pg_catalog.bool_or(COALESCE(c.is_reversed, false)) AS is_reversed,
      pg_catalog.min(c.reversal_reason) AS reversal_reason,
      pg_catalog.min(c.currency_code) AS currency_code
    FROM public.cashbox_transactions c
    WHERE c.source_type = 'payment'
      AND c.source_id = p.id
      AND c.reversal_of IS NULL
  ) c ON true
  LEFT JOIN LATERAL (
    SELECT
      pg_catalog.count(*) AS reversal_count,
      pg_catalog.bool_and(
        r.source_type = 'reversal'
        AND r.branch_id = c.branch_id
        AND r.amount = -c.amount
      ) AS reversal_matches,
      pg_catalog.min(r.currency_code) AS currency_code,
      pg_catalog.min(r.transaction_date) AS transaction_date
    FROM public.cashbox_transactions r
    WHERE r.reversal_of = c.id
  ) r ON true
  CROSS JOIN LATERAL (
    SELECT (
      COALESCE(c.ledger_count, 0) = 1
      AND c.branch_id IS NOT NULL
      AND p.branch_id IS NOT NULL
      AND i.branch_id IS NOT NULL
      AND c.branch_id = p.branch_id
      AND p.branch_id = i.branch_id
      AND c.amount IS NOT DISTINCT FROM pg_catalog.abs(p.amount)
      AND (
        (
          NOT COALESCE(c.is_reversed, false)
          AND COALESCE(r.reversal_count, 0) = 0
        )
        OR (
          c.is_reversed
          AND r.reversal_count = 1
          AND r.reversal_matches IS TRUE
        )
      )
    ) AS ledger_matches
  ) integrity
  WHERE p.id = ANY(_payment_ids)
    AND private.app_has_branch_access(p.branch_id)
    AND private.app_has_branch_access(i.branch_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.get_invoice_payment_receipt_status_v2(uuid[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_invoice_payment_receipt_status_v2(uuid[]) TO authenticated;

COMMIT;
