import { supabase } from '../lib/supabase'
import { MEDIA_BUCKET } from '../types/database'
import type { Media, MediaType } from '../types/database'

function safeFileName(name: string): string {
  // Storage paths stay ASCII-safe; the original name is kept in display_name.
  return name.replace(/[^\w.\-]+/g, '_')
}

export function guessMediaType(file: File): MediaType {
  if (file.type.startsWith('video/')) return 'video'
  if (file.type === 'application/pdf') return 'pdf'
  return 'other'
}

export async function listMedia(postId: string): Promise<Media[]> {
  const { data, error } = await supabase
    .from('media')
    .select('*')
    .eq('post_id', postId)
    .order('sort_order')
  if (error) throw error
  return (data ?? []) as Media[]
}

export async function uploadMedia(postId: string, file: File, type: MediaType): Promise<Media> {
  const path = `${postId}/${Date.now()}-${safeFileName(file.name)}`
  const { error: upError } = await supabase.storage.from(MEDIA_BUCKET).upload(path, file)
  if (upError) throw upError

  const existing = await listMedia(postId)
  const { data, error } = await supabase
    .from('media')
    .insert({
      post_id: postId,
      type,
      storage_path: path,
      display_name: file.name,
      sort_order: existing.length,
    })
    .select('*')
    .single()
  if (error) throw error
  return data as Media
}

export async function updateMedia(
  id: string,
  patch: Partial<Pick<Media, 'type' | 'display_name'>>,
): Promise<void> {
  const { error } = await supabase.from('media').update(patch).eq('id', id)
  if (error) throw error
}

export async function deleteMedia(item: Media): Promise<void> {
  if (item.storage_path) {
    await supabase.storage.from(MEDIA_BUCKET).remove([item.storage_path])
  }
  const { error } = await supabase.from('media').delete().eq('id', item.id)
  if (error) throw error
}

export async function reorderMedia(ids: string[]): Promise<void> {
  await Promise.all(
    ids.map((id, index) => supabase.from('media').update({ sort_order: index }).eq('id', id)),
  )
}

export async function getMediaSignedUrl(path: string): Promise<string | null> {
  const { data } = await supabase.storage.from(MEDIA_BUCKET).createSignedUrl(path, 3600)
  return data?.signedUrl ?? null
}
