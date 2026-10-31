# Issue #142 — Storage entity/branch binding

**Date:** 2026-10-31  
**Status:** Phase 47 source candidate; not applied to QA or production.

## Finding and scope

The Phase 34 Storage boundary validates the branch prefix, bucket/path shape, and permission, but does not resolve the entity identifier in the path. A branch-A writer can therefore present a branch-A prefix with a syntactically valid branch-B entity identifier. This is a forged/misassociated or orphaned object-placement risk; it is not evidence of a demonstrated cross-branch read.

The candidate binds the third path segment to the authoritative row and verifies the row's parent branch before the restrictive Storage policy permits SELECT, INSERT, UPDATE, or DELETE.

## Bucket/entity inventory

| Private bucket | Path entity key | Authoritative row | Branch/parent contract |
| --- | --- | --- | --- |
| `roshan-lab-reports` | UUID | `public.lab_orders.id` | `lab_orders.branch_id` and the linked patient's branch must match the path. If `visit_id` is present, the visit must exist, be active, belong to the same patient, and resolve to the same branch. A legacy unlinked order is accepted only when its explicit order and patient branches match. |
| `roshan-medical-certificates` | Positive integer | `public.medical_certificates.id` | The table has no `branch_id`; the certificate must resolve to an active patient and active visit, the visit must belong to that patient, and the patient/visit branch (visit branch falling back to patient branch) must match the path. |
| `roshan-clinical-attachments` | UUID | `public.attachments.id` | At least one patient or visit parent must exist and be active. If both are present, the visit must belong to the same patient; every supplied parent must resolve to the path branch. |

The repository currently has direct uploader call sites for lab orders and medical certificates. No current uploader call site for the generic clinical-attachments bucket was found; its path contract is nevertheless mapped to the existing `attachments` table, which stores patient/visit linkage and a storage path.

## Source changes

- Adds `private.phase47_storage_entity_branch_matches(text,text)`, a narrowly scoped `STABLE SECURITY DEFINER` helper with an empty fixed `search_path`. It is not directly executable by `anon`, `authenticated`, or `service_role`; it is called only by the existing SECURITY DEFINER Storage boundary.
- Replaces `private.phase33_storage_access` without changing the existing bucket permission matrix. Every operation now requires both the caller's branch-prefix access and a live entity/parent row whose authoritative branch equals the prefix.
- Aligns client path validation with actual primary-key types: UUIDs for lab orders and attachments; positive 32-bit integer IDs for certificates. The certificate list previously read a non-existent `medical_certificates.branch_id`; it now selects the linked visit/patient branch and hides the uploader if those parent branches conflict. Client checks are usability guards only; database policy remains authoritative.
- Adds disposable PostgreSQL 17 tests for valid uploads in all three buckets, branch-A-prefix/branch-B-entity forgery (including privileged pre-existing forged objects on SELECT), missing entities, patient/visit mismatches, same-branch read visibility, UPDATE rebinding, and helper ACL/search-path properties.

## Verification and release boundary

Dedicated workflow: `.github/workflows/ci-phase47-storage-entity-branch-binding.yml`. It replays the canonical v112 PostgreSQL 17 baseline, Phase 34 Storage migration, existing Phase 33 assertions, the Phase 47 candidate, and the new Phase 47 assertions. It then runs the focused Node regression tests without an npm install.

This is a source/test candidate only. No production or QA SQL was executed, no Storage bucket configuration was changed, and no object or clinical record was created in a live project. Do not apply the candidate to QA or production without a separate explicit release authorization and the normal release gates.

## Next step

Review the exact PR head and require the dedicated PostgreSQL 17 workflow to pass. Keep Issue #95 open; clinical end-to-end acceptance remains deferred until the isolated free test environment and suitable synthetic doctor identity are available.
