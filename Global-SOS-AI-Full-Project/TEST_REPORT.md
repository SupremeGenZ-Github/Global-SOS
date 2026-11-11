# v6 validation scope

The release workflow checks Flutter analysis and widget/unit tests, Node project tests, TypeScript/Vite production builds, mocked browser emergency flows and desktop/mobile/RTL UI regressions. It captures screen previews for review.

APK/AAB builds must pass signature verification. The website package is checked for matching release metadata, binary download, HEAD/range behavior and SHA-256 checksum. Complete source, Render and Android ZIPs are inspected to ensure temporary private environment-file fixtures are absent.

Actual pass/fail results belong to the successful GitHub Actions run for the source commit. A source archive alone is not evidence of a successful build. See `.github/workflows/v4.yml` and `docs/V6-UX-REVIEW.md`.

Not tested automatically: a physical phone, real emergency calls, real SIM SMS, provider delivery, OEM permissions or the deployed PostgreSQL connection. Android artifacts are development/test signed unless a private production signing environment is configured. Export local data before uninstalling an older installation.
