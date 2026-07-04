-- =============================================================
-- CampusCrib --- Migration 004
-- Row Level Security: enable on all tables + all policies
-- Phase 1 --- Step 4.3 (CORRECTED VERSION)
-- =============================================================
-- After this migration runs:
-- • Students see only verified, available rooms
-- • Admins see everything
-- • Landlords can manage their own rooms (but cannot verify them)
-- • Users see only their own profiles and wishlists
-- • No unauthenticated caller can write to any table
-- =============================================================

-- ─────────────────────────────────────────────
-- HELPER FUNCTION 1: Admin Check
-- Reusable admin check used by every admin policy.
-- Returns TRUE when the calling user's role = 'admin'.
-- ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
);
$$;

COMMENT ON FUNCTION public.is_admin() IS
'Returns TRUE if the calling auth.uid() has role=admin in profiles.';

-- ─────────────────────────────────────────────
-- HELPER FUNCTION 2: Landlord Check
-- Returns TRUE if the calling user is a landlord.
-- Used to allow landlords to create rooms.
-- ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.is_landlord()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
SELECT EXISTS (
    SELECT 1
    FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'landlord'
);
$$;

COMMENT ON FUNCTION public.is_landlord() IS
'Returns TRUE if the calling auth.uid() has role=landlord in profiles.';

-- =============================================================
-- TABLE: universities
-- =============================================================

ALTER TABLE public.universities ENABLE ROW LEVEL SECURITY;

-- Anyone can read universities (used in room cards, register form, etc.)
CREATE POLICY "universities: anyone can read"
ON public.universities
FOR SELECT
USING (true);

-- Only admins can add a new university
CREATE POLICY "universities: admin can insert"
ON public.universities
FOR INSERT
WITH CHECK (public.is_admin());

-- Only admins can edit a university
CREATE POLICY "universities: admin can update"
ON public.universities
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Only admins can delete a university
CREATE POLICY "universities: admin can delete"
ON public.universities
FOR DELETE
USING (public.is_admin());

-- =============================================================
-- TABLE: profiles
-- =============================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- A user can read their own profile only.
CREATE POLICY "profiles: user reads own row"
ON public.profiles
FOR SELECT
USING (id = auth.uid());

-- Admin can read any profile (needed for /admin/users page)
CREATE POLICY "profiles: admin reads all"
ON public.profiles
FOR SELECT
USING (public.is_admin());

-- On registration the server action inserts a profile.
-- The id inserted must equal the caller's own auth.uid().
-- This prevents a user from creating a profile for someone else.
CREATE POLICY "profiles: user inserts own row"
ON public.profiles
FOR INSERT
WITH CHECK (id = auth.uid());

-- A user can update only their own profile.
CREATE POLICY "profiles: user updates own row"
ON public.profiles
FOR UPDATE
USING (id = auth.uid())
WITH CHECK (id = auth.uid());

-- Admin can update any profile (e.g. to change a role)
CREATE POLICY "profiles: admin updates any row"
ON public.profiles
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- =============================================================
-- TABLE: rooms
-- =============================================================

ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

-- ***** THE MOST IMPORTANT POLICY IN THE ENTIRE DATABASE *****
-- Students and guests can read rooms ONLY when:
-- • status = 'available' (not reserved, occupied, or archived)
-- • verification_status = 'verified' (admin has reviewed and approved)
-- This single policy is the trust engine of CampusCrib.
-- A room never appears to a student until both conditions are true.
CREATE POLICY "rooms: public can read verified available rooms"
ON public.rooms
FOR SELECT
USING (
    status = 'available'
    AND verification_status = 'verified'
);

-- Admin reads ALL rooms regardless of status or verification.
-- Needed so admin can see pending/rejected rooms to manage them.
CREATE POLICY "rooms: admin reads all"
ON public.rooms
FOR SELECT
USING (public.is_admin());

-- Landlord can read their OWN rooms (all statuses, including pending)
-- This allows landlords to see their own listings and their status.
CREATE POLICY "rooms: landlord reads own"
ON public.rooms
FOR SELECT
USING (landlord_id = auth.uid());

-- Only admin can create a room listing.
CREATE POLICY "rooms: admin can insert"
ON public.rooms
FOR INSERT
WITH CHECK (public.is_admin());

-- Landlord can create their own room listing.
-- The landlord_id must equal the caller's auth.uid().
CREATE POLICY "rooms: landlord can insert"
ON public.rooms
FOR INSERT
WITH CHECK (
    public.is_landlord()
    AND landlord_id = auth.uid()
);

-- Only admin can edit a room (change price, status, verification, etc.)
CREATE POLICY "rooms: admin can update"
ON public.rooms
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Landlord can edit their OWN rooms.
-- The verification_status restriction is handled by the trigger below.
CREATE POLICY "rooms: landlord can update own"
ON public.rooms
FOR UPDATE
USING (landlord_id = auth.uid())
WITH CHECK (landlord_id = auth.uid());

-- Only admin can delete a room.
-- In practice we archive (status = 'archived') rather than delete,
-- but the policy must exist for completeness.
CREATE POLICY "rooms: admin can delete"
ON public.rooms
FOR DELETE
USING (public.is_admin());

-- Landlord can delete their OWN rooms.
-- (This will cascade to photos and wishlists due to our CASCADE rules)
CREATE POLICY "rooms: landlord can delete own"
ON public.rooms
FOR DELETE
USING (landlord_id = auth.uid());

-- ─────────────────────────────────────────────
-- TRIGGER: Prevent landlords from changing verification_status
-- This trigger runs BEFORE UPDATE and blocks landlords from
-- changing the verification_status column.
-- ─────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.prevent_landlord_verification_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- If the user is not an admin and trying to change verification_status
    IF NOT public.is_admin() AND OLD.verification_status IS DISTINCT FROM NEW.verification_status THEN
        RAISE EXCEPTION 'Only admins can change verification_status. Your role: %', 
            (SELECT role FROM public.profiles WHERE id = auth.uid());
    END IF;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.prevent_landlord_verification_change() IS
'Blocks non-admin users from changing verification_status on rooms.';

-- Attach the trigger to the rooms table
DROP TRIGGER IF EXISTS prevent_landlord_verification_change ON public.rooms;
CREATE TRIGGER prevent_landlord_verification_change
BEFORE UPDATE ON public.rooms
FOR EACH ROW
EXECUTE FUNCTION public.prevent_landlord_verification_change();

-- =============================================================
-- TABLE: room_photos
-- =============================================================

ALTER TABLE public.room_photos ENABLE ROW LEVEL SECURITY;

-- Photos are publicly readable — guests need to see them on room cards.
CREATE POLICY "room_photos: anyone can read"
ON public.room_photos
FOR SELECT
USING (true);

-- Only admin can upload photos.
CREATE POLICY "room_photos: admin can insert"
ON public.room_photos
FOR INSERT
WITH CHECK (public.is_admin());

-- Landlord can upload photos for their own rooms.
CREATE POLICY "room_photos: landlord can insert"
ON public.room_photos
FOR INSERT
WITH CHECK (
    public.is_landlord()
    AND EXISTS (
        SELECT 1 FROM public.rooms
        WHERE rooms.id = room_id
        AND rooms.landlord_id = auth.uid()
    )
);

-- Only admin can update photo metadata (e.g. change sort_order).
CREATE POLICY "room_photos: admin can update"
ON public.room_photos
FOR UPDATE
USING (public.is_admin())
WITH CHECK (public.is_admin());

-- Only admin can delete a photo.
CREATE POLICY "room_photos: admin can delete"
ON public.room_photos
FOR DELETE
USING (public.is_admin());

-- Landlord can delete photos from their own rooms.
CREATE POLICY "room_photos: landlord can delete"
ON public.room_photos
FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM public.rooms
        WHERE rooms.id = room_id
        AND rooms.landlord_id = auth.uid()
    )
);

-- =============================================================
-- TABLE: wishlists
-- =============================================================

ALTER TABLE public.wishlists ENABLE ROW LEVEL SECURITY;

-- A student can only see their own wishlist.
CREATE POLICY "wishlists: user reads own entries"
ON public.wishlists
FOR SELECT
USING (student_id = auth.uid());

-- A student can only add rooms to their own wishlist.
-- The student_id inserted must equal auth.uid().
CREATE POLICY "wishlists: user inserts own entries"
ON public.wishlists
FOR INSERT
WITH CHECK (student_id = auth.uid());

-- A student can only remove entries from their own wishlist.
CREATE POLICY "wishlists: user deletes own entries"
ON public.wishlists
FOR DELETE
USING (student_id = auth.uid());

-- =============================================================
-- END OF MIGRATION 004
-- =============================================================