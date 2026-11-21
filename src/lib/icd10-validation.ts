export type DiagnosisCertainty = "confirmed" | "provisional" | "narrative_only";

export interface Icd10ClassificationMetadata {
  classificationId: string;
  version: string;
  effectiveDate: string;
  sourceName: string;
  licenseNote: string;
}

export interface Icd10CodeRecord {
  code: string;
  titleEn: string;
  titleAr?: string;
  arabicReviewed?: boolean;
  isActive: boolean;
  effectiveFrom?: string;
  effectiveTo?: string;
  billable?: boolean;
}

export interface Icd10Dataset {
  metadata: Icd10ClassificationMetadata;
  codes: ReadonlyMap<string, Icd10CodeRecord>;
}

export interface DiagnosisValidationInput {
  narrative: string;
  certainty: DiagnosisCertainty;
  icd10Code?: string | null;
  referenceDate?: string;
}

export type DiagnosisValidationErrorCode =
  | "narrative_required"
  | "confirmed_requires_code"
  | "code_format_invalid"
  | "code_not_in_dataset"
  | "code_inactive"
  | "code_outside_effective_window";

export interface DiagnosisValidationResult {
  valid: boolean;
  errorCode?: DiagnosisValidationErrorCode;
  normalizedCode: string | null;
  classificationId: string;
  classificationVersion: string;
  matchedRecord: Icd10CodeRecord | null;
}

/**
 * Broad syntactic screen including WHO ICD-10 U-chapter emergency/special codes (e.g., U07.1).
 * Syntax alone NEVER proves clinical or classification validity; dataset membership is mandatory.
 */
const ICD10_SYNTAX_RE = /^[A-Z][0-9][0-9A-Z](?:\.[0-9A-Z]{1,4})?$/;

export function normalizeIcd10Code(raw: string | null | undefined): string | null {
  if (typeof raw !== "string") return null;
  const cleaned = raw.trim().toUpperCase();
  return cleaned.length > 0 ? cleaned : null;
}

export function isSyntacticallyValidIcd10Format(raw: string | null | undefined): boolean {
  const normalized = normalizeIcd10Code(raw);
  return normalized !== null && ICD10_SYNTAX_RE.test(normalized);
}

export function createIcd10Dataset(
  metadata: Icd10ClassificationMetadata,
  records: readonly Icd10CodeRecord[],
): Icd10Dataset {
  const map = new Map<string, Icd10CodeRecord>();
  for (const record of records) {
    const normalized = normalizeIcd10Code(record.code);
    if (!normalized) continue;
    map.set(normalized, { ...record, code: normalized });
  }
  return { metadata, codes: map };
}

export function validateDiagnosisAgainstDataset(
  input: DiagnosisValidationInput,
  dataset: Icd10Dataset,
): DiagnosisValidationResult {
  const narrative = input.narrative?.trim() ?? "";
  const normalizedCode = normalizeIcd10Code(input.icd10Code);
  const base = {
    normalizedCode,
    classificationId: dataset.metadata.classificationId,
    classificationVersion: dataset.metadata.version,
    matchedRecord: null as Icd10CodeRecord | null,
  };

  if (!narrative) {
    return { valid: false, errorCode: "narrative_required", ...base };
  }

  if (normalizedCode === null) {
    if (input.certainty === "confirmed") {
      return { valid: false, errorCode: "confirmed_requires_code", ...base };
    }
    return { valid: true, ...base };
  }

  if (!isSyntacticallyValidIcd10Format(normalizedCode)) {
    return { valid: false, errorCode: "code_format_invalid", ...base };
  }

  const record = dataset.codes.get(normalizedCode);
  if (!record) {
    return { valid: false, errorCode: "code_not_in_dataset", ...base };
  }

  if (!record.isActive) {
    return { valid: false, errorCode: "code_inactive", ...base, matchedRecord: record };
  }

  if (input.referenceDate) {
    if (record.effectiveFrom && input.referenceDate < record.effectiveFrom) {
      return {
        valid: false,
        errorCode: "code_outside_effective_window",
        ...base,
        matchedRecord: record,
      };
    }
    if (record.effectiveTo && input.referenceDate > record.effectiveTo) {
      return {
        valid: false,
        errorCode: "code_outside_effective_window",
        ...base,
        matchedRecord: record,
      };
    }
  }

  return { valid: true, ...base, matchedRecord: record };
}

export function searchIcd10Dataset(
  dataset: Icd10Dataset,
  query: string,
  options: { includeInactive?: boolean; limit?: number } = {},
): Icd10CodeRecord[] {
  const q = query.trim().toLowerCase();
  if (!q) return [];
  const limit = options.limit ?? 20;
  const results: Icd10CodeRecord[] = [];
  for (const record of dataset.codes.values()) {
    if (!options.includeInactive && !record.isActive) continue;
    const codeMatch = record.code.toLowerCase().includes(q);
    const enMatch = record.titleEn.toLowerCase().includes(q);
    const arMatch =
      record.arabicReviewed === true &&
      typeof record.titleAr === "string" &&
      record.titleAr.toLowerCase().includes(q);
    if (codeMatch || enMatch || arMatch) {
      results.push(record);
      if (results.length >= limit) break;
    }
  }
  return results;
}
