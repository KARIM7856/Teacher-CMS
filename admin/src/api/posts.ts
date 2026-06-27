import { supabase } from '../lib/supabase'
import type { Post } from '../types/database'

export interface PostFilters {
  search?: string
  categoryId?: string | null
  tagId?: string | null
}

export async function listPosts(filters: PostFilters = {}): Promise<Post[]> {
  // Resolve category -> its subcategory ids, and tag -> its post ids, then
  // apply both as simple IN filters (avoids brittle embedded-resource filters).
  let subcategoryIds: string[] | null = null
  if (filters.categoryId) {
    const { data } = await supabase
      .from('subcategories')
      .select('id')
      .eq('category_id', filters.categoryId)
    subcategoryIds = (data ?? []).map((r: any) => r.id)
    if (subcategoryIds.length === 0) return []
  }

  let postIds: string[] | null = null
  if (filters.tagId) {
    const { data } = await supabase.from('post_tags').select('post_id').eq('tag_id', filters.tagId)
    postIds = (data ?? []).map((r: any) => r.post_id)
    if (postIds.length === 0) return []
  }

  let query = supabase.from('posts').select('*').order('updated_at', { ascending: false })
  if (filters.search) query = query.ilike('title', `%${filters.search}%`)
  if (subcategoryIds) query = query.in('subcategory_id', subcategoryIds)
  if (postIds) query = query.in('id', postIds)

  const { data, error } = await query
  if (error) throw error
  return (data ?? []) as Post[]
}

export async function getPost(id: string): Promise<Post | null> {
  const { data, error } = await supabase.from('posts').select('*').eq('id', id).single()
  if (error) throw error
  return (data as Post) ?? null
}

export async function createPost(input: {
  title: string
  body: string | null
  subcategory_id: string
  published: boolean
  author_id: string | null
}): Promise<string> {
  const { data, error } = await supabase.from('posts').insert(input).select('id').single()
  if (error) throw error
  return (data as { id: string }).id
}

export async function updatePost(
  id: string,
  patch: Partial<Pick<Post, 'title' | 'body' | 'subcategory_id' | 'published'>>,
): Promise<void> {
  const { error } = await supabase.from('posts').update(patch).eq('id', id)
  if (error) throw error
}

export async function deletePost(id: string): Promise<void> {
  const { error } = await supabase.from('posts').delete().eq('id', id)
  if (error) throw error
}

export async function getPostTagIds(postId: string): Promise<string[]> {
  const { data, error } = await supabase.from('post_tags').select('tag_id').eq('post_id', postId)
  if (error) throw error
  return (data ?? []).map((r: any) => r.tag_id)
}

export async function setPostTags(postId: string, tagIds: string[]): Promise<void> {
  const { error: delError } = await supabase.from('post_tags').delete().eq('post_id', postId)
  if (delError) throw delError
  if (tagIds.length === 0) return
  const { error } = await supabase
    .from('post_tags')
    .insert(tagIds.map((tag_id) => ({ post_id: postId, tag_id })))
  if (error) throw error
}
