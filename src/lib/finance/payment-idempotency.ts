export type InvoicePaymentRequest = {
  invoiceId: string;
  amount: number;
  method: string;
  reference: string | null;
};

type IdempotencyStorage = {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
};

const STORAGE_PREFIX = "roshan:invoice-payment-idempotency:";
const storageKeysByRequest = new WeakMap<IdempotencyStorage, Map<string, string>>();

function requestIdentity(request: InvoicePaymentRequest): string {
  return JSON.stringify([
    request.invoiceId.trim(),
    request.amount,
    request.method.trim() || "cash",
    request.reference?.trim() || null,
  ]);
}

async function fingerprint(identity: string): Promise<string> {
  const bytes = new TextEncoder().encode(identity);
  const digest = await globalThis.crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

/**
 * Returns the same opaque key for retries of the same logical payment request.
 * sessionStorage keeps the key across route reloads without persisting payment
 * references or amounts. A changed request receives a different key.
 */
export async function getInvoicePaymentIdempotencyKey(
  request: InvoicePaymentRequest,
  storage: IdempotencyStorage = window.sessionStorage,
  createKey: () => string = () => globalThis.crypto.randomUUID(),
): Promise<string> {
  if (!request.invoiceId.trim() || !Number.isFinite(request.amount) || request.amount <= 0) {
    throw new Error("A valid invoice and positive payment amount are required for idempotency.");
  }

  const identity = requestIdentity(request);
  const digest = await fingerprint(identity);
  const storageKey = `${STORAGE_PREFIX}${request.invoiceId.trim()}:${digest}`;
  const existing = storage.getItem(storageKey);
  const key = existing || createKey();

  if (!existing) storage.setItem(storageKey, key);

  let requestKeys = storageKeysByRequest.get(storage);
  if (!requestKeys) {
    requestKeys = new Map<string, string>();
    storageKeysByRequest.set(storage, requestKeys);
  }
  requestKeys.set(identity, storageKey);

  return key;
}

/** Remove the retry key only after the RPC confirms the payment was saved. */
export function clearInvoicePaymentIdempotencyKey(
  request: InvoicePaymentRequest,
  storage: IdempotencyStorage = window.sessionStorage,
): boolean {
  const identity = requestIdentity(request);
  const storageKey = storageKeysByRequest.get(storage)?.get(identity);
  if (!storageKey) return false;

  storage.removeItem(storageKey);
  storageKeysByRequest.get(storage)?.delete(identity);
  return true;
}
