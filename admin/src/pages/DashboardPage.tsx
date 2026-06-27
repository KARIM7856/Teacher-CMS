import { useEffect, useState } from 'react'
import { Card, Group, SimpleGrid, Skeleton, Stack, Text, ThemeIcon, Title } from '@mantine/core'
import { IconArticle, IconCategory, IconPlaylist } from '@tabler/icons-react'
import { getDashboardCounts } from '../api/dashboard'
import type { DashboardCounts } from '../api/dashboard'

export function DashboardPage() {
  const [counts, setCounts] = useState<DashboardCounts | null>(null)

  useEffect(() => {
    getDashboardCounts()
      .then(setCounts)
      .catch(() => setCounts({ posts: 0, playlists: 0, categories: 0 }))
  }, [])

  const cards = [
    { label: 'المنشورات', value: counts?.posts, icon: IconArticle, color: 'indigo' },
    { label: 'قوائم التشغيل', value: counts?.playlists, icon: IconPlaylist, color: 'teal' },
    { label: 'التصنيفات', value: counts?.categories, icon: IconCategory, color: 'grape' },
  ]

  return (
    <Stack>
      <Title order={2}>لوحة المعلومات</Title>
      <SimpleGrid cols={{ base: 1, sm: 3 }}>
        {cards.map((c) => (
          <Card key={c.label} withBorder p="lg">
            <Group>
              <ThemeIcon size={48} radius="md" variant="light" color={c.color}>
                <c.icon size={26} stroke={1.5} />
              </ThemeIcon>
              <div>
                <Text c="dimmed" size="sm">
                  {c.label}
                </Text>
                {counts ? (
                  <Text fw={700} fz={28}>
                    {c.value}
                  </Text>
                ) : (
                  <Skeleton h={28} w={48} mt={6} />
                )}
              </div>
            </Group>
          </Card>
        ))}
      </SimpleGrid>
    </Stack>
  )
}
