import { memo, useCallback, useMemo, useState } from 'react'
import {
  ActionIcon,
  Alert,
  Anchor,
  Badge,
  Button,
  Checkbox,
  Group,
  Loader,
  Paper,
  Progress,
  ScrollArea,
  Stack,
  Table,
  Text,
  TextInput,
  Title,
  Tooltip,
} from '@mantine/core'
import { modals } from '@mantine/modals'
import { notifications } from '@mantine/notifications'
import {
  IconAlertTriangle,
  IconArrowRight,
  IconCheck,
  IconFileSpreadsheet,
  IconRefresh,
  IconUpload,
  IconX,
} from '@tabler/icons-react'
import { Link } from 'react-router-dom'
import { checkUsernames, createStudent } from '../api/students'
import { listGroups } from '../api/groups'
import {
  downloadCredentialsWorkbook,
  parseWorkbook,
  type CredentialRow,
} from '../lib/studentImport'
import { generatePassword, normalizeArabic, usernameFor } from '../lib/transliterate'
import type { Group as GroupType } from '../types/database'

type RowStatus = 'pending' | 'creating' | 'created' | 'failed' | 'skipped'

interface ImportRow {
  id: string
  sheetName: string
  groupName: string // first two words of the source tab
  matchedGroupId: string | null // resolved existing group, or null if unmatched
  displayName: string
  username: string
  password: string
  phone: string // shown + exported, not stored in the DB
  parentPhone: string // exported only
  serial: string
  requestCode: string
  include: boolean
  status: RowStatus
  error?: string
}

interface SheetMeta {
  sheetName: string
  groupName: string
  matchedGroupId: string | null
  matchedGroupName: string | null
}

type Step = 'upload' | 'review' | 'running' | 'done'

function errMessage(e: unknown): string {
  return e instanceof Error ? e.message : 'حدث خطأ غير متوقّع'
}

function fileStamp(): string {
  return new Date().toISOString().slice(0, 19).replace(/[:T]/g, '-')
}

// Ensure a username is unique against everything in `taken` by bumping its 5-digit
// tail. Seeds and updates `taken` in place.
function uniquify(username: string, taken: Set<string>): string {
  if (!taken.has(username)) {
    taken.add(username)
    return username
  }
  const match = username.match(/^(.*?)(\d{5})$/)
  const base = match ? match[1] : username
  let num = match ? Number(match[2]) : 0
  for (let i = 0; i < 100000; i++) {
    num = (num + 1) % 100000
    const candidate = base + String(num).padStart(5, '0')
    if (!taken.has(candidate)) {
      taken.add(candidate)
      return candidate
    }
  }
  taken.add(username)
  return username
}

export function StudentsImportPage() {
  const [step, setStep] = useState<Step>('upload')
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [rows, setRows] = useState<ImportRow[]>([])
  const [sheets, setSheets] = useState<SheetMeta[]>([])
  // Usernames known to already exist on the server (for live conflict flagging).
  const [serverExisting, setServerExisting] = useState<Set<string>>(new Set())

  const running = step === 'running'

  const patchRow = useCallback((id: string, patch: Partial<ImportRow>) => {
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, ...patch } : r)))
  }, [])

  const regenPassword = useCallback((id: string) => {
    setRows((prev) => prev.map((r) => (r.id === id ? { ...r, password: generatePassword() } : r)))
  }, [])

  // Usernames that collide with another *included* row (case-insensitive).
  const duplicateUsernames = useMemo(() => {
    const counts = new Map<string, number>()
    for (const r of rows) {
      if (!r.include) continue
      const u = r.username.trim().toLowerCase()
      if (u) counts.set(u, (counts.get(u) ?? 0) + 1)
    }
    return new Set([...counts.entries()].filter(([, n]) => n > 1).map(([u]) => u))
  }, [rows])

  const rowsBySheet = useMemo(() => {
    const map = new Map<string, ImportRow[]>()
    for (const r of rows) {
      const list = map.get(r.sheetName) ?? []
      list.push(r)
      map.set(r.sheetName, list)
    }
    return map
  }, [rows])

  function usernameConflict(row: ImportRow): string | null {
    const u = row.username.trim().toLowerCase()
    if (!u) return 'اسم المستخدم مطلوب'
    if (serverExisting.has(u)) return 'اسم المستخدم مستخدم بالفعل على الخادم'
    if (duplicateUsernames.has(u)) return 'اسم المستخدم مكرَّر في هذا الاستيراد'
    return null
  }

  const creatable = useMemo(
    () => rows.filter((r) => r.include && r.matchedGroupId),
    [rows],
  )
  const conflictCount = useMemo(
    () => creatable.filter((r) => usernameConflict(r)).length,
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [creatable, serverExisting, duplicateUsernames],
  )
  const unmatchedSheets = useMemo(() => sheets.filter((s) => !s.matchedGroupId), [sheets])

  const doneCount = rows.filter((r) => r.status === 'created').length
  const failedCount = rows.filter((r) => r.status === 'failed').length

  // ── Upload + parse ──────────────────────────────────────────────────────────
  async function handleFile(file: File | null) {
    if (!file) return
    setBusy(true)
    setError(null)
    try {
      const buffer = await file.arrayBuffer()
      const parsed = parseWorkbook(buffer)
      if (parsed.length === 0) {
        throw new Error('لم يُعثر على أي طلاب في الملف. تأكد من وجود عمود «الاسم» وصفوف بأسماء.')
      }

      const groups = await listGroups()
      const byNormName = new Map<string, GroupType>()
      for (const g of groups) {
        const key = normalizeArabic(g.name)
        if (!byNormName.has(key)) byNormName.set(key, g)
      }

      const sheetMeta: SheetMeta[] = []
      const draft: ImportRow[] = []
      for (const sheet of parsed) {
        const matched = byNormName.get(normalizeArabic(sheet.groupName)) ?? null
        sheetMeta.push({
          sheetName: sheet.sheetName,
          groupName: sheet.groupName,
          matchedGroupId: matched?.id ?? null,
          matchedGroupName: matched?.name ?? null,
        })
        for (const row of sheet.rows) {
          draft.push({
            id: crypto.randomUUID(),
            sheetName: sheet.sheetName,
            groupName: sheet.groupName,
            matchedGroupId: matched?.id ?? null,
            displayName: row.displayName,
            username: usernameFor(row.displayName),
            password: generatePassword(),
            phone: row.phone,
            parentPhone: row.parentPhone,
            serial: row.serial,
            requestCode: row.requestCode,
            include: matched != null,
            status: matched != null ? 'pending' : 'skipped',
          })
        }
      }

      // Flag usernames already taken on the server, then de-duplicate the whole
      // batch (avoiding both server-existing names and in-batch collisions).
      let existing: string[] = []
      try {
        existing = await checkUsernames(draft.map((r) => r.username))
      } catch {
        // Non-fatal: the per-row create still rejects duplicates as a backstop.
      }
      const serverSet = new Set(existing.map((u) => u.toLowerCase()))
      const taken = new Set(serverSet)
      for (const r of draft) r.username = uniquify(r.username, taken)

      setServerExisting(serverSet)
      setSheets(sheetMeta)
      setRows(draft)
      setStep('review')
    } catch (e) {
      setError(errMessage(e))
    } finally {
      setBusy(false)
    }
  }

  // Re-resolve group matches (after the teacher creates missing groups) without
  // discarding any edits already made to the rows.
  async function rematchGroups() {
    setBusy(true)
    setError(null)
    try {
      const groups = await listGroups()
      const byNormName = new Map<string, GroupType>()
      for (const g of groups) {
        const key = normalizeArabic(g.name)
        if (!byNormName.has(key)) byNormName.set(key, g)
      }
      setSheets((prev) =>
        prev.map((s) => {
          const matched = byNormName.get(normalizeArabic(s.groupName)) ?? null
          return { ...s, matchedGroupId: matched?.id ?? null, matchedGroupName: matched?.name ?? null }
        }),
      )
      setRows((prev) =>
        prev.map((r) => {
          const matched = byNormName.get(normalizeArabic(r.groupName)) ?? null
          const nowMatched = matched?.id ?? null
          const becameMatched = nowMatched && !r.matchedGroupId
          return {
            ...r,
            matchedGroupId: nowMatched,
            include: nowMatched ? (becameMatched ? true : r.include) : false,
            status: r.status === 'created' ? r.status : nowMatched ? 'pending' : 'skipped',
          }
        }),
      )
      notifications.show({ color: 'blue', message: 'تمّت إعادة مطابقة المجموعات' })
    } catch (e) {
      setError(errMessage(e))
    } finally {
      setBusy(false)
    }
  }

  async function revalidateUsernames() {
    setBusy(true)
    try {
      const existing = await checkUsernames(rows.map((r) => r.username))
      setServerExisting(new Set(existing.map((u) => u.toLowerCase())))
      notifications.show({ color: 'blue', message: 'تمّ فحص أسماء المستخدمين' })
    } catch (e) {
      setError(errMessage(e))
    } finally {
      setBusy(false)
    }
  }

  // ── Submit: download record, then create row by row ─────────────────────────
  function confirmSubmit() {
    const toCreate = rows.filter((r) => r.include && r.matchedGroupId)
    if (toCreate.length === 0) {
      setError('لا توجد صفوف قابلة للإنشاء (تأكد من مطابقة المجموعات وتحديد الصفوف).')
      return
    }
    modals.openConfirmModal({
      title: 'إنشاء حسابات الطلاب',
      children: (
        <Stack gap="xs">
          <Text size="sm">
            سيتم أولًا تنزيل ملف Excel ببيانات الدخول (اسم المستخدم وكلمة المرور لكل طالب) —
            احتفظ به، فكلمات المرور لن تظهر مرّة أخرى. ثم تُنشأ {toCreate.length} حساب واحدًا تلو
            الآخر.
          </Text>
          {conflictCount > 0 && (
            <Text size="sm" c="red">
              تنبيه: {conflictCount} صفّ به تعارض في اسم المستخدم وقد يفشل إنشاؤه.
            </Text>
          )}
        </Stack>
      ),
      labels: { confirm: 'تنزيل وإنشاء', cancel: 'إلغاء' },
      onConfirm: () => void runCreate(toCreate),
    })
  }

  async function runCreate(toCreate: ImportRow[]) {
    // 1) Download the credentials record, grouped into worksheets per source sheet.
    const bySheet = new Map<string, CredentialRow[]>()
    for (const r of toCreate) {
      const list = bySheet.get(r.sheetName) ?? []
      list.push({
        serial: r.serial,
        requestCode: r.requestCode,
        displayName: r.displayName,
        username: r.username,
        password: r.password,
        phone: r.phone,
        parentPhone: r.parentPhone,
      })
      bySheet.set(r.sheetName, list)
    }
    try {
      downloadCredentialsWorkbook(
        [...bySheet.entries()].map(([sheetName, sheetRows]) => ({ sheetName, rows: sheetRows })),
        `students-${fileStamp()}.xlsx`,
      )
    } catch (e) {
      setError('تعذّر تنزيل ملف بيانات الدخول: ' + errMessage(e))
      return
    }

    // 2) Create each account in turn, colouring the row as we go.
    setStep('running')
    setError(null)
    for (const r of toCreate) {
      patchRow(r.id, { status: 'creating', error: undefined })
      try {
        await createStudent({
          username: r.username.trim().toLowerCase(),
          display_name: r.displayName.trim(),
          password: r.password,
          group_ids: r.matchedGroupId ? [r.matchedGroupId] : [],
          serial_number: r.serial || null,
          request_code: r.requestCode || null,
        })
        patchRow(r.id, { status: 'created' })
      } catch (e) {
        patchRow(r.id, { status: 'failed', error: errMessage(e) })
      }
    }
    setStep('done')
  }

  function reset() {
    setStep('upload')
    setRows([])
    setSheets([])
    setServerExisting(new Set())
    setError(null)
  }

  // ── Render ──────────────────────────────────────────────────────────────────
  const totalToRun = creatable.length
  const ranCount = doneCount + failedCount

  return (
    <Stack>
      <Group justify="space-between">
        <Title order={2}>استيراد الطلاب من Excel</Title>
        <Button component={Link} to="/students" variant="subtle">
          العودة إلى الطلاب
        </Button>
      </Group>

      {error && (
        <Alert color="red" variant="light" icon={<IconAlertTriangle size={16} />} withCloseButton onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {step === 'upload' && (
        <Paper withBorder p="xl">
          <Stack align="center" gap="md">
            <IconFileSpreadsheet size={48} stroke={1.3} />
            <Text ta="center" maw={520} c="dimmed">
              ارفع ملف Excel يحتوي على ورقة لكل مجموعة. أول كلمتين من اسم الورقة هما اسم المجموعة،
              ويجب أن تكون المجموعة موجودة مسبقًا في صفحة{' '}
              <Anchor component={Link} to="/groups">
                المجموعات
              </Anchor>
              . سنقرأ عمود «الاسم» وننشئ لكل طالب اسم مستخدم وكلمة مرور يمكنك تعديلهما قبل الإنشاء.
            </Text>
            <Button
              component="label"
              leftSection={<IconUpload size={16} />}
              loading={busy}
            >
              اختر ملف Excel
              <input
                type="file"
                accept=".xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
                hidden
                onChange={(e) => {
                  const file = e.currentTarget.files?.[0] ?? null
                  e.currentTarget.value = '' // allow re-selecting the same file
                  void handleFile(file)
                }}
              />
            </Button>
          </Stack>
        </Paper>
      )}

      {(step === 'review' || step === 'running' || step === 'done') && (
        <>
          <Paper withBorder p="md">
            <Group justify="space-between" wrap="wrap">
              <Group gap="xl">
                <Stat label="طلاب سيُنشأون" value={creatable.length} />
                <Stat label="مُستبعَدون (بلا مجموعة)" value={rows.length - creatable.length} />
                <Stat label="تعارض بالاسم" value={conflictCount} color={conflictCount ? 'red' : undefined} />
              </Group>
              <Group gap="xs">
                {step === 'review' && (
                  <>
                    <Button variant="default" onClick={reset} disabled={busy}>
                      ملف آخر
                    </Button>
                    <Button
                      variant="default"
                      leftSection={<IconRefresh size={16} />}
                      onClick={revalidateUsernames}
                      loading={busy}
                    >
                      فحص الأسماء
                    </Button>
                    <Button onClick={confirmSubmit} disabled={busy || creatable.length === 0}>
                      إنشاء الحسابات
                    </Button>
                  </>
                )}
                {step === 'done' && (
                  <>
                    <Button variant="default" onClick={reset}>
                      استيراد ملف آخر
                    </Button>
                    <Button component={Link} to="/students">
                      عرض الطلاب
                    </Button>
                  </>
                )}
              </Group>
            </Group>

            {(step === 'running' || step === 'done') && (
              <Stack gap={4} mt="md">
                <Progress
                  value={totalToRun ? (ranCount / totalToRun) * 100 : 0}
                  color={failedCount ? 'orange' : 'green'}
                />
                <Text size="sm" c="dimmed">
                  {step === 'done' ? 'اكتمل: ' : 'جارٍ الإنشاء: '}
                  تم إنشاء {doneCount} من {totalToRun}
                  {failedCount > 0 ? ` — فشل ${failedCount}` : ''}
                </Text>
              </Stack>
            )}
          </Paper>

          {unmatchedSheets.length > 0 && step === 'review' && (
            <Alert color="orange" variant="light" icon={<IconAlertTriangle size={16} />}>
              <Stack gap={6}>
                <Text size="sm">
                  الأوراق التالية لا تطابق أي مجموعة موجودة، وطلابها لن يُنشأوا حتى تنشئ المجموعة
                  المطابقة في صفحة{' '}
                  <Anchor component={Link} to="/groups" target="_blank">
                    المجموعات
                  </Anchor>
                  ، ثم اضغط «إعادة مطابقة المجموعات».
                </Text>
                <Group gap={6}>
                  {unmatchedSheets.map((s) => (
                    <Badge key={s.sheetName} color="orange" variant="light">
                      {s.groupName || s.sheetName}
                    </Badge>
                  ))}
                </Group>
                <Button
                  size="compact-sm"
                  variant="light"
                  color="orange"
                  leftSection={<IconRefresh size={14} />}
                  onClick={rematchGroups}
                  loading={busy}
                  w="fit-content"
                >
                  إعادة مطابقة المجموعات
                </Button>
              </Stack>
            </Alert>
          )}

          {sheets.map((sheet) => {
            const sheetRows = rowsBySheet.get(sheet.sheetName) ?? []
            return (
              <Paper key={sheet.sheetName} withBorder p="md">
                <Group justify="space-between" mb="sm" wrap="wrap">
                  <div>
                    <Text fw={600}>{sheet.sheetName}</Text>
                    {sheet.matchedGroupId ? (
                      <Badge color="green" variant="light" mt={4}>
                        المجموعة: {sheet.matchedGroupName}
                      </Badge>
                    ) : (
                      <Badge color="orange" variant="light" mt={4}>
                        لا توجد مجموعة مطابقة لـ «{sheet.groupName}»
                      </Badge>
                    )}
                  </div>
                  <Text size="sm" c="dimmed">
                    {sheetRows.length} طالب
                  </Text>
                </Group>

                <ScrollArea>
                  <Table striped withTableBorder verticalSpacing={4} miw={860}>
                    <Table.Thead>
                      <Table.Tr>
                        <Table.Th w={40} />
                        <Table.Th w={44}>الحالة</Table.Th>
                        <Table.Th miw={160}>الاسم</Table.Th>
                        <Table.Th miw={170}>اسم المستخدم</Table.Th>
                        <Table.Th miw={120}>كلمة المرور</Table.Th>
                        <Table.Th miw={120}>التليفون</Table.Th>
                        <Table.Th miw={90}>التسلسلي</Table.Th>
                        <Table.Th miw={90}>كود الطلب</Table.Th>
                      </Table.Tr>
                    </Table.Thead>
                    <Table.Tbody>
                      {sheetRows.map((row) => (
                        <ImportRowView
                          key={row.id}
                          row={row}
                          disabled={running || step === 'done'}
                          conflict={usernameConflict(row)}
                          onChange={patchRow}
                          onRegenPassword={regenPassword}
                        />
                      ))}
                    </Table.Tbody>
                  </Table>
                </ScrollArea>
              </Paper>
            )
          })}
        </>
      )}
    </Stack>
  )
}

function Stat({ label, value, color }: { label: string; value: number; color?: string }) {
  return (
    <div>
      <Text size="xs" c="dimmed">
        {label}
      </Text>
      <Text fw={700} size="lg" c={color}>
        {value}
      </Text>
    </div>
  )
}

const STATUS_BG: Record<RowStatus, string | undefined> = {
  pending: undefined,
  skipped: undefined,
  creating: 'var(--mantine-color-yellow-light)',
  created: 'var(--mantine-color-green-light)',
  failed: 'var(--mantine-color-red-light)',
}

interface RowViewProps {
  row: ImportRow
  disabled: boolean
  conflict: string | null
  onChange: (id: string, patch: Partial<ImportRow>) => void
  onRegenPassword: (id: string) => void
}

const ImportRowView = memo(function ImportRowView({
  row,
  disabled,
  conflict,
  onChange,
  onRegenPassword,
}: RowViewProps) {
  const cell = (
    field: 'displayName' | 'username' | 'password' | 'phone' | 'serial' | 'requestCode',
    extra?: { error?: boolean; rightSection?: React.ReactNode },
  ) => (
    <TextInput
      size="xs"
      variant="unstyled"
      value={row[field]}
      disabled={disabled}
      error={extra?.error}
      rightSection={extra?.rightSection}
      onChange={(e) => onChange(row.id, { [field]: e.currentTarget.value } as Partial<ImportRow>)}
    />
  )

  return (
    <Table.Tr bg={STATUS_BG[row.status]} opacity={row.include ? 1 : 0.5}>
      <Table.Td>
        <Checkbox
          checked={row.include}
          disabled={disabled || !row.matchedGroupId}
          onChange={(e) => onChange(row.id, { include: e.currentTarget.checked })}
        />
      </Table.Td>
      <Table.Td>
        <StatusIcon status={row.status} error={row.error} />
      </Table.Td>
      <Table.Td>{cell('displayName')}</Table.Td>
      <Table.Td>
        {conflict ? (
          <Tooltip label={conflict} color="red">
            {cell('username', { error: true })}
          </Tooltip>
        ) : (
          cell('username')
        )}
      </Table.Td>
      <Table.Td>
        {cell('password', {
          rightSection: (
            <Tooltip label="توليد كلمة مرور">
              <ActionIcon
                variant="subtle"
                size="sm"
                disabled={disabled}
                onClick={() => onRegenPassword(row.id)}
              >
                <IconRefresh size={14} />
              </ActionIcon>
            </Tooltip>
          ),
        })}
      </Table.Td>
      <Table.Td>{cell('phone')}</Table.Td>
      <Table.Td>{cell('serial')}</Table.Td>
      <Table.Td>{cell('requestCode')}</Table.Td>
    </Table.Tr>
  )
})

function StatusIcon({ status, error }: { status: RowStatus; error?: string }) {
  if (status === 'creating') return <Loader size="xs" />
  if (status === 'created') return <IconCheck size={18} color="var(--mantine-color-green-6)" />
  if (status === 'failed') {
    return (
      <Tooltip label={error ?? 'فشل'} color="red" multiline maw={260}>
        <IconX size={18} color="var(--mantine-color-red-6)" />
      </Tooltip>
    )
  }
  return (
    <Text c="dimmed" size="sm">
      —
    </Text>
  )
}
