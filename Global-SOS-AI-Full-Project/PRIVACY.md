# Privacy policy template — deployment owner must complete

Version 0.1.0. The deploying operator must add their legal name, address, privacy contact, jurisdiction, hosting/subprocessors, lawful basis and applicable user rights before public distribution. This template is not a global legal-compliance certification.

Basic directory use needs no account, device location or online AI key. The app asks the user to confirm their country. It never chooses an emergency jurisdiction from IP alone.

Android stores its directory in local SQLite, preferences locally, and trusted contacts/history in encrypted secure storage. The browser stores contacts/history/favorites/directory/preferences in that browser's local storage. It is not encrypted against someone who can access the browser profile. Delete controls remove private local safety data. The Android directory is retained for offline access.

Offline chat stays on the device. The optional model download retrieves a pinned model from Hugging Face; that host receives the download request and ordinary network metadata, but not chat messages. Model license is Apache-2.0. Offline model inference never intentionally sends chat text to the backend.

If the user enables online routing, the current message is sent to the operator's backend and configured model service. This backend does not persist chat messages. The configured provider may have separate logging/retention terms. Do not include unnecessary sensitive details. Users may leave online routing disabled.

GPS capture requires device permission. Coordinates remain local until the user explicitly enables live sharing in an active server session. Shared positions are stored in PostgreSQL under a random private capability, with one-hour expiry. Anyone holding the copied private link can view the session. Mark Safe or Cancel deletes stored positions. A cleanup sweep removes expired sessions, normally within one minute of expiry while the service is running. Backups and provider logs may have separate operator-defined retention. No coordinates are publicly listed.

Opening phone/SMS/WhatsApp/email/maps links transfers the selected content to that external app or service. Review it there before calling or sending. Global SOS AI does not confirm connection, delivery or response. It does not silently send messages, record audio or perform background public dispatch.

Operational admin audit records retain action, role, target and time. They do not store user chats or coordinates. Directory approval history and source provenance are retained for safety accountability. Operators must define administrative retention, backup deletion procedures and legally required disclosures.

The system is not a substitute for direct emergency services. Children and vulnerable users should use safety features with appropriate trusted support. No advertising or analytics integration is included by this project; hosting providers may collect technical metadata under their own terms.

## Optional provider alerts and device services
When explicitly enabled, trusted-contact recipient addresses and the user-selected alert message are sent through the configured backend to Twilio (SMS/WhatsApp) or Resend (email). Only operator-allowlisted recipients are accepted. Location appears only after location consent and capture/sharing; medical notes are not automatically attached. Provider retention and legal terms must be reviewed by the operator. Server receipts retain recipient hashes, provider IDs and statuses, and are deleted with expired sessions.

Optional Android address lookup may send coordinates to the installed geocoding provider; it is off by default. Android speech recognition prefers offline mode but follows the recognition provider's own privacy/network settings. These services must be reviewed on the actual device.
