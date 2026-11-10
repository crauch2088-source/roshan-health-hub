# Implementation Plan: Pharmacist-to-Prescriber Correction Workflow

**Branch**: `061-pharmacist-prescriber-correction` | **Date**: 2026-11-10 | **Issue**: #217

## Technical context

- React/TanStack Start, TypeScript, Supabase JS, PostgreSQL 17.
- Existing prescription creation: `create_prescription_atomic(uuid, boolean, jsonb)`.
- Existing dispensing: `fn_dispense_prescription_with_invoice(uuid, boolean)`; Phase 57/57B guards missing quantities, free-text items and external prescriptions.
- Phase 29 revoked direct browser DML on `prescriptions` and `prescription_items`; new writes must remain RPC-only.
- Parent fields include `prescribed_by`, `patient_id`, `visit_id`, `branch_id`, `is_external`, `status`; item fields include `medicine_id`, `medication_name`, `quantity`, `dose/dosage`, `frequency`, `duration`, `instructions`, `dosage_form`, `route`, `unit_price`, `is_dispensed`, `deleted_at`.

## Proposed architecture

### Tables
- `prescription_correction_requests`: immutable parent/item/patient/visit/branch/prescriber/requester linkage, idempotency key, reason, immutable item snapshot, controlled status and resolution metadata.
- `prescription_correction_events`: append-only lifecycle events with actor/time, before/after snapshots, disposition and replacement prescription id.
- Both tables: RLS enabled/forced; SELECT-only browser grants; no direct INSERT/UPDATE/DELETE/TRUNCATE; event mutation rejected by trigger.

### RPCs
- `create_prescription_correction_request(uuid, uuid, text, text, uuid)`: pharmacist request creation, server-derived context, same-branch and pending/internal/unlinked checks, idempotent by request UUID.
- `resolve_prescription_correction_request(uuid, text, uuid, jsonb)`: original prescriber replaces one item with an explicitly selected active medicine, or cancels and reissues a complete prescription; all operations atomic and snapshot-checked.
- `reject_prescription_correction_request(uuid, text)`: original prescriber rejects with required reason; no clinical/financial/inventory mutation.

### Authorization
- Create: active authenticated caller, `pharmacy.update`, branch access.
- Pharmacy read: `pharmacy.read` plus branch access.
- Prescriber read: `emr.read`, caller equals original `prescribed_by`, branch access.
- Resolve/reject: `emr.update` and caller equals original `prescribed_by`; admin/super-admin does not override clinical authorship.
- Cancel/reissue additionally requires `emr.create` and complete validated replacement payload.

### Atomicity
Lock request → prescription → item in a consistent order. Recheck status, soft-delete flags, branch/patient/visit linkage, item snapshot, medicine activity and dispensed state under lock. Unique request key plus partial unique open-request-per-item index. Any failure aborts all writes. Do not call dispense, invoice, payment or ledger functions.

## Constitution check

- Clinical authorship and data fidelity: PASS by explicit original-prescriber constraint.
- Least privilege and branch isolation: PASS by RPC-only writes, RLS and server-side checks.
- Auditability: PASS by immutable snapshots and append-only events.
- No inferred clinical content: PASS by exact catalogue selection.
- Production safety: PASS; disposable PostgreSQL 17 only.
- Test-first: mandatory before implementation.

## Pre-implementation verification

Confirm exact deployed/canonical column types, foreign keys, active-user helper, permission helper, branch helper, audit triggers and migration chronology. Do not assume field types from this plan. Do not rewrite Phase 57/57B history.
