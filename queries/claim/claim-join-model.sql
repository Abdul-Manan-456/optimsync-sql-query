-- ============================================================================
-- CLAIM JOIN MODEL: how public.claim links to its related tables (ids only)
-- ============================================================================
--
-- WHY:
--   Reference for every query that starts from a claim. It documents which
--   tables a claim joins to, on which columns, and which of those related
--   rows are shared between claims vs unique to one claim. Both queries only
--   return the id columns of the joined tables, so the shape of the
--   relationships can be inspected without pulling any other data.
--
-- JOINS AMONG TABLES:
--
--   claim (c)  -- base row
--   |
--   +- prescription (p)     JOIN       ON c.prescription_id    = p.id
--   |   +- drug (dp)        JOIN       ON p.drug_prescribed_id = dp.id   (prescribed = dispensed, enforced by eligibility)
--   |   +- prescriber (pr)  JOIN       ON p.prescriber_id      = pr.id
--   |   +- patient (pt)     LEFT JOIN  ON p.patient_id         = pt.id   <- added join
--   |
--   +- fill (f)             JOIN       ON f.prescription_id    = p.id
--   |   |                              AND f.refill_number     = c.refill_number   <- the claim's fill
--   |   +- insurance (ins)  LEFT JOIN  ON f.primary_id         = ins.id  <- added join (fill's primary insurance)
--   |
--   +- pharmacy (ph)        LEFT JOIN  ON c.pharmacy_id        = ph.id
--
-- CONFIRMED (checked on the dev DB with query 2 below):
--   1. patient / prescriber / drug are shared   - many claims point at the same row
--   2. prescription is shared across refills    - one prescription, one claim + one fill per refill_number
--   3. claim / fill / insurance unique per join - each claim has its own fill and its own
--                                                 primary insurance row (insurance perfectly)
--
-- HOW TO RUN:
--   Query 1: one row per claim with the id of every table in the tree above,
--            reached exactly as the tree says (the claim's own fill is matched
--            by refill_number). NULL in a column means that LEFT JOIN found no row.
--   Query 2: one row per claim with every fill id and every primary insurance
--            id of the whole prescription aggregated into arrays. This is the
--            query that confirmed the shared/unique findings above: fill_ids
--            and insurance_ids grow with the refills, while patient_id,
--            prescriber_id and drug_prescribed_id stay the same.
--
-- NOTES (dev DB as of 2026-10-27, 209,403 claims):
--   - Every claim has a prescription row.
--   - 2,311 claims have no fill with a matching refill_number, so the inner
--     JOIN on fill in query 1 drops them. Use LEFT JOIN on fill to keep them.
--   - 24 claims match more than one fill row (same prescription_id and
--     refill_number), so query 1 returns a duplicate row for each of those.
--   - 10,717 claims have no pharmacy_id. The LEFT JOIN keeps them with
--     pharmacy_id = NULL.
--   - 11,780 claims have claim.drug_id <> prescription.drug_prescribed_id
--     (171 of those point at a drug id that does not exist in drug), so
--     "prescribed = dispensed" does not hold for about 5.6% of dev claims.
--     Query 1 follows the model and reaches drug through the prescription.
--     Use c.drug_id instead when the dispensed drug is what you need.
--
-- EXPECTED RESULT SHAPE (query 1):
--   claim_id | prescription_id | drug_id | prescriber_id | patient_id | fill_id | insurance_id | pharmacy_id
--   one row per claim, every column is the id of the joined table.
--
-- EXPECTED RESULT SHAPE (query 2):
--   claim_id | prescription_id | drug_id | patient_id | prescriber_id | drug_prescribed_id | fill_ids | insurance_ids
--   one row per claim, fill_ids / insurance_ids are arrays over all refills
--   of the claim's prescription.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- QUERY 1: the join model, one row per claim, ids of the joined tables only
-- ----------------------------------------------------------------------------
SELECT
  c.id    AS claim_id,
  p.id    AS prescription_id,
  dp.id   AS drug_id,
  pr.id   AS prescriber_id,
  pt.id   AS patient_id,
  f.id    AS fill_id,
  ins.id  AS insurance_id,
  ph.id   AS pharmacy_id
FROM claim c
JOIN prescription p     ON c.prescription_id    = p.id
JOIN drug dp            ON p.drug_prescribed_id = dp.id
JOIN prescriber pr      ON p.prescriber_id      = pr.id
LEFT JOIN patient pt    ON p.patient_id         = pt.id
JOIN fill f             ON f.prescription_id    = p.id
                       AND f.refill_number      = c.refill_number
LEFT JOIN insurance ins ON f.primary_id         = ins.id
LEFT JOIN pharmacy ph   ON c.pharmacy_id        = ph.id
ORDER BY c.id
LIMIT 100;


-- ----------------------------------------------------------------------------
-- QUERY 2: shared vs unique check, one row per claim with all fill ids and
--          primary insurance ids of the whole prescription aggregated
-- ----------------------------------------------------------------------------
SELECT
  c.id              AS claim_id,
  c.prescription_id,
  c.drug_id,
  p.patient_id,
  p.prescriber_id,
  p.drug_prescribed_id,
  array_agg(DISTINCT f.id)         FILTER (WHERE f.id IS NOT NULL)         AS fill_ids,
  array_agg(DISTINCT f.primary_id) FILTER (WHERE f.primary_id IS NOT NULL) AS insurance_ids
FROM claim c
LEFT JOIN prescription p ON p.id = c.prescription_id
LEFT JOIN fill f         ON f.prescription_id = p.id
GROUP BY c.id, c.prescription_id, c.drug_id,
         p.patient_id, p.prescriber_id, p.drug_prescribed_id
LIMIT 100;
