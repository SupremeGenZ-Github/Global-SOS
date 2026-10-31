# Third-party components

Project source: MIT. Government contact facts remain attributed to their original government pages and may be subject to those sites' reuse terms; no government endorsement is claimed.

| Component | License / source |
|---|---|
| Flutter / Dart | BSD-3-Clause; https://github.com/flutter/flutter and https://github.com/dart-lang/sdk |
| React, React DOM | MIT; https://github.com/facebook/react |
| Express, Helmet, express-rate-limit, Zod | MIT; respective package repositories identified by package-lock.json |
| node-postgres | MIT; https://github.com/brianc/node-postgres |
| Vite / TypeScript | MIT / Apache-2.0; their official repositories |
| sqflite, url_launcher, geolocator, shared_preferences, path_provider, flutter_secure_storage, http, crypto | See each resolved pub package LICENSE; exact versions and package hashes in android/pubspec.lock |
| llama_flutter_android 0.2.6 | MIT; https://pub.dev/packages/llama_flutter_android; native llama.cpp code included by plugin |
| llama.cpp / ggml | MIT; https://github.com/ggml-org/llama.cpp |
| SmolLM2-360M-Instruct GGUF | Apache-2.0; https://huggingface.co/HuggingFaceTB/SmolLM2-360M-Instruct-GGUF; model is optional, not silently included |
| PGlite (test only) | Apache-2.0; https://github.com/electric-sql/pglite; PostgreSQL uses its own permissive license |
| robots-parser / supertest | MIT; see package-lock.json and installed package LICENSE files |

Dependency lockfiles fix the resolved versions. Android/Flutter builds generate their own runtime license registry. Before binary redistribution, retain required third-party notices and review the exact licenses distributed by the chosen plugin/model revisions. Android SDK and JDK are build tools and are not included in source archives.
