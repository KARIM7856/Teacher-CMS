import { useEffect, useState } from 'react'
import {
  ActionIcon,
  Box,
  Button,
  Card,
  Divider,
  Group,
  Modal,
  Stack,
  Text,
  TextInput,
  Title,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import { IconEdit, IconGripVertical, IconPlus, IconTrash } from '@tabler/icons-react'
import { SortableList } from '../components/SortableList'
import {
  createCategory,
  createSubcategory,
  deleteCategory,
  deleteSubcategory,
  listAllSubcategories,
  listCategories,
  reorderCategories,
  reorderSubcategories,
  updateCategory,
  updateSubcategory,
} from '../api/categories'
import type { Category, Subcategory } from '../types/database'

function showError(e: any) {
  notifications.show({ color: 'red', message: e?.message ?? 'حدث خطأ' })
}

export function CategoriesPage() {
  const [cats, setCats] = useState<Category[]>([])
  const [subs, setSubs] = useState<Record<string, Subcategory[]>>({})

  const [catModal, setCatModal] = useState(false)
  const [editingCat, setEditingCat] = useState<Category | null>(null)
  const catForm = useForm({
    initialValues: { name: '', slug: '', icon: '' },
    validate: { name: (v) => (v.trim() ? null : 'مطلوب'), slug: (v) => (v.trim() ? null : 'مطلوب') },
  })

  const [subModal, setSubModal] = useState(false)
  const [subContext, setSubContext] = useState<{ categoryId: string; editing: Subcategory | null } | null>(
    null,
  )
  const subForm = useForm({
    initialValues: { name: '', slug: '' },
    validate: { name: (v) => (v.trim() ? null : 'مطلوب'), slug: (v) => (v.trim() ? null : 'مطلوب') },
  })

  async function reload() {
    try {
      const c = await listCategories()
      const allSubs = await listAllSubcategories()
      const grouped: Record<string, Subcategory[]> = {}
      for (const cat of c) grouped[cat.id] = []
      for (const s of allSubs) (grouped[s.category_id] ??= []).push(s)
      setCats(c)
      setSubs(grouped)
    } catch (e) {
      showError(e)
    }
  }
  useEffect(() => {
    reload()
  }, [])

  function newCategory() {
    setEditingCat(null)
    catForm.setValues({ name: '', slug: '', icon: '' })
    setCatModal(true)
  }
  function editCategory(c: Category) {
    setEditingCat(c)
    catForm.setValues({ name: c.name, slug: c.slug, icon: c.icon ?? '' })
    setCatModal(true)
  }
  function deleteCategoryConfirm(c: Category) {
    modals.openConfirmModal({
      title: 'حذف التصنيف',
      children: <Text size="sm">سيُحذف «{c.name}» وكل تصنيفاته الفرعية. متابعة؟</Text>,
      labels: { confirm: 'حذف', cancel: 'إلغاء' },
      confirmProps: { color: 'red' },
      onConfirm: async () => {
        try {
          await deleteCategory(c.id)
          await reload()
        } catch (e) {
          showError(e)
        }
      },
    })
  }
  async function onReorderCats(next: Category[]) {
    setCats(next)
    try {
      await reorderCategories(next.map((c) => c.id))
    } catch (e) {
      showError(e)
    }
  }

  function newSub(categoryId: string) {
    setSubContext({ categoryId, editing: null })
    subForm.setValues({ name: '', slug: '' })
    setSubModal(true)
  }
  function editSub(s: Subcategory) {
    setSubContext({ categoryId: s.category_id, editing: s })
    subForm.setValues({ name: s.name, slug: s.slug })
    setSubModal(true)
  }
  function deleteSubConfirm(s: Subcategory) {
    modals.openConfirmModal({
      title: 'حذف التصنيف الفرعي',
      children: <Text size="sm">حذف «{s.name}»؟</Text>,
      labels: { confirm: 'حذف', cancel: 'إلغاء' },
      confirmProps: { color: 'red' },
      onConfirm: async () => {
        try {
          await deleteSubcategory(s.id)
          await reload()
        } catch (e) {
          showError(e)
        }
      },
    })
  }
  async function onReorderSubs(categoryId: string, next: Subcategory[]) {
    setSubs((prev) => ({ ...prev, [categoryId]: next }))
    try {
      await reorderSubcategories(next.map((s) => s.id))
    } catch (e) {
      showError(e)
    }
  }

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2}>التصنيفات</Title>
        <Button leftSection={<IconPlus size={16} />} onClick={newCategory}>
          تصنيف جديد
        </Button>
      </Group>

      {cats.length === 0 && <Text c="dimmed">لا توجد تصنيفات بعد.</Text>}

      <SortableList
        items={cats}
        onReorder={onReorderCats}
        renderItem={(cat, handle) => (
          <Card withBorder mb="sm" p="md">
            <Group justify="space-between" wrap="nowrap">
              <Group gap="xs" wrap="nowrap">
                <ActionIcon variant="subtle" color="gray" {...handle} style={{ cursor: 'grab' }}>
                  <IconGripVertical size={18} />
                </ActionIcon>
                <div>
                  <Text fw={600}>{cat.name}</Text>
                  <Text size="xs" c="dimmed">
                    {cat.slug}
                    {cat.icon ? ` · ${cat.icon}` : ''}
                  </Text>
                </div>
              </Group>
              <Group gap="xs">
                <ActionIcon variant="subtle" onClick={() => editCategory(cat)}>
                  <IconEdit size={16} />
                </ActionIcon>
                <ActionIcon variant="subtle" color="red" onClick={() => deleteCategoryConfirm(cat)}>
                  <IconTrash size={16} />
                </ActionIcon>
              </Group>
            </Group>

            <Divider my="sm" label="التصنيفات الفرعية" labelPosition="center" />
            <Box pe="lg">
              <SortableList
                items={subs[cat.id] ?? []}
                onReorder={(next) => onReorderSubs(cat.id, next)}
                renderItem={(s, h) => (
                  <Group justify="space-between" wrap="nowrap" py={4}>
                    <Group gap="xs" wrap="nowrap">
                      <ActionIcon variant="subtle" color="gray" {...h} style={{ cursor: 'grab' }}>
                        <IconGripVertical size={16} />
                      </ActionIcon>
                      <Text size="sm">{s.name}</Text>
                      <Text size="xs" c="dimmed">
                        {s.slug}
                      </Text>
                    </Group>
                    <Group gap={4}>
                      <ActionIcon variant="subtle" size="sm" onClick={() => editSub(s)}>
                        <IconEdit size={14} />
                      </ActionIcon>
                      <ActionIcon variant="subtle" size="sm" color="red" onClick={() => deleteSubConfirm(s)}>
                        <IconTrash size={14} />
                      </ActionIcon>
                    </Group>
                  </Group>
                )}
              />
              <Button
                variant="subtle"
                size="compact-sm"
                mt="xs"
                leftSection={<IconPlus size={14} />}
                onClick={() => newSub(cat.id)}
              >
                إضافة تصنيف فرعي
              </Button>
            </Box>
          </Card>
        )}
      />

      <Modal
        opened={catModal}
        onClose={() => setCatModal(false)}
        title={editingCat ? 'تعديل تصنيف' : 'تصنيف جديد'}
      >
        <form
          onSubmit={catForm.onSubmit(async (v) => {
            try {
              const payload = { name: v.name, slug: v.slug, icon: v.icon || null }
              if (editingCat) await updateCategory(editingCat.id, payload)
              else await createCategory({ ...payload, sort_order: cats.length })
              setCatModal(false)
              await reload()
            } catch (e) {
              showError(e)
            }
          })}
        >
          <Stack>
            <TextInput label="الاسم" {...catForm.getInputProps('name')} />
            <TextInput label="المُعرّف (slug)" {...catForm.getInputProps('slug')} />
            <TextInput label="الأيقونة (اختياري)" placeholder="calculator" {...catForm.getInputProps('icon')} />
            <Button type="submit">حفظ</Button>
          </Stack>
        </form>
      </Modal>

      <Modal
        opened={subModal}
        onClose={() => setSubModal(false)}
        title={subContext?.editing ? 'تعديل تصنيف فرعي' : 'تصنيف فرعي جديد'}
      >
        <form
          onSubmit={subForm.onSubmit(async (v) => {
            if (!subContext) return
            try {
              if (subContext.editing) await updateSubcategory(subContext.editing.id, v)
              else
                await createSubcategory({
                  category_id: subContext.categoryId,
                  name: v.name,
                  slug: v.slug,
                  sort_order: subs[subContext.categoryId]?.length ?? 0,
                })
              setSubModal(false)
              await reload()
            } catch (e) {
              showError(e)
            }
          })}
        >
          <Stack>
            <TextInput label="الاسم" {...subForm.getInputProps('name')} />
            <TextInput label="المُعرّف (slug)" {...subForm.getInputProps('slug')} />
            <Button type="submit">حفظ</Button>
          </Stack>
        </form>
      </Modal>
    </Stack>
  )
}
