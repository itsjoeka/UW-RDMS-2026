---

## Flowchart: Research Data Transformation Process

### Structure for Lucidchart

I'll describe each shape, its text, and connections. Use:
- **Rectangles** for processes/steps
- **Diamonds** for decisions
- **Parallelograms** for data/inputs/outputs
- **Cylinders** for databases
- **Arrows** for flow direction

---

## FLOWCHART LAYOUT

```
┌─────────────────────────────────────────────┐
│         START: Research Question            │
│   "What is the association between          │
│   treatment and mortality in breast cancer?"│
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│      DATABASE: Google BigQuery              │
│   SynPUF OMOP CDM Dataset (2008-2010)       │
│   • 481,799 total persons                   │
│   • Claims-based Medicare data              │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│    STEP 1: Identify Breast Cancer Codes    │
│                                             │
│   • ICD10CM: C50% (All breast sites)       │
│   • ICD9CM: 174% (Malignant neoplasm)      │
│   • Query CONCEPT table                     │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│  STEP 2: Map Source Codes to SNOMED        │
│                                             │
│   Process:                                  │
│   1. Source concepts (ICD codes)            │
│   2. CONCEPT_RELATIONSHIP (Maps to)         │
│   3. Target concepts (SNOMED standard)      │
│                                             │
│   Tables used:                              │
│   • CONCEPT (source & target)               │
│   • CONCEPT_RELATIONSHIP                    │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 3: Define Inclusion Criteria         │
│                                             │
│   ✓ Female patients (gender_concept_id=8532)│
│   ✓ Breast cancer diagnosis in             │
│     CONDITION_OCCURRENCE table              │
│   ✓ Standardized SNOMED concept_ids         │
│                                             │
│   Tables used:                              │
│   • PERSON                                  │
│   • CONDITION_OCCURRENCE                    │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 4: Extract Patient Demographics      │
│                                             │
│   From PERSON table:                        │
│   • person_id                               │
│   • year_of_birth, month, day               │
│   • race_concept_id → race name             │
│   • Calculate age at diagnosis              │
│                                             │
│   From CONDITION_OCCURRENCE:                │
│   • first_diagnosis_date (MIN)              │
│   • diagnosis_subtypes (STRING_AGG)         │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 5: Identify Treatment Interventions  │
│                                             │
│   A. SURGICAL PROCEDURES                    │
│      • Query PROCEDURE_OCCURRENCE           │
│      • Search: mastectomy, lumpectomy       │
│      • Extract: first_surgery_date          │
│                                             │
│   B. CHEMOTHERAPY                           │
│      • Query DRUG_EXPOSURE                  │
│      • Search: doxorubicin, paclitaxel, etc.│
│      • Extract: first_chemo_date, drug names│
│                                             │
│   C. RADIATION THERAPY                      │
│      • Query PROCEDURE_OCCURRENCE           │
│      • Search: radiation, radiotherapy      │
│      • Extract: first_radiation_date        │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 6: Categorize Treatment Groups       │
│                                             │
│   Logic:                                    │
│   IF surgery + chemo + radiation            │
│      → "Triple therapy"                     │
│   ELSE IF surgery + chemo                   │
│      → "Surgery+Chemo"                      │
│   ELSE IF surgery + radiation               │
│      → "Surgery+Radiation"                  │
│   ELSE IF surgery only → "Surgery only"     │
│   ELSE IF chemo only → "Chemo only"         │
│   ELSE IF radiation only → "Radiation only" │
│   ELSE → "No treatment"                     │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 7: Extract Outcome Data (Death)      │
│                                             │
│   From DEATH table:                         │
│   • death_date                              │
│   • death_year                              │
│                                             │
│   Calculate:                                │
│   • vital_status (Deceased/Alive)           │
│   • survival_days (diagnosis → death)       │
│   • survival_years                          │
│   • died_within_1_year (Yes/No)             │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 8: Join All Data Using CTEs          │
│                                             │
│   WITH clauses:                             │
│   1. breast_cancer_patients (base cohort)   │
│   2. surgeries (surgical data)              │
│   3. chemotherapy (drug data)               │
│   4. radiation (radiation data)             │
│   5. deaths (outcome data)                  │
│                                             │
│   JOIN strategy:                            │
│   LEFT JOIN on person_id                    │
│   (keep all patients even without treatment)│
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 9: Create Final Analysis Dataset     │
│                                             │
│   Columns included:                         │
│   • Demographics: person_id, race, age      │
│   • Diagnosis: date, subtypes               │
│   • Treatments: surgery, chemo, radiation   │
│   • Treatment group categorization          │
│   • Outcomes: death status, survival time   │
│                                             │
│   Output: One row per patient               │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 10: Export Results                   │
│                                             │
│   • Query results displayed in BigQuery     │
│   • Download as CSV using Export button     │
│   • LIMIT 1000 for quota management         │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│   STEP 11: Statistical Analysis              │
│                                             │
│   Summary statistics by treatment group:     │
│   • COUNT patients                          │
│   • AVG age                                 │
│   • SUM deaths                              │
│   • Calculate mortality rate                │
│   • AVG survival time                       │
│                                             │
│   GROUP BY treatment_group                  │
└──────────────────┬──────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────┐
│          END: Analysis-Ready Dataset         │
│                                             │
│   CSV file with:                            │
│   • Patient demographics                    │
│   • Treatment interventions                 │
│   • Mortality outcomes                      │
│   • Ready for statistical modeling          │
└─────────────────────────────────────────────┘
```

---

## Color Coding Suggestions for Lucidchart

- **Yellow/Gold**: Start/End nodes
- **Blue**: Database/Data sources (BigQuery, tables)
- **Green**: Data extraction steps (Steps 1-5)
- **Orange**: Data transformation (Steps 6-9)
- **Purple**: Analysis/Output (Steps 10-11)
- **Red borders**: Decision points (if any)

---

## Detailed Node Descriptions for Lucidchart

### Level 1: Foundation
```
START → Database Source → Identify Codes → Map to SNOMED
```

### Level 2: Cohort Building
```
Define Inclusion → Extract Demographics
```

### Level 3: Intervention Data
```
Extract Treatments (3 parallel branches):
  ├─ Surgery
  ├─ Chemotherapy  
  └─ Radiation
→ Merge to → Categorize Treatment Groups
```

### Level 4: Outcomes
```
Extract Death Data → Calculate Survival Metrics
```

### Level 5: Integration
```
Join All Data → Create Final Dataset → Export CSV → Analysis
```

---

## Technical Details to Add (in text boxes)

**Box 1: Key Tables Used**
```
• PERSON (demographics)
• CONCEPT (vocabularies)
• CONCEPT_RELATIONSHIP (mappings)
• CONDITION_OCCURRENCE (diagnoses)
• PROCEDURE_OCCURRENCE (surgeries, radiation)
• DRUG_EXPOSURE (medications)
• DEATH (outcomes)
```

**Box 2: SQL Techniques Used**
```
• WITH clauses (CTEs)
• INNER JOIN (exact matches)
• LEFT JOIN (keep all patients)
• STRING_AGG (combine text)
• DATE_DIFF (calculate survival)
• CASE WHEN (categorization)
• GROUP BY (aggregation)
```

**Box 3: Data Quality Checks**
```
• Verify female gender only
• Check for duplicate person_ids
• Validate date ranges (2008-2010)
• Ensure SNOMED standardization
• Handle NULL values in treatments
```

---

## Alternative: Simplified Version

If you want a simpler flowchart:

```
1. Define Research Question
   ↓
2. Access SynPUF Database (BigQuery)
   ↓
3. Identify & Map Breast Cancer Codes (ICD→SNOMED)
   ↓
4. Build Base Cohort (Female + Diagnosis)
   ↓
5. Extract Treatment Data (Surgery, Chemo, Radiation)
   ↓
6. Extract Outcome Data (Death)
   ↓
7. Join All Data into Single Table
   ↓
8. Export to CSV
   ↓
9. Statistical Analysis
```

---

**Which version do you prefer?** 
- **Detailed** (11 steps with all technical details)
- **Simplified** (9 high-level steps)

Let me know and I can help you refine it further! 📊
