import { useCallback, useEffect, useState } from "react";

export type PaperWidth = "a4" | "58mm" | "80mm";
export type ReceiptPrintState = "active" | "void" | "inconsistent";

export type PrintRequest<T> = {
  document: T;
  paperWidth: PaperWidth;
};

function asText(value: unknown): string {
  return value == null ? "" : String(value).trim();
}

function nestedRow(value: unknown): Record<string, unknown> {
  if (Array.isArray(value)) return (value[0] as Record<string, unknown> | undefined) ?? {};
  return (value as Record<string, unknown> | null | undefined) ?? {};
}

/** A receipt is printable only when the payment and its authoritative ledger state agree. */
export function getReceiptPrintState(
  payment: Record<string, unknown>,
  status: Record<string, unknown> | null | undefined,
): ReceiptPrintState {
  if (!status || status.ledger_found !== true || status.ledger_matches !== true) {
    return "inconsistent";
  }
  const paymentVoided = Boolean(payment.deleted_at);
  const ledgerVoided = status.ledger_is_reversed === true;
  if (paymentVoided !== ledgerVoided) return "inconsistent";
  return ledgerVoided ? "void" : "active";
}

/** Never print an external record or a prescription with incomplete medication directions. */
export function isPrescriptionPrintReady(prescription: Record<string, unknown>): boolean {
  if (prescription.prescription_type !== "internal" || prescription.is_external === true) {
    return false;
  }
  if (!asText(nestedRow(prescription.users).full_name)) return false;
  const items = Array.isArray(prescription.prescription_items)
    ? (prescription.prescription_items as Record<string, unknown>[])
    : [];
  if (items.length === 0) return false;

  return items.every((item) => {
    const medicine = nestedRow(item.medicines);
    const medicationName =
      asText(item.medication_name) || asText(medicine.name) || asText(medicine.generic_name);
    const dose = asText(item.dose) || asText(item.dosage);
    const frequency = asText(item.frequency);
    const duration = asText(item.duration);
    const quantity = Number(item.quantity);
    return (
      medicationName.length > 0 &&
      dose.length > 0 &&
      frequency.length > 0 &&
      duration.length > 0 &&
      Number.isFinite(quantity) &&
      quantity > 0
    );
  });
}

/** Branch identity overrides global center address/phone; the configured center name remains primary. */
export function getClinicIdentity(
  settings: Record<string, string>,
  branch: Record<string, unknown> | null | undefined,
  lang: "ar" | "en",
) {
  const centerName =
    lang === "ar"
      ? asText(settings.center_name_ar) || asText(settings.center_name)
      : asText(settings.center_name) || asText(settings.center_name_ar);
  const branchName = asText(branch?.branch_name) || asText(branch?.name);
  return {
    name: centerName || (lang === "ar" ? "مركز روشان الطبي" : "ROSHAN Medical Center"),
    branchName,
    address: asText(branch?.address) || asText(settings.address),
    phone: asText(branch?.phone) || asText(settings.phone),
  };
}

/** Renders one selected document only, then clears the request after the browser print dialog closes. */
export function useDocumentPrint<T>() {
  const [request, setRequest] = useState<PrintRequest<T> | null>(null);

  useEffect(() => {
    if (!request || typeof window === "undefined") return;
    const afterPrint = () => setRequest(null);
    document.documentElement.dataset.printWidth = request.paperWidth;
    window.addEventListener("afterprint", afterPrint);
    const frame = window.requestAnimationFrame(() => window.print());
    return () => {
      window.cancelAnimationFrame(frame);
      window.removeEventListener("afterprint", afterPrint);
      delete document.documentElement.dataset.printWidth;
    };
  }, [request]);

  const printDocument = useCallback((documentValue: T, paperWidth: PaperWidth = "a4") => {
    setRequest({ document: documentValue, paperWidth });
  }, []);

  const cancelPrint = useCallback(() => setRequest(null), []);

  return { request, printDocument, cancelPrint, isPrinting: request !== null };
}
