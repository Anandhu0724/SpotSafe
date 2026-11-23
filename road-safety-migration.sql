BEGIN;

-- Every column added to the existing report table is nullable so legacy rows remain valid.
ALTER TABLE public.road_reports
  ADD COLUMN IF NOT EXISTS road_type text,
  ADD COLUMN IF NOT EXISTS road_number text,
  ADD COLUMN IF NOT EXISTS chainage text,
  ADD COLUMN IF NOT EXISTS location_type text,
  ADD COLUMN IF NOT EXISTS incident_known boolean,
  ADD COLUMN IF NOT EXISTS incident_date date,
  ADD COLUMN IF NOT EXISTS time_of_day text,
  ADD COLUMN IF NOT EXISTS severity text,
  ADD COLUMN IF NOT EXISTS fatalities integer,
  ADD COLUMN IF NOT EXISTS injuries integer,
  ADD COLUMN IF NOT EXISTS victim_type text,
  ADD COLUMN IF NOT EXISTS weather text,
  ADD COLUMN IF NOT EXISTS hazards text[],
  ADD COLUMN IF NOT EXISTS countermeasure text,
  ADD COLUMN IF NOT EXISTS district text,
  ADD COLUMN IF NOT EXISTS crash_type text,
  ADD COLUMN IF NOT EXISTS review_status text,
  ADD COLUMN IF NOT EXISTS duplicate_of uuid REFERENCES public.road_reports(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS device_hash text;

CREATE INDEX IF NOT EXISTS road_reports_created_at_idx ON public.road_reports (created_at DESC);
CREATE INDEX IF NOT EXISTS road_reports_device_created_idx ON public.road_reports (device_hash, created_at DESC);

CREATE SEQUENCE IF NOT EXISTS public.road_black_spot_code_seq START WITH 1 INCREMENT BY 1;

CREATE TABLE IF NOT EXISTS public.road_safety_admins (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  added_at timestamptz DEFAULT now()
);
ALTER TABLE public.road_safety_admins ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.road_safety_admins FROM anon, authenticated;
GRANT SELECT ON public.road_safety_admins TO authenticated;
DROP POLICY IF EXISTS road_safety_admins_read_self ON public.road_safety_admins;
CREATE POLICY road_safety_admins_read_self ON public.road_safety_admins
  FOR SELECT TO authenticated USING (user_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.is_road_safety_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM public.road_safety_admins a
    WHERE a.user_id = (SELECT auth.uid())
  );
$function$;
REVOKE ALL ON FUNCTION public.is_road_safety_admin() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_road_safety_admin() TO authenticated;

CREATE TABLE IF NOT EXISTS public.road_safety_thresholds (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  road_type text,
  multiplier integer,
  annual_crashes_per_500m numeric,
  reaction_order text,
  source text,
  updated_at timestamptz DEFAULT now(),
  UNIQUE (road_type, multiplier)
);
ALTER TABLE public.road_safety_thresholds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.road_safety_thresholds FROM anon, authenticated;
GRANT SELECT ON public.road_safety_thresholds TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.road_safety_thresholds TO authenticated;
DROP POLICY IF EXISTS road_safety_thresholds_public_read ON public.road_safety_thresholds;
CREATE POLICY road_safety_thresholds_public_read ON public.road_safety_thresholds
  FOR SELECT TO anon, authenticated USING (true);
DROP POLICY IF EXISTS road_safety_thresholds_admin_write ON public.road_safety_thresholds;
CREATE POLICY road_safety_thresholds_admin_write ON public.road_safety_thresholds
  FOR ALL TO authenticated USING (public.is_road_safety_admin())
  WITH CHECK (public.is_road_safety_admin());

INSERT INTO public.road_safety_thresholds (road_type, multiplier, annual_crashes_per_500m, reaction_order, source)
VALUES
  ('National Highway', 3, 7.55, '4th order', 'IRC:131-2022 Annexure B; Kerala AATC 5.04/km'),
  ('National Highway', 5, 12.59, '3rd order', 'IRC:131-2022 Annexure B; Kerala AATC 5.04/km'),
  ('National Highway', 10, 25.18, '2nd order', 'IRC:131-2022 Annexure B; Kerala AATC 5.04/km'),
  ('National Highway', 15, 37.77, '1st order', 'IRC:131-2022 Annexure B; Kerala AATC 5.04/km'),
  ('State Highway', 3, 2.50, '4th order', 'IRC:131-2022 Annexure B; Kerala AATC 1.67/km'),
  ('State Highway', 5, 4.17, '3rd order', 'IRC:131-2022 Annexure B; Kerala AATC 1.67/km'),
  ('State Highway', 10, 8.34, '2nd order', 'IRC:131-2022 Annexure B; Kerala AATC 1.67/km'),
  ('State Highway', 15, 12.51, '1st order', 'IRC:131-2022 Annexure B; Kerala AATC 1.67/km'),
  ('Major District Road', 3, 1.26, '4th order', 'IRC:131-2022 Annexure B; Kerala ODR AATC 0.84/km'),
  ('Major District Road', 5, 2.09, '3rd order', 'IRC:131-2022 Annexure B; Kerala ODR AATC 0.84/km'),
  ('Major District Road', 10, 4.18, '2nd order', 'IRC:131-2022 Annexure B; Kerala ODR AATC 0.84/km'),
  ('Major District Road', 15, 6.28, '1st order', 'IRC:131-2022 Annexure B; Kerala ODR AATC 0.84/km')
ON CONFLICT (road_type, multiplier) DO UPDATE SET
  annual_crashes_per_500m = EXCLUDED.annual_crashes_per_500m,
  reaction_order = EXCLUDED.reaction_order,
  source = EXCLUDED.source,
  updated_at = now();

CREATE TABLE IF NOT EXISTS public.road_black_spots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  spot_code text UNIQUE DEFAULT ('KL-' || lpad(nextval('public.road_black_spot_code_seq')::text, 3, '0')),
  anchor_report_id uuid UNIQUE REFERENCES public.road_reports(id) ON DELETE SET NULL,
  status text DEFAULT 'Under Review',
  verified_at timestamptz,
  short_term_due_at timestamptz,
  monitoring_ends_at timestamptz,
  rectified_at timestamptz,
  treatment_note text,
  before_photo_url text,
  after_photo_url text,
  countermeasure text,
  treatment_horizon text,
  merged_into_id uuid REFERENCES public.road_black_spots(id) ON DELETE SET NULL,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  CONSTRAINT road_black_spots_status_check CHECK (status IS NULL OR status IN (
    'Reported', 'Under Review', 'Verified Black Spot', 'Under Rectification',
    'Partially Rectified', 'Rectified', 'Monitoring', 'Rejected', 'Merged'
  )),
  CONSTRAINT road_black_spots_horizon_check CHECK (treatment_horizon IS NULL OR treatment_horizon IN ('Short-term', 'Long-term'))
);
ALTER TABLE public.road_black_spots ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.road_black_spots FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.road_black_spots TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.road_black_spot_code_seq TO authenticated;
DROP POLICY IF EXISTS road_black_spots_admin_access ON public.road_black_spots;
CREATE POLICY road_black_spots_admin_access ON public.road_black_spots
  FOR ALL TO authenticated USING (public.is_road_safety_admin())
  WITH CHECK (public.is_road_safety_admin());

CREATE TABLE IF NOT EXISTS public.road_report_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid REFERENCES public.road_reports(id) ON DELETE CASCADE,
  black_spot_id uuid REFERENCES public.road_black_spots(id) ON DELETE CASCADE,
  status text,
  note text,
  before_photo_url text,
  after_photo_url text,
  countermeasure text,
  treatment_horizon text,
  actor_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.road_report_events ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.road_report_events FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.road_report_events TO authenticated;
DROP POLICY IF EXISTS road_report_events_public_read ON public.road_report_events;
DROP POLICY IF EXISTS road_report_events_admin_read ON public.road_report_events;
CREATE POLICY road_report_events_admin_read ON public.road_report_events
  FOR SELECT TO authenticated USING (public.is_road_safety_admin());
DROP POLICY IF EXISTS road_report_events_admin_write ON public.road_report_events;
CREATE POLICY road_report_events_admin_write ON public.road_report_events
  FOR INSERT TO authenticated WITH CHECK (public.is_road_safety_admin());
CREATE POLICY road_report_events_admin_update ON public.road_report_events
  FOR UPDATE TO authenticated USING (public.is_road_safety_admin())
  WITH CHECK (public.is_road_safety_admin());
CREATE POLICY road_report_events_admin_delete ON public.road_report_events
  FOR DELETE TO authenticated USING (public.is_road_safety_admin());

CREATE TABLE IF NOT EXISTS public.road_report_followups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid REFERENCES public.road_reports(id) ON DELETE SET NULL,
  black_spot_id uuid REFERENCES public.road_black_spots(id) ON DELETE SET NULL,
  followup_type text DEFAULT 'Still unsafe',
  note text,
  photo_url text,
  device_hash text,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.road_report_followups ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.road_report_followups FROM anon, authenticated;
GRANT INSERT ON public.road_report_followups TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.road_report_followups TO authenticated;
DROP POLICY IF EXISTS road_report_followups_public_insert ON public.road_report_followups;
CREATE POLICY road_report_followups_public_insert ON public.road_report_followups
  FOR INSERT TO anon, authenticated WITH CHECK (
    (followup_type IS NULL OR followup_type IN ('Still unsafe', 'Follow-up photo'))
    AND (note IS NULL OR char_length(note) <= 600)
  );
DROP POLICY IF EXISTS road_report_followups_admin_read ON public.road_report_followups;
CREATE POLICY road_report_followups_admin_read ON public.road_report_followups
  FOR SELECT TO authenticated USING (public.is_road_safety_admin());
CREATE POLICY road_report_followups_admin_manage ON public.road_report_followups
  FOR UPDATE TO authenticated USING (public.is_road_safety_admin())
  WITH CHECK (public.is_road_safety_admin());
CREATE POLICY road_report_followups_admin_delete ON public.road_report_followups
  FOR DELETE TO authenticated USING (public.is_road_safety_admin());

CREATE TABLE IF NOT EXISTS public.road_site_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  black_spot_id uuid REFERENCES public.road_black_spots(id) ON DELETE SET NULL,
  report_id uuid REFERENCES public.road_reports(id) ON DELETE SET NULL,
  physical_checklist jsonb,
  operational_checklist jsonb,
  notes text,
  created_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at timestamptz DEFAULT now()
);
ALTER TABLE public.road_site_visits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.road_site_visits FROM anon, authenticated;
GRANT INSERT ON public.road_site_visits TO anon, authenticated;
GRANT SELECT, UPDATE, DELETE ON public.road_site_visits TO authenticated;
DROP POLICY IF EXISTS road_site_visits_public_insert ON public.road_site_visits;
CREATE POLICY road_site_visits_public_insert ON public.road_site_visits
  FOR INSERT TO anon, authenticated WITH CHECK (
    (notes IS NULL OR char_length(notes) <= 1200)
    AND jsonb_typeof(physical_checklist) IN ('object', 'array')
    AND jsonb_typeof(operational_checklist) IN ('object', 'array')
  );
DROP POLICY IF EXISTS road_site_visits_admin_read ON public.road_site_visits;
CREATE POLICY road_site_visits_admin_read ON public.road_site_visits
  FOR SELECT TO authenticated USING (public.is_road_safety_admin());
CREATE POLICY road_site_visits_admin_manage ON public.road_site_visits
  FOR UPDATE TO authenticated USING (public.is_road_safety_admin())
  WITH CHECK (public.is_road_safety_admin());
CREATE POLICY road_site_visits_admin_delete ON public.road_site_visits
  FOR DELETE TO authenticated USING (public.is_road_safety_admin());

CREATE OR REPLACE FUNCTION public.submit_road_report(p_report jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_name text := nullif(pg_catalog.btrim(p_report ->> 'name'), '');
  v_phone text := nullif(pg_catalog.btrim(p_report ->> 'phone'), '');
  v_place text := nullif(pg_catalog.btrim(p_report ->> 'place'), '');
  v_solution text := nullif(pg_catalog.btrim(p_report ->> 'solution'), '');
  v_lat double precision;
  v_lng double precision;
  v_photo_url text := nullif(pg_catalog.btrim(p_report ->> 'photo_url'), '');
  v_device_hash text := nullif(p_report ->> 'device_hash', '');
  v_incident_known boolean := coalesce((p_report ->> 'incident_known')::boolean, false);
  v_fatalities integer;
  v_injuries integer;
  v_hazards text[];
  v_report_id uuid;
BEGIN
  IF pg_catalog.jsonb_typeof(p_report) <> 'object' THEN
    RAISE EXCEPTION 'Report data is invalid.' USING ERRCODE = '22023';
  END IF;
  IF v_name IS NULL OR pg_catalog.char_length(v_name) NOT BETWEEN 2 AND 80 THEN
    RAISE EXCEPTION 'Enter a name between 2 and 80 characters.' USING ERRCODE = '22023';
  END IF;
  IF v_phone IS NULL OR v_phone !~ '^[6-9][0-9]{9}$' THEN
    RAISE EXCEPTION 'Enter a valid 10-digit Indian mobile number.' USING ERRCODE = '22023';
  END IF;
  IF v_place IS NULL OR pg_catalog.char_length(v_place) NOT BETWEEN 3 AND 160 THEN
    RAISE EXCEPTION 'Enter a place or landmark between 3 and 160 characters.' USING ERRCODE = '22023';
  END IF;
  IF pg_catalog.length(coalesce(v_solution, '')) > 600 THEN
    RAISE EXCEPTION 'Keep the suggestion within 600 characters.' USING ERRCODE = '22023';
  END IF;
  IF v_photo_url IS NULL OR v_photo_url !~ '^https://[^/]+/storage/v1/object/public/report-photos/.+[.]jpg$' THEN
    RAISE EXCEPTION 'Add a JPEG photo before submitting.' USING ERRCODE = '22023';
  END IF;
  IF coalesce(p_report ->> 'lat', '') !~ '^-?[0-9]+([.][0-9]+)?$' OR coalesce(p_report ->> 'lng', '') !~ '^-?[0-9]+([.][0-9]+)?$' THEN
    RAISE EXCEPTION 'Choose a location within Kerala.' USING ERRCODE = '22023';
  END IF;
  v_lat := (p_report ->> 'lat')::double precision;
  v_lng := (p_report ->> 'lng')::double precision;
  IF v_lat NOT BETWEEN 7.9 AND 12.95 OR v_lng NOT BETWEEN 74.6 AND 77.5 THEN
    RAISE EXCEPTION 'Choose a location within Kerala.' USING ERRCODE = '22023';
  END IF;
  IF v_device_hash IS NOT NULL AND v_device_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'This device could not be verified. Please try again.' USING ERRCODE = '22023';
  END IF;
  IF v_device_hash IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.road_reports r
    WHERE r.device_hash = v_device_hash
      AND r.created_at >= now() - interval '24 hours'
      AND 6371008.8 * 2 * pg_catalog.asin(pg_catalog.sqrt(
        pg_catalog.sin(pg_catalog.radians(r.lat - v_lat) / 2) ^ 2
        + pg_catalog.cos(pg_catalog.radians(v_lat)) * pg_catalog.cos(pg_catalog.radians(r.lat))
        * pg_catalog.sin(pg_catalog.radians(r.lng - v_lng) / 2) ^ 2
      )) <= 50
  ) THEN
    RAISE EXCEPTION 'A report from this device is already on file within 50 metres. Please review the map before sending another.' USING ERRCODE = '23505';
  END IF;
  IF (p_report ->> 'fatalities') IS NOT NULL AND (p_report ->> 'fatalities') !~ '^[0-9]{1,3}$' THEN
    RAISE EXCEPTION 'Number killed must be a whole number from 0 to 999.' USING ERRCODE = '22023';
  END IF;
  IF (p_report ->> 'injuries') IS NOT NULL AND (p_report ->> 'injuries') !~ '^[0-9]{1,3}$' THEN
    RAISE EXCEPTION 'Number injured must be a whole number from 0 to 999.' USING ERRCODE = '22023';
  END IF;
  v_fatalities := nullif(p_report ->> 'fatalities', '')::integer;
  v_injuries := nullif(p_report ->> 'injuries', '')::integer;
  IF v_incident_known AND (
    p_report ->> 'incident_date' IS NULL OR
    p_report ->> 'time_of_day' NOT IN ('Day', 'Night') OR
    p_report ->> 'severity' NOT IN ('Fatal', 'Grievous', 'Minor', 'No injury')
  ) THEN
    RAISE EXCEPTION 'Add the crash date, time of day, and severity.' USING ERRCODE = '22023';
  END IF;
  IF (p_report ->> 'road_type') IS NOT NULL AND (p_report ->> 'road_type') NOT IN ('National Highway', 'State Highway', 'Major District Road', 'Other') THEN
    RAISE EXCEPTION 'Choose a valid road type.' USING ERRCODE = '22023';
  END IF;
  IF (p_report ->> 'location_type') IS NOT NULL AND (p_report ->> 'location_type') NOT IN ('Junction', 'Mid-block', 'Bend or curve', 'Median opening', 'Bridge or culvert', 'Railway crossing', 'Pedestrian crossing') THEN
    RAISE EXCEPTION 'Choose a valid location type.' USING ERRCODE = '22023';
  END IF;
  IF (p_report ->> 'weather') IS NOT NULL AND (p_report ->> 'weather') NOT IN ('Sunny', 'Rainy', 'Foggy') THEN
    RAISE EXCEPTION 'Choose a valid weather condition.' USING ERRCODE = '22023';
  END IF;
  v_hazards := CASE WHEN pg_catalog.jsonb_typeof(p_report -> 'hazards') = 'array'
    THEN ARRAY(SELECT pg_catalog.jsonb_array_elements_text(p_report -> 'hazards'))
    ELSE ARRAY[]::text[] END;

  INSERT INTO public.road_reports (
    name, phone, place, solution, lat, lng, photo_url, road_type, road_number, chainage,
    location_type, incident_known, incident_date, time_of_day, severity, fatalities, injuries,
    victim_type, weather, hazards, countermeasure, district, crash_type, device_hash
  ) VALUES (
    v_name, v_phone, v_place, v_solution, v_lat, v_lng, v_photo_url,
    nullif(p_report ->> 'road_type', ''), nullif(pg_catalog.btrim(p_report ->> 'road_number'), ''),
    nullif(pg_catalog.btrim(p_report ->> 'chainage'), ''), nullif(p_report ->> 'location_type', ''),
    v_incident_known, nullif(p_report ->> 'incident_date', '')::date,
    nullif(p_report ->> 'time_of_day', ''), nullif(p_report ->> 'severity', ''),
    v_fatalities, v_injuries, nullif(p_report ->> 'victim_type', ''),
    nullif(p_report ->> 'weather', ''), v_hazards, nullif(p_report ->> 'countermeasure', ''),
    nullif(pg_catalog.btrim(p_report ->> 'district'), ''), nullif(p_report ->> 'crash_type', ''),
    v_device_hash
  ) RETURNING id INTO v_report_id;
  RETURN v_report_id;
END;
$function$;
REVOKE ALL ON FUNCTION public.submit_road_report(jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_road_report(jsonb) TO anon, authenticated;

-- Public display is an explicit allowlist: phone, device hash, duplicate link, and admin identity stay private.
CREATE OR REPLACE VIEW public.road_reports_public WITH (security_barrier = true) AS
SELECT id, name, place, solution, lat, lng, photo_url, created_at,
       road_type, road_number, chainage, location_type, incident_known, incident_date,
       time_of_day, severity, fatalities, injuries, victim_type, weather, hazards,
       countermeasure, district, crash_type, review_status
FROM public.road_reports;
REVOKE ALL ON public.road_reports_public FROM anon, authenticated;
GRANT SELECT ON public.road_reports_public TO anon, authenticated;

-- All direct writes go through submit_road_report(); only an admin can review or merge reports.
ALTER TABLE public.road_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.road_reports FROM anon, authenticated;
GRANT SELECT ON public.road_reports TO authenticated;
GRANT UPDATE (review_status, duplicate_of) ON public.road_reports TO authenticated;
DROP POLICY IF EXISTS "anonymous can submit road reports" ON public.road_reports;
DROP POLICY IF EXISTS road_reports_admin_read ON public.road_reports;
CREATE POLICY road_reports_admin_read ON public.road_reports
  FOR SELECT TO authenticated USING (public.is_road_safety_admin());
DROP POLICY IF EXISTS road_reports_admin_update ON public.road_reports;
CREATE POLICY road_reports_admin_update ON public.road_reports
  FOR UPDATE TO authenticated USING (public.is_road_safety_admin())
  WITH CHECK (public.is_road_safety_admin());

CREATE OR REPLACE VIEW public.road_black_spots_public WITH (security_barrier = true) AS
SELECT id, spot_code, anchor_report_id, status, verified_at, short_term_due_at,
       monitoring_ends_at, rectified_at, treatment_note, before_photo_url,
       after_photo_url, countermeasure, treatment_horizon, merged_into_id, created_at, updated_at
FROM public.road_black_spots;
REVOKE ALL ON public.road_black_spots_public FROM anon, authenticated;
GRANT SELECT ON public.road_black_spots_public TO anon, authenticated;

CREATE OR REPLACE VIEW public.road_report_events_public WITH (security_barrier = true) AS
SELECT id, report_id, black_spot_id, status, note, before_photo_url, after_photo_url,
       countermeasure, treatment_horizon, created_at
FROM public.road_report_events;
REVOKE ALL ON public.road_report_events_public FROM anon, authenticated;
GRANT SELECT ON public.road_report_events_public TO anon, authenticated;

CREATE OR REPLACE VIEW public.road_report_followups_public WITH (security_barrier = true) AS
SELECT id, report_id, black_spot_id, followup_type, note, photo_url, created_at
FROM public.road_report_followups;
REVOKE ALL ON public.road_report_followups_public FROM anon, authenticated;
GRANT SELECT ON public.road_report_followups_public TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_road_safety_clusters()
RETURNS TABLE (
  cluster_id text,
  anchor_report_id uuid,
  center_lat double precision,
  center_lng double precision,
  report_count bigint,
  fatal_crashes bigint,
  grievous_crashes bigint,
  minor_crashes bigint,
  no_injury_crashes bigint,
  total_fatalities bigint,
  severity_score bigint,
  incident_count_3y bigint,
  morth_criterion boolean,
  irc_order text,
  cluster_label text,
  status text,
  road_type text,
  district text,
  first_report_at timestamptz,
  last_report_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
WITH RECURSIVE source AS (
  SELECT r.id, r.lat, r.lng, r.created_at, r.incident_date, r.incident_known,
         r.severity, r.fatalities, r.road_type, r.district, r.review_status
  FROM public.road_reports r
  WHERE r.lat IS NOT NULL AND r.lng IS NOT NULL
), pairs AS (
  SELECT a.id AS left_id, b.id AS right_id
  FROM source a
  JOIN source b ON a.id < b.id
    AND b.lat BETWEEN a.lat - 0.005 AND a.lat + 0.005
    AND b.lng BETWEEN a.lng - 0.006 AND a.lng + 0.006
  WHERE 6371008.8 * 2 * pg_catalog.asin(pg_catalog.sqrt(
    pg_catalog.sin(pg_catalog.radians(b.lat - a.lat) / 2) ^ 2
    + pg_catalog.cos(pg_catalog.radians(a.lat)) * pg_catalog.cos(pg_catalog.radians(b.lat))
    * pg_catalog.sin(pg_catalog.radians(b.lng - a.lng) / 2) ^ 2
  )) <= 500
), edges AS (
  SELECT left_id AS from_id, right_id AS to_id FROM pairs
  UNION ALL
  SELECT right_id AS from_id, left_id AS to_id FROM pairs
), reachability(root_id, node_id) AS (
  SELECT s.id, s.id FROM source s
  UNION
  SELECT r.root_id, e.to_id
  FROM reachability r
  JOIN edges e ON e.from_id = r.node_id
), component_map AS (
  SELECT node_id, min(root_id::text)::uuid AS anchor_id
  FROM reachability GROUP BY node_id
), grouped AS (
  SELECT cm.anchor_id, s.*
  FROM source s JOIN component_map cm ON cm.node_id = s.id
), clusters AS (
  SELECT g.anchor_id,
         avg(g.lat) AS center_lat,
         avg(g.lng) AS center_lng,
         count(*) AS report_count,
         count(*) FILTER (WHERE g.incident_known IS TRUE AND g.severity = 'Fatal'
           AND g.incident_date >= (date_trunc('year', current_date)::date - interval '2 years')::date) AS fatal_crashes,
         count(*) FILTER (WHERE g.incident_known IS TRUE AND g.severity = 'Grievous'
           AND g.incident_date >= (date_trunc('year', current_date)::date - interval '2 years')::date) AS grievous_crashes,
         count(*) FILTER (WHERE g.incident_known IS TRUE AND g.severity = 'Minor'
           AND g.incident_date >= (date_trunc('year', current_date)::date - interval '2 years')::date) AS minor_crashes,
         count(*) FILTER (WHERE g.incident_known IS TRUE AND g.severity = 'No injury'
           AND g.incident_date >= (date_trunc('year', current_date)::date - interval '2 years')::date) AS no_injury_crashes,
         coalesce(sum(g.fatalities) FILTER (WHERE g.incident_known IS TRUE
           AND g.incident_date >= (date_trunc('year', current_date)::date - interval '2 years')::date), 0) AS total_fatalities,
         count(*) FILTER (WHERE g.incident_known IS TRUE
           AND g.incident_date >= (date_trunc('year', current_date)::date - interval '2 years')::date) AS incident_count_3y,
         mode() WITHIN GROUP (ORDER BY g.road_type) FILTER (WHERE g.road_type IS NOT NULL) AS road_type,
         mode() WITHIN GROUP (ORDER BY g.district) FILTER (WHERE g.district IS NOT NULL) AS district,
         min(g.created_at) AS first_report_at,
         max(g.created_at) AS last_report_at,
         mode() WITHIN GROUP (ORDER BY g.review_status) FILTER (WHERE g.review_status IS NOT NULL) AS review_status
  FROM grouped g GROUP BY g.anchor_id
), scored AS (
  SELECT c.*,
         (c.fatal_crashes * 10 + c.grievous_crashes * 5 + c.minor_crashes * 2 + c.no_injury_crashes) AS severity_score,
         (coalesce(c.road_type, 'Other') = 'National Highway'
          AND (c.fatal_crashes + c.grievous_crashes >= 5 OR c.total_fatalities >= 10)) AS morth_criterion,
         c.incident_count_3y::numeric / 3 AS annualized_incidents
  FROM clusters c
), classified AS (
  SELECT s.*,
         t.reaction_order AS irc_order,
         b.id AS stored_black_spot_id,
         b.spot_code AS stored_spot_code,
         b.status AS stored_status
  FROM scored s
  LEFT JOIN LATERAL (
    SELECT threshold.reaction_order
    FROM public.road_safety_thresholds threshold
    WHERE threshold.road_type = s.road_type
      AND threshold.annual_crashes_per_500m <= s.annualized_incidents
    ORDER BY threshold.multiplier DESC LIMIT 1
  ) t ON true
  LEFT JOIN public.road_black_spots b ON b.anchor_report_id = s.anchor_id
), ranked AS (
  SELECT c.*,
         row_number() OVER (ORDER BY c.first_report_at, c.anchor_id) AS code_rank
  FROM classified c
)
SELECT coalesce(r.stored_spot_code, 'KL-' || lpad(r.code_rank::text, 3, '0')),
       r.anchor_id, r.center_lat, r.center_lng, r.report_count,
       r.fatal_crashes, r.grievous_crashes, r.minor_crashes, r.no_injury_crashes,
       r.total_fatalities, r.severity_score, r.incident_count_3y, r.morth_criterion,
       r.irc_order,
       CASE
         WHEN r.stored_status IN ('Verified Black Spot', 'Under Rectification', 'Partially Rectified', 'Monitoring') THEN 'Verified black spot'
         WHEN r.stored_status = 'Rectified' THEN 'Rectified'
         WHEN r.stored_status = 'Rejected' THEN 'Reported'
         WHEN r.morth_criterion OR r.irc_order IS NOT NULL THEN 'Potential black spot'
         WHEN r.report_count >= 2 THEN 'Community-flagged cluster'
         ELSE 'Reported'
       END,
       coalesce(r.stored_status, r.review_status, 'Reported'),
       coalesce(r.road_type, 'Other'), r.district, r.first_report_at, r.last_report_at
FROM ranked r;
$function$;
REVOKE ALL ON FUNCTION public.get_road_safety_clusters() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_road_safety_clusters() TO anon, authenticated;

COMMIT;
