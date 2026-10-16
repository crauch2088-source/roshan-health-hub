# Roshan Health Hub — 40-item redesign and clinical workflow batch

**Branch:** `redesign/clinical-workflows-40-item-batch`
**Status:** temporary execution plan; no production deployment or main-branch merge implied.

## Research basis and design constraints
- The 2025 ONC SAFER Guides emphasize high-priority EHR practices, computerized order entry/decision support, and test-result reporting/follow-up: https://healthit.gov/clinical-quality-and-safety/safer-guides
- ONC frames EHR usability as a clinical safety concern, not merely visual polish: https://healthit.gov/usability-and-provider-burden/
- Vercel documents plan-specific build/deployment limits; do not spam retries while quota is exhausted: https://vercel.com/docs/limits
- Supabase's current security changelog is a reference for auth/Data API changes: https://supabase.com/changelog?tags=security

Principles: preserve permission gates and atomic RPCs; never auto-invent clinical doses; never imply an unmeasured vital is normal; preserve Arabic RTL and English LTR; test mobile, keyboard, error/loading states, and duplicate-submit safety. Unproven items stay pending.

## 40 deliverables

### A. Design system and navigation
1. [x] Refresh semantic colors to a stronger teal/ink palette while preserving light/dark tokens.
2. [x] Increase design-system corner radius for a contemporary clinical workspace.
3. [x] Add a subtle low-contrast clinical canvas gradient.
4. [x] Add shared surface, patient-context, field-label and tab classes.
5. [x] Add restrained page-enter motion with reduced-motion override.
6. [x] Improve shell spacing and widen the working canvas.
7. [x] Give the global header clearer hierarchy, softer surface and backdrop blur.
8. [x] Refine desktop rail contrast, active item affordance and target height.
9. [x] Refine mobile bottom navigation surface and safe-area treatment.
10. [x] Add responsive/safe-area source regression guards; actual phone screenshots remain a release gate.
11. [x] Add regression guards for keyboard tab behavior, semantic selected state and visible focus; live keyboard QA remains a release gate.
12. [x] Add regression guards for dark semantic tokens, reduced motion and print styles; screenshot QA remains a release gate.

### B. Consultation workflow
13. [x] Make consultation tabs bilingual rather than Arabic-only in English mode.
14. [x] Add semantic tablist/tab/tabpanel roles and selected state.
15. [x] Add arrow/Home/End keyboard navigation.
16. [x] Upgrade patient context into a clear clinical banner.
17. [x] Surface the visit number prominently.
18. [x] Improve MRN, age/sex, department and doctor hierarchy.
19. [x] Preserve MRN LTR rendering inside RTL screens.
20. [x] Add a tested unsaved-note warning before leaving consultation, including a browser beforeunload warning and explicit discard confirmation when changing consultation tabs.
21. [x] Add a collapsed, optional clinical review checklist that is explicitly local-only and never blocks emergency care.
22. [x] Add automated consultation workflow regression coverage for accessible tabs, unsaved-note warnings and the optional review checklist; full browser E2E remains a release gate.

### C. Laboratory workflow
23. [x] Debounce catalogue search to reduce requests during typing.
24. [x] Sanitize debounced search before composing the PostgREST filter.
25. [x] Show a dedicated catalogue-loading state.
26. [x] Show a clear catalogue-error state and explain that no order was submitted.
27. [x] Keep search/category controls responsive and category counts visible.
28. [x] Expose selected state via aria-pressed.
29. [x] Show estimated subtotal for selected tests before submission.
30. [x] Improve selected-test summary hierarchy and desktop sticky placement.
31. [x] Give removal controls bilingual accessible names.
32. [x] Add clinical-justification reminder for urgent priority.
33. [x] Disable order submission when patient is unresolved or catalogue errors exist.
34. [x] Preserve idempotency key and atomic order+invoice RPC.
35. [x] Add a bilingual, accessible five-stage laboratory worklist progress indicator derived from the existing persisted order status; no schema mutation.
36. [x] Add abnormal-result review warning and require explicit acknowledgement before verifying out-of-range results; block verification while results are unsaved. Critical-value escalation remains separate because the schema has no governed critical flag/thresholds.

### D. Prescription safety and correctness
37. [x] Add pure validation for empty prescriptions, missing drug/dose/frequency/duration and invalid quantities.
38. [x] Enforce prescription completeness before existing atomic RPC.
39. [x] Add bilingual safety text: no automatic dosing; clinician verifies age, weight, allergies, renal function and guidance.
40. [x] Add pediatric age/weight safety warnings with distinct messages for missing versus unverifiable current weight; do not calculate or infer doses. Medicine-specific dose libraries remain blocked on clinical governance.

## Verification status
- Automated source/pure-logic regression file is included in test:guard. Final CI run 38982527057 passed all 10 jobs on commit c24dbfb; this documentation-only refresh should pass CI again before merge.
- Completed in code: 40/40 checklist items with source/pure-logic regression coverage. Remaining release gates are actual device/browser screenshots (RTL/LTR and dark/light/print), live screen-reader/keyboard review, full synthetic-data E2E, clinician review of pediatric safety wording, and a current preview deployment. These are not claimed completed merely because code tests pass.
- Feature branch only: no database migration, production SQL mutation, merge, or deployment.