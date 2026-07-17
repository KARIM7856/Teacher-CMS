// Read the teacher's roster workbook and (on submit) write the credentials record.
//
// Workbook shape (one sheet per class):
//   • The sheet TAB name's first two words are the group, e.g.
//     «تانيه اعدادى السبت الساعه 12» → group «تانيه اعدادى».
//   • A header row carries «الاسم» (name); alongside it: «الرقم التسلسلي» (serial),
//     «كود الطلب» (request code), and phone columns («تليفون الطالب» / «تليفون ولي
//     الأمر»). Student rows follow. Everything to the right (attendance grid) is
//     ignored. Sheets with no named students (blank templates) are dropped.
//
// We read cells as their *formatted* text so phone numbers keep leading zeros and
// never arrive in scientific notation ("phone represented as decimal").

import * as XLSX from 'xlsx'
import { foldArabicDigits, normalizeArabic } from './transliterate'

export interface ParsedStudentRow {
  displayName: string
  phone: string
  parentPhone: string
  serial: string
  requestCode: string
}

export interface ParsedSheet {
  sheetName: string
  groupName: string // first two words of the tab name (raw, for display)
  rows: ParsedStudentRow[]
}

// First two whitespace-separated words of a sheet tab — the group name.
export function groupNameFromSheet(sheetName: string): string {
  return sheetName.trim().split(/\s+/).slice(0, 2).join(' ')
}

// A phone/serial cell as a plain decimal string: fold Arabic digits, and if Excel
// handed us a float/scientific form, render it as a whole number.
function toDecimalString(value: unknown): string {
  if (value === null || value === undefined) return ''
  let text = foldArabicDigits(String(value)).trim()
  if (!text) return ''
  if (/[eE]/.test(text) || /^\d+\.\d+$/.test(text)) {
    const n = Number(text)
    if (Number.isFinite(n)) {
      text = n.toLocaleString('en-US', { useGrouping: false, maximumFractionDigits: 0 })
    }
  }
  return text
}

function cellText(value: unknown): string {
  if (value === null || value === undefined) return ''
  return String(value).trim()
}

const MAX_HEADER_SCAN = 15

// Locate the header row + the column index of each field we care about.
function locateColumns(rows: string[][]) {
  for (let r = 0; r < Math.min(rows.length, MAX_HEADER_SCAN); r++) {
    const row = rows[r]
    let name = -1
    let serial = -1
    let request = -1
    let phone = -1
    let parentPhone = -1
    for (let c = 0; c < row.length; c++) {
      const h = normalizeArabic(row[c])
      if (!h) continue
      const phoneish =
        h.includes('تليفون') ||
        h.includes('تلفون') ||
        h.includes('هاتف') ||
        h.includes('موبايل') ||
        h.includes('محمول')
      if (h.includes('الاسم') && name < 0) name = c
      else if (h.includes('تسلسل') && serial < 0) serial = c
      else if ((h.includes('كود') || h.includes('الطلب')) && request < 0) request = c
      else if (phoneish && (h.includes('طالب') || h.includes('الطالب'))) phone = c
      else if (phoneish && (h.includes('امر') || h.includes('ولي'))) parentPhone = c
      else if (phoneish && phone < 0) phone = c
    }
    if (name >= 0) return { headerRow: r, name, serial, request, phone, parentPhone }
  }
  return null
}

// Parse a workbook into per-sheet student lists. Empty sheets are skipped.
export function parseWorkbook(data: ArrayBuffer): ParsedSheet[] {
  const wb = XLSX.read(data, { type: 'array' })
  const sheets: ParsedSheet[] = []

  for (const sheetName of wb.SheetNames) {
    const ws = wb.Sheets[sheetName]
    if (!ws) continue
    // raw:false → formatted text (keeps phone leading zeros, no scientific form).
    const rows = XLSX.utils.sheet_to_json<string[]>(ws, {
      header: 1,
      raw: false,
      defval: '',
      blankrows: false,
    })
    const cols = locateColumns(rows)
    if (!cols) continue

    const parsed: ParsedStudentRow[] = []
    for (let r = cols.headerRow + 1; r < rows.length; r++) {
      const row = rows[r]
      const displayName = cellText(row[cols.name])
      if (!displayName) continue
      if (normalizeArabic(displayName) === 'الاسم') continue // stray repeated header

      parsed.push({
        displayName,
        phone: cols.phone >= 0 ? toDecimalString(row[cols.phone]) : '',
        parentPhone: cols.parentPhone >= 0 ? toDecimalString(row[cols.parentPhone]) : '',
        serial: cols.serial >= 0 ? toDecimalString(row[cols.serial]) : '',
        requestCode: cols.request >= 0 ? toDecimalString(row[cols.request]) : '',
      })
    }

    if (parsed.length === 0) continue // blank template / non-roster sheet
    sheets.push({ sheetName, groupName: groupNameFromSheet(sheetName), rows: parsed })
  }

  return sheets
}

// ── Credentials record (downloaded on submit) ─────────────────────────────────

export interface CredentialRow {
  serial: string
  requestCode: string
  displayName: string
  username: string
  password: string
  phone: string
  parentPhone: string
}

export interface CredentialSheet {
  sheetName: string
  rows: CredentialRow[]
}

const EXPORT_HEADERS = [
  'الرقم التسلسلي',
  'كود الطلب',
  'الاسم',
  'اسم المستخدم',
  'كلمة المرور',
  'تليفون الطالب',
  'تليفون ولي الأمر',
]

// Excel forbids []:*?/\\ in tab names and caps them at 31 chars; also no dupes.
function safeSheetName(name: string, used: Set<string>): string {
  let base = (name || 'ورقة').replace(/[[\]:*?/\\]/g, ' ').trim().slice(0, 31) || 'ورقة'
  let candidate = base
  let n = 2
  while (used.has(candidate)) {
    const suffix = ` ${n++}`
    candidate = base.slice(0, 31 - suffix.length) + suffix
  }
  used.add(candidate)
  return candidate
}

// Build the workbook (one worksheet per source sheet) and trigger a download.
export function downloadCredentialsWorkbook(sheets: CredentialSheet[], fileName: string): void {
  const wb = XLSX.utils.book_new()
  const used = new Set<string>()
  for (const sheet of sheets) {
    const aoa = [
      EXPORT_HEADERS,
      ...sheet.rows.map((r) => [
        r.serial,
        r.requestCode,
        r.displayName,
        r.username,
        r.password,
        r.phone,
        r.parentPhone,
      ]),
    ]
    const ws = XLSX.utils.aoa_to_sheet(aoa)
    ws['!cols'] = [
      { wch: 12 },
      { wch: 12 },
      { wch: 26 },
      { wch: 20 },
      { wch: 14 },
      { wch: 16 },
      { wch: 16 },
    ]
    // Match the source: render the sheet right-to-left.
    ws['!views'] = [{ RTL: true }]
    XLSX.utils.book_append_sheet(wb, ws, safeSheetName(sheet.sheetName, used))
  }
  XLSX.writeFile(wb, fileName)
}
