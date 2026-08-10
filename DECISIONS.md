# Architectural Decisions

## 1. Single-Vendor Architecture
This application is designed and maintained as a **single-operator tool**, not a multi-tenant SaaS platform. 

While the database utilizes a `user_roles` table and an `is_vendor()` RPC function to implement Role-Based Access Control (RBAC), these mechanisms exist solely to maintain clean Row Level Security (RLS) hygiene. We will not build or maintain automated vendor onboarding infrastructure, invitation flows, or tenant partitioning logic.

Vendor provisioning is strictly a manual process performed by the database owner via direct SQL insertion into the `user_roles` table.

## 2. Deprecation of `profiles.role` for Authorization
The `role` column in the `public.profiles` table is **not used for authorization**. 

The `public.user_roles` table is the single source of truth for elevated access. Any authorization checks in the frontend or backend (via RLS or RPCs) must query `user_roles` (or use the `private.is_vendor()` helper). 

While the auth trigger (`handle_new_user`) currently inserts a default `'customer'` role into `profiles`, this value is vestigial and must never be relied upon for access control to prevent split-brain authorization bugs.
