-- =============================================================
-- CampusCrib — Migration 001
-- Creates: universities, profiles
-- Part of Phase 1 — Step 4.1
-- =============================================================
 
-- ─────────────────────────────────────────────
-- HELPER: auto-update updated_at on every edit
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;
 
 
-- ═════════════════════════════════════════════
-- TABLE: universities
-- Reference data for all supported campuses.
-- GPS coordinates of the main gate are the
-- reference point for distance calculations.
-- ═════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.universities (
 
  -- Primary key: auto-generated UUID
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
 
  -- Full official name, e.g. 'Ardhi University'
  name          TEXT NOT NULL,
 
  -- Short code displayed on room cards, e.g. 'ARU'
  short_name    TEXT NOT NULL,
 
  -- City the campus is in, e.g. 'Dar es Salaam'
  city          TEXT NOT NULL,
 
  -- GPS coordinates of the campus main gate.
  -- Used as the reference point for distance_meters on rooms.
  -- DECIMAL(10,8) gives 8 decimal places of precision (~1cm accuracy).
  latitude      DECIMAL(10, 8) NOT NULL,
  longitude     DECIMAL(11, 8) NOT NULL,
 
  -- Soft-delete flag. FALSE hides from the university selector.
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
 
  -- Timestamps
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
 
  -- Constraints
  CONSTRAINT universities_name_unique       UNIQUE (name),
  CONSTRAINT universities_short_name_unique UNIQUE (short_name),
  CONSTRAINT universities_lat_range         CHECK (latitude  BETWEEN -11.75 AND -0.99),
  CONSTRAINT universities_lng_range         CHECK (longitude BETWEEN  29.34 AND 40.45)
  -- Latitude/longitude bounds cover all of Tanzania.
  -- A GPS entry outside these ranges is almost certainly a data entry error.
 
);
 
COMMENT ON TABLE  public.universities            IS 'Reference table for supported Tanzanian universities.';
COMMENT ON COLUMN public.universities.latitude   IS 'GPS latitude of campus main gate. Tanzania range: -11.75 to -0.99.';
COMMENT ON COLUMN public.universities.longitude  IS 'GPS longitude of campus main gate. Tanzania range: 29.34 to 40.45.';
 
 
-- ═════════════════════════════════════════════
-- TABLE: profiles
-- Extends Supabase Auth (auth.users).
-- One row per registered user.
-- The id column is set equal to auth.users.id
-- so auth.uid() can look it up with no join.
-- ═════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.profiles (
 
  -- Primary key: set equal to auth.users.id at registration.
  -- NOT auto-generated — the application inserts the auth.uid() value.
  id                   UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
 
  -- Contact information (mirrors auth.users for easy querying)
  email                TEXT,
 
  -- Personal details collected during /register
  first_name           TEXT NOT NULL,
  last_name            TEXT NOT NULL,
  date_of_birth        DATE NOT NULL,
 
  -- Gender: constrained to three allowed values
  gender               TEXT NOT NULL
                         CONSTRAINT profiles_gender_check
                         CHECK (gender IN ('male', 'female', 'prefer_not_to_say')),
 
  -- Role: determines what the user can access
  role                 TEXT NOT NULL DEFAULT 'student'
                         CONSTRAINT profiles_role_check
                         CHECK (role IN ('student', 'admin', 'support', 'landlord')),
 
  -- The university this student attends.
  -- SET NULL on delete: if a university row is removed,
  -- the profile stays intact (the student account survives).
  university_id        UUID
                         REFERENCES public.universities(id)
                         ON DELETE SET NULL,
 
  -- The year the student expects to start/started university, e.g. 2026
  expected_start_year  INTEGER
                         CONSTRAINT profiles_start_year_range
                         CHECK (expected_start_year BETWEEN 2000 AND 2100),
 
  -- Language preference: drives the i18n system
  preferred_language   TEXT NOT NULL DEFAULT 'en'
                         CONSTRAINT profiles_language_check
                         CHECK (preferred_language IN ('en', 'sw')),
 
  -- Account status flag
  is_active            BOOLEAN NOT NULL DEFAULT TRUE,
 
  -- Timestamps
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
 
);
 
COMMENT ON TABLE  public.profiles                    IS 'Extended user data. One row per auth.users row. id = auth.uid().';
COMMENT ON COLUMN public.profiles.role               IS 'student | admin | support | landlord';
COMMENT ON COLUMN public.profiles.preferred_language IS 'en = English, sw = Swahili';
 
-- Auto-update updated_at whenever a profile row is edited
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();
 
 
-- ═════════════════════════════════════════════
-- INDEXES
-- Created here, used in every room/dashboard query.
-- See CampusCrib Technical Architecture Part 3.
-- ═════════════════════════════════════════════
 
-- Speeds up filtering profiles by role (admin queries)
CREATE INDEX IF NOT EXISTS idx_profiles_role
  ON public.profiles (role);
 
-- Speeds up the dashboard: 'show rooms near this student's university'
CREATE INDEX IF NOT EXISTS idx_profiles_university
  ON public.profiles (university_id);
 
-- Speeds up listing universities by active status
CREATE INDEX IF NOT EXISTS idx_universities_active
  ON public.universities (is_active);
