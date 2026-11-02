# Global SOS v4 (0.4.0)

## App and website connection

The Android app defaults to https://global-sos.onrender.com. It fetches the website's
/api/directory on startup and on resume after five minutes, saves validated snapshots in
SQLite and retains the offline directory on failures. Settings can override the HTTPS URL.
The app uses the site's backend API; the native interface and directory also work offline.

## SOS

1. Confirm the current country in Settings.
2. Add a trusted person manually or choose one through the phone's contact picker.
   Only the selected contact is read; broad address-book permission is unnecessary.
3. In My Safety, record the person's consent, select permitted methods, and enable automatic alerts.
4. Android: optionally enable device SMS. This asks for SEND_SMS permission on SOS.
   Use international trusted-contact numbers. Your SIM/mobile plan may charge for SMS.
   Select a default SIM in Android settings. No READ_SMS or call-log permissions are requested.
5. Press SOS, choose whether to include a fresh location, and allow location access if desired.
   After the cancellable five seconds, the country-specific police number opens in the dialer.
   Android requires you to press Call for emergency calls. Denying GPS does not prevent dialing.
6. Automatic alerts wait for the fresh location attempt, independently of opening the dialer.
   Location denial/failure gives an alert without a position. The message never includes medical notes.
   Device SMS submission is shown separately from actual delivery, which is unconfirmed.
   Already submitted messages cannot be recalled by cancelling SOS.

Android phone SMS works without PostgreSQL or provider credentials. WhatsApp and email automation
use server providers. The website cannot silently send SIM SMS or place emergency calls; it uses
the configured server for automatic alerts and opens phone/SMS apps for manual actions.

Only foreground location sharing is implemented. Android may suspend or terminate work after the
dialer opens; this version does not guarantee background execution or resend missed alerts.
Live delivery and real-device behavior must be checked with consenting test contacts before relying
on the setup. Never test by calling emergency services.

## PostgreSQL integration

The integration code is in backend/server.mjs, backend/store.mjs and database/001_initial.sql.
Use a PostgreSQL connection string from Render or Neon, with its TLS parameters preserved.

In Render > your existing service > Environment set:

```dotenv
NODE_ENV=production
APP_BASE_URL=https://global-sos.onrender.com
CORS_ORIGINS=https://global-sos.onrender.com
DATABASE_URL=postgresql://USER:PASSWORD@HOST/DATABASE?sslmode=require
```

Replace the DATABASE_URL example with the actual private value in Render. Never commit .env
or embed database/provider credentials in the Android app or browser bundle.
Startup applies additive migrations and seeds source-checked data without resetting admin changes.
For a manual migration use `npm run migrate` from Global-SOS-AI-Full-Project.
Without a database the directory remains available in read-only mode; server SOS sessions,
private links and provider alerts require PostgreSQL. /ready reports the storage status.
If a configured database fails, server writes are unavailable and saved offline data is retained.

## Automatic server alerts (Android and web)

Set these private values in Render:

```dotenv
ALERT_CLIENT_TOKEN=GENERATE_A_SEPARATE_RANDOM_TOKEN_OF_AT_LEAST_32_CHARACTERS
ALERT_ALLOWED_RECIPIENTS=+YOUR_CONSENTING_CONTACT_NUMBER,consenting-contact@example.com
TWILIO_ACCOUNT_SID=
TWILIO_AUTH_TOKEN=
TWILIO_SMS_FROM=
TWILIO_WHATSAPP_FROM=
TWILIO_WHATSAPP_TEMPLATE_SID=
RESEND_API_KEY=
ALERT_EMAIL_FROM=
```

Configure only the providers you need: Twilio SMS, an approved Twilio WhatsApp template
(with variable 1), or Resend email with a verified sender. Enter the matching private
ALERT_CLIENT_TOKEN under My Safety on each client; the website holds it only in page memory,
and Android uses encrypted storage. Never embed it in a public build.
This is an operator-controlled, allowlisted deployment: arbitrary website visitors cannot
send provider alerts until their consenting recipients are approved. Multi-user accounts
and per-user messaging credentials are not implemented.

Enable the contact's consent and methods, then enable automatic alerts.
Only exact allowlisted recipients are accepted. Existing server idempotency prevents a
repeated session/recipient/method submission. Device SMS recipients are excluded from the
automatic server SMS attempt when Android accepted the device submission.
Manual resubmission after an uncertain device result can duplicate messages; check results first.
Use the status refresh button to obtain actual provider states.
Queued/accepted/sent must never be interpreted as delivered.

## Deploying this repository

The source is inside Global-SOS-AI-Full-Project, not the repository root.
For an existing Render service, set Root Directory to Global-SOS-AI-Full-Project,
Build Command to `npm ci --include=dev && npm run build`, and Start Command to `npm start`.
The repository-root render.yaml uses that rootDir for a new Blueprint.
Do not create a second service just to update your existing global-sos deployment.

## Build and signing

The repository-root .github/workflows/v4.yml runs web/backend checks and Flutter tests,
builds the ARM64 release APK and AAB and uploads them as Global-SOS-v4-Android artifacts.
GitHub Actions workflows nested inside the project directory were not runnable; the new
workflow lives at the repository root. Actions must be enabled on the repository.

The CI build uses a development signing key. This is a testing APK, not a Play-ready release.
A different signing certificate from the previous downloaded APK requires uninstalling
the previous app or rebuilding with its original key. Export any local safety data first.
Production updates require your existing private upload key; never commit a keystore.
SEND_SMS is restricted on Google Play. Declare the physical-safety/emergency-alert use case
and obtain the required approval before publishing. This build does not assert Play approval.

The existing website APK remains v0.3 until the verified v4 binary is staged with
scripts/stage-android-release.mjs; a successful source build does not update its release chunks.
Do not relabel the old APK as v4.

## Validation status

CI checks, artifact signatures and physical-device checks must be read from the current run.
Old v3 evidence under docs/evidence does not validate v4.
Live Render connectivity, PostgreSQL credentials, real calls, SIM messages and provider delivery
are not validated by mocked tests. No real emergency call or provider message is made by CI.
