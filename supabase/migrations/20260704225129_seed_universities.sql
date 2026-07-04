-- =============================================================
-- CampusCrib — Migration 004
-- Seed Data: Tanzanian Universities
-- Phase 1 — Step 4.4
-- =============================================================
-- Inserts 8 verified Tanzanian universities.
-- GPS coordinates are the main gate of each campus.
-- ON CONFLICT DO NOTHING makes this safe to run multiple times.
-- =============================================================
 
INSERT INTO public.universities
  (name, short_name, city, latitude, longitude, is_active)
VALUES
 
  -- 1. University of Dar es Salaam
  --    Main gate on UDSM Road, Mlimani
  (
    'University of Dar es Salaam',
    'UDSM',
    'Dar es Salaam',
    -6.77430000,
    39.21250000,
    TRUE
  ),
 
  -- 2. Ardhi University
  --    Main gate on Observation Hill, Mlimani area
  (
    'Ardhi University',
    'ARU',
    'Dar es Salaam',
    -6.77350000,
    39.21750000,
    TRUE
  ),
 
  -- 3. Institute of Finance Management
  --    Main gate on Shaaban Robert Street, Upanga
  (
    'Institute of Finance Management',
    'IFM',
    'Dar es Salaam',
    -6.80000000,
    39.27330000,
    TRUE
  ),
 
  -- 4. Dar es Salaam University College of Education
  --    Main gate, Chang'ombe
  (
    'Dar es Salaam University College of Education',
    'DUCE',
    'Dar es Salaam',
    -6.85580000,
    39.25300000,
    TRUE
  ),
 
  -- 5. Muhimbili University of Health and Allied Sciences
  --    Main gate on United Nations Road, Upanga
  (
    'Muhimbili University of Health and Allied Sciences',
    'MUHAS',
    'Dar es Salaam',
    -6.80080000,
    39.20930000,
    TRUE
  ),
 
  -- 6. College of Business Education
  --    Main gate on Bibi Titi Mohamed Road
  (
    'College of Business Education',
    'CBE',
    'Dar es Salaam',
    -6.81480000,
    39.28050000,
    TRUE
  ),
 
  -- 7. Sokoine University of Agriculture
  --    Main gate, Chuo Kikuu, Morogoro
  (
    'Sokoine University of Agriculture',
    'SUA',
    'Morogoro',
    -6.84570000,
    37.66220000,
    TRUE
  ),
 
  -- 8. Mzumbe University — Dar es Salaam Campus
  --    Mzumbe DSM campus gate, Mlimani area
  (
    'Mzumbe University',
    'MU-DSM',
    'Dar es Salaam',
    -6.77680000,
    39.21470000,
    TRUE
  )
 
ON CONFLICT (name) DO NOTHING;
 
 
-- Verify the inserts ran correctly.
-- This SELECT is a comment-style check: run it manually in the
-- SQL Editor after db push to confirm 8 rows exist.
--
-- SELECT id, name, short_name, city, latitude, longitude
-- FROM public.universities
-- ORDER BY city, name;
