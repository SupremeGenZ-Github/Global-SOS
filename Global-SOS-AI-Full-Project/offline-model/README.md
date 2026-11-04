# Optional local model

Global SOS also bundles a small, English-focused intent classifier trained on
synthetic examples in `shared/intent-training.json`. Run
`npm run train:intents` to regenerate the weights for Android and the server.
Emergency rules take priority and the classifier abstains on weak matches.
The training script updates the lightweight classifier only.

Model metadata is authoritative in `android/assets/model.json`: HuggingFaceTB SmolLM2-360M-Instruct-GGUF, Q8_0, 386,404,992 bytes, Apache-2.0, pinned revision and SHA-256. The normal app includes the directory and fallback rules but downloads model weights only when requested in Settings. Tap Download, wait for verification, then Load model. Chat routing uses it only in offline mode when deterministic emergency rules did not already match.

The model classifies intent. Freeform generated numbers, URLs or medical advice are never displayed. English-focused; no validated multilingual capability. CPU-only, ARM64 Android 8+ for this plugin. Memory, temperature, model latency and actual device compatibility require testing; more available memory improves reliability. Directory/SOS shortcuts remain independent of model success.

## Fully offline distribution option

With Node dependencies installed, run from the monorepo root:

```sh
node scripts/prepare-offline-model.mjs
cd android
flutter build apk --release --target-platform android-arm64
```

This opt-in script downloads the immutable weights, verifies their size and checksum, adds a bundled model asset, and creates a separate model-inclusive distribution. It makes the APK hundreds of MB larger and can require substantial temporary RAM when loading the bundled asset. Preserve Apache-2.0 model notices. The standard APK does not include weights. The model-inclusive option is source-supported but is not claimed tested unless TEST_REPORT.md records it.

The runtime copies and verifies the bundled model when Load model is tapped if no downloaded model exists. Without either an installed bundle or download, directory lookup and rules still work entirely offline. No API key is needed.
