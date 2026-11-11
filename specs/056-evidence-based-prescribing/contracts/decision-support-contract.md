# Medication Engine Contract

Engineering contract only; not a clinical guideline.

## Arithmetic input
Typed basis: fixed mg, mg/kg/dose, or mg/kg/day. All values are mg and kg. dosesPerDay is explicit. Weight-based calculations require a current encounter-linked weight. Optional rounding is source-defined.

## Result
- calculated: per-dose mg, daily mg, uncapped per-dose mg, applied ceiling(s), rounding flag.
- needs_data: encounter weight absent.
- invalid: malformed/non-finite rule values, invalid weight, arithmetic overflow, unsafe rounding.

## Invariants
1. Fixed dose does not require weight; weight-based dose always does.
2. No historical or patient-master weight fallback.
3. mg/kg/dose and mg/kg/day use separate formulas.
4. Frequency is protocol-supplied, never inferred.
5. Per-dose and per-day ceilings are separate.
6. Daily ceiling is divided by explicit dosesPerDay only.
7. Rounding cannot exceed a configured ceiling.
8. No DB, network, AI, clock or mutable state in the arithmetic kernel.
9. Kernel does not select medicine, indication, route, frequency, duration, concentration, volume or monitoring.
10. A calculation is not a recommendation; only a separately approved matched protocol may recommend.

## Future protocol outcomes
recommendation, needs_data, no_match, blocked.

## Lifecycle
draft → reviewed → approved → active → suspended/retired. Expired or unreviewed versions are never matchable.
