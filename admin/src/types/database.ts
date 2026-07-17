// Row shapes for the Supabase schema in /supabase. Hand-written (a focused
// subset) rather than CLI-generated to keep the scaffold dependency-light.

export type UserRole = 'student' | 'admin'
export type MediaType = 'video' | 'pdf' | 'other'

export interface Profile {
  id: string
  role: UserRole
  display_name: string | null
  avatar_url: string | null
}

// A student account as returned by the /api/students serverless function
// (a merge of auth.users + the profiles row). Managed only via that endpoint.
export interface StudentAccount {
  id: string
  username: string
  display_name: string | null
  // Roster fields from a bulk Excel import (nullable for manually-created ones).
  serial_number: string | null
  request_code: string | null
  created_at: string
  last_sign_in_at: string | null
  disabled: boolean
  groups: GroupRef[]
}

// A group the student belongs to (id + name), as returned inline by `list`.
export interface GroupRef {
  id: string
  name: string
}

// A content-access group. Students in a group see the categories/subcategories
// granted to it (see group_categories / group_subcategories).
export interface Group {
  id: string
  name: string
  description: string | null
  sort_order: number
  created_at: string
  updated_at: string
}

// The taxonomy a group is allowed to see: whole categories plus individual
// subcategories.
export interface GroupGrants {
  categoryIds: string[]
  subcategoryIds: string[]
}

export interface Category {
  id: string
  name: string
  slug: string
  icon: string | null
  sort_order: number
  created_at: string
  updated_at: string
}

export interface Subcategory {
  id: string
  category_id: string
  name: string
  slug: string
  sort_order: number
  created_at: string
  updated_at: string
}

export interface Tag {
  id: string
  name: string
  slug: string
}

export interface Post {
  id: string
  title: string
  body: string | null
  subcategory_id: string
  author_id: string | null
  published: boolean
  created_at: string
  updated_at: string
}

export interface Media {
  id: string
  post_id: string
  type: MediaType
  storage_path: string | null
  external_url: string | null
  display_name: string | null
  sort_order: number
}

export interface Playlist {
  id: string
  title: string
  description: string | null
  cover_image: string | null
  published: boolean
  created_at: string
  updated_at: string
}

export interface PlaylistItem {
  id: string
  playlist_id: string
  post_id: string
  position: number
}

export const MEDIA_BUCKET = 'media'
