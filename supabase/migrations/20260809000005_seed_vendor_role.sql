-- This file serves as documentation for the manual role seeding process.
-- In a single-vendor architecture, we do not automate vendor provisioning 
-- to avoid race conditions and privilege escalation vulnerabilities.
-- 
-- TO ASSIGN THE VENDOR ROLE TO YOURSELF:
-- 1. Create an account via the frontend.
-- 2. Open the Supabase Dashboard -> SQL Editor.
-- 3. Find your user ID in the auth.users table.
-- 4. Execute the following INSERT statement, substituting your actual user ID:

/*
INSERT INTO public.user_roles (user_id, role) 
VALUES ('<YOUR_USER_ID>', 'vendor');
*/
