# Roshan feature specifications

Each non-trivial feature uses a numbered directory: specs/NNN-short-name/.

- spec.md records user journeys, scope, functional requirements, edge cases, and measurable acceptance criteria.
- research.md, data-model.md, contracts/, and quickstart.md are added only when the feature needs them.
- plan.md is written only after requirements are sufficiently clarified and existing code/database contracts have been inspected.
- tasks.md is derived from the accepted specification and plan. Every task identifies the files/behavior it changes and evidence that proves completion.
- Reviewer checklists assess requirement quality; they are not implementation-completion checkboxes.

Do not copy the full project roadmap into a feature directory. Link to the relevant phase in docs/MASTER_PLAN.md. Keep real patient, clinical, financial, identity, credential, and production data out of specifications and examples; use synthetic fixtures only.

The first pilot is 001-clinical-document-printing. It remains Draft and must not be implemented until its listed clarifications are resolved.
