import { supabase } from '../lib/supabase'
import type { Category, Subcategory } from '../types/database'

export async function listCategories(): Promise<Category[]> {
  const { data, error } = await supabase.from('categories').select('*').order('sort_order')
  if (error) throw error
  return (data ?? []) as Category[]
}

export async function createCategory(input: {
  name: string
  slug: string
  icon: string | null
  sort_order: number
}): Promise<void> {
  const { error } = await supabase.from('categories').insert(input)
  if (error) throw error
}

export async function updateCategory(
  id: string,
  patch: Partial<Pick<Category, 'name' | 'slug' | 'icon' | 'sort_order'>>,
): Promise<void> {
  const { error } = await supabase.from('categories').update(patch).eq('id', id)
  if (error) throw error
}

export async function deleteCategory(id: string): Promise<void> {
  const { error } = await supabase.from('categories').delete().eq('id', id)
  if (error) throw error
}

// sort_order is not unique, so a parallel "set to new index" is safe.
export async function reorderCategories(ids: string[]): Promise<void> {
  await Promise.all(
    ids.map((id, index) => supabase.from('categories').update({ sort_order: index }).eq('id', id)),
  )
}

export async function listAllSubcategories(): Promise<Subcategory[]> {
  const { data, error } = await supabase
    .from('subcategories')
    .select('*')
    .order('category_id')
    .order('sort_order')
  if (error) throw error
  return (data ?? []) as Subcategory[]
}

export async function listSubcategories(categoryId: string): Promise<Subcategory[]> {
  const { data, error } = await supabase
    .from('subcategories')
    .select('*')
    .eq('category_id', categoryId)
    .order('sort_order')
  if (error) throw error
  return (data ?? []) as Subcategory[]
}

export async function createSubcategory(input: {
  category_id: string
  name: string
  slug: string
  sort_order: number
}): Promise<void> {
  const { error } = await supabase.from('subcategories').insert(input)
  if (error) throw error
}

export async function updateSubcategory(
  id: string,
  patch: Partial<Pick<Subcategory, 'name' | 'slug' | 'sort_order'>>,
): Promise<void> {
  const { error } = await supabase.from('subcategories').update(patch).eq('id', id)
  if (error) throw error
}

export async function deleteSubcategory(id: string): Promise<void> {
  const { error } = await supabase.from('subcategories').delete().eq('id', id)
  if (error) throw error
}

export async function reorderSubcategories(ids: string[]): Promise<void> {
  await Promise.all(
    ids.map((id, index) =>
      supabase.from('subcategories').update({ sort_order: index }).eq('id', id),
    ),
  )
}
