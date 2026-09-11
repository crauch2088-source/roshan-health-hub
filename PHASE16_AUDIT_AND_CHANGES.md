# Phase 16 — Production Readiness Audit & Hardening

## 1. Full audit summary

Audited the latest GitHub ZIP as the only source of truth across routes, navigation, permissions, clinical/financial/pharmacy workflows, mobile UI primitives, i18n, and shared components.

### Already correct (left alone)

- Central `NAV_GROUPS` / `flatNavItems()` driving NavRail, mobile More menu, and Command Palette
- Clinic present in nav with `visits.read` (post–12.1 real fix)
- PatientPicker: modal Popover, measured width, `pointer-events-auto` on portaled layers
- New Visit Selects: empty string avoided via conditional `value` spread
- Finance mutations via atomic RPCs (`post_invoice_payment`, `post_cashbox_entry`, `post_supplier_*`, `fn_dispense_prescription`)
- Consultation invoice create checks existing `visit_id` before insert
- Pharmacy FEFO via server RPC
- `useSave` fail-closed toasts on error
- Auth `can()` fail-closed until permissions ready; super_admin bypass
- Patient chart timeline + visits/labs/rx/invoices tabs
- Shared kit: `PermissionGate`, `Forbidden`, `Empty`, `Loading`, `ErrorBox`

### Critical findings fixed

| ID | Severity | Finding |
|----|----------|---------|
| C1 | **Critical** | 14 authenticated routes had **no** `PermissionGate` — nav hide only. Direct URL access to billing, finance, clinic, patient chart, users, settings, etc. |
| C2 | **High** | **Finish visit** set `visits.status=completed` but did **not** complete related `queue_tickets` → queue still showed waiting/called/in_progress |

### Medium / low (not changed or minor)

| ID | Severity | Notes |
|----|----------|-------|
| M1 | Medium | Expenses and Finance both used `Wallet` icon → expenses → `Banknote` |
| M2 | Low | ConsultationPage still densely formatted / some inline bilingual strings (pre-existing; only finish message normalized) |
| M3 | Low | Mobile primary strip is dashboard/patients/visits/pharmacy (queue/clinic in More) — intentional, not broken |
| L1 | Info | Queue ticket **creation** still depends on live DB trigger (not in repo SQL) |
| L2 | Info | No `npm run typecheck` / `build` in this sandbox |

---

## 2. What was already correct

- Dialog/Popover/Select z-index + `pointer-events-auto` stack from Phase 12.1 real fix
- Clinical path Patients → New Visit → Visits list → Clinic link
- Patient preselect via `?patient=`
- Debounced server-side patient search
- RLS remains the real data boundary; this phase adds UI-route gates only

---

## 3–4. Critical findings & root causes

### C1 — Missing PermissionGate on routes

**Root cause:** Incremental modules shipped page UI and nav perm filters, but many route components never wrapped with `PermissionGate`. Navigation is not security.

**Fix:** Outer wrapper pattern on each ungated page:

```tsx
function XPage() {
  return (
    <PermissionGate perm="…">
      <XPageInner />
    </PermissionGate>
  );
}
```

| Route | Permission |
|-------|------------|
| `/clinic`, `/clinic/$visitId` | `visits.read` |
| `/billing`, `/billing/$invoiceId` | `billing.read` |
| `/finance` | `cashbox.read` |
| `/accounting`, `/expenses` | `accounting.read` |
| `/partners` | `partners.read` |
| `/inventory` | `pharmacy.read` |
| `/lab-catalog` | `lab_admin.read` |
| `/lab/$orderId` | `lab.read` |
| `/patients/$patientId` | `patients.read` |
| `/users` | `users.read` |
| `/settings` | `settings.read` |
| `/audit` | `audit.read` |

No new permission codes. Matches existing nav + seed modules.

### C2 — Finish visit left queue stale

**Root cause:** `ConsultationPage` finish mutation only updated `visits`. Queue actions update `queue_tickets` independently.

**Fix:** On finish, also set open tickets for that `visit_id` to `completed` (only statuses `waiting` \| `called` \| `in_progress`), invalidate `["queue"]`, bilingual success toast.

---

## 5. Exact files modified

- `src/routes/_authenticated/clinic.tsx`
- `src/routes/_authenticated/clinic_.$visitId.tsx`
- `src/routes/_authenticated/billing.tsx`
- `src/routes/_authenticated/billing_.$invoiceId.tsx`
- `src/routes/_authenticated/finance.tsx`
- `src/routes/_authenticated/accounting.tsx`
- `src/routes/_authenticated/expenses.tsx`
- `src/routes/_authenticated/partners.tsx`
- `src/routes/_authenticated/inventory.tsx`
- `src/routes/_authenticated/lab-catalog.tsx`
- `src/routes/_authenticated/lab_.$orderId.tsx`
- `src/routes/_authenticated/patients_.$patientId.tsx`
- `src/routes/_authenticated/users.tsx`
- `src/routes/_authenticated/settings.tsx`
- `src/routes/_authenticated/audit.tsx`
- `src/features/clinic/consultation/ConsultationPage.tsx`
- `src/config/nav.ts` (expenses icon only)

---

## 6. Exact changes made

1. PermissionGate wrappers + kit imports on all previously ungated authenticated feature routes listed above.
2. Finish-visit also completes related queue tickets and invalidates queue queries.
3. Expenses nav icon: `Wallet` → `Banknote` (icon already in `nav-icons.tsx`).

---

## 7. Database changes

**None.** No migrations. Queue update uses existing `queue_tickets` columns already used by the Queue page.

---

## 8. Security / permission findings

- UI routes now fail-closed like modules that already used PermissionGate.
- RLS unchanged; still authoritative for data access.
- Super admin still `can() === true` for all codes.
- Reception can open Clinic list/consultation via `visits.read` (consistent with nav); writing clinical notes still constrained by emr RLS on clinical tables.

---

## 9. Patient workflow verification (static)

Patients → search → New Visit (`?patient=`) → department/doctor/type → Save → visit insert (+ optional invoice) → queue (DB trigger) → Clinic / queue Clinic link → consultation → Finish (visit + queue ticket completed) → patient chart timeline shows visits/labs/rx/invoices.

Identity keys used in code: `patient_id`, `visit_id`, `invoices.visit_id`, lab orders / prescriptions tied in existing queries.

---

## 10. Clinic workflow verification (static)

- `/clinic` gated `visits.read`
- `/clinic/$visitId` gated; loads visit + patient + dept + doctor
- Invoice surface with anti-duplicate check
- Finish syncs queue
- Queue row still links to clinic

---

## 11. Financial integrity verification (static)

- Payments/cashbox/supplier paths use RPCs (no multi-step client-only money moves introduced)
- No change to posting logic this phase

---

## 12. Mobile audit results

- Prior 12.1 real fixes for pointer-events / PatientPicker / Select empty values remain in tree
- No new nested-portal regressions introduced
- Touch targets / tables: pre-existing compact tables with horizontal scroll left as-is (working pattern)

---

## 13. Performance findings

- Patient search remains debounced server-side
- No large unpaginated patient fetches added
- No speculative memoization pass

---

## 14. i18n findings

- Finish toast now AR/EN via `lang` (was AR-only hardcoded)
- No new duplicate keys
- Many screens still mix `t()` and inline `lang === "ar"` (pre-existing; not bulk-rewritten)

---

## 15. Build / typecheck

Not executed: no `node_modules` / network install in this environment.

---

## 16. Remaining limitations

1. Live mobile browser verification still required after deploy.
2. Queue **ticket creation** on visit insert still assumes live DB trigger.
3. ConsultationPage file remains minified-style; functional only this phase.
4. RLS policies not re-audited against live Supabase (tools not used this session).

---

## 17. Phase 17 (only if needed)

Optional later: (a) live RLS policy review, (b) consultation page readability refactor without behavior change, (c) mobile primary nav A/B for Queue vs Pharmacy. Not required for Phase 16 closure.
