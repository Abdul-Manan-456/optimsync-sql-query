-- ============================================================================
-- DELETE INVOICE: delete all invoice_claim rows and the invoices themselves
-- ============================================================================
--
-- HOW TO RUN:
--   Set the invoice_number list in every statement, then run them in order.
--   invoice_claim must be deleted first since it references the invoice.
--   invoice_claim is the only table with a foreign key to invoice.
--   Only invoice_claim rows are removed, the claims they point at are kept.
--
--   Step 1 previews what will be deleted.
--   Step 2 deletes inside a transaction. If the deleted row counts do not
--          match step 1, run ROLLBACK instead of COMMIT.


-- ----------------------------------------------------------------------------
-- STEP 1: preview - invoices found and how many invoice_claim rows each has
-- ----------------------------------------------------------------------------
SELECT
  i.id,
  i.invoice_number,
  COUNT(ic.id) AS invoice_claim_rows
FROM "invoice" i
LEFT JOIN "invoice_claim" ic ON ic.invoice_id = i.id
WHERE i.invoice_number IN (
  'east-side-family-0001',
  'east-side-family-0002',
  'east-side-family-0003',
  'east-side-family-0004'
)
GROUP BY i.id, i.invoice_number
ORDER BY i.invoice_number;


-- ----------------------------------------------------------------------------
-- STEP 2: delete invoice_claim rows first, then the invoices
-- ----------------------------------------------------------------------------
BEGIN;

DELETE FROM "invoice_claim"
WHERE invoice_id IN (
  SELECT id FROM "invoice"
  WHERE invoice_number IN (
    'east-side-family-0001',
    'east-side-family-0002',
    'east-side-family-0003',
    'east-side-family-0004'
  )
);

DELETE FROM "invoice"
WHERE invoice_number IN (
  'east-side-family-0001',
  'east-side-family-0002',
  'east-side-family-0003',
  'east-side-family-0004'
);

COMMIT;   -- or run ROLLBACK instead of COMMIT if the deleted counts look wrong
