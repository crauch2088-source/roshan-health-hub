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


## Production catalogue evidence and product-label cross-check — 2026-11-03

A read-only query found nine active, non-deleted Production medicine catalogue rows and zero QA medicine rows. The normalized product fields `brand_name`, `strength`, and `dosage_form` were NULL in every Production row. The inventory `unit` field is not sufficient evidence of administration route or exact formulation. See [catalogue-audit.md](catalogue-audit.md) for the limited candidate list and explicit data-quality caveats. No stock, price, patient, or financial data was retrieved.

### Cefpodoxime identity/route mismatch
- DailyMed, **CEFPODOXIME PROXETIL tablet, film coated**, label updated 2026-10-22: https://www.dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=ce5646cb-a450-4c2c-8499-6ecf71b12b0e
- DailyMed, **CEFPODOXIME PROXETIL granule, for suspension**: https://dailymed.nlm.nih.gov/dailymed/drugInfo.cfm?setid=63777889-d306-4fc3-88da-b24859040ef4
- Both labels identify the products as for oral use only. This is a product-label cross-check, not proof that the local `Cefpodoxim` inventory row is cefpodoxime proxetil. Its `Inj` unit is therefore a high-priority identity mismatch to quarantine from route auto-fill until the actual pack and active ingredient are verified.
- Do not transfer any dosing table from these labels into Roshan's active protocols without indication-specific review, local guideline reconciliation, population boundaries, and independent GP/pharmacist approval.


## Sudan Federal and Gezira-state guideline source audit — 2026-11-03

**Scope:** Public-source discovery and provenance assessment only. This is not clinical guideline approval, protocol extraction, or a claim that no unpublished/local document exists. Searches covered the Federal Ministry of Health public portal, WHO repositories, indexed Sudanese health-policy material, University of Gezira references, and peer-reviewed literature. Retrieval date: 2026-11-03.

### Federal Ministry of Health material

- **Sudan National Health Care Quality Policy and Strategy (2017)**, hosted in the WHO policy repository: https://platform.who.int/docs/default-source/mca-documents/policy-documents/policy/sdn-cc-31-01-policy-2017-eng-national-health-care-quality.pdf
  - The document identifies the Federal Ministry of Health as the lead for national clinical standards and guidelines. At the time of publication, it reports 20 consultative councils, 15 published clinical standards for major conditions, and standard treatment guidelines for 26 PHC conditions (Section Five, approximately pp. 51–52).
  - This is evidence that such standards/guidelines existed in 2017; it does **not** provide their individual titles, complete primary documents, current versions, state applicability, or current endorsement status.
- **Sudan National Standard Treatment Guidelines (2014)** are cited as a Federal Ministry of Health publication in the WHO Bulletin comparative review: https://pmc.ncbi.nlm.nih.gov/articles/PMC8722630/ . The review cites the former Sudan Health Observatory download endpoint: http://www.sho.gov.sd/controller/dwn_hub_files.php?id=915 . The primary document could not be retrieved/validated in this audit. Its recommendations, full text, licence, and whether it was superseded remain unverified.
- A 2017 consultant terms-of-reference notice described a planned Federal Ministry of Health update of the 2014 STGs: https://www.sudanjob.net/jobview.php?id=5269 . A recruitment notice proves an update was planned, not that a final updated guideline was completed, approved, published, or implemented. Do not treat it as evidence of a newer edition.
- WHO's Sudan **National Essential Medicines List 2019** publication record: https://www.who.int/publications/m/item/sudan--national-essential-medicines-list-2019-%28english%29 . This is a 2019 essential-medicines list (40-page WHO record), not a standard treatment guideline and not a source for indication-specific dose/frequency rules.

### State-level and Gezira-specific material

- **Treatment Manual for Family Medicine Practitioners (2020), Red Sea State**: https://khartoum.aics.gov.it/wp-content/uploads/2021/12/Treatment-Manual_FINALE_2020.pdf . The cover and foreword identify the National Medical Supplies Fund — Red Sea State, under the supervision of the Ministry of Health and Social Development, Red Sea State. It is a useful example of a state-specific PHC manual, but it is not a Gezira or national guideline. It must not be copied into Roshan's active rules or represented as applicable to Gezira without an explicit local adoption/adaptation review. Redistribution/adaptation rights for its clinical content were not established.
- A secondary report describes a **University of Gezira Center for Noncommunicable Studies emergency-treatment protocol** approved for Wad Madani Emergency Hospital and intended for other centers: https://africanuniversities.org/university-of-gezira-sudan-a-treatment-protocol-for-emergency-cases-in-hospitals-and-centers-in-the-gezira/ . The report says the center called on the State Ministry of Health to apply and disseminate it. The original protocol document and evidence of formal State Ministry adoption were not located. Treat it as an institutional protocol lead only, not an official state-wide guideline.
- A 2024 BMC Primary Care study of guideline implementation in Khartoum and Gezira (survey conducted April–December 2021; 101 PHC centers, including 24 in Gezira) reported that local Sudanese guidelines were difficult to access and not regularly updated: https://doi.org/10.1186/s12875-024-02542-x . This is implementation/accessibility evidence, not a treatment guideline. The article is CC BY-NC-ND 4.0; cite it, but do not adapt its text or figures.
- The 2017–2018 Gezira NHIF drug-use study refers to state-level STGs and an NHIF essential medicines list version 6 (2018): https://www.scirp.org/journal/paperinformation?paperid=112722 . It is historical secondary evidence, not a current Ministry-issued protocol or a source for regimen content.

### Audit conclusion and implementation boundary

- As of this public-source audit, no accessible, verifiable current Federal STG edition or formally adopted Gezira State Ministry of Health STG/protocol set was obtained. This is a bounded search result, **not proof that no such documents exist**; unpublished circulars, facility manuals, or documents distributed offline may exist.
- The 2017 FMoH policy, 2014 national STG reference, 2019 NEML, 2020 Red Sea manual, and 2022 University of Gezira protocol lead have different issuers, dates, scope and authority. They are not interchangeable.
- No drug regimen, dose, frequency, duration, route mapping, interaction severity, or contraindication rule was extracted or activated from these documents.
- Redistribution/licensing permission for the Federal 2014 STG primary file, Red Sea manual, and University of Gezira protocol remains unverified. Do not reproduce their tables or import their content into the application until rights and provenance are checked.
- Before any Sudan-local protocol is activated, obtain the primary document from FMoH/Directorate General of Pharmacy and Gezira State Ministry of Health (and the University of Gezira for its emergency protocol lead); verify issuer, signed approval, edition/date, population, facility level, state/jurisdiction, supersession, source sections, redistribution rights, and local GP/pharmacist approval.

### Primary references

1. Sudan FMoH. *National Health Care Quality Policy and Strategy* (2017), Section Five. WHO-hosted primary policy document.
2. WHO Bulletin comparative review. *Comparison of national antimicrobial treatment guidelines* (2021), citing Sudan FMoH STGs (2014): https://pmc.ncbi.nlm.nih.gov/articles/PMC8722630/
3. WHO. *Sudan: National Essential Medicines List 2019*: https://www.who.int/publications/m/item/sudan--national-essential-medicines-list-2019-%28english%29
4. Abdelgadir HS, Bajouri S, Abdelgadir HS. *Implementation of the clinical practice guidelines among family medicine doctors at primary health care facilities in Khartoum and Gezira states of Sudan*. BMC Prim Care. 2024;25:277. doi:10.1186/s12875-024-02542-x.
5. National Medical Supplies Fund — Red Sea State. *Treatment Manual for Family Medicine Practitioners* (2020). State-specific, not a Gezira guideline.
6. University of Gezira Center for Noncommunicable Studies emergency protocol (reported 2022); primary protocol and Ministry adoption not verified.
