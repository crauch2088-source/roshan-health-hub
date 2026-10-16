export type InsuranceClaimDraftItem = {
  description: string;
  gross_amount: number;
  covered_amount: number;
  patient_amount: number;
};

export function isInsuranceClaimReadyToSubmit(args: {
  patientInsuranceId: string;
  invoiceId: string | null | undefined;
  itemCount: number;
  isSaving: boolean;
}): boolean {
  return Boolean(
    args.patientInsuranceId.trim() &&
    args.invoiceId?.trim() &&
    args.itemCount > 0 &&
    !args.isSaving,
  );
}

export function validateInsuranceClaimDraft(args: {
  patientInsuranceId: string;
  invoiceId: string | null | undefined;
  items: readonly InsuranceClaimDraftItem[];
}): void {
  if (!args.patientInsuranceId.trim()) {
    throw new Error("Select patient insurance.");
  }
  if (!args.invoiceId?.trim()) {
    throw new Error("Select an invoice for the insurance claim.");
  }
  if (args.items.length === 0) {
    throw new Error("Add at least one claim item.");
  }
  if (
    args.items.some((item) => {
      const amountsAreValid =
        Number.isFinite(item.gross_amount) &&
        item.gross_amount > 0 &&
        Number.isFinite(item.covered_amount) &&
        item.covered_amount >= 0 &&
        Number.isFinite(item.patient_amount) &&
        item.patient_amount >= 0;
      if (!amountsAreValid || !item.description.trim()) return true;

      // Money is stored to two decimal places; compare rounded cents to avoid
      // rejecting valid amounts because of floating-point representation.
      const grossCents = Math.round(item.gross_amount * 100);
      const splitCents =
        Math.round(item.covered_amount * 100) + Math.round(item.patient_amount * 100);
      return splitCents !== grossCents;
    })
  ) {
    throw new Error(
      "Claim item amounts must be valid and covered plus patient amounts must equal the gross amount.",
    );
  }
}
