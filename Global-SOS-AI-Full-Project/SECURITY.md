# Security

Development release. No independent security audit or penetration test has been performed. Report issues privately to your deploying operator; no project-owned public reporting address is configured in this source package.

- HTTPS-only Android API and remote model connections; local model server HTTP restricted to loopback. Do not disable certificate verification in PostgreSQL or clients.
- PostgreSQL queries are parameterized. Migrations are additive; seed data never overwrites approved records.
- Administrator API tokens are supplied by the operator, at least 32 characters, compared through fixed-size SHA-256 digests with constant-time comparison. Use two distinct tokens and separate humans for reviewer and publisher duties. Do not distribute these tokens in the Android app. Role separation is credential-based, not identity-bound or 2FA.
- No password login is exposed; password hashing is therefore not a runtime feature. Reserved account tables are not a working identity system.
- JSON validation, bounded requests, Helmet/CSP, explicit origin allowlist, per-IP rate limits and no public user/location enumeration.
- Private SOS bearer capabilities use 256 bits of randomness, are stored as hashes and expire after one hour. Their URLs use fragments. Anyone given a capability can read/update that one session until expiry, so share only with trusted recipients.
- Mark Safe/Cancel deletes stored coordinates; an expiry sweep deletes sessions. Do not treat stale or missing positions as reliable.
- Android contacts/history use flutter_secure_storage with encrypted Android preferences. Android backup is disabled. Browser contacts/history are not encrypted local storage; avoid shared browsers and use Delete my local data when needed.
- Chat/model text is never a source of contact information. Only category identifiers are accepted from model output. Source changes require human review; no AI auto-publication.
- Monitor accesses only approved HTTPS sources at their stored hostname, with bounded bodies/timeouts, robots checks and no redirects. A trusted maintainer must vet sources, host ownership, DNS and terms before approval. Harden network egress if operating a multi-tenant admin system.
- No request body, database URL, chat, contact or coordinate logging. Reverse proxies and model providers have separate logging policies; configure them accordingly.
- Source assets may be cached by the website service worker. API responses and personal location requests are excluded from service-worker caching.

Before production: independent emergency workflow/device assessment, authority confirmation, load/failure testing, managed encrypted backups, restoration drills, provider retention review, token rotation/2FA or identity-aware admin access, security dependency review and legal/privacy review. Operator-side infrastructure and availability obligations cannot be certified by this package.
