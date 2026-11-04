-- ============================================================================
-- DELETE ORDER: delete all order_items, order_ndc_line rows and the orders
-- ============================================================================
--
-- HOW TO RUN:
--   Set the order_code list in every statement, then run them in order.
--   Two tables have a foreign key to "order", both with ON DELETE RESTRICT
--   (checked on the dev DB 2026-11-04), so both must be emptied first:
--     order_items     -> "order"           (also -> order_ndc_line)
--     order_ndc_line  -> "order"
--   Delete order: order_items, then order_ndc_line, then "order".
--   Only order_items rows are removed, the claims they point at are kept.
--
--   package_balance_entry has an order_id but no foreign key by design (the
--   ledger must outlive the order), so its rows are NOT deleted and will
--   keep pointing at the deleted order_id. Step 1 counts them. If that count
--   is not 0, the app expects the order to be set to VOID instead of deleted.
--
--   Step 1 previews what will be deleted.
--   Step 2 deletes inside a transaction. If the deleted row counts do not
--          match step 1, run ROLLBACK instead of COMMIT.


-- ----------------------------------------------------------------------------
-- STEP 1: preview - orders found and how many dependent rows each has
-- ----------------------------------------------------------------------------
SELECT
  o.id,
  o.order_code,
  (SELECT COUNT(*) FROM "order_items" oi           WHERE oi.order_id  = o.id) AS order_items_rows,
  (SELECT COUNT(*) FROM "order_ndc_line" onl       WHERE onl.order_id = o.id) AS order_ndc_line_rows,
  (SELECT COUNT(*) FROM "package_balance_entry" pb WHERE pb.order_id  = o.id) AS ledger_rows_kept
FROM "order" o
WHERE o.order_code IN (
  'jua-0007'
)
ORDER BY o.order_code;


-- ----------------------------------------------------------------------------
-- STEP 2: delete order_items, then order_ndc_line, then the orders
-- ----------------------------------------------------------------------------
BEGIN;

DELETE FROM "order_items"
WHERE order_id IN (
  SELECT id FROM "order"
  WHERE order_code IN (
    'jua-0007'
  )
);

DELETE FROM "order_ndc_line"
WHERE order_id IN (
  SELECT id FROM "order"
  WHERE order_code IN (
    'jua-0007'
  )
);

DELETE FROM "order"
WHERE order_code IN (
  'jua-0007'
);

COMMIT;   -- or run ROLLBACK instead of COMMIT if the deleted counts look wrong
