import { supabase } from '../lib/supabase'
import type { Tag } from '../types/database'

export async function listTags(): Promise<Tag[]> {
  const { data, error } = await supabase.from('tags').select('id, name, slug').order('name')
  if (error) throw error
  return (data ?? []) as Tag[]
}

export async function createTag(input: { name: string; slug: string }): Promise<void> {
  const { error } = await supabase.from('tags').insert(input)
  if (error) throw error
}

export async function updateTag(id: string, patch: { name: string; slug: string }): Promise<void> {
  const { error } = await supabase.from('tags').update(patch).eq('id', id)
  if (error) throw error
}

export async function deleteTag(id: string): Promise<void> {
  const { error } = await supabase.from('tags').delete().eq('id', id)
  if (error) throw error
}
