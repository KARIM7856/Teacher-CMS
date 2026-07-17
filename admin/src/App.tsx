import { lazy, Suspense } from 'react'
import { Navigate, Route, Routes } from 'react-router-dom'
import { Center, Loader } from '@mantine/core'
import { AppLayout } from './components/AppLayout'
import { RequireAdmin } from './components/RequireAdmin'
import { LoginPage } from './pages/LoginPage'
import { DashboardPage } from './pages/DashboardPage'
import { CategoriesPage } from './pages/CategoriesPage'
import { TagsPage } from './pages/TagsPage'
import { GroupsListPage } from './pages/GroupsListPage'
import { StudentsListPage } from './pages/StudentsListPage'
// Code-split: this page pulls in the (heavy) xlsx library, loaded only on demand.
const StudentsImportPage = lazy(() =>
  import('./pages/StudentsImportPage').then((m) => ({ default: m.StudentsImportPage })),
)
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
        <Route path="/groups" element={<GroupsListPage />} />
        <Route path="/students" element={<StudentsListPage />} />
        <Route
          path="/students/import"
          element={
            <Suspense fallback={<Center h={240}><Loader /></Center>}>
              <StudentsImportPage />
            </Suspense>
          }
        />
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
