# Road Safety Mission — Supabase setup

The browser app reads the Supabase project URL and **publishable/anon key** from the server-only `/api/public-config` route. Set these Vercel project variables (never use a service-role key in the browser):

- `NEXT_PUBLIC_SUPABASE_URL` (or `SUPABASE_URL`)
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (or `SUPABASE_PUBLISHABLE_KEY`)
- Legacy `NEXT_PUBLIC_SUPABASE_ANON_KEY` / `SUPABASE_ANON_KEY` is also supported.

Apply `road-safety-migration.sql` to the connected project. It adds nullable report fields, a privacy-filtered public view, submission validation, clustering thresholds and safety lifecycle tables/policies. The app uses `road_reports_public` for public report reads and `submit_road_report` for submissions. Do not grant public access to phone numbers or the base report table.

Serve the app over **HTTPS** (localhost is also allowed by browsers) for camera capture and GPS location. Without Supabase configuration, the report form runs in local demo mode; demo reports remain in that browser only.
