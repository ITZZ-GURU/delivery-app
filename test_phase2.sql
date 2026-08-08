BEGIN;
CREATE TEMP TABLE test_log (msg text);
GRANT ALL ON test_log TO public;

-- Setup: Create a test dish
INSERT INTO public.dishes (id, name, cuisine, meal_type, price)
VALUES ('99999999-9999-9999-9999-999999999999', 'RPC Test Dish', 'Test', 'Test', 150)
ON CONFLICT (id) DO NOTHING;

-- Act as Customer
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);

-- Test 1: Direct INSERT
DO $$
BEGIN
  INSERT INTO public.orders (user_id, order_number, fulfillment_type, items_total, delivery_fee, grand_total, status)
  VALUES ('11111111-1111-1111-1111-111111111111', 'ORD-DIRECT', 'pickup', 10, 0, 10, 'received');
  INSERT INTO test_log VALUES ('TEST 1: Direct INSERT allowed (FAIL)');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO test_log VALUES ('TEST 1: Direct INSERT denied (PASS) - ' || SQLERRM);
END $$;

-- Test 2: RPC with tampered price (0 instead of 150)
DO $$
BEGIN
  PERFORM public.create_order(
    'ORD-TAMPER', 'pickup', null,
    0, 0, 0, null,
    '[{"dish_id": "99999999-9999-9999-9999-999999999999", "dish_name": "Test", "quantity": 1}]'::jsonb
  );
  INSERT INTO test_log VALUES ('TEST 2: Tampered RPC allowed (FAIL)');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO test_log VALUES ('TEST 2: Tampered RPC denied (PASS) - ' || SQLERRM);
END $$;

-- Test 3: RPC with correct price
DO $$
BEGIN
  PERFORM public.create_order(
    'ORD-VALID', 'pickup', null,
    150, 0, 150, null,
    '[{"dish_id": "99999999-9999-9999-9999-999999999999", "dish_name": "Test", "quantity": 1}]'::jsonb
  );
  INSERT INTO test_log VALUES ('TEST 3: Valid RPC allowed (PASS)');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO test_log VALUES ('TEST 3: Valid RPC denied (FAIL) - ' || SQLERRM);
END $$;

SELECT * FROM test_log;
ROLLBACK;
