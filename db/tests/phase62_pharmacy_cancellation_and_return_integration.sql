-- Phase 62 (RHH-01) Integration Tests: Pre-handover cancellation, post-handover quarantine return,
-- immutable financial compensation, quarantine disposition, RLS/RBAC/branch isolation, and atomicity.

BEGIN;

DO $$
DECLARE
  v_branch_a uuid := '10000000-0000-0000-0000-000000000001';
  v_branch_b uuid := '10000000-0000-0000-0000-000000000002';

  v_pharm_a uuid := '20000000-0000-0000-0000-000000000001';
  v_reader_a uuid := '20000000-0000-0000-0000-000000000002';
  v_pharm_b uuid := '20000000-0000-0000-0000-000000000003';

  v_pat_1 uuid := '30000000-0000-0000-0000-000000000001';
  v_pat_2 uuid := '30000000-0000-0000-0000-000000000002';
  v_pat_3 uuid := '30000000-0000-0000-0000-000000000003';
  v_pat_4 uuid := '30000000-0000-0000-0000-000000000004';
  v_pat_5 uuid := '30000000-0000-0000-0000-000000000005';

  v_vis_1 uuid := '40000000-0000-0000-0000-000000000001';
  v_vis_2 uuid := '40000000-0000-0000-0000-000000000002';
  v_vis_3 uuid := '40000000-0000-0000-0000-000000000003';
  v_vis_4 uuid := '40000000-0000-0000-0000-000000000004';
  v_vis_5 uuid := '40000000-0000-0000-0000-000000000005';

  v_inv_unpaid uuid := '50000000-0000-0000-0000-000000000001';
  v_inv_partial uuid := '50000000-0000-0000-0000-000000000002';
  v_inv_paid uuid := '50000000-0000-0000-0000-000000000003';
  v_inv_ret uuid := '50000000-0000-0000-0000-000000000004';

  v_med_1 uuid := '60000000-0000-0000-0000-000000000001';
  v_batch_valid uuid := '70000000-0000-0000-0000-000000000001';
  v_batch_expired uuid := '70000000-0000-0000-0000-000000000002';

  v_rx_unpaid uuid := '80000000-0000-0000-0000-000000000001';
  v_rx_partial uuid := '80000000-0000-0000-0000-000000000002';
  v_rx_paid uuid := '80000000-0000-0000-0000-000000000003';
  v_rx_handover uuid := '80000000-0000-0000-0000-000000000004';
  v_rx_exp uuid := '80000000-0000-0000-0000-000000000005';

  v_idem_1 uuid := '90000000-0000-0000-0000-000000000001';
  v_idem_2 uuid := '90000000-0000-0000-0000-000000000002';
  v_idem_3 uuid := '90000000-0000-0000-0000-000000000003';
  v_idem_4 uuid := '90000000-0000-0000-0000-000000000004';
  v_idem_5 uuid := '90000000-0000-0000-0000-000000000005';
  v_idem_6 uuid := '90000000-0000-0000-0000-000000000006';
  v_idem_7 uuid := '90000000-0000-0000-0000-000000000007';

  v_cancel_id uuid;
  v_cancel_id_2 uuid;
  v_ret_id_1 uuid;
  v_ret_id_1_dup uuid;
  v_ret_id_2 uuid;
  v_ret_id_3 uuid;
  v_q_id_1 uuid;
  v_q_id_2 uuid;
  v_q_id_3 uuid;
  v_handover_ts timestamptz;
  v_cnt integer;
  v_qty numeric;
  v_med_qty integer;
  v_comp record;
  v_inv record;
  v_state text;
BEGIN
  -- Seed users
  INSERT INTO public.users (id, branch_id, active) VALUES
    (v_pharm_a, v_branch_a, true),
    (v_reader_a, v_branch_a, true),
    (v_pharm_b, v_branch_b, true);

  -- Seed patients & visits
  INSERT INTO public.patients (id, branch_id) VALUES
    (v_pat_1, v_branch_a),
    (v_pat_2, v_branch_a),
    (v_pat_3, v_branch_a),
    (v_pat_4, v_branch_a),
    (v_pat_5, v_branch_a);

  INSERT INTO public.visits (id, patient_id, branch_id) VALUES
    (v_vis_1, v_pat_1, v_branch_a),
    (v_vis_2, v_pat_2, v_branch_a),
    (v_vis_3, v_pat_3, v_branch_a),
    (v_vis_4, v_pat_4, v_branch_a),
    (v_vis_5, v_pat_5, v_branch_a);

  -- Seed invoices (unpaid, partially paid, paid, and return target)
  INSERT INTO public.invoices (id, invoice_number, patient_id, visit_id, total_amount, net_amount, paid_amount, payment_status, branch_id) VALUES
    (v_inv_unpaid,  'INV-P62-001', v_pat_1, v_vis_1, 100.00, 100.00,   0.00, 'unpaid',         v_branch_a),
    (v_inv_partial, 'INV-P62-002', v_pat_2, v_vis_2, 100.00, 100.00,  40.00, 'partially_paid', v_branch_a),
    (v_inv_paid,    'INV-P62-003', v_pat_3, v_vis_3, 100.00, 100.00, 100.00, 'paid',           v_branch_a),
    (v_inv_ret,     'INV-P62-004', v_pat_4, v_vis_4, 150.00, 150.00,  75.00, 'partially_paid', v_branch_a);

  -- Seed medicine & batches (initial remaining after dispenses: valid=50, expired=10, med.stock_quantity=60)
  INSERT INTO public.medicines (id, name, selling_price, stock_quantity) VALUES
    (v_med_1, 'Amoxicillin 500mg', 25.00, 60);

  INSERT INTO public.pharmacy_inventory (id, medicine_id, batch_number, expiry_date, quantity, quantity_remaining, quantity_received, branch_id) VALUES
    (v_batch_valid,   v_med_1, 'BATCH-VALID-01', CURRENT_DATE + 180, 100, 50, 100, v_branch_a),
    (v_batch_expired, v_med_1, 'BATCH-EXP-01',   CURRENT_DATE - 1,   20,  10,  20, v_branch_a);

  -- Seed dispensed prescriptions
  INSERT INTO public.prescriptions (id, patient_id, visit_id, status, dispensed_by, dispensed_at) VALUES
    (v_rx_unpaid,   v_pat_1, v_vis_1, 'dispensed', v_pharm_a, clock_timestamp()),
    (v_rx_partial,  v_pat_2, v_vis_2, 'dispensed', v_pharm_a, clock_timestamp()),
    (v_rx_paid,     v_pat_3, v_vis_3, 'dispensed', v_pharm_a, clock_timestamp()),
    (v_rx_handover, v_pat_4, v_vis_4, 'dispensed', v_pharm_a, clock_timestamp()),
    (v_rx_exp,      v_pat_5, v_vis_5, 'dispensed', v_pharm_a, clock_timestamp());

  INSERT INTO public.prescription_items (id, prescription_id, medicine_id, medication_name, quantity, dispensed_quantity, unit_price, is_dispensed) VALUES
    (gen_random_uuid(), v_rx_unpaid,   v_med_1, 'Amoxicillin 500mg', 4, 4, 25.00, true),
    (gen_random_uuid(), v_rx_partial,  v_med_1, 'Amoxicillin 500mg', 4, 4, 25.00, true),
    (gen_random_uuid(), v_rx_paid,     v_med_1, 'Amoxicillin 500mg', 4, 4, 25.00, true),
    (gen_random_uuid(), v_rx_handover, v_med_1, 'Amoxicillin 500mg', 6, 6, 25.00, true),
    (gen_random_uuid(), v_rx_exp,      v_med_1, 'Amoxicillin 500mg', 2, 2, 25.00, true);

  INSERT INTO public.stock_movements (medicine_id, batch_id, movement_type, quantity, reference_id, reference_table, branch_id, created_by) VALUES
    (v_med_1, v_batch_valid,   'dispense', -4, v_rx_unpaid,   'prescriptions', v_branch_a, v_pharm_a),
    (v_med_1, v_batch_valid,   'dispense', -4, v_rx_partial,  'prescriptions', v_branch_a, v_pharm_a),
    (v_med_1, v_batch_valid,   'dispense', -4, v_rx_paid,     'prescriptions', v_branch_a, v_pharm_a),
    (v_med_1, v_batch_valid,   'dispense', -6, v_rx_handover, 'prescriptions', v_branch_a, v_pharm_a),
    (v_med_1, v_batch_expired, 'dispense', -2, v_rx_exp,      'prescriptions', v_branch_a, v_pharm_a);

  -- Set Branch A pharmacist context
  PERFORM set_config('test.user_id', v_pharm_a::text, true);
  PERFORM set_config('test.perms', 'pharmacy.read,pharmacy.update', true);
  PERFORM set_config('test.super_admin', 'false', true);

  -- 1. Pre-handover cancellation on unpaid invoice
  v_cancel_id := public.cancel_dispense_before_handover(v_rx_unpaid, 'Patient declined before pickup', v_idem_1);
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_valid;
  SELECT stock_quantity INTO v_med_qty FROM public.medicines WHERE id = v_med_1;
  IF v_qty <> 54 OR v_med_qty <> 64 THEN
    RAISE EXCEPTION 'Expected stock restored to 54/64, got %/%', v_qty, v_med_qty;
  END IF;

  SELECT fc.* INTO v_comp
    FROM public.financial_compensations fc
    JOIN public.pharmacy_dispense_cancellations c ON c.compensation_id = fc.id
   WHERE c.id = v_cancel_id;
  IF v_comp.invoice_payment_state <> 'unpaid' OR v_comp.credit_amount <> 100.00 OR v_comp.refund_due_amount <> 0.00 THEN
    RAISE EXCEPTION 'Unexpected unpaid compensation: %', row_to_json(v_comp);
  END IF;

  -- Verify historical invoice is untouched
  SELECT paid_amount, net_amount, payment_status INTO v_inv FROM public.invoices WHERE id = v_inv_unpaid;
  IF v_inv.paid_amount <> 0.00 OR v_inv.net_amount <> 100.00 OR v_inv.payment_status <> 'unpaid' THEN
    RAISE EXCEPTION 'Historical unpaid invoice was mutated';
  END IF;

  -- 2. Idempotency of pre-handover cancellation
  v_cancel_id_2 := public.cancel_dispense_before_handover(v_rx_unpaid, 'Retry same key', v_idem_1);
  IF v_cancel_id_2 <> v_cancel_id THEN
    RAISE EXCEPTION 'Idempotent cancellation returned different id';
  END IF;
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_valid;
  IF v_qty <> 54 THEN
    RAISE EXCEPTION 'Idempotent retry double-restocked batch: %', v_qty;
  END IF;

  -- 3. Double-cancel rejection with new idempotency key
  BEGIN
    PERFORM public.cancel_dispense_before_handover(v_rx_unpaid, 'Second cancel', v_idem_2);
    RAISE EXCEPTION 'Expected dispense_already_cancelled error';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    NULL;
  END;

  -- 4. Pre-handover cancellation on partially paid and fully paid invoices
  PERFORM public.cancel_dispense_before_handover(v_rx_partial, 'Partial paid cancel', v_idem_2);
  SELECT fc.* INTO v_comp FROM public.financial_compensations fc WHERE fc.idempotency_key = v_idem_2;
  IF v_comp.invoice_payment_state <> 'partially_paid' OR v_comp.credit_amount <> 100.00 OR v_comp.refund_due_amount <> 40.00 THEN
    RAISE EXCEPTION 'Unexpected partially_paid compensation: %', row_to_json(v_comp);
  END IF;

  PERFORM public.cancel_dispense_before_handover(v_rx_paid, 'Full paid cancel', v_idem_3);
  SELECT fc.* INTO v_comp FROM public.financial_compensations fc WHERE fc.idempotency_key = v_idem_3;
  IF v_comp.invoice_payment_state <> 'paid' OR v_comp.credit_amount <> 100.00 OR v_comp.refund_due_amount <> 100.00 THEN
    RAISE EXCEPTION 'Unexpected paid compensation: %', row_to_json(v_comp);
  END IF;

  -- 5. Return before handover must be rejected
  BEGIN
    PERFORM public.record_post_handover_return(v_rx_handover, v_med_1, v_batch_valid, 2, 'unopened_intact', 'Before handover', v_idem_4);
    RAISE EXCEPTION 'Expected return_requires_handover_use_cancellation';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    NULL;
  END;

  -- 6. Confirm handover, then reject pre-handover cancellation
  v_handover_ts := public.confirm_pharmacy_handover(v_rx_handover);
  IF v_handover_ts IS NULL THEN
    RAISE EXCEPTION 'confirm_pharmacy_handover returned NULL';
  END IF;

  BEGIN
    PERFORM public.cancel_dispense_before_handover(v_rx_handover, 'After handover cancel', v_idem_4);
    RAISE EXCEPTION 'Expected handover_already_recorded_use_return_workflow';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    NULL;
  END;

  -- 7. Post-handover return into quarantine WITHOUT automatic restocking
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_valid; -- should be 62 (54+4+4)
  v_ret_id_1 := public.record_post_handover_return(v_rx_handover, v_med_1, v_batch_valid, 2, 'unopened_intact', 'Unopened box returned', v_idem_4);
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_valid;
  SELECT stock_quantity INTO v_med_qty FROM public.medicines WHERE id = v_med_1;
  IF v_qty <> 62 OR v_med_qty <> 72 THEN
    RAISE EXCEPTION 'Post-handover return must NOT auto-restock saleable inventory (got %/%)', v_qty, v_med_qty;
  END IF;

  SELECT id INTO v_q_id_1 FROM public.pharmacy_return_quarantine WHERE return_id = v_ret_id_1;
  IF v_q_id_1 IS NULL THEN
    RAISE EXCEPTION 'Expected quarantine record for return %', v_ret_id_1;
  END IF;

  -- Idempotency of post-handover return
  v_ret_id_1_dup := public.record_post_handover_return(v_rx_handover, v_med_1, v_batch_valid, 2, 'unopened_intact', 'Dup', v_idem_4);
  IF v_ret_id_1_dup <> v_ret_id_1 THEN
    RAISE EXCEPTION 'Idempotent return returned different id';
  END IF;

  -- Over-return rejection (dispensed 6, returned 2, trying 5)
  BEGIN
    PERFORM public.record_post_handover_return(v_rx_handover, v_med_1, v_batch_valid, 5, 'opened', 'Too many', v_idem_5);
    RAISE EXCEPTION 'Expected return_quantity_exceeds_dispensed';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    NULL;
  END;

  -- Record opened return
  v_ret_id_2 := public.record_post_handover_return(v_rx_handover, v_med_1, v_batch_valid, 2, 'opened', 'Opened blister', v_idem_5);
  SELECT id INTO v_q_id_2 FROM public.pharmacy_return_quarantine WHERE return_id = v_ret_id_2;

  -- 8. Quarantine disposition: unopened_intact restock succeeds; opened restock rejected; expired batch restock rejected + writeoff succeeds
  v_state := public.resolve_quarantine_disposition(v_q_id_1, 'approved_restock', 'Seal intact, approved by QA');
  IF v_state <> 'approved_restock' THEN
    RAISE EXCEPTION 'Expected approved_restock, got %', v_state;
  END IF;
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_valid;
  SELECT stock_quantity INTO v_med_qty FROM public.medicines WHERE id = v_med_1;
  IF v_qty <> 64 OR v_med_qty <> 74 THEN
    RAISE EXCEPTION 'Expected approved_restock to increment to 64/74, got %/%', v_qty, v_med_qty;
  END IF;

  -- Opened return cannot be restocked
  BEGIN
    PERFORM public.resolve_quarantine_disposition(v_q_id_2, 'approved_restock', 'Try restock opened');
    RAISE EXCEPTION 'Expected only_unopened_intact_may_be_restocked';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    NULL;
  END;

  -- Writeoff opened return succeeds without changing saleable stock
  v_state := public.resolve_quarantine_disposition(v_q_id_2, 'destroyed_writeoff', 'Incinerated per SOP');
  IF v_state <> 'destroyed_writeoff' THEN
    RAISE EXCEPTION 'Expected destroyed_writeoff';
  END IF;

  -- Expired batch return cannot be restocked even if unopened_intact
  PERFORM public.confirm_pharmacy_handover(v_rx_exp);
  v_ret_id_3 := public.record_post_handover_return(v_rx_exp, v_med_1, v_batch_expired, 1, 'unopened_intact', 'Expired batch return', v_idem_6);
  SELECT id INTO v_q_id_3 FROM public.pharmacy_return_quarantine WHERE return_id = v_ret_id_3;

  BEGIN
    PERFORM public.resolve_quarantine_disposition(v_q_id_3, 'approved_restock', 'Try restock expired');
    RAISE EXCEPTION 'Expected cannot_restock_expired_batch';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    NULL;
  END;
  PERFORM public.resolve_quarantine_disposition(v_q_id_3, 'destroyed_writeoff', 'Expired batch destroyed');

  -- 9. Append-only immutability triggers on ledger tables
  BEGIN
    UPDATE public.financial_compensations SET credit_amount = 0 WHERE id = v_comp.id;
    RAISE EXCEPTION 'Expected immutability trigger on financial_compensations UPDATE';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  BEGIN
    DELETE FROM public.pharmacy_dispense_cancellations WHERE id = v_cancel_id;
    RAISE EXCEPTION 'Expected immutability trigger on pharmacy_dispense_cancellations DELETE';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  BEGIN
    UPDATE public.pharmacy_returns SET quantity = 99 WHERE id = v_ret_id_1;
    RAISE EXCEPTION 'Expected immutability trigger on pharmacy_returns UPDATE';
  EXCEPTION WHEN SQLSTATE '55000' THEN NULL;
  END;

  -- 10. Unauthorized role denial (missing pharmacy.update)
  PERFORM set_config('test.user_id', v_reader_a::text, true);
  PERFORM set_config('test.perms', 'pharmacy.read', true);
  BEGIN
    PERFORM public.confirm_pharmacy_handover(v_rx_handover);
    RAISE EXCEPTION 'Expected pharmacy_handover_permission_denied';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  -- 11. Cross-branch denial (Branch B pharmacist cannot access Branch A)
  PERFORM set_config('test.user_id', v_pharm_b::text, true);
  PERFORM set_config('test.perms', 'pharmacy.read,pharmacy.update', true);
  BEGIN
    PERFORM public.cancel_dispense_before_handover(v_rx_handover, 'Cross branch', v_idem_7);
    RAISE EXCEPTION 'Expected branch_access_denied';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;

  -- RLS isolation check as authenticated for Branch B user
  SET LOCAL ROLE authenticated;
  SELECT COUNT(*) INTO v_cnt FROM public.financial_compensations;
  IF v_cnt <> 0 THEN
    RAISE EXCEPTION 'Branch B user saw % financial_compensations rows via RLS', v_cnt;
  END IF;
  SELECT COUNT(*) INTO v_cnt FROM public.pharmacy_return_quarantine;
  IF v_cnt <> 0 THEN
    RAISE EXCEPTION 'Branch B user saw % pharmacy_return_quarantine rows via RLS', v_cnt;
  END IF;

  -- anon role denial
  SET LOCAL ROLE anon;
  BEGIN
    PERFORM public.confirm_pharmacy_handover(v_rx_handover);
    RAISE EXCEPTION 'Expected anon execute denial';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
  RESET ROLE;

  -- 12. Rollback atomicity: failed mutation leaves stock and tables unchanged
  PERFORM set_config('test.user_id', v_pharm_a::text, true);
  PERFORM set_config('test.perms', 'pharmacy.read,pharmacy.update', true);
  BEGIN
    UPDATE public.pharmacy_inventory SET quantity_remaining = quantity_remaining + 999 WHERE id = v_batch_valid;
    PERFORM public.record_post_handover_return(v_rx_handover, v_med_1, v_batch_valid, 1, 'invalid_cond', 'Bad condition', v_idem_7);
    RAISE EXCEPTION 'Expected invalid_return_condition';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    NULL;
  END;
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_valid;
  IF v_qty <> 64 THEN
    RAISE EXCEPTION 'Subtransaction rollback failed to restore batch quantity (got %)', v_qty;
  END IF;

  DECLARE v_vis_old uuid := gen_random_uuid(); v_vis_new uuid := gen_random_uuid(); v_inv_old uuid := gen_random_uuid(); v_inv_new uuid := gen_random_uuid(); v_rx_mv uuid := gen_random_uuid(); v_comp_inv uuid; BEGIN INSERT INTO public.visits (id, patient_id, branch_id) VALUES (v_vis_old, v_pat_5, v_branch_a), (v_vis_new, v_pat_5, v_branch_a); INSERT INTO public.invoices (id, invoice_number, patient_id, visit_id, total_amount, net_amount, paid_amount, payment_status, branch_id, created_at) VALUES (v_inv_old, 'INV-P62-MV-OLD', v_pat_5, v_vis_old, 100.00, 100.00, 0.00, 'unpaid', v_branch_a, clock_timestamp() - interval '2 days'), (v_inv_new, 'INV-P62-MV-NEW', v_pat_5, v_vis_new, 100.00, 100.00, 0.00, 'unpaid', v_branch_a, clock_timestamp()); INSERT INTO public.prescriptions (id, patient_id, visit_id, status, dispensed_by, dispensed_at) VALUES (v_rx_mv, v_pat_5, v_vis_old, 'dispensed', v_pharm_a, clock_timestamp()); INSERT INTO public.prescription_items (id, prescription_id, medicine_id, medication_name, quantity, dispensed_quantity, unit_price, is_dispensed) VALUES (gen_random_uuid(), v_rx_mv, v_med_1, 'Amoxicillin 500mg', 2, 2, 25.00, true); INSERT INTO public.stock_movements (medicine_id, batch_id, movement_type, quantity, reference_id, reference_table, branch_id, created_by) VALUES (v_med_1, v_batch_valid, 'dispense', -2, v_rx_mv, 'prescriptions', v_branch_a, v_pharm_a); PERFORM public.cancel_dispense_before_handover(v_rx_mv, 'Multi-visit isolation regression', gen_random_uuid()); SELECT invoice_id INTO v_comp_inv FROM public.financial_compensations WHERE prescription_id = v_rx_mv; IF v_comp_inv IS DISTINCT FROM v_inv_old THEN RAISE EXCEPTION 'Expected older visit invoice %, got % (newer unrelated %)', v_inv_old, v_comp_inv, v_inv_new; END IF; END; RAISE NOTICE 'ALL PHASE 62 INTEGRATION TESTS PASSED';
END;
$$;

ROLLBACK;
