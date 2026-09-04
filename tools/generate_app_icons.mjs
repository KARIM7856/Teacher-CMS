// Generates every launcher/store icon for the student app from one description,
// so the art stays reproducible and tweakable in-repo instead of being a set of
// opaque binaries. No dependencies: PNGs are encoded with node's own zlib.
//
//   node tools/generate_app_icons.mjs
//
// Writes:
//   app/android/.../mipmap-*/          legacy, round, adaptive fg/bg, monochrome
//   app/ios/Runner/Assets.xcassets/    every size AppIcon's Contents.json lists
//   store/assets/                      Play 512 icon + feature graphic, App Store 1024
//
// Design: a white open book on a warm orange gradient (the app's seed colour,
// AppColors.seed) with a teal sparkle (AppColors.accent). Deliberately one bold
// shape — it has to stay readable at 48px on a home screen.

import { deflateSync } from 'node:zlib'
import { mkdirSync, writeFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

// PNG encoding ────────────────────────────────────────────────────────────────
const CRC_TABLE = (() => {
  const table = new Int32Array(256)
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1
    table[n] = c
  }
  return table
})()

function crc32(buffer) {
  let c = 0xffffffff
  for (const byte of buffer) c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8)
  return (c ^ 0xffffffff) >>> 0
}

function chunk(type, data) {
  const length = Buffer.alloc(4)
  length.writeUInt32BE(data.length)
  const typed = Buffer.concat([Buffer.from(type, 'ascii'), data])
  const crc = Buffer.alloc(4)
  crc.writeUInt32BE(crc32(typed))
  return Buffer.concat([length, typed, crc])
}

/// Encodes raw RGBA into a PNG. `withAlpha: false` drops the alpha channel and
/// composites onto `flatten` — an App Store icon with an alpha channel is
/// rejected at upload.
function encodePng(width, height, rgba, { withAlpha = true, flatten = [255, 255, 255] } = {}) {
  const channels = withAlpha ? 4 : 3
  const stride = width * channels
  const raw = Buffer.alloc((stride + 1) * height)
  for (let y = 0; y < height; y++) {
    raw[y * (stride + 1)] = 0 // filter: none
    for (let x = 0; x < width; x++) {
      const src = (y * width + x) * 4
      const dst = y * (stride + 1) + 1 + x * channels
      const alpha = rgba[src + 3] / 255
      for (let c = 0; c < 3; c++) {
        raw[dst + c] = withAlpha
          ? rgba[src + c]
          : Math.round(rgba[src + c] * alpha + flatten[c] * (1 - alpha))
      }
      if (withAlpha) raw[dst + 3] = rgba[src + 3]
    }
  }
  const ihdr = Buffer.alloc(13)
  ihdr.writeUInt32BE(width, 0)
  ihdr.writeUInt32BE(height, 4)
  ihdr[8] = 8 // bit depth
  ihdr[9] = withAlpha ? 6 : 2 // colour type: RGBA / RGB
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ])
}

// Palette ─────────────────────────────────────────────────────────────────────
const GRADIENT_TOP = [0xff, 0xa0, 0x6b]
const GRADIENT_BOTTOM = [0xe4, 0x55, 0x1f]
const PAGE_NEAR = [0xff, 0xff, 0xff]
const PAGE_FAR = [0xff, 0xf1, 0xe4] // the far page, a touch warmer, reads as depth
const CREASE = [0xe8, 0xcd, 0xba]
const SPARKLE = [0x2a, 0x9d, 0x8f]

const lerp = (a, b, t) => a + (b - a) * t
const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v)

// Geometry, in a [-1,1] square ────────────────────────────────────────────────
function insideRoundedSquare(u, v, half, radius) {
  const dx = Math.abs(u) - (half - radius)
  const dy = Math.abs(v) - (half - radius)
  if (dx <= 0 || dy <= 0) return Math.abs(u) <= half && Math.abs(v) <= half
  return dx * dx + dy * dy <= radius * radius
}

// One page of the open book, mirrored by `side`. The top edge lifts and the
// bottom edge rises as you move outward, which is what makes it read as pages
// fanning open rather than as a plain rectangle.
function insidePage(u, v, side, scale) {
  const x = (u / scale) * side
  const y = v / scale
  if (x < 0.045 || x > 0.72) return false
  const t = (x - 0.045) / (0.72 - 0.045)
  const ease = t * t * (3 - 2 * t)
  const top = lerp(-0.3, -0.44, ease)
  const bottom = lerp(0.44, 0.3, ease)
  return y >= top && y <= bottom
}

// A four-pointed sparkle. The astroid |x|^(2/3)+|y|^(2/3) <= r^(2/3) has concave
// sides and sharp points, which stays legible when tiny.
function insideSparkle(u, v, cx, cy, r) {
  const dx = Math.abs(u - cx)
  const dy = Math.abs(v - cy)
  if (dx > r || dy > r) return false
  return Math.cbrt(dx * dx) + Math.cbrt(dy * dy) <= Math.cbrt(r * r)
}

/// Colour of a single sample, or null for transparent. `mode` picks which layers
/// are drawn — see the callers below.
function sample(u, v, mode, artScale) {
  const drawsBackground =
    mode === 'full' || mode === 'rounded' || mode === 'round' || mode === 'background'
  const drawsArt = mode !== 'background'

  if (mode === 'rounded' && !insideRoundedSquare(u, v, 1, 0.44)) return null
  if (mode === 'round' && u * u + v * v > 1) return null

  if (drawsArt) {
    const s = artScale
    if (insideSparkle(u, v, 0.52 * s, -0.6 * s, 0.17 * s)) {
      return mode === 'monochrome' ? [255, 255, 255] : SPARKLE
    }
    // The crease is its own sliver between the two pages, so they stay distinct
    // without an outline — an outline thickens and muddies at small sizes.
    const nearCrease = Math.abs(u) < 0.045 * s && Math.abs(v) < 0.46 * s
    if (nearCrease && insidePage(Math.abs(u) + 0.05 * s, v, 1, s)) {
      return mode === 'monochrome' ? [255, 255, 255] : CREASE
    }
    if (insidePage(u, v, 1, s)) return mode === 'monochrome' ? [255, 255, 255] : PAGE_NEAR
    if (insidePage(u, v, -1, s)) return mode === 'monochrome' ? [255, 255, 255] : PAGE_FAR
  }

  if (!drawsBackground) return null
  const t = clamp01((v + 1) / 2)
  return [
    Math.round(lerp(GRADIENT_TOP[0], GRADIENT_BOTTOM[0], t)),
    Math.round(lerp(GRADIENT_TOP[1], GRADIENT_BOTTOM[1], t)),
    Math.round(lerp(GRADIENT_TOP[2], GRADIENT_BOTTOM[2], t)),
  ]
}

/// Renders `size`x`size` RGBA with 4x4 supersampling. The shapes are hard-edged,
/// so the anti-aliasing has to come from sampling rather than from the maths.
///
/// `zoom` shrinks the sampled area, which is how the adaptive-icon preview
/// reproduces what a launcher actually shows: it crops the 108dp layer to the
/// central 72dp (66.7%) and scales that up.
function render(size, mode, { artScale = 1, aspect = 1, zoom = 1 } = {}) {
  const width = Math.round(size * aspect)
  const height = size
  const out = Buffer.alloc(width * height * 4)
  const SS = 4
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      let r = 0
      let g = 0
      let b = 0
      let covered = 0
      for (let sy = 0; sy < SS; sy++) {
        for (let sx = 0; sx < SS; sx++) {
          const u = (((x + (sx + 0.5) / SS) / width) * 2 - 1) * zoom
          const v = (((y + (sy + 0.5) / SS) / height) * 2 - 1) * zoom
          const c = sample(u * aspect, v, mode, artScale)
          if (c) {
            r += c[0]
            g += c[1]
            b += c[2]
            covered++
          }
        }
      }
      const i = (y * width + x) * 4
      if (covered > 0) {
        out[i] = Math.round(r / covered)
        out[i + 1] = Math.round(g / covered)
        out[i + 2] = Math.round(b / covered)
      }
      out[i + 3] = Math.round((covered / (SS * SS)) * 255)
    }
  }
  return { width, height, data: out }
}

function write(relativePath, size, mode, options = {}) {
  const { withAlpha = true, ...renderOptions } = options
  const { width, height, data } = render(size, mode, renderOptions)
  const file = join(ROOT, relativePath)
  mkdirSync(dirname(file), { recursive: true })
  writeFileSync(file, encodePng(width, height, data, { withAlpha }))
  console.log(`  ${relativePath}  ${width}x${height}${withAlpha ? '' : ' (no alpha)'}`)
}

// Android ─────────────────────────────────────────────────────────────────────
// Legacy icons carry their own rounded/circular mask; adaptive layers are drawn
// on the full 108dp canvas, of which only the middle ~66% is guaranteed visible,
// so the art is scaled to sit inside that safe zone.
const ANDROID_RES = 'app/android/app/src/main/res'
const DENSITIES = [
  ['mdpi', 48],
  ['hdpi', 72],
  ['xhdpi', 96],
  ['xxhdpi', 144],
  ['xxxhdpi', 192],
]
const ADAPTIVE_SAFE_SCALE = 0.62

console.log('Android launcher icons:')
for (const [density, px] of DENSITIES) {
  write(`${ANDROID_RES}/mipmap-${density}/ic_launcher.png`, px, 'rounded')
  write(`${ANDROID_RES}/mipmap-${density}/ic_launcher_round.png`, px, 'round')
  const adaptive = Math.round((px * 108) / 48)
  write(`${ANDROID_RES}/mipmap-${density}/ic_launcher_foreground.png`, adaptive, 'foreground', {
    artScale: ADAPTIVE_SAFE_SCALE,
  })
  write(`${ANDROID_RES}/mipmap-${density}/ic_launcher_background.png`, adaptive, 'background')
  write(`${ANDROID_RES}/mipmap-${density}/ic_launcher_monochrome.png`, adaptive, 'monochrome', {
    artScale: ADAPTIVE_SAFE_SCALE,
  })
}

// iOS ─────────────────────────────────────────────────────────────────────────
// Full-bleed squares with no alpha: iOS applies the corner mask itself, and an
// alpha channel on the 1024 marketing icon fails App Store validation.
const IOS_ICONS = 'app/ios/Runner/Assets.xcassets/AppIcon.appiconset'
const IOS_SIZES = [
  ['Icon-App-20x20@1x.png', 20],
  ['Icon-App-20x20@2x.png', 40],
  ['Icon-App-20x20@3x.png', 60],
  ['Icon-App-29x29@1x.png', 29],
  ['Icon-App-29x29@2x.png', 58],
  ['Icon-App-29x29@3x.png', 87],
  ['Icon-App-40x40@1x.png', 40],
  ['Icon-App-40x40@2x.png', 80],
  ['Icon-App-40x40@3x.png', 120],
  ['Icon-App-60x60@2x.png', 120],
  ['Icon-App-60x60@3x.png', 180],
  ['Icon-App-76x76@1x.png', 76],
  ['Icon-App-76x76@2x.png', 152],
  ['Icon-App-83.5x83.5@2x.png', 167],
  ['Icon-App-1024x1024@1x.png', 1024],
]

console.log('iOS app icons:')
for (const [name, px] of IOS_SIZES) {
  write(`${IOS_ICONS}/${name}`, px, 'full', { withAlpha: false })
}

// Store listing assets ────────────────────────────────────────────────────────
console.log('Store assets:')
write('store/assets/play-icon-512.png', 512, 'full', { withAlpha: false })
write('store/assets/appstore-icon-1024.png', 1024, 'full', { withAlpha: false })
// Play's feature graphic is a 1024x500 banner; the same gradient with the art
// centred keeps the listing consistent with the icon.
write('store/assets/play-feature-graphic-1024x500.png', 500, 'full', {
  aspect: 1024 / 500,
  artScale: 0.85,
  withAlpha: false,
})

// Optional: `--preview <path>` composites both adaptive layers and crops to the
// central 66.7% — the area every launcher mask is guaranteed to show, whatever
// shape it uses. Worth a look after any change to the geometry, because the
// foreground PNG on its own is white-on-transparent and tells you nothing.
const previewIndex = process.argv.indexOf('--preview')
if (previewIndex !== -1 && process.argv[previewIndex + 1]) {
  const target = process.argv[previewIndex + 1]
  const { width, height, data } = render(512, 'round', {
    artScale: ADAPTIVE_SAFE_SCALE,
    zoom: 72 / 108,
  })
  mkdirSync(dirname(target), { recursive: true })
  writeFileSync(target, encodePng(width, height, data))
  console.log(`\nPreview (adaptive layers, cropped to the always-visible area): ${target}`)
}

console.log('\nDone.')
