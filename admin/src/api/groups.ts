// Group definitions and their content grants. These are plain admin-only tables
// (RLS: admins do everything), so — like categories/tags — the SPA talks to
// Supabase directly with the anon key + the admin's session. Student membership
// is the one thing that goes through the /api/students function (service_role);
// see api/students.ts.

import { supabase } from '../lib/supabase'
import type { Group, GroupGrants } from '../types/database'

export async function listGroups(): Promise<Group[]> {
  const { data, error } = await supabase
    .from('groups')
    .select('*')
    .order('sort_order')
    .order('name')
  if (error) throw error
  return (data ?? []) as Group[]
}

export async function createGroup(input: {
  name: string
  description: string | null
  sort_order: number
}): Promise<void> {
  const { error } = await supabase.from('groups').insert(input)
  if (error) throw error
}

export async function updateGroup(
  id: string,
  patch: Partial<Pick<Group, 'name' | 'description' | 'sort_order'>>,
): Promise<void> {
  const { error } = await supabase.from('groups').update(patch).eq('id', id)
  if (error) throw error
}

export async function deleteGroup(id: string): Promise<void> {
  // group_categories / group_subcategories / group_members cascade on delete.
  const { error } = await supabase.from('groups').delete().eq('id', id)
  if (error) throw error
}

// What this group is currently allowed to see.
export async function getGroupGrants(groupId: string): Promise<GroupGrants> {
  const [cats, subs] = await Promise.all([
    supabase.from('group_categories').select('category_id').eq('group_id', groupId),
    supabase.from('group_subcategories').select('subcategory_id').eq('group_id', groupId),
  ])
  if (cats.error) throw cats.error
  if (subs.error) throw subs.error
  return {
    categoryIds: (cats.data ?? []).map((r) => r.category_id as string),
    subcategoryIds: (subs.data ?? []).map((r) => r.subcategory_id as string),
  }
}

// Replace this group's grants with exactly [grants]. Done as delete-then-insert;
// the set is small and admin-only, so a brief non-atomic window is acceptable.
export async function setGroupGrants(groupId: string, grants: GroupGrants): Promise<void> {
  const delCats = await supabase.from('group_categories').delete().eq('group_id', groupId)
  if (delCats.error) throw delCats.error
  const delSubs = await supabase.from('group_subcategories').delete().eq('group_id', groupId)
  if (delSubs.error) throw delSubs.error

  if (grants.categoryIds.length > 0) {
    const insCats = await supabase
      .from('group_categories')
      .insert(grants.categoryIds.map((category_id) => ({ group_id: groupId, category_id })))
    if (insCats.error) throw insCats.error
  }
  if (grants.subcategoryIds.length > 0) {
    const insSubs = await supabase
      .from('group_subcategories')
      .insert(grants.subcategoryIds.map((subcategory_id) => ({ group_id: groupId, subcategory_id })))
    if (insSubs.error) throw insSubs.error
  }
}
