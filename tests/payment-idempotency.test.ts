import assert from "node:assert/strict";
import test from "node:test";
import {
  clearInvoicePaymentIdempotencyKey,
  getInvoicePaymentIdempotencyKey,
} from "../src/lib/finance/payment-idempotency.ts";

function memoryStorage() {
  const values = new Map<string, string>();
  return {
    getItem: (key: string) => values.get(key) ?? null,
    setItem: (key: string, value: string) => values.set(key, value),
    removeItem: (key: string) => values.delete(key),
    entries: () => [...values.entries()],
  };
}

const request = {
  invoiceId: "invoice-001",
  amount: 125.5,
  method: "bankak",
  reference: "BANKAK-REF-7781",
};

test("reuses one key for the same logical payment across retries", async () => {
  const storage = memoryStorage();
  let generated = 0;
  const createKey = () => `attempt-${++generated}`;
  const first = await getInvoicePaymentIdempotencyKey(request, storage, createKey);
  const retry = await getInvoicePaymentIdempotencyKey(request, storage, createKey);
  assert.equal(retry, first);
  assert.equal(generated, 1);
});

test("creates a distinct key when payment details change", async () => {
  const storage = memoryStorage();
  let generated = 0;
  const createKey = () => `attempt-${++generated}`;
  const original = await getInvoicePaymentIdempotencyKey(request, storage, createKey);
  const changedAmount = await getInvoicePaymentIdempotencyKey(
    { ...request, amount: 126 },
    storage,
    createKey,
  );
  const changedReference = await getInvoicePaymentIdempotencyKey(
    { ...request, reference: "BANKAK-REF-7782" },
    storage,
    createKey,
  );
  assert.notEqual(changedAmount, original);
  assert.notEqual(changedReference, original);
  assert.notEqual(changedReference, changedAmount);
  assert.equal(generated, 3);
});

test("clears only the completed logical payment key", async () => {
  const storage = memoryStorage();
  let generated = 0;
  const createKey = () => `attempt-${++generated}`;
  const first = await getInvoicePaymentIdempotencyKey(request, storage, createKey);
  await clearInvoicePaymentIdempotencyKey(request, storage);
  const next = await getInvoicePaymentIdempotencyKey(request, storage, createKey);
  assert.notEqual(next, first);
  assert.equal(generated, 2);
});

test("persists only an opaque request fingerprint and idempotency key", async () => {
  const storage = memoryStorage();
  await getInvoicePaymentIdempotencyKey(request, storage, () => "opaque-key");
  const [[storageKey, value]] = storage.entries();
  assert.match(storageKey, /^roshan:invoice-payment-idempotency:invoice-001:[a-f0-9]{64}$/);
  assert.equal(value, "opaque-key");
  assert.doesNotMatch(storageKey, /BANKAK-REF-7781|125\.5/);
});
