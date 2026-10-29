#!/usr/bin/env node
// Fills the App Store Connect record of אבן דרך (app 6802333227) for version 1.0.2 from
// store-assets/: version string, Hebrew listing, app info, categories, age rating, review
// details, screenshots, and build 17 once it is processed. Availability is left as it is.
//
//   node scripts/asc-metadata.mjs               dry run (default): reads App Store Connect, prints the plan
//   node scripts/asc-metadata.mjs --apply       writes the plan
//   node scripts/asc-metadata.mjs --self-test   offline: inputs, JWT signing, guards; no network
//
// It never submits: any request whose path names a submission endpoint throws before it is
// sent, and DELETE is only allowed on screenshots. Key: ASC_KEY_ID, ASC_ISSUER_ID and
// optionally ASC_KEY_PATH, from the environment or ~/.appstoreconnect/asc.env; the .p8
// defaults to ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8. The key and the JWT
// are generated and used in-process and never printed.
// Review contact: REVIEW_CONTACT_EMAIL and REVIEW_CONTACT_PHONE (left unchanged when unset).
import crypto from 'node:crypto'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..')
const ASSETS = path.join(ROOT, 'store-assets')
const API = 'https://api.appstoreconnect.apple.com'

const APP_ID = '6802333227'
const BUNDLE_ID = 'com.yahpz.responder'
const VERSION = '1.0.2'
const BUILD = '17'
const LOCALE = 'he'
const COPYRIGHT = '2026 Omri Landman'
const SUPPORT_URL = 'https://yahpz.com/support'
const MARKETING_URL = 'https://yahpz.com'
const PRIVACY_URL = 'https://yahpz.com/privacy'
const PRIVACY_CHOICES_URL = 'https://yahpz.com/delete-data'
const PRIMARY_CATEGORY = 'PRODUCTIVITY'
const SECONDARY_CATEGORY = 'UTILITIES'
const EDITABLE_STATES = new Set([
  'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED', 'INVALID_BINARY',
])
const SCREENSHOT_SETS = [
  { type: 'APP_IPHONE_67', dir: 'iphone-6.9-1320x2868', width: 1320, height: 2868 },
  { type: 'APP_IPHONE_65', dir: 'iphone-6.5-1242x2688', width: 1242, height: 2688 },
]
// AGE-RATING.md: every content question None / No; not made for kids. Only keys the API
// returns are sent; any other key it returns is listed for a human to answer.
const AGE_RATING = {
  alcoholTobaccoOrDrugUseOrReferences: 'NONE',
  contests: 'NONE',
  gamblingSimulated: 'NONE',
  gunsOrOtherWeapons: 'NONE',
  horrorOrFearThemes: 'NONE',
  matureOrSuggestiveThemes: 'NONE',
  medicalOrTreatmentInformation: 'NONE',
  profanityOrCrudeHumor: 'NONE',
  sexualContentGraphicAndNudity: 'NONE',
  sexualContentOrNudity: 'NONE',
  violenceCartoonOrFantasy: 'NONE',
  violenceRealistic: 'NONE',
  violenceRealisticProlongedGraphicOrSadistic: 'NONE',
  advertising: false,
  ageAssurance: false,
  gambling: false,
  healthOrWellnessTopics: false,
  lootBox: false,
  messagingAndChat: false,
  parentalControls: false,
  unrestrictedWebAccess: false,
  userGeneratedContent: false,
}
const AGE_RATING_LEAVE = new Set(['kidsAgeBand', 'ageRatingOverride', 'ageRatingOverrideV2', 'koreaAgeRatingOverride'])

// ---------------------------------------------------------------- guards

/** Throws for anything this script must never do, whatever the caller asks. */
export function guardRequest(method, urlPath) {
  if (/submission/i.test(urlPath)) {
    throw new Error(`refused: ${method} ${urlPath} is a submission endpoint; this script never submits`)
  }
  if (!/^\/v[12]\//.test(urlPath)) {
    throw new Error(`refused: ${urlPath} is not an App Store Connect API path`)
  }
  if (method === 'DELETE' && !/^\/v1\/appScreenshots\/[^/]+$/.test(urlPath)) {
    throw new Error(`refused: DELETE ${urlPath}; only screenshots may be deleted`)
  }
}

// ---------------------------------------------------------------- inputs

function codeBlockAfter(markdown, heading) {
  const at = markdown.indexOf(heading)
  if (at < 0) throw new Error(`missing "${heading}"`)
  const match = markdown.slice(at).match(/```\n([\s\S]*?)\n```/)
  if (!match) throw new Error(`no code block after "${heading}"`)
  return match[1]
}

function limited(name, text, limit) {
  if ([...text].length > limit) throw new Error(`${name} is ${[...text].length} characters, limit ${limit}`)
  return text
}

/** IHDR: width and height at bytes 16-23, colour type at 25 (2 = RGB, 6 = RGBA). */
function pngInfo(file) {
  const bytes = fs.readFileSync(file)
  if (bytes.readUInt32BE(12) !== 0x49484452) throw new Error(`${file} is not a PNG`)
  return { width: bytes.readUInt32BE(16), height: bytes.readUInt32BE(20), colourType: bytes[25], bytes }
}

export function loadInputs() {
  const listing = fs.readFileSync(path.join(ASSETS, 'LISTING.md'), 'utf8')
  const notes = fs.readFileSync(path.join(ASSETS, 'REVIEW-NOTES.md'), 'utf8')
  const inputs = {
    name: limited('name', codeBlockAfter(listing, '## Name'), 30),
    subtitle: limited('subtitle', codeBlockAfter(listing, '## Subtitle'), 30),
    promotionalText: limited('promotional text', codeBlockAfter(listing, '## Promotional text'), 170),
    description: limited('description', codeBlockAfter(listing, '## Description'), 4000),
    keywords: limited('keywords', codeBlockAfter(listing, '## Keywords'), 100),
    whatsNew: limited("what's new", codeBlockAfter(listing, "## What's New"), 4000),
    reviewNotes: limited('review notes', codeBlockAfter(notes, '## Notes for the reviewer'), 4000),
    screenshots: {},
  }
  for (const set of SCREENSHOT_SETS) {
    const dir = path.join(ASSETS, 'screenshots', set.dir)
    const files = fs.readdirSync(dir).filter((f) => f.endsWith('.png')).sort()
    if (files.length !== 7) throw new Error(`${set.dir}: expected 7 PNGs, found ${files.length}`)
    inputs.screenshots[set.type] = files.map((f) => {
      const file = path.join(dir, f)
      const info = pngInfo(file)
      if (info.width !== set.width || info.height !== set.height) {
        throw new Error(`${set.dir}/${f} is ${info.width}x${info.height}, expected ${set.width}x${set.height}`)
      }
      if (info.colourType !== 2) throw new Error(`${set.dir}/${f} is not RGB without alpha`)
      return { file, name: f, size: info.bytes.length, md5: crypto.createHash('md5').update(info.bytes).digest('hex') }
    })
  }
  return inputs
}

// ---------------------------------------------------------------- key and token

function loadEnvFile(file) {
  if (!fs.existsSync(file)) return
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const match = line.match(/^\s*(?:export\s+)?(ASC_KEY_ID|ASC_ISSUER_ID|ASC_KEY_PATH)=["']?([^"'\n]*)["']?\s*$/)
    // The same file is sourced by deploy-xtool.sh, so accept the shell's $HOME and ~.
    const value = match?.[2].replace(/^(\$HOME|\$\{HOME\}|~)(?=\/)/, os.homedir())
    if (match && !process.env[match[1]]) process.env[match[1]] = value
  }
}

function loadKey() {
  loadEnvFile(process.env.ASC_ENV_FILE || path.join(os.homedir(), '.appstoreconnect', 'asc.env'))
  const keyId = process.env.ASC_KEY_ID
  const issuerId = process.env.ASC_ISSUER_ID
  if (!keyId || !issuerId) throw new Error('set ASC_KEY_ID and ASC_ISSUER_ID (or ~/.appstoreconnect/asc.env)')
  const keyPath = process.env.ASC_KEY_PATH
    || path.join(os.homedir(), '.appstoreconnect', 'private_keys', `AuthKey_${keyId}.p8`)
  if (!fs.existsSync(keyPath)) throw new Error('the .p8 file is missing (ASC_KEY_PATH or ~/.appstoreconnect/private_keys)')
  if ((fs.statSync(keyPath).mode & 0o777) !== 0o600) throw new Error('chmod 600 the .p8 file first')
  if (keyPath.startsWith(ROOT + path.sep)) throw new Error('keep the .p8 outside the repo')
  return { keyId, issuerId, privateKey: crypto.createPrivateKey(fs.readFileSync(keyPath)) }
}

const b64url = (data) => Buffer.from(data).toString('base64url')

/** ES256 JWT for the App Store Connect API (20-minute maximum lifetime). */
export function signToken({ keyId, issuerId, privateKey }, now = Math.floor(Date.now() / 1000)) {
  const header = b64url(JSON.stringify({ alg: 'ES256', kid: keyId, typ: 'JWT' }))
  const payload = b64url(JSON.stringify({ iss: issuerId, iat: now, exp: now + 1200, aud: 'appstoreconnect-v1' }))
  const signature = crypto.sign('sha256', Buffer.from(`${header}.${payload}`), { key: privateKey, dsaEncoding: 'ieee-p1363' })
  return `${header}.${payload}.${b64url(signature)}`
}

// ---------------------------------------------------------------- client

function makeClient(key, apply) {
  let token = null
  let tokenAt = 0
  const auth = () => {
    const now = Math.floor(Date.now() / 1000)
    if (!token || now - tokenAt > 900) {
      token = signToken(key, now)
      tokenAt = now
    }
    return `Bearer ${token}`
  }
  async function request(method, urlPath, body) {
    guardRequest(method, urlPath)
    if (method !== 'GET' && !apply) return null
    const response = await fetch(API + urlPath, {
      method,
      headers: { Authorization: auth(), ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    })
    if (response.status === 204) return null
    const json = await response.json().catch(() => null)
    if (!response.ok) {
      const detail = json?.errors?.map((e) => `${e.code}: ${e.detail}`).join('; ') || response.statusText
      throw new Error(`${method} ${urlPath} → ${response.status} ${detail}`)
    }
    return json
  }
  async function list(urlPath) {
    const out = []
    let next = urlPath + (urlPath.includes('?') ? '&' : '?') + 'limit=200'
    while (next) {
      const page = await request('GET', next)
      out.push(...(page?.data ?? []))
      const link = page?.links?.next
      next = link ? link.replace(API, '') : null
    }
    return out
  }
  /** Presigned upload slices from POST /v1/appScreenshots; Apple's own URLs, no API token. */
  async function uploadParts(operations, bytes) {
    for (const op of operations) {
      const headers = Object.fromEntries((op.requestHeaders ?? []).map((h) => [h.name, h.value]))
      const response = await fetch(op.url, {
        method: op.method,
        headers,
        body: bytes.subarray(op.offset, op.offset + op.length),
      })
      if (!response.ok) throw new Error(`screenshot upload part → ${response.status}`)
    }
  }
  return { request, list, uploadParts }
}

// ---------------------------------------------------------------- plan

const say = (line) => console.log(line)

function changed(current, wanted) {
  return Object.fromEntries(Object.entries(wanted).filter(([k, v]) => v !== undefined && current?.[k] !== v))
}

function describe(fields) {
  return Object.entries(fields)
    .map(([k, v]) => `${k}=${typeof v === 'string' && v.length > 40 ? `${JSON.stringify(v.slice(0, 40))}… (${[...v].length} chars)` : JSON.stringify(v)}`)
    .join(', ')
}

async function patchIfChanged(api, label, type, id, current, wanted, apply) {
  const fields = changed(current, wanted)
  if (Object.keys(fields).length === 0) return say(`= ${label}: unchanged`)
  say(`${apply ? '~' : '~ would set'} ${label}: ${describe(fields)}`)
  await api.request('PATCH', `/v1/${type}/${id}`, { data: { type, id, attributes: fields } })
}

async function run(apply) {
  const inputs = loadInputs()
  const api = makeClient(loadKey(), apply)
  say(apply ? 'APPLY: writing to App Store Connect (never submits)' : 'DRY RUN: reading only; pass --apply to write')

  const app = (await api.request('GET', `/v1/apps/${APP_ID}`)).data
  if (app.attributes.bundleId !== BUNDLE_ID) throw new Error(`app ${APP_ID} is ${app.attributes.bundleId}, expected ${BUNDLE_ID}`)
  say(`app ${APP_ID}: ${app.attributes.name} (${app.attributes.bundleId}), primary locale ${app.attributes.primaryLocale}`)
  if (app.attributes.primaryLocale !== LOCALE) say(`! primary locale is not ${LOCALE}; the Hebrew fields go to a ${LOCALE} localization`)

  // Version: rename the editable 1.0 (or reuse 1.0.2); create 1.0.2 only if none is editable.
  const versions = await api.list(`/v1/apps/${APP_ID}/appStoreVersions?filter[platform]=IOS`)
  for (const v of versions) say(`  version ${v.attributes.versionString}: ${v.attributes.appVersionState ?? v.attributes.appStoreState}`)
  const stateOf = (v) => v.attributes.appVersionState ?? v.attributes.appStoreState
  const editable = versions.filter((v) => EDITABLE_STATES.has(stateOf(v)))
  let version = editable.find((v) => v.attributes.versionString === VERSION) ?? editable[0]
  const firstRelease = !versions.some((v) => ['READY_FOR_SALE', 'READY_FOR_DISTRIBUTION', 'REPLACED_WITH_NEW_VERSION', 'REMOVED_FROM_SALE'].includes(stateOf(v)))
  if (!version) {
    say(`${apply ? '+' : '+ would create'} version ${VERSION}`)
    const created = await api.request('POST', '/v1/appStoreVersions', {
      data: {
        type: 'appStoreVersions',
        attributes: { platform: 'IOS', versionString: VERSION, copyright: COPYRIGHT, releaseType: 'MANUAL' },
        relationships: { app: { data: { type: 'apps', id: APP_ID } } },
      },
    })
    if (!created) return say('(dry run stops here: the rest needs the new version)')
    version = created.data
  } else {
    await patchIfChanged(api, `version ${version.attributes.versionString}`, 'appStoreVersions', version.id, version.attributes,
      { versionString: VERSION, copyright: COPYRIGHT, releaseType: 'MANUAL' }, apply)
  }

  // Hebrew store listing.
  const localizations = await api.list(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`)
  let localization = localizations.find((l) => l.attributes.locale === LOCALE)
  const listingFields = {
    description: inputs.description,
    keywords: inputs.keywords,
    promotionalText: inputs.promotionalText,
    supportUrl: SUPPORT_URL,
    marketingUrl: MARKETING_URL,
    whatsNew: firstRelease ? undefined : inputs.whatsNew,
  }
  if (firstRelease) say("  what's new: skipped, App Store Connect does not take it on a first release")
  if (!localization) {
    say(`${apply ? '+' : '+ would create'} ${LOCALE} version localization: ${describe(changed({}, listingFields))}`)
    const created = await api.request('POST', '/v1/appStoreVersionLocalizations', {
      data: {
        type: 'appStoreVersionLocalizations',
        attributes: { locale: LOCALE, ...changed({}, listingFields) },
        relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
      },
    })
    localization = created?.data
  } else {
    await patchIfChanged(api, `${LOCALE} listing`, 'appStoreVersionLocalizations', localization.id, localization.attributes, listingFields, apply)
  }

  // App info: name, subtitle, privacy URLs, categories, age rating.
  const infos = await api.list(`/v1/apps/${APP_ID}/appInfos`)
  const info = infos.find((i) => EDITABLE_STATES.has(i.attributes.appStoreState ?? i.attributes.state)) ?? infos[0]
  const infoLocalizations = await api.list(`/v1/appInfos/${info.id}/appInfoLocalizations`)
  const infoLocalization = infoLocalizations.find((l) => l.attributes.locale === LOCALE)
  const infoFields = { name: inputs.name, subtitle: inputs.subtitle, privacyPolicyUrl: PRIVACY_URL, privacyChoicesUrl: PRIVACY_CHOICES_URL }
  if (!infoLocalization) {
    say(`${apply ? '+' : '+ would create'} ${LOCALE} app info localization: ${describe(infoFields)}`)
    await api.request('POST', '/v1/appInfoLocalizations', {
      data: {
        type: 'appInfoLocalizations',
        attributes: { locale: LOCALE, ...infoFields },
        relationships: { appInfo: { data: { type: 'appInfos', id: info.id } } },
      },
    })
  } else {
    await patchIfChanged(api, `${LOCALE} app info`, 'appInfoLocalizations', infoLocalization.id, infoLocalization.attributes, infoFields, apply)
  }
  const primary = await api.request('GET', `/v1/appInfos/${info.id}/relationships/primaryCategory`)
  const secondary = await api.request('GET', `/v1/appInfos/${info.id}/relationships/secondaryCategory`)
  if (primary?.data?.id === PRIMARY_CATEGORY && secondary?.data?.id === SECONDARY_CATEGORY) {
    say('= categories: unchanged')
  } else {
    say(`${apply ? '~' : '~ would set'} categories: ${primary?.data?.id ?? 'none'}/${secondary?.data?.id ?? 'none'} → ${PRIMARY_CATEGORY}/${SECONDARY_CATEGORY}`)
    await api.request('PATCH', `/v1/appInfos/${info.id}`, {
      data: {
        type: 'appInfos',
        id: info.id,
        relationships: {
          primaryCategory: { data: { type: 'appCategories', id: PRIMARY_CATEGORY } },
          secondaryCategory: { data: { type: 'appCategories', id: SECONDARY_CATEGORY } },
        },
      },
    })
  }
  const rating = (await api.request('GET', `/v1/appInfos/${info.id}/ageRatingDeclaration`))?.data
  if (rating) {
    const known = Object.fromEntries(Object.entries(AGE_RATING).filter(([k]) => k in rating.attributes))
    const unknown = Object.keys(rating.attributes).filter((k) => !(k in AGE_RATING) && !AGE_RATING_LEAVE.has(k))
    if (unknown.length) say(`! age rating questions not in AGE-RATING.md, answer by hand: ${unknown.join(', ')}`)
    await patchIfChanged(api, 'age rating', 'ageRatingDeclarations', rating.id, rating.attributes, known, apply)
  } else {
    say('! no age rating declaration found on the app info; fill it by hand (AGE-RATING.md)')
  }

  // App Review details: sign-in required, demo account left empty, notes from REVIEW-NOTES.md.
  const reviewFields = {
    contactFirstName: 'Omri',
    contactLastName: 'Landman',
    contactEmail: process.env.REVIEW_CONTACT_EMAIL || undefined,
    contactPhone: process.env.REVIEW_CONTACT_PHONE || undefined,
    demoAccountRequired: true,
    demoAccountName: '',
    demoAccountPassword: '',
    notes: inputs.reviewNotes,
  }
  if (!reviewFields.contactEmail) say('! TODO review contact email: set REVIEW_CONTACT_EMAIL')
  if (!reviewFields.contactPhone) say('! TODO review contact phone: set REVIEW_CONTACT_PHONE')
  say('  demo account name and password: left empty; type them in App Store Connect (DEMO-LOGIN.md)')
  const review = (await api.request('GET', `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`).catch(() => null))?.data
  if (review) {
    const { demoAccountPassword: _ignored, ...visible } = review.attributes
    await patchIfChanged(api, 'review details', 'appStoreReviewDetails', review.id, { ...visible, demoAccountPassword: null }, reviewFields, apply)
  } else {
    say(`${apply ? '+' : '+ would create'} review details`)
    await api.request('POST', '/v1/appStoreReviewDetails', {
      data: {
        type: 'appStoreReviewDetails',
        attributes: changed({}, reviewFields),
        relationships: { appStoreVersion: { data: { type: 'appStoreVersions', id: version.id } } },
      },
    })
  }

  // Screenshots: delete every old one on this localization, upload the 7 new ones per size.
  if (localization) {
    const sets = await api.list(`/v1/appStoreVersionLocalizations/${localization.id}/appScreenshotSets`)
    for (const set of sets) {
      const shots = await api.list(`/v1/appScreenshotSets/${set.id}/appScreenshots`)
      for (const shot of shots) {
        say(`${apply ? '-' : '- would delete'} ${set.attributes.screenshotDisplayType} ${shot.attributes.fileName}`)
        await api.request('DELETE', `/v1/appScreenshots/${shot.id}`)
      }
    }
    for (const { type } of SCREENSHOT_SETS) {
      let set = sets.find((s) => s.attributes.screenshotDisplayType === type)
      if (!set) {
        say(`${apply ? '+' : '+ would create'} screenshot set ${type}`)
        set = (await api.request('POST', '/v1/appScreenshotSets', {
          data: {
            type: 'appScreenshotSets',
            attributes: { screenshotDisplayType: type },
            relationships: { appStoreVersionLocalization: { data: { type: 'appStoreVersionLocalizations', id: localization.id } } },
          },
        }))?.data
      }
      const uploaded = []
      for (const shot of inputs.screenshots[type]) {
        say(`${apply ? '+' : '+ would upload'} ${type} ${shot.name} (${shot.size} bytes)`)
        if (!apply || !set) continue
        const reserved = (await api.request('POST', '/v1/appScreenshots', {
          data: {
            type: 'appScreenshots',
            attributes: { fileName: shot.name, fileSize: shot.size },
            relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: set.id } } },
          },
        })).data
        await api.uploadParts(reserved.attributes.uploadOperations, fs.readFileSync(shot.file))
        await api.request('PATCH', `/v1/appScreenshots/${reserved.id}`, {
          data: { type: 'appScreenshots', id: reserved.id, attributes: { uploaded: true, sourceFileChecksum: shot.md5 } },
        })
        uploaded.push(reserved.id)
      }
      if (uploaded.length) {
        await api.request('PATCH', `/v1/appScreenshotSets/${set.id}/relationships/appScreenshots`, {
          data: uploaded.map((id) => ({ type: 'appScreenshots', id })),
        })
      }
    }
  } else {
    say('! no localization yet (dry run); screenshots are planned after it exists')
  }

  // Build 17 under 1.0.2, once App Store Connect has processed it.
  const builds = await api.list(`/v1/builds?filter[app]=${APP_ID}&filter[version]=${BUILD}&filter[preReleaseVersion.version]=${VERSION}`)
  const build = builds[0]
  if (!build) {
    say(`! build ${VERSION} (${BUILD}) is not on App Store Connect yet: upload it, then run this again`)
  } else if (build.attributes.processingState !== 'VALID') {
    say(`! build ${VERSION} (${BUILD}) is ${build.attributes.processingState}: run this again once it is VALID`)
  } else {
    const attached = await api.request('GET', `/v1/appStoreVersions/${version.id}/relationships/build`)
    if (attached?.data?.id === build.id) {
      say(`= build ${VERSION} (${BUILD}): attached`)
    } else {
      say(`${apply ? '~' : '~ would attach'} build ${VERSION} (${BUILD})`)
      await api.request('PATCH', `/v1/appStoreVersions/${version.id}/relationships/build`, { data: { type: 'builds', id: build.id } })
    }
  }

  say('= availability and pricing: left as they are (public App Store)')
  say('Not submitted. Submit for review in App Store Connect yourself, then reply in the Resolution Center.')
}

// ---------------------------------------------------------------- self-test (offline)

function selfTest() {
  const inputs = loadInputs()
  console.log(`inputs: name ${[...inputs.name].length}, subtitle ${[...inputs.subtitle].length}, promo ${[...inputs.promotionalText].length}, description ${[...inputs.description].length}, keywords ${[...inputs.keywords].length}, notes ${[...inputs.reviewNotes].length} characters`)
  for (const { type } of SCREENSHOT_SETS) console.log(`screenshots ${type}: ${inputs.screenshots[type].map((s) => s.name).join(', ')}`)

  const { privateKey, publicKey } = crypto.generateKeyPairSync('ec', { namedCurve: 'prime256v1' })
  const token = signToken({ keyId: 'TESTKEY', issuerId: 'test-issuer', privateKey }, 1_700_000_000)
  const [h, p, s] = token.split('.')
  const valid = crypto.verify('sha256', Buffer.from(`${h}.${p}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(s, 'base64url'))
  const payload = JSON.parse(Buffer.from(p, 'base64url'))
  if (!valid || payload.aud !== 'appstoreconnect-v1' || payload.exp - payload.iat !== 1200) throw new Error('JWT check failed')
  console.log('JWT: ES256 signature verifies with a throwaway key; aud and 20-minute lifetime correct')

  const refused = [
    ['POST', '/v1/reviewSubmissions'],
    ['POST', '/v1/reviewSubmissionItems'],
    ['PATCH', '/v1/reviewSubmissions/abc'],
    ['POST', '/v1/appStoreVersionSubmissions'],
    ['DELETE', '/v1/appStoreVersions/abc'],
    ['DELETE', '/v1/apps/6802333227'],
    ['GET', 'https://example.com/v1/apps'],
  ]
  for (const [method, urlPath] of refused) {
    let threw = false
    try { guardRequest(method, urlPath) } catch { threw = true }
    if (!threw) throw new Error(`guard let ${method} ${urlPath} through`)
  }
  guardRequest('DELETE', '/v1/appScreenshots/abc')
  guardRequest('PATCH', '/v1/appStoreVersions/abc/relationships/build')
  console.log(`guard: refuses ${refused.length} submit/delete/foreign requests, allows screenshot deletes and build attach`)
  console.log('self-test passed (no network)')
}

const args = new Set(process.argv.slice(2))
for (const arg of args) {
  if (!['--apply', '--dry-run', '--self-test'].includes(arg)) {
    console.error(`unknown option ${arg}`)
    process.exit(2)
  }
}
if (args.has('--apply') && args.has('--dry-run')) {
  console.error('choose --apply or --dry-run')
  process.exit(2)
}
try {
  if (args.has('--self-test')) selfTest()
  else await run(args.has('--apply'))
} catch (error) {
  console.error(`✗ ${error.message}`)
  process.exit(1)
}
