import { AppShell, Burger, Group, NavLink, ScrollArea, Text, Button, Box } from '@mantine/core'
import { useDisclosure } from '@mantine/hooks'
import { NavLink as RouterNavLink, Outlet, useNavigate } from 'react-router-dom'
import {
  IconLayoutDashboard,
  IconCategory,
  IconTags,
  IconArticle,
  IconPlaylist,
  IconLogout,
} from '@tabler/icons-react'
import { useAuth } from '../auth/AuthProvider'

const NAV = [
  { to: '/', label: 'لوحة المعلومات', icon: IconLayoutDashboard, end: true },
  { to: '/categories', label: 'التصنيفات', icon: IconCategory },
  { to: '/tags', label: 'الوسوم', icon: IconTags },
  { to: '/posts', label: 'المنشورات', icon: IconArticle },
  { to: '/playlists', label: 'قوائم التشغيل', icon: IconPlaylist },
]

export function AppLayout() {
  const [opened, { toggle, close }] = useDisclosure()
  const { profile, signOut } = useAuth()
  const navigate = useNavigate()

  async function handleSignOut() {
    await signOut()
    navigate('/login', { replace: true })
  }

  return (
    <AppShell
      header={{ height: 60 }}
      navbar={{ width: 260, breakpoint: 'sm', collapsed: { mobile: !opened } }}
      padding="md"
    >
      <AppShell.Header>
        <Group h="100%" px="md" justify="space-between">
          <Group gap="sm">
            <Burger opened={opened} onClick={toggle} hiddenFrom="sm" size="sm" />
            <Text fw={700}>لوحة تحكم المعلّم</Text>
          </Group>
          <Text size="sm" c="dimmed">
            {profile?.display_name ?? 'مشرف'}
          </Text>
        </Group>
      </AppShell.Header>

      <AppShell.Navbar p="md">
        <AppShell.Section grow component={ScrollArea}>
          {NAV.map((item) => (
            <NavLink
              key={item.to}
              component={RouterNavLink}
              to={item.to}
              end={item.end}
              label={item.label}
              leftSection={<item.icon size={18} stroke={1.5} />}
              onClick={close}
            />
          ))}
        </AppShell.Section>
        <AppShell.Section>
          <Button
            variant="light"
            color="red"
            fullWidth
            leftSection={<IconLogout size={18} />}
            onClick={handleSignOut}
          >
            تسجيل الخروج
          </Button>
        </AppShell.Section>
      </AppShell.Navbar>

      <AppShell.Main>
        <Box maw={1100} mx="auto">
          <Outlet />
        </Box>
      </AppShell.Main>
    </AppShell>
  )
}
