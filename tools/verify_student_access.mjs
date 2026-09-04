// Signs in as a student and reports exactly what that account can see.
//
//   node tools/verify_student_access.mjs <username> <password>
//
// Written for one job: proving the Play reviewer account will not land in an
// empty app. "Empty catalogue" is the most common rejection for a login-gated
// educational app, and it is invisible from the admin portal — the admin bypasses
// every RLS policy, so content that looks fine to the teacher can be completely
// unreachable for a student who is in no group.
//
// This talks to Supabase as an ordinary signed-in student, so every row it counts
// has passed the same RLS policies the Flutter app is subject to. Reads only.
//
// Credentials come from app/dart_define.json (gitignored) unless SUPABASE_URL and
// SUPABASE_ANON_KEY are set in the environment. Neither the password nor the
// access token is ever printed.

import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

// Must match kStudentEmailDomain in app/lib/src/core/config/auth_config.dart and
// STUDENT_EMAIL_DOMAIN in the serverless function. If these three ever diverge,
// sign-in fails silently with "invalid credentials".
const STUDENT_EMAIL_DOMAIN = 'students.teachercms.app'

function loadConfig() {
  if (process.env.SUPABASE_URL && process.env.SUPABASE_ANON_KEY) {
    return { url: process.env.SUPABASE_URL, anonKey: process.env.SUPABASE_ANON_KEY }
  }
  try {
    const raw = JSON.parse(readFileSync(join(ROOT, 'app', 'dart_define.json'), 'utf8'))
    if (!raw.SUPABASE_URL || !raw.SUPABASE_ANON_KEY) throw new Error('incomplete')
    return { url: raw.SUPABASE_URL, anonKey: raw.SUPABASE_ANON_KEY }
  } catch {
    console.error(
      'Could not read Supabase credentials.\n' +
        'Fill in app/dart_define.json, or set SUPABASE_URL and SUPABASE_ANON_KEY.',
    )
    process.exit(1)
  }
}

/// Wraps fetch so an unreachable backend reports itself instead of dumping a
/// stack trace. A dead or renamed Supabase project shows up here first.
async function request(url, options) {
  try {
    return await fetch(url, options)
  } catch (cause) {
    const host = new URL(url).host
    console.error(`\nCannot reach ${host}.`)
    if (String(cause?.cause?.code) === 'ENOTFOUND') {
      console.error(
        '\nThe hostname does not resolve at all. Supabase gives every project its\n' +
          'own DNS record, so this usually means the project was deleted or its ref\n' +
          'changed — not that it is merely paused. Check the Supabase dashboard, then\n' +
          'update SUPABASE_URL / SUPABASE_ANON_KEY in app/dart_define.json, the admin\n' +
          "portal's Vercel env vars, and rebuild both.",
      )
    } else {
      console.error(`\n${cause?.cause?.code ?? cause?.message ?? cause}`)
    }
    process.exit(2)
  }
}

async function signIn({ url, anonKey }, username, password) {
  const response = await request(`${url}/auth/v1/token?grant_type=password`, {
    method: 'POST',
    headers: { apikey: anonKey, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: `${username.trim().toLowerCase()}@${STUDENT_EMAIL_DOMAIN}`,
      password,
    }),
  })
  const body = await response.json()
  if (!response.ok) {
    console.error(`\nSign-in failed (HTTP ${response.status}): ${body.error_description ?? body.msg ?? body.error}`)
    if (response.status === 400) {
      console.error(
        '\nUsual causes:\n' +
          '  - wrong username or password\n' +
          '  - the account was never created (the teacher creates them in الطلاب)\n' +
          '  - the account is disabled (banned) in the admin portal',
      )
    }
    process.exit(1)
  }
  return body.access_token
}

/// Counts rows the signed-in student is allowed to read. RLS does the filtering,
/// so a count of 0 is a real answer, not an error.
async function count({ url, anonKey }, token, path) {
  const response = await request(`${url}/rest/v1/${path}`, {
    headers: {
      apikey: anonKey,
      Authorization: `Bearer ${token}`,
      Prefer: 'count=exact',
      Range: '0-4',
    },
  })
  if (!response.ok) {
    return { error: `HTTP ${response.status}: ${(await response.text()).slice(0, 120)}` }
  }
  // PostgREST reports the total in Content-Range as "0-4/37".
  const total = Number((response.headers.get('content-range') ?? '').split('/')[1])
  return { total: Number.isFinite(total) ? total : 0, sample: await response.json() }
}

const [username, password] = process.argv.slice(2)
if (!username || !password) {
  console.error('Usage: node tools/verify_student_access.mjs <username> <password>')
  process.exit(1)
}

const config = loadConfig()
console.log(`Signing in as "${username}" …`)
const token = await signIn(config, username, password)
console.log('Signed in.\n')

const checks = [
  ['Categories visible', 'categories?select=id,name'],
  ['Subcategories visible', 'subcategories?select=id,name'],
  ['Published posts visible', 'posts?select=id,title&published=eq.true'],
  ['Posts with media', 'media?select=id,type'],
  ['Published playlists', 'playlists?select=id,title&published=eq.true'],
]

const results = {}
for (const [label, path] of checks) {
  const result = await count(config, token, path)
  results[label] = result
  if (result.error) {
    console.log(`  ${label.padEnd(26)} ERROR  ${result.error}`)
    continue
  }
  const names = result.sample
    .map((row) => row.name ?? row.title ?? row.type)
    .filter(Boolean)
    .slice(0, 3)
  console.log(
    `  ${label.padEnd(26)} ${String(result.total).padStart(4)}` +
      (names.length ? `   e.g. ${names.join(' · ')}` : ''),
  )
}

const posts = results['Published posts visible']?.total ?? 0
const categories = results['Categories visible']?.total ?? 0

console.log('')
if (posts > 0 && categories > 0) {
  console.log('VERDICT: this account sees content — safe to hand to a store reviewer.')
} else {
  console.log('VERDICT: this account would open to an EMPTY app.')
  console.log(
    '\nAlmost always this means the student is in no group, or their groups grant\n' +
      'no categories. Fix it in the admin portal: المجموعات (grant categories to a\n' +
      'group) then الطلاب (put this student in that group). Content visibility is\n' +
      'enforced by RLS, so the admin portal will still show everything — only this\n' +
      'check tells you what the student actually gets.',
  )
  process.exitCode = 1
}
