// Serverless function: student-account management for the teacher (admin).
//
// The student sign-up flow is gone — the teacher creates every account here. That
// requires Supabase's `service_role` key, which must NEVER reach the browser, so it
// lives only in this server-side function (env: SUPABASE_SERVICE_ROLE_KEY).
//
// Students log in with a *username*; there is no email. We map each username to a
// deterministic synthetic email `<username>@<STUDENT_EMAIL_DOMAIN>` so Supabase Auth
// (which is email-based) still works. That same domain constant must be mirrored in
// the Flutter app (kStudentEmailDomain) so its login screen builds the same address.
//
// Every request is gated: the caller must present their own admin JWT, and we verify
// their profiles.role is 'admin' before doing anything. Mutations additionally refuse
// to touch any account that isn't a student (so the admin can't be modified here).
//
// Using the Admin API (auth.admin.createUser) — rather than a manual SQL insert —
// also avoids the NULL-token login-500 bug: GoTrue writes the token columns as ''.

import type { VercelRequest, VercelResponse } from '@vercel/node'
import { createClient, type SupabaseClient } from '@supabase/supabase-js'

const SUPABASE_URL = process.env.SUPABASE_URL
const SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
const STUDENT_EMAIL_DOMAIN = process.env.STUDENT_EMAIL_DOMAIN

// Small typed error so action handlers can bail out with a status + Arabic message.
class HttpError extends Error {
  constructor(public status: number, message: string) {
    super(message)
  }
}

const USERNAME_RE = /^[a-z0-9._-]{3,30}$/

function normalizeUsername(raw: unknown): string {
  const username = String(raw ?? '').trim().toLowerCase()
  if (!USERNAME_RE.test(username)) {
    throw new HttpError(
      400,
      'اسم المستخدم غير صالح (أحرف إنجليزية وأرقام و . _ - فقط، من 3 إلى 30 خانة)',
    )
  }
  return username
}

function requirePassword(raw: unknown): string {
  if (typeof raw !== 'string' || raw.length < 6) {
    throw new HttpError(400, 'كلمة المرور يجب ألا تقل عن 6 خانات')
  }
  return raw
}

function requireDisplayName(raw: unknown): string {
  const name = String(raw ?? '').trim()
  if (!name) throw new HttpError(400, 'الاسم مطلوب')
  return name
}

function requireUserId(raw: unknown): string {
  const id = String(raw ?? '').trim()
  if (!id) throw new HttpError(400, 'مُعرّف الطالب مطلوب')
  return id
}

// A guard for mutations: never let this endpoint alter a non-student (e.g. the admin).
async function assertTargetIsStudent(admin: SupabaseClient, userId: string): Promise<void> {
  const { data, error } = await admin
    .from('profiles')
    .select('role')
    .eq('id', userId)
    .single()
  if (error || !data) throw new HttpError(404, 'الطالب غير موجود')
  if (data.role !== 'student') throw new HttpError(403, 'لا يمكن تعديل هذا الحساب')
}

// Optional list of group ids (deduped). Used on create and set_groups. Group
// definitions live in the `groups` table, managed directly from the SPA.
function parseGroupIds(raw: unknown): string[] {
  if (raw == null) return []
  if (!Array.isArray(raw)) throw new HttpError(400, 'قائمة المجموعات غير صالحة')
  const ids = raw.map((v) => String(v ?? '').trim()).filter(Boolean)
  return Array.from(new Set(ids))
}

// Optional free-form roster text (Excel import: serial number / request code).
// Trimmed; an empty value becomes null so we never overwrite with blanks.
function parseOptionalText(raw: unknown): string | null {
  const value = String(raw ?? '').trim()
  return value ? value : null
}

// Deduped, lowercased list of usernames to check for existence.
function parseUsernameList(raw: unknown): string[] {
  if (!Array.isArray(raw)) throw new HttpError(400, 'قائمة أسماء المستخدمين غير صالحة')
  const names = raw.map((v) => String(v ?? '').trim().toLowerCase()).filter(Boolean)
  return Array.from(new Set(names))
}

// Replace a student's group memberships with exactly [groupIds] (empty clears them).
async function replaceMemberships(
  admin: SupabaseClient,
  userId: string,
  groupIds: string[],
): Promise<void> {
  const { error: delError } = await admin
    .from('group_members')
    .delete()
    .eq('student_id', userId)
  if (delError) throw new HttpError(400, delError.message)
  if (groupIds.length === 0) return
  const rows = groupIds.map((group_id) => ({ group_id, student_id: userId }))
  const { error: insError } = await admin.from('group_members').insert(rows)
  // A bad/unknown group id trips the FK — report it rather than 500.
  if (insError) throw new HttpError(400, 'تعذّر تعيين المجموعات: ' + insError.message)
}

// ── Actions ──────────────────────────────────────────────────────────────────────

async function listStudents(admin: SupabaseClient) {
  // profiles is the source of truth for who is a student and for display_name.
  const { data: profiles, error: profilesError } = await admin
    .from('profiles')
    .select('id, role, display_name, serial_number, request_code')
  if (profilesError) throw new HttpError(500, profilesError.message)
  const byId = new Map(profiles.map((p) => [p.id, p]))

  // Group memberships, resolved to {id, name} per student.
  const { data: groupRows, error: groupsError } = await admin.from('groups').select('id, name')
  if (groupsError) throw new HttpError(500, groupsError.message)
  const groupName = new Map((groupRows ?? []).map((g) => [g.id as string, g.name as string]))
  const { data: memberships, error: membersError } = await admin
    .from('group_members')
    .select('group_id, student_id')
  if (membersError) throw new HttpError(500, membersError.message)
  const groupsByStudent = new Map<string, Array<{ id: string; name: string }>>()
  for (const m of memberships ?? []) {
    const name = groupName.get(m.group_id as string)
    if (!name) continue
    const list = groupsByStudent.get(m.student_id as string) ?? []
    list.push({ id: m.group_id as string, name })
    groupsByStudent.set(m.student_id as string, list)
  }

  // Page through auth users to enrich with username / timestamps / ban status.
  const students: Array<{
    id: string
    username: string
    display_name: string | null
    serial_number: string | null
    request_code: string | null
    created_at: string
    last_sign_in_at: string | null
    disabled: boolean
    groups: Array<{ id: string; name: string }>
  }> = []
  const perPage = 1000
  for (let page = 1; ; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage })
    if (error) throw new HttpError(500, error.message)
    for (const user of data.users) {
      const profile = byId.get(user.id)
      if (!profile || profile.role !== 'student') continue
      const bannedUntil = (user as { banned_until?: string }).banned_until
      students.push({
        id: user.id,
        username: (user.user_metadata?.username as string | undefined) ?? '',
        display_name:
          profile.display_name ??
          ((user.user_metadata?.display_name as string | undefined) ?? null),
        serial_number: (profile as { serial_number?: string | null }).serial_number ?? null,
        request_code: (profile as { request_code?: string | null }).request_code ?? null,
        created_at: user.created_at,
        last_sign_in_at: user.last_sign_in_at ?? null,
        disabled: bannedUntil ? new Date(bannedUntil).getTime() > Date.now() : false,
        groups: groupsByStudent.get(user.id) ?? [],
      })
    }
    if (data.users.length < perPage) break
  }

  students.sort((a, b) => (a.created_at < b.created_at ? 1 : -1))
  return { students }
}

async function createStudent(admin: SupabaseClient, body: Record<string, unknown>) {
  const username = normalizeUsername(body.username)
  const password = requirePassword(body.password)
  const displayName = String(body.display_name ?? '').trim() || username
  const groupIds = parseGroupIds(body.group_ids)
  const email = `${username}@${STUDENT_EMAIL_DOMAIN}`

  const { data, error } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true, // admin-created; no verification email, never a NULL-token 500
    user_metadata: { username, display_name: displayName },
  })
  if (error) {
    const taken = /already been registered|already exists|duplicate/i.test(error.message)
    throw new HttpError(taken ? 409 : 400, taken ? 'اسم المستخدم مستخدم بالفعل' : error.message)
  }
  // on_auth_user_created trigger creates the profiles row (role 'student',
  // display_name pulled from user_metadata) synchronously, so the FK on
  // group_members is satisfiable by the time we assign groups.
  if (groupIds.length > 0) await replaceMemberships(admin, data.user.id, groupIds)

  // Optional roster fields from an Excel import. Patch only what was supplied so
  // a partial import never blanks an already-set column.
  const patch: Record<string, string> = {}
  const serialNumber = parseOptionalText(body.serial_number)
  const requestCode = parseOptionalText(body.request_code)
  if (serialNumber !== null) patch.serial_number = serialNumber
  if (requestCode !== null) patch.request_code = requestCode
  if (Object.keys(patch).length > 0) {
    const { error: profileError } = await admin
      .from('profiles')
      .update(patch)
      .eq('id', data.user.id)
    if (profileError) throw new HttpError(400, profileError.message)
  }
  return { id: data.user.id, username }
}

// Bulk existence check for the Excel import: which of these usernames are already
// taken? Read-only, so it only needs the admin gate the handler already applies.
async function checkUsernames(admin: SupabaseClient, body: Record<string, unknown>) {
  const requested = parseUsernameList(body.usernames)
  if (requested.length === 0) return { existing: [] }

  const taken = new Set<string>()
  const perPage = 1000
  for (let page = 1; ; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage })
    if (error) throw new HttpError(500, error.message)
    for (const user of data.users) {
      const uname = (user.user_metadata?.username as string | undefined)?.toLowerCase()
      if (uname) taken.add(uname)
      // Fallback to the synthetic email's local part in case metadata is missing.
      const local = (user.email ?? '').split('@')[0]?.toLowerCase()
      if (local) taken.add(local)
    }
    if (data.users.length < perPage) break
  }
  return { existing: requested.filter((u) => taken.has(u)) }
}

async function setGroups(admin: SupabaseClient, body: Record<string, unknown>) {
  const userId = requireUserId(body.user_id)
  const groupIds = parseGroupIds(body.group_ids)
  await assertTargetIsStudent(admin, userId)
  await replaceMemberships(admin, userId, groupIds)
  return { ok: true }
}

async function resetPassword(admin: SupabaseClient, body: Record<string, unknown>) {
  const userId = requireUserId(body.user_id)
  const password = requirePassword(body.password)
  await assertTargetIsStudent(admin, userId)
  const { error } = await admin.auth.admin.updateUserById(userId, { password })
  if (error) throw new HttpError(400, error.message)
  return { ok: true }
}

async function renameStudent(admin: SupabaseClient, body: Record<string, unknown>) {
  const userId = requireUserId(body.user_id)
  const displayName = requireDisplayName(body.display_name)
  await assertTargetIsStudent(admin, userId)

  // profiles.display_name is what the app + this list read; keep auth metadata in
  // sync too, merging so the username stays intact.
  const { data: existing } = await admin.auth.admin.getUserById(userId)
  const metadata = { ...(existing?.user?.user_metadata ?? {}), display_name: displayName }
  const { error: authError } = await admin.auth.admin.updateUserById(userId, {
    user_metadata: metadata,
  })
  if (authError) throw new HttpError(400, authError.message)
  const { error: profileError } = await admin
    .from('profiles')
    .update({ display_name: displayName })
    .eq('id', userId)
  if (profileError) throw new HttpError(400, profileError.message)
  return { ok: true }
}

async function setDisabled(admin: SupabaseClient, body: Record<string, unknown>) {
  const userId = requireUserId(body.user_id)
  const disabled = Boolean(body.disabled)
  await assertTargetIsStudent(admin, userId)
  // Ban ≈ block login without deleting the account or its history. 'none' unbans.
  const { error } = await admin.auth.admin.updateUserById(userId, {
    ban_duration: disabled ? '876000h' : 'none',
  })
  if (error) throw new HttpError(400, error.message)
  return { ok: true }
}

async function deleteStudent(admin: SupabaseClient, body: Record<string, unknown>) {
  const userId = requireUserId(body.user_id)
  await assertTargetIsStudent(admin, userId)
  const { error } = await admin.auth.admin.deleteUser(userId)
  if (error) throw new HttpError(400, error.message)
  return { ok: true }
}

// ── Handler ──────────────────────────────────────────────────────────────────────

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'method not allowed' })
  }
  if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !STUDENT_EMAIL_DOMAIN) {
    return res.status(500).json({
      error:
        'الخادم غير مُهيّأ: SUPABASE_URL و SUPABASE_SERVICE_ROLE_KEY و STUDENT_EMAIL_DOMAIN مطلوبة',
    })
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  try {
    // Gate: the caller must be an authenticated admin.
    const token = (req.headers.authorization ?? '').replace(/^Bearer\s+/i, '')
    if (!token) throw new HttpError(401, 'غير مصرّح')
    const { data: caller, error: callerError } = await admin.auth.getUser(token)
    if (callerError || !caller?.user) throw new HttpError(401, 'جلسة غير صالحة')
    const { data: callerProfile } = await admin
      .from('profiles')
      .select('role')
      .eq('id', caller.user.id)
      .single()
    if (callerProfile?.role !== 'admin') throw new HttpError(403, 'صلاحيات المشرف مطلوبة')

    const body = (req.body ?? {}) as Record<string, unknown>
    const action = String(body.action ?? '')

    switch (action) {
      case 'list':
        return res.status(200).json(await listStudents(admin))
      case 'create':
        return res.status(200).json(await createStudent(admin, body))
      case 'check_usernames':
        return res.status(200).json(await checkUsernames(admin, body))
      case 'reset_password':
        return res.status(200).json(await resetPassword(admin, body))
      case 'rename':
        return res.status(200).json(await renameStudent(admin, body))
      case 'set_groups':
        return res.status(200).json(await setGroups(admin, body))
      case 'set_disabled':
        return res.status(200).json(await setDisabled(admin, body))
      case 'delete':
        return res.status(200).json(await deleteStudent(admin, body))
      default:
        throw new HttpError(400, `إجراء غير معروف: ${action}`)
    }
  } catch (err) {
    if (err instanceof HttpError) return res.status(err.status).json({ error: err.message })
    const message = err instanceof Error ? err.message : 'خطأ غير متوقّع'
    return res.status(500).json({ error: message })
  }
}
