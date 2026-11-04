export type MedicineCatalogueDraft = {
  name: string;
  generic_name: string;
  brand_name: string;
  strength: string;
  dosage_form: string;
  custom_dosage_form: string;
  unit: string;
  cost_price: string;
  selling_price: string;
  reorder_level: string;
};

export type MedicineCatalogueIdentityDraft = Pick<
  MedicineCatalogueDraft,
  "name" | "generic_name" | "brand_name" | "strength" | "dosage_form" | "custom_dosage_form"
>;

export type MedicineCatalogueIdentityBuildResult =
  | {
      data: {
        name: string;
        generic_name: string;
        brand_name: string | null;
        strength: string;
        dosage_form: string;
      };
    }
  | {
      error:
        | "missing-generic-name"
        | "missing-strength"
        | "missing-dosage-form"
        | "missing-custom-dosage-form";
    };

type MedicineCatalogueInsert = {
  name: string;
  generic_name: string;
  brand_name: string | null;
  strength: string;
  dosage_form: string;
  unit: string | null;
  cost_price: number;
  selling_price: number;
  stock_quantity: 0;
  reorder_level: number;
  expiry_date: null;
  batch_number: null;
};

export type MedicineCatalogueBuildResult =
  | { data: MedicineCatalogueInsert }
  | {
      error:
        | "missing-generic-name"
        | "missing-strength"
        | "missing-dosage-form"
        | "missing-custom-dosage-form"
        | "invalid-cost-price"
        | "invalid-selling-price"
        | "invalid-reorder-level";
    };

function parseNonNegativeNumber(value: string): number | null {
  if (!value.trim()) return null;
  const parsed = Number(value);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : null;
}

export function buildMedicineCatalogueInsert(
  draft: MedicineCatalogueDraft,
): MedicineCatalogueBuildResult {
  const genericName = draft.generic_name.trim();
  if (!genericName) return { error: "missing-generic-name" };

  const strength = draft.strength.trim();
  if (!strength) return { error: "missing-strength" };

  const selectedForm = draft.dosage_form.trim();
  if (!selectedForm) return { error: "missing-dosage-form" };
  const dosageForm = selectedForm === "other" ? draft.custom_dosage_form.trim() : selectedForm;
  if (!dosageForm) return { error: "missing-custom-dosage-form" };

  const costPrice = parseNonNegativeNumber(draft.cost_price);
  if (costPrice == null) return { error: "invalid-cost-price" };
  const sellingPrice = parseNonNegativeNumber(draft.selling_price);
  if (sellingPrice == null) return { error: "invalid-selling-price" };
  const reorderLevel = parseNonNegativeNumber(draft.reorder_level);
  if (reorderLevel == null || !Number.isInteger(reorderLevel)) {
    return { error: "invalid-reorder-level" };
  }

  const brandName = draft.brand_name.trim();
  const displayBase = brandName || genericName;
  const generatedName = [displayBase, strength, dosageForm].filter(Boolean).join(" ");

  return {
    data: {
      name: draft.name.trim() || generatedName,
      generic_name: genericName,
      brand_name: brandName || null,
      strength,
      dosage_form: dosageForm,
      unit: draft.unit.trim() || null,
      cost_price: costPrice,
      selling_price: sellingPrice,
      stock_quantity: 0,
      reorder_level: reorderLevel,
      expiry_date: null,
      batch_number: null,
    },
  };
}

/**
 * Build a strict identity-only update. Stock, packaging unit, prices and reorder
 * settings are intentionally excluded from this write contract.
 */
export function buildMedicineCatalogueIdentityUpdate(
  draft: MedicineCatalogueIdentityDraft,
): MedicineCatalogueIdentityBuildResult {
  const genericName = draft.generic_name.trim();
  if (!genericName) return { error: "missing-generic-name" };

  const strength = draft.strength.trim();
  if (!strength) return { error: "missing-strength" };

  const selectedForm = draft.dosage_form.trim();
  if (!selectedForm) return { error: "missing-dosage-form" };
  const dosageForm = selectedForm === "other" ? draft.custom_dosage_form.trim() : selectedForm;
  if (!dosageForm) return { error: "missing-custom-dosage-form" };

  const brandName = draft.brand_name.trim();
  const displayBase = brandName || genericName;
  const generatedName = [displayBase, strength, dosageForm].join(" ");

  return {
    data: {
      name: draft.name.trim() || generatedName,
      generic_name: genericName,
      brand_name: brandName || null,
      strength,
      dosage_form: dosageForm,
    },
  };
}

/** Safe PostgREST OR filter for the medicine catalogue's searchable identity fields. */
export function buildMedicineCatalogueSearchFilter(term: string): string | null {
  const clean = term
    .replace(/[(),*%_\\'"]/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (clean.length < 2) return null;

  const pattern = "%" + clean + "%";
  return [
    "name.ilike." + pattern,
    "generic_name.ilike." + pattern,
    "brand_name.ilike." + pattern,
    "strength.ilike." + pattern,
    "dosage_form.ilike." + pattern,
  ].join(",");
}
