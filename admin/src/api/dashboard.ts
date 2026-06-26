import { supabase } from '../lib/supabase'

export interface DashboardCounts {
  posts: number
  playlists: number
  categories: number
}

export async function getDashboardCounts(): Promise<DashboardCounts> {
  const [posts, playlists, categories] = await Promise.all([
    supabase.from('posts').select('*', { count: 'exact', head: true }),
    supabase.from('playlists').select('*', { count: 'exact', head: true }),
    supabase.from('categories').select('*', { count: 'exact', head: true }),
  ])
  return {
    posts: posts.count ?? 0,
    playlists: playlists.count ?? 0,
    categories: categories.count ?? 0,
  }
}
