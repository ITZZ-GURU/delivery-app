-- 20260817000001_rpc_integrity.sql

-- Drop previous versions
DROP FUNCTION IF EXISTS public.create_order(text, text, jsonb, numeric, numeric, numeric, text, jsonb);
DROP FUNCTION IF EXISTS private.internal_create_order(text, text, jsonb, numeric, numeric, numeric, text, jsonb);

CREATE OR REPLACE FUNCTION private.internal_create_order(
  p_fulfillment_type text,
  p_address_id uuid,
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
  v_order_number text;
  v_address record;
  v_address_snapshot jsonb;
  v_delivery_fee numeric := 0;
  
  v_item jsonb;
  v_dish record;
  v_quantity integer;
  v_unit_price numeric;
  v_line_total numeric;
  
  v_mod jsonb;
  v_mod_price numeric;
  v_mod_available boolean;
  
  v_calculated_items_total numeric := 0;
  v_calculated_grand_total numeric := 0;
  
  v_sanitized_customizations jsonb;
  v_sanitized_items jsonb := '[]'::jsonb;
  v_sanitized_item jsonb;
BEGIN
  -- 1. Get authenticated user
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- 2. Validate fulfillment & address ownership atomically
  IF p_fulfillment_type NOT IN ('delivery', 'pickup') THEN
    RAISE EXCEPTION 'Invalid fulfillment type';
  END IF;

  IF p_fulfillment_type = 'delivery' THEN
    IF p_address_id IS NULL THEN
      RAISE EXCEPTION 'Delivery requires an address_id';
    END IF;
    
    -- Verify address belongs to user
    SELECT * INTO v_address FROM public.addresses WHERE id = p_address_id AND user_id = v_user_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Address not found or does not belong to user';
    END IF;

    -- Snapshot address
    v_address_snapshot := jsonb_build_object(
      'label', v_address.label,
      'hostel_name', v_address.hostel_name,
      'room_number', v_address.room_number,
      'phone', v_address.phone
    );
    v_delivery_fee := 20; -- Business rule
  ELSE
    v_address_snapshot := NULL;
    v_delivery_fee := 0;
  END IF;

  -- 3. Generate Order Number
  -- Basic server-side generator
  v_order_number := 'ORD-' || floor(random() * 900000 + 100000)::text;

  -- 4. Validate items atomically
  IF jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order must contain at least one item';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_quantity := (v_item->>'quantity')::integer;
    
    -- Quantity bounds
    IF v_quantity IS NULL OR v_quantity <= 0 THEN
       RAISE EXCEPTION 'Invalid quantity: %', v_quantity;
    END IF;
    IF v_quantity > 50 THEN
       RAISE EXCEPTION 'Quantity exceeds maximum allowed per item (50)';
    END IF;

    -- Fetch dish, locking it for share to ensure it isn't modified/deleted during this transaction
    SELECT * INTO v_dish FROM public.dishes WHERE id = (v_item->>'dish_id')::uuid FOR SHARE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Dish not found: %', v_item->>'dish_id';
    END IF;

    -- Availability
    IF NOT v_dish.is_available THEN
      RAISE EXCEPTION 'Dish is currently unavailable: %', v_dish.name;
    END IF;

    v_unit_price := v_dish.price;
    v_line_total := v_unit_price * v_quantity;
    v_sanitized_customizations := '[]'::jsonb;

    -- Customization validation
    IF v_item ? 'customizations' AND jsonb_array_length(v_item->'customizations') > 0 THEN
      FOR v_mod IN SELECT * FROM jsonb_array_elements(v_item->'customizations')
      LOOP
        v_mod_price := NULL;
        v_mod_available := NULL;

        -- We look up exact match by label (or id if schema changes)
        SELECT (c->>'price')::numeric, COALESCE((c->>'is_available')::boolean, true)
        INTO v_mod_price, v_mod_available
        FROM jsonb_array_elements(v_dish.customizations) AS c
        WHERE c->>'label' = v_mod->>'label';

        IF NOT FOUND THEN
          RAISE EXCEPTION 'Invalid customization "%" for dish "%"', v_mod->>'label', v_dish.name;
        END IF;

        IF NOT v_mod_available THEN
          RAISE EXCEPTION 'Customization "%" is currently unavailable for dish "%"', v_mod->>'label', v_dish.name;
        END IF;

        v_line_total := v_line_total + (v_mod_price * v_quantity);
        v_sanitized_customizations := v_sanitized_customizations || jsonb_build_object('label', v_mod->>'label', 'price', v_mod_price);
      END LOOP;
    END IF;

    v_calculated_items_total := v_calculated_items_total + v_line_total;
    
    v_sanitized_item := jsonb_build_object(
      'dish_id', v_dish.id,
      'dish_name', v_dish.name,
      'dish_price', v_unit_price,
      'quantity', v_quantity,
      'customizations', v_sanitized_customizations,
      'line_total', v_line_total
    );
    v_sanitized_items := v_sanitized_items || v_sanitized_item;
  END LOOP;

  v_calculated_grand_total := v_calculated_items_total + v_delivery_fee;

  -- 5. Insert order
  INSERT INTO public.orders (
    user_id, order_number, status, items_total, delivery_fee, grand_total, 
    fulfillment_type, delivery_address, notes
  ) VALUES (
    v_user_id, v_order_number, 'received', v_calculated_items_total, v_delivery_fee, v_calculated_grand_total,
    p_fulfillment_type, v_address_snapshot, p_notes
  ) RETURNING id INTO v_order_id;

  -- 6. Insert order items
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

REVOKE ALL ON FUNCTION private.internal_create_order FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.internal_create_order TO authenticated;

-- Expose to API via SECURITY INVOKER
CREATE OR REPLACE FUNCTION public.create_order(
  p_fulfillment_type text,
  p_address_id uuid,
  p_notes text,
  p_items jsonb
) RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$
  SELECT private.internal_create_order(
    p_fulfillment_type,
    p_address_id,
    p_notes,
    p_items
  );
$$;

REVOKE ALL ON FUNCTION public.create_order FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_order TO authenticated;
