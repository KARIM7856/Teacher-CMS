import type { ReactNode } from 'react'
import { Navigate } from 'react-router-dom'
import { Center, Loader } from '@mantine/core'
import { useAuth } from '../auth/AuthProvider'

// Route guard: only an authenticated admin may see the wrapped content.
export function RequireAdmin({ children }: { children: ReactNode }) {
  const { session, isAdmin, loading } = useAuth()

  if (loading) {
    return (
      <Center h="100vh">
        <Loader />
      </Center>
    )
  }

  if (!session || !isAdmin) {
    return <Navigate to="/login" replace />
  }

  return <>{children}</>
}
