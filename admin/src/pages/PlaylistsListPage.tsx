import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  ActionIcon,
  Badge,
  Button,
  Group,
  Stack,
  Table,
  Text,
  Title,
} from '@mantine/core'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import { IconEdit, IconPlus, IconTrash } from '@tabler/icons-react'
import { deletePlaylist, listPlaylists } from '../api/playlists'
import type { PlaylistWithCount } from '../api/playlists'

function showError(e: any) {
  notifications.show({ color: 'red', message: e?.message ?? 'حدث خطأ' })
}

export function PlaylistsListPage() {
  const navigate = useNavigate()
  const [playlists, setPlaylists] = useState<PlaylistWithCount[]>([])

  async function reload() {
    try {
      setPlaylists(await listPlaylists())
    } catch (e) {
      showError(e)
    }
  }
  useEffect(() => {
    reload()
  }, [])

  function confirmDelete(p: PlaylistWithCount) {
    modals.openConfirmModal({
      title: 'حذف قائمة التشغيل',
      children: <Text size="sm">حذف «{p.title}»؟</Text>,
      labels: { confirm: 'حذف', cancel: 'إلغاء' },
      confirmProps: { color: 'red' },
      onConfirm: async () => {
        try {
          await deletePlaylist(p.id)
          await reload()
        } catch (e) {
          showError(e)
        }
      },
    })
  }

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2}>قوائم التشغيل</Title>
        <Button leftSection={<IconPlus size={16} />} onClick={() => navigate('/playlists/new')}>
          قائمة جديدة
        </Button>
      </Group>

      <Table striped withTableBorder highlightOnHover>
        <Table.Thead>
          <Table.Tr>
            <Table.Th>العنوان</Table.Th>
            <Table.Th w={120}>عدد المنشورات</Table.Th>
            <Table.Th w={110}>الحالة</Table.Th>
            <Table.Th w={100} />
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {playlists.map((p) => (
            <Table.Tr
              key={p.id}
              style={{ cursor: 'pointer' }}
              onClick={() => navigate(`/playlists/${p.id}/edit`)}
            >
              <Table.Td>{p.title}</Table.Td>
              <Table.Td>{p.itemCount}</Table.Td>
              <Table.Td>
                {p.published ? (
                  <Badge color="green" variant="light">
                    منشور
                  </Badge>
                ) : (
                  <Badge color="gray" variant="light">
                    مسودة
                  </Badge>
                )}
              </Table.Td>
              <Table.Td onClick={(e) => e.stopPropagation()}>
                <Group gap="xs" justify="flex-end">
                  <ActionIcon variant="subtle" onClick={() => navigate(`/playlists/${p.id}/edit`)}>
                    <IconEdit size={16} />
                  </ActionIcon>
                  <ActionIcon variant="subtle" color="red" onClick={() => confirmDelete(p)}>
                    <IconTrash size={16} />
                  </ActionIcon>
                </Group>
              </Table.Td>
            </Table.Tr>
          ))}
          {playlists.length === 0 && (
            <Table.Tr>
              <Table.Td colSpan={4}>
                <Text c="dimmed" ta="center" py="md">
                  لا توجد قوائم تشغيل بعد
                </Text>
              </Table.Td>
            </Table.Tr>
          )}
        </Table.Tbody>
      </Table>
    </Stack>
  )
}
