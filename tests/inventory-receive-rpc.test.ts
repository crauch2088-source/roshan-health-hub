import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import testRunner from "node:test";
import {
  buildMedicineCatalogueInsert,
  buildMedicineCatalogueIdentityUpdate,
  buildMedicineCatalogueSearchFilter,
  updateMedicineCatalogueIdentityEditorState,
} from "../src/lib/medicine-catalogue.ts";

const source = readFileSync(
  new URL("../src/routes/_authenticated/inventory.tsx", import.meta.url),
  "utf8",
);
const medicineAuditSql = readFileSync(
  new URL("../db/roshan_phase39_permissions_lab_catalog_and_audit_closure.sql", import.meta.url),
  "utf8",
);
const medicineRlsSql = readFileSync(
  new URL(
    "../docs/recovered-migrations/sql/20260818234039_harden_rls_permissions_and_public_grants_v1.sql",
    import.meta.url,
  ),
  "utf8",
);

testRunner("inventory receiving uses the atomic guarded pharmacy RPC", () => {
  assert.doesNotMatch(
    source,
    /\.rpc\(["']fn_receive_pharmacy_batch["']/,
    "the legacy non-idempotent receive RPC must not be called by the client",
  );
  assert.match(
    source,
    /\.rpc\(["']fn_receive_pharmacy_batch_atomic["']/,
    "batch receipt must call the server-side atomic RPC",
  );
  assert.match(source, /p_idempotency_key:\s*idempotencyKey/);
  assert.match(source, /setActiveTab\("batches"\)/);
  assert.match(source, /initialMedicineId=\{pendingReceiveMedicineId\}/);
  assert.match(source, /purchase_price"\)\}>\s*<Input\s+type="number"\s+min="0"\s+step="0\.01"/s);
  assert.match(source, /selling_price"\)\}>\s*<Input\s+type="number"\s+min="0"\s+step="0\.01"/s);
  assert.doesNotMatch(
    source,
    /supabase\s*\.from\(["']pharmacy_inventory["']\)\s*\.insert\s*\(/,
    "batch receipt must not insert inventory rows directly from the client",
  );
  assert.doesNotMatch(
    source,
    /supabase\s*\.from\(["']stock_movements["']\)\s*\.insert\s*\(/,
    "batch receipt must not write stock movements separately from the inventory transaction",
  );
  assert.doesNotMatch(
    source,
    /supabase\s*\.from\(["']medicines["']\)\s*\.update\s*\(\s*\{\s*stock_quantity/,
    "batch receipt must not update stock totals separately from the inventory transaction",
  );
});

testRunner(
  "medicine catalogue requires ingredient, exact strength and dosage form without inferring a route",
  () => {
    const result = buildMedicineCatalogueInsert({
      name: "",
      generic_name: "  amoxicillin  ",
      brand_name: "  Amoxil ",
      strength: " 500 mg ",
      dosage_form: "capsule",
      custom_dosage_form: "",
      unit: " strip ",
      cost_price: "12.50",
      selling_price: "15",
      reorder_level: "8",
    });
    assert.ok("data" in result);
    assert.deepEqual(result, {
      data: {
        name: "Amoxil 500 mg capsule",
        generic_name: "amoxicillin",
        brand_name: "Amoxil",
        strength: "500 mg",
        dosage_form: "capsule",
        unit: "strip",
        cost_price: 12.5,
        selling_price: 15,
        stock_quantity: 0,
        reorder_level: 8,
        expiry_date: null,
        batch_number: null,
      },
    });
    assert.equal("route" in result.data, false);
    assert.deepEqual(
      buildMedicineCatalogueInsert({
        name: "x",
        generic_name: " ",
        brand_name: "",
        strength: "500 mg",
        dosage_form: "tablet",
        custom_dosage_form: "",
        unit: "",
        cost_price: "0",
        selling_price: "0",
        reorder_level: "0",
      }),
      { error: "missing-generic-name" },
    );
    assert.deepEqual(
      buildMedicineCatalogueInsert({
        name: "x",
        generic_name: "drug",
        brand_name: "",
        strength: " ",
        dosage_form: "tablet",
        custom_dosage_form: "",
        unit: "",
        cost_price: "0",
        selling_price: "0",
        reorder_level: "0",
      }),
      { error: "missing-strength" },
    );
    assert.deepEqual(
      buildMedicineCatalogueInsert({
        name: "x",
        generic_name: "drug",
        brand_name: "",
        strength: "500 mg",
        dosage_form: "",
        custom_dosage_form: "",
        unit: "",
        cost_price: "0",
        selling_price: "0",
        reorder_level: "0",
      }),
      { error: "missing-dosage-form" },
    );
  },
);

testRunner(
  "medicine catalogue supports a custom dosage form and rejects invalid numeric metadata",
  () => {
    const base = {
      name: "",
      generic_name: "drug",
      brand_name: "",
      strength: "1%",
      dosage_form: "other",
      custom_dosage_form: " nasal spray ",
      unit: "",
      cost_price: "0",
      selling_price: "0",
      reorder_level: "0",
    };
    const custom = buildMedicineCatalogueInsert(base);
    assert.ok("data" in custom);
    assert.equal(custom.data.dosage_form, "nasal spray");
    assert.deepEqual(buildMedicineCatalogueInsert({ ...base, custom_dosage_form: " " }), {
      error: "missing-custom-dosage-form",
    });
    assert.deepEqual(buildMedicineCatalogueInsert({ ...base, cost_price: "-1" }), {
      error: "invalid-cost-price",
    });
    assert.deepEqual(buildMedicineCatalogueInsert({ ...base, selling_price: "NaN" }), {
      error: "invalid-selling-price",
    });
    assert.deepEqual(buildMedicineCatalogueInsert({ ...base, reorder_level: "1.5" }), {
      error: "invalid-reorder-level",
    });
  },
);

testRunner(
  "medicine catalogue search covers product identity fields and sanitizes PostgREST filters",
  () => {
    const term = " amox%,(x)*_" + "\\" + "'" + '"' + " ";
    const expectedFilter = [
      "name.ilike.%amox x%",
      "generic_name.ilike.%amox x%",
      "brand_name.ilike.%amox x%",
      "strength.ilike.%amox x%",
      "dosage_form.ilike.%amox x%",
    ].join(",");
    assert.equal(buildMedicineCatalogueSearchFilter(term), expectedFilter);
    assert.equal(buildMedicineCatalogueSearchFilter("a"), null);
    assert.match(source, /buildMedicineCatalogueSearchFilter\(search\)/);
    assert.match(source, /generic_name, brand_name, strength, dosage_form/);
    assert.match(source, /medicine_identity_hint/);
    assert.match(source, /inventory_unit_hint/);
  },
);

testRunner(
  "medicine identity updates whitelist product fields and never alter stock or commercial metadata",
  () => {
    const result = buildMedicineCatalogueIdentityUpdate({
      name: "",
      generic_name: "  amoxicillin  ",
      brand_name: " Amoxil ",
      strength: " 500 mg ",
      dosage_form: "capsule",
      custom_dosage_form: "",
    });
    assert.deepEqual(result, {
      data: {
        name: "Amoxil 500 mg capsule",
        generic_name: "amoxicillin",
        brand_name: "Amoxil",
        strength: "500 mg",
        dosage_form: "capsule",
      },
    });
    assert.ok("data" in result);
    assert.deepEqual(Object.keys(result.data).sort(), [
      "brand_name",
      "dosage_form",
      "generic_name",
      "name",
      "strength",
    ]);
  },
);

testRunner("medicine identity update validates custom form and required product fields", () => {
  const base = {
    name: "",
    generic_name: "drug",
    brand_name: "",
    strength: "1%",
    dosage_form: "other",
    custom_dosage_form: " nasal spray ",
  };
  assert.deepEqual(buildMedicineCatalogueIdentityUpdate(base), {
    data: {
      name: "drug 1% nasal spray",
      generic_name: "drug",
      brand_name: null,
      strength: "1%",
      dosage_form: "nasal spray",
    },
  });
  assert.deepEqual(buildMedicineCatalogueIdentityUpdate({ ...base, custom_dosage_form: " " }), {
    error: "missing-custom-dosage-form",
  });
  assert.deepEqual(buildMedicineCatalogueIdentityUpdate({ ...base, generic_name: " " }), {
    error: "missing-generic-name",
  });
  assert.deepEqual(buildMedicineCatalogueIdentityUpdate({ ...base, strength: " " }), {
    error: "missing-strength",
  });
});

testRunner("editing any medicine identity field invalidates physical-pack confirmation", () => {
  const base = {
    name: "Amoxil 500 mg capsule",
    generic_name: "amoxicillin",
    brand_name: "Amoxil",
    strength: "500 mg",
    dosage_form: "capsule",
    custom_dosage_form: "",
  };
  const current = { draft: base, packChecked: true };
  const patches = [
    { name: "Amoxil 250 mg capsule" },
    { generic_name: "amoxicillin trihydrate" },
    { brand_name: "Amoxil Forte" },
    { strength: "250 mg" },
    { dosage_form: "tablet" },
    { custom_dosage_form: "nasal spray" },
  ];

  for (const patch of patches) {
    const next = updateMedicineCatalogueIdentityEditorState(current, patch);
    assert.deepEqual(next, { draft: { ...base, ...patch }, packChecked: false });
  }

  for (const field of [
    "name",
    "generic_name",
    "brand_name",
    "strength",
    "dosage_form",
    "custom_dosage_form",
  ]) {
    assert.match(
      source,
      new RegExp("updateIdentityField\\(\\{[^}]*\\s" + field + ":"),
      field + " edits must invalidate the physical-pack acknowledgement",
    );
  }
});

testRunner(
  "medicine identity editing is permission-gated, pack-confirmed and covered by existing RLS/audit controls",
  () => {
    assert.match(source, /can\("pharmacy\.update"\)/);
    assert.match(source, /if \(!packChecked\)/);
    assert.match(source, /medicine_identity_shared_hint/);
    assert.match(source, /buildMedicineCatalogueIdentityUpdate\(vars\.draft\)/);
    assert.match(source, /\.update\(result\.data\)/);
    assert.match(source, /\.eq\("id", vars\.id\)/);
    assert.match(source, /\.is\("deleted_at", null\)/);
    assert.match(
      medicineRlsSql,
      /CREATE POLICY medicines_update ON public\.medicines FOR UPDATE TO authenticated USING \(\(SELECT public\.app_has_perm\('pharmacy\.update'\)\)\) WITH CHECK \(\(SELECT public\.app_has_perm\('pharmacy\.update'\)\)\)/,
    );
    assert.match(medicineAuditSql, /'medicines'/);
    assert.match(medicineAuditSql, /trigger_name := 'trg_audit_'\|\|table_name/);
    assert.match(medicineAuditSql, /EXECUTE FUNCTION public\.audit_row_change\(\)/);
  },
);
