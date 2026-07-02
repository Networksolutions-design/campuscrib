-- =============================================================
-- CampusCrib — Migration 003
-- Improves the rooms schema after Migration 002
-- =============================================================

-- =============================================================
-- 1. Add landlord_id
-- Every room belongs to a landlord
-- =============================================================

ALTER TABLE public.rooms
ADD COLUMN landlord_id UUID
REFERENCES public.profiles(id)
ON DELETE RESTRICT;

-- Uncomment this AFTER every existing room has a landlord assigned.
-- ALTER TABLE public.rooms
-- ALTER COLUMN landlord_id SET NOT NULL;

---------------------------------------------------------------

-- =============================================================
-- 2. Add verification_status
-- Used by CampusCrib admins
-- =============================================================

ALTER TABLE public.rooms
ADD COLUMN verification_status TEXT
NOT NULL
DEFAULT 'pending'
CHECK (
    verification_status IN (
        'pending',
        'verified',
        'rejected'
    )
);

---------------------------------------------------------------

-- =============================================================
-- 3. Transport cost estimates
-- =============================================================

ALTER TABLE public.rooms
ADD COLUMN transport_cost_boda INTEGER
CHECK (transport_cost_boda >= 0);

ALTER TABLE public.rooms
ADD COLUMN transport_cost_bus INTEGER
CHECK (transport_cost_bus >= 0);

ALTER TABLE public.rooms
ADD COLUMN transport_cost_car INTEGER
CHECK (transport_cost_car >= 0);

---------------------------------------------------------------

-- =============================================================
-- 4. Available From
-- =============================================================

ALTER TABLE public.rooms
ADD COLUMN available_from DATE;

---------------------------------------------------------------

-- =============================================================
-- 5. View Counter
-- =============================================================

ALTER TABLE public.rooms
ADD COLUMN view_count INTEGER
NOT NULL
DEFAULT 0
CHECK (view_count >= 0);

---------------------------------------------------------------

-- =============================================================
-- 6. Only ONE cover photo per room
-- =============================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_room_cover
ON public.room_photos(room_id)
WHERE is_cover = TRUE;

---------------------------------------------------------------

-- =============================================================
-- 7. Performance Indexes
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_rooms_landlord
ON public.rooms(landlord_id);

CREATE INDEX IF NOT EXISTS idx_rooms_verification
ON public.rooms(verification_status);

CREATE INDEX IF NOT EXISTS idx_rooms_available_from
ON public.rooms(available_from);

-- =============================================================
-- End of Migration 003
-- =============================================================