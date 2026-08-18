-- 20260817000003_order_items_rls.sql

-- 1. Drop all customer mutation policies on order_items
-- Since internal_create_order is SECURITY DEFINER, customers never directly insert order items.
DROP POLICY IF EXISTS "insert_own_order_items" ON public.order_items;
DROP POLICY IF EXISTS "update_own_order_items" ON public.order_items;
DROP POLICY IF EXISTS "delete_own_order_items" ON public.order_items;

-- (The select_own_order_items policy remains to securely join back to the user's order)

-- 2. Drop existing vendor policies on order_items (if any)
DROP POLICY IF EXISTS "vendor_select_order_items" ON public.order_items;
DROP POLICY IF EXISTS "vendor_update_order_items" ON public.order_items;

-- 3. Vendors can select all order items
CREATE POLICY "vendor_select_order_items"
ON public.order_items
FOR SELECT
TO authenticated
USING (private.is_vendor());

-- Note: Vendors DO NOT have INSERT, UPDATE, or DELETE on order_items.
-- Order items are immutable once created.
