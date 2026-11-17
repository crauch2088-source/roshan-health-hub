/**
 * Prescription-only age context. Uses the clinic-local encounter date, not the
 * device's current date. This is a safety cue only; it never calculates a dose.
 */
export type PrescriptionAgeAtEncounter = {
  years: number;
  days: number;
};

const clinicDateFormatter = new Intl.DateTimeFormat("en-US", {
  timeZone: "Africa/Khartoum",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

function parseDateOnly(value: string | null | undefined): Date | null {
  if (!value) return null;
  const match = /^(\\d{4})-(\\d{2})-(\\d{2})$/.exec(value);
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    Number.isNaN(date.getTime()) ||
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() + 1 !== month ||
    date.getUTCDate() !== day
  ) {
    return null;
  }
  return date;
}

export function getPrescriptionAgeAtEncounter(
  dateOfBirth?: string | null,
  visitDate?: string | null,
): PrescriptionAgeAtEncounter | null {
  const birthDate = parseDateOnly(dateOfBirth);
  if (!birthDate || !visitDate) return null;

  const visitInstant = new Date(visitDate);
  if (Number.isNaN(visitInstant.getTime())) return null;

  const parts = clinicDateFormatter.formatToParts(visitInstant);
  const year = parts.find((part) => part.type === "year")?.value;
  const month = parts.find((part) => part.type === "month")?.value;
  const day = parts.find((part) => part.type === "day")?.value;
  if (!year || !month || !day) return null;

  const encounterDate = parseDateOnly(`${year}-${month}-${day}`);
  if (!encounterDate || encounterDate.getTime() < birthDate.getTime()) return null;

  const days = Math.floor((encounterDate.getTime() - birthDate.getTime()) / 86_400_000);
  let years = encounterDate.getUTCFullYear() - birthDate.getUTCFullYear();
  const monthDifference = encounterDate.getUTCMonth() - birthDate.getUTCMonth();
  if (
    monthDifference < 0 ||
    (monthDifference === 0 && encounterDate.getUTCDate() < birthDate.getUTCDate())
  ) {
    years--;
  }

  return { years, days };
}
