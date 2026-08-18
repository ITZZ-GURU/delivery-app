-- 20260817000004_addresses_rls.sql

-- 1. Ensure explicit isolation for Addresses
-- Vendors DO NOT get access to the addresses table.
-- They read addresses from the immutable `delivery_address` JSONB snapshot on the order.

DROP POLICY IF EXISTS "select_own_addresses" ON public.addresses;
DROP POLICY IF EXISTS "insert_own_addresses" ON public.addresses;
DROP POLICY IF EXISTS "update_own_addresses" ON public.addresses;
DROP POLICY IF EXISTS "delete_own_addresses" ON public.addresses;

CREATE POLICY "select_own_addresses"
ON public.addresses
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

CREATE POLICY "insert_own_addresses"
ON public.addresses
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "update_own_addresses"
ON public.addresses
FOR UPDATE
TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "delete_own_addresses"
ON public.addresses
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
