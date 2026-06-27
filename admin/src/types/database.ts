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
