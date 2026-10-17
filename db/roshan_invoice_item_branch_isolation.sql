-- Focused remediation for invoice child-row branch isolation.
-- Apply only after the normal migration-history/replay review.
-- invoice_items has no branch_id; derive authorization from its parent invoice.
REVOKE ALL ON FUNCTION private.app_has_invoice_branch(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.app_has_invoice_branch(uuid) TO authenticated;

ALTER POLICY invoice_items_select ON public.invoice_items
  USING (
    (
      (SELECT public.app_has_perm('billing.read'))
      OR (SELECT public.app_has_perm('billing.view'))
    )
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  );

ALTER POLICY invoice_items_insert ON public.invoice_items
  WITH CHECK (
    (SELECT public.app_has_perm('billing.create'))
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  );

ALTER POLICY invoice_items_update ON public.invoice_items
  USING (
    (
      (SELECT public.app_has_perm('billing.update'))
      OR (SELECT public.app_has_perm('billing.edit'))
    )
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  )
  WITH CHECK (
    (
      (SELECT public.app_has_perm('billing.update'))
      OR (SELECT public.app_has_perm('billing.edit'))
    )
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  );

ALTER POLICY invoice_items_delete ON public.invoice_items
  USING (
    (SELECT public.app_has_perm('billing.delete'))
    AND (SELECT private.app_has_invoice_branch(invoice_items.invoice_id))
  );
