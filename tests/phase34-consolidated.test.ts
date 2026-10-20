import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import {
  assertClinicalStoragePath,
  buildClinicalStoragePath,
  validateClinicalFileMetadata,
} from "../src/lib/storage-path.ts";
import { verifyLabOrder } from "../src/lib/lab-workflow.ts";

const read = (path: string) => readFileSync(new URL(path, import.meta.url), "utf8");
const branchId = "00000000-0000-0000-0000-000000003301";

test("storage paths encode branch, typed entity and safe filename", () => {
  const path = buildClinicalStoragePath({
    branchId,
    bucket: "roshan-lab-reports",
    entityId: "00000000-0000-0000-0000-000000003361",
    filename: "CBC report.pdf",
  });
  assert.equal(path, branchId + "/lab-reports/00000000-0000-0000-0000-000000003361/CBC-report.pdf");
  assertClinicalStoragePath("roshan-lab-reports", path);
  assert.throws(() =>
    buildClinicalStoragePath({
      branchId: "not-a-uuid",
      bucket: "roshan-lab-reports",
      entityId: "1",
      filename: "x.pdf",
    }),
  );
  assert.throws(() =>
    buildClinicalStoragePath({
      branchId,
      bucket: "roshan-lab-reports",
      entityId: "../other",
      filename: "x.pdf",
    }),
  );
  assert.throws(() => assertClinicalStoragePath("roshan-medical-certificates", path));
});

test("clinical storage helper rejects unsafe MIME types and oversized files", () => {
  validateClinicalFileMetadata({ type: "application/pdf", size: 1024 }, "roshan-lab-reports");
  validateClinicalFileMetadata({ type: "image/jpeg", size: 1024 }, "roshan-clinical-attachments");
  assert.throws(() =>
    validateClinicalFileMetadata({ type: "image/webp", size: 100 }, "roshan-clinical-attachments"),
  );
  assert.throws(() =>
    validateClinicalFileMetadata(
      { type: "application/pdf", size: 10 * 1024 * 1024 + 1 },
      "roshan-lab-reports",
    ),
  );
});

test("lab verification calls only the atomic RPC and surfaces server errors", async () => {
  let called: unknown;
  await verifyLabOrder("order-1", async (args) => {
    called = args;
    return { error: null };
  });
  assert.deepEqual(called, { p_order_id: "order-1" });
  await assert.rejects(
    verifyLabOrder("order-1", async () => ({ error: { message: "permission denied" } })),
    /permission denied/,
  );
  await assert.rejects(
    verifyLabOrder(" ", async () => ({ error: null })),
    /required/,
  );
});

test("Realtime hook uses branch topics, targeted invalidation and quiet fallback", () => {
  const realtime = read("../src/lib/realtime.ts");
  assert.match(realtime, /postgres_changes/);
  assert.match(realtime, /branch:/);
  assert.match(realtime, /invalidateQueries/);
  assert.match(realtime, /45_000/);
  assert.doesNotMatch(realtime, /toast\(|sonner/);
});

test("private storage helper signs short-lived URLs and never returns public URLs", () => {
  const storage = read("../src/lib/storage.ts");
  assert.match(storage, /createSignedUrl/);
  assert.match(storage, /uploadClinicalFile/);
  assert.match(storage, /assertClinicalStoragePath/);
  assert.doesNotMatch(storage, /getPublicUrl/);
});

test("Phase 34 lab verification and Realtime default on; direct Storage upload remains opt-in", () => {
  const lab = read("../src/routes/_authenticated/lab_.$orderId.tsx");
  const realtime = read("../src/lib/realtime.ts");
  const storage = read("../src/lib/storage.ts");
  assert.match(lab, /VITE_ROSHAN_PHASE34_ENABLED.*!== "false"/);
  assert.match(lab, /!phase34Enabled/);
  assert.match(realtime, /VITE_ROSHAN_PHASE34_ENABLED.*!== "false"/);
  assert.match(realtime, /consultation-visit/);
  assert.match(realtime, /certificate-visits/);
  assert.match(storage, /VITE_ROSHAN_STORAGE_DIRECT_UPLOAD_ENABLED.*!== "true"/);
  assert.match(storage, /Direct clinical file uploads are disabled/);
});

test("Phase 36 Realtime invalidates pharmacy and billing query keys", () => {
  const realtime = read("../src/lib/realtime.ts");
  const pharmacy = read("../src/routes/_authenticated/pharmacy.tsx");
  const billing = read("../src/routes/_authenticated/billing.tsx");
  assert.match(realtime, /subscribe\("pharmacy", "prescriptions"\)/);
  assert.match(realtime, /subscribe\("billing", "invoices"\)/);
  assert.match(realtime, /\["pharmacy-queue"\]/);
  assert.match(realtime, /\["billing"\]/);
  assert.match(pharmacy, /useBranchRealtime/);
  assert.match(billing, /useBranchRealtime/);
});

test("Phase 36 lab and certificate screens preserve the opt-in private storage contract", () => {
  const lab = read("../src/routes/_authenticated/lab_.$orderId.tsx");
  const certificates = read("../src/routes/_authenticated/certificates.tsx");
  const storage = read("../src/lib/storage.ts");
  for (const screen of [lab, certificates]) {
    assert.match(screen, /VITE_ROSHAN_STORAGE_DIRECT_UPLOAD_ENABLED/);
    assert.match(screen, /buildClinicalStoragePath/);
    assert.match(screen, /createClinicalSignedUrl/);
    assert.match(screen, /uploadClinicalFile/);
  }
  assert.match(storage, /createSignedUrl/);
  assert.match(storage, /VITE_ROSHAN_STORAGE_DIRECT_UPLOAD_ENABLED/);
});
