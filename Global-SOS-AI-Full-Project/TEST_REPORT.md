# Test report — Global SOS AI 0.1.0

Generated 2026-10-31T12:03:59.367Z. Results below report actual commands, not intended behavior.

| Check | Status | Evidence |
|---|---|---|
| Backend/API/PostgreSQL engine tests | PASSED | [Command log](docs/evidence/backend-tests.txt) |
| Flutter static analysis | PASSED | [Command log](docs/evidence/flutter-analyze.txt) |
| Flutter routing and widget tests | PASSED | [Command log](docs/evidence/flutter-tests.txt) |
| TypeScript and website production build | PASSED | [Command log](docs/evidence/web-build.txt) |
| Production dependency security audit | PASSED | [Command log](docs/evidence/npm-audit.txt) |
| Android APK compilation | NOT COMPLETED / NOT TESTED | [Command log](docs/evidence/flutter-build-apk.txt) |
| Android AAB compilation | NOT COMPLETED / NOT TESTED | [Command log](docs/evidence/flutter-build-aab.txt) |

## Tested scope

Backend tests use PGlite (actual PostgreSQL engine in WebAssembly) with the production SQL migration and API handlers. They check source/channel consistency, country isolation, validation, CORS, role separation, approved-source requirements, version/history preservation, idempotent seeds, stale-review conflict rejection, reviewed withdrawal, private capability access, coordinate bounds, Mark Safe deletion, expiry, rate limits, robots handling, and online-provider failure. These tests use fixtures and never call emergency services.

Flutter tests check deterministic routing, channel links, country isolation, directory navigation and offline assistance without a model/network. Widget tests inject directory and safety data; they do not exercise the Android SQLite or encrypted-storage platform implementations.

Website production compilation checks TypeScript and bundling. A local server startup and HTTP responses are checked separately where recorded.

## Not tested / not established

- Browser UI interaction, screenshots, responsive-device rendering and browser-console checks: browser preview failed to attach. CSS responsiveness and event handlers are implemented but visual behavior is not certified.
- Real Android installation, physical-device navigation, GPS permissions, secure storage, SQLite synchronization, background/process-loss behavior, external dialer/SMS/WhatsApp/email applications, ARM CPU compatibility and actual LLM inference.
- Real emergency-call connection, message delivery, public dispatch, helpline response times and exhaustive worldwide accuracy. No live calls or messages were made.
- Actual configured online model response, multilingual reliability, fully bundled-model distribution and on-device memory/thermal performance.
- External Neon/Render PostgreSQL connectivity, failover, backups, production load, hosted Render deployment, GitHub Actions remote run and Play publication.
- Independent security/privacy/legal certification.

## Build interpretation

An APK/AAB is available only if its compilation command finished successfully and the artifact exists. A successful compile is not proof of device installation or service safety. Without a permanent keystore, binaries are development/test signed. The GitHub workflow is included as an alternative build route; no successful remote Actions run is claimed.

Initial failures encountered during development included missing Windows tool-discovery variables, Dart syntax/style issues, dependency audit findings, Gradle download timeouts and widget-test asynchronous asset setup. See the final command logs above for the latest status; an unfinished or failed row is not a pass.

See docs/LIMITATIONS.md for requirements that remain unimplemented. This release is not production-ready for emergency reliance.
