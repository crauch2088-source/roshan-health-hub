-- Phase 52: bounded, branch-aware, read-only operational reporting.
-- SECURITY INVOKER is intentional: source-table RLS remains the row-visibility boundary.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_reporting_analytics(
  p_from_date date,
  p_to_date date,
  p_branch_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path TO ''
AS $function$
DECLARE
  v_from timestamptz;
  v_to timestamptz;
  v_result jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT private.app_has_perm('reports.read') THEN
    RAISE EXCEPTION 'reporting_permission_denied' USING ERRCODE = '42501';
  END IF;

  IF p_from_date IS NULL OR p_to_date IS NULL
     OR p_to_date < p_from_date
     OR (p_to_date - p_from_date) > 365 THEN
    RAISE EXCEPTION 'reporting_date_range_invalid' USING ERRCODE = '22023';
  END IF;

  IF p_branch_id IS NOT NULL
     AND NOT COALESCE(private.app_has_branch_access(p_branch_id), false) THEN
    RAISE EXCEPTION 'reporting_branch_access_denied' USING ERRCODE = '42501';
  END IF;

  -- Roshan operates in Sudan (Africa/Khartoum, UTC+2); use clinic-local
  -- calendar dates rather than the database session timezone.
  v_from := p_from_date::timestamp AT TIME ZONE 'Africa/Khartoum';
  v_to := (p_to_date + 1)::timestamp AT TIME ZONE 'Africa/Khartoum';

  SELECT pg_catalog.jsonb_build_object(
    'period', pg_catalog.jsonb_build_object('from', p_from_date, 'to', p_to_date, 'branch_id', p_branch_id),
    'summary', pg_catalog.jsonb_build_object(
      'visits', (
        SELECT count(*) FROM public.visits v
         WHERE v.deleted_at IS NULL AND v.visit_date >= v_from AND v.visit_date < v_to
           AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
      ),
      'completed_visits', (
        SELECT count(*) FROM public.visits v
         WHERE v.deleted_at IS NULL AND v.status = 'completed'
           AND v.visit_date >= v_from AND v.visit_date < v_to
           AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
      ),
      'cancelled_visits', (
        SELECT count(*) FROM public.visits v
         WHERE v.deleted_at IS NULL AND v.status = 'cancelled'
           AND v.visit_date >= v_from AND v.visit_date < v_to
           AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
      ),
      'consultation_revenue', (
        SELECT COALESCE(sum(v.consultation_fee), 0) FROM public.visits v
         WHERE v.deleted_at IS NULL AND v.visit_date >= v_from AND v.visit_date < v_to
           AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
      ),
      'payments_collected', (
        SELECT COALESCE(sum(p.amount), 0) FROM public.payments p
         WHERE p.deleted_at IS NULL AND p.payment_date >= v_from AND p.payment_date < v_to
           AND (p_branch_id IS NULL OR p.branch_id = p_branch_id)
      ),
      'operating_expenses', (
        SELECT COALESCE(sum(e.amount), 0) FROM public.expenses e
         WHERE e.deleted_at IS NULL AND e.expense_date >= p_from_date AND e.expense_date <= p_to_date
           AND (p_branch_id IS NULL OR e.branch_id = p_branch_id)
      ),
      'net_cashflow', (
        (SELECT COALESCE(sum(p.amount), 0) FROM public.payments p
          WHERE p.deleted_at IS NULL AND p.payment_date >= v_from AND p.payment_date < v_to
            AND (p_branch_id IS NULL OR p.branch_id = p_branch_id))
        -
        (SELECT COALESCE(sum(e.amount), 0) FROM public.expenses e
          WHERE e.deleted_at IS NULL AND e.expense_date >= p_from_date AND e.expense_date <= p_to_date
            AND (p_branch_id IS NULL OR e.branch_id = p_branch_id))
      ),
      'lab_orders', (
        SELECT count(*) FROM public.lab_orders lo
         WHERE lo.deleted_at IS NULL AND lo.created_at >= v_from AND lo.created_at < v_to
           AND (p_branch_id IS NULL OR lo.branch_id = p_branch_id)
      ),
      'lab_items', (
        SELECT count(*) FROM public.lab_order_items li
         JOIN public.lab_orders lo ON lo.id = li.order_id
         WHERE li.deleted_at IS NULL AND lo.deleted_at IS NULL
           AND lo.created_at >= v_from AND lo.created_at < v_to
           AND (p_branch_id IS NULL OR lo.branch_id = p_branch_id)
      ),
      'lab_revenue', (
        SELECT COALESCE(sum(li.price), 0) FROM public.lab_order_items li
         JOIN public.lab_orders lo ON lo.id = li.order_id
         WHERE li.deleted_at IS NULL AND lo.deleted_at IS NULL
           AND lo.created_at >= v_from AND lo.created_at < v_to
           AND (p_branch_id IS NULL OR lo.branch_id = p_branch_id)
      ),
      'insurance_claims', (
        SELECT count(*) FROM public.insurance_claims c
         JOIN public.invoices i ON i.id = c.invoice_id
         WHERE c.deleted_at IS NULL AND i.deleted_at IS NULL
           AND c.submitted_at >= v_from AND c.submitted_at < v_to
           AND (p_branch_id IS NULL OR i.branch_id = p_branch_id)
      ),
      'insurance_submitted', (
        SELECT COALESCE(sum(c.submitted_amount), 0) FROM public.insurance_claims c
         JOIN public.invoices i ON i.id = c.invoice_id
         WHERE c.deleted_at IS NULL AND i.deleted_at IS NULL
           AND c.submitted_at >= v_from AND c.submitted_at < v_to
           AND (p_branch_id IS NULL OR i.branch_id = p_branch_id)
      ),
      'insurance_approved', (
        SELECT COALESCE(sum(c.approved_amount), 0) FROM public.insurance_claims c
         JOIN public.invoices i ON i.id = c.invoice_id
         WHERE c.deleted_at IS NULL AND i.deleted_at IS NULL
           AND c.decided_at >= v_from AND c.decided_at < v_to
           AND (p_branch_id IS NULL OR i.branch_id = p_branch_id)
      ),
      'insurance_paid', (
        SELECT COALESCE(sum(c.paid_amount), 0) FROM public.insurance_claims c
         JOIN public.invoices i ON i.id = c.invoice_id
         WHERE c.deleted_at IS NULL AND i.deleted_at IS NULL
           AND c.paid_at >= v_from AND c.paid_at < v_to
           AND (p_branch_id IS NULL OR i.branch_id = p_branch_id)
      ),
      'prescriptions', (
        SELECT count(*) FROM public.prescriptions rx
         WHERE rx.deleted_at IS NULL AND rx.created_at >= v_from AND rx.created_at < v_to
           AND (p_branch_id IS NULL OR rx.branch_id = p_branch_id)
      ),
      'dispensed_prescriptions', (
        SELECT count(*) FROM public.prescriptions rx
         WHERE rx.deleted_at IS NULL AND rx.dispensed_at >= v_from AND rx.dispensed_at < v_to
           AND (p_branch_id IS NULL OR rx.branch_id = p_branch_id)
      ),
      'dispensed_units', (
        SELECT COALESCE(sum(pg_catalog.abs(sm.quantity)), 0) FROM public.stock_movements sm
         WHERE sm.movement_type = 'dispense' AND sm.created_at >= v_from AND sm.created_at < v_to
           AND (p_branch_id IS NULL OR sm.branch_id = p_branch_id)
      ),
      'writeoff_units', (
        SELECT COALESCE(sum(pg_catalog.abs(sm.quantity)), 0) FROM public.stock_movements sm
         WHERE sm.movement_type = 'writeoff' AND sm.created_at >= v_from AND sm.created_at < v_to
           AND (p_branch_id IS NULL OR sm.branch_id = p_branch_id)
      )
    ),
    'monthly', (
      SELECT COALESCE(
        pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object(
            'month', pg_catalog.to_char(m.month_start, 'YYYY-MM'),
            'visits', (
              SELECT count(*) FROM public.visits v
               WHERE v.deleted_at IS NULL
                 AND v.visit_date >= (GREATEST(m.month_start::date, p_from_date)::timestamp AT TIME ZONE 'Africa/Khartoum')
                 AND v.visit_date < (LEAST((m.month_start + interval '1 month')::date, p_to_date + 1)::timestamp AT TIME ZONE 'Africa/Khartoum')
                 AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
            ),
            'payments', (
              SELECT COALESCE(sum(p.amount), 0) FROM public.payments p
               WHERE p.deleted_at IS NULL
                 AND p.payment_date >= (GREATEST(m.month_start::date, p_from_date)::timestamp AT TIME ZONE 'Africa/Khartoum')
                 AND p.payment_date < (LEAST((m.month_start + interval '1 month')::date, p_to_date + 1)::timestamp AT TIME ZONE 'Africa/Khartoum')
                 AND (p_branch_id IS NULL OR p.branch_id = p_branch_id)
            ),
            'expenses', (
              SELECT COALESCE(sum(e.amount), 0) FROM public.expenses e
               WHERE e.deleted_at IS NULL
                 AND e.expense_date >= GREATEST(m.month_start::date, p_from_date)
                 AND e.expense_date < LEAST((m.month_start + interval '1 month')::date, p_to_date + 1)
                 AND (p_branch_id IS NULL OR e.branch_id = p_branch_id)
            )
          ) ORDER BY m.month_start
        ), '[]'::jsonb
      )
      FROM (
        SELECT pg_catalog.generate_series(
          pg_catalog.date_trunc('month', p_from_date::timestamp),
          pg_catalog.date_trunc('month', p_to_date::timestamp),
          interval '1 month'
        ) AS month_start
      ) m
    ),
    'by_department', (
      SELECT COALESCE(
        pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', d.name, 'count', d.total)
                             ORDER BY d.total DESC, d.name), '[]'::jsonb)
      FROM (
        SELECT COALESCE(NULLIF(pg_catalog.btrim(v.department), ''), '—') AS name, count(*) AS total
          FROM public.visits v
         WHERE v.deleted_at IS NULL AND v.visit_date >= v_from AND v.visit_date < v_to
           AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
         GROUP BY 1 ORDER BY total DESC, name LIMIT 20
      ) d
    ),
    'by_doctor', (
      SELECT COALESCE(
        pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', d.name, 'count', d.total)
                             ORDER BY d.total DESC, d.name), '[]'::jsonb)
      FROM (
        SELECT COALESCE(NULLIF(pg_catalog.btrim(u.full_name), ''), '—') AS name, count(*) AS total
          FROM public.visits v
          LEFT JOIN public.users u ON u.id = v.doctor_id
         WHERE v.deleted_at IS NULL AND v.visit_date >= v_from AND v.visit_date < v_to
           AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
         GROUP BY 1 ORDER BY total DESC, name LIMIT 20
      ) d
    ),
    'by_test', (
      SELECT COALESCE(
        pg_catalog.jsonb_agg(
          pg_catalog.jsonb_build_object('name', d.name, 'name_ar', d.name_ar, 'count', d.total)
          ORDER BY d.total DESC, d.name
        ), '[]'::jsonb)
      FROM (
        SELECT COALESCE(NULLIF(pg_catalog.btrim(t.name), ''), '—') AS name,
               COALESCE(NULLIF(pg_catalog.btrim(t.name_ar), ''), NULLIF(pg_catalog.btrim(t.name), ''), '—') AS name_ar,
               count(*) AS total
          FROM public.lab_order_items li
          JOIN public.lab_orders lo ON lo.id = li.order_id
          LEFT JOIN public.lab_tests t ON t.id = li.test_id
         WHERE li.deleted_at IS NULL AND lo.deleted_at IS NULL
           AND lo.created_at >= v_from AND lo.created_at < v_to
           AND (p_branch_id IS NULL OR lo.branch_id = p_branch_id)
         GROUP BY 1, 2 ORDER BY total DESC, name LIMIT 20
      ) d
    ),
    'by_diagnosis', (
      SELECT COALESCE(
        pg_catalog.jsonb_agg(pg_catalog.jsonb_build_object('name', d.name, 'count', d.total)
                             ORDER BY d.total DESC, d.name), '[]'::jsonb)
      FROM (
        SELECT COALESCE(NULLIF(pg_catalog.btrim(dx.diagnosis_name), ''), '—') AS name, count(*) AS total
          FROM public.diagnoses dx
          JOIN public.visits v ON v.id = dx.visit_id
         WHERE dx.deleted_at IS NULL AND v.deleted_at IS NULL
           AND v.visit_date >= v_from AND v.visit_date < v_to
           AND (p_branch_id IS NULL OR v.branch_id = p_branch_id)
         GROUP BY 1 ORDER BY total DESC, name LIMIT 20
      ) d
    )
  )
  INTO v_result;

  RETURN v_result;
END;
$function$;

REVOKE ALL ON FUNCTION public.get_reporting_analytics(date, date, uuid) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.get_reporting_analytics(date, date, uuid) TO authenticated;
COMMENT ON FUNCTION public.get_reporting_analytics(date, date, uuid) IS
  'Returns bounded, branch-aware operational aggregates only; SECURITY INVOKER preserves source-table RLS and no patient identifiers or clinical notes are returned.';

NOTIFY pgrst, 'reload schema';
COMMIT;
