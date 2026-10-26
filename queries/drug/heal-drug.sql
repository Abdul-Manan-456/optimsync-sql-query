-- ============================================================================
-- HEAL DRUG DATA: restore empty ndc/name in public.drug from liberty_raw_data.drugs
-- ============================================================================
--
-- WHY:
--   An update job had a bug: when it pulled fresh values from the raw source
--   and the source value was empty, it blindly overwrote the previously good
--   ndc/name in public.drug with that empty value instead of skipping it.
--   Since drug.id is shared across multiple tables, these blanked-out ndc/name
--   values can cascade into anything that joins on drug.id.
--
-- HOW IT WORKS:
--   Matches public.drug to liberty_raw_data.drugs by id. A row is only
--   healed if public.drug's ndc/name is currently empty/null AND the raw
--   table has a real (non-empty) value for that same column. Existing
--   non-empty values in public.drug are never touched, and empty raw values
--   are never copied over (that would just reproduce the original bug).
--   updated_at is intentionally left untouched since this is a backfill, not
--   a genuine vendor update.
--
-- IMPACT:
--   Run the SELECT first to preview exactly which rows/columns will change
--   (drug_ndc/drug_name = current value, raw_ndc/raw_name = value it will be
--   healed to). Then run the UPDATE to apply it. On the dev DB as of this
--   writing, 205 rows are healable (name only) out of 405 rows with an empty
--   name and 5 rows with an empty ndc — the rest have no usable value in
--   liberty_raw_data.drugs either, so they are left unchanged and need a
--   different source or manual entry.
--
-- EXPECTED RESULT SHAPE (SELECT):
--   id | drug_ndc | raw_ndc | drug_name | raw_name
--   one row per healable drug, showing the before (drug_*) and the
--   after (raw_*) value it will be set to.
-- ============================================================================

-- see which drug rows are healable (empty ndc/name in public.drug, real value in liberty_raw_data.drugs)
SELECT
  d.id,
  d.ndc  AS drug_ndc,
  r.ndc  AS raw_ndc,
  d.name AS drug_name,
  r.name AS raw_name
FROM public.drug d
JOIN liberty_raw_data.drugs r ON r.id = d.id
WHERE
  ((d.ndc  IS NULL OR d.ndc  = '') AND (r.ndc  IS NOT NULL AND r.ndc  <> ''))
  OR ((d.name IS NULL OR d.name = '') AND (r.name IS NOT NULL AND r.name <> ''));

-- heal: only fills empty ndc/name from raw, never overwrites existing values or writes empty over real data
UPDATE public.drug d
SET
  ndc  = CASE WHEN (d.ndc  IS NULL OR d.ndc  = '') AND (r.ndc  IS NOT NULL AND r.ndc  <> '') THEN r.ndc  ELSE d.ndc  END,
  name = CASE WHEN (d.name IS NULL OR d.name = '') AND (r.name IS NOT NULL AND r.name <> '') THEN r.name ELSE d.name END
FROM liberty_raw_data.drugs r
WHERE r.id = d.id
  AND (
    ((d.ndc  IS NULL OR d.ndc  = '') AND (r.ndc  IS NOT NULL AND r.ndc  <> ''))
    OR ((d.name IS NULL OR d.name = '') AND (r.name IS NOT NULL AND r.name <> ''))
  );
