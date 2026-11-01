# Requirement review — 0.3

| Requested capability | Implementation and validation boundary |
|---|---|
| Public website APK download | /download page, checked binary, checksum, HEAD/range support; release parts assembled automatically at build/start; no visitor login |
| Personal checklist | Persistent user-marked reminders on Android and website; widget-tested; not a safety assessment |
| Printable emergency card | Browser print/Save PDF, chosen country and trusted contacts; medical notes only after explicit inclusion; actual printer/browser layout not visually tested |
| Directory convenience tools | Website favorites-only, sorting, result count and reset; contact editing and setup diagnostics |
| Installable Android application | Flutter app; APK and AAB built locally; development signing; physical install not tested |
| Five-second SOS | Native ACTION_DIAL after countdown; India 112; cancellation and background interruption tested with mocked launches; direct emergency call prohibited by Android |
| Local emergency lookup | SQLite snapshot; bundled update handling; country/category/channel/region/favorite filters |
| Worldwide country registry | All 193 UN states plus territories selectable; published service coverage reported separately |
| Specialist directory | Government-source entries across requested categories; not every local service or category is verified worldwide |
| Phone, WhatsApp, email, SMS, web | Verified channel data; editable external message composers; no invented addresses |
| Offline LLM | Pinned SmolLM2 GGUF, real llama.cpp adapter, integrity check and fallback; physical inference not tested |
| Basic conversation | Offline app guide, greetings and simple arithmetic; not an unrestricted generative tutor |
| Online AI | OpenAI-compatible intent model endpoint with consent, timeout, rate limits and deterministic fallback; requires configured model host |
| GPS | Permission-aware foreground capture and optional sharing; physical fix not tested |
| Country / region detection | Coarse offline country polygons, optional Android geocoder, manual confirmation and uncertainty warning; small regions/borders remain uncertain |
| Trusted contacts | Encrypted Android contacts and medical notes; call/message actions and per-contact provider consent |
| Automatic trusted-contact alerts | Twilio SMS/approved WhatsApp template and Resend email adapters; token and recipient allowlist; idempotency and status tests with mocks; live credentials not configured |
| Provider delivery status | Submission and poll states; no conversion of queued/accepted into delivered |
| Public-service automatic messaging | Deliberately excluded; public helpline messages require external user confirmation |
| Push notifications | Not included; requires authorized push infrastructure |
| Private live sharing | Capability-protected one-hour sessions, opt-in foreground updates, cancel/safe deletion; external server and physical behavior not tested |
| SOS history, Cancel, Mark Safe | Local history and backend status/retention; tested backend erasure and expiry |
| Voice / languages | Native recognition and TTS controls, device language preference; device services and language packs required; physical behavior not tested |
| Silent interface | App haptic/read-aloud controls; does not override system telephony audio |
| Website and backend | React/TypeScript, Express, PostgreSQL, offline browser routing; production build and API tests |
| Android / website synchronization | Shared versioned snapshot; additive database seed upgrades preserve admin changes and withdrawals |
| Administrative review | Two roles, proposals, source evidence, history, atomic publish and stale-version rejection; actual administrator interface not browser tested |
| Source monitoring | Robots-aware page-change detection and review queue; no automatic publication of extracted numbers |
| Accounts | Optional feature remains disabled; no cross-device account/profile sync |
| Deployment and privacy | Render config, env template, migrations, HTTPS-only Android API, encrypted local safety data; external deployment/legal review not performed |
| Production certification | Not independently audited or certified; no emergency availability guarantee |

See TEST_REPORT.md and UPGRADE-v0.2.md for exact results and required configuration.
