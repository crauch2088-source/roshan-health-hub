import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import {
  confirmPharmacyHandover,
  cancelDispenseBeforeHandover,
  recordPostHandoverReturn,
  resolveQuarantineDisposition,
  type SupabaseRpcClient,
} from "../src/lib/pharmacy-lifecycle.ts";

const VALID_UUID = "11111111-1111-4111-8111-111111111111";

interface RpcCall {
  fn: string;
  params?: Record<string, unknown>;
}

function createMockClient(
  handler: (fn: string, params?: Record<string, unknown>) => { data: unknown; error: unknown },
): { client: SupabaseRpcClient; calls: RpcCall[] } {
  const calls: RpcCall[] = [];
  const client: SupabaseRpcClient = {
    rpc(fn, params) {
      calls.push({ fn, params });
      return Promise.resolve(handler(fn, params));
    },
  };
  return { client, calls };
}

test("confirmPharmacyHandover invokes confirm_pharmacy_handover RPC with expected params and returns data", async () => {
  const expected = { prescription_id: "rx-1", status: "handed_over" };
  const { client, calls } = createMockClient(() => ({ data: expected, error: null }));

  const result = await confirmPharmacyHandover("rx-1", client);

  assert.deepEqual(result, expected);
  assert.deepEqual(calls, [
    { fn: "confirm_pharmacy_handover", params: { p_prescription_id: "rx-1" } },
])  ;
});

test("cancelDispenseBeforeHandover invokes cancel_dispense_before_handover RPC and validates inputs", async () => {
  const expected = { cancelled: true, idempotency_key: VALID_UUID };
  const { client, calls } = createMockClient(() => ({ data: expected, error: null }));

  const result = await cancelDispenseBeforeHandover(
    { prescriptionId: "rx-2", reason: "Patient declined medication", idempotencyKey: VALID_UUID },
    client,
  );

  assert.deepEqual(result, expected);
  assert.deepEqual(calls, [
    {
      fn: "cancel_dispense_before_handover",
      params: {
        p_prescription_id: "rx-2",
        p_reason: "Patient declined medication",
        p_idempotency_key: VALID_UUID,
      },
    },
  ]);

  await assert.rejects(
    () =>
      cancelDispenseBeforeHandover(
        { prescriptionId: "rx-2", reason: "   ", idempotencyKey: VALID_UUID },
        client,
      ),
    /Reason is required\./,
  );

  await assert.rejects(
    () =>
      cancelDispenseBeforeHandover(
        { prescriptionId: "rx-2", reason: "Valid reason", idempotencyKey: "not-a-uuid" },
        client,
      ),
    /Idempotency key must be a valid UUID\./,
  );
});

test("recordPostHandoverReturn invokes record_post_handover_return RPC and validates inputs", async () => {
  const expected = { return_id: "ret-1", quarantined: true };
  const { client, calls } = createMockClient(() => ({ data: expected, error: null }));

  const result = await recordPostHandoverReturn(
    {
      prescriptionId: "rx-3",
      medicineId: "med-1",
      batchId: "batch-1",
      quantity: 2,
      condition: "damaged",
      reason: "Blister pack torn",
      idempotencyKey: VALID_UUID,
    },
    client,
  );

  assert.deepEqual(result, expected);
  assert.deepEqual(calls, [
    {
      fn: "record_post_handover_return",
      params: {
        p_prescription_id: "rx-3",
        p_medicine_id: "med-1",
        p_batch_id: "batch-1",
        p_quantity: 2,
        p_condition: "damaged",
        p_reason: "Blister pack torn",
        p_idempotency_key: VALID_UUID,
      },
    },
  ]);

  await assert.rejects(
    () =>
      recordPostHandoverReturn(
        {
          prescriptionId: "rx-3",
          medicineId: "med-1",
          batchId: "batch-1",
          quantity: 0,
          condition: "damaged",
          reason: "Blister pack torn",
          idempotencyKey: VALID_UUID,
        },
        client,
      ),
    /Return quantity must be a positive number\./,
  );

  await assert.rejects(
    () =>
      recordPostHandoverReturn(
        {
          prescriptionId: "rx-3",
          medicineId: "med-1",
          batchId: "batch-1",
          quantity: 1,
          condition: "damaged",
          reason: "",
          idempotencyKey: VALID_UUID,
        },
        client,
      ),
    /Reason is required\./,
  );

  await assert.rejects(
    () =>
      recordPostHandoverReturn(
        {
          prescriptionId: "rx-3",
          medicineId: "med-1",
          batchId: "batch-1",
          quantity: 1,
          condition: "damaged",
          reason: "Valid reason",
          idempotencyKey: "bad-uuid",
        },
        client,
      ),
    /Idempotency key must be a valid UUID\./,
  );

  await assert.rejects(
    () =>
      recordPostHandoverReturn(
        {
          prescriptionId: "rx-3",
          medicineId: "med-1",
          batchId: "batch-1",
          quantity: 1,
          condition: "melted" as never,
          reason: "Valid reason",
          idempotencyKey: VALID_UUID,
        },
        client,
      ),
    /Invalid return condition/,
  );
});

test("resolveQuarantineDisposition invokes resolve_quarantine_disposition RPC and validates disposition", async () => {
  const expected = { quarantine_id: "q-1", disposition: "approved_restock" };
  const { client, calls } = createMockClient(() => ({ data: expected, error: null }));

  const result = await resolveQuarantineDisposition(
    { quarantineId: "q-1", disposition: "approved_restock", notes: "Sealed box verified" },
    client,
  );

  assert.deepEqual(result, expected);
  assert.deepEqual(calls, [
    {
      fn: "resolve_quarantine_disposition",
      params: {
        p_quarantine_id: "q-1",
        p_disposition: "approved_restock",
        p_notes: "Sealed box verified",
      },
    },
  ]);

  await assert.rejects(
    () =>
      resolveQuarantineDisposition(
        { quarantineId: "q-1", disposition: "invalid_disposition" as never },
        client,
      ),
    /Invalid quarantine disposition/,
  );
});

test("wrappers propagate 42501 unauthorized and cross-branch denial errors", async () => {
  const unauthorized = createMockClient(() => ({
    data: null,
    error: { code: "42501", message: "insufficient_privilege" },
  }));
  const crossBranch = createMockClient(() => ({
    data: null,
    error: { code: "42501", message: "Cross-branch pharmacy operation denied" },
  }));

  await assert.rejects(
    () => confirmPharmacyHandover("rx-1", unauthorized.client),
    /insufficient_privilege \(permission denied by database policy\)/,
  );
  await assert.rejects(
    () =>
      cancelDispenseBeforeHandover(
        { prescriptionId: "rx-1", reason: "Cancel", idempotencyKey: VALID_UUID },
        crossBranch.client,
      ),
    /Cross-branch pharmacy operation denied \(permission denied by database policy\)/,
  );
  await assert.rejects(
    () =>
      recordPostHandoverReturn(
        {
          prescriptionId: "rx-1",
          medicineId: "med-1",
          batchId: "batch-1",
          quantity: 1,
          condition: "opened",
          reason: "Opened",
          idempotencyKey: VALID_UUID,
        },
        unauthorized.client,
      ),
    /permission denied by database policy/,
  );
  await assert.rejects(
    () =>
      resolveQuarantineDisposition(
        { quarantineId: "q-1", disposition: "destroyed_writeoff" },
        crossBranch.client,
      ),
    /Cross-branch pharmacy operation denied \(permission denied by database policy\)/,
  );
});

test(
    "pharmacy route contract uses lifecycle wrappers, role guards, idempotency keys, and no direct table writes", 
  () => {
  const source = readFileSync(resolve(process.cwd(), "src/routes/_authenticated/pharmacy.tsx"), "utf8");

  assert.ok(
    source.includes("@/lib/pharmacy-lifecycle"),
    "Expected pharmacy.tsx to import from @/lib/pharmacy-lifecycle",
    );
  for (const fnName of [
    "confirmPharmacyHandover",
    "cancelDispenseBeforeHandover",
    "recordPostHandoverReturn",
    "resolveQuarantineDisposition",
  ]) {
    assert.match(source, new RegExp(`${fnName}\\s*\\(`), `Expected pharmacy.tsx to call ${fnName}`);
  }

  assert.ok(source.includes("isPharmacist"), "Expected pharmacy.tsx to check isPharmacist");
  assert.ok(
    source.includes('can("pharmacy.update")'), 
    'Expected pharmacy.tsx to check can("pharmacy.update")',
  );
  assert.ok(
    source.includes("idempotencyKey"), 
    "Expected pharmacy.tsx to pass retry-safe idempotencyKey",
  );

  for (const table of [
    "pharmacy_dispense_cancellations",
    "pharmacy_returns",
    "pharmacy_return_quarantine",
    "financial_compensations",
  ]) {
    const directWritePattern = new RegExp(
      `\\.from\\s*\\(\\s*["'\`]${table}["'\`]\\s*\\)\\s*\\.(?:insert|update|upsert|delete)\\s*\\(`,
    );
    assert.equal(
      directWritePattern.test(source),
      false, 
      `Expected no direct table writes to ${table}`,
    );
  }
});
