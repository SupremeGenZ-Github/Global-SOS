# Scope and remaining validation

This release must not be represented as the complete independently verified worldwide system described in the development brief.

| Requirement | Delivered behavior / remaining work |
|---|---|
| Worldwide directory | 193 UN states plus extra territories selectable. Actual service coverage is limited to government-page sourced seed records documented in HELPLINE_SOURCES.md. Remaining countries/categories show unverified information. No exhaustive regional/municipal inventory. |
| Government verification | Source provenance and checking dates retained. Several records rely on UK FCDO travel guidance rather than their own government's emergency authority. No live authority confirmation or operational testing. Some source pages are old numbering plans. |
| Offline model | Real Android llama.cpp inference adapter, pinned optional model download, SHA-256 check, category-only output and deterministic fallback. Actual on-device model loading, speed, thermal behavior and compatibility need testing. English-focused; no validated multilingual model performance. |
| Conversational AI | Routes intent to contacts. No unrestricted everyday conversational answers, diagnosis, counseling or medical advice. Browser offline mode is explicitly rules-based; only Android runs the optional local LLM. |
| SOS automation | Countdown, local history, external dialer/composers, optional foreground location sharing. No automatic SMS/WhatsApp/email/push provider delivery, public dispatch, background tracking, silent recording or unsupported emergency-call permissions. |
| Region detection | GPS captures coordinates after permission. Manual country confirmation is mandatory. No automatic reverse geocoding, country polygons, offline jurisdiction detection or border inference. |
| Voice assistance | Voice input and multilingual speech synthesis are not included. |
| Accounts | No registration or cross-device account synchronization. Android contacts use encrypted local storage; browser contacts remain in local browser storage. User/contact/preferences tables reserve future storage but are not account endpoints. |
| Location | One-hour bearer-capability sessions, foreground uploads, link copied or manually shared. No SMS delivery reports or guaranteed location freshness. No session recovery after process termination. Capability remains in memory until app/page closes. |
| Admin | Separate reviewer and publisher tokens, proposals/history, source-review queue and publication. Source admission is a vetted maintainer SQL action; no automatic government-domain trust discovery. Tokens are operator credentials, not a full multiuser identity/2FA system. |
| Monitoring | Robots-aware bounded HTTPS page checks; redirects/restricted sources skipped, changes require manual review. Operator must review site terms and configure contact/hosting uptime. Hash changes may be cosmetic; no automatic extraction or publication. |
| Privacy and law | Technical minimization and retention controls implemented. No claim of global legal compliance, independent security audit, Play approval or regulatory certification. Operator details, hosting contracts and policy review remain necessary. |
| Database | Migrations and queries tested with PostgreSQL via PGlite. External managed PostgreSQL, failover, backup restoration, load tests and provider TLS configurations require operator verification. |
| Availability | No emergency uptime SLA. Model host, phone network, permissions and external applications are independent dependencies. |

Read TEST_REPORT.md for actual build and test outcomes. No real emergency service was contacted during development.
