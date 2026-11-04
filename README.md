# Global SOS v5

Global SOS is a Flutter Android app, React website, and Node.js API for finding emergency and specialist help, preparing an SOS, and staying in touch with trusted contacts. The Android app includes an offline directory and can synchronize reviewed updates over HTTPS.

[Website](https://global-sos.onrender.com) · [Phone layout](https://global-sos.onrender.com/mobile) · [Android builds](https://github.com/SupremeGenZ-Github/Global-SOS/actions/workflows/v4.yml) · [v5 source review](https://github.com/SupremeGenZ-Github/Global-SOS/pull/5)

**Emergency use.** Global SOS is a development project without emergency dispatch certification. If you need immediate help, use the official emergency channel for your current location. The app can open the dialer after a five-second countdown. You press **Call** in the dialer. An inbox entry, message composer, or share sheet gives no assurance that someone has received or acted on the alert.

## What you can do

| Feature | How it works |
| --- | --- |
| Emergency directory | Confirm your current country, then filter reviewed records by category, region, or contact channel. Some countries and regions have limited verified coverage. |
| Offline access | Android ships with a directory snapshot and an offline intent router. The website API can serve a bundled read-only snapshot without PostgreSQL. |
| Safety assistant | Describes available routes using directory entries. Optional online model routing runs through a separately configured service. Contact details come from the directory. |
| SOS and location | Start or cancel a countdown, review a timestamped location fix, and choose whether to share it. Older fixes are labeled. |
| Trusted contacts | Open SMS or WhatsApp composers, share through another app, or send to a private Global SOS inbox. The recipient can mark an inbox alert as opened. |
| Check-ins and emergency cards | Schedule a check-in for an invited contact, mark yourself safe, or use a locally stored emergency card. A running backend processes missed check-ins. |
| Desktop and mobile | The website offers a desktop console and a phone-style layout. Both the website and Android have light and dark themes. |

## Trip tools on the website

Open **My Safety** to prepare a trip plan with a destination, route, backup meeting point, and check-in time. Preview the text before sharing. You can save or clear the plan in the current browser, share it through another app, copy it where supported, or download it as a text file. Saved plans use unencrypted browser storage.

- **Calendar reminder.** Download the `.ics` file, import it into your calendar, and confirm the reminder. This is a personal reminder. For a missed check-in alert to an invited contact, use the separate server-backed check-in feature.
- **Trusted-contact export.** Download an individual contact as a `.vcf` file under **Edit trusted contacts**. The file contains the contact's name and phone number.
- **SOS practice.** Run or cancel a five-second countdown on the web page. The drill has no call, message, location, or permission action.

## Install Android

1. Open the [v5 Actions workflow](https://github.com/SupremeGenZ-Github/Global-SOS/actions/workflows/v4.yml) and select a successful run for the commit you want.
2. Download the `Global-SOS-v5-Android` artifact and extract it. Use the `Global-SOS-v5-TEST-SIGNED.apk` file on a supported ARM64 Android device. The AAB is a distribution bundle.
3. Open the app, confirm your country, and check **Settings → Website & backend**. The app defaults to `https://global-sos.onrender.com`. Use **Synchronize directory** to request an update.
4. Set up trusted contacts under **My Safety**. Android may ask for location or SMS permissions depending on the feature you choose.

The [previous verified v5 artifact](https://github.com/SupremeGenZ-Github/Global-SOS/actions/runs/41851441430/artifacts/13337385159) predates the latest URL and localization fixes. Test signing is for development. An APK signed with a different key cannot update an existing installation in place. Uninstalling can erase local data.

The website has a [download page](https://global-sos.onrender.com/download). Its APK depends on the release files staged in that deployment, so check the displayed version.

## Run the website and API locally

The application lives under `Global-SOS-AI-Full-Project/` in this repository. If you extracted a release ZIP, run commands in the directory containing `package.json`. Node.js **24.21.0** matches CI.

```sh
cd Global-SOS-AI-Full-Project
npm ci --include=dev
npm run build
npm start
```

Open [localhost:3000](http://localhost:3000). Copy [`.env.example`](Global-SOS-AI-Full-Project/.env.example) to `.env` if you need local settings. For browser requests, set both `APP_BASE_URL` and `CORS_ORIGINS` to `http://localhost:3000`. Keep secrets out of Git and Android builds.

| Setting | Purpose |
| --- | --- |
| `PORT` | Local HTTP port. Defaults to `3000`. |
| `APP_BASE_URL`, `CORS_ORIGINS` | Public URL and allowed browser origin. Use the exact deployed HTTPS origin in production. |
| `DATABASE_URL` | PostgreSQL connection string for private inboxes, check-ins, live sessions, and directory administration. Preserve the provider’s TLS options. |
| `ADMIN_REVIEW_TOKEN`, `ADMIN_PUBLISH_TOKEN` | Separate private tokens for proposal and publication roles. Each must be at least 32 characters. |
| `AI_PROVIDER`, `AI_BASE_URL`, `AI_MODEL`, `AI_API_KEY` | Optional online intent routing. The bundled routing works with `AI_PROVIDER=none`. |
| `ALERT_CLIENT_TOKEN`, `ALERT_ALLOWED_RECIPIENTS`, provider credentials | Optional operator-managed alerts. Configure consenting recipients and the applicable Twilio or Resend settings in the environment template. |
| `MONITOR_CONTACT`, `DIRECTORY_UPDATE_INTERVAL` | Optional government source monitoring. Changes go to review before publication. |

Startup applies database migrations and seeds missing records when PostgreSQL is configured. Run `npm run migrate` to prepare the database manually. `/health` reports process health and `/ready` reports readiness, including PostgreSQL when configured. API details are in [the API reference](Global-SOS-AI-Full-Project/docs/API.md).

## Deploy the web app to Render

1. Connect the repository as a Node web service. For this repository layout, set the service **Root Directory** to `Global-SOS-AI-Full-Project`. If the extracted Render ZIP is at your repository root, use that root. The supplied [Render blueprint](Global-SOS-AI-Full-Project/render.yaml) sits in the application directory.
2. Use build command `npm ci --include=dev && npm run build` and start command `npm start`. Set the health check path to `/health`.
3. Set `APP_BASE_URL` and `CORS_ORIGINS` to your actual HTTPS origin. For database-backed features, add the connection string from Neon or Render PostgreSQL as `DATABASE_URL`.
4. Deploy and check `/health`, `/ready`, and the directory. Test private inboxes and check-ins with consenting test contacts before offering them to users.

A sleeping or unavailable server can delay check-ins. To publish a specific Android build on `/download`, stage its verified APK before rebuilding the website, or deploy the Render ZIP from the matching Actions artifact.

## Build Android from source

Use Flutter **3.38.10**, Java **17**, Android platforms **34–36**, Build Tools **36.0.0**, NDK **28.2.13676358**, and CMake **3.22.1**, as configured in CI. Run from the application directory:

```sh
cd android
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://global-sos.onrender.com
flutter build appbundle --release --target-platform android-arm64 --dart-define=API_BASE_URL=https://global-sos.onrender.com
```

Look for the APK at `build/app/outputs/flutter-apk/app-release.apk` and the bundle at `build/app/outputs/bundle/release/app-release.aab`, relative to the Flutter project. CI verifies signatures and generates `SHA256SUMS.txt`. Use your own production signing credentials for distribution.

## Languages and content review

Core navigation and Home and Assistant introductions support **32 languages**. Telugu, Hindi, and Tamil have additional safety-tool and inbox translations. Telugu **Home** is **ప్రధాన పేజీ**. Some instructions and status text still appear in English. Official service names and messages written by users can appear in their original language.

The [shared catalog](Global-SOS-AI-Full-Project/shared/languages.json) and [Android catalog](Global-SOS-AI-Full-Project/android/assets/languages.json) should match. Review translated instructions in context, especially when they tell people how to call, cancel, share a location, or send an alert.

For directory updates, submit a proposal with the official source and applicable jurisdiction. A separate publisher reviews the evidence and approves the change. A source-monitor alert only flags a page change for review. See [helpline sources](Global-SOS-AI-Full-Project/HELPLINE_SOURCES.md).

## Project layout

| Path inside the application directory | Contents |
| --- | --- |
| `android/` | Flutter app and native Android project |
| `website/` | React, TypeScript, and Vite frontend |
| `backend/` | Express API, directory review, and safety services |
| `database/` | PostgreSQL migrations |
| `shared/` | Directory data, intent router, and translations |
| `offline-model/` | Optional local model setup |
| `scripts/`, `tests/` | Builds, packaging, and automated checks |
| `docs/` | API reference, setup, and limitations |

The source repository also contains GitHub workflows in `.github/workflows/`.

## Tests and release status

From the application directory:

```sh
npm test
npm run build
node --test tests/languages.test.mjs
```

The [previous v5 CI run](https://github.com/SupremeGenZ-Github/Global-SOS/actions/runs/41851441430) passed the web and Android builds and artifact checks for its commit. After the later translation edits, the website production build, localization tests, and Dart analysis passed locally. The browser smoke test could not launch locally, and a fresh APK with those edits has yet to be verified. Automated tests use simulated delivery and do not establish that a real emergency call or alert reached anyone.

## Privacy, security, and license

Keep private inbox keys and live-location links private. Share only the inbox invite with trusted contacts. Inbox messages expire after seven days. Marking a live SOS safe or cancelling it ends location sharing and removes stored positions. Medical notes stay local unless you explicitly export or share them.

See the [privacy policy](Global-SOS-AI-Full-Project/PRIVACY.md), [security policy](Global-SOS-AI-Full-Project/SECURITY.md), and [known limitations](Global-SOS-AI-Full-Project/docs/LIMITATIONS.md).

The project source uses the [MIT License](Global-SOS-AI-Full-Project/LICENSE). Separate terms may apply to bundled components and optional models. See [third-party notices](Global-SOS-AI-Full-Project/THIRD_PARTY_NOTICES.md).
# Global SOS v4.12

Connection recovery, 32-language core navigation, clearer online status and an emergency-siren website interface. [Read the setup guide](docs/V41-SETUP.md).

# Global SOS v4

Native Android and web safety tools connected to https://global-sos.onrender.com.

See [v4 setup and limitations](docs/V4-SETUP.md) for SOS permissions, trusted-contact automation, PostgreSQL, Render configuration and Android builds.

# Global SOS AI — v0.3.0

One Tap. One Conversation. Help Anywhere.

This is a development release of a connected Flutter Android app, React/TypeScript website and Express/PostgreSQL API. **It is not certified for emergency dispatch or production reliance.** The directory works without an AI key. Calling and message buttons open external apps; they do not confirm connection or delivery.

## New in 0.3

The website now has a public **/download** page and serves the actual APK without a ChatGPT login. The full and Render ZIPs include checked Android release parts; build/start reconstructs and validates the download automatically. Keep the releases/android directory when uploading the source to GitHub. No database or API key is required for downloads.

Personal readiness checklists are available on Android and the website. The website also adds printable emergency cards, contact editing, favorites-only filtering, sorting and setup diagnostics. See [the 0.3 upgrade guide](docs/UPGRADE-v0.3.md).

## Upgrade from 0.1

Read [the upgrade and provider configuration guide](docs/UPGRADE-v0.2.md). The SOS button now opens the native emergency dialer after five seconds. New source-checked specialist contacts, messaging channels, regional filtering, voice controls and country suggestions are included. See [the complete feature status](docs/FEATURE_STATUS.md) for implementation and device-validation boundaries.

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
7. In Android Settings, enter the HTTPS Render URL and tap **Synchronize directory**. Alternatively set it in the GitHub build workflow input.

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
```

The database tests use PGlite's actual PostgreSQL engine in-process. They do not prove connectivity to an external Neon/Render database. See `docs/API.md`, `SECURITY.md`, `PRIVACY.md`, and the execution evidence in `docs/evidence/`.

### Global SOS v5 safety tools

Open **My Safety** on web or Android to create an inbox and share its invite with a trusted contact. Keep the inbox owner key private. The invite can receive alerts but cannot read inbox contents. Recipients check the inbox in the app or web. Inbox messages expire after seven days. Missed check-ins are queued by PostgreSQL and processed while the backend is running. Use an always-running deployment for timely check-ins.

SMS and WhatsApp compose screens require the user to send the message. Existing opt-in automatic alert channels require their configured Android permissions or server provider credentials. The general share sheet hands the text to the chosen app. Provider acceptance, inbox storage and recipient opening have separate meanings.

The desktop console is available at /desktop and the phone layout at /mobile. Location sharing requests a foreground fix on demand and labels older or retained coordinates with their capture time. Medical notes stay local unless the user explicitly exports or shares them. The offline intent router uses 200 synthetic training examples across 25 categories and falls back to directory choices when uncertain.
