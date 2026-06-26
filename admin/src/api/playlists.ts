import { supabase } from '../lib/supabase'
import type { Playlist, PlaylistItem, Post } from '../types/database'

export interface PlaylistWithCount extends Playlist {
  itemCount: number
}

export interface PlaylistItemWithPost extends PlaylistItem {
  post: Pick<Post, 'id' | 'title' | 'published'> | null
}

export async function listPlaylists(): Promise<PlaylistWithCount[]> {
  const { data, error } = await supabase
    .from('playlists')
    .select('*, playlist_items(count)')
    .order('updated_at', { ascending: false })
  if (error) throw error
  return (data ?? []).map((row: any) => ({
    ...row,
    itemCount: row.playlist_items?.[0]?.count ?? 0,
  })) as PlaylistWithCount[]
}

export async function getPlaylist(id: string): Promise<Playlist | null> {
  const { data, error } = await supabase.from('playlists').select('*').eq('id', id).single()
  if (error) throw error
  return (data as Playlist) ?? null
}

export async function createPlaylist(input: {
  title: string
  description: string | null
  cover_image: string | null
  published: boolean
}): Promise<string> {
  const { data, error } = await supabase.from('playlists').insert(input).select('id').single()
  if (error) throw error
  return (data as { id: string }).id
}

export async function updatePlaylist(
  id: string,
  patch: Partial<Pick<Playlist, 'title' | 'description' | 'cover_image' | 'published'>>,
): Promise<void> {
  const { error } = await supabase.from('playlists').update(patch).eq('id', id)
  if (error) throw error
}

export async function deletePlaylist(id: string): Promise<void> {
  const { error } = await supabase.from('playlists').delete().eq('id', id)
  if (error) throw error
}

export async function listPlaylistItems(playlistId: string): Promise<PlaylistItemWithPost[]> {
  const { data, error } = await supabase
    .from('playlist_items')
    .select('*, posts(id, title, published)')
    .eq('playlist_id', playlistId)
    .order('position')
  if (error) throw error
  return (data ?? []).map((row: any) => ({
    id: row.id,
    playlist_id: row.playlist_id,
    post_id: row.post_id,
    position: row.position,
    post: row.posts ?? null,
  }))
}

export async function addPlaylistItem(
  playlistId: string,
  postId: string,
  position: number,
): Promise<void> {
  const { error } = await supabase
    .from('playlist_items')
    .insert({ playlist_id: playlistId, post_id: postId, position })
  if (error) throw error
}

export async function removePlaylistItem(id: string): Promise<void> {
  const { error } = await supabase.from('playlist_items').delete().eq('id', id)
  if (error) throw error
}

// (playlist_id, position) is UNIQUE, so reorder in two phases through a high
// temporary offset to avoid transient collisions across separate REST calls.
export async function reorderPlaylistItems(ids: string[]): Promise<void> {
  await Promise.all(
    ids.map((id, index) =>
      supabase.from('playlist_items').update({ position: 10000 + index }).eq('id', id),
    ),
  )
  await Promise.all(
    ids.map((id, index) =>
      supabase.from('playlist_items').update({ position: index }).eq('id', id),
    ),
  )
}
