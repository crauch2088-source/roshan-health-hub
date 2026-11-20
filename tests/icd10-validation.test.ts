import assert from "node:assert/strict";
import { test } from "node:test";
import {
  createIcd10Dataset,
  isSyntacticallyValidIcd10Format,
  searchIcd10Dataset,
  validateDiagnosisAgainstDataset,
} from "../src/lib/icd10-validation.ts";

const whoFixture = createIcd10Dataset(
  {
    classificationId: "WHO-ICD10",
    version: "2019-synthetic-fixture",
    effectiveDate: "2020-01-01",
    sourceName: "Synthetic test fixture (pending clinical classification approval)",
    licenseNote: "Test fixture only",
  },
  [
    {
      code: "U07.1",
      titleEn: "COVID-19, virus identified",
      titleAr: "كوفيد-19، الفيروس محدد",
      arabicReviewed: true,
      isActive: true,
      effectiveFrom: "2020-02-01",
    },
    {
      code: "J06.9",
      titleEn: "Acute upper respiratory infection, unspecified",
      titleAr: "عدوى حادة في الجهاز التنفسي العلوي غير محددة",
      arabicReviewed: true,
      isActive: true,
    },
    {
      code: "A99.9",
      titleEn: "Deprecated synthetic test code",
      isActive: false,
    },
    {
      code: "E11.9",
      titleEn: "Type 2 diabetes mellitus without complications",
      titleAr: "مسودة غير مراجعة",
      arabicReviewed: false,
      isActive: true,
      effectiveFrom: "2020-01-01",
      effectiveTo: "2025-12-31",
    },
  ],
);

const altClassificationFixture = createIcd10Dataset(
  {
    classificationId: "ALT-ICD10-SUBSET",
    version: "2025-synthetic-fixture",
    effectiveDate: "2025-01-01",
    sourceName: "Alternate synthetic subset",
    licenseNote: "Test fixture only",
  },
  [
    {
      code: "J06.9",
      titleEn: "Acute upper respiratory infection, unspecified",
      isActive: true,
    },
  ],
);

test("accepts valid WHO U-category code U07.1 when present in active dataset", () => {
  assert.equal(isSyntacticallyValidIcd10Format("u07.1"), true);
  const res = validateDiagnosisAgainstDataset(
    {
      narrative: "Confirmed respiratory viral infection",
      certainty: "confirmed",
      icd10Code: "u07.1",
      referenceDate: "2026-11-20",
    },
    whoFixture,
  );
  assert.equal(res.valid, true);
  assert.equal(res.normalizedCode, "U07.1");
  assert.equal(res.classificationId, "WHO-ICD10");
  assert.equal(res.matchedRecord?.code, "U07.1");
});

test("rejects syntactically valid code that does not exist in selected dataset (regex alone is insufficient)", () => {
  assert.equal(isSyntacticallyValidIcd10Format("Z99.8"), true);
  const res = validateDiagnosisAgainstDataset(
    {
      narrative: "Uncatalogued code test",
      certainty: "confirmed",
      icd10Code: "Z99.8",
    },
    whoFixture,
  );
  assert.equal(res.valid, false);
  assert.equal(res.errorCode, "code_not_in_dataset");
});

test("distinguishes codes valid in one classification from another", () => {
  const inWho = validateDiagnosisAgainstDataset(
    { narrative: "Viral illness", certainty: "confirmed", icd10Code: "U07.1" },
    whoFixture,
  );
  const inAlt = validateDiagnosisAgainstDataset(
    { narrative: "Viral illness", certainty: "confirmed", icd10Code: "U07.1" },
    altClassificationFixture,
  );
  assert.equal(inWho.valid, true);
  assert.equal(inAlt.valid, false);
  assert.equal(inAlt.errorCode, "code_not_in_dataset");
});

test("rejects inactive codes and codes outside effective date window", () => {
  const inactive = validateDiagnosisAgainstDataset(
    { narrative: "Old diagnosis", certainty: "confirmed", icd10Code: "A99.9" },
    whoFixture,
  );
  assert.equal(inactive.valid, false);
  assert.equal(inactive.errorCode, "code_inactive");

  const expired = validateDiagnosisAgainstDataset(
    {
      narrative: "Diabetes follow-up",
      certainty: "confirmed",
      icd10Code: "E11.9",
      referenceDate: "2026-11-20",
    },
    whoFixture,
  );
  assert.equal(expired.valid, false);
  assert.equal(expired.errorCode, "code_outside_effective_window");
});

test("preserves narrative and provisional diagnoses without forcing a confirmed code", () => {
  const provisional = validateDiagnosisAgainstDataset(
    { narrative: "Suspected viral fever pending CBC", certainty: "provisional", icd10Code: null },
    whoFixture,
  );
  assert.equal(provisional.valid, true);
  assert.equal(provisional.normalizedCode, null);

  const confirmedWithoutCode = validateDiagnosisAgainstDataset(
    { narrative: "Fever", certainty: "confirmed", icd10Code: "" },
    whoFixture,
  );
  assert.equal(confirmedWithoutCode.valid, false);
  assert.equal(confirmedWithoutCode.errorCode, "confirmed_requires_code");
});

test("searches bilingual dataset while excluding unreviewed Arabic labels", () => {
  const arReviewed = searchIcd10Dataset(whoFixture, "التنفسي");
  assert.equal(arReviewed.length, 1);
  assert.equal(arReviewed[0]?.code, "J06.9");

  const arUnreviewed = searchIcd10Dataset(whoFixture, "مسودة");
  assert.equal(arUnreviewed.length, 0);
});
