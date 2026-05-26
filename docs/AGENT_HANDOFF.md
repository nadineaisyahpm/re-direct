# Agent Handoff

Use this as the first read for any new chat picking up re:direct work. Pair it with `docs/ROADMAP.md` for the full architecture and slice history.

## Repo

- GitHub: <https://github.com/nadineaisyahpm/re-direct>
- Local root: `/Users/mac/Desktop/re_direct`
- App folder: `re_direct/`
- Default branch: `main`
- **First step every session:** `git status --short`

Companion repo (sibling, separate git history):
- AI proxy: <https://github.com/nadineaisyahpm/re-direct-ai-proxy> (private)
- Local root: `/Users/mac/Desktop/re_direct_ai_proxy`
- Default branch: `main`

## Read first

- `README.md`
- `re_direct/CLAUDE.md`
- `docs/ROADMAP.md`
- `docs/GIT_WORKFLOW.md`
- `docs/AI_INTEGRATION_PLAN.md`
- `docs/AI_PROXY_IMPLEMENTATION_PLAN.md`
- `docs/REFLECTION_ARCHITECTURE.md`
- `docs/RABBIT_HOLE_THREADS.md`
- `docs/DEVICE_ACTIVITY_FEASIBILITY.md`
- `docs/SLICE_E1_ENGAGEMENT.md`
- `docs/AUTH_SETUP.md`

## Core concept

re:direct is a **local-first curiosity redirection app**. v1 focus:

- **AI-guided curiosity redirection.** Dashboard's Daily Direct suggests one intentional next step today, drawn from local interests + manually-logged rabbit holes. The AI call goes through a Cloudflare Worker proxy (no provider key on device).
- **Rabbit Hole memory.** `CuriosityEngagement` is the canonical record of "I actually went down this rabbit hole." re:tuals remembers per-method history; Re:Log summarizes across topics, methods, and reflections.
- **Reflection.** Local writing surface (Reflect-method ritual today; post-ritual reflection planned in REF3). Reflection bodies never leave the device.
- **Local-first privacy.** Everything sensitive stays on-device. AI requests carry only sanitized, user-declared signals.

DeviceActivity / FamilyControls is **parked for v2** (not abandoned). Family Controls entitlement isn't available on the current Personal Team. Phase 7B resumes when the Apple Developer Program + entitlement land. See `docs/DEVICE_ACTIVITY_FEASIBILITY.md`.

## Surface architecture (load-bearing)

- **Dashboard** discovers curiosity and now displays an **AI-backed Daily Direct** when fresh cache or proxy returns a recommendation. Falls back silently to seeded curiosity content when AI is unavailable.
- **re:tuals** remembers per-method ritual history (read-only). Card front carries editorial copy; tapping flips to engagement history for the lane.
- **Re:Log** summarizes — rabbit holes, reflections (read-only floating popup), boundary sessions.
- **Rabbit Hole** (tab 1, as of RH3-B) is where the user picks up where they left off. The RH3-B shell ships an editorial title, an inert `+ new thread` capsule, and the "no threads yet." empty state. RH3-C wires the today card, threads list, loose-ends section, and `ThreadPreviewSheet`.
- **Timer/Boundary** is **parked for v2.** As of RH3-B it is no longer reachable from the tab bar — tab 1 holds `RabbitHoleView`. The `TimerView` source and `TimerSession` model remain in the codebase for Phase 7B / 7C unparking. No primary v1 surface presents the Timer flow; Settings exposure for `TimerView` is deferred (likely to a later slice once thread surfaces stabilize).
- **Settings** is the local status dossier + S3 data-clearing controls (soft-delete with confirmation).

## Semantic rules — never cross these

Preserved invariants:
- `TimerSession` is **boundary telemetry**, not a rabbit hole.
- `CuriosityEngagement` is the **rabbit hole / user-declared content engagement** record.
- `ReflectionEntry` is **local writing** (reflection bodies) and never leaves the device.
- Timer chooses the method (single-select).
- re:tuals never chooses a method. No `continue this lane` or any replacement selection CTA.
- Reflect-as-method (the ritual *is* writing) and post-ritual reflection (follow-up record attached to a non-reflect ritual) are **distinct flows**. See `docs/REFLECTION_ARCHITECTURE.md` §2.
- `start boundary` **arms** a boundary. Manual user end action is `stop early`. Completion is reserved for system-driven (DeviceActivity) when Phase 7B unparks.
- TimerView must not become a generic stopwatch / countdown timer.

Added since the last handoff:
- **Rabbit Hole Threads architecture is locked in `docs/RABBIT_HOLE_THREADS.md` (RH0, done).** Threads are topic-centric, optional, cross-method, and group `CuriosityEngagement` rows without modifying them. The §13 anti-scope-creep rules are load-bearing — do not cross them without amending that doc first. RH1 (SwiftData model) is the next implementation slice.
- **Do not delete `TimerSession` without a migration plan.** The model still ships and Re:Log shows its data; v1 may de-emphasize the surface but the row remains.
- **Do not continue building Timer/DeviceActivity as v1 core** unless the user explicitly resumes Phase 7. Treat any work in that direction as Phase 7B / Phase 7C and apply the `docs/DEVICE_ACTIVITY_FEASIBILITY.md §10` workflow guardrails.

## Design language

Modern editorial, warm paper texture, subtle iOS liquid glass, tactile, cinematic, reflective, minimal but alive. Instrument Serif for editorial titles and numerics; system sans for controls/data/status. Palette: warm cream, off-white, taupe, dusty rose, soft grey, deep teal, dark slate.

Avoid: neon, futuristic glassmorphism, generic dashboard/settings UI, heavy glow, clutter, broad redesigns.

## Current implementation state

Shipped (in `origin/main` as of post-6D-E):

**Prototype foundation:**
- v0.1.0 SwiftUI prototype.
- Local-first SwiftData foundation; seed importer wired at launch.
- Apple Sign-In coordinator + Keychain store (entitlement step deferred to Slice 7.1).
- Swift Testing target.

**Engagement / rabbit hole:**
- `CuriosityEngagement` model + Re:Log "+ log a rabbit hole" sheet + Dashboard Re:Log widget counts `CuriosityEngagement` rows + Re:Log full screen Recent Rabbit Holes section.

**Reflection:**
- `ReflectionPrompt` model + seed schema v2 + bundled reflection prompts.
- `ReflectMethodRitualView` — full-screen writing surface for Reflect-method ritual, behind a DEBUG-only trigger from `start boundary` (REF2.1 swaps in the real reminder trigger when Phase 7B lands).
- Re:Log Reflections section (read-only) with floating paper popup for full-body view.

**re:tuals:**
- Card lanes A–C.2 shipped: tap-to-flip, back face shows recent engagement rows filtered by `methodSlug`, tactile 3D flip motion.
- `choose this` retired; shared `ActiveMethodStore` written by Timer, read by re:tuals.

**Timer/Boundary (provisional, v2 focus):**
- Timer arms a boundary session and prevents duplicate active sessions.
- Active state has only `stop early`; manual `done` removed.
- TimerSession lifecycle helpers (`status`, `isActive`, `isCompleted`, `isInterrupted`, `isDeleted`, `elapsedSeconds/Minutes`).

**Settings:**
- S1: read-only dossier (six sections, paper-glass rows, `StatusChip` primitive).
- S2: live status values + capability statuses.
- S3: local data controls with confirmable soft-delete.

**Phase 6 — AI lane (shipped through 6D-E):**

Proxy repo:
- `/Users/mac/Desktop/re_direct_ai_proxy` — sibling repo, private.
- GitHub: <https://github.com/nadineaisyahpm/re-direct-ai-proxy>
- Cloudflare dev Worker: `https://re-direct-ai-proxy-dev.nadineaisyah170806.workers.dev`
- Default provider: **DeepSeek**, model **`deepseek-v4-flash`**.
- Provider abstraction + adapter for OpenRouter as escape hatch.
- Cost-control allowlists:
  - DeepSeek allowlist: only `deepseek-v4-flash` (anything else → `proxy_unavailable`).
  - OpenRouter allowlist: only `meta-llama/llama-3.3-70b-instruct`.
  - iOS request payload **cannot** specify `model`, `model_name`, or `MODEL_NAME` — rejected as `invalid_input` at strict Zod parse.
- Privacy denylist on the proxy: 14 forbidden field names (reflection body, Apple identity, DeviceActivity tokens, precise timestamps, screenshots, etc.) rejected before any provider call.
- Wrangler v4. 77 / 77 proxy tests passing.

iOS AI pipeline:
- `AIProxyHTTPClient` — single-attempt HTTP client matching the existing `AIRecommendationResolver.callProxy` closure seam.
- `DailyDirectLoader` — composes the request from personal v1 interest seeds (`Apple`, `Machine Learning`, `AI`, `Neuroscience`, `Software Engineering`).
- `AIEnvironment` — single source of truth for the dev Worker URL.
- `DailyDirectSessionStore` — per-app-session throttle (one proxy attempt per cold launch).
- Dashboard `DailyDirectSection` — AI override card (1 card on success) vs seeded list (current 2 cards on fallback); `DailyDirectMapping` is the pure mapper.
- SwiftData cache write-back: successful `.proxy` responses persist via `SwiftDataAIRecommendationCache.store(_:for:)` with dedup-by-`promptInputHash`.
- 24h cache freshness: stale rows hidden from `lookup(_:)`; resolver proceeds to proxy and write-back replaces. `defaultCacheTTL = 24 * 60 * 60`.

Tests at last checkpoint:
- **184 / 184 passing across 22 suites** after Phase 6D-E (iOS).
- **77 / 77 passing in the proxy repo** post-DeepSeek + OpenRouter allowlist.

## Privacy posture

Local-first. Runtime AI **exists** through the Cloudflare proxy — that's the current truth, updated from the prior "no runtime AI" line.

Hard rules:
- iOS **never stores provider API keys**. The proxy holds the key as a Cloudflare secret.
- **Reflection bodies never leave the device.** Period. `ReflectionEntry.body` is not in any outbound payload.
- iOS **never calls DeepSeek / OpenRouter / any vendor endpoint directly** — only the Cloudflare Worker.
- **No DeviceActivity tokens, Apple identity, screenshots, private notes, or precise timestamps** leave the device. Test-enforced via the proxy's denylist + iOS-side encode tests.
- Reflection text **never** feeds AI prompt generation (REF5 future-work).
- Provider API key never appears in repos, dotfiles (`.dev.vars` gitignored), or commit history.

## Git workflow

- Local commits allowed under `docs/GIT_WORKFLOW.md`.
- Do **not** push unless explicitly instructed.
- `git status --short` before any work.
- Don't stage unrelated files. `.kiro/` is ignored and stays unstaged.
- **Known persistent drift**: `re_direct.xcodeproj/project.pbxproj` carries personal signing values (`DEVELOPMENT_TEAM = F9BT3PQ9Z6`, `CODE_SIGN_IDENTITY[sdk=macosx*] = "Apple Development"`). Leave it unstaged on every slice unless the user explicitly opts to commit it.
- Build/test after code changes.
- Simulator verification often needs a manual tap from the user — automated osascript clicks miss the small bottom-nav icons.

## Protected root view initializers

- `DashboardView()`
- `RabbitHoleView()`
- `TimerView()`
- `RetualsView()`
- `ReLogView()`
- `AppTabView()`
- `SettingsView()`

## Do not

- Restructure navigation.
- Casually change root view initializers.
- Add backend / Screen Time / notifications without explicit approval.
- Add new AI capability beyond the documented proxy contract without an `AI_INTEGRATION_PLAN.md` update.
- Bake API keys, vendor URLs, or `Authorization` headers into iOS source.
- Reintroduce re:tuals method selection.
- Treat `TimerSession` as a rabbit-hole count.
- Overbuild `TimerView` as a generic countdown timer.
- Delete `TimerSession` or treat Timer as dead — it's parked, not removed.
- Resume Phase 7 (DeviceActivity / FamilyControls) without explicit user direction and the `docs/DEVICE_ACTIVITY_FEASIBILITY.md §10` workflow guardrails.
- Stage the `re_direct.xcodeproj/project.pbxproj` signing drift unless asked.

## Likely next slices (proposed, not started)

- **RH1** — `RabbitHoleThread` SwiftData model + `ThreadStatus` / `ThreadSourceKind` enums + ordering mechanism + tests. No UI. Next implementation slice; gated only on user signal to proceed. See `docs/RABBIT_HOLE_THREADS.md §11`.
- **RH2–RH5** — user-facing thread surface, 6E ↔ thread bridge, re:tuals grouping, Dashboard "continue thread" Daily Direct variant. Sequenced in `docs/RABBIT_HOLE_THREADS.md §11`.
- **Timer de-centering / Direct surface planning** — the broader v1 re-shape that takes Timer out of the center and puts AI-guided redirection + rabbit-hole threads there.
- **Phase 7B** — DeviceActivity feasibility spike. **Parked**, pending Apple Developer Program + Family Controls entitlement access. Resume only on explicit user signal.
- **REF3 / REF3.1** — post-ritual reflection (per `docs/REFLECTION_ARCHITECTURE.md` §11). Defined; not implemented.
- **Slice 7.1** — Apple Sign-In capability + end-to-end verification (manual Xcode UI step required). Standalone, can land anytime.

## First task in next chat

1. Run `git status --short`. Confirm only the known `re_direct.xcodeproj/project.pbxproj` signing drift is unstaged (if present); no other working-tree changes expected. Confirm `origin/main` is in sync.
2. Read the docs listed under **Read first**, especially `docs/AI_INTEGRATION_PLAN.md`, `docs/REFLECTION_ARCHITECTURE.md`, and this file.
3. Default next action: **propose RH1** — `RabbitHoleThread` SwiftData model + enums + ordering mechanism + tests, per `docs/RABBIT_HOLE_THREADS.md §11`. Do not start coding until the user approves the slice scope.
4. Stop and ask if the user redirects to something else (e.g. Slice 7.1, a polish pass, or resuming Phase 7).
