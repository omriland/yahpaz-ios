// Resubmits אבן דרך 1.0.2 for App Review once the right build is attached.
//
//   node scripts/asc-resubmit.mjs            dry run (default): GET only, prints the state and the plan
//   node scripts/asc-resubmit.mjs --apply    marks the rejected item resolved and submits again
//
// Refuses unless version 1.0.2 has build BUILD attached and that build is VALID. Release type
// is never touched (it stays MANUAL), and nothing is released. Key: ASC_KEY_ID, ASC_ISSUER_ID,
// ASC_KEY_PATH from the environment or ~/.appstoreconnect/asc.env; the key and the JWT are
// used in-process and never printed.
import { readFileSync } from 'node:fs'
import { createSign } from 'node:crypto'
import { homedir } from 'node:os'

const APP = '6802333227'
const VERSION = '1.0.2'
const BUILD = '18'
const APPLY = process.argv.includes('--apply')

const fileEnv = (() => {
  try {
    return Object.fromEntries(
      readFileSync(`${homedir()}/.appstoreconnect/asc.env`, 'utf8')
        .split('\n').filter((l) => /^[A-Z_]+=/.test(l))
        .map((l) => { const i = l.indexOf('='); return [l.slice(0, i), l.slice(i + 1).trim().replace(/^["']|["']$/g, '')] }),
    )
  } catch { return {} }
})()
const env = (k) => process.env[k] || fileEnv[k]
const keyId = env('ASC_KEY_ID')
const keyPath = (env('ASC_KEY_PATH') || `~/.appstoreconnect/private_keys/AuthKey_${keyId}.p8`).replace(/^~/, homedir())
const b64u = (v) => Buffer.from(v).toString('base64url')
const now = Math.floor(Date.now() / 1000)
const head = b64u(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }))
const body = b64u(JSON.stringify({ iss: env('ASC_ISSUER_ID'), iat: now, exp: now + 900, aud: 'appstoreconnect-v1' }))
const signer = createSign('SHA256')
signer.update(`${head}.${body}`)
const jwt = `${head}.${body}.${signer.sign({ key: readFileSync(keyPath, 'utf8'), dsaEncoding: 'ieee-p1363' }).toString('base64url')}`

async function api(method, path, payload) {
  const res = await fetch(`https://api.appstoreconnect.apple.com${path}`, {
    method,
    headers: { Authorization: `Bearer ${jwt}`, 'Content-Type': 'application/json' },
    body: payload ? JSON.stringify(payload) : undefined,
  })
  const json = await res.json().catch(() => ({}))
  if (!res.ok) {
    const detail = (json.errors || []).map((e) => `${e.code}: ${e.detail || e.title}`).join('; ')
    throw new Error(`${method} ${path} → ${res.status} ${detail}`)
  }
  return json
}
const il = (iso) => (iso ? new Date(iso).toLocaleString('en-GB', { timeZone: 'Asia/Jerusalem' }) + ' IL' : '—')

const versions = await api('GET', `/v1/apps/${APP}/appStoreVersions?filter[versionString]=${VERSION}&filter[platform]=IOS&include=build`)
const version = versions.data?.[0]
if (!version) throw new Error(`no version ${VERSION}`)
const build = (versions.included || []).find((x) => x.type === 'builds')
console.log(`version ${VERSION}: ${version.attributes.appStoreState} | release ${version.attributes.releaseType} | build ${build?.attributes.version ?? 'none'} ${build?.attributes.processingState ?? ''}`)
if (build?.attributes.version !== BUILD || build?.attributes.processingState !== 'VALID') {
  throw new Error(`refusing: build ${BUILD} must be attached and VALID first (node scripts/asc-metadata.mjs --apply)`)
}

const subs = await api('GET', `/v1/reviewSubmissions?filter[app]=${APP}&filter[platform]=IOS&limit=20`)
const active = (subs.data || []).filter((s) => !['COMPLETE', 'CANCELING', 'COMPLETING'].includes(s.attributes.state))
for (const s of active) console.log(`submission ${s.id}: ${s.attributes.state} (submitted ${il(s.attributes.submittedDate)})`)
const sub = active.find((s) => ['UNRESOLVED_ISSUES', 'READY_FOR_REVIEW'].includes(s.attributes.state))
if (!sub) {
  console.log(active.length ? 'nothing to resubmit: the active submission is already in review' : 'no active submission')
  process.exit(0)
}
const items = await api('GET', `/v1/reviewSubmissions/${sub.id}/items?limit=50`)
for (const item of items.data || []) console.log(`  item ${item.id.slice(0, 12)}…: ${item.attributes.state}`)

if (!APPLY) {
  console.log(`dry run: would mark rejected items resolved and set submitted=true on ${sub.id}. Run with --apply.`)
  process.exit(0)
}
for (const item of items.data || []) {
  if (item.attributes.state === 'REJECTED') {
    await api('PATCH', `/v1/reviewSubmissionItems/${item.id}`, {
      data: { type: 'reviewSubmissionItems', id: item.id, attributes: { resolved: true } },
    })
    console.log(`  item ${item.id.slice(0, 12)}… marked resolved`)
  }
}
await api('PATCH', `/v1/reviewSubmissions/${sub.id}`, {
  data: { type: 'reviewSubmissions', id: sub.id, attributes: { submitted: true } },
})
const after = await api('GET', `/v1/reviewSubmissions/${sub.id}`)
console.log(`submitted: ${after.data.attributes.state} at ${il(after.data.attributes.submittedDate)}`)
