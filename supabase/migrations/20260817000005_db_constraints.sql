-- 20260817000005_db_constraints.sql

-- 1. Orders table constraints
ALTER TABLE public.orders 
  ADD CONSTRAINT check_items_total_non_negative CHECK (items_total >= 0),
  ADD CONSTRAINT check_delivery_fee_non_negative CHECK (delivery_fee >= 0),
  ADD CONSTRAINT check_grand_total_non_negative CHECK (grand_total >= 0),
  ADD CONSTRAINT unique_order_number UNIQUE (order_number),
  ADD CONSTRAINT check_status_valid CHECK (status IN ('received', 'preparing', 'out_for_delivery', 'delivered', 'cancelled')),
  ADD CONSTRAINT check_fulfillment_valid CHECK (fulfillment_type IN ('delivery', 'pickup'));

-- 2. Order Items table constraints
-- Drop the existing loose check constraint first if it exists
ALTER TABLE public.order_items DROP CONSTRAINT IF EXISTS order_items_quantity_check;

ALTER TABLE public.order_items 
  ADD CONSTRAINT check_quantity_bounds CHECK (quantity > 0 AND quantity <= 50),
  ADD CONSTRAINT check_dish_price_non_negative CHECK (dish_price >= 0),
  ADD CONSTRAINT check_line_total_non_negative CHECK (line_total >= 0);

-- 3. Dishes catalog constraints
ALTER TABLE public.dishes 
  ADD CONSTRAINT check_dish_price_non_negative CHECK (price >= 0);

-- 4. User roles constraints
-- Existing schema has: role text NOT NULL CHECK (role = 'vendor')
-- (No change needed)
