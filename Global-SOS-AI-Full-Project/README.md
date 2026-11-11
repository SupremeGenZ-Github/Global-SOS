# Global SOS v6

A Flutter Android app, React website and Node.js API for finding reviewed emergency contacts, preparing an SOS and keeping personal safety tools close.

[Website](https://global-sos.onrender.com) · [Android download](https://global-sos.onrender.com/download) · [Phone website](https://global-sos.onrender.com/mobile) · [Desktop website](https://global-sos.onrender.com/desktop) · [Builds](https://github.com/SupremeGenZ-Github/Global-SOS/actions/workflows/v4.yml)

**Version:** Android `0.6.0+10`; website/API `0.6.0`. Android's default backend is **https://global-sos.onrender.com**.

**Emergency use:** Global SOS is a development project, not a monitored emergency-dispatch service. SOS opens a verified emergency number in the phone dialer after a cancellable five-second countdown. **Press Call in the dialer.** A queued alert, share sheet or opened composer does not confirm delivery or response. Use the official emergency channel for your current location when immediate help is needed.

## What changes in v6

- A new black/blue/red and white/blue/red interface, compact SOS panel, centered emergency navigation and clearer safety setup.
- A separate desktop workspace, and a phone website with the same information order as the Android app.
- An Android assistant composer that stays above the keyboard, with voice input beside Send. Browser prompts can be edited before sending.
- Contacts first in My Safety, personal tools grouped together, secondary filters and settings behind disclosures.
- Browser incident and trip drafts survive internal navigation. Save or export them before closing the tab.
- Persistent SOS cancellation across tabs, correct browser Back/reload routing, country-change filter resets and protection against stale assistant responses.
- Field-level contact validation, correct Settings Back navigation, ordered secure-storage writes and recoverable browser-storage errors.
- Exported packages exclude private environment files. A fixture-based package check verifies this.

See [the UX review](docs/V6-UX-REVIEW.md) for research, bug details and verification boundaries.

## Features and limits

| Area | Behavior |
| --- | --- |
| Reviewed directory | Choose your current country; search by service, category, region and channel. Records retain government sources, jurisdiction and verification details. Coverage varies; the country registry is broader than verified service coverage. |
| Contact channels | Phone, SMS, WhatsApp, email and web appear only where present in reviewed records. Non-urgent channels may be unsuitable for emergency dispatch. |
| Offline use | Android bundles a directory and trained intent router. The website can use its bundled/cached directory after loading. A failed database connection preserves the last reviewed snapshot, including withdrawals. |
| Assistant | Rules and intent routing select directory records. Android optionally supports a downloaded local model; an operator can configure a separate online model service. Generated text is not trusted as a contact source. |
| SOS | Review location choices, start or cancel the countdown, open the dialer, capture a position, create an optional private session, and mark safe or cancel. |
| Trusted contacts | Android contact picker/manual entry, phone/SMS/WhatsApp composers, sharing, contact export and per-recipient alert choices. Optional server alerts require consent, approved recipients and configured providers. |
| Private inbox/check-ins | Capability-based inboxes and invited-contact check-ins use PostgreSQL. A running backend processes missed check-ins. An inbox entry or provider acceptance is not proof that someone read it. |
| Incident journal | Photos, videos and notes; review attachments, save, edit, share, export ZIP and delete. Android notes are encrypted and media uses private app storage. Browser media/notes use unencrypted IndexedDB. |
| Personal tools | Trip plans, route/meeting-point notes, calendar reminders, emergency card, preparation checklist, favorites, safety history and SOS practice. |
| Display/languages | Dark/light themes, high contrast, RTL support and 32 languages for core labels. Detailed service records and some new/detailed UI wording retain English or their source wording. This is not a fully translated 64-language app. |
| Directory administration | Separate reviewer/publisher tokens, government evidence review, revision checks, audit history and source monitoring. |

The incident journal permits up to 50 entries, 10 attachments per entry, 100 MB per attachment, 200 MB per entry and 500 MB total. Browser quotas may be lower. Android capture uses an external camera app and requests a 60-second video limit. The camera app controls that limit. Device timestamps do not establish authenticity.

Journal files remain local until exported/shared. Clearing browser storage or uninstalling the Android app can erase them. Export anything you need to keep.

## Install Android

Use the [download page](https://global-sos.onrender.com/download) and check its displayed version. A source branch does not update that live page until merged and deployed.

For a new build, open a successful [Actions run](https://github.com/SupremeGenZ-Github/Global-SOS/actions/workflows/v4.yml), download **Global-SOS-v6-Android**, extract it and install **Global-SOS-v6-TEST-SIGNED.apk**. The AAB is a distribution bundle, not a directly installable APK.

- Android **8.0+**, **ARM64**.
- Current public builds use a **development/test signing key**. Different keys cannot update one another in place; do not uninstall an older app before exporting local data.
- Production signing is supported through `KEYSTORE_PATH`, `KEY_ALIAS`, `KEYSTORE_PASSWORD` and `KEY_PASSWORD` in a private build environment. Never commit a keystore or its passwords.
- Confirm country, review trusted contacts and practice SOS before relying on your setup. Location and SMS permissions are requested for the selected actions; camera/document/contact pickers open when those features are chosen.

The app does not require every permission to browse the directory. Denying optional location access still permits dialing. Automatic device SMS uses an enabled SIM, Android permission, consenting recipients and your mobile plan. WhatsApp/email/manual SMS require the user to review and send in the external app unless a separate provider integration is configured.

## Project layout

```text
android/          Flutter app, native Android bridges and tests
backend/          Express API, PostgreSQL migrations, notifications and monitoring
website/          React UI, desktop/phone layouts and browser incident journal
shared/           Directory, countries, categories, language catalogue and intent weights
scripts/          Builds, packaging, download verification and browser checks
tests/            Backend, directory, notification and browser-storage data tests
releases/android/ Verified APK parts and public release metadata
docs/             UX review and supporting material
```

In the GitHub repository, the application lives under **`Global-SOS-AI-Full-Project/`**. The standalone source/Render ZIPs place the application at their root. Run commands from the application root.

## Run locally

Use Node.js **24** (the CI version is `24.21.0`).

```bash
npm ci --include=dev
cp .env.example .env
```

For local use, set `APP_BASE_URL=http://localhost:3000` and `CORS_ORIGINS=http://localhost:3000` in `.env`. Leave `DATABASE_URL` empty for the public read-only directory, or supply your PostgreSQL provider URL.

```bash
npm test
npm run build
npm start
```

Open `http://localhost:3000`. The server serves the API and built website together. `npm run dev` starts the same backend; rebuild the website after source edits. Environment values are loaded from `.env`, then `.env.local` if present. Keep both private.

## Render and Neon PostgreSQL

For the existing GitHub repository, choose **Root Directory: `Global-SOS-AI-Full-Project`**. For the standalone Render ZIP, leave Root Directory empty.

| Render setting | Value |
| --- | --- |
| Runtime | Node |
| Build | `npm ci --include=dev && npm run build` |
| Start | `npm start` |
| Health path | `/health` |
| `APP_BASE_URL` | `https://global-sos.onrender.com` |
| `CORS_ORIGINS` | `https://global-sos.onrender.com` |
| `DATABASE_URL` | Your private Neon/Render PostgreSQL connection string |

Copy the PostgreSQL connection string from your Neon project's connection panel into Render's **Environment → DATABASE_URL**. Retain the provider's TLS parameters. Do not put this URL in the Android app, browser code or GitHub. No new database schema or required environment variable is introduced by v6.

```bash
npm run migrate
```

Migrations are additive/idempotent. Startup also supports database preparation and reconnect recovery. `/health` reports the running process; `/ready` reports database/read-only readiness. Public directory/downloads work without a database; private sessions, inboxes, scheduled check-ins, administration and provider queues need PostgreSQL.

Optional administration uses **two different random tokens**, each at least 32 characters: `ADMIN_REVIEW_TOKEN` and `ADMIN_PUBLISH_TOKEN`. Review and publishing are separate roles.

Optional provider alerts use `ALERT_CLIENT_TOKEN`, `ALERT_ALLOWED_RECIPIENTS` and the Twilio/Resend values documented in [.env.example](.env.example). Recipients must be approved and consenting. Configure approved WhatsApp templates where required. Provider credentials stay on the server; a private operator client token does not belong in public web source.

Optional online routing uses `AI_PROVIDER=openai-compatible`, `AI_BASE_URL`, `AI_MODEL` and `AI_API_KEY`. That model service runs separately. `AI_PROVIDER=none` leaves directory/rules routing available. This release has no account login/JWT system and does not provision Neon Auth, object storage or realtime services.

## Build Android

CI uses Flutter **3.38.10**, Java **17** and the pinned Android SDK/NDK configuration.

```bash
cd android
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://global-sos.onrender.com
flutter build appbundle --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://global-sos.onrender.com
```

`API_BASE_URL` is a build-time HTTPS backend address, not a database URL. The official URL is already the default. The optional model is not embedded in the APK; download/load it explicitly in Settings.

## Validation and release packages

The workflow runs project tests, TypeScript/Vite production builds, mocked browser SOS tests, mobile/desktop/RTL regressions, Flutter analysis/tests, APK/AAB builds and signature verification. It captures web and Android previews, stages verified APK parts and checks metadata, binary downloads, checksums and HTTP range behavior.

The build artifact includes APK, AAB, checksums and complete source, Render and Android-source ZIPs. Private environment files are excluded and tested with temporary fixtures. No real emergency calls or messages are made by automated checks.

Physical-device installation, camera hardware, real SIM SMS, real provider delivery, OEM permissions and your deployed database need separate checks. See [TEST_REPORT.md](TEST_REPORT.md), [PRIVACY.md](PRIVACY.md), [SECURITY.md](SECURITY.md) and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Code is provided under the [MIT license](LICENSE). Directory source material and third-party models retain their respective terms. Government webpage review does not certify live service availability or worldwide completeness.
