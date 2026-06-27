import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  ActionIcon,
  Badge,
  Box,
  Button,
  Card,
  Group,
  LoadingOverlay,
  Select,
  Stack,
  Switch,
  Text,
  Textarea,
  TextInput,
  Title,
} from '@mantine/core'
import { notifications } from '@mantine/notifications'
import { IconArrowRight, IconDeviceFloppy, IconGripVertical, IconPlus, IconTrash } from '@tabler/icons-react'
import { SortableList } from '../components/SortableList'
import { listPosts } from '../api/posts'
import {
  addPlaylistItem,
  createPlaylist,
  getPlaylist,
  listPlaylistItems,
  removePlaylistItem,
  reorderPlaylistItems,
  updatePlaylist,
} from '../api/playlists'
import type { PlaylistItemWithPost } from '../api/playlists'
import type { Post } from '../types/database'

function showError(e: any) {
  notifications.show({ color: 'red', message: e?.message ?? 'حدث خطأ' })
}

export function PlaylistEditPage() {
  const params = useParams()
  const navigate = useNavigate()
  const routeId = params.id && params.id !== 'new' ? params.id : null

  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [playlistId, setPlaylistId] = useState<string | null>(routeId)

  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [coverImage, setCoverImage] = useState('')
  const [published, setPublished] = useState(false)

  const [items, setItems] = useState<PlaylistItemWithPost[]>([])
  const [allPosts, setAllPosts] = useState<Post[]>([])
  const [addPostId, setAddPostId] = useState<string | null>(null)

  useEffect(() => {
    ;(async () => {
      try {
        setAllPosts(await listPosts({}))
        if (routeId) {
          const pl = await getPlaylist(routeId)
          if (pl) {
            setTitle(pl.title)
            setDescription(pl.description ?? '')
            setCoverImage(pl.cover_image ?? '')
            setPublished(pl.published)
          }
          setItems(await listPlaylistItems(routeId))
        }
      } catch (e) {
        showError(e)
      } finally {
        setLoading(false)
      }
    })()
  }, [routeId])

  const availablePosts = useMemo(() => {
    const taken = new Set(items.map((i) => i.post_id))
    return allPosts.filter((p) => !taken.has(p.id)).map((p) => ({ value: p.id, label: p.title }))
  }, [allPosts, items])

  async function reloadItems(id: string) {
    try {
      setItems(await listPlaylistItems(id))
    } catch (e) {
      showError(e)
    }
  }

  async function handleSave() {
    if (!title.trim()) {
      notifications.show({ color: 'red', message: 'العنوان مطلوب' })
      return
    }
    setSaving(true)
    try {
      const payload = {
        title,
        description: description || null,
        cover_image: coverImage || null,
        published,
      }
      if (playlistId) {
        await updatePlaylist(playlistId, payload)
        notifications.show({ color: 'green', message: 'تم الحفظ' })
      } else {
        const newId = await createPlaylist(payload)
        setPlaylistId(newId)
        notifications.show({ color: 'green', message: 'تم إنشاء القائمة' })
        navigate(`/playlists/${newId}/edit`, { replace: true })
      }
    } catch (e) {
      showError(e)
    } finally {
      setSaving(false)
    }
  }

  async function handleAddPost() {
    if (!playlistId || !addPostId) return
    try {
      await addPlaylistItem(playlistId, addPostId, items.length)
      setAddPostId(null)
      await reloadItems(playlistId)
    } catch (e) {
      showError(e)
    }
  }

  async function handleRemove(item: PlaylistItemWithPost) {
    try {
      await removePlaylistItem(item.id)
      if (playlistId) await reloadItems(playlistId)
    } catch (e) {
      showError(e)
    }
  }

  async function onReorder(next: PlaylistItemWithPost[]) {
    setItems(next)
    try {
      await reorderPlaylistItems(next.map((i) => i.id))
    } catch (e) {
      showError(e)
    }
  }

  return (
    <Stack pos="relative">
      <LoadingOverlay visible={loading} />
      <Group justify="space-between">
        <Group gap="xs">
          <ActionIcon variant="subtle" onClick={() => navigate('/playlists')}>
            <IconArrowRight size={18} />
          </ActionIcon>
          <Title order={2}>{playlistId ? 'تعديل قائمة تشغيل' : 'قائمة تشغيل جديدة'}</Title>
        </Group>
        <Button leftSection={<IconDeviceFloppy size={16} />} loading={saving} onClick={handleSave}>
          حفظ
        </Button>
      </Group>

      <Card withBorder p="lg">
        <Stack>
          <TextInput
            label="العنوان"
            required
            value={title}
            onChange={(e) => setTitle(e.currentTarget.value)}
          />
          <Textarea
            label="الوصف"
            autosize
            minRows={2}
            value={description}
            onChange={(e) => setDescription(e.currentTarget.value)}
          />
          <TextInput
            label="رابط صورة الغلاف (اختياري)"
            placeholder="https://..."
            value={coverImage}
            onChange={(e) => setCoverImage(e.currentTarget.value)}
          />
          <Switch
            label="منشور"
            checked={published}
            onChange={(e) => setPublished(e.currentTarget.checked)}
          />
        </Stack>
      </Card>

      <Card withBorder p="lg">
        <Title order={4} mb="sm">
          المنشورات في القائمة
        </Title>
        {!playlistId && (
          <Text size="sm" c="dimmed">
            احفظ القائمة أولًا لتتمكّن من إضافة المنشورات.
          </Text>
        )}

        {playlistId && (
          <>
            <Group mb="md" align="flex-end">
              <Select
                label="إضافة منشور"
                placeholder="اختر منشورًا"
                data={availablePosts}
                value={addPostId}
                onChange={setAddPostId}
                searchable
                w={300}
                nothingFoundMessage="لا مزيد من المنشورات"
              />
              <Button
                variant="light"
                leftSection={<IconPlus size={16} />}
                onClick={handleAddPost}
                disabled={!addPostId}
              >
                إضافة
              </Button>
            </Group>

            {items.length === 0 && (
              <Text size="sm" c="dimmed">
                القائمة فارغة.
              </Text>
            )}

            <SortableList
              items={items}
              onReorder={onReorder}
              renderItem={(item, handle) => (
                <Group
                  justify="space-between"
                  wrap="nowrap"
                  py={6}
                  style={{ borderBottom: '1px solid var(--mantine-color-default-border)' }}
                >
                  <Group gap="xs" wrap="nowrap" style={{ minWidth: 0 }}>
                    <ActionIcon variant="subtle" color="gray" {...handle} style={{ cursor: 'grab' }}>
                      <IconGripVertical size={16} />
                    </ActionIcon>
                    <Text size="sm" truncate>
                      {item.post?.title ?? '—'}
                    </Text>
                    {item.post && !item.post.published && (
                      <Badge size="xs" color="gray" variant="light">
                        مسودة
                      </Badge>
                    )}
                  </Group>
                  <ActionIcon variant="subtle" color="red" onClick={() => handleRemove(item)}>
                    <IconTrash size={16} />
                  </ActionIcon>
                </Group>
              )}
            />
          </>
        )}
      </Card>
      <Box />
    </Stack>
  )
}
