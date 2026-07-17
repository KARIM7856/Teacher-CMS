// Arabic → Latin helpers for the bulk student import.
//
// A username is: <first-name transliterated> + <5 digits deriving from the full
// name>, e.g. «عبد الله أحمد» → "abdullah14837". The teacher can edit any result
// in the import table before creating accounts, so the goal here is a sensible,
// deterministic default — not perfect romanization.
//
// Everything keys off `normalizeArabic`: we strip diacritics/tatweel, unify the
// alef/ya/hamza/ta-marbuta variants, and fold Arabic-Indic digits to Western, so
// that spelling differences (أحمد vs احمد) collapse to one form for both the
// dictionary lookup and the hash.

const TASHKEEL = /[ً-ْٰـ]/g // fathatan..sukun, superscript alef, tatweel
const ARABIC_INDIC = /[٠-٩۰-۹]/g // ٠-٩ and ۰-۹

function foldDigit(ch: string): string {
  const code = ch.charCodeAt(0)
  if (code >= 0x0660 && code <= 0x0669) return String(code - 0x0660)
  if (code >= 0x06f0 && code <= 0x06f9) return String(code - 0x06f0)
  return ch
}

// Fold Arabic-Indic (٠-٩) / Extended (۰-۹) digits to Western 0-9, leaving the
// rest of the string intact. Used when reading phone/serial cells.
export function foldArabicDigits(input: string): string {
  return (input ?? '').replace(ARABIC_INDIC, foldDigit)
}

// Canonical form used for matching + hashing. Lowercased Arabic with variants folded.
export function normalizeArabic(input: string): string {
  return (input ?? '')
    .normalize('NFKC')
    .replace(TASHKEEL, '')
    .replace(/[آأإٱ]/g, 'ا') // آأإٱ → ا
    .replace(/ى/g, 'ي') // ى → ي
    .replace(/ة/g, 'ه') // ة → ه
    .replace(/ؤ/g, 'و') // ؤ → و
    .replace(/ئ/g, 'ي') // ئ → ي
    .replace(/ء/g, '') // ء (standalone hamza) dropped
    .replace(ARABIC_INDIC, foldDigit)
    .replace(/\s+/g, ' ')
    .trim()
}

// Full compound first names (kept together, not split on the space).
const COMPOUND_NAMES_RAW: Record<string, string> = {
  'عبد الله': 'abdullah',
  'عبد الرحمن': 'abdelrahman',
  'عبد الرحيم': 'abdelrahim',
  'عبد العزيز': 'abdelaziz',
  'عبد الحميد': 'abdelhamid',
  'عبد الفتاح': 'abdelfattah',
  'عبد الناصر': 'abdelnasser',
  'عبد المنعم': 'abdelmoneim',
  'عبد الوهاب': 'abdelwahab',
  'عبد الستار': 'abdelsattar',
  'عبد المجيد': 'abdelmagid',
  'عبد اللطيف': 'abdellatif',
  'عبد الغني': 'abdelghani',
  'عبد الخالق': 'abdelkhalek',
  'عبد الرزاق': 'abdelrazek',
  'عبد السلام': 'abdelsalam',
  'عبد الحكيم': 'abdelhakim',
  'عبد الحفيظ': 'abdelhafez',
  'عبد المعطي': 'abdelmoaty',
  'عبد الباسط': 'abdelbaset',
  'ابو بكر': 'aboubakr',
  'ابو الفتوح': 'abolfotoh',
  'ابو زيد': 'abouzeid',
}

// Single-token names (first names common among Arabic — esp. Egyptian — students).
const WORD_NAMES_RAW: Record<string, string> = {
  محمد: 'mohamed',
  احمد: 'ahmed',
  محمود: 'mahmoud',
  مصطفى: 'mostafa',
  ابراهيم: 'ibrahim',
  اسلام: 'islam',
  علي: 'ali',
  حسن: 'hassan',
  حسين: 'hussein',
  عمر: 'omar',
  خالد: 'khaled',
  يوسف: 'youssef',
  كريم: 'karim',
  طارق: 'tarek',
  وليد: 'waleed',
  سامح: 'sameh',
  هاني: 'hany',
  ايمن: 'ayman',
  عماد: 'emad',
  ياسر: 'yasser',
  رامي: 'ramy',
  شريف: 'sherif',
  تامر: 'tamer',
  هشام: 'hisham',
  اشرف: 'ashraf',
  مازن: 'mazen',
  زياد: 'ziad',
  عبده: 'abdo',
  جمال: 'gamal',
  صلاح: 'salah',
  سيد: 'sayed',
  سعيد: 'saeed',
  رضا: 'reda',
  ماهر: 'maher',
  نبيل: 'nabil',
  سمير: 'samir',
  عادل: 'adel',
  فادي: 'fady',
  عمرو: 'amr',
  انس: 'anas',
  ادم: 'adam',
  حمزة: 'hamza',
  طه: 'taha',
  بلال: 'belal',
  مالك: 'malek',
  زين: 'zein',
  فارس: 'fares',
  مهند: 'mohanad',
  معاذ: 'moaz',
  اكرم: 'akram',
  باسم: 'basem',
  حاتم: 'hatem',
  خيري: 'khairy',
  رفيق: 'rafik',
  سلطان: 'sultan',
  صابر: 'saber',
  عصام: 'essam',
  فتحي: 'fathy',
  فوزي: 'fawzy',
  لؤي: 'louay',
  ناصر: 'nasser',
  نادر: 'nader',
  هيثم: 'haitham',
  وائل: 'wael',
  يحيى: 'yahia',
  يعقوب: 'yaacoub',
  مروان: 'marwan',
  سيف: 'seif',
  جاد: 'gad',
  بيتر: 'peter',
  مينا: 'mina',
  مايكل: 'michael',
  جورج: 'george',
  كيرلس: 'kirollos',
  بيشوي: 'bishoy',
  مرقس: 'marcos',
  // Female
  فاطمة: 'fatma',
  عائشة: 'aisha',
  مريم: 'mariam',
  ندى: 'nada',
  نور: 'nour',
  ايه: 'aya',
  اية: 'aya',
  سارة: 'sara',
  ساره: 'sara',
  هبة: 'heba',
  دينا: 'dina',
  ريم: 'reem',
  رنا: 'rana',
  منى: 'mona',
  هدى: 'hoda',
  امنية: 'omnia',
  اسراء: 'esraa',
  الاء: 'alaa',
  دعاء: 'doaa',
  شيماء: 'shaimaa',
  سلمى: 'salma',
  حبيبة: 'habiba',
  ملك: 'malak',
  رحمة: 'rahma',
  ياسمين: 'yasmin',
  نرمين: 'nermin',
  دنيا: 'donia',
  جنى: 'jana',
  لينا: 'lina',
  مايا: 'maya',
  رودينا: 'rodina',
  فريدة: 'farida',
  جميلة: 'gamila',
  خديجة: 'khadija',
  زينب: 'zeinab',
  اسماء: 'asmaa',
  امال: 'amal',
  هناء: 'hanaa',
  سناء: 'sanaa',
  وفاء: 'wafaa',
  نجلاء: 'naglaa',
  عبير: 'abeer',
  غادة: 'ghada',
  رانيا: 'rania',
  داليا: 'dalia',
  ايناس: 'inas',
  ايمان: 'iman',
  نهى: 'noha',
  سمر: 'samar',
  سهير: 'soheir',
  منال: 'manal',
  هالة: 'hala',
}

// Prefix name-parts that precede a definite article, romanized as one unit.
const AL = 'ال' // ال

// Per-letter fallback for words not in the dictionaries. Applied after
// normalizeArabic, so the folded forms (ا/ي/ه/و) are what we map.
const LETTER_MAP: Record<string, string> = {
  ا: 'a',
  ب: 'b',
  ت: 't',
  ث: 'th',
  ج: 'g',
  ح: 'h',
  خ: 'kh',
  د: 'd',
  ذ: 'z',
  ر: 'r',
  ز: 'z',
  س: 's',
  ش: 'sh',
  ص: 's',
  ض: 'd',
  ط: 't',
  ظ: 'z',
  ع: 'a',
  غ: 'gh',
  ف: 'f',
  ق: 'k',
  ك: 'k',
  ل: 'l',
  م: 'm',
  ن: 'n',
  ه: 'h',
  و: 'o',
  ي: 'y',
  ' ': '',
}

function transliterateWord(word: string): string {
  let out = ''
  for (const ch of word) out += LETTER_MAP[ch] ?? ''
  return out
}

const COMPOUND_NAMES = new Map(
  Object.entries(COMPOUND_NAMES_RAW).map(([k, v]) => [normalizeArabic(k), v]),
)
const WORD_NAMES = new Map(Object.entries(WORD_NAMES_RAW).map(([k, v]) => [normalizeArabic(k), v]))

// Name-parts that bind to the following word to form one first name.
const COMPOUND_HEADS = new Set(['عبد', 'ابو']) // عبد, ابو

// The first name, keeping عبد/ابو compounds together (normalized input).
function firstNameOf(normalized: string): string {
  const tokens = normalized.split(' ').filter(Boolean)
  if (tokens.length === 0) return ''
  if (tokens.length >= 2 && COMPOUND_HEADS.has(tokens[0])) {
    return `${tokens[0]} ${tokens[1]}`
  }
  return tokens[0]
}

// Romanize the (already-normalized) first name via dictionaries, else by rule.
function romanizeFirstName(firstName: string): string {
  const compound = COMPOUND_NAMES.get(firstName)
  if (compound) return compound

  const tokens = firstName.split(' ').filter(Boolean)
  if (tokens.length >= 2 && tokens[0] === 'عبد') {
    // عبد X not in the dictionary: "abd" + romanized X (dropping its ال).
    const rest = tokens[1].startsWith(AL) ? tokens[1].slice(AL.length) : tokens[1]
    return 'abd' + (WORD_NAMES.get(tokens[1]) ?? transliterateWord(rest))
  }

  const single = tokens[0] ?? ''
  return WORD_NAMES.get(single) ?? transliterateWord(single)
}

// djb2 → 5 digits. Deterministic: the same name always yields the same suffix.
function hash5(input: string): string {
  let hash = 5381
  for (let i = 0; i < input.length; i++) {
    hash = ((hash << 5) + hash + input.charCodeAt(i)) >>> 0
  }
  return String(hash % 100000).padStart(5, '0')
}

const USERNAME_MAX = 30
const SUFFIX_LEN = 5

// The suggested username for a full Arabic display name.
export function usernameFor(fullName: string): string {
  const normalized = normalizeArabic(fullName)
  const romanized = romanizeFirstName(firstNameOf(normalized)).replace(/[^a-z0-9]/g, '')
  const base = romanized || 'std'
  const suffix = hash5(normalized || fullName || 'student')
  return (base.slice(0, USERNAME_MAX - SUFFIX_LEN) + suffix).toLowerCase()
}

// Password: two lowercase letters followed by six digits (e.g. "kt481903").
// Easy to read out; unambiguous alphabet (no l/o) since the teacher dictates it.
const PW_LETTERS = 'abcdefghijkmnpqrstuvwxyz'
const PW_DIGITS = '23456789'

export function generatePassword(): string {
  const letters = new Uint32Array(2)
  const digits = new Uint32Array(6)
  crypto.getRandomValues(letters)
  crypto.getRandomValues(digits)
  const l = Array.from(letters, (v) => PW_LETTERS[v % PW_LETTERS.length]).join('')
  const d = Array.from(digits, (v) => PW_DIGITS[v % PW_DIGITS.length]).join('')
  return l + d
}
