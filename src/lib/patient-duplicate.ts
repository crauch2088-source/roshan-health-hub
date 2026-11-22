export type PatientDuplicateCandidate = {
  id: string;
  mrn?: string | null;
  full_name?: string | null;
  phone?: string | null;
  national_id?: string | null;
  date_of_birth?: string | null;
};

export type PatientRegistrationInput = {
  full_name: string;
  phone?: string | null;
  national_id?: string | null;
  date_of_birth?: string | null;
};

export type DuplicateLevel = "none" | "possible" | "confirmed";

export type DuplicateMatch = {
  candidate: PatientDuplicateCandidate;
  level: Exclude<DuplicateLevel, "none">;
  reasons: Array<"national_id" | "name_and_phone" | "phone_only" | "name_only">;
};

export function normalizePhone(value: string | null | undefined): string {
  const raw = String(value ?? "").trim();
  if (!raw) return "";
  const ascii = raw.replace(/[\u0660-\u0669]/g, (d) => String(d.charCodeAt(0) - 0x0660));
  const digits = ascii.replace(/\D+/g, "");
  if (!digits) return "";
  if (digits.startsWith("00249") && digits.length >= 14) {
    return `0${digits.slice(5)}`;
  }
  if (digits.startsWith("249") && digits.length >= 12) {
    return `0${digits.slice(3)}`;
  }
  return digits;
}

export function normalizePatientName(value: string | null | undefined): string {
  return String(value ?? "")
    .trim()
    .replace(/\s+/g, " ")
    .toLowerCase()
    .replace(/[أإآ]/g, "ا")
    .replace(/ة/g, "ه")
    .replace(/ى/g, "ي");
}

export function normalizeNationalId(value: string | null | undefined): string {
  return String(value ?? "")
    .trim()
    .replace(/\s+/g, "")
    .toLowerCase();
}

export function classifyPatientDuplicates(
  input: PatientRegistrationInput,
  candidates: PatientDuplicateCandidate[],
): { level: DuplicateLevel; matches: DuplicateMatch[] } {
  const inName = normalizePatientName(input.full_name);
  const inPhone = normalizePhone(input.phone);
  const inNatId = normalizeNationalId(input.national_id);

  const matches: DuplicateMatch[] = [];

  for (const candidate of candidates) {
    const cName = normalizePatientName(candidate.full_name);
    const cPhone = normalizePhone(candidate.phone);
    const cNatId = normalizeNationalId(candidate.national_id);

    const sameNatId = Boolean(inNatId && cNatId && inNatId === cNatId);
    const sameName = Boolean(inName && cName && inName === cName);
    const samePhone = Boolean(inPhone && cPhone && inPhone === cPhone);

    const reasons: DuplicateMatch["reasons"] = [];
    let level: Exclude<DuplicateLevel, "none"> | null = null;

    if (sameNatId) {
      reasons.push("national_id");
      level = "confirmed";
    }
    if (sameName && samePhone) {
      reasons.push("name_and_phone");
      level = "confirmed";
    } else if (samePhone && !sameName) {
      reasons.push("phone_only");
      if (!level) level = "possible";
    } else if (sameName && !samePhone) {
      reasons.push("name_only");
      if (!level) level = "possible";
    }

    if (level) {
      matches.push({ candidate, level, reasons });
    }
  }

  matches.sort((a, b) => (a.level === "confirmed" ? -1 : 1) - (b.level === "confirmed" ? -1 : 1));
  const highest: DuplicateLevel = matches.some((m) => m.level === "confirmed")
    ? "confirmed"
    : matches.length > 0
      ? "possible"
      : "none";

  return { level: highest, matches };
}
