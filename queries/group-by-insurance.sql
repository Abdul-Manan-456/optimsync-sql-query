WITH unique_insurance AS (
    SELECT *
    FROM (
        SELECT 
            *, 
            ROW_NUMBER() OVER (PARTITION BY bin, pcn, group_number ORDER BY id DESC) as rn
        FROM "insurance"
    ) t
    WHERE rn = 1
)

SELECT DISTINCT
    ui.bin,
    ui.pcn,
    ui.group_number,
    ui.name AS insurance_name
FROM "claim" c
-- Filter by Workspace
INNER JOIN "workspace_pharmacy" wp 
    ON c."pharmacy_id" = wp."pharmacy_id"
    AND wp."workspace_id" = 'org_ehxXFJpvaLBCZAxV'

-- Link Claim to Fill to find the Primary Insurance ID
JOIN "fill" f 
    ON f."prescription_id" = c."prescription_id"
    AND f."refill_number" = c."refill_number"

-- Join the Deduplicated Insurance CTE
JOIN unique_insurance ui 
    ON ui."id" = f."primary_id"

-- Joining pharmacy just to ensure the claim belongs to a valid pharmacy record
JOIN "pharmacy" ph 
    ON ph.id = c.pharmacy_id
WHERE c.date_submitted BETWEEN '2026-01-01' AND CURRENT_DATE