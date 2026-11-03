export type PrescriptionPrintItem = {
  id: string;
  medicationName: string;
  dosageForm: string;
  dose: string;
  route: string;
  frequency: string;
  duration: string;
  quantity: number;
  instructions: string;
};

export type PrescriptionPrintModel = {
  id: string;
  createdAt: string;
  status: string;
  isExternal: boolean;
  patientName: string;
  patientMrn: string;
  prescriberName: string;
  notes: string;
  items: PrescriptionPrintItem[];
  complete: boolean;
  missingFields: string[];
};

type RecordValue = Record<string, unknown>;

function asRecord(value: unknown): RecordValue {
  return value && typeof value === "object" && !Array.isArray(value)
    ? (value as RecordValue)
    : {};
}

function relation(row: RecordValue, key: string): RecordValue {
  const value = row[key];
  return Array.isArray(value) ? asRecord(value[0]) : asRecord(value);
}

function text(value: unknown): string {
  return value == null ? "" : String(value);
}

function positiveInteger(value: unknown): number {
  const parsed = Number(value);
  return Number.isInteger(parsed) && parsed > 0 ? parsed : 0;
}

/**
 * Build a read-only print model from one persisted prescription row.
 * Values are copied verbatim; missing clinical fields are never inferred.
 */
export function buildPrescriptionPrintModel(
  value: unknown,
): PrescriptionPrintModel | null {
  const row = asRecord(value);
  if (!text(row["id"]).trim()) return null;

  const patient = relation(row, "patients");
  const prescriber = relation(row, "users");
  const rawItems = Array.isArray(row["prescription_items"])
    ? (row["prescription_items"] as unknown[]).map(asRecord)
    : [];
  const items = rawItems
    .filter((item) => !text(item["deleted_at"]))
    .map((item) => ({
      id: text(item["id"]),
      medicationName: text(item["medication_name"]),
      dosageForm: text(item["dosage_form"]),
      dose: text(item["dose"]),
      route: text(item["route"]),
      frequency: text(item["frequency"]),
      duration: text(item["duration"]),
      quantity: positiveInteger(item["quantity"]),
      instructions: text(item["instructions"]),
    }));

  const missingFields: string[] = [];
  if (!text(patient["full_name"]).trim()) missingFields.push("patient");
  if (text(patient["deleted_at"])) missingFields.push("patient record");
  if (!text(prescriber["full_name"]).trim()) missingFields.push("prescriber");
  if (!text(row["created_at"]).trim()) missingFields.push("created date");
  if (items.length === 0) missingFields.push("items");

  items.forEach((item, index) => {
    const prefix = `item ${index + 1}: `;
    if (!item.medicationName.trim()) missingFields.push(prefix + "medicine");
    if (!item.dose.trim()) missingFields.push(prefix + "dose");
    if (!item.route.trim()) missingFields.push(prefix + "route");
    if (!item.frequency.trim()) missingFields.push(prefix + "frequency");
    if (!item.duration.trim()) missingFields.push(prefix + "duration");
    if (!item.dosageForm.trim()) missingFields.push(prefix + "dosage form");
    if (item.quantity <= 0) missingFields.push(prefix + "quantity");
  });

  return {
    id: text(row["id"]),
    createdAt: text(row["created_at"]),
    status: text(row["status"]),
    isExternal: Boolean(row["is_external"]),
    patientName: text(patient["full_name"]),
    patientMrn: text(patient["mrn"]),
    prescriberName: text(prescriber["full_name"]),
    notes: text(row["notes"]),
    items,
    complete: missingFields.length === 0,
    missingFields,
  };
}
