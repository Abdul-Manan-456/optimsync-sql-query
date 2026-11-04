-- ============================================================================
-- DELETE ORDER: delete all order_items and the order itself
-- ============================================================================
--
-- HOW TO RUN:
--   Set the order_code in both statements, then run them in order.
--   order_items must be deleted first since they reference the order.

DELETE FROM order_items
WHERE order_id = (
  SELECT id FROM "order" WHERE order_code = 'jua-0007'
);

DELETE FROM "order"
WHERE order_code = 'jua-0007';
