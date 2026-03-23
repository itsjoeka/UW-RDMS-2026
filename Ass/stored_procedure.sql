CREATE OR REPLACE PROCEDURE `bime-530-jk-itk-naa-aao.assignment_2`.get_breast_cancer_cohort()
BEGIN

  CREATE OR REPLACE TABLE `bime-530-jk-itk-naa-aao.assignment_2.breast_cancer` AS

  WITH

  -- Step 1: Get all female breast cancer patients with diagnosis info
  breast_cancer_patients AS (
    SELECT DISTINCT
        p.person_id,
        p.year_of_birth,
        p.month_of_birth,
        p.day_of_birth,
        p.gender_concept_id,
        p.race_concept_id,
        p.ethnicity_concept_id,
        MIN(co.condition_start_date) AS first_diagnosis_date,
        STRING_AGG(
          DISTINCT c.concept_name, '; '
          ORDER BY c.concept_name
          LIMIT 3
        ) AS diagnosis_subtypes
    FROM `bigquery-public-data.cms_synthetic_patient_data_omop.person`            AS p
    INNER JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.condition_occurrence` AS co
        ON p.person_id = co.person_id
    INNER JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.concept`     AS c
        ON co.condition_concept_id = c.concept_id
    WHERE p.gender_concept_id = 8532  -- Female only
      AND co.condition_concept_id IN (
          SELECT DISTINCT ct.concept_id
          FROM `bigquery-public-data.cms_synthetic_patient_data_omop.concept`              AS cs
          JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.concept_relationship` AS cr
              ON cr.concept_id_1 = cs.concept_id
          JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.concept`              AS ct
              ON ct.concept_id = cr.concept_id_2
          WHERE (
                  (cs.vocabulary_id = 'ICD10CM' AND cs.concept_code LIKE 'C50%')
               OR (cs.vocabulary_id = 'ICD9CM'  AND cs.concept_code LIKE '174%')
                )
            AND cr.relationship_id = 'Maps to'
            AND ct.standard_concept  = 'S'
      )
    GROUP BY
        p.person_id, p.year_of_birth, p.month_of_birth, p.day_of_birth,
        p.gender_concept_id, p.race_concept_id, p.ethnicity_concept_id
  ),

  -- Step 2: Breast-cancer-specific surgical procedures
  surgeries AS (
    SELECT
        po.person_id,
        CAST(MIN(po.procedure_datetime) AS DATE)                          AS first_surgery_date,
        STRING_AGG(
          DISTINCT c.concept_name, '; '
          ORDER BY c.concept_name
          LIMIT 3
        )                                                                  AS surgery_procedures
    FROM `bigquery-public-data.cms_synthetic_patient_data_omop.procedure_occurrence` AS po
    INNER JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.concept`        AS c
        ON po.procedure_concept_id = c.concept_id
    WHERE po.person_id IN (SELECT person_id FROM breast_cancer_patients)
      AND (
            LOWER(c.concept_name) LIKE '%mastectomy%'
         OR LOWER(c.concept_name) LIKE '%lumpectomy%'
         OR LOWER(c.concept_name) LIKE '%excision of breast%'
         OR LOWER(c.concept_name) LIKE '%breast surgery%'
          )
    GROUP BY po.person_id
  ),

  -- Step 3: Breast-cancer-specific chemotherapy drugs
  chemotherapy AS (
    SELECT
        de.person_id,
        MIN(de.drug_exposure_start_date)                                   AS first_chemo_date,
        STRING_AGG(
          DISTINCT c.concept_name, '; '
          ORDER BY c.concept_name
          LIMIT 5
        )                                                                   AS chemo_drugs
    FROM `bigquery-public-data.cms_synthetic_patient_data_omop.drug_exposure` AS de
    INNER JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.concept` AS c
        ON de.drug_concept_id = c.concept_id
    WHERE de.person_id IN (SELECT person_id FROM breast_cancer_patients)
      AND (
            LOWER(c.concept_name) LIKE '%doxorubicin%'
         OR LOWER(c.concept_name) LIKE '%cyclophosphamide%'
         OR LOWER(c.concept_name) LIKE '%paclitaxel%'
         OR LOWER(c.concept_name) LIKE '%docetaxel%'
         OR LOWER(c.concept_name) LIKE '%fluorouracil%'
         OR LOWER(c.concept_name) LIKE '%carboplatin%'
         OR LOWER(c.concept_name) LIKE '%tamoxifen%'
         OR LOWER(c.concept_name) LIKE '%trastuzumab%'
         OR LOWER(c.concept_name) LIKE '%herceptin%'
          )
    GROUP BY de.person_id
  ),

  -- Step 4: Radiation procedures for breast cancer patients
  radiation AS (
    SELECT
        po.person_id,
        CAST(MIN(po.procedure_datetime) AS DATE)               AS first_radiation_date,
        COUNT(DISTINCT po.procedure_occurrence_id)             AS radiation_sessions
    FROM `bigquery-public-data.cms_synthetic_patient_data_omop.procedure_occurrence` AS po
    INNER JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.concept`        AS c
        ON po.procedure_concept_id = c.concept_id
    WHERE po.person_id IN (SELECT person_id FROM breast_cancer_patients)
      AND (
            LOWER(c.concept_name) LIKE '%radiation%'
         OR LOWER(c.concept_name) LIKE '%radiotherapy%'
          )
    GROUP BY po.person_id
  ),

  -- Step 5: Death information
  deaths AS (
    SELECT
        person_id,
        death_date,
        EXTRACT(YEAR FROM death_date) AS death_year
    FROM `bigquery-public-data.cms_synthetic_patient_data_omop.death`
    WHERE person_id IN (SELECT person_id FROM breast_cancer_patients)
  )

  -- Step 6: Combine everything
  SELECT
      -- Demographics
      bcp.person_id,
      gender_concept.concept_name                                              AS gender,
      race_concept.concept_name                                                AS race,
      EXTRACT(YEAR FROM bcp.first_diagnosis_date) - bcp.year_of_birth         AS age_at_diagnosis,
      bcp.year_of_birth,

      -- Diagnosis
      bcp.first_diagnosis_date,
      bcp.diagnosis_subtypes,

      -- Surgery
      CASE WHEN s.surgery_procedures IS NOT NULL THEN 'Yes' ELSE 'No' END     AS had_surgery,
      s.surgery_procedures,
      s.first_surgery_date,

      -- Chemotherapy
      CASE WHEN ch.chemo_drugs IS NOT NULL THEN 'Yes' ELSE 'No' END           AS had_chemotherapy,
      ch.chemo_drugs,
      ch.first_chemo_date,

      -- Radiation
      CASE WHEN r.first_radiation_date IS NOT NULL THEN 'Yes' ELSE 'No' END   AS had_radiation,
      r.radiation_sessions,
      r.first_radiation_date,

      -- Treatment group
      CASE
          WHEN s.surgery_procedures  IS NOT NULL
           AND ch.chemo_drugs        IS NOT NULL
           AND r.first_radiation_date IS NOT NULL  THEN 'Triple therapy'
          WHEN s.surgery_procedures  IS NOT NULL
           AND ch.chemo_drugs        IS NOT NULL    THEN 'Surgery + Chemo'
          WHEN s.surgery_procedures  IS NOT NULL
           AND r.first_radiation_date IS NOT NULL   THEN 'Surgery + Radiation'
          WHEN s.surgery_procedures  IS NOT NULL    THEN 'Surgery only'
          WHEN ch.chemo_drugs        IS NOT NULL    THEN 'Chemo only'
          WHEN r.first_radiation_date IS NOT NULL   THEN 'Radiation only'
          ELSE 'No recorded treatment'
      END                                                                      AS treatment_group,

      -- Death outcomes
      d.death_date,
      d.death_year,
      CASE WHEN d.death_date IS NOT NULL THEN 'Deceased' ELSE 'Alive' END     AS vital_status,

      -- Survival metrics
      DATE_DIFF(
          COALESCE(d.death_date, DATE '2010-12-31'),
          bcp.first_diagnosis_date,
          DAY
      )                                                                        AS survival_days,

      ROUND(
          DATE_DIFF(
              COALESCE(d.death_date, DATE '2010-12-31'),
              bcp.first_diagnosis_date,
              DAY
          ) / 365.25,
          2
      )                                                                        AS survival_years,

      CASE
          WHEN d.death_date IS NOT NULL
           AND DATE_DIFF(d.death_date, bcp.first_diagnosis_date, DAY) <= 365
          THEN 'Yes'
          ELSE 'No'
      END                                                                      AS died_within_1_year

  FROM breast_cancer_patients AS bcp

  LEFT JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.concept` AS gender_concept
      ON bcp.gender_concept_id = gender_concept.concept_id
  LEFT JOIN `bigquery-public-data.cms_synthetic_patient_data_omop.concept` AS race_concept
      ON bcp.race_concept_id = race_concept.concept_id
  LEFT JOIN surgeries    AS s  ON bcp.person_id = s.person_id
  LEFT JOIN chemotherapy AS ch ON bcp.person_id = ch.person_id
  LEFT JOIN radiation    AS r  ON bcp.person_id = r.person_id
  LEFT JOIN deaths       AS d  ON bcp.person_id = d.person_id

  ORDER BY bcp.person_id;

END;
