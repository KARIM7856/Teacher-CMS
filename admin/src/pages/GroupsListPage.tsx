import { useEffect, useMemo, useState } from 'react'
import {
  ActionIcon,
  Box,
  Button,
  Card,
  Checkbox,
  Divider,
  Group,
  Modal,
  ScrollArea,
  Stack,
  Text,
  Textarea,
  TextInput,
  Title,
  Tooltip,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import { IconEdit, IconLock, IconPlus, IconTrash } from '@tabler/icons-react'
import { listAllSubcategories, listCategories } from '../api/categories'
import {
  createGroup,
  deleteGroup,
  getGroupGrants,
  listGroups,
  setGroupGrants,
  updateGroup,
} from '../api/groups'
import type { Category, Group as GroupType, Subcategory } from '../types/database'

function showError(e: any) {
  notifications.show({ color: 'red', message: e?.message ?? 'حدث خطأ' })
}

export function GroupsListPage() {
  const [groups, setGroups] = useState<GroupType[]>([])
  const [cats, setCats] = useState<Category[]>([])
  const [subsByCat, setSubsByCat] = useState<Record<string, Subcategory[]>>({})

  const [groupModal, setGroupModal] = useState(false)
  const [editingGroup, setEditingGroup] = useState<GroupType | null>(null)
  const groupForm = useForm({
    initialValues: { name: '', description: '' },
    validate: { name: (v) => (v.trim() ? null : 'مطلوب') },
  })

  // Grants editor state.
  const [grantsTarget, setGrantsTarget] = useState<GroupType | null>(null)
  const [grantsLoading, setGrantsLoading] = useState(false)
  const [grantsSaving, setGrantsSaving] = useState(false)
  const [catChecked, setCatChecked] = useState<Set<string>>(new Set())
  const [subChecked, setSubChecked] = useState<Set<string>>(new Set())

  // sub id -> its category id, so we can drop redundant sub grants under a
  // wholesale category on save.
  const subCategoryOf = useMemo(() => {
    const m = new Map<string, string>()
    for (const list of Object.values(subsByCat)) for (const s of list) m.set(s.id, s.category_id)
    return m
  }, [subsByCat])

  async function reload() {
    try {
      const [g, c, allSubs] = await Promise.all([
        listGroups(),
        listCategories(),
        listAllSubcategories(),
      ])
      const grouped: Record<string, Subcategory[]> = {}
      for (const cat of c) grouped[cat.id] = []
      for (const s of allSubs) (grouped[s.category_id] ??= []).push(s)
      setGroups(g)
      setCats(c)
      setSubsByCat(grouped)
    } catch (e) {
      showError(e)
    }
  }
  useEffect(() => {
    reload()
  }, [])

  function newGroup() {
    setEditingGroup(null)
    groupForm.setValues({ name: '', description: '' })
    setGroupModal(true)
  }
  function editGroup(g: GroupType) {
    setEditingGroup(g)
    groupForm.setValues({ name: g.name, description: g.description ?? '' })
    setGroupModal(true)
  }
  function confirmDelete(g: GroupType) {
    modals.openConfirmModal({
      title: 'حذف المجموعة',
      children: (
        <Text size="sm">
          سيُحذف «{g.name}» وصلاحياته، وسيخرج طلابه منه (لن تُحذف حساباتهم). متابعة؟
        </Text>
      ),
      labels: { confirm: 'حذف', cancel: 'إلغاء' },
      confirmProps: { color: 'red' },
      onConfirm: async () => {
        try {
          await deleteGroup(g.id)
          await reload()
        } catch (e) {
          showError(e)
        }
      },
    })
  }

  async function openGrants(g: GroupType) {
    setGrantsTarget(g)
    setGrantsLoading(true)
    setCatChecked(new Set())
    setSubChecked(new Set())
    try {
      const grants = await getGroupGrants(g.id)
      setCatChecked(new Set(grants.categoryIds))
      setSubChecked(new Set(grants.subcategoryIds))
    } catch (e) {
      showError(e)
      setGrantsTarget(null)
    } finally {
      setGrantsLoading(false)
    }
  }

  function toggleCat(id: string) {
    setCatChecked((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }
  function toggleSub(id: string) {
    setSubChecked((prev) => {
      const next = new Set(prev)
      next.has(id) ? next.delete(id) : next.add(id)
      return next
    })
  }

  async function saveGrants() {
    if (!grantsTarget) return
    setGrantsSaving(true)
    try {
      // Drop individual sub grants that a wholesale category already covers.
      const subcategoryIds = [...subChecked].filter(
        (id) => !catChecked.has(subCategoryOf.get(id) ?? ''),
      )
      await setGroupGrants(grantsTarget.id, {
        categoryIds: [...catChecked],
        subcategoryIds,
      })
      setGrantsTarget(null)
      notifications.show({ color: 'green', message: 'تم حفظ الصلاحيات' })
    } catch (e) {
      showError(e)
    } finally {
      setGrantsSaving(false)
    }
  }

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2}>المجموعات</Title>
        <Button leftSection={<IconPlus size={16} />} onClick={newGroup}>
          مجموعة جديدة
        </Button>
      </Group>

      <Text c="dimmed" size="sm">
        كل مجموعة تحدّد ما يراه طلابها من التصنيفات. الطالب الذي لا ينتمي لأي مجموعة لا يرى أي محتوى.
      </Text>

      {groups.length === 0 && <Text c="dimmed">لا توجد مجموعات بعد.</Text>}

      {groups.map((g) => (
        <Card key={g.id} withBorder p="md">
          <Group justify="space-between" wrap="nowrap">
            <div>
              <Text fw={600}>{g.name}</Text>
              {g.description && (
                <Text size="sm" c="dimmed">
                  {g.description}
                </Text>
              )}
            </div>
            <Group gap="xs" wrap="nowrap">
              <Button
                variant="light"
                size="compact-sm"
                leftSection={<IconLock size={14} />}
                onClick={() => openGrants(g)}
              >
                الصلاحيات
              </Button>
              <Tooltip label="تعديل">
                <ActionIcon variant="subtle" onClick={() => editGroup(g)}>
                  <IconEdit size={16} />
                </ActionIcon>
              </Tooltip>
              <Tooltip label="حذف">
                <ActionIcon variant="subtle" color="red" onClick={() => confirmDelete(g)}>
                  <IconTrash size={16} />
                </ActionIcon>
              </Tooltip>
            </Group>
          </Group>
        </Card>
      ))}

      {/* Create / edit group */}
      <Modal
        opened={groupModal}
        onClose={() => setGroupModal(false)}
        title={editingGroup ? 'تعديل مجموعة' : 'مجموعة جديدة'}
      >
        <form
          onSubmit={groupForm.onSubmit(async (v) => {
            try {
              const payload = { name: v.name.trim(), description: v.description.trim() || null }
              if (editingGroup) await updateGroup(editingGroup.id, payload)
              else await createGroup({ ...payload, sort_order: groups.length })
              setGroupModal(false)
              await reload()
            } catch (e) {
              showError(e)
            }
          })}
        >
          <Stack>
            <TextInput label="الاسم" placeholder="مثال: الصف العاشر" {...groupForm.getInputProps('name')} />
            <Textarea
              label="الوصف (اختياري)"
              autosize
              minRows={2}
              {...groupForm.getInputProps('description')}
            />
            <Button type="submit">حفظ</Button>
          </Stack>
        </form>
      </Modal>

      {/* Grants editor */}
      <Modal
        opened={grantsTarget !== null}
        onClose={() => setGrantsTarget(null)}
        title={`صلاحيات — ${grantsTarget?.name ?? ''}`}
        size="lg"
      >
        <Stack>
          <Text size="sm" c="dimmed">
            فعّل تصنيفًا كاملًا ليشمل كل تصنيفاته الفرعية (الحالية والمستقبلية)، أو اختر تصنيفات فرعية
            بمفردها.
          </Text>

          {grantsLoading ? (
            <Text c="dimmed" py="md" ta="center">
              جارٍ التحميل…
            </Text>
          ) : cats.length === 0 ? (
            <Text c="dimmed" py="md" ta="center">
              لا توجد تصنيفات بعد. أنشئ تصنيفات أولًا من صفحة التصنيفات.
            </Text>
          ) : (
            <ScrollArea.Autosize mah={420}>
              <Stack gap="xs">
                {cats.map((cat) => {
                  const wholeCategory = catChecked.has(cat.id)
                  const subs = subsByCat[cat.id] ?? []
                  return (
                    <Box key={cat.id}>
                      <Checkbox
                        label={cat.name}
                        fw={600}
                        checked={wholeCategory}
                        onChange={() => toggleCat(cat.id)}
                      />
                      {subs.length > 0 && (
                        <Box pe="xl" mt={6}>
                          <Stack gap={4}>
                            {subs.map((s) => (
                              <Checkbox
                                key={s.id}
                                label={s.name}
                                size="sm"
                                checked={wholeCategory || subChecked.has(s.id)}
                                disabled={wholeCategory}
                                onChange={() => toggleSub(s.id)}
                              />
                            ))}
                          </Stack>
                        </Box>
                      )}
                      <Divider mt="xs" />
                    </Box>
                  )
                })}
              </Stack>
            </ScrollArea.Autosize>
          )}

          <Button onClick={saveGrants} loading={grantsSaving} disabled={grantsLoading}>
            حفظ الصلاحيات
          </Button>
        </Stack>
      </Modal>
    </Stack>
  )
}
