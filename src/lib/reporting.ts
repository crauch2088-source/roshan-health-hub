export type ReportingBreakdown = {
  name: string;
  name_ar?: string;
  count: number;
};

export type ReportingMonthlyRow = {
  month: string;
  visits: number;
  payments: number;
  expenses: number;
};

export type ReportingPayload = {
  period: { from: string; to: string; branch_id: string | null };
  coverage: {
    visits: boolean; payments: boolean; expenses: boolean; lab: boolean;
    insurance: boolean; pharmacy: boolean; diagnoses: boolean; doctors: boolean;
  };
  summary: {
    visits: number;
    completed_visits: number;
    cancelled_visits: number;
    consultation_revenue: number;
    payments_collected: number;
    operating_expenses: number;
    net_cashflow: number;
    lab_orders: number;
    lab_items: number;
    lab_revenue: number;
    insurance_claims: number;
    insurance_submitted: number;
    insurance_approved: number;
    insurance_paid: number;
    prescriptions: number;
    dispensed_prescriptions: number;
    dispensed_units: number;
    writeoff_units: number;
  };
  monthly: ReportingMonthlyRow[];
  by_department: ReportingBreakdown[];
  by_doctor: ReportingBreakdown[];
  by_test: ReportingBreakdown[];
  by_diagnosis: ReportingBreakdown[];
};

/** Inclusive clinic-local date range, capped at 366 calendar days. */
export function isValidReportingRange(from: string, to: string): boolean {
  const isoDate = /^\d{4}-\d{2}-\d{2}$/;
  if (!isoDate.test(from) || !isoDate.test(to)) return false;

  const fromMs = Date.parse(`${from}T00:00:00.000Z`);
  const toMs = Date.parse(`${to}T00:00:00.000Z`);
  if (!Number.isFinite(fromMs) || !Number.isFinite(toMs)) return false;
  if (new Date(fromMs).toISOString().slice(0, 10) !== from) return false;
  if (new Date(toMs).toISOString().slice(0, 10) !== to) return false;

  const days = (toMs - fromMs) / 86_400_000;
  return days >= 0 && days <= 365;
}
