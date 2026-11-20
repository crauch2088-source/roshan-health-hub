-- Phase 63 (RHH-03) integration tests: ledger-based inventory adjustments, expiry quarantine, write-off, price audit, immutability, RBAC/branch isolation, and reconciliation.

BEGIN;

DO $$
DECLARE
  v_branch_1 uuid := 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
  v_branch_2 uuid := 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
  v_user_b1  uuid := '11111111-1111-1111-1111-111111111111';
  v_user_b2  uuid := '22222222-2222-2222-2222-222222222222';
  v_med_id   uuid := '60000000-0000-0000-0000-000000000063';
  v_batch_1  uuid := '70000000-0000-0000-0000-000000000001';
  v_batch_2  uuid := '70000000-0000-0000-0000-000000000002';

  v_key_pos  uuid := '90000000-0000-0000-0000-000000000001';
  v_key_neg  uuid := '90000000-0000-0000-0000-000000000002';
  v_key_over uuid := '90000000-0000-0000-0000-000000000003';
  v_key_quar uuid := '90000000-0000-0000-0000-000000000004';
  v_key_qadj uuid := '90000000-0000-0000-0000-000000000005';
  v_key_qwo  uuid := '90000000-0000-0000-0000-000000000006';
  v_key_dwo  uuid := '90000000-0000-0000-0000-000000000007';
  v_key_pneg uuid := '90000000-0000-0000-0000-000000000008';
  v_key_pok  uuid := '90000000-0000-0000-0000-000000000009';
  v_key_unauth uuid := '90000000-0000-0000-0000-000000000010';
  v_key_xbr  uuid := '90000000-0000-0000-0000-000000000011';

  v_mov_1    uuid;
  v_mov_2    uuid;
  v_q_id     uuid;
  v_wo_1     uuid;
  v_wo_2     uuid;
  v_price_id uuid;
  v_qty      numeric;
  v_stock    integer;
  v_is_q     boolean;
  v_q_status text;
  v_wo_cnt   integer;
  v_price    numeric;
  v_rec      record;
BEGIN
  -- Seed users, medicine, two batches in branch 1, and initial receipt ledger movements
  INSERT INTO public.users (id, branch_id, active) VALUES
    (v_user_b1, v_branch_1, true),
    (v_user_b2, v_branch_2, true);

  INSERT INTO public.medicines (id, name, brand_name, generic_name, selling_price, stock_quantity, active, is_active)
  VALUES (v_med_id, 'Cefixime 400mg', 'Cefixime', 'Cefixime', 10.00, 50, true, true);

  INSERT INTO public.pharmacy_inventory (id, medicine_id, batch_number, expiry_date, quantity, quantity_remaining, quantity_received, branch_id)
  VALUES
    (v_batch_1, v_med_id, 'B63-ACTIVE', CURRENT_DATE + 180, 30, 30, 30, v_branch_1),
    (v_batch_2, v_med_id, 'B63-EXPIRED', CURRENT_DATE - 5, 20, 20, 20, v_branch_1);

  INSERT INTO public.stock_movements (medicine_id, batch_id, movement_type, quantity, reference_id, reference_table, notes, branch_id, created_by)
  VALUES
    (v_med_id, v_batch_1, 'receipt', 30, v_batch_1, 'pharmacy_inventory', 'Initial receipt B1', v_branch_1, v_user_b1),
    (v_med_id, v_batch_2, 'receipt', 20, v_batch_2, 'pharmacy_inventory', 'Initial receipt B2', v_branch_1, v_user_b1);

  -- Authenticate as Branch 1 pharmacist with pharmacy.read + pharmacy.update
  PERFORM set_config('test.user_id', v_user_b1::text, true);
  PERFORM set_config('test.super_admin', 'false', true);
  PERFORM set_config('test.perms', 'pharmacy.read,pharmacy.update', true);

  -- 1. Atomic positive stock adjustment (+10 on B1 -> 40, medicine -> 60)
  v_mov_1 := public.adjust_inventory_batch_atomic(v_batch_1, 10, 'Cycle count surplus', v_key_pos);
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_1;
  SELECT stock_quantity INTO v_stock FROM public.medicines WHERE id = v_med_id;
  IF v_qty <> 40 OR v_stock <> 60 THEN
    RAISE EXCEPTION 'Expected B1=40 and med=60 after +10 adjust, got B1=%, med=%', v_qty, v_stock;
  END IF;

  -- 2. Idempotency: repeating same key returns same movement_id without changing stock
  v_mov_2 := public.adjust_inventory_batch_atomic(v_batch_1, 10, 'Cycle count surplus', v_key_pos);
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_1;
  IF v_mov_2 <> v_mov_1 OR v_qty <> 40 THEN
    RAISE EXCEPTION 'Idempotent adjustment failed: mov1=%, mov2=%, qty=%', v_mov_1, v_mov_2, v_qty;
  END IF;

  -- 3. Atomic negative stock adjustment (-5 on B1 -> 35, medicine -> 55)
  PERFORM public.adjust_inventory_batch_atomic(v_batch_1, -5, 'Cycle count shrinkage', v_key_neg);
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_1;
  SELECT stock_quantity INTO v_stock FROM public.medicines WHERE id = v_med_id;
  IF v_qty <> 35 OR v_stock <> 55 THEN
    RAISE EXCEPTION 'Expected B1=35 and med=55 after -5 adjust, got B1=%, med=%', v_qty, v_stock;
  END IF;

  -- 4. Negative-stock rejection
  BEGIN
    PERFORM public.adjust_inventory_batch_atomic(v_batch_1, -100, 'Excessive deduction', v_key_over);
    RAISE EXCEPTION 'Expected negative_stock_not_permitted error';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '22023' OR SQLERRM NOT LIKE '%negative_stock_not_permitted%' THEN
      RAISE;
    END IF;
  END;

  -- 5. Expiry quarantine on B2: moves out of saleable stock separately from write-off, blocks further adjustment
  v_q_id := public.quarantine_expired_batch_atomic(v_batch_2, 'Expired batch removed from shelf', v_key_quar);
  SELECT quantity_remaining, is_quarantined INTO v_qty, v_is_q FROM public.pharmacy_inventory WHERE id = v_batch_2;
  SELECT stock_quantity INTO v_stock FROM public.medicines WHERE id = v_med_id;
  SELECT status INTO v_q_status FROM public.inventory_expiry_quarantine WHERE id = v_q_id;
  SELECT count(*) INTO v_wo_cnt FROM public.inventory_writeoffs WHERE batch_id = v_batch_2;
  IF v_qty <> 0 OR NOT v_is_q OR v_stock <> 35 OR v_q_status <> 'quarantined' OR v_wo_cnt <> 0 THEN
    RAISE EXCEPTION 'Quarantine state mismatch: qty=%, is_q=%, stock=%, q_status=%, wo_cnt=%', v_qty, v_is_q, v_stock, v_q_status, v_wo_cnt;
  END IF;

  BEGIN
    PERFORM public.adjust_inventory_batch_atomic(v_batch_2, 5, 'Should fail on quarantined batch', v_key_qadj);
    RAISE EXCEPTION 'Expected batch_is_quarantined error';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '22023' OR SQLERRM NOT LIKE '%batch_is_quarantined%' THEN
      RAISE;
    END IF;
  END;

  -- 6. Quarantined write-off on B2 (20 units, expired)
  v_wo_1 := public.record_inventory_writeoff_atomic(v_batch_2, 20, 'expired', 'Disposed expired batch', v_key_qwo);
  SELECT status INTO v_q_status FROM public.inventory_expiry_quarantine WHERE id = v_q_id;
  IF v_q_status <> 'written_off' OR v_wo_1 IS NULL THEN
    RAISE EXCEPTION 'Expected quarantine status written_off, got %', v_q_status;
  END IF;

  -- 7. Active-batch damaged write-off on B1 (5 units -> B1=30, med=30)
  v_wo_2 := public.record_inventory_writeoff_atomic(v_batch_1, 5, 'damaged', 'Broken vials during handling', v_key_dwo);
  SELECT quantity_remaining INTO v_qty FROM public.pharmacy_inventory WHERE id = v_batch_1;
  SELECT stock_quantity INTO v_stock FROM public.medicines WHERE id = v_med_id;
  IF v_qty <> 30 OR v_stock <> 30 OR v_wo_2 IS NULL THEN
    RAISE EXCEPTION 'Expected B1=30 and med=30 after damaged write-off, got B1=%, med=%', v_qty, v_stock;
  END IF;

  -- 8. Audited selling-price change + negative price rejection
  BEGIN
    PERFORM public.update_medicine_selling_price_atomic(v_med_id, v_branch_1, -1.00, 'Invalid price', v_key_pneg);
    RAISE EXCEPTION 'Expected selling_price_must_be_non_negative error';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '22023' OR SQLERRM NOT LIKE '%selling_price_must_be_non_negative%' THEN
      RAISE;
    END IF;
  END;

  v_price_id := public.update_medicine_selling_price_atomic(v_med_id, v_branch_1, 14.50, 'Supplier cost increase', v_key_pok);
  SELECT selling_price INTO v_price FROM public.medicines WHERE id = v_med_id;
  IF v_price <> 14.50 OR v_price_id IS NULL THEN
    RAISE EXCEPTION 'Expected selling_price=14.50, got %', v_price;
  END IF;

  -- 9. Append-only immutability on stock_movements, inventory_writeoffs, medicine_price_history
  BEGIN
    UPDATE public.stock_movements SET quantity = 999 WHERE id = v_mov_1;
    RAISE EXCEPTION 'Expected append-only trigger error on stock_movements UPDATE';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '55000' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM public.stock_movements WHERE id = v_mov_1;
    RAISE EXCEPTION 'Expected append-only trigger error on stock_movements DELETE';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '55000' THEN RAISE; END IF;
  END;

  BEGIN
    UPDATE public.inventory_writeoffs SET quantity = 1 WHERE id = v_wo_1;
    RAISE EXCEPTION 'Expected append-only trigger error on inventory_writeoffs UPDATE';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '55000' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM public.inventory_writeoffs WHERE id = v_wo_1;
    RAISE EXCEPTION 'Expected append-only trigger error on inventory_writeoffs DELETE';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '55000' THEN RAISE; END IF;
  END;

  BEGIN
    UPDATE public.medicine_price_history SET new_selling_price = 1.00 WHERE id = v_price_id;
    RAISE EXCEPTION 'Expected append-only trigger error on medicine_price_history UPDATE';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '55000' THEN RAISE; END IF;
  END;
  BEGIN
    DELETE FROM public.medicine_price_history WHERE id = v_price_id;
    RAISE EXCEPTION 'Expected append-only trigger error on medicine_price_history DELETE';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '55000' THEN RAISE; END IF;
  END;

  -- 10. Unauthorized role denial (missing pharmacy.update / pharmacy.read)
  PERFORM set_config('test.perms', 'pharmacy.read', true);
  BEGIN
    PERFORM public.adjust_inventory_batch_atomic(v_batch_1, 1, 'Unauthorized adjust', v_key_unauth);
    RAISE EXCEPTION 'Expected inventory_adjust_permission_denied';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '42501' THEN RAISE; END IF;
  END;

  PERFORM set_config('test.perms', '', true);
  BEGIN
    PERFORM * FROM public.reconcile_medicine_stock_ledger(v_med_id, v_branch_1);
    RAISE EXCEPTION 'Expected inventory_reconcile_permission_denied';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '42501' THEN RAISE; END IF;
  END;

  -- 11. Cross-branch denial (Branch 2 user attempting operations on Branch 1)
  PERFORM set_config('test.user_id', v_user_b2::text, true);
  PERFORM set_config('test.perms', 'pharmacy.read,pharmacy.update', true);
  BEGIN
    PERFORM public.adjust_inventory_batch_atomic(v_batch_1, 1, 'Cross-branch adjust', v_key_xbr);
    RAISE EXCEPTION 'Expected branch_access_denied for adjust';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '42501' OR SQLERRM NOT LIKE '%branch_access_denied%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.update_medicine_selling_price_atomic(v_med_id, v_branch_1, 20.00, 'Cross-branch price', v_key_xbr);
    RAISE EXCEPTION 'Expected branch_access_denied for price update';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '42501' OR SQLERRM NOT LIKE '%branch_access_denied%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM * FROM public.reconcile_medicine_stock_ledger(v_med_id, v_branch_1);
    RAISE EXCEPTION 'Expected branch_access_denied for reconcile';
  EXCEPTION WHEN OTHERS THEN
    IF SQLSTATE <> '42501' OR SQLERRM NOT LIKE '%branch_access_denied%' THEN RAISE; END IF;
  END;

  -- 12. Reconcile medicine stock ledger as Branch 1 user
  PERFORM set_config('test.user_id', v_user_b1::text, true);
  SELECT * INTO v_rec FROM public.reconcile_medicine_stock_ledger(v_med_id, v_branch_1);
  IF v_rec.batch_sum <> 30 OR v_rec.ledger_net <> 30 OR NOT v_rec.is_balanced THEN
    RAISE EXCEPTION 'Reconciliation mismatch: batch_sum=%, ledger_net=%, is_balanced=%',
      v_rec.batch_sum, v_rec.ledger_net, v_rec.is_balanced;
  END IF;
END $$;

ROLLBACK;
