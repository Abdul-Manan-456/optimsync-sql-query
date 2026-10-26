-- ============================================================================
-- HEAL CLAIM NPI: fill empty npi in public.claim from public.pharmacy.npi
-- ============================================================================
--
-- WHY:
--   Some rows in public.claim have an empty npi (NULL, '' or whitespace only).
--   Every claim belongs to a pharmacy (claim.pharmacy_id -> pharmacy.id) and
--   the pharmacy row carries the real NPI, so the claim's npi can be restored
--   from there.
--
-- HOW IT WORKS (no-loss rules):
--   1. Only claims whose npi is currently empty are touched. A claim that
--      already has a non-empty npi is never overwritten, even if it differs
--      from its pharmacy's npi (those are only reported, see step 1).
--   2. The pharmacy value is only copied when it is itself non-empty, so an
--      empty value is never written over anything.
--   3. Claims with no pharmacy_id, with a pharmacy_id that no longer exists in
--      public.pharmacy, or whose pharmacy has an empty npi are left exactly as
--      they are (step 1 counts them so nothing is skipped silently).
--   4. The copied value is trimmed so no stray whitespace is stored.
--   5. Re-running is safe: once healed, a claim no longer matches the WHERE.
--   updated_at is intentionally left untouched since this is a backfill, not
--   a genuine update of the claim.
--
-- HOW TO RUN:
--   Step 0 confirms the column exists and shows its type.
--   Step 1 shows how many claims are empty / healable / not healable.
--   Step 2 previews every row that will change (claim_npi = current value,
--          pharmacy_npi = value it will be set to).
--   Step 3 applies the update inside a transaction and re-checks the counts.
--          If the numbers look wrong, run ROLLBACK instead of COMMIT.
--
-- EXPECTED RESULT SHAPE (step 2):
--   claim_id | pharmacy_id | pharmacy_name | claim_npi | pharmacy_npi
--   one row per healable claim, before (claim_npi) and after (pharmacy_npi).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- STEP 0: preflight - confirm public.claim.npi exists (expect exactly one row)
-- ----------------------------------------------------------------------------
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name   = 'claim'
  AND column_name  = 'npi';


-- ----------------------------------------------------------------------------
-- STEP 1: summary - how many claims are empty, healable, and why not healable
-- ----------------------------------------------------------------------------
SELECT
  COUNT(*)                                                               AS total_claims,
  COUNT(*) FILTER (WHERE c.npi IS NULL OR btrim(c.npi) = '')             AS claims_with_empty_npi,
  COUNT(*) FILTER (WHERE (c.npi IS NULL OR btrim(c.npi) = '')
                     AND ph.npi IS NOT NULL AND btrim(ph.npi) <> '')     AS healable,
  COUNT(*) FILTER (WHERE (c.npi IS NULL OR btrim(c.npi) = '')
                     AND c.pharmacy_id IS NULL)                          AS not_healable_no_pharmacy_id,
  COUNT(*) FILTER (WHERE (c.npi IS NULL OR btrim(c.npi) = '')
                     AND c.pharmacy_id IS NOT NULL AND ph.id IS NULL)    AS not_healable_pharmacy_row_missing,
  COUNT(*) FILTER (WHERE (c.npi IS NULL OR btrim(c.npi) = '')
                     AND ph.id IS NOT NULL
                     AND (ph.npi IS NULL OR btrim(ph.npi) = ''))         AS not_healable_pharmacy_npi_empty,
  -- informational only: never touched by the UPDATE
  COUNT(*) FILTER (WHERE c.npi IS NOT NULL AND btrim(c.npi) <> ''
                     AND ph.npi IS NOT NULL AND btrim(ph.npi) <> ''
                     AND btrim(c.npi) <> btrim(ph.npi))                  AS existing_npi_differs_from_pharmacy
FROM public.claim c
LEFT JOIN public.pharmacy ph ON ph.id = c.pharmacy_id;


-- ----------------------------------------------------------------------------
-- STEP 2: preview - exactly which claims will change and what they become
-- ----------------------------------------------------------------------------
SELECT
  c.id             AS claim_id,
  c.pharmacy_id,
  ph.pharmacy_name,
  c.npi            AS claim_npi,
  ph.npi           AS pharmacy_npi,
  c.date_submitted
FROM public.claim c
JOIN public.pharmacy ph ON ph.id = c.pharmacy_id
WHERE (c.npi IS NULL OR btrim(c.npi) = '')
  AND ph.npi IS NOT NULL AND btrim(ph.npi) <> ''
ORDER BY c.date_submitted DESC NULLS LAST, c.id;


-- ----------------------------------------------------------------------------
-- STEP 3: heal - only fills empty claim.npi from pharmacy.npi, never overwrites
--         an existing value and never writes an empty value
-- ----------------------------------------------------------------------------
BEGIN;

UPDATE public.claim c
SET npi = btrim(ph.npi)
FROM public.pharmacy ph
WHERE ph.id = c.pharmacy_id
  AND (c.npi IS NULL OR btrim(c.npi) = '')
  AND ph.npi IS NOT NULL AND btrim(ph.npi) <> '';

-- verify before committing:
--   still_healable            must be 0
--   still_empty_no_source     should equal the three not_healable_* counts from step 1 added together
SELECT
  COUNT(*) FILTER (WHERE (c.npi IS NULL OR btrim(c.npi) = '')
                     AND ph.npi IS NOT NULL AND btrim(ph.npi) <> '')     AS still_healable,
  COUNT(*) FILTER (WHERE c.npi IS NULL OR btrim(c.npi) = '')             AS still_empty_no_source
FROM public.claim c
LEFT JOIN public.pharmacy ph ON ph.id = c.pharmacy_id;

COMMIT;   -- or run ROLLBACK instead of COMMIT if the verification above looks wrong
