# Roshan Health Hub — Clinical Guideline Policy, Pediatric Safety Contract & ICD-10 Recommendation (2026-11-20)

> **Target repository path:** `docs/CLINICAL_GUIDELINE_POLICY_AND_ICD10_RECOMMENDATION_2026-11-20.md`
> **Scope:** Unblocks **RHH-02** (PR `#292`, Pediatric Medication Safety) and **RHH-04** (PR `#291`, ICD-10 Validation & Versioning) under the updated clinical evidence policy without weakening clinical safety or inventing dosing rules.
> **Status:** `Evidence verified` (Policy & Technical Specification) | `Clinically reviewed: Pending` | `Approved for activation: NO`

## 1. Clinical Evidence Policy & Source Hierarchy (Effective 2026-11-20)

Absence of a current, accessible, or complete Sudanese national clinical guideline is **no longer treated as an engineering or protocol-design blocker**. Roshan Health Hub operates in a resource-constrained primary-care setting (Al-Hasaheisa, Al Jazirah, Sudan) and applies the following evidence hierarchy:

1. **Tier 1 — WHO Guidelines & Technical Recommendations:** Primary care, emergency, maternal, newborn, pediatric, and resource-limited care guidance.
2. **Tier 2 — Recognized International Specialty Guidelines:** Current guidelines from NICE, CDC, IDSA, AAP, ACOG, RCOG, ESC, and equivalent professional societies.
3. **Tier 3 — High-Quality National Guidelines:** Reputable health-system guidelines (e.g., BNFC/NHS) when they provide more specific operational recommendations.
4. **Tier 4 — Systematic Reviews, Meta-Analyses & High-Quality Primary Evidence:** Used when no suitable Tier 1–3 guideline exists.

### Verified Tier 1 WHO Reference Registry (Pediatric & Primary Care)

| Reference | Version / Edition | Publication / Update Date | Population & Setting | Key Scope & Limitations | Source URL |
| :--- | :--- | :--- | :--- | :--- | :--- |
| WHO Model List of Essential Medicines for Children (EMLc) | 10th List (paired with 24th Adult EML) | Published 2025-09-05 | Children; primary care & hospital essential formulary | Guides local formulary selection and age-appropriate dosage forms; requires local availability mapping | [WHO EMLc 10th List (2025)](https://www.who.int/publications/i/item/B09475) / [WHO EML Portal](https://www.who.int/groups/expert-committee-on-selection-and-use-of-essential-medicines/essential-medicines-lists) |
| WHO Guideline on Management of Pneumonia and Diarrhoea in Children up to 10 Years of Age | 2024 Guideline (ISBN 9789240103412) | Published 2024-12-31 | Children aged 0–10 years (extends prior <5y guidance to ages 5–9); community, primary care, hospital | Covers pneumonia antibiotics (oral amoxicillin dispersible tablets), hypoxaemia clinical signs when pulse oximetry is unavailable, low-osmolarity ORS, and updated zinc dosing; non-commercial CC BY-NC-SA 3.0 IGO | [WHO Pneumonia & Diarrhoea 2024](https://www.who.int/publications/i/item/9789240103412) |
| WHO Recommendations for Management of Serious Bacterial Infections in Infants Aged 0–59 Days | 2024 Guideline (ISBN 9789240102903) | Published 2024-12-08 | Young infants 0–59 days with suspected sepsis, pneumonia, or meningitis; hospital & non-hospital when referral is not feasible | Explicitly defines both hospital first-line empiric therapy and simplified outpatient regimens when urgent referral cannot be completed | [WHO SBI 0–59 Days 2024](https://www.who.int/publications/i/item/9789240102903) |
| The WHO AWaRe (Access, Watch, Reserve) Antibiotic Book | 2022 Book + 2024–2025 Bridge Summary | Published 2022-12-09 (bridge reflects Dec 2024 pediatric updates) | Adults and children; >30 common infections in primary care & hospital settings | Empiric choice, dose, route, and duration aligned with AWaRe stewardship; must be read alongside WHO's pediatric update bridge table | [WHO AWaRe Antibiotic Book](https://www.who.int/publications/i/item/9789240062382) / [WHO Pediatric Diff Bridge](https://cdn.who.int/media/docs/default-source/antimicrobial-resistance/surveillance--prevention---control-(spc)/control---response-strategies-(csr)/infections-in-children.pdf?sfvrsn=683ffc7a_1) |
| WHO Pocket Book of Hospital Care for Children | 2nd Edition (ISBN 9789241548373) | 2013 (2nd ed.; NCBI mirror updated 2022-02-01) | Severely ill children at first-referral hospitals with basic lab & essential medicines | Consistent with IMCI; older than 2024 pneumonia/diarrhoea/newborn guidelines—defer to 2024 WHO updates where superseded | [WHO Pocket Book 2nd Ed.](https://www.who.int/publications/i/item/9789241548373) / [NCBI Bookshelf](https://www.ncbi.nlm.nih.gov/books/NBK154447/) |
| WHO IMCI Chart Booklets | 2014 Sick Child + 2019 Young Infant | 2014-03-04 (2m–5y) / 2019-07-22 (0–2m supersedes 2014 young-infant section) | Outpatient sick children 0–5 years in primary health facilities | Structured danger-sign assessment, pre-referral care, and caregiver counseling; supplement with 2024 WHO guidelines for ages 5–9 and 0–59d SBI | [WHO IMCI 2014](https://www.who.int/publications/m/item/integrated-management-of-childhood-illness---chart-booklet-(march-2014)) / [WHO Young Infant IMCI 2019](https://www.who.int/publications/i/item/9789241516365) |
| WHO GRADE-ADOLOPMENT Contextualization Guide | 15-Step Framework + GRADE Guidance 39 | 2023-08-14 (WHO) / 2024-10-15 (GRADE Guidance 39) | Guideline adaptation teams in resource-constrained settings | Provides transparent adopt/adapt/de-novo contextualization without silently lowering evidence standards | [WHO GRADE-ADOLOPMENT (2023)](https://www.who.int/publications/i/item/9789289060028) / [GRADE Guidance 39 (2024)](https://pubmed.ncbi.nlm.nih.gov/39117011/) |

## 2. Roshan Contextualization & GRADE-ADOLOPMENT Rules

For every clinical pathway or medication decision-support rule implemented in Roshan Health Hub, engineering and clinical reviewers must record all six contextualization dimensions:

1. **Local Resource Availability:** Verify actual stock/availability of medicines, diagnostics (e.g., pulse oximetry, CBC, RDTs), equipment, and referral transport at the center.
2. **Resource Gaps:** Explicitly flag when the ideal guideline intervention requires diagnostics or parenteral/hospital resources unavailable on-site.
3. **Ideal vs. Safe Feasible Alternative:** Never silently weaken evidence-based standards. Display the **ideal recommended intervention** and, separately, any **evidence-supported safe feasible alternative**.
4. **Referral & Escalation Thresholds:** Encode explicit danger signs and referral triggers (e.g., inability to drink/breastfeed, persistent vomiting, convulsions, lethargy/unconsciousness, chest indrawing with danger signs, young infant 0–59 days SBI red flags).
5. **Monitoring & Follow-Up Feasibility:** Specify realistic outpatient review intervals and caregiver return-immediately instructions.
6. **Patient-Specific Modifiers:** Capture contraindications, drug interactions, allergies, pregnancy/lactation, malnutrition, and renal/hepatic impairment warnings.

## 3. Mandatory 5-State Protocol Lifecycle & Pediatric Safety Contract (RHH-02 / PR #292)

Software test passage **never** implies clinical approval. Every clinical rule or protocol record must track five independent states:

1. `Implemented in code` (Engineering)
2. `Technically tested` (Engineering / QA)
3. `Evidence verified` (Clinical Informatics / Reviewer)
4. `Clinically reviewed` (Qualified Clinician)
5. `Approved for activation` (Medical Director / Owner)

No medication rule may be added without verified structured metadata (`rule_id`, `protocol_version`, `lifecycle_state`, `indication`, `target_population`, `dose`, `dose_basis`, `route`, `formulation_concentration`, `frequency`, `duration`, `max_single_dose`, `max_daily_dose`, `renal_hepatic_adjustments`, `contraindications`, `warnings`, `interactions`, `ideal_intervention`, `safe_feasible_alternative`, `referral_threshold`, `source_title`, `source_organization`, `source_version`, `publication_date`, `update_date`, `source_url`, `clinical_setting`, `limitations`, `clinician_confirmation_required: true`). Never invent a dose, maximum dose, pediatric threshold, or clinical rule.

## 4. RHH-04 (PR #291) — ICD-10 Standard & Versioning Technical Recommendation

- **Recommended Primary Standard:** `WHO-ICD-10` Version `2019` (`coding_system = 'WHO-ICD-10'`, `coding_version = '2019'`), grounded in the [WHO ICD-10 Version: 2019 Browser](https://icd.who.int/browse10/2019/en) (the final official WHO ICD-10 update per [WHO ICD Portal](https://www.who.int/standards/classifications/classification-of-diseases)), rather than US-reimbursement-oriented ICD-10-CM.
- **Future Migration Path:** Persist `coding_system`, `coding_version`, `code`, and `display_label_snapshot` on every diagnosis record so historical encounters remain immutable when Roshan later adopts [WHO ICD-11](https://www.who.int/standards/classifications/frequently-asked-questions/icd-11-implementation).
- **Backward Compatibility & Activation Gate:** Never silently overwrite legacy/free-text diagnoses; production activation requires clinician/owner confirmation.
