export type InvoiceDraftLine = {
  description: string;
  quantity: unknown;
  unit_price: unknown;
  item_type: string;
};

export type ValidatedInvoiceLine = {
  description: string;
  quantity: number;
  unit_price: number;
  item_type: string;
};

export type ValidatedInvoiceDraft = {
  subtotal: number;
  discount: number;
  net: number;
  lines: ValidatedInvoiceLine[];
};

function finiteInput(value: unknown): number | null {
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  if (typeof value !== "string" || value.trim() === "") return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

/** Client-side preflight only; the database RPC enforces the same invariants. */
export function validateInvoiceDraft(
  draftLines: readonly InvoiceDraftLine[],
  discountInput: unknown,
): ValidatedInvoiceDraft {
  if (draftLines.length === 0) throw new Error("An invoice must contain at least one item.");

  const allowedTypes = new Set(["consultation", "lab", "pharmacy", "procedure", "other"]);
  const lines = draftLines.map((line) => {
    const description = line.description.trim();
    if (!description) throw new Error("Every invoice item needs a description.");
    if (!allowedTypes.has(line.item_type)) throw new Error("Invoice item type is not supported.");

    const quantity = finiteInput(line.quantity);
    if (quantity === null || !Number.isInteger(quantity) || quantity <= 0) {
      throw new Error("Invoice quantity must be a positive whole number.");
    }

    const unitPrice = finiteInput(line.unit_price);
    if (unitPrice === null || unitPrice < 0) {
      throw new Error("Invoice unit price must be a finite non-negative amount.");
    }
    if (!/^\d+(?:\.\d{1,2})?$/.test(String(line.unit_price).trim())) {
      throw new Error("Invoice unit price must have at most two decimal places.");
    }

    return { description, quantity, unit_price: unitPrice, item_type: line.item_type };
  });

  const subtotal = lines.reduce((sum, line) => sum + line.quantity * line.unit_price, 0);
  if (!Number.isFinite(subtotal)) {
    throw new Error("Invoice subtotal is outside the supported numeric range.");
  }

  const discount = finiteInput(discountInput);
  if (discount === null || discount < 0 || discount > subtotal) {
    throw new Error("Invoice discount must be finite and between zero and the subtotal.");
  }
  if (!/^\d+(?:\.\d{1,2})?$/.test(String(discountInput).trim())) {
    throw new Error("Invoice discount must have at most two decimal places.");
  }

  const net = subtotal - discount;
  if (!Number.isFinite(net) || net < 0) throw new Error("Invoice net amount is invalid.");
  return { subtotal, discount, net, lines };
}
