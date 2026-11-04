# Global SOS v5

Global SOS is an Android app and website for finding emergency contacts, preparing an SOS, and coordinating with trusted contacts. The Android app starts with a bundled offline directory and synchronizes updates from the HTTPS server.

[Live website](https://global-sos.onrender.com) · [v5 source and review](https://github.com/SupremeGenZ-Github/Global-SOS/pull/5)

## Start here

- Open the website on a computer for the desktop console, or use the [phone layout](https://global-sos.onrender.com/mobile).
- Select your current country before using the directory. A listed country may have incomplete contact coverage.
- Use **My Safety** to manage trusted contacts, open a private inbox, and schedule a check-in.
- Use the official emergency channel when you need immediate help. Global SOS is a development release and has no emergency dispatch certification.

## Languages

The website and Android app use the same bundled catalog. The language picker offers **32 languages** for core navigation and the Home and Assistant introductions. Telugu, Hindi, and Tamil also have translated safety tools, location-sharing controls, and private inbox and check-in actions. Telugu **Home** is **ప్రధాన పేజీ**.

Coverage varies by screen. Untranslated interface text falls back to English. Official directory entries and user-written messages can appear in their original language. The 64-language expansion and complete screen coverage are still open.

## What's in v5

- Separate desktop console and phone-style layouts, with light and dark themes.
- Trusted-contact alerts through private Global SOS inboxes, SMS and WhatsApp composers, and the system share sheet.
- Scheduled check-ins, timestamped location previews, discreet alerts, and offline emergency cards.
- Offline intent routing trained on 200 synthetic examples across 25 categories. The assistant uses reviewed directory entries for contact details.

## What is implemented

- Government-page sourced directory bundled into Android; SQLite stores approved synchronized snapshots atomically. All 193 UN member states are selectable, with extra territories. A country entry does not imply verified contact coverage.
- Telephone, SMS and officially published WhatsApp links. Email and web channels are seeded where government sources publish them.
- Search/category/channel filtering, favorites, country confirmation and accessible navigation.
- Offline rules plus optional real llama.cpp model inference on ARM64 Android. The model performs **intent classification**, not medical advice or a general conversational tutor. Inference output is reduced to an allowed category; model-generated contacts are never displayed.
- Optional server-side OpenAI-compatible model routing, consent switch, timeouts, rate limits and local fallback.
- SOS countdown, cancel, local history, GPS capture, encrypted Android trusted-contact storage, message composers and Mark Safe.
- Opt-in foreground location sharing through private capability-protected server sessions. No account is required. Links expire in one hour; Mark Safe/Cancel erases positions.
- Administrator proposal/review queue, independent reviewer/publisher tokens, immutable previous record revisions, atomic directory version increments and stale-review rejection.
- Government source page-change monitoring with robots checks. Changes queue for review and never publish contact data automatically.

See `TEST_REPORT.md` for executed checks, `docs/LIMITATIONS.md` for unimplemented requirements and `HELPLINE_SOURCES.md` for current coverage. Source checking is not live-service testing.

## Folder layout

```text
android/             Flutter project (native Android project is android/android/)
website/             React + TypeScript + Vite
backend/             Express API, PostgreSQL adapter, source monitor
database/            Additive SQL migration
shared/              Directory snapshot and category definitions
offline-model/       Model installation notes and preparation script
tests/               API, database and safety tests
docs/                API, limitations, deployment and test evidence
.github/workflows/   Android builds and web/backend checks
```

## Run the website locally

Install Node.js 24.21.0, extract the full or Render source ZIP, then run in its root:

```sh
npm ci --include=dev
npm run build
npm start
```

Open `http://localhost:3000`. With no `DATABASE_URL`, the directory and chat routing use a read-only bundled snapshot. Database-backed administrative updates and live sessions return an explicit unavailable response. For local browser POST requests, copy `.env.example` to `.env`, set `APP_BASE_URL=http://localhost:3000`, and `CORS_ORIGINS=http://localhost:3000`.

To enable writes, set `DATABASE_URL` to your PostgreSQL connection string, retain the provider's TLS parameters, and restart. Startup runs the additive migration and seed automatically. Existing records are preserved: seed insertion uses `ON CONFLICT DO NOTHING`. Failed initialization never resets a database. Manual database preparation:

```sh
npm run migrate
```

## Render + Neon or Render PostgreSQL

1. Create an empty GitHub repository. Extract the Render or full ZIP and upload its contents so `package.json` and `render.yaml` are at the repository root. Do not upload the ZIP itself as your only repository file. Include hidden `.github` and `.gitignore` files; GitHub's Node `.gitignore` template is appropriate if creating the repository first, but retain this project's supplied file.
2. Create PostgreSQL in Neon or Render. Copy its application connection string. Keep passwords private; never embed the database URL in Flutter or browser code.
3. In Render, choose **New → Blueprint** and connect the repository, or use **New → Web Service**, runtime Node, build `npm ci --include=dev && npm run build`, start `npm start`.
4. Set `DATABASE_URL`, `APP_BASE_URL=https://your-service.onrender.com`, and `CORS_ORIGINS` to that exact website origin. Do not include a trailing slash in origins.
5. For admin features, use two different randomly generated tokens of at least 32 characters as `ADMIN_REVIEW_TOKEN` and `ADMIN_PUBLISH_TOKEN`. The Blueprint generates them. For source monitoring, set `MONITOR_CONTACT` to a real operator contact, first review applicable government site terms, and set the interval in seconds.
6. Deploy. `/health` checks that the process is alive. `/ready` checks PostgreSQL if configured. A failed configured database yields 503 readiness; restart/redeploy after repairing connectivity.
7. Android defaults to `https://global-sos.onrender.com`. For a separate deployment, enter its HTTPS URL in Android Settings and tap **Synchronize directory**, or set the URL when building the app.

The app uses only HTTPS APIs. Android never connects directly to PostgreSQL. Render deployments and external account setup were not performed as part of local packaging. A free web service may sleep; use infrastructure suitable for your actual availability requirements before relying on a hosted emergency-assistance service. Database and model hosting costs are separate.

## Build APK and AAB without local Android tools

The full source ZIP includes `.github/workflows/build-android.yml`. The workflow is intended for a repository containing the complete monorepo, not just the nested Flutter directory.

1. Upload full project contents to GitHub, including `.github/workflows/` and `android/pubspec.lock`.
2. Open **Actions → Build Android APK and AAB → Run workflow**. Optionally enter your HTTPS Render URL. Leave production signing off for an installable development artifact.
3. When successful, open that run and download the `Global-SOS-AI-Android` artifact ZIP. It contains the APK, AAB and checksums.
4. Transfer the APK to an ARM64 Android 8+ phone and install it after enabling installation from that trusted source. Review permissions on the device. An AAB is for Play distribution and is not directly installable.

Workflow runs fail on analysis/tests/build errors and do not upload empty files. This package does not claim a remote Actions run has succeeded unless `TEST_REPORT.md` records one.

## Local Flutter build

Pinned SDK: Flutter 3.38.10 / Dart 3.10.9, Java 17. Android command-line SDK plus platforms 35 and 36, build tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1. The native model plugin supports **arm64-v8a only** in this release. Tablets and other ABIs have not been validated.

The supplied native Android project is complete. Only if regenerating an absent platform directory, run `npm run prepare:android` from the monorepo root. Then:

```sh
cd android
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://your-service.onrender.com
flutter build appbundle --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://your-service.onrender.com
```

Outputs: `android/build/app/outputs/flutter-apk/app-release.apk` and `android/build/app/outputs/bundle/release/app-release.aab`, relative to the monorepo root. Android runtime permissions, actual model inference, calls and device installation require separate device validation.

## Signing

Without production credentials, release-mode builds use the generated **development debug key**. They must be labeled TEST-SIGNED and are unsuitable for Play publication or a stable production update identity. Keep an existing key if you want future test APKs to update an installed app; replacing the key requires uninstalling first, which can erase local data.

Create and retain a permanent upload keystore on your own secure computer:

```sh
keytool -genkeypair -v -keystore upload.jks -keyalg RSA -keysize 3072 -validity 10000 -alias upload
```

Back up the keystore and passwords securely. Never commit them. In GitHub repository Actions secrets, configure `KEYSTORE_BASE64` (base64 contents of the keystore), `KEY_ALIAS`, `KEYSTORE_PASSWORD`, and `KEY_PASSWORD`. Run the workflow with production signing enabled. Locally, set `KEYSTORE_PATH`, `KEY_ALIAS`, `KEYSTORE_PASSWORD`, and `KEY_PASSWORD`. All four are required. Use Play App Signing according to Google's documentation and review current Play policies, privacy declarations and target-SDK requirements before publication.

## AI configuration

Offline model: `HuggingFaceTB/SmolLM2-360M-Instruct-GGUF`, Q8_0, exact revision and checksum in `android/assets/model.json`. Size: 386,404,992 bytes, Apache-2.0. Runtime: `llama_flutter_android` 0.2.6 / llama.cpp, CPU inference. Download and load it from Android Settings. Integrity is verified before loading. Missing model, download failure and inference timeout retain the deterministic directory router. English-focused; multilingual performance is not validated. No API key is required. See `offline-model/README.md`.

Online mode requires your own OpenAI-compatible model service. Run the same model through a compatible llama.cpp server on a suitable separate machine:

```sh
llama-server -m smollm2-360m-instruct-q8_0.gguf -c 2048 --host 127.0.0.1 --port 8080
```

Set `AI_PROVIDER=openai-compatible`, `AI_BASE_URL=http://127.0.0.1:8080/v1`, `AI_MODEL=smollm2-360m-instruct`, optional `AI_API_KEY`, and `AI_TIMEOUT_MS=10000`. For a remotely hosted model, use HTTPS and authentication. Do not point a Render service at `localhost` unless the model actually runs in that same service; use its secured network endpoint instead. This web service does not install or host a model automatically, and a free 512 MB web-service instance is not a practical default model host.

Online requests send only the current chat message and routing instructions. No conversation storage or location is added. Emergency rules take priority over model inference. The UI reports the actual router used.

## Administrator review

Open the website's Admin page. Use the reviewer token to load an existing record, edit its JSON, retain its approved `source_id` and exact `source_url`, and submit. Unknown categories, invalid contact formats and unknown/unapproved sources are rejected. Government domains must be manually vetted before a maintainer approves a new source in PostgreSQL; a domain's appearance alone is not evidence.

Sign out and use the **different publisher token**. Check the government page yourself, jurisdiction, immediate-emergency suitability and all channels, add evidence notes and approve. Publication records history and increments the directory version in one transaction. Stale pending proposals are rejected. A page-change alert is not a contact proposal and cannot directly publish numbers. Resolve it after inspection, then submit a separate record proposal if an update is needed.

## Checks

```sh
npm test
npm run build
npm audit --omit=dev
node --test tests/languages.test.mjs
```

The database tests use PGlite's actual PostgreSQL engine in-process. They do not prove connectivity to an external Neon/Render database. See `docs/API.md`, `SECURITY.md`, `PRIVACY.md`, and the execution evidence in `docs/evidence/`.

### Global SOS v5 safety tools

Open **My Safety** on web or Android to create an inbox and share its invite with a trusted contact. Keep the inbox owner key private. The invite can receive alerts but cannot read inbox contents. Recipients check the inbox in the app or web. Inbox messages expire after seven days. Missed check-ins are queued by PostgreSQL and processed while the backend is running. Use an always-running deployment for timely check-ins.

SMS and WhatsApp compose screens require the user to send the message. Existing opt-in automatic alert channels require their configured Android permissions or server provider credentials. The general share sheet hands the text to the chosen app. Provider acceptance, inbox storage and recipient opening have separate meanings.

The desktop console is available at /desktop and the phone layout at /mobile. Location sharing requests a foreground fix on demand and labels older or retained coordinates with their capture time. Medical notes stay local unless the user explicitly exports or shares them. The offline intent router uses 200 synthetic training examples across 25 categories and falls back to directory choices when uncertain.
