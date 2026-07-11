// Client wrappers for the /api/students serverless function. Unlike the other api
// modules (which hit Supabase directly with the anon key), student management needs
// the service_role key, so it goes through our own server function. We forward the
// signed-in admin's JWT so the function can verify the caller is an admin.

import { supabase } from '../lib/supabase'
import type { StudentAccount } from '../types/database'

async function callStudentsApi<T>(
  action: string,
  payload: Record<string, unknown> = {},
): Promise<T> {
  const { data } = await supabase.auth.getSession()
  const token = data.session?.access_token
  if (!token) throw new Error('انتهت الجلسة، سجّل الدخول من جديد')

  const res = await fetch('/api/students', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
    body: JSON.stringify({ action, ...payload }),
  })
  const json = (await res.json().catch(() => ({}))) as { error?: string } & T
  if (!res.ok) throw new Error(json?.error ?? 'حدث خطأ في الخادم')
  return json
}

export async function listStudents(): Promise<StudentAccount[]> {
  const { students } = await callStudentsApi<{ students: StudentAccount[] }>('list')
  return students
}

export async function createStudent(input: {
  username: string
  display_name: string
  password: string
  group_ids?: string[]
}): Promise<{ id: string; username: string }> {
  return callStudentsApi('create', input)
}

// Replace a student's group memberships with exactly [groupIds] (empty clears them).
export async function setStudentGroups(userId: string, groupIds: string[]): Promise<void> {
  await callStudentsApi('set_groups', { user_id: userId, group_ids: groupIds })
}

export async function resetStudentPassword(userId: string, password: string): Promise<void> {
  await callStudentsApi('reset_password', { user_id: userId, password })
}

export async function renameStudent(userId: string, displayName: string): Promise<void> {
  await callStudentsApi('rename', { user_id: userId, display_name: displayName })
}

export async function setStudentDisabled(userId: string, disabled: boolean): Promise<void> {
  await callStudentsApi('set_disabled', { user_id: userId, disabled })
}

export async function deleteStudent(userId: string): Promise<void> {
  await callStudentsApi('delete', { user_id: userId })
}
