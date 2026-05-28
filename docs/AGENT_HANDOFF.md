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

## Milestone — v1 core loop shipped (entering hardening, not expansion)

**The v1 spine is shipped end-to-end.** A user can today:

1. Open **Dashboard** → see an AI-personalized Daily Direct card (or seeded fallback).
2. Open **Re:Log** → tap `+ log a rabbit hole` → record a curiosity manually.
3. Open **Rabbit Hole** (tab 1) → see the loose engagement under "loose ends" + any threads they've created.
4. Create a thread manually via `+ new thread`, OR attach the loose end to an existing thread via `[thread?]`, OR tap `[deepen]` → AI proposes a bounded 3–5 step trail → accept → it materializes as a `.aiDeepened` `RabbitHoleThread` with N step engagements.
5. Re:Log surfaces logged rabbit holes + reflection prompts (Reflect ritual) over time.
6. **All of this is local-first.** No reflection body, no engagement note, no identifier, no raw timestamp ever leaves the device. iOS calls only the Cloudflare Worker — never a vendor directly. No API keys in iOS.

**Posture for the next chat: hardening and polish, not broad feature expansion.** The audit (QA0) found three notable rough edges; all three are shipped (Slice A/B/C below). Remaining options — listed in `Likely next slices` — are deliberately scoped to **manual QA**, **small targeted polish**, or **incremental optional fills (6E-E, RH4, RH5)**. Avoid large feature work unless the user explicitly asks.

## Surface architecture (load-bearing)

- **Dashboard** discovers curiosity and now displays an **AI-backed Daily Direct** when fresh cache or proxy returns a recommendation. Falls back silently to seeded curiosity content when AI is unavailable.
- **re:tuals** remembers per-method ritual history (read-only). Card front carries editorial copy; tapping flips to engagement history for the lane.
- **Re:Log** summarizes — rabbit holes, reflections (read-only floating popup), boundary sessions.
- **Rabbit Hole** (tab 1) is where the user picks up where they left off. **Full local v1 workflow is shipped** — design-plan RH3-B/C/D/E series = canonical RH2 per `docs/RABBIT_HOLE_THREADS.md §11`. Editorial title, `+ new thread` capsule, today card (most recently engaged thread, colored by `ActiveMethodStore`), your-threads list (next 3, open/resting accent bars), loose-ends section (3 most recent unthreaded engagements with active `thread?` attach pill), empty + loose-only states. `NewRabbitHoleThreadSheet` creates manual threads (title + optional summary). `AttachToThreadSheet` attaches a loose engagement to an existing thread (single-tap confirm; closed/deleted excluded from picker). `ThreadPreviewSheet` shows a thread's engagements read-only (capped at 25; reflection bodies never displayed).
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
- **Rabbit Hole Threads architecture is locked in `docs/RABBIT_HOLE_THREADS.md` (RH0, done).** Threads are topic-centric, optional, cross-method, and group `CuriosityEngagement` rows without modifying them. The §13 anti-scope-creep rules are load-bearing — do not cross them without amending that doc first. **RH1 (SwiftData model), RH2 (manual thread creation + overview + attach loose ends), and Phase 6E (AI-deepened trail → `.aiDeepened` thread persistence per §6) are all shipped.** RH2 shipped under the design plan's RH3-B/C/D/E branding; 6E shipped through 6E-D2. Remaining canonical slices: RH4 (re:tuals back-face thread grouping), RH5 (Dashboard "continue thread" Daily Direct variant), Phase 6E-E (seeded `TopicTrail` fallback for offline / proxy-unavailable), Phase 6E-F (additional triggers — Daily Direct card, existing thread "extend with AI"). All proposed, none active.
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

**Rabbit Hole tab (design-plan RH3-B/C/D/E series, = canonical RH2):**
- `RabbitHoleThread` SwiftData model + `ThreadStatus` / `ThreadSourceKind` enums + tests (RH1).
- `RabbitHoleView` replaces Timer at tab 1; `SharedNavBar.tabs[1]` is `("arrow.turn.down.right", "rabbit hole")` (RH3-B).
- Read-only overview with today card + your-threads list (max 3 + overflow) + loose-ends section (max 3), empty + loose-only states, `ThreadPreviewSheet` (cap 25 engagements, `EngagementPreviewRowModel` structurally excludes reflection bodies) (RH3-C).
- Manual thread creation via `NewRabbitHoleThreadSheet` from `+ new thread` and the empty-state CTA — title required, optional summary, validator + inserter helpers covered by tests (RH3-D).
- Loose-end attachment via `AttachToThreadSheet` from the `thread?` pill — single-tap confirm, `EngagementThreadAttacher` updates `lastEngagedAt = max(existing, engagement.engagedAt)` + stamps `updatedAt`, idempotent, picker excludes closed/deleted (RH3-E).
- 267 tests in the `RabbitHoleView` suite covering tab config, copy, mode resolver, step/overflow plural, color palette, privacy invariant, query predicates, partition, engagement display cap, validator, inserter, attacher, picker.

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

**Phase 6 — AI lane (shipped through 6E-D2 — end-to-end AI rabbit-hole trails are live):**

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
- Privacy denylist on the proxy: 14 forbidden field names (reflection body, Apple identity, DeviceActivity tokens, precise timestamps, screenshots, etc.) rejected before any provider call. **Phase 6E-B added 5 more trail-specific denylist entries** (`reflection_body`, `engagement_note`, `engagement_history`, `root_engagement_id`, `root_engaged_at`).
- Two endpoints: `POST /v1/recommendation` (6B, Daily Direct) and `POST /v1/trail` (6E-B, AI rabbit-hole trails). Both speak snake_case JSON, both reuse the same Cloudflare Worker, both reject `model` / `model_name` / `MODEL_NAME` at strict parse.
- Wrangler v4. Proxy tests passing.

iOS AI pipeline — Daily Direct (Phase 6B/6C/6D):
- `AIProxyHTTPClient` — single-attempt HTTP client. `call(_:)` for the `/v1/recommendation` Daily Direct endpoint; `callTrail(_:)` for `/v1/trail` (Phase 6E-C).
- `DailyDirectLoader` — composes the request from personal v1 interest seeds (`Apple`, `Machine Learning`, `AI`, `Neuroscience`, `Software Engineering`).
- `AIEnvironment` — single source of truth for the dev Worker URL. Two presets: `dailyDirect` (recommendation) and `trail` (rabbit-hole trails) — both point at the same Cloudflare Worker.
- `DailyDirectSessionStore` — per-app-session throttle (one proxy attempt per cold launch).
- Dashboard `DailyDirectSection` — AI override card (1 card on success) vs seeded list (current 2 cards on fallback); `DailyDirectMapping` is the pure mapper.
- SwiftData cache write-back: successful `.proxy` responses persist via `SwiftDataAIRecommendationCache.store(_:for:)` with dedup-by-`promptInputHash`.
- 24h cache freshness: stale rows hidden from `lookup(_:)`; resolver proceeds to proxy and write-back replaces. `defaultCacheTTL = 24 * 60 * 60`.

iOS AI pipeline — Rabbit Hole Trails (Phase 6E end-to-end loop, shipped):
- `AITrailRequest` (final class, ARM64e-safe) + `AITrailResponse` / `AITrailStep` Codables (6E-C).
- `AITrailRequestBuilder` — pure builder that extracts only the allowlisted fields from a `CuriosityEngagement` (title, methodSlug, coarse recency bucket); never reads `note`, `reflection`, `id`, `sourceURL`, `topic`, `prompt`, or raw `engagedAt`. Builds an `AITrailRequest`. Used by `TrailPreviewSheet` (6E-D2).
- `AITrailMaterializer` — pure side-effect helper that turns an accepted `AITrailResponse` + root `CuriosityEngagement` into one `.aiDeepened` `RabbitHoleThread` + N step `CuriosityEngagement` rows in a single transaction, per `docs/RABBIT_HOLE_THREADS.md §6`. Steps whose `type` doesn't map to a canonical method slug (`article→read`, `video→watch`, `question/reflection→reflect`, `topic→deep-dive`) are dropped, not coerced. Returns nil and writes nothing if zero valid steps remain. Handles Branch A (unthreaded root → attached) vs Branch B (already-threaded root → new thread carries `seedTopic`/`seedPrompt`) for race protection (6E-D1).
- `RabbitHoleThread` schema additions (6E-D1): `seedTopic: CuriosityTopic?` and `seedPrompt: CuriosityPrompt?`, both nullable, default nil. SwiftData lightweight migration handles this automatically; cold-launch sanity check verified.
- `LooseEndRow` (6E-D2): now renders two pills — `[deepen]` (paper-cream, opens `TrailPreviewSheet`) sibling to existing `[thread?]` (yellow, opens `AttachToThreadSheet`).
- `TrailPreviewSheet` (6E-D2): state machine `.loading` / `.success(response)` / `.failure`. On appear, fires one `callTrail` request via a single-hop MainActor→URLSession→MainActor pattern (matches the post-ARM64e-fix Daily Direct path). Success state renders trail title + optional summary + 3–5 step rows (type chip, title, rationale, optional `↗ link` indicator, optional minutes) + `[accept trail]` CTA. Accept invokes `AITrailMaterializer.materialize` then `dismiss()`. Failure offers `[try again]` (re-fires the load). Cancel / drag-dismiss in any state writes nothing.
- End-to-end flow: log a loose rabbit hole → tap `deepen` → iOS calls Cloudflare Worker `/v1/trail` → DeepSeek returns bounded 3–5 step trail → user reviews `TrailPreviewSheet` → user taps `accept trail` → app materializes one `.aiDeepened` `RabbitHoleThread` + step engagements → root loose end disappears from loose-ends list (if Branch A attached it) → new thread visible in the overview.

**QA0 audit follow-ups (shipped):**
- **Slice A — `fix(nav): rename re:tuals tab`** (commit `68b45a8`). Tab 2's nav-bar tuple changed from `("hourglass", "usage")` (a misleading leftover from before the Timer→Rabbit Hole tab swap) to `("rectangle.stack.fill", "re:tuals")`. Icon + label now match the view that mounts there.
- **Slice B — `feat(ai): cache trail previews per session`** (commit `98316c0`). `AITrailSessionStore` is a `@MainActor` in-memory singleton with 1h TTL (per `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §7`). `AITrailRequestBuilder.cacheKey(forRoot:)` derives a `Hashable` key from the engagement UUID + canonicalized request inputs. `TrailPreviewSheet.load()` routes through `AITrailSessionStore.shared.loadingResponse(for:call:)`: cache hit returns immediately without a proxy call; cache miss fires one `callTrail`; **failures are not cached** so the retry button works fresh. In-memory only — no SwiftData persistence; resets on cold launch.
- **Slice C — `polish(settings): clarify parked capability copy`** (commit `2258a54`). Settings rows that previously exposed framework jargon (`DeviceActivity`, `FamilyControls`, `fallback signal`, `TimerSession`, `feasibility doc · Phase 7B spike`) now read as a user-facing local-status surface (`screen-time connection`, `app-boundary permission`, `your logged rabbit holes`, `parked for v2`, `tracks app usage when this lands`). No data-control behavior changed; "parked for v2" reads honestly without sounding broken.

Tests at last checkpoint:
- **357 / 357 passing across iOS suites** after QA0 Slice B (post-clean-build count fluctuates 351–357 because of the conditionally-skipped Keychain suite; zero failures).
- Proxy tests passing in the sibling repo post-6E-B `/v1/trail` endpoint (counts maintained in the proxy repo's README).

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
- **Known persistent drift** (two files, both leave unstaged on every slice unless the user explicitly opts to commit them):
  - `re_direct.xcodeproj/project.pbxproj` — personal signing drift (`DEVELOPMENT_TEAM = F9BT3PQ9Z6`, `CODE_SIGN_IDENTITY[sdk=macosx*] = "Apple Development"`).
  - `re_direct.xcodeproj/xcshareddata/xcschemes/re_direct.xcscheme` — local debug-diagnostics drift from physical-device testing (e.g. `disableMainThreadChecker = "YES"`, `LastUpgradeVersion`/`version` toggles between Xcode runs). Cosmetic to the repo, useful per-developer; do not stage unless explicitly asked.
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
- Stage either of the two known Xcode local drifts unless asked: `re_direct.xcodeproj/project.pbxproj` (signing) or `re_direct.xcodeproj/xcshareddata/xcschemes/re_direct.xcscheme` (debug diagnostics).

## Likely next slices (proposed, not started)

**Posture:** the v1 core loop is shipped. The next phase is hardening / polish, not broad feature expansion. **Avoid large new features unless the user explicitly asks.**

### Recommended next

- **MILESTONE-QA1 — product hardening / manual QA pass.** End-to-end manual walkthroughs of the v1 spine on simulator + physical device, with specific attention to: cold launch, schema migration sanity (RH1 + RH3-E + 6E-D1 additions), Daily Direct AI vs seeded fallback, Re:Log log flow, Rabbit Hole tab full loop (create / attach / deepen / accept), `TrailPreviewSheet` loading / success / failure / retry paths, trail cache hit/miss behavior, Settings parked-copy reads cleanly. **No code changes expected**; output is a bug list ordered by severity. If real issues surface, address them in a single small commit per finding. Likely 1 session.

### Optional small fills (any can land next, in any order)

- **Phase 6E-E** — Seeded `TopicTrail` fallback for proxy-unavailable. When the proxy is unreachable, render a matching seeded trail for the root's topic instead of the quiet "couldn't fetch a trail just now." copy. May require a seed-content audit if `seed/curiosity_seed_v1.json`'s `TopicTrail` coverage is too thin. Smallest remaining 6E work.
- **Thread-detail polish** — small slice options: surface `thread.summary` in `ThreadPreviewSheet` (currently persisted by RH3-D + 6E-D1 but not displayed); a dedicated thread-detail screen with edit/close affordances; an "and N more arc/arcs" overflow tap to a paginated list. Low risk, no schema impact.
- **F4 — `AIRecommendation` cache row pruning.** Gradual storage bloat from un-pruned Daily Direct cache rows. Add a max-rows cap or scheduled cleanup.

### Available but **NOT** recommended without explicit user direction

- **Phase 6E-F** — Additional trail triggers (from Daily Direct card; from existing thread "extend with AI"). Deferred until 6E quality is validated in real use.
- **RH4** (canonical) — re:tuals back-face groups engagements by thread (read-only). Depends on RH2 (done).
- **RH5** (canonical) — Dashboard "continue an open thread" Daily Direct variant. Local-only selection; no proxy contract change. Depends on canonical RH3 / Phase 6E (which is shipped).
- **REF3 / REF3.1** — post-ritual reflection (per `docs/REFLECTION_ARCHITECTURE.md` §11). Defined; not implemented. **Parked.**
- **Slice 7.1** — Apple Sign-In capability + end-to-end verification (manual Xcode UI step required). Standalone; can land anytime when the user wants to ship to TestFlight.
- **Phase 7B** — DeviceActivity feasibility spike. **Parked**, pending Apple Developer Program + Family Controls entitlement access. Resume only on explicit user signal.

## First task in next chat

1. **Run `git status --short`.** Confirm only the two known Xcode local drifts are unstaged (if present): `re_direct.xcodeproj/project.pbxproj` (personal signing values) and/or `re_direct.xcodeproj/xcshareddata/xcschemes/re_direct.xcscheme` (debug diagnostics — `disableMainThreadChecker = "YES"` etc.). No other working-tree changes expected. Confirm `origin/main` is in sync.
2. **Read the handoff doc set**, in this order:
   - This file (`docs/AGENT_HANDOFF.md`) — Milestone callout + Current implementation state + Likely next slices
   - `docs/ROADMAP.md` — slice-sequence table for status snapshots
   - `docs/RABBIT_HOLE_THREADS.md` — RH architecture (load-bearing; §13 anti-scope-creep rules)
   - `docs/AI_INTEGRATION_PLAN.md` — Phase 6 lane overview
   - `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md` — 6E details
3. **Ask the user which direction.** The v1 core loop is shipped (Milestone callout above). Three first-class options for the next slice:
   - **MILESTONE-QA1** — product hardening / manual QA pass. Recommended next if the goal is stability before any further feature work.
   - **Phase 6E-E** — seeded `TopicTrail` fallback for proxy-unavailable trails. Small fill; ~half a slice.
   - **Thread-detail polish** — surface `thread.summary` in `ThreadPreviewSheet`, or build a dedicated thread-detail screen. Low risk, no schema impact.
   - Or something else entirely (Slice 7.1, RH4/RH5, REF3, Phase 7B unparking). Treat large feature requests with the §13 anti-scope-creep rules in `docs/RABBIT_HOLE_THREADS.md`.
4. **Do not start coding until the user approves the slice scope.** Do not auto-pick a slice from the "Available but NOT recommended" list without explicit user direction.
5. **Do not stage either Xcode drift** in any commit unless the user explicitly opts in.
