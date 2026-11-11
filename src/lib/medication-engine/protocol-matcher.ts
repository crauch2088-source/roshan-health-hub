import { calculateDose } from "./dose-calculator.ts";
import type { DoseBasis, DoseCalculationResult } from "./types.ts";

export type MedicationProtocolStatus =
  "draft" | "reviewed" | "approved" | "active" | "suspended" | "retired";

export type MedicationProtocolSource = {
  sourceId: string;
  issuer: string;
  title: string;
  edition: string;
  section: string;
  jurisdiction: string;
  population: string;
  setting: string;
  publishedAt: string;
  retrievedAt: string;
  licenseStatus: "verified" | "unverified" | "review_required";
};

export type MedicationProtocolApproval = {
  role: "gp" | "pharmacist";
  actorId: string;
  approvedAt: string;
};

export type MedicationProtocol = {
  id: string;
  version: string;
  status: MedicationProtocolStatus;
  effectiveFrom: string;
  effectiveTo?: string | null;
  indicationCode: string;
  setting: string;
  population: string;
  jurisdiction: string;
  medicineId: string;
  route: string;
  minAgeDays?: number;
  maxAgeDays?: number;
  doseBasis: DoseBasis;
  source: MedicationProtocolSource;
  approvals: MedicationProtocolApproval[];
};

export type MedicationProtocolMatchContext = {
  /** Explicit date makes matching deterministic; the matcher never reads the system clock. */
  asOfDate: string;
  indicationCode: string;
  setting: string;
  population: string;
  jurisdiction: string;
  medicineId: string;
  ageDays?: number | null;
  /** Encounter-linked measured weight only; no patient-master fallback. */
  weightKg?: number | null;
};

type CalculatedDose = Extract<DoseCalculationResult, { status: "calculated" }>;

export type MedicationProtocolMatchResult =
  | {
      status: "recommendation";
      protocolId: string;
      protocolVersion: string;
      route: string;
      source: MedicationProtocolSource;
      dose: CalculatedDose;
    }
  | {
      status: "needs_data";
      protocolId: string;
      protocolVersion: string;
      missing: Array<"age_days" | "weight_kg">;
      source: MedicationProtocolSource;
    }
  | {
      status: "no_match";
      reason:
        | "no_matching_protocol"
        | "no_active_protocol"
        | "outside_effective_dates"
        | "outside_age_range";
    }
  | {
      status: "blocked";
      reason:
        | "invalid_context"
        | "invalid_patient_data"
        | "ambiguous_active_protocols"
        | "invalid_protocol_provenance"
        | "missing_dual_approval"
        | "invalid_protocol_rule";
    };

function nonEmpty(value: unknown): value is string {
  return typeof value === "string" && value.trim().length > 0;
}

function isIsoDate(value: unknown): value is string {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 10) === value;
}

function isDoseBasis(value: unknown): value is DoseBasis {
  if (!value || typeof value !== "object" || Array.isArray(value)) return false;
  const candidate = value as Record<string, unknown>;
  if (typeof candidate["dosesPerDay"] !== "number") return false;
  if (candidate["kind"] === "fixed") return typeof candidate["amountMg"] === "number";
  if (candidate["kind"] === "mg_per_kg_per_dose") {
    return typeof candidate["amountMgPerKg"] === "number";
  }
  if (candidate["kind"] === "mg_per_kg_per_day") {
    return typeof candidate["amountMgPerKgPerDay"] === "number";
  }
  return false;
}

function hasValidSource(
  source: unknown,
  asOfDate: string,
  protocol: MedicationProtocol,
): source is MedicationProtocolSource {
  if (!source || typeof source !== "object" || Array.isArray(source)) return false;
  const candidate = source as Record<string, unknown>;
  return (
    nonEmpty(candidate["sourceId"]) &&
    nonEmpty(candidate["issuer"]) &&
    nonEmpty(candidate["title"]) &&
    nonEmpty(candidate["edition"]) &&
    nonEmpty(candidate["section"]) &&
    nonEmpty(candidate["jurisdiction"]) &&
    nonEmpty(candidate["population"]) &&
    nonEmpty(candidate["setting"]) &&
    candidate["setting"] === protocol.setting &&
    candidate["population"] === protocol.population &&
    candidate["jurisdiction"] === protocol.jurisdiction &&
    candidate["licenseStatus"] === "verified" &&
    isIsoDate(candidate["publishedAt"]) &&
    isIsoDate(candidate["retrievedAt"]) &&
    candidate["publishedAt"] <= asOfDate &&
    candidate["retrievedAt"] <= asOfDate
  );
}

function hasDualApproval(approvals: MedicationProtocolApproval[], asOfDate: string): boolean {
  if (!Array.isArray(approvals)) return false;

  // A dual-control approval must represent two different people. Treat malformed
  // persisted JSON as missing approval; never let it throw or satisfy the gate.
  const validApprovals = approvals.filter((approval) => {
    if (!approval || typeof approval !== "object") return false;
    return (
      (approval.role === "gp" || approval.role === "pharmacist") &&
      nonEmpty(approval.actorId) &&
      isIsoDate(approval.approvedAt) &&
      approval.approvedAt <= asOfDate
    );
  });

  const gpActors = new Set(
    validApprovals
      .filter((approval) => approval.role === "gp")
      .map((approval) => approval.actorId.trim().toLowerCase()),
  );
  const pharmacistActors = validApprovals
    .filter((approval) => approval.role === "pharmacist")
    .map((approval) => approval.actorId.trim().toLowerCase());

  return [...gpActors].some((gpActor) =>
    pharmacistActors.some((pharmacistActor) => pharmacistActor !== gpActor),
  );
}

function hasValidAgeRange(protocol: MedicationProtocol): boolean {
  const min = protocol.minAgeDays;
  const max = protocol.maxAgeDays;
  return (
    (min === undefined || (Number.isFinite(min) && min >= 0)) &&
    (max === undefined || (Number.isFinite(max) && max >= 0)) &&
    (min === undefined || max === undefined || min <= max)
  );
}

function isEffective(protocol: MedicationProtocol, asOfDate: string): boolean {
  return (
    isIsoDate(protocol.effectiveFrom) &&
    (protocol.effectiveTo == null || isIsoDate(protocol.effectiveTo)) &&
    (protocol.effectiveTo == null || protocol.effectiveTo >= protocol.effectiveFrom) &&
    protocol.effectiveFrom <= asOfDate &&
    (protocol.effectiveTo == null || protocol.effectiveTo >= asOfDate)
  );
}

function isWeightBased(basis: DoseBasis): boolean {
  return basis.kind !== "fixed";
}

/**
 * Deterministic protocol selection only. It never invents a protocol, frequency,
 * route, duration or source. Only active, date-valid, source-verified and
 * dual-approved records can produce a recommendation. This module contains no
 * real clinical protocols and is not a substitute for clinical review.
 */
export function matchMedicationProtocol(
  protocols: readonly MedicationProtocol[],
  context: MedicationProtocolMatchContext,
): MedicationProtocolMatchResult {
  if (
    !context ||
    !Array.isArray(protocols) ||
    !isIsoDate(context.asOfDate) ||
    !nonEmpty(context.indicationCode) ||
    !nonEmpty(context.setting) ||
    !nonEmpty(context.population) ||
    !nonEmpty(context.jurisdiction) ||
    !nonEmpty(context.medicineId) ||
    (context.ageDays != null && (!Number.isFinite(context.ageDays) || context.ageDays < 0))
  ) {
    return { status: "blocked", reason: "invalid_context" };
  }
  if (context.weightKg != null && (!Number.isFinite(context.weightKg) || context.weightKg <= 0)) {
    return { status: "blocked", reason: "invalid_patient_data" };
  }

  const candidates = protocols.filter(
    (protocol) =>
      protocol &&
      protocol.indicationCode === context.indicationCode &&
      protocol.setting === context.setting &&
      protocol.population === context.population &&
      protocol.jurisdiction === context.jurisdiction &&
      protocol.medicineId === context.medicineId,
  );
  if (candidates.length === 0) {
    return { status: "no_match", reason: "no_matching_protocol" };
  }

  const active = candidates.filter((protocol) => protocol.status === "active");
  if (active.length === 0) {
    return { status: "no_match", reason: "no_active_protocol" };
  }

  if (active.some((protocol) => !hasValidAgeRange(protocol))) {
    return { status: "blocked", reason: "invalid_protocol_provenance" };
  }

  const effective = active.filter((protocol) => isEffective(protocol, context.asOfDate));
  if (effective.length === 0) {
    return { status: "no_match", reason: "outside_effective_dates" };
  }

  const ageRequired = effective.some(
    (protocol) => protocol.minAgeDays !== undefined || protocol.maxAgeDays !== undefined,
  );
  if (context.ageDays == null && ageRequired) {
    if (effective.length !== 1) {
      return { status: "blocked", reason: "ambiguous_active_protocols" };
    }
    const protocol = effective[0];
    if (!protocol) return { status: "blocked", reason: "invalid_protocol_provenance" };
    if (
      !nonEmpty(protocol.id) ||
      !nonEmpty(protocol.version) ||
      !nonEmpty(protocol.route) ||
      !hasValidSource(protocol.source, context.asOfDate, protocol)
    ) {
      return { status: "blocked", reason: "invalid_protocol_provenance" };
    }
    if (!hasDualApproval(protocol.approvals, context.asOfDate)) {
      return { status: "blocked", reason: "missing_dual_approval" };
    }
    if (!isDoseBasis(protocol.doseBasis)) {
      return { status: "blocked", reason: "invalid_protocol_rule" };
    }
    const missing: Array<"age_days" | "weight_kg"> = ["age_days"];
    if (isWeightBased(protocol.doseBasis) && context.weightKg == null) {
      missing.push("weight_kg");
    }
    return {
      status: "needs_data",
      protocolId: protocol.id,
      protocolVersion: protocol.version,
      missing,
      source: protocol.source,
    };
  }

  const ageMatches =
    context.ageDays == null
      ? effective
      : effective.filter(
          (protocol) =>
            (protocol.minAgeDays === undefined || context.ageDays! >= protocol.minAgeDays) &&
            (protocol.maxAgeDays === undefined || context.ageDays! <= protocol.maxAgeDays),
        );
  if (ageMatches.length === 0) {
    return { status: "no_match", reason: "outside_age_range" };
  }
  if (ageMatches.length > 1) {
    return { status: "blocked", reason: "ambiguous_active_protocols" };
  }

  const protocol = ageMatches[0];
  if (!protocol) return { status: "blocked", reason: "invalid_protocol_provenance" };
  if (
    !nonEmpty(protocol.id) ||
    !nonEmpty(protocol.version) ||
    !nonEmpty(protocol.route) ||
    !protocol.source ||
    !hasValidSource(protocol.source, context.asOfDate, protocol)
  ) {
    return { status: "blocked", reason: "invalid_protocol_provenance" };
  }
  if (!hasDualApproval(protocol.approvals, context.asOfDate)) {
    return { status: "blocked", reason: "missing_dual_approval" };
  }
  if (!isDoseBasis(protocol.doseBasis)) {
    return { status: "blocked", reason: "invalid_protocol_rule" };
  }

  const dose = calculateDose({ basis: protocol.doseBasis, weightKg: context.weightKg ?? null });
  if (dose.status === "needs_data") {
    return {
      status: "needs_data",
      protocolId: protocol.id,
      protocolVersion: protocol.version,
      missing: ["weight_kg"],
      source: protocol.source,
    };
  }
  if (dose.status !== "calculated") {
    return { status: "blocked", reason: "invalid_protocol_rule" };
  }

  return {
    status: "recommendation",
    protocolId: protocol.id,
    protocolVersion: protocol.version,
    route: protocol.route,
    source: protocol.source,
    dose,
  };
}
