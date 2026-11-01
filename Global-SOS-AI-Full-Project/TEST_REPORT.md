# Global SOS AI 0.3.0 — test report

Generated 2026-11-01T13:38:15.806Z. Only executed checks are reported as passed.

| Check | Result | Evidence |
|---|---|---|
| Flutter static analysis | PASSED, no issues | docs/evidence/v2-analyze.txt |
| Flutter unit/widget regression suite | PASSED, 11 tests | docs/evidence/v2-flutter-tests.txt |
| Backend/API/PostgreSQL/provider-adapter tests | PASSED, 18 tests | docs/evidence/v2-backend-tests.txt |
| TypeScript and website production build | PASSED | docs/evidence/v2-web-build.txt |
| Android APK and AAB build | PASSED | Gradle assembleRelease and bundleRelease completed locally |
| APK signature | PASSED | Android apksigner verification |
| AAB signature | PASSED | Java jarsigner verification |
| Production dependencies | Previously audited, no production dependency changes in 0.2 | docs/evidence/npm-audit.txt |

## Scope verified

The SOS widget tests inject a fake dialer and prove a five-second delay, exactly one launch with India's 112, cancellation and cancellation on background interruption. No real emergency call was placed. Tests also check country isolation, offline navigation/routing, valid deep links, regional filtering that retains national services, offline geographic suggestions/uncertainty, basic app guidance and arithmetic.

Backend tests use PGlite's PostgreSQL engine, real migrations, admin role separation, versioned publication, withdrawal preservation, expiry, private capabilities, location deletion, input validation, CORS, rate limits, source monitoring and online-provider failure handling. Provider adapters use mocked HTTP responses: they test private authorization, recipient allowlisting, idempotency, queued vs delivered status, missing configuration and ambiguous failures. No paid provider was contacted.

Directory: 525 source-checked services; 625 channels; 186 UN members plus 11 additional territories have records. National primary-service records exist for 184 UN members. Government-page verification is not an operational call test. Download route tests cover public metadata, exact response bytes, HEAD, byte ranges, checksums, missing or tampered releases, and corrupted release-part rejection. Checklist widget tests cover change reporting and reset. The data covers specialist services unevenly; it is not a complete list of every local helpline.

## Not tested

- Physical Android install/upgrade, SQLite and encrypted storage on a device, device voice engines, external composers/dialer, actual GPS/geocoder and optional GGUF inference.
- Real emergency connection, live provider delivery, WhatsApp approval, SMS reachability, global service availability, and response times.
- Browser UI interaction and responsive visual testing. TypeScript/build tests are not browser interaction tests.
- External Render/Neon PostgreSQL deployment, remote GitHub Actions execution, production load, legal/security certification and Play publication.
- Fully model-inclusive APK distribution and multilingual model quality.

## Artifacts

Both artifacts are development/test signed, version 0.3.0 build 3. Physical installation is NOT TESTED.

- APK SHA-256: bd84a53d10395d03b54a9dd73b82b3d0a94c8849eaedeb8e5aefe50711ea6d05
- AAB SHA-256: 4278ad2bfa6f5d824123949996cbea735e288accfeff00b968008a2f4fcaa2f2

See docs/UPGRADE-v0.3.md for installation, provider settings and Android calling restrictions, and docs/FEATURE_STATUS.md for the complete implementation boundary. This release is not independently certified for emergency reliance.
