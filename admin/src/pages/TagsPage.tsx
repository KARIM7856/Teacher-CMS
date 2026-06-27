import { useEffect, useState } from 'react'
import {
  ActionIcon,
  Button,
  Group,
  Modal,
  Stack,
  Table,
  Text,
  TextInput,
  Title,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import { IconEdit, IconPlus, IconTrash } from '@tabler/icons-react'
import { createTag, deleteTag, listTags, updateTag } from '../api/tags'
import type { Tag } from '../types/database'

function showError(e: any) {
  notifications.show({ color: 'red', message: e?.message ?? 'حدث خطأ' })
}

export function TagsPage() {
  const [tags, setTags] = useState<Tag[]>([])
  const [opened, setOpened] = useState(false)
  const [editing, setEditing] = useState<Tag | null>(null)

  const form = useForm({
    initialValues: { name: '', slug: '' },
    validate: {
      name: (v) => (v.trim() ? null : 'مطلوب'),
      slug: (v) => (v.trim() ? null : 'مطلوب'),
    },
  })

  async function reload() {
    try {
      setTags(await listTags())
    } catch (e) {
      showError(e)
    }
  }
  useEffect(() => {
    reload()
  }, [])

  function openCreate() {
    setEditing(null)
    form.setValues({ name: '', slug: '' })
    setOpened(true)
  }
  function openEdit(t: Tag) {
    setEditing(t)
    form.setValues({ name: t.name, slug: t.slug })
    setOpened(true)
  }

  function confirmDelete(t: Tag) {
    modals.openConfirmModal({
      title: 'حذف الوسم',
      children: <Text size="sm">هل تريد حذف «{t.name}»؟</Text>,
      labels: { confirm: 'حذف', cancel: 'إلغاء' },
      confirmProps: { color: 'red' },
      onConfirm: async () => {
        try {
          await deleteTag(t.id)
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
        <Title order={2}>الوسوم</Title>
        <Button leftSection={<IconPlus size={16} />} onClick={openCreate}>
          وسم جديد
        </Button>
      </Group>

      <Table striped withTableBorder>
        <Table.Thead>
          <Table.Tr>
            <Table.Th>الاسم</Table.Th>
            <Table.Th>المُعرّف</Table.Th>
            <Table.Th w={100} />
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {tags.map((t) => (
            <Table.Tr key={t.id}>
              <Table.Td>{t.name}</Table.Td>
              <Table.Td>
                <Text c="dimmed">{t.slug}</Text>
              </Table.Td>
              <Table.Td>
                <Group gap="xs" justify="flex-end">
                  <ActionIcon variant="subtle" onClick={() => openEdit(t)}>
                    <IconEdit size={16} />
                  </ActionIcon>
                  <ActionIcon variant="subtle" color="red" onClick={() => confirmDelete(t)}>
                    <IconTrash size={16} />
                  </ActionIcon>
                </Group>
              </Table.Td>
            </Table.Tr>
          ))}
          {tags.length === 0 && (
            <Table.Tr>
              <Table.Td colSpan={3}>
                <Text c="dimmed" ta="center" py="md">
                  لا توجد وسوم بعد
                </Text>
              </Table.Td>
            </Table.Tr>
          )}
        </Table.Tbody>
      </Table>

      <Modal
        opened={opened}
        onClose={() => setOpened(false)}
        title={editing ? 'تعديل وسم' : 'وسم جديد'}
      >
        <form
          onSubmit={form.onSubmit(async (values) => {
            try {
              if (editing) await updateTag(editing.id, values)
              else await createTag(values)
              setOpened(false)
              await reload()
              notifications.show({ color: 'green', message: editing ? 'تم التحديث' : 'تمت الإضافة' })
            } catch (e) {
              showError(e)
            }
          })}
        >
          <Stack>
            <TextInput label="الاسم" {...form.getInputProps('name')} />
            <TextInput label="المُعرّف (slug)" {...form.getInputProps('slug')} />
            <Button type="submit">حفظ</Button>
          </Stack>
        </form>
      </Modal>
    </Stack>
  )
}
