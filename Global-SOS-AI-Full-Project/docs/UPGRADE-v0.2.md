# Global SOS AI 0.2 — installation and configuration

Install the new APK over 0.1.0. It uses the same development signing identity and application ID. Existing encrypted trusted contacts and preferences should remain. Physical-device upgrade is NOT TESTED. Keep a backup of important contact details before changing installations.

## SOS

Confirm your country, then tap or hold SOS. A five-second countdown appears. Cancel stops it. Leaving the app during the countdown also cancels it. At zero, the Android native dialer opens with the verified emergency shortcut. For India this is 112. Press Call in the phone application. Ordinary Android applications cannot directly place emergency calls using ACTION_CALL. No private permission or default-dialer bypass is used. No real emergency calls were placed during testing.

The dialer opens before database, storage, GPS or model work; a failing backend cannot block that action. Call connection is never reported as confirmed. Other countries use their own verified primary police number, rather than receiving India's number. A country without a national verified shortcut shows an explicit unavailable message.

## Directory and contact actions

The bundled directory now includes primary and specialist services with telephone, SMS, WhatsApp, email and web channels. All channel values come from government-operated pages. Some service operators are charities named by government sources. Many newly added primary numbers come from UK FCDO travel guidance, rather than each country's own government. Check the card's jurisdiction, reliability and network restrictions.

All 193 UN members are selectable. Some countries have no reliable published primary number; those gaps remain explicit. Specialist coverage is not exhaustive for every country, region or category. A selector entry does not certify availability.

Use All Helplines to filter by category, channel, state/region/city, or favorites. National services remain visible alongside a selected region. Email/SMS/WhatsApp actions open an editable message preview before the external composer. You must send messages in the external app. Email, web forms and ordinary messaging do not imply immediate dispatch.

An app update replaces the previous bundled directory. Server-synchronized and administrator-approved snapshots are preserved. For a phone using an older server snapshot, deploy this updated backend and tap Synchronize directory. Database startup adds new records, updates untouched seed records with history, and preserves administrator-approved modifications and withdrawals.

## Trusted contacts and automatic provider alerts

No credentials are needed for the offline directory or emergency dialer.

My Safety supports call, SMS, WhatsApp and email composers; optional encrypted medical notes; per-contact alert consent; and permitted alert methods. WhatsApp requires a full international phone number and an installed handler. Provider alerts are an optional private-deployment feature, not public emergency dispatch.

For automatic alerts, configure a healthy PostgreSQL backend and these server environment variables:

```
ALERT_CLIENT_TOKEN=<different random private token, at least 32 characters>
ALERT_ALLOWED_RECIPIENTS=+COUNTRYCODEPHONENUMBER,friend@example.com
TWILIO_ACCOUNT_SID=<optional Twilio account SID>
TWILIO_AUTH_TOKEN=<optional Twilio auth token>
TWILIO_SMS_FROM=<approved Twilio sender number>
TWILIO_WHATSAPP_FROM=whatsapp:+APPROVEDNUMBER
TWILIO_WHATSAPP_TEMPLATE_SID=<approved template with message variable 1>
RESEND_API_KEY=<optional Resend key>
ALERT_EMAIL_FROM=<verified sender address>
```

Only set credentials for the methods you use. Obtain the recipient's permission and add that exact phone/email to the backend allowlist. Public helplines must never be allowlisted for automatic notifications. Provider charges, country restrictions, verified senders, WhatsApp template approval and recipient opt-in are external requirements.

In Android Settings enter your HTTPS backend address. In My Safety, enter ALERT_CLIENT_TOKEN (stored encrypted), add the contact, confirm their consent, select permitted methods, and enable automatic trusted-contact alerts. Never put provider credentials or DATABASE_URL into Android. Each recipient/method is submitted once per SOS session. Unknown outcomes are not automatically retried. Refresh provider status to check subsequent delivery information. Accepted, queued, sent and unknown do not mean delivered. No live provider delivery was tested.

Location is included only after explicit location consent and capture; live links require a running private session and foreground sharing. Medical notes are not automatically uploaded or attached. Notification receipt records are deleted with expiring sessions. Ending an SOS cannot recall an alert already submitted.

## Location, voice and AI

Settings offers Detect my country/region. Coarse Natural Earth polygons support offline country suggestions. Near coasts/borders, poor GPS fixes, small countries, disputed territories and missing polygons require careful manual confirmation. This is not an authoritative boundary database. Optional Android address lookup can obtain state/city; it is disabled until you allow coordinates to be sent to that provider.

Voice input uses Android's installed recognition service and prefers offline recognition; the system service's own privacy/network behavior applies. Read aloud uses installed Android TTS voices. English, Tamil, Telugu and Hindi voice preferences are available, depending on installed device language support. Silent interface hides speech controls and disables app haptics, but does not change phone-call or external-app audio settings.

The pinned optional SmolLM2 model and integrity check remain. The model performs intent classification, not unrestricted counseling. The offline app guide handles basic greetings, app questions and simple arithmetic without a model. The website supports the same app guide and server AI routing. Online generative routing still requires your configured model service. On-device model inference, recognition, TTS and GPS behavior are NOT TESTED on a physical phone.

## Remaining boundaries

No unrestricted silent emergency calling, emergency dispatch service, guaranteed notification delivery, background location service, global service-completeness guarantee, account registration/cross-device account sync, or independent safety certification is claimed. Account registration was optional in the brief and remains disabled. Optional push notifications require a separate authorized push provider and are not included. Model-inclusive offline distribution can be prepared using the supplied model packaging script; weights are not in these APK/AAB files.
