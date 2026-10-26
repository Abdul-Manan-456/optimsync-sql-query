WITH unique_prescriber AS (
    SELECT *
    FROM (
        SELECT *, ROW_NUMBER() OVER (PARTITION BY npi ORDER BY id DESC) as rn
        FROM "prescriber"
    ) t
    WHERE rn = 1
)

SELECT DISTINCT -- This is the key change
    up.first_name,
    up.last_name,
    up.npi,
    up.city,
    up.state,
    up.zip
FROM "claim" c
INNER JOIN "workspace_pharmacy" wp 
    ON c."pharmacy_id" = wp."pharmacy_id"
    AND wp."workspace_id" = 'org_ehxXFJpvaLBCZAxV'

JOIN "fill" f 
    ON f."prescription_id" = c."prescription_id"
    AND f."refill_number" = c."refill_number"

JOIN "prescription" p 
    ON c."prescription_id" = p."id"

JOIN "drug" dp 
    ON dp."id" = p."drug_prescribed_id"

JOIN unique_prescriber up 
    ON up."id" = p."prescriber_id"

JOIN "insurance" i_primary 
    ON i_primary."id" = f."primary_id"

JOIN "patient" pat 
    ON pat.id = p.patient_id

JOIN "pharmacy" ph 
    ON ph.id = c.pharmacy_id
WHERE c.date_submitted BETWEEN '2026-01-01' AND CURRENT_DATE