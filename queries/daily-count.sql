SELECT 
    c.date_submitted::date AS submission_day,
    -- i_primary.bin,
    -- i_primary.pcn,
    -- i_primary.group_number,
    -- pr.first_name,
    -- pr.last_name,
    -- pr.npi,
    -- pr.city,
    -- pr.state,
    COUNT(c.id) AS total_claims
FROM "claim" c
-- Filter by Workspace
INNER JOIN "workspace_pharmacy" wp 
    ON c."pharmacy_id" = wp."pharmacy_id"
    AND wp."workspace_id" = 'org_ehxXFJpvaLBCZAxV'

-- Join to Fill to get to Insurance
JOIN "fill" f 
    ON f."prescription_id" = c."prescription_id"
    AND f."refill_number" = c."refill_number"

-- Join directly to raw Insurance table (no unique CTE)
JOIN "insurance" i_primary 
    ON i_primary."id" = f."primary_id"
JOIN "prescription" p 
    ON c."prescription_id" = p."id"
  
JOIN "prescriber" pr 
    ON pr."id" = p."prescriber_id"

-- Date Filter
WHERE c.date_submitted BETWEEN '2026-01-01' AND CURRENT_DATE

-- Grouping by the date and the payer info
GROUP BY 
    c.date_submitted::date
    -- pr.first_name,
    -- pr.last_name,
    -- pr.npi,
    -- pr.city,
    -- pr.state,
    -- i_primary.bin, 
    -- i_primary.pcn, 
    -- i_primary.group_number

-- Sort by newest date first
ORDER BY submission_day DESC;