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
