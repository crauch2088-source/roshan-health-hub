import assert from "node:assert/strict";
import test from "node:test";

import { matchMedicationProtocol } from "../src/lib/medication-engine/protocol-matcher.ts";

const source = {
  sourceId: "SYNTHETIC-TEST-ONLY",
  issuer: "Synthetic test authority",
  title: "Synthetic protocol fixture",
  edition: "test-1",
  section: "fixture section",
  jurisdiction: "test jurisdiction",
  population: "paediatric",
  setting: "outpatient",
  publishedAt: "2025-01-01",
  retrievedAt: "2026-01-01",
  revalidateBy: "2027-01-01",
  licenseStatus: "verified" as const,
};

const approvals = [
  { role: "gp" as const, actorId: "gp-test-1", approvedAt: "2026-01-02" },
  { role: "pharmacist" as const, actorId: "ph-test-1", approvedAt: "2026-01-03" },
];

const protocol = {
  id: "synthetic-protocol-1",
  version: "1",
  status: "active" as const,
  effectiveFrom: "2026-01-01",
  effectiveTo: null,
  indicationCode: "J18.9",
  setting: "outpatient",
  population: "paediatric",
  jurisdiction: "test jurisdiction",
  medicineId: "synthetic-medicine-1",
  route: "oral",
  minAgeDays: 365,
  maxAgeDays: 3650,
  doseBasis: {
    kind: "mg_per_kg_per_dose" as const,
    amountMgPerKg: 10,
    dosesPerDay: 2,
    maxPerDoseMg: 500,
    maxPerDayMg: 1000,
  },
  source,
  approvals,
};

const context = {
  asOfDate: "2026-11-11",
  indicationCode: "J18.9",
  setting: "outpatient",
  population: "paediatric",
  jurisdiction: "test jurisdiction",
  medicineId: "synthetic-medicine-1",
  ageDays: 730,
  weightKg: 12,
};

test("matches only an active, effective, dual-approved protocol and returns its source", () => {
  const result = matchMedicationProtocol([protocol], context);
  assert.equal(result.status, "recommendation");
  if (result.status !== "recommendation") return;
  assert.equal(result.protocolId, protocol.id);
  assert.equal(result.protocolVersion, "1");
  assert.equal(result.route, "oral");
  assert.equal(result.dose.doseMg, 120);
  assert.equal(result.dose.dailyDoseMg, 240);
  assert.equal(result.source.sourceId, "SYNTHETIC-TEST-ONLY");
});

test("does not infer a protocol from a different indication, setting or medicine", () => {
  assert.deepEqual(matchMedicationProtocol([protocol], { ...context, indicationCode: "A09" }), {
    status: "no_match",
    reason: "no_matching_protocol",
  });
  assert.deepEqual(matchMedicationProtocol([protocol], { ...context, setting: "inpatient" }), {
    status: "no_match",
    reason: "no_matching_protocol",
  });
  assert.deepEqual(
    matchMedicationProtocol([protocol], { ...context, medicineId: "other-medicine" }),
    {
      status: "no_match",
      reason: "no_matching_protocol",
    },
  );
});

test("ignores draft and suspended protocols rather than recommending them", () => {
  assert.deepEqual(matchMedicationProtocol([{ ...protocol, status: "draft" }], context), {
    status: "no_match",
    reason: "no_active_protocol",
  });
  assert.deepEqual(matchMedicationProtocol([{ ...protocol, status: "suspended" }], context), {
    status: "no_match",
    reason: "no_active_protocol",
  });
});

test("does not use future or expired protocol versions", () => {
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, effectiveFrom: "2027-01-01" }], context),
    {
      status: "no_match",
      reason: "outside_effective_dates",
    },
  );
  assert.deepEqual(matchMedicationProtocol([{ ...protocol, effectiveTo: "2026-01-01" }], context), {
    status: "no_match",
    reason: "outside_effective_dates",
  });
});

test("requires age when the protocol defines an age range", () => {
  assert.deepEqual(matchMedicationProtocol([protocol], { ...context, ageDays: null }), {
    status: "needs_data",
    protocolId: protocol.id,
    protocolVersion: "1",
    missing: ["age_days"],
    source,
  });
});

test("requires measured weight for a weight-based protocol and never falls back", () => {
  assert.deepEqual(matchMedicationProtocol([protocol], { ...context, weightKg: null }), {
    status: "needs_data",
    protocolId: protocol.id,
    protocolVersion: "1",
    missing: ["weight_kg"],
    source,
  });
});

test("blocks protocols without both GP and pharmacist approval", () => {
  assert.deepEqual(matchMedicationProtocol([{ ...protocol, approvals: [approvals[0]] }], context), {
    status: "blocked",
    reason: "missing_dual_approval",
  });
});

test("blocks unverified or incomplete source provenance", () => {
  assert.deepEqual(
    matchMedicationProtocol(
      [{ ...protocol, source: { ...source, licenseStatus: "unverified" } }],
      context,
    ),
    {
      status: "blocked",
      reason: "invalid_protocol_provenance",
    },
  );
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, source: { ...source, section: "" } }], context),
    {
      status: "blocked",
      reason: "invalid_protocol_provenance",
    },
  );
});

test("blocks ambiguous active protocols instead of selecting one arbitrarily", () => {
  assert.deepEqual(
    matchMedicationProtocol([protocol, { ...protocol, id: "synthetic-protocol-2" }], context),
    {
      status: "blocked",
      reason: "ambiguous_active_protocols",
    },
  );
});

test("does not match patients outside the protocol age range", () => {
  assert.deepEqual(matchMedicationProtocol([protocol], { ...context, ageDays: 3651 }), {
    status: "no_match",
    reason: "outside_age_range",
  });
});

test("blocks invalid protocol arithmetic rather than producing a recommendation", () => {
  assert.deepEqual(
    matchMedicationProtocol(
      [{ ...protocol, doseBasis: { ...protocol.doseBasis, dosesPerDay: 0 } }],
      context,
    ),
    {
      status: "blocked",
      reason: "invalid_protocol_rule",
    },
  );
});

test("allows fixed-dose protocols without a weight measurement", () => {
  const fixed = {
    ...protocol,
    doseBasis: { kind: "fixed" as const, amountMg: 250, dosesPerDay: 2 },
  };
  const result = matchMedicationProtocol([fixed], { ...context, weightKg: null });
  assert.equal(result.status, "recommendation");
  if (result.status !== "recommendation") return;
  assert.equal(result.dose.doseMg, 250);
});

test("rejects invalid context dates and malformed patient measurements", () => {
  assert.deepEqual(matchMedicationProtocol([protocol], { ...context, asOfDate: "2026-02-31" }), {
    status: "blocked",
    reason: "invalid_context",
  });
  assert.deepEqual(matchMedicationProtocol([protocol], { ...context, ageDays: -1 }), {
    status: "blocked",
    reason: "invalid_context",
  });
  assert.deepEqual(matchMedicationProtocol([protocol], { ...context, weightKg: -1 }), {
    status: "blocked",
    reason: "invalid_patient_data",
  });
});

test("requires GP and pharmacist approvals from two distinct human actors", () => {
  const sharedActorApprovals = [
    { role: "gp" as const, actorId: "shared-clinician", approvedAt: "2026-01-02" },
    { role: "pharmacist" as const, actorId: "shared-clinician", approvedAt: "2026-01-03" },
  ];
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, approvals: sharedActorApprovals }], context),
    {
      status: "blocked",
      reason: "missing_dual_approval",
    },
  );
});

test("ignores malformed approval entries without throwing or granting approval", () => {
  const malformedApprovals = [null, approvals[0]] as never;
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, approvals: malformedApprovals }], context),
    {
      status: "blocked",
      reason: "missing_dual_approval",
    },
  );
});

test("blocks a protocol whose cited source setting differs from the protocol setting", () => {
  assert.deepEqual(
    matchMedicationProtocol(
      [{ ...protocol, source: { ...source, setting: "inpatient" } }],
      context,
    ),
    {
      status: "blocked",
      reason: "invalid_protocol_provenance",
    },
  );
});

test("treats actor identifiers case-insensitively when enforcing distinct approvers", () => {
  const sameActorDifferentCase = [
    { role: "gp" as const, actorId: "Clinician-A", approvedAt: "2026-01-02" },
    { role: "pharmacist" as const, actorId: "clinician-a", approvedAt: "2026-01-03" },
  ];
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, approvals: sameActorDifferentCase }], context),
    {
      status: "blocked",
      reason: "missing_dual_approval",
    },
  );
});

test("fails closed when the protocol collection is not an array", () => {
  assert.deepEqual(matchMedicationProtocol(null as never, context), {
    status: "blocked",
    reason: "invalid_context",
  });
});

test("blocks a source whose population or jurisdiction differs from the protocol", () => {
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, source: { ...source, population: "adult" } }], context),
    { status: "blocked", reason: "invalid_protocol_provenance" },
  );
  assert.deepEqual(
    matchMedicationProtocol(
      [{ ...protocol, source: { ...source, jurisdiction: "another jurisdiction" } }],
      context,
    ),
    { status: "blocked", reason: "invalid_protocol_provenance" },
  );
});

test("does not match a protocol outside the explicit patient population or jurisdiction", () => {
  const expected = {
    status: "no_match",
    reason: "no_matching_protocol",
  };
  assert.deepEqual(
    matchMedicationProtocol([protocol], { ...context, population: "adult" }),
    expected,
  );
  assert.deepEqual(
    matchMedicationProtocol([protocol], { ...context, jurisdiction: "another jurisdiction" }),
    expected,
  );
});

test("requires explicit population and jurisdiction context", () => {
  const expected = {
    status: "blocked",
    reason: "invalid_context",
  };
  assert.deepEqual(
    matchMedicationProtocol([protocol], { ...context, population: "" }),
    expected,
  );
  assert.deepEqual(
    matchMedicationProtocol([protocol], { ...context, jurisdiction: "" }),
    expected,
  );
});

test("does not return needs_data for a protocol with an invalid dose basis or missing route", () => {
  const invalidRule = {
    status: "blocked",
    reason: "invalid_protocol_rule",
  };
  const invalidProvenance = {
    status: "blocked",
    reason: "invalid_protocol_provenance",
  };
  assert.deepEqual(
    matchMedicationProtocol(
      [{ ...protocol, doseBasis: { kind: "unknown" } as never }],
      { ...context, ageDays: null },
    ),
    invalidRule,
  );
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, route: "" }], { ...context, ageDays: null }),
    invalidProvenance,
  );
});

test("blocks a malformed source object before either recommendation or needs_data", () => {
  const expected = {
    status: "blocked",
    reason: "invalid_protocol_provenance",
  };
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, source: null as never }], context),
    expected,
  );
});

test("does not allow an unverified or malformed source to pass the evidence gate", () => {
  assert.deepEqual(
    matchMedicationProtocol(
      [{ ...protocol, source: { ...source, licenseStatus: "unverified" } as never }],
      context,
    ),
    {
      status: "blocked",
      reason: "invalid_protocol_provenance",
    },
  );
});

test("blocks a source whose revalidation deadline has passed", () => {
  const expected = {
    status: "blocked",
    reason: "invalid_protocol_provenance",
  };
  assert.deepEqual(
    matchMedicationProtocol(
      [{ ...protocol, source: { ...source, revalidateBy: "2026-11-10" } }],
      context,
    ),
    expected,
  );
});

test("blocks source provenance without an explicit revalidation deadline", () => {
  const { revalidateBy: _revalidateBy, ...sourceWithoutDeadline } = source;
  const expected = {
    status: "blocked",
    reason: "invalid_protocol_provenance",
  };
  assert.deepEqual(
    matchMedicationProtocol([{ ...protocol, source: sourceWithoutDeadline as never }], context),
    expected,
  );
});

test("blocks a source retrieved before its stated publication date", () => {
  const expected = {
    status: "blocked",
    reason: "invalid_protocol_provenance",
  };
  assert.deepEqual(
    matchMedicationProtocol(
      [
        {
          ...protocol,
          source: { ...source, publishedAt: "2026-02-01", retrievedAt: "2026-01-01" },
        },
      ],
      context,
    ),
    expected,
  );
});
