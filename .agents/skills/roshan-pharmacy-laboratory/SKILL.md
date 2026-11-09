---
name: roshan-pharmacy-laboratory
description: Use for Roshan pharmacy inventory, medicine catalogue, prescriptions, dispensing, batches/expiry, laboratory orders, results, verification, and related workflows.
---

# Roshan Pharmacy and Laboratory

## Pharmacy contracts
- Separate medicine identity, stock quantity, batches, packaging units, dispensing route, and prescription directions.
- Catalogue identity must reflect the physical pack and remain unverified until an authorized person checks it.
- Never invent ingredient, brand, strength, dosage form, route, unit conversion, price, or product authenticity.
- Preserve atomic stock receipt/dispense and invoice behavior, idempotency, batch traceability, expiry controls, audit history, and branch ownership.
- Browser clients must not update aggregate stock outside approved transactional RPC boundary.
- Catalogue entries are not prescribing protocols and do not authorize dose/frequency/duration auto-fill.

## Laboratory contracts
- Preserve order-to-visit-to-patient-to-branch linkage.
- Distinguish uncollected, pending, partially saved, completed, verified, cancelled, abnormal, and critical states.
- Zero is a valid numeric result, not empty.
- Preserve numeric, textual, coded, and qualitative results with units/ranges and explicit abnormal/critical flags.
- Use approved verification RPC; never bypass with direct table writes.
- Preserve partial save, retry, idempotency, and audit behavior.

Test role/permission boundaries, branch mismatch, duplicates, partial failure/retry, invalid quantities/batches, malformed catalogue fields, empty versus zero, critical results, and prohibited direct writes. Use synthetic fixtures only.
