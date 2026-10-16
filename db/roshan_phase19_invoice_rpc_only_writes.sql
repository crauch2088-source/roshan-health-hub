-- Proposed follow-up migration; apply only after the recovered migration history
-- is reconciled and the RPC-only paths in PR #23 are reviewed on the target database.
--
-- The current app uses atomic/idempotent RPCs for manual billing, visit consultation
-- invoices, and lab-order invoices. Direct table writes can bypass transaction
-- consolidation, line validation, idempotency, and invoice-total synchronization.

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.invoices, public.invoice_items
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.create_billing_invoice_atomic(uuid, uuid, uuid, date, numeric, jsonb, boolean, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_billing_invoice_atomic(uuid, uuid, uuid, date, numeric, jsonb, boolean, uuid)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.create_visit_consultation_invoice_atomic(uuid, date)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_visit_consultation_invoice_atomic(uuid, date)
  TO authenticated;

REVOKE EXECUTE ON FUNCTION public.create_lab_order_with_invoice_atomic(uuid, text, text, uuid[], boolean, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_lab_order_with_invoice_atomic(uuid, text, text, uuid[], boolean, uuid)
  TO authenticated;

-- invoice_items has no branch_id of its own. Its old SELECT policy checked only
-- billing.read/view, which could expose line items for invoices in other branches.
-- Reuse the same branch-access helper as the parent invoices table.
DROP POLICY IF EXISTS invoice_items_select ON public.invoice_items;
CREATE POLICY invoice_items_select ON public.invoice_items
  FOR SELECT TO authenticated
  USING (
    (
      (SELECT public.app_has_perm('billing.read'))
      OR (SELECT public.app_has_perm('billing.view'))
    )
    AND EXISTS (
      SELECT 1
      FROM public.invoices AS i
      WHERE i.id = invoice_items.invoice_id
        AND (SELECT private.app_has_branch_access(i.branch_id))
    )
  );
