# Delivery App

A single-vendor food delivery application for campus/hostel environments.

## Setup

1. Copy `.env.example` to `.env` or `.env.local`:
   ```bash
   cp .env.example .env
   ```
2. Fill in your Supabase project URL and Anon Key in `.env`:
   ```
   VITE_SUPABASE_URL="https://your-project-id.supabase.co"
   VITE_SUPABASE_ANON_KEY="your-anon-key"
   ```
3. Install dependencies and start the development server:
   ```bash
   npm install
   npm run dev
   ```

## Admin Access (Vendor Role)

This application uses a strict single-vendor architecture. To gain access to the admin dashboard, you must manually assign yourself the `vendor` role in the database.

1. Sign up for an account through the frontend UI.
2. Go to your Supabase Project Dashboard -> SQL Editor.
3. Run the following SQL, replacing `<YOUR_USER_ID>` with the UUID from your `auth.users` table:
   ```sql
   INSERT INTO public.user_roles (user_id, role) 
   VALUES ('<YOUR_USER_ID>', 'vendor');
   ```

## Supabase Free Tier Note
If you are deploying this on the Supabase free tier, be aware that projects **auto-pause after 1 week of inactivity**. During semester breaks or extended periods of zero orders, the database will sleep, causing the frontend to fail to fetch data. You can un-pause it manually from the Supabase dashboard when operations resume.
