import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";

const idempotency = readFileSync(new URL("../db/roshan_phase16_billing_idempotency.sql", import.meta.url), "utf8");
const migration = readFileSync(
  new URL("../db/roshan_phase15_manual_invoice_consolidation.sql", import.meta.url),
  "utf8",
);
const billingRoute = readFileSync(
  new URL("../src/routes/_authenticated/billing.tsx", import.meta.url),
  "utf8",
);
const integration = readFileSync(
  new URL("../db/tests/manual_billing_consolidation_integration.sql", import.meta.url),
  "utf8",
);

test("manual billing uses the visit invoice wrapper and cannot bypass it", () => {
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.create_billing_invoice_atomic/);
  assert.match(
    migration,
    /REVOKE ALL ON FUNCTION public\.create_invoice_atomic\(uuid,uuid,date,numeric,jsonb\) FROM PUBLIC, anon, authenticated/,
  );
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.create_billing_invoice_atomic/);
  assert.match(billingRoute, /rpc\("create_billing_invoice_atomic"/);
  assert.doesNotMatch(billingRoute, /rpc\("create_invoice_atomic"/);
  assert.match(billingRoute, /billing-patient-visits/);
  assert.match(billingRoute, /standalone/);
});

test("manual invoice integration proves append-by-default and explicit standalone/secondary invoices", () => {
  assert.match(integration, /manual billing created a second invoice by default/);
  assert.match(integration, /explicit secondary invoice was not created correctly/);
  assert.match(integration, /standalone invoice was not explicit/);
  assert.match(integration, /manual pharmacy line bypassed dispense billing/);
  assert.match(integration, /authenticated can bypass the manual billing wrapper/);
});

test("manual billing reuses a durable request key across retries", () => {
  assert.ok(idempotency.includes("v_operation text := 'create_billing_invoice_atomic'"));
  assert.ok(idempotency.includes("GRANT EXECUTE ON FUNCTION public.create_billing_invoice_atomic(uuid,uuid,uuid,date,numeric,jsonb,boolean,uuid) TO authenticated"));
  assert.ok(billingRoute.includes("p_request_id: requestId"));
  assert.ok(billingRoute.includes("pendingInvoiceRequestRef"));
  assert.ok(billingRoute.includes("crypto.randomUUID()"));
  assert.ok(integration.includes("manual retry duplicated invoice lines"));
});
