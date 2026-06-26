import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import {
  ActionIcon,
  Box,
  Button,
  Card,
  FileButton,
  Group,
  LoadingOverlay,
  MultiSelect,
  Select,
  Stack,
  Switch,
  Tabs,
  Text,
  Textarea,
  TextInput,
  Title,
} from '@mantine/core'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import {
  IconArrowRight,
  IconDeviceFloppy,
  IconExternalLink,
  IconGripVertical,
  IconTrash,
  IconUpload,
} from '@tabler/icons-react'
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { SortableList } from '../components/SortableList'
import { useAuth } from '../auth/AuthProvider'
import { listAllSubcategories, listCategories } from '../api/categories'
import { listTags } from '../api/tags'
import { createPost, getPost, getPostTagIds, setPostTags, updatePost } from '../api/posts'
import {
  deleteMedia,
  getMediaSignedUrl,
  guessMediaType,
  listMedia,
  reorderMedia,
  updateMedia,
  uploadMedia,
} from '../api/media'
import type { Category, Media, MediaType, Subcategory, Tag } from '../types/database'

const MEDIA_TYPE_OPTIONS = [
  { value: 'video', label: 'فيديو' },
  { value: 'pdf', label: 'PDF' },
  { value: 'other', label: 'أخرى' },
]

function showError(e: any) {
  notifications.show({ color: 'red', message: e?.message ?? 'حدث خطأ' })
}

export function PostEditPage() {
  const params = useParams()
  const navigate = useNavigate()
  const { session } = useAuth()
  const routeId = params.id && params.id !== 'new' ? params.id : null

  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [postId, setPostId] = useState<string | null>(routeId)

  const [title, setTitle] = useState('')
  const [body, setBody] = useState('')
  const [subcategoryId, setSubcategoryId] = useState<string | null>(null)
  const [published, setPublished] = useState(false)
  const [tagIds, setTagIds] = useState<string[]>([])

  const [categories, setCategories] = useState<Category[]>([])
  const [allSubs, setAllSubs] = useState<Subcategory[]>([])
  const [tags, setTags] = useState<Tag[]>([])
  const [media, setMedia] = useState<Media[]>([])

  useEffect(() => {
    ;(async () => {
      try {
        const [c, s, t] = await Promise.all([listCategories(), listAllSubcategories(), listTags()])
        setCategories(c)
        setAllSubs(s)
        setTags(t)
        if (routeId) {
          const post = await getPost(routeId)
          if (post) {
            setTitle(post.title)
            setBody(post.body ?? '')
            setSubcategoryId(post.subcategory_id)
            setPublished(post.published)
          }
          setTagIds(await getPostTagIds(routeId))
          setMedia(await listMedia(routeId))
        }
      } catch (e) {
        showError(e)
      } finally {
        setLoading(false)
      }
    })()
  }, [routeId])

  const subcategoryData = useMemo(
    () =>
      categories
        .map((c) => ({
          group: c.name,
          items: allSubs
            .filter((s) => s.category_id === c.id)
            .map((s) => ({ value: s.id, label: s.name })),
        }))
        .filter((g) => g.items.length > 0),
    [categories, allSubs],
  )
  const tagData = useMemo(() => tags.map((t) => ({ value: t.id, label: t.name })), [tags])

  async function reloadMedia(id: string) {
    try {
      setMedia(await listMedia(id))
    } catch (e) {
      showError(e)
    }
  }

  async function handleSave() {
    if (!title.trim()) {
      notifications.show({ color: 'red', message: 'العنوان مطلوب' })
      return
    }
    if (!subcategoryId) {
      notifications.show({ color: 'red', message: 'اختر تصنيفًا فرعيًا' })
      return
    }
    setSaving(true)
    try {
      if (postId) {
        await updatePost(postId, { title, body: body || null, subcategory_id: subcategoryId, published })
        await setPostTags(postId, tagIds)
        notifications.show({ color: 'green', message: 'تم الحفظ' })
      } else {
        const newId = await createPost({
          title,
          body: body || null,
          subcategory_id: subcategoryId,
          published,
          author_id: session?.user.id ?? null,
        })
        await setPostTags(newId, tagIds)
        setPostId(newId)
        notifications.show({ color: 'green', message: 'تم إنشاء المنشور' })
        navigate(`/posts/${newId}/edit`, { replace: true })
      }
    } catch (e) {
      showError(e)
    } finally {
      setSaving(false)
    }
  }

  async function handleUpload(files: File[]) {
    if (!postId || files.length === 0) return
    try {
      for (const f of files) await uploadMedia(postId, f, guessMediaType(f))
      await reloadMedia(postId)
    } catch (e) {
      showError(e)
    }
  }

  async function changeType(id: string, type: MediaType) {
    try {
      await updateMedia(id, { type })
      if (postId) await reloadMedia(postId)
    } catch (e) {
      showError(e)
    }
  }

  async function openMedia(m: Media) {
    if (m.external_url) {
      window.open(m.external_url, '_blank')
      return
    }
    if (m.storage_path) {
      const url = await getMediaSignedUrl(m.storage_path)
      if (url) window.open(url, '_blank')
    }
  }

  function removeMedia(m: Media) {
    modals.openConfirmModal({
      title: 'حذف الملف',
      children: <Text size="sm">حذف «{m.display_name ?? 'ملف'}»؟</Text>,
      labels: { confirm: 'حذف', cancel: 'إلغاء' },
      confirmProps: { color: 'red' },
      onConfirm: async () => {
        try {
          await deleteMedia(m)
          if (postId) await reloadMedia(postId)
        } catch (e) {
          showError(e)
        }
      },
    })
  }

  async function onReorderMedia(next: Media[]) {
    setMedia(next)
    try {
      await reorderMedia(next.map((m) => m.id))
    } catch (e) {
      showError(e)
    }
  }

  return (
    <Stack pos="relative">
      <LoadingOverlay visible={loading} />
      <Group justify="space-between">
        <Group gap="xs">
          <ActionIcon variant="subtle" onClick={() => navigate('/posts')}>
            <IconArrowRight size={18} />
          </ActionIcon>
          <Title order={2}>{postId ? 'تعديل منشور' : 'منشور جديد'}</Title>
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
          <Select
            label="التصنيف الفرعي"
            required
            placeholder="اختر..."
            data={subcategoryData}
            value={subcategoryId}
            onChange={setSubcategoryId}
            searchable
          />
          <MultiSelect
            label="الوسوم"
            placeholder="اختر وسومًا"
            data={tagData}
            value={tagIds}
            onChange={setTagIds}
            searchable
            clearable
          />
          <Box>
            <Text size="sm" fw={500} mb={4}>
              المحتوى (Markdown)
            </Text>
            <Tabs defaultValue="edit">
              <Tabs.List>
                <Tabs.Tab value="edit">تحرير</Tabs.Tab>
                <Tabs.Tab value="preview">معاينة</Tabs.Tab>
              </Tabs.List>
              <Tabs.Panel value="edit" pt="xs">
                <Textarea
                  autosize
                  minRows={8}
                  value={body}
                  onChange={(e) => setBody(e.currentTarget.value)}
                  placeholder="اكتب المحتوى بصيغة ماركداون..."
                />
              </Tabs.Panel>
              <Tabs.Panel value="preview" pt="xs">
                <Box className="markdown-preview" style={{ minHeight: 160 }}>
                  <Markdown remarkPlugins={[remarkGfm]}>{body || '_لا يوجد محتوى_'}</Markdown>
                </Box>
              </Tabs.Panel>
            </Tabs>
          </Box>
          <Switch
            label="منشور"
            checked={published}
            onChange={(e) => setPublished(e.currentTarget.checked)}
          />
        </Stack>
      </Card>

      <Card withBorder p="lg">
        <Group justify="space-between" mb="sm">
          <Title order={4}>الملفات والوسائط</Title>
          <FileButton multiple onChange={handleUpload} disabled={!postId}>
            {(props) => (
              <Button
                {...props}
                variant="light"
                leftSection={<IconUpload size={16} />}
                disabled={!postId}
              >
                رفع ملفات
              </Button>
            )}
          </FileButton>
        </Group>
        {!postId && (
          <Text size="sm" c="dimmed">
            احفظ المنشور أولًا لتتمكّن من رفع الملفات.
          </Text>
        )}
        {postId && media.length === 0 && (
          <Text size="sm" c="dimmed">
            لا توجد ملفات بعد.
          </Text>
        )}
        <SortableList
          items={media}
          onReorder={onReorderMedia}
          renderItem={(m, handle) => (
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
                  {m.display_name ?? m.storage_path}
                </Text>
              </Group>
              <Group gap="xs" wrap="nowrap">
                <Select
                  size="xs"
                  w={110}
                  data={MEDIA_TYPE_OPTIONS}
                  value={m.type}
                  onChange={(v) => v && changeType(m.id, v as MediaType)}
                  allowDeselect={false}
                />
                <ActionIcon variant="subtle" onClick={() => openMedia(m)}>
                  <IconExternalLink size={16} />
                </ActionIcon>
                <ActionIcon variant="subtle" color="red" onClick={() => removeMedia(m)}>
                  <IconTrash size={16} />
                </ActionIcon>
              </Group>
            </Group>
          )}
        />
      </Card>
    </Stack>
  )
}
