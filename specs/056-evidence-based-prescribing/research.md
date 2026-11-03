# Research: Evidence-Based Prescribing & Clinical Decision Support

**Date:** 2026-11-03  
**Status:** Evidence survey for architecture; not a clinical protocol approval.

## 1. Evidence hierarchy for Roshan

1. Current Sudan Federal/State Ministry of Health standard treatment guidelines, circulars and formulary protocols, if their version, issuing body and applicability can be verified.
2. Current WHO guidelines relevant to low-resource/primary-care settings and the target population.
3. Current specialty-society/national guidelines with transparent evidence grading (e.g. NICE, AAP/IDSA where appropriate), with jurisdiction differences explicitly shown.
4. Authoritative product information/SmPC for product-specific formulation, contraindications and pharmacokinetics.
5. Secondary references only to corroborate; never silently substitute a tertiary source for a current local protocol.

A source may be strong but out-of-scope. Protocol metadata must include population, setting, indication, severity, jurisdiction, publication/version date, relevant section/page, evidence grade where provided, and explicit exclusions.

## 2. Sources reviewed

### WHO AWaRe Antibiotic Book (2022)
- URL: https://www.who.int/publications/i/item/9789240062382
- Use: syndrome/indication-specific antibiotic selection, adult/child quick-reference material and antimicrobial stewardship context.
- Limitation explicitly stated by WHO: the book is being updated; newer WHO recommendations have appeared for serious bacterial infections in infants 0–59 days (Dec 2024), pneumonia/diarrhoea in children (Dec 2024), STIs (Jul 2024), and meningitis (Apr 2025). WHO publishes interim summaries of key differences.
- Design consequence: AWaRe is a baseline/reference index, not the sole authority where newer guidance exists.

### WHO recommendations for management of serious bacterial infections in infants aged 0–59 days (2024)
- URL: https://www.who.int/publications/i/item/9789240102903
- NCBI full text: https://www.ncbi.nlm.nih.gov/books/NBK610597/
- Use: neonatal/young-infant sepsis, meningitis and pneumonia; hospital and selected non-hospital pathways where referral is not possible.
- Limitation: specific to 0–59 days and includes setting/referral distinctions. Do not extend these regimens to older infants or all pediatric patients.
- Design consequence: represent exact age boundaries, hospital/referral context and disease category as explicit predicates.

### WHO guidelines on meningitis diagnosis, treatment and care (2025)
- URL: https://www.who.int/publications/i/item/9789240108042
- Executive summary: https://www.who.int/publications/i/item/B09452
- Use: current community-acquired meningitis management for children and adults in first/second-level facilities, relevant to Sudan's low-resource context.
- Limitation: guideline scope excludes neonates under 28 days (refer to neonatal-specific guidance); pathogen/risk-factor and age differences matter.
- Design consequence: a free-text word "meningitis" cannot choose one dose; age group, suspected etiology, risk factors, care setting and local resistance/protocol conditions must be matched.

### NICE NG5 — Medicines optimisation
- URL: https://www.nice.org.uk/guidance/ng5/chapter/Recommendations
- Use: recommends that clinical decision support not replace clinical judgement; robust transparent processes for development, use, review and updating; important safety issues; mandatory acknowledgement for selected alerts; relevance and currency to reduce alert fatigue.
- Design consequence: tier alerts by severity and require review/acknowledgement rules; avoid indiscriminate interruptive warnings.

### NICE CG183 — Drug allergy
- URL: https://www.nice.org.uk/guidance/CG183/chapter/recommendations
- Use: allergy status should be distinct from adverse drug reactions, clearly visible, checked before prescribing/dispensing/administering, and updated when changed.
- Design consequence: allergy object includes substance/class, reaction, severity, certainty/status, onset and source; unknown is not equivalent to "no known allergies".

### FDA Clinical Decision Support Software Guidance (Final, 2026-01-29)
- URL: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software
- Use: current US guidance explaining categories of clinical decision support and the importance of transparent basis and ability of health professionals to independently review recommendations, depending on intended function.
- Limitation: US regulatory guidance is not Sudanese law. It is used as a design/safety reference, not as a claim of legal compliance.
- Design consequence: expose rule inputs, source, logic and limits; assess intended-use/regulatory status separately before commercialization.

### HL7 FHIR R5 MedicationKnowledge and Dosage
- MedicationKnowledge: https://hl7.org/fhir/R5/medicationknowledge.html
- Dosage: https://hl7.org/fhir/R5/dosage.html
- Use: useful data-model concepts for medication catalogue knowledge, indicationGuideline, dosingGuideline, administrationTreatment, patientCharacteristic and structured dosage instructions.
- Limitation: FHIR resources are interoperability standards, not a validated drug knowledge base or dose recommendation source.
- Design consequence: adopt concepts and field semantics; do not introduce a full FHIR server or imply that FHIR itself supplies dosing evidence.

### Sudan National Essential Medicines List (2019)
- URL: https://www.who.int/publications/m/item/sudan--national-essential-medicines-list-2019-%28english%29
- Use: historic/local formulary context and candidate medicine coverage.
- Limitation: 2019 edition is not a current treatment guideline and cannot substantiate present-day dose/frequency recommendations.
- Design consequence: request/locate newer Sudanese national or state treatment protocols before local alignment claims.

## 3. Key clinical-engineering conclusions

- A drug is not a regimen. Product/formulation constrains route; confirmed indication plus patient context selects the protocol.
- The same molecule may have multiple regimens across indication, severity, age, site of care, pregnancy, renal/hepatic function and pathogen risk.
- Pediatric dosing must encode the dose basis, not just the arithmetic. mg/kg/dose and mg/kg/day are not interchangeable.
- Dose ceilings, age/gestational cutoffs, concentration, route, interval, duration, rounding and monitoring are protocol-specific fields. Missing required metadata makes a rule ineligible.
- Patient context must distinguish positive, negative and unknown states. Unknown allergy, unknown renal function and missing weight cannot be interpreted as normal.
- Drug interaction and contraindication rules require a trustworthy curated source and licensing/redistribution review. No free public API was verified as a comprehensive substitute for a commercial drug-interaction system.
- AI can assist in finding/structuring source documents or suggesting terminology candidates, but every extracted clinical rule must be reviewed by a clinician and tested before activation. AI cannot supply the dose or interaction severity.

## 4. Source update workflow

Each source record must include: source owner, title, edition/version, publication date, jurisdiction, population, setting, URL or stable citation, relevant page/section, retrieval date, licence/redistribution constraints, reviewer, approval date, next review date, superseded/withdrawn state.

At each review:
1. Check for newer version/corrigendum or replacement guidance.
2. Compare only relevant sections and record differences.
3. Re-evaluate affected protocols and test fixtures.
4. Keep old versions for audit/reproducibility but mark them inactive for new prescribing.
5. Re-run golden cases and clinical sign-off before activating the replacement.

## 5. Unresolved evidence acquisition

- Current Sudan Federal/State Ministry of Health Standard Treatment Guidelines and Essential Medicines List.
- Roshan's actual QA formulary export and high-frequency diagnoses/case mix (synthetic/anonymized aggregates only).
- A licensed/redistributable interaction and product safety dataset or a bounded, manually curated local rule set.
- Local antimicrobial resistance data/antibiogram and referral capability assumptions.
- Named GP and pharmacist clinical reviewers and their sign-off workflow.

## 6. Research source index
- WHO AWaRe 2022: https://www.who.int/publications/i/item/9789240062382
- WHO serious bacterial infections 0–59 days 2024: https://www.who.int/publications/i/item/9789240102903
- WHO meningitis 2025: https://www.who.int/publications/i/item/9789240108042
- NICE NG5: https://www.nice.org.uk/guidance/ng5/chapter/Recommendations
- NICE CG183: https://www.nice.org.uk/guidance/CG183/chapter/recommendations
- FDA CDS final guidance 2026: https://www.fda.gov/regulatory-information/search-fda-guidance-documents/clinical-decision-support-software
- HL7 FHIR R5 MedicationKnowledge: https://hl7.org/fhir/R5/medicationknowledge.html
- HL7 FHIR R5 Dosage: https://hl7.org/fhir/R5/dosage.html
- Sudan NEML 2019: https://www.who.int/publications/m/item/sudan--national-essential-medicines-list-2019-%28english%29


## Sudan-specific evidence located — 2026-11-03

A WHO Bulletin comparative review identifies Sudan Federal Ministry of Health, *National Standard Treatment Guidelines* (2014), and cites the primary download hosted by the Sudan Health Observatory. The primary file could not be retrieved in this session; its recommendations and current validity are therefore unverified. Obtain the complete document and later federal/state circulars before encoding local protocols. Review: https://pmc.ncbi.nlm.nih.gov/articles/PMC8722630/ .

A 2025 Sudan primary-care observational study (Abdou et al., J Infect Dev Ctries 19(1):91–97; DOI 10.3855/jidc.20106; https://pubmed.ncbi.nlm.nih.gov/39977472/) examined 52,274 antimicrobials across 325 PHCs in five states using 2022 data and reported 71% Watch-antibiotic use with low compliance to WHO AWaRe guidance for several syndromes. This is stewardship evidence, not a treatment/dosing guideline; it must not generate a regimen.
