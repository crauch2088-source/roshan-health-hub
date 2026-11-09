type ReceiptRow = Record<string, unknown>;

export type InvoicePaymentReceiptModel = {
  paymentId: string;
  invoiceNumber: string;
  patientName: string;
  patientMrn: string;
  amount: number;
  currency: string;
  paymentMethod: string;
  reference: string;
  receivedAt: string;
  cashierName: string;
  currentBalance: number;
  isReversed: boolean;
  reversalReason: string;
  reversalAt: string;
  complete: boolean;
  missingFields: string[];
};

type ReceiptLedgerStatus = {
  payment_id?: unknown;
  ledger_found?: unknown;
  ledger_matches?: unknown;
  ledger_is_reversed?: unknown;
  reversal_reason?: unknown;
  reversal_at?: unknown;
  payment_currency_code?: unknown;
  invoice_currency_code?: unknown;
  ledger_currency_code?: unknown;
  reversal_currency_code?: unknown;
  currency_matches?: unknown;
};

function text(row: ReceiptRow | null | undefined, key: string): string {
  const value = row?.[key];
  return value == null ? "" : String(value).trim();
}

function numberValue(row: ReceiptRow, key: string): number | null {
  const value = row[key];
  if (value == null || value === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function relation(row: ReceiptRow, key: string): ReceiptRow | null {
  const value = row[key];
  const candidate = Array.isArray(value) ? value[0] : value;
  return candidate && typeof candidate === "object" ? (candidate as ReceiptRow) : null;
}

function validTimestamp(value: string): boolean {
  return Boolean(value) && Number.isFinite(Date.parse(value));
}

/**
 * Builds a read-only receipt model from one saved payment, its invoice,
 * and the Phase59 ledger-integrity and persisted-currency result. Incomplete
 * or contradictory records remain non-printable; no values are inferred.
 */
export function buildInvoicePaymentReceiptModel(
  payment: ReceiptRow,
  invoice: ReceiptRow,
  ledger: ReceiptLedgerStatus | null | undefined,
  cashierNameValue: string,
): InvoicePaymentReceiptModel | null {
  const paymentId = text(payment, "id");
  const invoiceId = text(invoice, "id");
  if (!paymentId || !invoiceId) return null;

  const missing = new Set<string>();
  const patient = relation(invoice, "patients");
  const invoiceNumber = text(invoice, "invoice_number");
  const patientName = text(patient, "full_name");
  const patientMrn = text(patient, "mrn");
  const cashierName = cashierNameValue.trim();
  const paymentCurrency = text(payment, "currency_code");
  const invoiceCurrency = text(invoice, "currency_code");
  const ledgerPaymentCurrency = text(ledger as ReceiptRow, "payment_currency_code");
  const ledgerInvoiceCurrency = text(ledger as ReceiptRow, "invoice_currency_code");
  const ledgerCurrency = text(ledger as ReceiptRow, "ledger_currency_code");
  const reversalCurrency = text(ledger as ReceiptRow, "reversal_currency_code");
  const isReversed = ledger?.ledger_is_reversed === true;
  const currencyMatches =
    ledger?.currency_matches === true &&
    paymentCurrency === "SDG" &&
    invoiceCurrency === "SDG" &&
    ledgerPaymentCurrency === paymentCurrency &&
    ledgerInvoiceCurrency === invoiceCurrency &&
    ledgerCurrency === "SDG" &&
    (isReversed ? reversalCurrency === "SDG" : !reversalCurrency);
  const currency = currencyMatches ? "SDG" : "";

  if (text(payment, "invoice_id") !== invoiceId) missing.add("invoice linkage");
  if (text(invoice, "deleted_at")) missing.add("active invoice");
  if (text(patient, "deleted_at")) missing.add("active patient");
  if (!invoiceNumber) missing.add("invoice number");
  if (!patientName) missing.add("patient");
  if (!cashierName) missing.add("cashier");
  if (!currencyMatches) missing.add("currency provenance");

  const paymentBranch = text(payment, "branch_id");
  const invoiceBranch = text(invoice, "branch_id");
  const patientBranch = text(patient, "branch_id");
  if (
    !paymentBranch ||
    !invoiceBranch ||
    paymentBranch !== invoiceBranch ||
    (patientBranch && patientBranch !== invoiceBranch)
  ) {
    missing.add("branch binding");
  }

  const amount = numberValue(payment, "amount");
  if (amount == null || amount <= 0) missing.add("payment amount");

  const paymentMethod = text(payment, "payment_method");
  const legacyMethod = text(payment, "method");
  if (!paymentMethod && !legacyMethod) missing.add("payment method");
  if (paymentMethod && legacyMethod && paymentMethod !== legacyMethod) {
    missing.add("payment method consistency");
  }

  const receivedAt = text(payment, "received_at");
  if (!validTimestamp(receivedAt)) missing.add("received timestamp");

  const netAmount = numberValue(invoice, "net_amount");
  const paidAmount = numberValue(invoice, "paid_amount");
  const currentBalance = netAmount != null && paidAmount != null ? netAmount - paidAmount : null;
  if (
    netAmount == null ||
    paidAmount == null ||
    netAmount < 0 ||
    paidAmount < 0 ||
    currentBalance == null ||
    currentBalance < 0
  ) {
    missing.add("invoice balance");
  }

  const ledgerMatchesPayment =
    Boolean(ledger) && text(ledger as ReceiptRow, "payment_id") === paymentId;
  if (!ledgerMatchesPayment || ledger?.ledger_found !== true) {
    missing.add("ledger");
  } else if (ledger.ledger_matches !== true) {
    missing.add("ledger integrity");
  }

  const paymentIsDeleted = Boolean(text(payment, "deleted_at"));
  if (paymentIsDeleted !== isReversed) missing.add("payment state");

  const reversalAt = text((ledger ?? {}) as ReceiptRow, "reversal_at");
  if (isReversed && !validTimestamp(reversalAt)) {
    missing.add("reversal timestamp");
  }

  return {
    paymentId,
    invoiceNumber,
    patientName,
    patientMrn,
    amount: amount ?? 0,
    currency,
    paymentMethod: paymentMethod || legacyMethod,
    reference: text(payment, "reference_no") || text(payment, "reference"),
    receivedAt,
    cashierName,
    currentBalance: currentBalance ?? 0,
    isReversed,
    reversalReason: text((ledger ?? {}) as ReceiptRow, "reversal_reason"),
    reversalAt,
    complete: missing.size === 0,
    missingFields: [...missing],
  };
}
