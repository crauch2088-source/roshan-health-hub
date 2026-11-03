# Tasks: Clinical parent-link and private helper ACL reconciliation

- [x] Compare production and QA Phase36 function definitions.
- [x] Identify missing production `order_id` immutability check.
- [x] Identify QA-only PUBLIC EXECUTE grants on private helpers.
- [x] Implement forward-only Phase55 migration.
- [x] Add legacy-drift PostgreSQL 17 fixture and assertions.
- [x] Add targeted PostgreSQL 17 workflow.
- [ ] Complete full CI and merge PR #172.
- [ ] Apply Phase55 to QA and verify catalog/advisors.
- [ ] Apply Phase55 to production only after backup/restore proof.
