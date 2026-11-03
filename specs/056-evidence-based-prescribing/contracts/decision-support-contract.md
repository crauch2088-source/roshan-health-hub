# Clinical Decision Support Contract (proposed)

**Status:** conceptual TypeScript contract; names may be adapted to repository conventions after design review. No endpoint or database RPC is implemented by this document.

## Input

```ts
type KnowledgeStatus = "known" | "unknown" | "not_present" | "stale";

type PatientContext = {
  patientId: string;
  visitId: string;
  ageAtEncounter: { value: number; unit: "days" | "months" | "years" } | null;
  gestationalAgeDays?: number | null;
  currentWeight?: { value: number; unit: "kg"; measuredAt: string; vitalId: string } | null;
  allergyStatus: KnowledgeStatus;
  allergyIds: string[];
  activeMedicationIds: string[];
  diagnosisIds: string[];
  renalContext?: { status: KnowledgeStatus; eGFR?: number; measuredAt?: string };
  hepaticContext?: { status: KnowledgeStatus; severity?: string };
  pregnancyStatus?: KnowledgeStatus;
  lactationStatus?: KnowledgeStatus;
};

type PrescribingRequest = {
  selectedProductId: string;
  confirmedIndicationId: string;
  context: PatientContext;
  requestedSetting: "outpatient" | "emergency" | "inpatient" | "referral";
  at: string;
};
```

## Output

```ts
type EvaluationResult =
  | { status: "recommendation"; recommendation: RegimenDraft; provenance: RuleProvenance; matchedFacts: string[]; alerts: SafetyAlert[] }
  | { status: "needs_data"; missing: { field: string; reason: string }[]; alerts: SafetyAlert[] }
  | { status: "no_match"; reason: string }
  | { status: "blocked"; blockers: SafetyAlert[] };

type DoseBasis =
  | { kind: "fixed"; amount: number; unit: string }
  | { kind: "per_kg_per_dose"; amountPerKg: number; unit: string; maxPerDose?: Quantity }
  | { kind: "per_kg_per_day"; amountPerKgPerDay: number; unit: string; maxPerDay?: Quantity }
  | { kind: "per_m2_per_dose"; amountPerM2: number; unit: string; maxPerDose?: Quantity };

type RegimenDraft = {
  dose: Quantity;
  doseBasis: DoseBasis;
  route: string;
  frequency: string;
  intervalHours?: number;
  duration?: { value: number; unit: "hours" | "days" | "weeks" };
  maxPerDose?: Quantity;
  maxPerDay?: Quantity;
  instructions?: string;
  roundingRule: string;
  concentration?: Quantity;
  volumePerDose?: Quantity;
};

type SafetyAlert = {
  ruleId: string;
  severity: "hard_stop" | "acknowledge" | "information";
  title: string;
  rationale: string;
  action: string;
  sourceIds: string[];
  overrideAllowed: boolean;
};
```

## Contract invariants
- Evaluator is pure/deterministic; no network, model or DB mutation inside dose calculation.
- All numeric values include units; no implicit mg/mL, mg/kg or frequency conversions.
- `per_kg_per_dose` and `per_kg_per_day` are distinct types and distinct calculation paths.
- A protocol must be active, current, source-backed, reviewed and match all required predicates.
- Unknown/stale/missing required data returns `needs_data`; it never silently falls back to normal.
- The result carries protocol/source version and matched facts so the prescriber can independently review the recommendation.
- The prescriber must explicitly accept/edit the draft; saving a recommendation is not automatic.
- Safety evaluation runs against both existing active medications and all items in the current draft.
- No clinical rule may be enabled from this illustrative contract alone.
