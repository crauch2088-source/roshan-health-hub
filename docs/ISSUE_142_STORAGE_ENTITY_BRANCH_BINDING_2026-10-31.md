# Issue #142 — Storage entity/branch binding

**Date:** 2026-10-31  
**Status:** Phase 48 source candidate; not applied to QA or production.

## Finding and scope

The Phase 34 Storage boundary validates the branch prefix, bucket/path shape, and permission, but does not resolve the entity identifier in the path. A branch-A writer can therefore present a branch-A prefix with a syntactically valid branch-B entity identifier. This is a forged/misassociated or orphaned object-placement risk; it is not evidence of a demonstrated cross-branch read.

The forward-only Phase 48 candidate binds the supported lab-order and medical-certificate path identifiers to authoritative rows and checks the actual parent branch before the restrictive Storage policy permits SELECT, INSERT, UPDATE, or DELETE.

## Bucket/entity inventory

| Private bucket | Current status | Authoritative contract |
| --- | --- | --- |
| `roshan-lab-reports` | Supported | Path UUID resolves to `public.lab_orders.id`; order and active patient branches must match. If `visit_id` is present, the visit must exist, be active, belong to the same patient, and have `visit.branch_id = path branch`. Legacy unlinked orders remain valid only when the explicit order and patient branches match. |
| `roshan-medical-certificates` | Supported | Path segment is a positive 32-bit integer resolving to `public.medical_certificates.id`. The certificate, patient, and required visit must be active; visit patient must equal certificate patient; both patient and visit branches must equal the path branch. There is no branch fallback for a branchless visit. |
| `roshan-clinical-attachments` | **Fail-closed / unsupported** | Repository search found no active uploader call site and no approved entity contract. The bucket remains denied for every Storage action, even when a same-branch `attachments` row exists. Do not infer that the generic `attachments` table is an approved object-key contract. |

## Source changes

- Adds `private.phase48_storage_entity_branch_matches(text,text)`, a narrowly scoped `STABLE SECURITY DEFINER` helper with an empty fixed `search_path`. It is not directly executable by `anon`, `authenticated`, or `service_role`; it is called only by the existing SECURITY DEFINER Storage boundary.
- Replaces `private.phase33_storage_access` without changing the existing permission matrix. Supported lab/certificate operations require both branch-prefix access and a live entity/parent row whose authoritative branch equals the prefix. The generic clinical-attachments bucket returns false before permission evaluation.
- Removes the unsupported generic-attachments bucket from the typed client upload helper. The Phase 34 bucket itself remains private, but no typed upload path can target it.
- The certificate list/uploader derives branch from its linked visit/patient rather than reading the non-existent `medical_certificates.branch_id`; conflicting parent branches hide the uploader. Client checks are usability guards only; database policy remains authoritative.
- Disposable PostgreSQL 17 assertions cover matching-branch lab/certificate uploads, forged branch-A-prefix/branch-B-entity paths, missing entities, mismatched parent links, read visibility, UPDATE rebinding, helper ACL/search-path, and explicit denial of an otherwise valid generic attachment row and pre-existing objects.

## Verification and release boundary

- **Test-first source regression:** the Phase 48 source guard failed against the prior Phase 47 candidate before correction (3/4 focused assertions passed). An initial exact-head lint run then caught one Prettier wrapping error; commit `355d24c04afc333ea8d2848131efbcb87eb38fff` fixed it.
- **Exact-head Phase 48 PostgreSQL 17: PASS** — PR #148 current head `1cd9f71bbb769615ba702e836d4620810480e504` (code-bearing commit `355d24c04afc333ea8d2848131efbcb87eb38fff`), run [41180748822](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41180748822), job `124477494190`; canonical v112 baseline + Phase 34 + Phase 33 assertions + Phase 48 candidate/assertions; 15/15 focused source tests passed.
- **Exact-head aggregate CI: PASS** — run [41180748870](https://github.com/crauch2088-source/roshan-health-hub/actions/runs/41180748870), job `124477494519`; Node 22 lockfile install, role-guard tests, typecheck, lint, and build passed. Production dependency audit found 0 vulnerabilities. The complete dependency tree still reports 14 moderate development-tree `minimatch <11.0.1` advisories; the current gate blocks high/critical in the complete tree but does not claim these moderate findings are fixed.
- Exact-head PR checks: **27 success, 1 intentionally skipped, 0 failures**. The skipped authenticated clinical acceptance job remains deferred by design. Local Node 24 regressions passed 4/4 and 11/11; a temporary full guard attempt was 220/221 because the shell lacked installed `zod`, so GitHub Actions is authoritative for the dependency-complete run.
- No QA or production SQL was executed, no Storage configuration or bucket visibility was changed, and no object or clinical/financial record was created in a live project. PR #148 remains draft/open pending independent review and separate release authorization.

## Next step

Obtain independent review of the Phase 48 candidate and assess the separate release gate. Keep Issue #95 open; authenticated clinical E2E remains deferred until the isolated free test environment and suitable synthetic doctor identity are available. Resolve the remaining moderate development-tree minimatch advisories separately and without forced major downgrades. Do not apply this candidate to QA or production without separate explicit authorization and the normal release gates.
