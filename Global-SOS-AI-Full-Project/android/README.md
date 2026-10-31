# Global SOS AI — Flutter source

This folder is a complete Flutter project. Its native Android project is the nested `android/` directory. Android 8+ on ARM64 is required by the optional native model plugin.

With Flutter 3.38.10, Java 17 and the Android SDK installed, run from this folder:

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build apk --release --target-platform android-arm64
flutter build appbundle --release --target-platform android-arm64
```

The app includes its government-source directory and deterministic offline router. Set your HTTPS backend URL in Settings and tap Synchronize directory. No PostgreSQL credentials belong in this app. A server is optional for offline directory use. The optional pinned local model can be downloaded from Settings; the directory works without it.

The companion full-project ZIP contains the backend, Render configuration, complete documentation and GitHub Actions workflow. Use that monorepo for the automated cloud build route. This standalone Flutter archive does not require manually copying source snippets into a different app.

Without all four production signing environment variables, release-mode builds use development signing. Such artifacts are test-only and must not be presented as Play-ready releases. See the signing, security, privacy, source coverage and test-report documents included with the full project. Actual device installation, model inference and emergency communications require independent validation.
