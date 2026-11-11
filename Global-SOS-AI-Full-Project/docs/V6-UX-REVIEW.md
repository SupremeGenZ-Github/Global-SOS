# Global SOS v6 — UX review and release scope

## Design direction

Use a calm black/navy and blue workspace with red reserved for emergency actions. Light mode uses white surfaces and the same blue/red hierarchy. The Android app and phone website share the order Home → Directory → SOS → Assistant → Safety. Desktop uses a separate workspace with a permanent sidebar, service overview, setup and tools.

SOS is a prominent, readable action with an explicit preparation step. Its five-second countdown has a pinned Cancel control. Setup guidance explains country and trusted contacts without claiming that a device is monitored or that help has been dispatched. Emergency calling is independent of optional AI.

The assistant separates conversation from a persistent composer. Android voice input sits beside text and Send. Suggested prompts are editable; they are not automatically sent. Routing mode and optional online transmission remain explicit. Service records retain their source and jurisdiction, with operational details behind a disclosure.

## Research used

- [Material foundations](https://m3.material.io/foundations/): consistent design tokens, layout, interaction states and accessibility.
- [Material touch targets](https://m1.material.io/usability/accessibility.html): minimum 48dp touch targets and separation between controls.
- [Android Material 3](https://developer.android.com/develop/ui/compose/designsystems/material3): coherent color roles, typography and components. Global SOS continues using Flutter; this is design research, not a framework migration.
- [Noonlight safety button](https://help.noonlight.com/en/articles/2114600-how-does-the-button-work): an unmistakable primary action and cancellation path. Global SOS does not provide Noonlight's dispatcher service or PIN workflow.
- [Life360 SOS](https://support.life360.com/hc/en-us/articles/23053474049687-SOS-Alerts): setup, practice and contact/location context. Global SOS does not inherit Life360's monitoring, subscriptions or dispatch coverage.
- [ChatGPT Voice](https://chatgpt.com/features/voice/) and [Claude mobile voice controls](https://support.anthropic.com/en/articles/11101966-using-voice-mode-on-claude-mobile-apps): input controls kept close to the conversation, clear mode controls and readable conversation history. Global SOS's browser assistant remains directory/rules routing unless a model provider is configured.

These are interaction references. Global SOS uses its own implementation and does not copy their branding, artwork or claim equivalent capabilities.

## Bugs addressed

| Issue found in audit | v6 behavior | Verification |
| --- | --- | --- |
| Browser Back/reload loses the selected screen | Routed screen is stored in the URL and restored | Browser regression |
| Country changes retain stale filters or async replies | Reset filters and invalidate pending assistant responses | Browser and Flutter regressions |
| Web countdown Cancel disappears after navigating away | Cancel stays pinned across screens | Mocked browser SOS regression |
| Assistant input scrolls out of reach in Android | Separate composer follows keyboard insets | Flutter keyboard layout regression |
| Native Settings Back always returns Home | Return to the preceding screen | Flutter navigation regression |
| Contact validation silently ignores invalid data | Field-specific validation; dialog owns controllers for its lifetime | Flutter contact flow regression |
| Switching themes/screens can collide with expansion/scroll state | Isolate expansion state with stable identifiers | Flutter screen/theme regressions |
| Older secure writes can finish after newer edits/deletion | Ordered writes, with recoverable failures | Controlled asynchronous vault tests |
| Recreated web service-card components close details on a favorite action | Stable keyed article elements | Browser regression |
| Browser storage failures can crash persistence effects | Safety controls remain usable and persistence warning is shown | Blocked-storage browser regression |
| Private environment files can enter exported ZIPs | Exclude private `.env*` files at any depth | Packaged fixture inspection |

## Verification boundary

CI runs the project tests, production web build, mocked browser SOS flows, mobile/desktop/RTL checks, Flutter analysis and tests, APK/AAB compilation, signature verification, packaged download checks and private-file exclusion checks. It uploads web and Android screen captures for review.

Physical Android installation, camera hardware, real SIM SMS, real emergency calls, provider delivery, the deployed database and OEM permission behavior require device/operator checks. Automated tests do not place real emergency calls or send real alerts.

Version: **0.6.0+10**. Backend URL: **https://global-sos.onrender.com**. Database schema remains compatible; this release adds no required tables or environment variables.
