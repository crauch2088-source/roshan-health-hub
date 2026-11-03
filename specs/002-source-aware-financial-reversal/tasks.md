# Tasks: Source-aware financial reversal

- [x] Inspect live payment, invoice and cashbox schema and existing reversal functions.
- [x] Identify nullable branch attribution and the missing `payments.updated_at` column.
- [x] Implement Phase54 and Phase54B forward migrations.
- [x] Add Phase54C branchless reversal guards and receipt-status RPC.
- [x] Add PostgreSQL 17 integration fixtures and assertions.
- [x] Merge PR #168 (Phase54).
- [x] Record/apply Phase54B in QA.
- [x] Merge Phase54C PR #171.
- [x] Apply Phase54C to QA and verify function ACL/search_path metadata.
- [ ] Finish Phase53 print UI and gate receipt printing on the status RPC.
- [ ] Apply Phase54/54B/54C to production only after encrypted backup and isolated restore proof.
- [ ] Re-run production/QA catalog fingerprint after the production cutover.
