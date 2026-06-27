import { Navigate, Route, Routes } from 'react-router-dom'
import { AppLayout } from './components/AppLayout'
import { RequireAdmin } from './components/RequireAdmin'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { CategoriesPage } from './pages/CategoriesPage'
import { TagsPage } from './pages/TagsPage'
import { PostsListPage } from './pages/PostsListPage'
import { PostEditPage } from './pages/PostEditPage'
import { PlaylistsListPage } from './pages/PlaylistsListPage'
import { PlaylistEditPage } from './pages/PlaylistEditPage'

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <RequireAdmin>
            <AppLayout />
          </RequireAdmin>
        }
      >
        <Route path="/" element={<DashboardPage />} />
        <Route path="/categories" element={<CategoriesPage />} />
        <Route path="/tags" element={<TagsPage />} />
        <Route path="/posts" element={<PostsListPage />} />
        <Route path="/posts/new" element={<PostEditPage />} />
        <Route path="/posts/:id/edit" element={<PostEditPage />} />
        <Route path="/playlists" element={<PlaylistsListPage />} />
        <Route path="/playlists/new" element={<PlaylistEditPage />} />
        <Route path="/playlists/:id/edit" element={<PlaylistEditPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}
