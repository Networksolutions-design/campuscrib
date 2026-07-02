-- =============================================================
-- CampusCrib — Migration 002
-- Creates: rooms, room_photos, wishlists
-- Part of Phase 1 — Step 4.2
-- Depends on: universities, profiles (created in Migration 001)
-- =============================================================

-- ═════════════════════════════════════════════
-- TABLE: rooms
-- The core listing table. Every room a landlord
-- lists and every student browses lives here.
-- ═════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.rooms (
  -- Primary key: auto-generated UUID
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- Listing content
  title TEXT NOT NULL,
  description TEXT NOT NULL,

  -- Room category
  room_type TEXT NOT NULL
    CONSTRAINT rooms_room_type_check
    CHECK (room_type IN ('self_contained', 'shared', 'bedsitter', 'studio')),

  -- Money: stored in TZS as a whole-number integer (no decimals in TZS pricing)
  monthly_rent INTEGER NOT NULL
    CONSTRAINT rooms_monthly_rent_positive CHECK (monthly_rent > 0),

  -- How many months of rent must be paid up front
  advance_months_required INTEGER NOT NULL
    CONSTRAINT rooms_advance_months_check
    CHECK (advance_months_required IN (1, 4, 6)),

  -- GPS location of the room itself (same precision as universities.latitude/longitude)
  latitude DECIMAL(10, 8) NOT NULL
    CONSTRAINT rooms_lat_range CHECK (latitude BETWEEN -11.75 AND -0.99),
  longitude DECIMAL(11, 8) NOT NULL
    CONSTRAINT rooms_lng_range CHECK (longitude BETWEEN 29.34 AND 40.45),

  address TEXT NOT NULL,

  -- The closest university campus. Required — every room must be
  -- located relative to a supported campus. RESTRICT: a university
  -- with rooms attached cannot be deleted.
  nearest_university_id UUID NOT NULL
    REFERENCES public.universities(id) ON DELETE RESTRICT,

  -- Pre-calculated distance in meters from nearest_university_id's GPS point.
  -- Calculated by application code at write-time, not by the database.
  distance_meters INTEGER NOT NULL
    CONSTRAINT rooms_distance_nonnegative CHECK (distance_meters >= 0),

  gender_policy TEXT NOT NULL
    CONSTRAINT rooms_gender_policy_check
    CHECK (gender_policy IN ('any', 'female_only', 'male_only')),

  status TEXT NOT NULL DEFAULT 'available'
    CONSTRAINT rooms_status_check
    CHECK (status IN ('available', 'reserved', 'occupied', 'archived')),

  -- Flexible list of amenity tags, e.g. ["wifi","water","electricity"]
  amenities JSONB NOT NULL DEFAULT '[]'::jsonb,

  landlord_requirements TEXT,
  rules TEXT,

  is_featured BOOLEAN NOT NULL DEFAULT FALSE,

  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.rooms IS 'Core room listings. Every student-facing listing lives here.';
COMMENT ON COLUMN public.rooms.amenities IS 'JSON array of amenity tags, e.g. ["wifi","water","electricity"].';
COMMENT ON COLUMN public.rooms.distance_meters IS 'Pre-calculated distance in meters to nearest_university_id GPS point.';

-- Auto-update updated_at whenever a room row is edited
-- (re-uses the handle_updated_at() function created in Migration 001)
CREATE TRIGGER rooms_updated_at
  BEFORE UPDATE ON public.rooms
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

-- ═════════════════════════════════════════════
-- TABLE: room_photos
-- One row per photo. A room has many photos —
-- classic one-to-many relationship.
-- ═════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.room_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- CASCADE: deleting a room deletes its photo rows too —
  -- no orphaned photo records left behind.
  room_id UUID NOT NULL
    REFERENCES public.rooms(id) ON DELETE CASCADE,

  -- Path inside the Supabase Storage bucket (set up in a later step)
  storage_path TEXT NOT NULL,

  -- Full public URL, ready to use directly in an <img> tag
  url TEXT NOT NULL,

  category TEXT NOT NULL
    CONSTRAINT room_photos_category_check
    CHECK (category IN ('exterior', 'interior', 'bathroom', 'toilet', 'compound')),

  -- Display order on the room detail page gallery. 0 = shown first.
  sort_order INTEGER NOT NULL DEFAULT 0,

  -- The single photo used as the room's cover/thumbnail
  is_cover BOOLEAN NOT NULL DEFAULT FALSE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.room_photos IS 'One row per uploaded room photo. Many rows per room.';

-- ═════════════════════════════════════════════
-- TABLE: wishlists
-- Join table implementing the many-to-many
-- relationship between profiles and rooms.
-- ═════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.wishlists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

  -- CASCADE: deleting a user deletes their saved-rooms list too
  student_id UUID NOT NULL
    REFERENCES public.profiles(id) ON DELETE CASCADE,

  -- CASCADE: deleting a room removes it from everyone's wishlist
  room_id UUID NOT NULL
    REFERENCES public.rooms(id) ON DELETE CASCADE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  -- A student cannot save the exact same room twice.
  -- This is a COMPOSITE unique constraint: the pair must be
  -- unique, even though neither column alone is.
  CONSTRAINT wishlists_student_room_unique UNIQUE (student_id, room_id)
);

COMMENT ON TABLE public.wishlists IS 'Join table: which students saved which rooms. One row per (student, room) pair.';

-- ═════════════════════════════════════════════
-- INDEXES
-- Created here, used in every rooms/dashboard/wishlist query.
-- See CampusCrib Technical Architecture Part 3.
-- ═════════════════════════════════════════════

-- Speeds up the /rooms page: "show all rooms where status != archived"
CREATE INDEX IF NOT EXISTS idx_rooms_status
  ON public.rooms (status);

-- Speeds up "show rooms near this student's university"
CREATE INDEX IF NOT EXISTS idx_rooms_nearest_university
  ON public.rooms (nearest_university_id);

-- Speeds up the homepage featured-rooms section
CREATE INDEX IF NOT EXISTS idx_rooms_is_featured
  ON public.rooms (is_featured);

-- Speeds up fetching all photos for one room, in gallery order
CREATE INDEX IF NOT EXISTS idx_room_photos_room_id
  ON public.room_photos (room_id, sort_order);

-- Speeds up "show this student's saved rooms" on their dashboard
CREATE INDEX IF NOT EXISTS idx_wishlists_student_id
  ON public.wishlists (student_id);

-- Speeds up "how many students saved this room" (used for popularity sorting later)
CREATE INDEX IF NOT EXISTS idx_wishlists_room_id
  ON public.wishlists (room_id);
