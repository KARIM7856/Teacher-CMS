import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  ActionIcon,
  Badge,
  Button,
  Group,
  Select,
  Stack,
  Table,
  Text,
  TextInput,
  Title,
} from '@mantine/core'
import { useDebouncedValue } from '@mantine/hooks'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import { IconEdit, IconPlus, IconSearch, IconTrash } from '@tabler/icons-react'
import { deletePost, listPosts } from '../api/posts'
import { listAllSubcategories, listCategories } from '../api/categories'
import { listTags } from '../api/tags'
import type { Category, Post, Subcategory, Tag } from '../types/database'

function showError(e: any) {
  notifications.show({ color: 'red', message: e?.message ?? 'حدث خطأ' })
}

export function PostsListPage() {
  const navigate = useNavigate()
  const [posts, setPosts] = useState<Post[]>([])
  const [categories, setCategories] = useState<Category[]>([])
  const [subs, setSubs] = useState<Subcategory[]>([])
  const [tags, setTags] = useState<Tag[]>([])

  const [search, setSearch] = useState('')
  const [debouncedSearch] = useDebouncedValue(search, 300)
  const [categoryId, setCategoryId] = useState<string | null>(null)
  const [tagId, setTagId] = useState<string | null>(null)

  const subMap = useMemo(() => {
    const m = new Map<string, Subcategory>()
    for (const s of subs) m.set(s.id, s)
    return m
  }, [subs])
  const catMap = useMemo(() => {
    const m = new Map<string, Category>()
    for (const c of categories) m.set(c.id, c)
    return m
  }, [categories])

  useEffect(() => {
    Promise.all([listCategories(), listAllSubcategories(), listTags()])
      .then(([c, s, t]) => {
        setCategories(c)
        setSubs(s)
        setTags(t)
      })
      .catch(showError)
  }, [])

  useEffect(() => {
    listPosts({ search: debouncedSearch || undefined, categoryId, tagId })
      .then(setPosts)
      .catch(showError)
  }, [debouncedSearch, categoryId, tagId])

  function subcategoryLabel(post: Post) {
    const sub = subMap.get(post.subcategory_id)
    if (!sub) return '—'
    const cat = catMap.get(sub.category_id)
    return cat ? `${cat.name} › ${sub.name}` : sub.name
  }

  function confirmDelete(p: Post) {
    modals.openConfirmModal({
      title: 'حذف المنشور',
      children: <Text size="sm">حذف «{p.title}»؟ لا يمكن التراجع.</Text>,
      labels: { confirm: 'حذف', cancel: 'إلغاء' },
      confirmProps: { color: 'red' },
      onConfirm: async () => {
        try {
          await deletePost(p.id)
          setPosts((prev) => prev.filter((x) => x.id !== p.id))
        } catch (e) {
          showError(e)
        }
      },
    })
  }

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2}>المنشورات</Title>
        <Button leftSection={<IconPlus size={16} />} onClick={() => navigate('/posts/new')}>
          منشور جديد
        </Button>
      </Group>

      <Group align="flex-end" wrap="wrap">
        <TextInput
          label="بحث"
          placeholder="ابحث في العناوين..."
          leftSection={<IconSearch size={16} />}
          value={search}
          onChange={(e) => setSearch(e.currentTarget.value)}
          w={240}
        />
        <Select
          label="التصنيف"
          placeholder="الكل"
          clearable
          data={categories.map((c) => ({ value: c.id, label: c.name }))}
          value={categoryId}
          onChange={setCategoryId}
          w={200}
        />
        <Select
          label="الوسم"
          placeholder="الكل"
          clearable
          data={tags.map((t) => ({ value: t.id, label: t.name }))}
          value={tagId}
          onChange={setTagId}
          w={200}
        />
      </Group>

      <Table striped withTableBorder highlightOnHover>
        <Table.Thead>
          <Table.Tr>
            <Table.Th>العنوان</Table.Th>
            <Table.Th>التصنيف</Table.Th>
            <Table.Th w={110}>الحالة</Table.Th>
            <Table.Th w={100} />
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {posts.map((p) => (
            <Table.Tr
              key={p.id}
              style={{ cursor: 'pointer' }}
              onClick={() => navigate(`/posts/${p.id}/edit`)}
            >
              <Table.Td>{p.title}</Table.Td>
              <Table.Td>
                <Text size="sm" c="dimmed">
                  {subcategoryLabel(p)}
                </Text>
              </Table.Td>
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
                  <ActionIcon variant="subtle" onClick={() => navigate(`/posts/${p.id}/edit`)}>
                    <IconEdit size={16} />
                  </ActionIcon>
                  <ActionIcon variant="subtle" color="red" onClick={() => confirmDelete(p)}>
                    <IconTrash size={16} />
                  </ActionIcon>
                </Group>
              </Table.Td>
            </Table.Tr>
          ))}
          {posts.length === 0 && (
            <Table.Tr>
              <Table.Td colSpan={4}>
                <Text c="dimmed" ta="center" py="md">
                  لا توجد منشورات مطابقة
                </Text>
              </Table.Td>
            </Table.Tr>
          )}
        </Table.Tbody>
      </Table>
    </Stack>
  )
}
