# Global SOS 4.1: connection repair and PostgreSQL setup

The deployed v4 server was reachable, but /ready returned database_unavailable and /api/directory returned HTTP 503. Both clients therefore used their local directory. Directory version 2 is the contact dataset version, not the application release number.

## What changes in 4.1

- Public directory and basic helpline routing remain readable if PostgreSQL is missing or temporarily fails.
- Clients keep their existing reviewed cache when the server returns non-authoritative fallback data. This avoids restoring withdrawn services into a reviewed local snapshot.
- The server retries database initialization every 30 seconds. No tables or existing confirmed data are reset.
- /api/status reports server, directory and database availability separately. /ready still returns 503 while a configured database is unavailable; writes and provider alerts stay disabled until the database is ready.
- The website has a new emergency-siren SVG button, consistent navigation icons, refreshed cards and mobile layouts, light/dark styling and right-to-left layout support.
- Both clients offer 32 languages for core navigation and SOS labels. Official records, detailed instructions and many dynamic messages remain in their original wording. This is not a full translation of every screen. Basic multilingual intent keywords work without an LLM. Voice recognition and TTS still depend on installed device language services.

## Activate PostgreSQL on Render

1. Open https://dashboard.render.com/new/database or choose New > Postgres.
2. Name it global-sos-db. You can leave Database and User blank to let Render generate them. Choose the same region as your existing global-sos web service. Use the provider's offered PostgreSQL version and select an appropriate plan.
3. Create the database and wait until it is Available.
4. Open its Connect menu and copy the complete Internal Database URL. Internal URLs work only within the same Render region/account. If the database already exists, reuse it instead of creating another.
5. Open the existing global-sos WEB SERVICE, choose Environment, and set DATABASE_URL to the copied PostgreSQL URL. It starts with postgres:// or postgresql://. Never use https://global-sos.onrender.com here.
6. Keep APP_BASE_URL and CORS_ORIGINS set to https://global-sos.onrender.com.
7. Choose Save and deploy. Startup creates the schema and seeds source-checked records automatically. No manual SQL editor step is required. Existing admin changes are preserved.
8. Open https://global-sos.onrender.com/ready. A successful connection returns status ready and storage postgresql. In 4.1, /api/status also shows database.ready true.

If you already use Neon, open the Neon project > Connect and copy its complete PostgreSQL connection string instead. Preserve its SSL/TLS query parameters. Never substitute the website URL or paste the database password into chat.

## Using the supplied .env

Fill DATABASE_URL in the downloadable .env template. In Render's web service Environment page, use Add from .env, import the values and choose Save and deploy. Keep any existing nonempty admin, AI or messaging secrets; the template comments do not replace those secrets. The completed .env must not be committed to GitHub or bundled into the APK.

Required production values:

```dotenv
NODE_ENV=production
PORT=10000
APP_BASE_URL=https://global-sos.onrender.com
CORS_ORIGINS=https://global-sos.onrender.com
DATABASE_URL=PASTE_THE_COMPLETE_POSTGRESQL_URL_HERE
AI_PROVIDER=none
```

AI_PROVIDER=none keeps basic directory routing available without a hosted LLM. A generative online model requires a separately configured OpenAI-compatible provider; a PostgreSQL connection does not create an LLM.

## Website deployment

Root Directory: Global-SOS-AI-Full-Project when deploying this GitHub repository.
Build Command: npm ci --include=dev && npm run build
Start Command: npm start
Runtime: Node.js (the project pins Node 24).

The website does not change until the new source is deployed. The verified Render ZIP produced by CI includes the updated APK for /download. If deploying the repository source directly, stage the new verified APK first; the previous release parts are retained in source until replaced with a verified build.

## Android

Version 0.4.1+5. The native app defaults to https://global-sos.onrender.com, preserves its local directory on server failures and provides an interface-language selector in Settings. Server errors now include an actionable description. Direct emergency calling remains restricted: the five-second SOS countdown opens the dialer and the user presses Call. Automatic SMS/provider alerts retain their existing consent, configuration and permission requirements.

## Limits

The update cannot supply your private DATABASE_URL, create a paid database without your choice, or validate live provider delivery without configured credentials. A successful automated build does not establish real-device call or SMS delivery. Test-signed APKs may require removing an older APK with a different certificate; preserve local contacts first.

Sources: https://render.com/docs/postgresql-creating-connecting and https://render.com/docs/configure-environment-variables
