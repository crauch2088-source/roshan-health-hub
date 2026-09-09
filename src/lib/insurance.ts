import { rpc } from "./db";

export type ClaimStatus =
  | "draft"
  | "submitted"
  | "under_review"
  | "approved"
  | "partially_approved"
  | "rejected"
  | "paid";

export const CLAIM_STATUSES: ClaimStatus[] = [
  "draft",
  "submitted",
  "under_review",
  "approved",
  "partially_approved",
  "rejected",
  "paid",
];

/** Allowed forward transitions — mirrors update_insurance_claim_status()'s own check. */
export const NEXT_CLAIM_STATUS: Partial<Record<ClaimStatus, ClaimStatus[]>> = {
  draft: ["submitted"],
  submitted: ["under_review"],
  under_review: ["approved", "partially_approved", "rejected"],
  approved: ["paid"],
  partially_approved: ["paid"],
};

export type CoverageResult = {
  covered_amount: number;
  patient_amount: number;
  requires_prior_auth: boolean;
  excluded: boolean;
  coverage_rule_id: string | null;
};

export type ClaimItemInput = {
  service_type: "consultation" | "lab" | "medicine";
  reference_id: string | null;
  description: string;
  gross_amount: number;
  covered_amount: number;
  patient_amount: number;
  coverage_rule_id: string | null;
};

export async function calculateInsuranceCoverage(args: {
  patientInsuranceId: string;
  serviceType: "consultation" | "lab" | "medicine";
  referenceId?: string | null;
  genericName?: string | null;
  grossAmount: number;
}): Promise<CoverageResult> {
  const rows = await rpc<CoverageResult[]>("fn_calculate_insurance_coverage", {
    _patient_insurance_id: args.patientInsuranceId,
    _service_type: args.serviceType,
    _reference_id: args.referenceId ?? null,
    _generic_name: args.genericName ?? null,
    _gross_amount: args.grossAmount,
  });
  return (
    rows[0] ?? {
      covered_amount: 0,
      patient_amount: args.grossAmount,
      requires_prior_auth: false,
      excluded: false,
      coverage_rule_id: null,
    }
  );
}

export function createInsuranceClaim(args: {
  patientInsuranceId: string;
  invoiceId: string | null;
  items: ClaimItemInput[];
  notes?: string | null;
}): Promise<string> {
  return rpc<string>("create_insurance_claim", {
    _patient_insurance_id: args.patientInsuranceId,
    _invoice_id: args.invoiceId,
    _items: args.items,
    _notes: args.notes ?? null,
  });
}

export function updateInsuranceClaimStatus(args: {
  claimId: string;
  newStatus: ClaimStatus;
  approvedAmount?: number | null;
  notes?: string | null;
}): Promise<void> {
  return rpc<void>("update_insurance_claim_status", {
    _claim_id: args.claimId,
    _new_status: args.newStatus,
    _approved_amount: args.approvedAmount ?? null,
    _notes: args.notes ?? null,
  });
}

export function postInsuranceClaimPayment(args: {
  claimId: string;
  amount: number;
  method?: string;
  reference?: string | null;
}): Promise<string> {
  return rpc<string>("post_insurance_claim_payment", {
    _claim_id: args.claimId,
    _amount: args.amount,
    _method: args.method ?? "bank",
    _reference: args.reference ?? null,
  });
}
