// =============================================================
// CampusCrib — Application Types
// Hand-written aliases derived from the generated database types.
// Import from here throughout the app, not from database.ts.
// =============================================================
 
import type { Database } from './database'
 
// ─────────────────────────────────────────────
// Database row types (what you receive from SELECT)
// ─────────────────────────────────────────────
export type University = Database['public']['Tables']['universities']['Row']
export type Profile    = Database['public']['Tables']['profiles']['Row']
export type Room       = Database['public']['Tables']['rooms']['Row']
export type RoomPhoto  = Database['public']['Tables']['room_photos']['Row']
export type Wishlist   = Database['public']['Tables']['wishlists']['Row']
 
// ─────────────────────────────────────────────
// Insert types (what you provide to INSERT)
// ─────────────────────────────────────────────
export type NewUniversity = Database['public']['Tables']['universities']['Insert']
export type NewProfile    = Database['public']['Tables']['profiles']['Insert']
export type NewRoom       = Database['public']['Tables']['rooms']['Insert']
export type NewRoomPhoto  = Database['public']['Tables']['room_photos']['Insert']
export type NewWishlist   = Database['public']['Tables']['wishlists']['Insert']
 
// ─────────────────────────────────────────────
// Update types (what you can change in UPDATE)
// ─────────────────────────────────────────────
export type UpdateRoom    = Database['public']['Tables']['rooms']['Update']
export type UpdateProfile = Database['public']['Tables']['profiles']['Update']
 
// ─────────────────────────────────────────────
// Enum helpers
// Derived from the CHECK constraints in the database.
// Use these instead of raw strings to prevent typos.
// ─────────────────────────────────────────────
export type RoomType          = 'self_contained' | 'shared' | 'bedsitter' | 'studio'
export type RoomStatus        = 'available' | 'reserved' | 'occupied' | 'archived'
export type VerificationStatus = 'pending' | 'verified' | 'rejected'
export type GenderPolicy      = 'any' | 'female_only' | 'male_only'
export type UserRole          = 'student' | 'admin' | 'support' | 'landlord'
export type Language          = 'en' | 'sw'
 
// ─────────────────────────────────────────────
// Composite types
// Used when a query joins multiple tables together.
// ─────────────────────────────────────────────
 
// A room with its cover photo and university attached —
// the shape returned by the rooms list query.
export type RoomWithDetails = Room & {
  universities: Pick<University, 'id' | 'name' | 'short_name'> | null
  room_photos:  Pick<RoomPhoto,  'url' | 'is_cover' | 'sort_order'>[]
}
 
// ─────────────────────────────────────────────
// API response wrapper
// All Server Actions and API routes return this shape.
// ─────────────────────────────────────────────
export type ActionResult<T = null> =
  | { success: true;  data?: T;    message?: string }
  | { success: false; error: string }
