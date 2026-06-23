export const meta = {
  name: 'djlevel-delta-read',
  description: 'Vision pass boxing the "<rank> +/-NNNN" subtitle (distractor class) on 176 grid crops',
  phases: [{ title: 'Read', detail: 'box the subtitle line on each delta grid crop' }],
}

const DIR = '/tmp/djdelta_grids'
const stems = Array.isArray(args) ? args : JSON.parse(args)

const BOX_SCHEMA = {
  type: 'object',
  properties: {
    boxes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          text: { type: 'string', description: 'the subtitle text you see, e.g. "AA +0002"' },
          gx0: { type: 'number' }, gy0: { type: 'number' },
          gx1: { type: 'number' }, gy1: { type: 'number' },
          confidence: { type: 'number' },
        },
        required: ['name', 'gx0', 'gy0', 'gx1', 'gy1', 'confidence'],
      },
    },
  },
  required: ['boxes'],
}

function chunk(a, n) { const o = []; for (let i = 0; i < a.length; i += n) o.push(a.slice(i, i + n)); return o }

function prompt(batch) {
  const paths = batch.map(s => `${DIR}/${s}.png`).join('\n')
  return `You are labeling bounding boxes on cropped beatmania IIDX result screens.

Each PNG is a zoomed crop taken from JUST BELOW the current DJ LEVEL rank glyph, with a green percentage GRID overlaid (x and y both 0..100 as a percentage of the image; bright GREEN lines at 0/50/100, gray every 10; yellow labels).

Somewhere in the crop is a SUBTITLE line of the form "<rank> +NNNN" or "<rank> -NNNN" — a rank (F/E/D/C/B/A/AA/AAA) followed by a signed 4-digit number, e.g. "AA +0002", "A -0163", "AAA +0019". It is rendered in small cyan/white text.

TASK: For each image, draw a TIGHT box around ONLY that "<rank> +/-NNNN" subtitle line (the rank, the sign, and the 4 digits — the whole line).
- EXCLUDE: the large rank glyph that may appear ABOVE it, the big SCORE number that may appear BELOW it (the score is larger digits with NO rank letters and NO +/- sign on the same line), the "NEW RECORD" badge, and the small "+NNNN" score-delta line further down.
- The subtitle is distinctive: it is the line that has a rank prefix AND a +/- sign.
- Report gx0 (left %), gy0 (top %), gx1 (right %), gy1 (bottom %), each 0–100, with gx1>gx0, gy1>gy0, plus the text you read and a confidence 0–1.

Read EACH file and return one entry per file, keyed by the stem (no extension/dir):
${paths}

Return all entries via the structured output. Do not skip any file.`
}

phase('Read')
const batches = chunk(stems, 6)
const results = await parallel(batches.map((b, i) => () =>
  agent(prompt(b), { label: `delta:${i}`, phase: 'Read', schema: BOX_SCHEMA })))

const boxes = {}, texts = {}, missing = []
for (const r of results) {
  if (!r || !r.boxes) continue
  for (const b of r.boxes) {
    if (b && b.name) { boxes[b.name] = [b.gx0, b.gy0, b.gx1, b.gy1]; texts[b.name] = b.text || '' }
  }
}
for (const s of stems) if (!(s in boxes)) missing.push(s)
log(`delta boxes=${Object.keys(boxes).length}; missing=${missing.length}`)
return { boxes, texts, missing }
