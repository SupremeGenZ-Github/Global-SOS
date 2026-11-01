# Global SOS AI 0.3 — new features and website APK downloads

## Install or deploy

Install the new ARM64 Android 8+ APK over 0.2.0. The application ID and development signing key remain the same. Physical-phone upgrade is not tested.

For the website, replace the source in your GitHub repository with the extracted contents of the new Render ZIP or full project ZIP. Keep your existing environment variables and PostgreSQL database. The public APK download does not need a database, AI key or administrator token.

Use the existing Render commands:

```
Build: npm ci --include=dev && npm run build
Start: npm start
```

Once deployed, open `https://YOUR-SERVICE.onrender.com/download`. The home page and navigation also link to this page.

## Public APK download

The source package includes the actual signature-verified APK as checked release parts in `releases/android/`. Both build and startup automatically reconstruct and validate it. Upload every release part along with the supplied manifest. You do not need to assemble files yourself.

The download page displays the version, size, SHA-256, compatibility, signing status and installation instructions. It provides a direct APK attachment and checksum file. If the release is absent or fails validation, the download is unavailable instead of linking to an incorrect binary. APK responses support HTTP HEAD and byte ranges. Service-worker caching excludes APK downloads.

The public routes are:

```
/download
/api/releases/android
/downloads/Global-SOS-AI.apk
/downloads/Global-SOS-AI.apk.sha256
```

Visitors do not need a ChatGPT account or application account. The website serves its own release bytes. No automatic installation occurs. The APK is development/test signed; use a retained production key before publishing a production distribution.

For a future release, use `node scripts/stage-android-release.mjs /path/to/Global-SOS-AI.apk /path/to/APK-BUILD-RESULT.json` after signature verification. The supplied build metadata must match the APK's checksum and byte size and declare `signature_verified: true`. Commit the updated parts and manifest and redeploy. Never edit the manifest to disguise an unverified APK.

## New personal safety tools

- Android and website: a personal readiness checklist with persistent, user-marked tasks and Reset. It is a reminder list, not a professional safety assessment.
- Android Settings: a shortcut to the configured website's APK download page. Enter your HTTPS backend/website URL first.
- Website: printable emergency card with current country, a source-checked local emergency shortcut and trusted contacts. Print it or use the browser's Save as PDF option. Optional medical notes appear only after you enable their inclusion.
- Website: contact editing, favorites-only directory filter, sorting by name/region, clear filters and result counts.
- Website Settings: a setup check for server health, database/directory readiness and APK availability. It never calls emergency services or submits provider messages.
- Website assistant: basic offline app guidance can answer supported app questions and greetings before country selection. Emergency contact routing still requires the current country.

Android checklist data uses encrypted private safety storage. Website checklist and optional medical-card notes use local browser storage; the website does not encrypt this browser storage. Printing includes only the contacts and medical notes shown on the card. Do not print sensitive notes unless you intend to share the card.

The v0.2 SOS, provider-alert, offline-model and location requirements remain unchanged. Consult `UPGRADE-v0.2.md` for those settings. Directory coverage is unchanged in 0.3; no new contact details were invented. Physical-device capabilities and live messaging delivery remain untested.
