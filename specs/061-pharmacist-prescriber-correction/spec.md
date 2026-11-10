# Feature Specification: Pharmacist-to-Prescriber Correction Workflow

**Feature Branch**: `061-pharmacist-prescriber-correction`  
**Created**: 2026-11-10  
**Status**: Draft — implementation not yet started  
**Input**: Issue #217.

## Problem

A free-text medication is a valid clinical prescribing record, but it is not an inventory identity. Pharmacy must not guess its catalogue equivalent, silently omit it, or convert it into stock. The pharmacist needs a durable way to request clarification from the responsible prescriber; the prescriber needs a traceable way to correct or replace the order.

This is a communication/correction workflow only. It must not weaken Phase 57/57B dispensing guards, create stock movements, invoices, invoice items, payments, cashbox entries, or ledger rows.

## User stories and acceptance criteria

### US1 — Pharmacist requests correction (P1)
A pharmacist reviewing a saved, pending, internal prescription sees an active item with `medicine_id IS NULL`, opens a request against that exact item, selects a reason and submits an explanation.

- The database derives prescription, patient, visit, branch, prescriber, requester, item snapshot and timestamp; the client cannot supply or override those identities.
- Same request UUID + same payload is idempotent. A second open request for the same item is rejected deterministically.
- External, cancelled, dispensed, deleted, wrong-branch, linked or soft-deleted records are rejected.
- The request itself changes no prescription, inventory or financial state.

### US2 — Original prescriber reviews and corrects (P1)
The original `prescribed_by` doctor sees open requests for prescriptions they authored, inspects the saved item snapshot, and explicitly selects an active catalogue medicine.

- Only the original prescriber with `emr.update` and matching branch may resolve or reject.
- Another doctor in the same branch is denied. Pharmacists cannot resolve. Admin/super-admin status alone does not confer prescribing authority; the caller must equal the original prescribed_by identity and their assigned users.branch_id must equal the prescription branch.
- Replacement uses an explicit medicine UUID; no fuzzy matching or automatic substitution.
- The RPC locks and revalidates the request, prescription and item; stale state fails closed.
- Item regimen (quantity, dose, frequency, duration, instructions, route) is preserved unless a separately specified clinical edit is explicitly approved.
- Before/after snapshots, actor, server timestamp and disposition are retained in append-only events.

### US3 — Cancel and reissue a complete order (P1)
When the original prescriber chooses not to edit the item in place, they can cancel the old pending order and create a complete replacement order atomically.

- The replacement payload must contain the complete intended order, not only the changed item.
- Invalid/empty payload or a concurrent dispense/resolution rolls back both cancellation and replacement.
- Original prescription and request history remain auditable.

### US4 — Read in correct context (P1)
- Pharmacy readers require `pharmacy.read` and branch access.
- Prescriber readers require `emr.read`, matching `prescribed_by`, and branch access.
- Other doctors cannot enumerate requests merely because they share a branch. Super-admin branch bypass must not apply: assigned branch equality is mandatory.
- Request/event tables have RLS enabled and forced; browser roles have no direct write grants.

## Invariants

1. Request, reject and replace actions never mutate stock, batches, stock movements, invoices, invoice items, payments, cashbox or ledger.
2. Existing fail-closed dispensing checks remain authoritative in both UI and SQL.
3. External prescriptions remain ineligible for internal pharmacy dispensing and correction.
4. Request snapshot is immutable; event history is append-only.
5. All writes use narrow SECURITY DEFINER RPCs with empty `search_path`, explicit permission/authorship/branch checks, server-derived identities and row locks.
6. No direct browser DML on clinical or correction tables.
7. No Production or hosted QA migration in this feature PR.

## Exclusions

No chat subsystem, autonomous clinical recommendation, dose calculation, diagnosis, fuzzy matching, pharmacist editing, silent item deletion, or stock/financial transaction.

## Definition of done

Spec and contracts reviewed; failing tests written first; PostgreSQL 17 tests cover roles, branch isolation, stale state, duplicate/idempotency, concurrency, cancel-and-reissue and zero side effects; unit and browser tests cover mobile/desktop RTL/LTR; full CI passes on exact head; authenticated synthetic QA pharmacist and original-prescriber acceptance completed; independent security review completed.
