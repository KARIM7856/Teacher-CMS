import { useEffect, useMemo, useState } from 'react'
import {
  ActionIcon,
  Alert,
  Badge,
  Button,
  CopyButton,
  Group,
  Modal,
  Stack,
  Table,
  Text,
  TextInput,
  Title,
  Tooltip,
} from '@mantine/core'
import { useForm } from '@mantine/form'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import {
  IconCheck,
  IconCopy,
  IconEdit,
  IconKey,
  IconPlus,
  IconRefresh,
  IconSearch,
  IconTrash,
  IconUserCheck,
  IconUserOff,
} from '@tabler/icons-react'
import {
  createStudent,
  deleteStudent,
  listStudents,
  renameStudent,
  resetStudentPassword,
  setStudentDisabled,
} from '../api/students'
import type { StudentAccount } from '../types/database'

const USERNAME_RE = /^[a-z0-9._-]{3,30}$/
const dateFmt = new Intl.DateTimeFormat('ar', { dateStyle: 'medium' })

function fmtDate(iso: string | null): string {
  return iso ? dateFmt.format(new Date(iso)) : '—'
}

function showError(e: any) {
  notifications.show({ color: 'red', message: e?.message ?? 'حدث خطأ' })
}

// Strong, unambiguous password (no 0/O/1/l/I) — the teacher reads it out to the student.
function generatePassword(length = 10): string {
  const alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  const values = new Uint32Array(length)
  crypto.getRandomValues(values)
  return Array.from(values, (v) => alphabet[v % alphabet.length]).join('')
}

export function StudentsListPage() {
  const [students, setStudents] = useState<StudentAccount[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')

  const [createOpened, setCreateOpened] = useState(false)
  const [resetTarget, setResetTarget] = useState<StudentAccount | null>(null)
  const [renameTarget, setRenameTarget] = useState<StudentAccount | null>(null)
  // Shown after create / reset so the teacher can copy the credentials to hand off.
  const [credentials, setCredentials] = useState<{ username: string; password: string } | null>(
    null,
  )

  const createForm = useForm({
    initialValues: { username: '', display_name: '', password: '' },
    validate: {
      username: (v) =>
        USERNAME_RE.test(v.trim().toLowerCase())
          ? null
          : 'أحرف إنجليزية وأرقام و . _ - فقط (3–30 خانة)',
      display_name: (v) => (v.trim() ? null : 'مطلوب'),
      password: (v) => (v.length >= 6 ? null : 'لا تقل عن 6 خانات'),
    },
  })
  const resetForm = useForm({
    initialValues: { password: '' },
    validate: { password: (v) => (v.length >= 6 ? null : 'لا تقل عن 6 خانات') },
  })
  const renameForm = useForm({
    initialValues: { display_name: '' },
    validate: { display_name: (v) => (v.trim() ? null : 'مطلوب') },
  })

  async function reload() {
    setLoading(true)
    try {
      setStudents(await listStudents())
    } catch (e) {
      showError(e)
    } finally {
      setLoading(false)
    }
  }
  useEffect(() => {
    reload()
  }, [])

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    if (!q) return students
    return students.filter(
      (s) =>
        s.username.toLowerCase().includes(q) ||
        (s.display_name ?? '').toLowerCase().includes(q),
    )
  }, [students, search])

  function openCreate() {
    createForm.setValues({ username: '', display_name: '', password: generatePassword() })
    setCreateOpened(true)
  }
  function openReset(s: StudentAccount) {
    resetForm.setValues({ password: generatePassword() })
    setResetTarget(s)
  }
  function openRename(s: StudentAccount) {
    renameForm.setValues({ display_name: s.display_name ?? '' })
    setRenameTarget(s)
  }

  function confirmToggleDisabled(s: StudentAccount) {
    const disabling = !s.disabled
    modals.openConfirmModal({
      title: disabling ? 'تعطيل الحساب' : 'تفعيل الحساب',
      children: (
        <Text size="sm">
          {disabling
            ? `سيتعذّر على «${s.display_name ?? s.username}» تسجيل الدخول حتى إعادة التفعيل.`
            : `سيتمكّن «${s.display_name ?? s.username}» من تسجيل الدخول مجددًا.`}
        </Text>
      ),
      labels: { confirm: disabling ? 'تعطيل' : 'تفعيل', cancel: 'إلغاء' },
      confirmProps: { color: disabling ? 'red' : 'green' },
      onConfirm: async () => {
        try {
          await setStudentDisabled(s.id, disabling)
          await reload()
        } catch (e) {
          showError(e)
        }
      },
    })
  }

  function confirmDelete(s: StudentAccount) {
    modals.openConfirmModal({
      title: 'حذف الطالب',
      children: (
        <Text size="sm">
          هل تريد حذف حساب «{s.display_name ?? s.username}» نهائيًا؟ سيُحذف سجلّ مشاهداته
          وإنجازاته أيضًا. لا يمكن التراجع.
        </Text>
      ),
      labels: { confirm: 'حذف', cancel: 'إلغاء' },
      confirmProps: { color: 'red' },
      onConfirm: async () => {
        try {
          await deleteStudent(s.id)
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
        <Title order={2}>الطلاب</Title>
        <Button leftSection={<IconPlus size={16} />} onClick={openCreate}>
          طالب جديد
        </Button>
      </Group>

      <TextInput
        placeholder="ابحث بالاسم أو اسم المستخدم"
        leftSection={<IconSearch size={16} />}
        value={search}
        onChange={(e) => setSearch(e.currentTarget.value)}
        maw={360}
      />

      <Table striped withTableBorder>
        <Table.Thead>
          <Table.Tr>
            <Table.Th>الاسم</Table.Th>
            <Table.Th>اسم المستخدم</Table.Th>
            <Table.Th>الحالة</Table.Th>
            <Table.Th>أُنشئ في</Table.Th>
            <Table.Th>آخر دخول</Table.Th>
            <Table.Th w={170} />
          </Table.Tr>
        </Table.Thead>
        <Table.Tbody>
          {filtered.map((s) => (
            <Table.Tr key={s.id}>
              <Table.Td>{s.display_name ?? '—'}</Table.Td>
              <Table.Td>
                <Text c="dimmed">{s.username || '—'}</Text>
              </Table.Td>
              <Table.Td>
                <Badge color={s.disabled ? 'red' : 'green'} variant="light">
                  {s.disabled ? 'معطّل' : 'نشط'}
                </Badge>
              </Table.Td>
              <Table.Td>{fmtDate(s.created_at)}</Table.Td>
              <Table.Td>{fmtDate(s.last_sign_in_at)}</Table.Td>
              <Table.Td>
                <Group gap="xs" justify="flex-end" wrap="nowrap">
                  <Tooltip label="إعادة تعيين كلمة المرور">
                    <ActionIcon variant="subtle" onClick={() => openReset(s)}>
                      <IconKey size={16} />
                    </ActionIcon>
                  </Tooltip>
                  <Tooltip label="تعديل الاسم">
                    <ActionIcon variant="subtle" onClick={() => openRename(s)}>
                      <IconEdit size={16} />
                    </ActionIcon>
                  </Tooltip>
                  <Tooltip label={s.disabled ? 'تفعيل' : 'تعطيل'}>
                    <ActionIcon
                      variant="subtle"
                      color={s.disabled ? 'green' : 'orange'}
                      onClick={() => confirmToggleDisabled(s)}
                    >
                      {s.disabled ? <IconUserCheck size={16} /> : <IconUserOff size={16} />}
                    </ActionIcon>
                  </Tooltip>
                  <Tooltip label="حذف">
                    <ActionIcon variant="subtle" color="red" onClick={() => confirmDelete(s)}>
                      <IconTrash size={16} />
                    </ActionIcon>
                  </Tooltip>
                </Group>
              </Table.Td>
            </Table.Tr>
          ))}
          {!loading && filtered.length === 0 && (
            <Table.Tr>
              <Table.Td colSpan={6}>
                <Text c="dimmed" ta="center" py="md">
                  {students.length === 0 ? 'لا يوجد طلاب بعد' : 'لا نتائج مطابقة'}
                </Text>
              </Table.Td>
            </Table.Tr>
          )}
          {loading && (
            <Table.Tr>
              <Table.Td colSpan={6}>
                <Text c="dimmed" ta="center" py="md">
                  جارٍ التحميل…
                </Text>
              </Table.Td>
            </Table.Tr>
          )}
        </Table.Tbody>
      </Table>

      {/* Create */}
      <Modal opened={createOpened} onClose={() => setCreateOpened(false)} title="طالب جديد">
        <form
          onSubmit={createForm.onSubmit(async (values) => {
            const username = values.username.trim().toLowerCase()
            try {
              await createStudent({
                username,
                display_name: values.display_name.trim(),
                password: values.password,
              })
              setCreateOpened(false)
              setCredentials({ username, password: values.password })
              await reload()
            } catch (e) {
              showError(e)
            }
          })}
        >
          <Stack>
            <TextInput
              label="اسم المستخدم"
              placeholder="مثال: ahmed2024"
              description="يستخدمه الطالب لتسجيل الدخول"
              {...createForm.getInputProps('username')}
            />
            <TextInput
              label="الاسم الظاهر"
              placeholder="مثال: أحمد محمد"
              {...createForm.getInputProps('display_name')}
            />
            <TextInput
              label="كلمة المرور"
              rightSection={
                <Tooltip label="توليد كلمة مرور">
                  <ActionIcon
                    variant="subtle"
                    onClick={() => createForm.setFieldValue('password', generatePassword())}
                  >
                    <IconRefresh size={16} />
                  </ActionIcon>
                </Tooltip>
              }
              {...createForm.getInputProps('password')}
            />
            <Button type="submit">إنشاء الحساب</Button>
          </Stack>
        </form>
      </Modal>

      {/* Reset password */}
      <Modal
        opened={resetTarget !== null}
        onClose={() => setResetTarget(null)}
        title={`إعادة تعيين كلمة المرور — ${resetTarget?.display_name ?? resetTarget?.username ?? ''}`}
      >
        <form
          onSubmit={resetForm.onSubmit(async (values) => {
            if (!resetTarget) return
            try {
              await resetStudentPassword(resetTarget.id, values.password)
              const username = resetTarget.username
              setResetTarget(null)
              setCredentials({ username, password: values.password })
            } catch (e) {
              showError(e)
            }
          })}
        >
          <Stack>
            <TextInput
              label="كلمة المرور الجديدة"
              rightSection={
                <Tooltip label="توليد كلمة مرور">
                  <ActionIcon
                    variant="subtle"
                    onClick={() => resetForm.setFieldValue('password', generatePassword())}
                  >
                    <IconRefresh size={16} />
                  </ActionIcon>
                </Tooltip>
              }
              {...resetForm.getInputProps('password')}
            />
            <Button type="submit">حفظ</Button>
          </Stack>
        </form>
      </Modal>

      {/* Rename */}
      <Modal
        opened={renameTarget !== null}
        onClose={() => setRenameTarget(null)}
        title="تعديل الاسم"
      >
        <form
          onSubmit={renameForm.onSubmit(async (values) => {
            if (!renameTarget) return
            try {
              await renameStudent(renameTarget.id, values.display_name.trim())
              setRenameTarget(null)
              await reload()
              notifications.show({ color: 'green', message: 'تم التحديث' })
            } catch (e) {
              showError(e)
            }
          })}
        >
          <Stack>
            <TextInput label="الاسم الظاهر" {...renameForm.getInputProps('display_name')} />
            <Button type="submit">حفظ</Button>
          </Stack>
        </form>
      </Modal>

      {/* Credentials hand-off (after create / reset) */}
      <Modal
        opened={credentials !== null}
        onClose={() => setCredentials(null)}
        title="بيانات الدخول"
      >
        <Stack>
          <Alert color="yellow" variant="light">
            سلّم هذه البيانات للطالب. لن تظهر كلمة المرور مرّة أخرى.
          </Alert>
          <CredentialRow label="اسم المستخدم" value={credentials?.username ?? ''} />
          <CredentialRow label="كلمة المرور" value={credentials?.password ?? ''} />
          <Button onClick={() => setCredentials(null)}>تم</Button>
        </Stack>
      </Modal>
    </Stack>
  )
}

function CredentialRow({ label, value }: { label: string; value: string }) {
  return (
    <Group justify="space-between" wrap="nowrap">
      <div>
        <Text size="xs" c="dimmed">
          {label}
        </Text>
        <Text fw={600}>{value}</Text>
      </div>
      <CopyButton value={value}>
        {({ copied, copy }) => (
          <Tooltip label={copied ? 'تم النسخ' : 'نسخ'}>
            <ActionIcon variant="subtle" color={copied ? 'green' : 'gray'} onClick={copy}>
              {copied ? <IconCheck size={16} /> : <IconCopy size={16} />}
            </ActionIcon>
          </Tooltip>
        )}
      </CopyButton>
    </Group>
  )
}
