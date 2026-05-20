# Curiosity Seed Content

Curated curiosity content shipped in the app bundle. AI-bootstrapped, human-reviewed, then committed here. Runtime AI calls (via the proxy) are separate and never write to these files.

## Files

- `curiosity_seed_v1.schema.json` — JSON Schema (draft 2020-12) defining the seed format.
- `curiosity_seed_v1.example.json` — Small valid example, useful as a template and for unit tests.

## How the seed is generated

1. Run the bootstrap CLI (Phase 2) with a target topic count and provider:
   ```
   swift run seed-curiosity --count 200 --provider openai --model gpt-4o --output draft.json
   ```
2. Hand-review every prompt. Edit, reject, or replace as needed. Fill in `review` blocks.
3. Validate the file against `curiosity_seed_v1.schema.json`.
4. Strip `review` blocks at build time and bundle the result as `curiosity_seed_v1.json` in the app.

## Versioning

- `seed_version` is monotonic. Increment whenever the curated corpus changes.
- The app compares the bundled `seed_version` against the value persisted in SwiftData on launch. If newer, it diff-imports.
- `seed_version` is independent of the OpenAPI proxy version and the app version.

## Locales

- Each file is single-locale (`locale` field, BCP-47).
- v1 ships `en-US` only.
- Additional locales ship as additional files (`curiosity_seed_v1.ja-JP.json`, etc.) and are loaded based on the device locale.

## What does *not* go in seed files

- Runtime AI output (kept in `AIRecommendation` rows only).
- Per-user data of any kind.
- Assets — assets are added to the Asset Catalog and referenced by name.

## Slug contracts

Some seed fields are *contracts* — the slug must match a value the app recognizes, otherwise the row imports into SwiftData but is silently dropped by the UI layer.

### `redirect_methods[].slug`

Must be one of the canonical set, mirroring `TimerRedirectMethod` cases in `TimerView.swift`:

- `watch`
- `read`
- `mini-game`
- `reflect`
- `deep-dive`

Anything else imports but never surfaces in `MethodSelector`.

`display_name` for these entries intentionally matches `TimerRedirectMethod.rawValue` (`Watch`, `Read`, `Mini Game`, `Reflect`, `Deep Dive`) so the Timer screen reads identically until a future slice surfaces seeded copy. The slug is the only contract; `display_name` and `summary` are editorial and can change without code changes.

Drift in this set is caught at test time by `bundledRedirectMethodSlugsMatchCanonicalSet` in `re_directTests/SeedImporterTests.swift`.
