/**
 * Roshan AI assistants — the only server functions in the app.
 *
 * Four read-only assistants, one per screen:
 *   1. draftClinicalNote  — proposes a note the clinician must accept
 *   2. askAboutPatient    — answers a question about one patient's own records
 *   3. explainLabOrder    — flags values outside the reference range
 *   4. reviewInvoice      — points out missing or inconsistent billing entries
 *
 * Rules enforced here, in code:
 * - The caller is revalidated with Supabase Auth and must hold the module's
 *   read permission (fail closed).
 * - Records are read with the caller's own token, so RLS applies unchanged.
 * - Nothing is ever written: no insert, update, delete or mutating rpc.
 *   The clinician decides what reaches the record.
 * - Gateway failures come back as a safe message, never a raw provider error.
 */

import { createServerFn } from "@tanstack/react-start";
import { z } from "zod/v3";
import { withinBudget } from "./prompt-utils.ts";

export type AiResult = {
  text: string | null;
  error: string | null;
  /** Parsed note sections, for the clinical-note assistant only. */
  sections?: Record<string, string>;
  /** Record labels the answer was built from, e.g. ["V1","L2"]. */
  sources?: string[];
};

/** Section keys the clinical note form understands. */
export const NOTE_SECTION_KEYS = [
  "chief_complaint",
  "hpi",
  "past_medical_history",
  "drug_history",
  "allergy_history",
  "examination",
  "assessment",
  "plan",
] as const;

const SECTION_HEADINGS: Record<string, string[]> = {
  chief_complaint: ["chief complaint", "chief_complaint", "الشكوى الرئيسية"],
  hpi: ["history of present illness", "hpi", "تاريخ المرض الحالي"],
  past_medical_history: [
    "past medical history",
    "pmh",
    "past_medical_history",
    "التاريخ المرضي السابق",
  ],
  drug_history: ["drug history", "medications", "drug_history", "الأدوية الحالية"],
  allergy_history: ["allergies", "allergy history", "allergy_history", "الحساسيات"],
  examination: ["examination", "physical examination", "examination", "الفحص السريري"],
  assessment: ["assessment", "differential", "assessment", "التقييم"],
  plan: ["plan", "management plan", "plan", "الخطة"],
};

/**
 * Splits the model's reply on `## <heading>` markers. Headings the form does
 * not know are dropped, so a stray section can never write into an unexpected
 * field.
 */
export function parseNoteSections(text: string): Record<string, string> {
  const sections: Record<string, string> = {};
  let current: string | null = null;
  let buffer: string[] = [];

  const flush = () => {
    if (current && buffer.join("\n").trim()) sections[current] = buffer.join("\n").trim();
    buffer = [];
  };

  for (const line of text.split(/\r?\n/)) {
    const heading = /^#{1,3}\s*(.+?)\s*$/i.exec(line.trim());
    if (heading) {
      flush();
      const wanted = (heading[1] ?? "").toLowerCase().replace(/[*_]/g, "").trim();
      current =
        Object.entries(SECTION_HEADINGS).find(([, aliases]) =>
          aliases.some((alias) => wanted === alias || wanted.includes(alias)),
        )?.[0] ?? null;
      continue;
    }
    if (current) buffer.push(line);
  }
  flush();
  return sections;
}

const NOTE_INSTRUCTIONS = [
  "You are a documentation assistant inside Roshan Medical Center's EMR.",
  "You draft a clinical note for a licensed clinician who will edit and approve it.",
  "Never invent findings, values, dates or diagnoses that are not in the data given.",
  "If a section has no support in the data, write exactly: (لا يوجد بيانات)",
  "Write mostly in Arabic, keeping standard medical terms and numbers in Latin script.",
  "Keep it factual, short and in plain clinical language. No disclaimers, no preamble.",
  "Output ONLY these sections, in this order, each on its own `## ` heading:",
  "## Chief complaint",
  "## HPI",
  "## PMH",
  "## Drug history",
  "## Allergies",
  "## Examination",
  "## Assessment",
  "## Plan",
  "Do not write anything before the first heading or after the last section.",
].join("\n");

const PATIENT_QA_INSTRUCTIONS = [
  "You are a record assistant inside Roshan Medical Center's EMR, answering one clinician",
  "about a single patient using only the records listed in the request.",
  "Answer strictly from those records. If the records do not contain the answer, say so plainly.",
  "Never guess, extrapolate, or add general medical advice the clinician did not ask for.",
  "Cite the record labels you actually used, e.g. [V1] [L2] [I3], at the end of each claim.",
  "Keep the answer under 180 words. Use short lines, not long paragraphs.",
  "Reply in the language the question was asked in.",
  "You have no write access. Never state that anything was saved, updated or prescribed.",
].join("\n");

const LAB_INSTRUCTIONS = [
  "You are a laboratory reporting assistant inside Roshan Medical Center's EMR.",
  "Using only the values and reference ranges given, list every result outside its reference",
  "range, with the value, the unit and the range. Say which direction (high/low).",
  "Then give two or three short lines on what pattern the abnormal set suggests,",
  "clearly marked as a reading of the numbers, not a diagnosis.",
  "Never add a result that is not in the data. Never change a value.",
  "If nothing is flagged, say the results are within the given ranges.",
  "Reply in Arabic with the test names and numbers in Latin script.",
  "You have no write access; never state that a result was verified or saved.",
].join("\n");

const BILLING_INSTRUCTIONS = [
  "You are a billing integrity assistant inside Roshan Medical Center's EMR.",
  "Review the invoice, its line items, its payments and any linked claim for entries that are",
  "missing, inconsistent or unusual: totals that do not add up, an unpaid or partially paid",
  "state that conflicts with the payments, a zero or negative amount, a claim whose submitted",
  "amount does not match the invoice net, a locked or voided invoice with activity after it.",
  "Output a short bullet list of concrete issues with the numbers that show them.",
  "If you find nothing, say exactly that. Do not suggest new amounts or write any number",
  "that is not already present in the data. Do not advise on clinical matters.",
  "You have no write access; never state that anything was corrected or saved.",
  "Reply in Arabic, keeping amounts, codes and dates in Latin script.",
].join("\n");

/** Shared failure shape: the UI shows the message, never a raw provider error. */
function failure(error: unknown): AiResult {
  const message = error instanceof Error ? error.message : "The assistant could not run.";
  return { text: null, error: message };
}

const NIL_UUID = "00000000-0000-0000-0000-000000000000";

function asRows(value: unknown): Record<string, unknown>[] {
  return Array.isArray(value) ? (value as Record<string, unknown>[]) : [];
}

// ---------------------------------------------------------------------------
// 1. Clinical note drafting
// ---------------------------------------------------------------------------

const noteInput = z.object({ visitId: z.string().min(1), lang: z.enum(["ar", "en"]) });

export const draftClinicalNote = createServerFn({ method: "POST" })
  .validator(noteInput)
  .handler(async ({ data }): Promise<AiResult> => {
    const { requireAppAccess, renderOne, renderRows, clampText } =
      await import("./data-access.server.ts");
    const { completeAiText, describeAiFailure } = await import("./gateway.server.ts");

    let access;
    try {
      access = await requireAppAccess("visits.read");
    } catch (error) {
      return failure(error);
    }

    const { data: visit } = await access.supabase
      .from("visits")
      .select("*")
      .eq("id", data.visitId)
      .maybeSingle();
    if (!visit) return { text: null, error: "This visit is not available to you." };

    const patientId = (visit as Record<string, unknown>)["patient_id"];
    const [{ data: patientRow }, vitals, note, diagnoses, priorVisits, labs] = await Promise.all([
      patientId
        ? access.supabase.from("patients").select("*").eq("id", patientId).maybeSingle()
        : Promise.resolve({ data: null }),
      access.supabase
        .from("vitals")
        .select("*")
        .eq("visit_id", data.visitId)
        .order("created_at", { ascending: false })
        .limit(1),
      access.supabase
        .from("clinical_notes")
        .select("*")
        .eq("visit_id", data.visitId)
        .is("deleted_at", null)
        .order("created_at", { ascending: false })
        .limit(1),
      access.supabase
        .from("diagnoses")
        .select("diagnosis_name, icd10_code, is_primary")
        .eq("visit_id", data.visitId)
        .is("deleted_at", null)
        .order("created_at"),
      access.supabase
        .from("visits")
        .select("visit_date, status, chief_complaint, departments(name)")
        .eq("patient_id", patientId ?? NIL_UUID)
        .neq("id", data.visitId)
        .order("visit_date", { ascending: false })
        .limit(3),
      access.supabase
        .from("lab_orders")
        .select("status, created_at, lab_order_items(status, lab_tests(name))")
        .eq("patient_id", patientId ?? NIL_UUID)
        .order("created_at", { ascending: false })
        .limit(3),
    ]);

    const currentNote = asRows(note?.data)[0] ?? null;
    const existing = currentNote
      ? NOTE_SECTION_KEYS.map(
          (key) => `${key}: ${clampText(String(currentNote[key] ?? ""), 400) || "(empty)"}`,
        ).join("\n")
      : "(no note saved yet for this visit)";

    const prompt = withinBudget(
      [
        renderOne("Visit", visit as Record<string, unknown>, [
          "visit_date",
          "visit_type",
          "status",
          "chief_complaint",
        ]),
        renderOne("Patient", patientRow as Record<string, unknown> | null, [
          "full_name",
          "gender",
          "date_of_birth",
          "blood_group",
          "chronic_conditions",
          "allergies",
        ]),
        renderRows("Vitals this visit", asRows(vitals?.data), { prefix: "W", maxRows: 1 }),
        renderRows("Diagnoses already recorded", asRows(diagnoses?.data), {
          prefix: "D",
          maxRows: 8,
        }),
        renderRows("Earlier visits", asRows(priorVisits?.data), { prefix: "V", maxRows: 3 }),
        renderRows("Recent lab orders", asRows(labs?.data), { prefix: "L", maxRows: 3 }),
        `Note already in the form:\n${existing}`,
        "Draft the note for this visit now.",
      ],
      9000,
    );

    try {
      const text = await completeAiText({ instructions: NOTE_INSTRUCTIONS, prompt });
      const sections = parseNoteSections(text);
      const filled = Object.keys(sections).filter((key) =>
        (NOTE_SECTION_KEYS as readonly string[]).includes(key),
      );
      return { text, error: null, sections, sources: filled };
    } catch (error) {
      return { text: null, error: describeAiFailure(error) };
    }
  });

// ---------------------------------------------------------------------------
// 2. Ask about a patient
// ---------------------------------------------------------------------------

const askInput = z.object({
  patientId: z.string().min(1),
  question: z.string().min(3).max(600),
  lang: z.enum(["ar", "en"]),
  history: z
    .array(z.object({ question: z.string().max(600), answer: z.string().max(4000) }))
    .max(6)
    .default([]),
});

export const askAboutPatient = createServerFn({ method: "POST" })
  .validator(askInput)
  .handler(async ({ data }): Promise<AiResult> => {
    const { requireAppAccess, renderOne, renderRows } = await import("./data-access.server.ts");
    const { completeAiText, describeAiFailure } = await import("./gateway.server.ts");

    let access;
    try {
      access = await requireAppAccess("patients.read");
    } catch (error) {
      return failure(error);
    }

    const { data: patientRow } = await access.supabase
      .from("patients")
      .select("*")
      .eq("id", data.patientId)
      .maybeSingle();
    if (!patientRow) return { text: null, error: "This patient is not available to you." };

    const [visitsQ, labsQ, invoicesQ, prescriptionsQ, followupsQ, claimsQ] = await Promise.all([
      access.supabase
        .from("visits")
        .select("visit_date, status, chief_complaint, departments(name), users(full_name)")
        .eq("patient_id", data.patientId)
        .order("visit_date", { ascending: false })
        .limit(8),
      access.supabase
        .from("lab_orders")
        .select("status, created_at, lab_order_items(status, lab_tests(name))")
        .eq("patient_id", data.patientId)
        .order("created_at", { ascending: false })
        .limit(8),
      access.supabase
        .from("invoices")
        .select("invoice_number, invoice_date, status, net_amount, paid_amount")
        .eq("patient_id", data.patientId)
        .order("invoice_date", { ascending: false })
        .limit(8),
      access.supabase
        .from("prescriptions")
        .select("created_at, status, is_external, prescription_items(dosage, medicines(name))")
        .eq("patient_id", data.patientId)
        .order("created_at", { ascending: false })
        .limit(5),
      access.supabase
        .from("followups")
        .select("followup_date, reason, status")
        .eq("patient_id", data.patientId)
        .order("followup_date", { ascending: false })
        .limit(5),
      access.supabase
        .from("insurance_claims")
        .select(
          "claim_number, status, submitted_amount, created_at, patient_insurance!inner(patient_id)",
        )
        .eq("patient_insurance.patient_id", data.patientId)
        .order("created_at", { ascending: false })
        .limit(4),
    ]);

    const rendered = [
      renderRows("Visits", asRows(visitsQ?.data), { prefix: "V", maxRows: 8 }),
      renderRows("Lab orders", asRows(labsQ?.data), { prefix: "L", maxRows: 8 }),
      renderRows("Invoices", asRows(invoicesQ?.data), { prefix: "I", maxRows: 8 }),
      renderRows("Prescriptions", asRows(prescriptionsQ?.data), { prefix: "P", maxRows: 5 }),
      renderRows("Follow-ups", asRows(followupsQ?.data), { prefix: "F", maxRows: 5 }),
      renderRows("Insurance claims", asRows(claimsQ?.data), { prefix: "C", maxRows: 4 }),
    ];

    const sources = rendered.flatMap((entry) => entry.legend);
    const historyText = data.history.length
      ? `Earlier in this conversation:\n${data.history
          .map((turn, index) => `Q${index + 1}: ${turn.question}\nA${index + 1}: ${turn.answer}`)
          .join("\n")}`
      : "";

    const prompt = withinBudget(
      [
        renderOne("Patient", patientRow as Record<string, unknown>, [
          "full_name",
          "gender",
          "date_of_birth",
          "blood_group",
          "chronic_conditions",
          "allergies",
        ]),
        ...rendered.map((entry) => entry.text),
        historyText,
        `Question: ${data.question}`,
      ],
      11000,
    );

    try {
      const text = await completeAiText({ instructions: PATIENT_QA_INSTRUCTIONS, prompt });
      const cited = sources.filter((label) => text.includes(`[${label}]`));
      return { text, error: null, sources: cited.length ? cited : sources };
    } catch (error) {
      return { text: null, error: describeAiFailure(error) };
    }
  });

// ---------------------------------------------------------------------------
// 3. Explain a lab order
// ---------------------------------------------------------------------------

const labInput = z.object({ orderId: z.string().min(1), lang: z.enum(["ar", "en"]) });

export const explainLabOrder = createServerFn({ method: "POST" })
  .validator(labInput)
  .handler(async ({ data }): Promise<AiResult> => {
    const { requireAppAccess, renderOne, renderRows, readRows } =
      await import("./data-access.server.ts");
    const { completeAiText, describeAiFailure } = await import("./gateway.server.ts");

    let access;
    try {
      access = await requireAppAccess("lab.read");
    } catch (error) {
      return failure(error);
    }

    const { data: order } = await access.supabase
      .from("lab_orders")
      .select(
        "id, status, created_at, ordered_at, verified_at, patients(full_name, gender, date_of_birth)",
      )
      .eq("id", data.orderId)
      .maybeSingle();
    if (!order) return { text: null, error: "This lab order is not available to you." };

    const itemsQ = await access.supabase
      .from("lab_order_items")
      .select("id, status, test_id, lab_tests(name, name_ar)")
      .eq("order_id", data.orderId);
    const itemRows = asRows(itemsQ?.data);
    const testIds = itemRows.map((row) => String(row["test_id"])).filter(Boolean);

    const results = await readRows(access, (client) =>
      client
        .from("lab_results")
        .select("*")
        .in(
          "item_id",
          itemRows.map((row) => String(row["id"])).filter(Boolean).length
            ? itemRows.map((row) => String(row["id"])).filter(Boolean)
            : [NIL_UUID],
        ),
    );
    const parameters = await readRows(access, (client) =>
      client
        .from("lab_parameters")
        .select("id, name, code, unit, data_type, reference_text")
        .in("test_id", testIds.length ? testIds : [NIL_UUID]),
    );
    const parameterIds = parameters.map((row) => String(row["id"])).filter(Boolean);
    const ranges = await readRows(access, (client) =>
      client
        .from("lab_reference_ranges")
        .select("parameter_id, gender, min_age, max_age, lower_limit, upper_limit, text_reference")
        .in("parameter_id", parameterIds.length ? parameterIds : [NIL_UUID]),
    );

    const prompt = withinBudget(
      [
        renderOne("Order", order as Record<string, unknown>, [
          "status",
          "created_at",
          "ordered_at",
          "verified_at",
        ]),
        renderOne(
          "Patient",
          (order as Record<string, unknown>)["patients"] as Record<string, unknown> | undefined,
          ["gender", "date_of_birth"],
        ),
        renderRows("Requested tests", itemRows, {
          prefix: "T",
          maxRows: 30,
          columns: ["status", "lab_tests"],
        }),
        renderRows("Result values", results, { prefix: "R", maxRows: 60 }),
        renderRows("Parameters", parameters, { prefix: "M", maxRows: 60 }),
        renderRows("Reference ranges", ranges, { prefix: "N", maxRows: 60 }),
        "Flag what is out of range and summarise the pattern.",
      ],
      11000,
    );

    try {
      const text = await completeAiText({ instructions: LAB_INSTRUCTIONS, prompt });
      return {
        text,
        error: null,
        sources: results.map((_, index) => `R${index + 1}`).slice(0, 60),
      };
    } catch (error) {
      return { text: null, error: describeAiFailure(error) };
    }
  });

// ---------------------------------------------------------------------------
// 4. Review an invoice
// ---------------------------------------------------------------------------

const invoiceInput = z.object({ invoiceId: z.string().min(1), lang: z.enum(["ar", "en"]) });

export const reviewInvoice = createServerFn({ method: "POST" })
  .validator(invoiceInput)
  .handler(async ({ data }): Promise<AiResult> => {
    const { requireAppAccess, renderOne, renderRows, readRows } =
      await import("./data-access.server.ts");
    const { completeAiText, describeAiFailure } = await import("./gateway.server.ts");

    let access;
    try {
      access = await requireAppAccess("billing.read");
    } catch (error) {
      return failure(error);
    }

    const { data: invoice } = await access.supabase
      .from("invoices")
      .select(
        "id, invoice_number, invoice_date, status, total_amount, discount_amount, net_amount, paid_amount, patients(full_name, mrn)",
      )
      .eq("id", data.invoiceId)
      .maybeSingle();
    if (!invoice) return { text: null, error: "This invoice is not available to you." };

    const [items, payments, claims] = await Promise.all([
      readRows(access, (client) =>
        client.from("invoice_items").select("*").eq("invoice_id", data.invoiceId),
      ),
      readRows(access, (client) =>
        client
          .from("payments")
          .select("amount, payment_method, payment_date, created_at")
          .eq("invoice_id", data.invoiceId)
          .order("payment_date"),
      ),
      readRows(access, (client) =>
        client
          .from("insurance_claims")
          .select("claim_number, status, submitted_amount, created_at, submitted_at")
          .eq("invoice_id", data.invoiceId),
      ),
    ]);

    const prompt = withinBudget(
      [
        renderOne("Invoice", invoice as Record<string, unknown>, [
          "invoice_number",
          "invoice_date",
          "status",
          "total_amount",
          "discount_amount",
          "net_amount",
          "paid_amount",
        ]),
        renderRows("Line items", items, { prefix: "T", maxRows: 40 }),
        renderRows("Payments", payments, { prefix: "P", maxRows: 20 }),
        renderRows("Linked claims", claims, { prefix: "C", maxRows: 6 }),
        "Review this invoice now.",
      ],
      10000,
    );

    try {
      const text = await completeAiText({ instructions: BILLING_INSTRUCTIONS, prompt });
      return { text, error: null, sources: claims.map((_, index) => `C${index + 1}`) };
    } catch (error) {
      return { text: null, error: describeAiFailure(error) };
    }
  });
