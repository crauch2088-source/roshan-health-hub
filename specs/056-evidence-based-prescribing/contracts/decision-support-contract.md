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


## Scope matching extension

A protocol and encounter context must both carry explicit population and jurisdiction. The cited source's setting, population and jurisdiction must exactly match the protocol. Missing context blocks; a different explicit population or jurisdiction produces no match. The matcher does not infer these dimensions from age or free text.

## Runtime input validation

The arithmetic kernel accepts only positive safe-integer doses-per-day counts. It rejects null/malformed input, basis and rounding payloads without throwing. Interval-based schedules require a future explicit interval model.


## Rounding precision

Rounding uses decimal coefficient/scale arithmetic so binary floating-point representation does not invert upward/downward direction near an increment boundary. The minimum supported increment is 1e-10 mg, matching the kernel output precision; smaller increments are rejected. Interval schedules and unit conversions remain out of scope.


Configured rounding increments and safety ceilings must align with the kernel's 1e-10 mg output precision. The engine rejects finer precision instead of normalising a cap or increment into a different value. Safety-ceiling comparisons are strict; no epsilon overshoot is permitted.


## Local guideline precedence and source classes

For malaria in Sudan, a Federal MoH/NMCP statement surfaced in September 2026 reiterates the 2023 National Malaria Diagnosis and Treatment Protocol as the only approved national reference until an official update. WHO global malaria guidance updated 10 September 2026 is a comparison and surveillance source; it must not silently override the Sudan national protocol. A conflict blocks activation pending an explicit national update/adoption decision and GP/pharmacist review.

Keep treatment guidelines distinct from formulary/product-registration records, medicine shortage notices and observational studies. Only a verified treatment guideline can support a regimen; product identity requires verified registration/label evidence; shortage notices only inform supply availability.
