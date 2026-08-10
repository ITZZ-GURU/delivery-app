-- Fix customization price validation
-- Replaces trusting client `v_mod->>'price'` with strict server-side label matching against `dishes.customizations`
-- Raises exception if a requested customization label is not found on the dish

CREATE OR REPLACE FUNCTION private.internal_create_order(
  p_order_number text,
  p_fulfillment_type text,
  p_delivery_address jsonb,
  p_items_total numeric,
  p_delivery_fee numeric,
  p_grand_total numeric,
  p_notes text,
  p_items jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order_id uuid;
  v_user_id uuid;
  v_item jsonb;
  v_dish record;
  v_calculated_items_total numeric := 0;
  v_calculated_grand_total numeric := 0;
  v_unit_price numeric;
  v_line_total numeric;
  v_mod jsonb;
  v_mod_price numeric;
  v_sanitized_customizations jsonb;
  v_sanitized_items jsonb := '[]'::jsonb;
  v_sanitized_item jsonb;
BEGIN
  -- 1. Get authenticated user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2. Verify prices by calculating totals server-side
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Fetch the exact current dish details
    SELECT * INTO v_dish FROM public.dishes WHERE id = (v_item->>'dish_id')::uuid;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Dish not found: %', v_item->>'dish_name';
    END IF;

    IF NOT v_dish.is_available THEN
      RAISE EXCEPTION 'Dish is currently unavailable: %', v_dish.name;
    END IF;

    v_unit_price := v_dish.price;
    v_line_total := v_unit_price * (v_item->>'quantity')::numeric;
    v_sanitized_customizations := '[]'::jsonb;

    -- Add customizations to the line total and sanitize
    IF v_item ? 'customizations' AND jsonb_array_length(v_item->'customizations') > 0 THEN
      FOR v_mod IN SELECT * FROM jsonb_array_elements(v_item->'customizations')
      LOOP
        v_mod_price := NULL;

        -- Look up the actual price from the dish's customizations array by exact label match
        SELECT (c->>'price')::numeric INTO v_mod_price
        FROM jsonb_array_elements(v_dish.customizations) AS c
        WHERE c->>'label' = v_mod->>'label';

        IF NOT FOUND THEN
          RAISE EXCEPTION 'Invalid customization "%" for dish "%"', v_mod->>'label', v_dish.name;
        END IF;

        v_line_total := v_line_total + (v_mod_price * (v_item->>'quantity')::numeric);
        
        -- Build sanitized customization object with server-verified price
        v_sanitized_customizations := v_sanitized_customizations || jsonb_build_object('label', v_mod->>'label', 'price', v_mod_price);
      END LOOP;
    END IF;

    v_calculated_items_total := v_calculated_items_total + v_line_total;
    
    -- Build sanitized item
    v_sanitized_item := v_item;
    v_sanitized_item := jsonb_set(v_sanitized_item, '{customizations}', v_sanitized_customizations);
    v_sanitized_item := jsonb_set(v_sanitized_item, '{dish_price}', to_jsonb(v_unit_price));
    v_sanitized_item := jsonb_set(v_sanitized_item, '{line_total}', to_jsonb(v_line_total));
    v_sanitized_items := v_sanitized_items || v_sanitized_item;
  END LOOP;

  v_calculated_grand_total := v_calculated_items_total + p_delivery_fee;

  -- 3. Compare with client totals
  IF p_items_total != v_calculated_items_total THEN
    RAISE EXCEPTION 'Items total mismatch. Client: %, Server: %', p_items_total, v_calculated_items_total;
  END IF;

  IF p_grand_total != v_calculated_grand_total THEN
    RAISE EXCEPTION 'Grand total mismatch. Client: %, Server: %', p_grand_total, v_calculated_grand_total;
  END IF;

  -- 4. Insert order
  INSERT INTO public.orders (
    user_id, order_number, status, items_total, delivery_fee, grand_total, 
    fulfillment_type, delivery_address, notes
  ) VALUES (
    v_user_id, p_order_number, 'received', v_calculated_items_total, p_delivery_fee, v_calculated_grand_total,
    p_fulfillment_type, p_delivery_address, p_notes
  ) RETURNING id INTO v_order_id;

  -- 5. Insert order items using the sanitized values
  FOR v_sanitized_item IN SELECT * FROM jsonb_array_elements(v_sanitized_items)
  LOOP
    INSERT INTO public.order_items (
      order_id, dish_id, dish_name, dish_price, quantity, customizations, line_total
    ) VALUES (
      v_order_id, 
      (v_sanitized_item->>'dish_id')::uuid, 
      v_sanitized_item->>'dish_name', 
      (v_sanitized_item->>'dish_price')::numeric, 
      (v_sanitized_item->>'quantity')::integer, 
      v_sanitized_item->'customizations', 
      (v_sanitized_item->>'line_total')::numeric
    );
  END LOOP;

  RETURN v_order_id;
END;
$$;
