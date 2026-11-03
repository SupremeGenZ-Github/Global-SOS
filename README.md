# Global SOS v4

The v4 source connects the native Android app to **https://global-sos.onrender.com** automatically, adds SOS permission choices, fresh-location trusted alerts, optional SIM SMS, contact import, clearer status and updated UI.

- [v4 setup, PostgreSQL and messaging configuration](Global-SOS-AI-Full-Project/docs/V4-SETUP.md)
- [v4 source](Global-SOS-AI-Full-Project)
- [Android builds and validation](https://github.com/SupremeGenZ-Github/Global-SOS/actions/workflows/v4.yml)

Emergency calls open the phone dialer after five seconds; Android requires **Call** confirmation.
Automatic alerts require consent, permitted contacts and an enabled sending method.
The website APK remains v3 until a verified v4 binary is staged. Current build results are in Actions.

---

# Global SOS AI

**One Tap. One Conversation. Help Anywhere.**

Global SOS AI combines a Flutter Android app, a React website and a Node.js API to help people find government-source emergency and specialist contacts. The Android directory works offline. Optional server features add approved directory updates, private location-sharing sessions, online AI routing and trusted-contact alerts.

**Previous packaged release: 0.3.0 · Development/test signed · ARM64 Android 8.0+**

> This project is not an emergency dispatch service. Opening a dialer or message composer does not confirm connection or delivery. Physical-phone operation and live messaging delivery have not been independently verified.

## Contents

- [Features](#features)
- [Directory coverage](#directory-coverage)
- [Architecture](#architecture)
- [Quick start](#quick-start)
- [GitHub setup](#github-setup)
- [Render deployment](#render-deployment)
- [Environment variables](#environment-variables)
- [PostgreSQL](#postgresql)
- [Public APK download page](#public-apk-download-page)
- [Android installation and connection](#android-installation-and-connection)
- [SOS behavior](#sos-behavior)
- [Offline and online AI](#offline-and-online-ai)
- [Trusted-contact provider alerts](#trusted-contact-provider-alerts)
- [Directory administration](#directory-administration)
- [Android builds and signing](#android-builds-and-signing)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Privacy and limitations](#privacy-and-limitations)
- [License](#license)

## Features

### Android

- Bundled emergency directory, with SQLite storage for synchronized snapshots.
- Country, category, channel and regional filtering; favorite services.
- Telephone, SMS, WhatsApp, email and web actions where officially published.
- Five-second SOS countdown with Cancel and a native emergency-dialer shortcut.
- Optional GPS capture and foreground private location sharing.
- Encrypted trusted contacts, optional medical notes, personal checklist and session history.
- Optional local LLM intent routing, with deterministic fallback when no model is loaded.
- Android voice input and text-to-speech controls, subject to installed engines and language support.
- Light theme, high contrast and silent-interface controls.
- Shortcut to the configured website's APK download page.

### Website

- Responsive emergency directory and assistant interface.
- Search, category/channel/region filters, favorites-only view, sorting and filter reset.
- Personal contact management and editing.
- Personal readiness checklist.
- Printable emergency card; optional medical notes appear only when explicitly included.
- Public APK download page with version, size, compatibility, checksum and installation instructions.
- Server, database/directory and APK availability checks.
- Administrator proposal and publication interface.

### Backend

- Express REST API serving the built website and Android clients.
- Read-only directory mode without a database.
- Optional PostgreSQL persistence, additive migrations and versioned synchronization.
- Independent reviewer/publisher credentials, revision history and stale-review rejection.
- Government-page change monitoring that queues changes for human review.
- Capability-protected SOS sessions with one-hour expiry and opt-in location updates.
- Optional Twilio SMS/approved WhatsApp-template and Resend email adapters for trusted contacts.
- Input validation, parameterized SQL, rate limits, CORS controls and security headers.

## Directory coverage

The bundled 0.3 directory contains:

| Item | Count |
|---|---:|
| Services | 525 |
| Communication channels | 625 |
| Telephone channels | 548 |
| SMS channels | 12 |
| WhatsApp channels | 9 |
| Email channels | 16 |
| Web channels | 40 |
| UN member countries with at least one record | 186 |
| Additional territories with records | 11 |

All 193 UN member states are selectable. A country being selectable does not mean that every category or local service has been verified. National primary-service records exist for 184 UN members; some other records have regional restrictions.

Contact details originate from government-operated pages. Some services are operated by organizations listed on those government pages. Many primary emergency numbers are sourced from UK FCDO travel guidance, rather than each country's own government. Cards retain source URLs, checking dates and jurisdiction notes.

Specialist coverage remains uneven. Missing WhatsApp numbers, email addresses or emergency numbers are not invented to fill gaps. Source-page checking does not establish operational availability. See [HELPLINE_SOURCES.md](HELPLINE_SOURCES.md).

## Architecture

| Component | Technology | Responsibility |
|---|---|---|
| Android application | Flutter/Dart | Offline directory, local safety data and device actions |
| Website | React, TypeScript, Vite | Browser interface and APK download page |
| API | Node.js, Express | Shared directory, administration, sessions and optional providers |
| Central database | PostgreSQL | Approved data, revisions, review queue and private sessions |
| Android directory storage | SQLite | Offline synchronized snapshots |
| Android private storage | Encrypted secure storage | Trusted contacts, notes and personal safety data |
| Optional local model | SmolLM2 GGUF through llama.cpp | Intent classification |

Android and the website communicate with the backend API. **Database credentials belong on the server; Android never connects directly to PostgreSQL.**

```text
android/                 Flutter project; native project is android/android/
website/                 React website and static assets
backend/                 Express API, persistence and source monitoring
database/                Additive SQL migration
shared/                  Directory, categories and app-guide data
releases/android/        Verified APK release parts and manifest
scripts/                 Build, release preparation and verification helpers
offline-model/           Model documentation and optional bundling helpers
tests/                   Backend/API/database/download tests
docs/                    Upgrade guides, feature status and test evidence
.github/workflows/       Android builds and web/backend checks
render.yaml              Render deployment configuration
.env.example             Environment-variable reference
```

The Render-only package omits Android source and Android build automation. Use the **full project package** for a GitHub repository that should also build the Android app.

## Quick start

Use the tested Node.js version **24.21.0**. Run commands from the project root containing `package.json`.

1. Copy `.env.example` to `.env`.
2. For local browsing, use these settings:

```env
NODE_ENV=development
PORT=3000
APP_BASE_URL=http://localhost:3000
CORS_ORIGINS=http://localhost:3000
AI_PROVIDER=none
```

Leave `DATABASE_URL` unset for read-only directory mode.

```sh
npm ci --include=dev
npm run build
npm start
```

Open `http://localhost:3000` and `http://localhost:3000/download`.

The build and startup scripts automatically prepare the bundled APK download. A missing release shows an unavailable state; a corrupt release fails its integrity check.

## GitHub setup

1. Create a repository and extract the supplied full project or Render ZIP.
2. Upload the **contents inside** the extracted folder. `package.json`, `package-lock.json` and `render.yaml` must be at the repository root.
3. Keep `releases/android/`, including every release part and `release.json`.
4. Keep the supplied `README.md`, `LICENSE`, `.gitignore` and `.env.example`.
5. Include `.github/workflows/` when using the full project and Android build automation.

When creating the repository, you can leave GitHub's README, license and `.gitignore` initialization options blank and upload the supplied files.

Do not commit `.env`, `node_modules`, database passwords, provider keys, signing keystores or generated build caches. The supplied `.gitignore` covers these items. The checked APK release parts are intentionally included so the website can serve the app after deployment.

## Render deployment

Connect the GitHub repository to a Node web service, or deploy using the supplied `render.yaml` Blueprint.

| Setting | Value |
|---|---|
| Runtime | Node |
| Node version | `24.21.0` |
| Root directory | Leave blank when `package.json` is at the repository root |
| Build command | `npm ci --include=dev && npm run build` |
| Start command | `npm start` |
| Health-check path | `/health` |

For a basic deployment, set:

```env
NODE_ENV=production
NODE_VERSION=24.21.0
APP_BASE_URL=https://YOUR-SERVICE.onrender.com
CORS_ORIGINS=https://YOUR-SERVICE.onrender.com
AI_PROVIDER=none
```

Replace the example hostname with your actual Render address. Use origins without a trailing slash. The server reads Render's `PORT` and binds to `0.0.0.0`; you normally do not need to override `PORT` there.

For read-only operation, omit `DATABASE_URL` rather than entering a placeholder. The Blueprint includes optional configuration fields for additional features; only supply real values for features you enable.

After deployment:

- `/health` checks that the process is alive.
- `/ready` reports database/directory readiness.
- `/download` displays the public Android download page.

Actual deployment to an external Render account has not been tested as part of the local release checks. Sleeping services, network failures and provider availability can affect online features; the Android directory remains available offline.

## Environment variables

Render uses its Environment settings. A physical `.env` file is for local setup and must stay out of Git.

### Application and database

| Variable | Purpose | Required? |
|---|---|---|
| `NODE_ENV` | `production` on the deployed server | Recommended |
| `NODE_VERSION` | Runtime selection; tested with `24.21.0` | Deployment configuration |
| `PORT` | HTTP listening port; local default is `3000` | Provided by Render |
| `APP_BASE_URL` | Your website's public origin | Set for the deployment |
| `CORS_ORIGINS` | Comma-separated allowed browser origins | Set for browser requests |
| `DATABASE_URL` | PostgreSQL connection string | Only for database-backed features |

### Administration and source monitoring

| Variable | Purpose |
|---|---|
| `ADMIN_REVIEW_TOKEN` | Private credential for submitting directory proposals |
| `ADMIN_PUBLISH_TOKEN` | Different private credential for approving/publishing proposals |
| `DIRECTORY_UPDATE_INTERVAL` | Monitoring interval in seconds; default `86400`, minimum enforced `3600` |
| `MONITOR_CONTACT` | Real operator contact required before scheduled source monitoring runs |

Both administrator tokens must be **at least 32 characters** and must be **different**. Generate separate values, for example by running this command twice:

```sh
node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"
```

Store the output privately in the server environment. Do not put tokens in README examples, public source or screenshots. Administrator tokens are not needed to browse the directory or download the APK.

### Optional online AI

| Variable | Purpose |
|---|---|
| `AI_PROVIDER` | `none` or `openai-compatible` |
| `AI_BASE_URL` | Base API URL of your compatible model service |
| `AI_MODEL` | Model identifier understood by that service |
| `AI_API_KEY` | Provider credential, if required |
| `AI_TIMEOUT_MS` | Request timeout; default `10000` |

### Optional trusted-contact alerts

| Variable | Purpose |
|---|---|
| `ALERT_CLIENT_TOKEN` | Separate private alert credential, at least 32 characters |
| `ALERT_ALLOWED_RECIPIENTS` | Comma-separated exact, consenting phone numbers/email addresses |
| `TWILIO_ACCOUNT_SID` | Twilio account identifier |
| `TWILIO_AUTH_TOKEN` | Twilio server credential |
| `TWILIO_SMS_FROM` | Approved SMS sender |
| `TWILIO_WHATSAPP_FROM` | Approved WhatsApp sender, including `whatsapp:` prefix |
| `TWILIO_WHATSAPP_TEMPLATE_SID` | Approved template using message variable `1` |
| `RESEND_API_KEY` | Resend server credential for email |
| `ALERT_EMAIL_FROM` | Verified email sender |

Only configure the methods you use. Sender approval, recipient opt-in, country restrictions and provider charges are external requirements. Never add public emergency helplines to the trusted-recipient allowlist.

`SESSION_SECRET` and `JWT_SECRET` are not used by this release. `API_BASE_URL` is an optional Android build-time setting, not a database connection string.

## PostgreSQL

PostgreSQL is **optional** for public browsing and APK downloads. It is required for administrator updates, private server SOS/location sessions and provider-alert records.

1. Create a PostgreSQL database in Neon or Render.
2. Set the backend's `DATABASE_URL` to the real connection string.
3. Retain the provider's TLS parameters; do not disable certificate verification.
4. Restart or redeploy the backend.

Startup applies additive schema preparation and seeds the directory. New source records are added; untouched seed records may be refreshed with revision history. Administrator-approved changes and withdrawals are preserved. Database initialization failure does not reset the database.

For manual preparation:

```sh
npm run migrate
```

See [DATABASE_SCHEMA.sql](DATABASE_SCHEMA.sql) and [database/001_initial.sql](database/001_initial.sql). Back up an existing production database before upgrades.

## Public APK download page

Once deployed, open your website's **`/download`** page. Visitors do not need a ChatGPT account, application account, AI key or database connection to download the installed release.

| Route | Purpose |
|---|---|
| `/download` | Download page and installation instructions |
| `/api/releases/android` | Availability, version, size and checksum metadata |
| `/downloads/Global-SOS-AI.apk` | Direct APK attachment |
| `/downloads/Global-SOS-AI.apk.sha256` | SHA-256 checksum file |

The full and Render packages include verified APK parts in `releases/android/`. Build/start automatically reconstructs them into `public-downloads/android/` and validates the part and final-file checksums. Keep every part and the manifest when uploading the source. No manual reassembly is required.

The download endpoint supports HEAD and byte-range requests. The service worker excludes APK downloads from caching. Missing or corrupted release data does not produce a working download link.

To stage a future, signature-verified APK:

```sh
node scripts/stage-android-release.mjs /path/to/Global-SOS-AI.apk /path/to/APK-BUILD-RESULT.json
npm run prepare:download
```

The build metadata must match the APK's SHA-256 and byte size and declare `signature_verified: true`. Commit the updated parts and manifest, then redeploy. Never change metadata to disguise an unverified binary.

## Android installation and connection

1. Download the APK on an **ARM64 Android 8.0+** phone.
2. Open the file and, if Android asks, allow installation for the application used to download this trusted file.
3. Install or update Global SOS AI and confirm your current country.
4. Use the bundled directory immediately; no `.env`, PostgreSQL connection or AI key is required on the phone.
5. For connected features, enter your website's **HTTPS base address** in Android Settings and tap **Synchronize directory**. Do not append `/api` or `/download` to that base address.
6. Optionally download and load the offline model in Settings.

Updates signed with the same key can be installed over the existing app. Changing signing keys may require uninstalling, which can erase local safety data. Retain important contact details before changing installations. The optional model is not included in the APK/AAB.

## SOS behavior

Tap or hold SOS to start a cancellable five-second countdown. Leaving the app during that pending countdown also cancels it.

At zero, the app opens the Android dialer with the current country's verified emergency shortcut. **For India, the shortcut is 112. Press Call in the phone application.** The app does not bypass Android's restrictions on direct emergency calling.

The dialer action is initiated before storage, GPS or backend work. A failed backend cannot block that shortcut. Opening the dialer does not confirm connection. Countries without an available national shortcut show an explicit limitation instead of receiving another country's number.

Trusted-contact provider alerts are separate from public emergency calling. Mark Safe and Cancel end local/server session activity and remove stored server positions; they cannot recall messages already submitted to a provider.

## Offline and online AI

### Offline

| Property | Value |
|---|---|
| Model | `HuggingFaceTB/SmolLM2-360M-Instruct-GGUF` |
| Quantization | Q8_0 |
| Revision | `593b5a2e04c8f3e4ee880263f93e0bd2901ad47f` |
| Download size | 386,404,992 bytes |
| License | Apache-2.0 |
| Runtime | `llama_flutter_android` 0.2.6 / llama.cpp |
| Language scope | English-focused; multilingual routing is not validated |

Download and load the model in Android Settings. The app checks its SHA-256 before loading it. Model metadata is recorded in `android/assets/model.json`.

The local model classifies intent. Contact values come from the verified directory, never generated model text. If the model is absent, fails to load or times out, deterministic routing remains available. Basic app guidance, greetings and supported arithmetic do not require an LLM. Browser offline routing uses rules and app-guide responses; it does not run the Android local model.

See [offline-model/README.md](offline-model/README.md) for the optional model-inclusive packaging route. Real on-device inference and memory/thermal behavior remain untested.

### Online

Configure your own OpenAI-compatible model service through the server environment. For example:

```env
AI_PROVIDER=openai-compatible
AI_BASE_URL=https://YOUR-MODEL-HOST/v1
AI_MODEL=YOUR_MODEL_IDENTIFIER
AI_API_KEY=YOUR_PRIVATE_PROVIDER_KEY
AI_TIMEOUT_MS=10000
```

The online model service runs separately from the web service unless you intentionally host both together. `localhost` on Render means that Render service itself, not your personal computer. Use a suitable authenticated HTTPS model endpoint for a remote host.

Online routing sends the current message after user consent. Provider failure falls back to local routing. A paid AI key is not required for directory use. The web service does not automatically install or host an LLM.

## Trusted-contact provider alerts

To enable optional automatic trusted-contact alerts:

1. Configure a healthy PostgreSQL backend and the relevant provider variables.
2. Obtain the recipient's agreement and add their exact international phone number or email to `ALERT_ALLOWED_RECIPIENTS`.
3. In Android, add the person in **My Safety**, confirm their consent and select permitted methods.
4. Enter the separate `ALERT_CLIENT_TOKEN` in My Safety; it is stored encrypted on the device.
5. Enable automatic trusted-contact alerts if desired.

Provider credentials remain on the server. The phone receives only the private client token used for this feature. Location is included only after consent and capture/sharing; medical notes are not automatically attached.

Each recipient/method is submitted once per SOS session. Refresh provider status for later delivery information. **Accepted, queued, sent or unknown does not mean delivered.** An ambiguous timeout is not automatically retried. If providers are unavailable, use the native contact composers and complete the message yourself.

Live provider delivery has not been tested. See [docs/UPGRADE-v0.2.md](docs/UPGRADE-v0.2.md) for detailed configuration.

## Directory administration

The Admin page uses two separate roles:

| Credential | Role |
|---|---|
| `ADMIN_REVIEW_TOKEN` | Submit a proposed record change |
| `ADMIN_PUBLISH_TOKEN` | Review, approve/publish, or reject a proposal |

Load a record, retain its approved source identity and exact source URL, make the proposed change and submit it with the reviewer credential. Sign out, use the different publisher credential, check the government evidence and jurisdiction, then approve or reject with review notes.

Publication is versioned and preserves history. Stale proposals are rejected. New source admission is a manually vetted maintainer/database action; an official-looking domain is not automatically trusted.

Source monitoring respects robots directives and queues page changes for review. It does not automatically publish extracted contact numbers. Set a real `MONITOR_CONTACT` and review relevant source-site terms before enabling scheduled checks.

```sh
npm run monitor
```

## Android builds and signing

### GitHub Actions

Use the **full project** repository, including `.github/workflows/build-android.yml` and `android/pubspec.lock`.

Run the **Build Android APK and AAB** workflow from the repository's Actions area. Optionally supply your HTTPS backend URL. Successful runs upload a `Global-SOS-AI-Android` artifact containing APK, AAB and checksums. No successful remote workflow execution is claimed by the local release report.

Without production signing credentials, the artifacts are development/test signed. An AAB is for distribution tooling; it is not directly installable like an APK.

For production signing, retain a permanent keystore and configure these repository Actions secrets:

- `KEYSTORE_BASE64`
- `KEY_ALIAS`
- `KEYSTORE_PASSWORD`
- `KEY_PASSWORD`

Enable production signing when running the workflow. Do not commit the keystore or its passwords. Keep the signing identity for future app updates.

### Local build

Pinned toolchain: Flutter **3.38.10**, Dart **3.10.9**, Java **17**, Android SDK platforms **35/36**, build tools **36.0.0**, NDK **28.2.13676358**, CMake **3.22.1**.

```sh
cd android
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
flutter build appbundle --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://YOUR-SERVICE.onrender.com
```

Outputs, relative to the repository root:

```text
android/build/app/outputs/flutter-apk/app-release.apk
android/build/app/outputs/bundle/release/app-release.aab
```

Local production signing uses `KEYSTORE_PATH`, `KEY_ALIAS`, `KEYSTORE_PASSWORD` and `KEY_PASSWORD`; all four are required. With no production configuration, builds use the development signing setup.

The supplied native Android project is included. `npm run prepare:android` is only needed if regenerating an absent platform project.

## Testing

Recorded local checks for release 0.3:

| Check | Result |
|---|---|
| Flutter static analysis | Passed |
| Flutter unit/widget tests | 11 passed |
| Backend/API/PostgreSQL-engine/download tests | 18 passed |
| Website TypeScript and production build | Passed |
| APK and AAB compilation | Passed |
| APK and AAB signature verification | Passed with development/test signing |
| Actual locally served APK | HTTP download bytes matched the verified release SHA-256 |

Backend database tests use PGlite's PostgreSQL engine. Provider adapters use mocked responses. SOS tests use mocked dialer launches. No real emergency calls or provider messages were sent during testing.

To run checks:

```sh
npm test
npm run build
npm audit --omit=dev
```

For Flutter, run `flutter analyze` and `flutter test` inside `android/`.

**Not established by these checks:** physical-phone installation/upgrade, actual voice/GPS/model performance, live provider delivery, external Neon/Render connectivity, browser interaction/print layout, remote GitHub Actions execution, Play publication or independent security/legal certification.

See [TEST_REPORT.md](TEST_REPORT.md) and [docs/FEATURE_STATUS.md](docs/FEATURE_STATUS.md).

## Troubleshooting

| Problem | What to check |
|---|---|
| Download page says no APK is installed | Keep `releases/android/release.json` and every APK part in the repository; run `npm run prepare:download` and redeploy/restart |
| APK part integrity check fails | Restore the unmodified parts and matching manifest from the same release; do not combine versions |
| Render cannot find `package.json` | Upload extracted project contents at the repository root, or correct the service's root directory |
| Browser requests show an origin error | Set `APP_BASE_URL` and `CORS_ORIGINS` to the exact site origin, without a trailing slash |
| `/ready` returns 503 | Repair the configured database connection and TLS settings, then restart; do not replace the URL with a dummy value |
| Admin or private-session actions are unavailable | These need healthy PostgreSQL; read-only mode intentionally does not support writes |
| APK cannot synchronize | Enter the HTTPS website base URL in Android Settings, with no `/api` suffix |
| Older contacts remain after an update | Deploy the matching updated backend, then synchronize; server-approved snapshots are preserved |
| Model is unavailable | Download and load it in Android Settings; verify storage/memory compatibility; fallback routing still works |
| Voice controls do not work | Check installed Android speech engines and language packs; type the request instead |
| WhatsApp/email action does not open | Check the verified channel and an installed compatible handler; completion still happens in that external app |
| Provider alert is rejected | Check the private alert token, contact consent, permitted methods, exact recipient allowlist and provider configuration |
| An update will not install over the old app | Check package identity, device compatibility and signing-key continuity before uninstalling or deleting data |

## Privacy and limitations

- Android private contacts, medical notes and checklist data use encrypted local storage.
- Browser safety data uses local storage; it is not encrypted by the website.
- Offline chat is not sent to the backend. Online routing sends the current request after consent.
- Location uploads require consent and a private session. Links expire after one hour; Mark Safe/Cancel removes stored positions. Sharing is foreground-only.
- Optional Android geocoding can send coordinates to its provider; it is disabled until enabled. Coarse offline country suggestions require manual confirmation, especially near borders/coasts and small territories.
- Android recognition prefers offline mode but follows the installed provider's network/privacy settings. Installed voice language support does not establish multilingual LLM accuracy.
- Optional medical-card notes print only when explicitly included. Review a card before sharing it.
- Push notifications, account registration and cross-device account synchronization remain unimplemented. Worldwide specialist coverage is incomplete.
- No automatic public emergency dispatch, unrestricted emergency calling, background tracking or guaranteed communication delivery is claimed.

Review and complete operator details in [PRIVACY.md](PRIVACY.md), [TERMS.md](TERMS.md) and [SECURITY.md](SECURITY.md) before public distribution. See [docs/LIMITATIONS.md](docs/LIMITATIONS.md) for remaining boundaries and [docs/UPGRADE-v0.3.md](docs/UPGRADE-v0.3.md) for the latest upgrade guide.

## License

Application source is distributed under the [MIT License](LICENSE). Dependencies, model weights and source datasets retain their respective licenses. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Government-source attribution does not imply government endorsement of this application.
