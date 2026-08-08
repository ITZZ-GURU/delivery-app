BEGIN;
CREATE TEMP TABLE test_log (msg text);
GRANT ALL ON test_log TO public;

INSERT INTO public.dishes (id, name, cuisine, meal_type, price)
VALUES ('99999999-9999-9999-9999-999999999999', 'RPC Test Dish', 'Test', 'Test', 150)
ON CONFLICT (id) DO NOTHING;

-- Act as Customer
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
SELECT set_config('request.jwt.claim.role', 'authenticated', true);

DO $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Create the test order
  v_order_id := public.create_order(
    'ORD-PHASE3', 'pickup', null,
    150, 0, 150, null,
    '[{"dish_id": "99999999-9999-9999-9999-999999999999", "dish_name": "Test", "quantity": 1}]'::jsonb
  );

  -- Test 1: Customer tries to modify the total
  BEGIN
    UPDATE public.orders SET grand_total = 0 WHERE id = v_order_id;
    INSERT INTO test_log VALUES ('TEST 1: Customer modified total (FAIL)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_log VALUES ('TEST 1: Customer modified total denied (PASS) - ' || SQLERRM);
  END;

  -- Test 2: Customer tries to change status to 'delivered'
  BEGIN
    UPDATE public.orders SET status = 'delivered' WHERE id = v_order_id;
    INSERT INTO test_log VALUES ('TEST 2: Customer changed status to delivered (FAIL)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_log VALUES ('TEST 2: Customer changed status to delivered denied (PASS) - ' || SQLERRM);
  END;

  -- Test 3: Customer adds notes (allowed)
  BEGIN
    UPDATE public.orders SET notes = 'Extra spicy' WHERE id = v_order_id;
    INSERT INTO test_log VALUES ('TEST 3: Customer updated notes allowed (PASS)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_log VALUES ('TEST 3: Customer updated notes denied (FAIL) - ' || SQLERRM);
  END;

  -- Test 4: Customer cancels order (allowed since it is 'received')
  BEGIN
    UPDATE public.orders SET status = 'cancelled' WHERE id = v_order_id;
    INSERT INTO test_log VALUES ('TEST 4: Customer cancelled order allowed (PASS)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_log VALUES ('TEST 4: Customer cancelled order denied (FAIL) - ' || SQLERRM);
  END;
END $$;

-- Act as Vendor
SELECT set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);

DO $$
DECLARE
  v_order_id uuid;
BEGIN
  -- Create a new order for the vendor to update, acting as customer first
  PERFORM set_config('request.jwt.claim.sub', '11111111-1111-1111-1111-111111111111', true);
  v_order_id := public.create_order(
    'ORD-PHASE3-2', 'pickup', null,
    150, 0, 150, null,
    '[{"dish_id": "99999999-9999-9999-9999-999999999999", "dish_name": "Test", "quantity": 1}]'::jsonb
  );

  -- Switch back to vendor
  PERFORM set_config('request.jwt.claim.sub', '22222222-2222-2222-2222-222222222222', true);
  
  -- Test 5: Vendor changes status to 'delivered'
  BEGIN
    UPDATE public.orders SET status = 'delivered' WHERE id = v_order_id;
    INSERT INTO test_log VALUES ('TEST 5: Vendor changed status to delivered allowed (PASS)');
  EXCEPTION WHEN OTHERS THEN
    INSERT INTO test_log VALUES ('TEST 5: Vendor changed status to delivered denied (FAIL) - ' || SQLERRM);
  END;
END $$;

SELECT * FROM test_log;
ROLLBACK;
