-- 20260817000002_orders_rls.sql

-- 1. Remove dangerous policies that give customers full CRUD
DROP POLICY IF EXISTS "update_own_orders" ON public.orders;
DROP POLICY IF EXISTS "delete_own_orders" ON public.orders;

-- 2. Drop existing vendor policies to recreate cleanly
DROP POLICY IF EXISTS "vendor_update_orders" ON public.orders;
DROP POLICY IF EXISTS "vendor_select_orders" ON public.orders;
DROP POLICY IF EXISTS "vendor_delete_orders" ON public.orders;

-- 3. Vendors can select all orders
CREATE POLICY "vendor_select_orders"
ON public.orders
FOR SELECT
TO authenticated
USING (private.is_vendor());

-- 4. Vendors can update all orders
CREATE POLICY "vendor_update_orders"
ON public.orders
FOR UPDATE
TO authenticated
USING (private.is_vendor())
WITH CHECK (private.is_vendor());

-- Note: Vendors explicitly DO NOT have a DELETE policy.
