# re:direct — Roadmap

This document is the corrected product architecture and the implementation roadmap for re:direct. It supersedes any older slice-level framing in commit messages or chat logs.

## Product

re:direct is a SwiftUI iOS app that helps people set gentle boundaries around distracting apps and then *redirect* their attention toward intentional curiosity rituals instead of passive doomscrolling. The product loop has four beats:

1. **Discover** a curiosity (Dashboard).
2. **Commit** to a boundary and choose a redirect method/category (Timer).
3. **Remember** what the user has done within each method, and offer return paths (re:tuals).
4. **Summarize** behavior across methods, topics, sessions, and reflections (Re:Log).

The visual language is **paper + glass** — warm paper texture as the emotional base, restrained iOS liquid glass for tactile controls, editorial typography over information density.

## Principles

- **Local-first.** Reflections, app-usage data, timer history, prompt history, and curiosity engagements all live on the user's device. Nothing leaves it unless we deliberately authorize the boundary crossing.
- **Provider-agnostic AI.** When AI generation arrives, it goes through a thin proxy with a stable contract — we don't lock to one vendor.
- **Privacy by minimization.** When a remote service is eventually called, only sanitized data (interest keywords, mood, time budget) crosses the boundary. No raw reflections. No Apple identity material forwarded.
- **Surgical change.** Each slice touches one concern. The carousel card is correct; the data going into it is the lever.
- **Honest empty states.** Copy adapts to 0 / 1 / N. Numbers reflect reality, not template defaults.

## Surface responsibilities

The four primary screens each own one verb. Blurring them creates the kind of overlap that produced the Slice 8 rabbit-hole-count confusion.

### Dashboard — *discovers*

- Daily curiosity carousel sourced from seeded `CuriosityTopic` rows.
- Search affordance (placeholder copy today).
- Re:Log preview widget — a compact summary that reads from local data only.

Does **not** own: session telemetry, per-method history, aggregate analytics.

### Rabbit Hole — *continues* (tab 1)

Full local v1 workflow shipped via the design plan's RH3-B/C/D/E series (= canonical RH2 per `docs/RABBIT_HOLE_THREADS.md §11`):

- Today card — most recently engaged thread, colored by `ActiveMethodStore.activeRedirectMethodSlug` (paper-cream fallback when no active method).
- Your-threads list — next 3 open/resting threads with teal/mauve accent bars; overflow as "and N more arc/arcs".
- Loose ends — 3 most recent unthreaded `CuriosityEngagement` rows; each has an active `thread?` pill that opens `AttachToThreadSheet`.
- Manual thread creation via `+ new thread` capsule (top-right) and empty-state CTA → `NewRabbitHoleThreadSheet`.
- Engagement attachment via `AttachToThreadSheet` — single-tap confirm; closed/deleted threads excluded from picker.
- Read-only `ThreadPreviewSheet` — inspects a thread's engagements (capped at 25; reflection bodies never displayed).

Does **not** own: picking a method (re:tuals), engagement archive (Re:Log), curiosity discovery (Dashboard), reflection writing (Reflect ritual), thread edit/delete/close (deferred), DeviceActivity/Timer integration (parked).

AI-deepened trails (Phase 6E, **shipped through 6E-D2**): a loose-end engagement gains a `[deepen]` pill alongside the existing `[thread?]` pill. Tap → `TrailPreviewSheet` calls the Cloudflare Worker `/v1/trail` endpoint → DeepSeek returns a bounded 3–5 step trail → user reviews and accepts → `AITrailMaterializer` writes one `.aiDeepened` `RabbitHoleThread` + N step `CuriosityEngagement` rows in one transaction. Cancel/dismiss writes nothing. Privacy: only the engagement's title + method slug + coarse recency bucket leave the device — no reflection body, no note, no identifiers, no raw timestamp.

### Timer — *parked for v2*

- No longer occupies the primary tab bar as of RH3-B; `RabbitHoleView` holds tab 1.
- `TimerView` source and the `TimerSession` model **remain in the codebase and schema** for Phase 7B / 7C unparking. No deletion, no migration.
- Historical responsibilities (picks a redirect method category, duration, theme, tracked apps; commits a `TimerSession` row) are preserved in the existing `TimerView` source for when Phase 7B resumes. Settings exposure for the parked surface is deferred — see `docs/AGENT_HANDOFF.md`.

Does **not** own: picking specific content, logging engagement, visualizing past sessions.

### re:tuals — *remembers* (per method)

- Each card represents one method lane (one `RedirectMethod`).
- The card front carries hardcoded editorial lane copy; tapping flips to a back face that shows the user's recent `CuriosityEngagement` rows for that lane (or a lane-personalized empty state).
- The card back is **inspection-only**: a record of what the user did inside that lane and a return path into existing engagements. It does **not** commit anything.

Does **not** own:
- Picking a method category. Timer already did that.
- A replacement selection CTA. **No "continue this lane →"** or similar. The card back is memory, not a chooser. If a future surface needs to commit a method, that commit comes from the shared active method state (see Slice T-shared below), not from a tap on a re:tuals card.
- Per-engagement detail UI, charts, totals, or rankings. Those belong to Re:Log.

The prototype "choose this" button remains for now because `WhenTimerEndsCard` still reads from `selectedRitual`. It retires only after the active method becomes shared state driven by Timer.

### Re:Log — *summarizes* (across methods)

- Aggregate, cross-method analytics: top topics overall, reflections, total time across lanes, optional Screen Time recap when available, behavioral patterns.
- Reads from `TimerSession`, `ReflectionEntry`, `CuriosityEngagement` (future), and optionally Screen Time aggregates (research-gated).

Does **not** own: per-lane drill-down (re:tuals does that). Real-time session state.

## Data model — status by entity

| Entity | Status | Meaning |
|---|---|---|
| `CuriosityTopic`, `CuriosityPrompt`, `TopicTrail`, `TopicTrailStep` | seeded, in use | Curated discovery content. Read on Dashboard. |
| `RedirectMethod` | seeded, in use | The 5-category taxonomy. Single source of truth for method slugs. |
| `ReminderTheme` | seeded, idle | Available for future ThemeGrid wiring. |
| `TrackedAppSelection` | model exists, idle | Future: which apps the user wants to set boundaries on. |
| `UserProfile` | in use (write side only) | Single local profile row. Created/updated on Apple Sign-In. |
| `TimerSession` | in use | A **boundary commitment** — start, planned minutes, optional end, completion/interruption. Created by the current Timer preview/start affordance. **NOT a rabbit hole.** |
| `ReflectionEntry` | model exists, no write surface yet | Future: reflection text linked to a `TimerSession`. |
| `Ritual`, `RitualSelection` | provisional | Original intent ("user-customized redirect templates") doesn't fit the corrected re:tuals semantics. Kept in schema with a `status: provisional` comment; decision deferred until a real driver appears (likely Slice E or later). |
| `ScreenTimeSummary` | model exists, no write surface yet | Future: daily aggregates only, never raw event logs. Gated on Phase 7 research. |
| `AIRecommendation` | model + cache in use, no producer | Read side ready; producer (the AI proxy) is Phase 6 work. |
| **`CuriosityEngagement`** | **not yet implemented** | Future: the actual rabbit-hole model. Fields proposed in Slice E1; implementation in Slice E2. |

### Proposed `CuriosityEngagement`

```
CuriosityEngagement
  id: UUID
  methodSlug: String           // joins to RedirectMethod.slug
  contentTitle: String         // optional override of topic.title
  sourceURL: String?           // optional, kept local
  engagedAt: Date
  durationSeconds: Int?        // optional self-reported time
  note: String?                // optional one-line note
  deletedAt: Date?
  topic: CuriosityTopic?       // optional link
  prompt: CuriosityPrompt?     // optional link
  session: TimerSession?       // optional: which session this happened during
```

Creation surfaces are designed in Slice E1 before any model code lands.

`CuriosityEngagement` is also the atomic record that the future `RabbitHoleThread` (RH0/RH1) groups. Threading is optional and cross-method — see `docs/RABBIT_HOLE_THREADS.md`. Engagement shape is unchanged by RH0.

### What changed semantically in this brief

Earlier work (through Slice 8) briefly counted `TimerSession` rows as "rabbit holes" in the Re:Log widget. **That was wrong** and was rolled back in Slice 8.1. The corrected model:

- Timer commits a session → `TimerSession` row.
- User engages with content (reads, watches, completes a prompt) → `CuriosityEngagement` row (future).
- A user can start 5 timers and engage with nothing; a user can engage without ever starting a timer. They are independent.

The Re:Log widget will count `CuriosityEngagement` rows once that model lands. Until then it shows persistent `0` with the honest empty-state copy "no rabbit holes yet."

### TimerSession creation note

The current preview/start affordance in `TimerView` saves a `TimerSession` on tap. That row represents a boundary commitment, not curiosity engagement. The button is currently labeled **"preview"** — that copy may want future review now that the affordance commits real data; flagged but not changed in this brief.

### Timer / Boundary note

`TimerView` is a provisional **boundary setup** surface, not a generic stopwatch module. The early local flow uses `TimerSession` rows as lightweight session telemetry while Apple Screen Time / DeviceActivity feasibility is still unknown.

Do not overbuild this surface as a regular countdown timer. If DeviceActivity and FamilyControls prove viable, this screen may evolve away from a visible timer and toward app-usage boundary configuration: selected apps, usage thresholds, active redirect method, and redirect/shield behavior. If those APIs are unavailable or too constrained, the same surface remains a manual boundary ritual with honest local session tracking.

Until Phase 7 answers the platform question, Timer work should stay small, local-first, and phrased as **boundary** behavior.

#### Arming semantics

`start boundary` **arms** a boundary. Tapping it does not mean usage time starts counting immediately. The intended future behavior:

- The user arms a boundary for selected apps and a duration.
- The boundary waits until the tracked app is actually used.
- Usage time accumulates only while the tracked app is in use.
- Completion is **system-driven** when tracked-app usage reaches the configured threshold (DeviceActivity callback, local-fallback countdown, or another system signal).
- Manual user action (`stop early`) can interrupt at any time. It cannot manually mark a boundary as completed/done.

For now:
- `TimerSession` rows are lightweight local telemetry for an armed boundary.
- No visible countdown UI.
- No copy or behavior that implies the app is tracking usage until DeviceActivity / Screen Time feasibility is proven.

User-facing language in `TimerView` should reflect arming, not real-time usage measurement. Past-tense event language in Re:Log (`{N} started`, `{N} completed`, `{N} stopped early`) is event-count language, not usage-duration language — that distinction is load-bearing.

## Phase history (what's shipped)

### Phase 1 — Foundation

- 14-entity SwiftData schema, idempotent seed importer, container wired at launch.
- Provider-agnostic AI proxy contract types (request/response/error/validator/fingerprint).
- Local AI recommendation cache with SHA-256 fingerprint that never leaves the device.
- Keychain wrapper for Apple identity (`AfterFirstUnlockThisDeviceOnly`).
- Test target added by hand-editing `project.pbxproj`; shared scheme; 28 tests across 6 suites in Swift Testing.
- Sign in with Apple coordinator + persister (entitlement step deferred to Slice 7.1).
- Git workflow policy documented in `docs/GIT_WORKFLOW.md`.

### Phase 2 — Wiring the prototype to real data

- Dashboard carousel reads seeded `CuriosityTopic` rows with a per-field fallback ladder (one source per card; inert defaults for unused fields).
- Timer method labels override from seeded `RedirectMethod.displayName` where slugs match.
- Re:Log widget copy pluralized (0 / 1 / N) with numeric content transition.
- Timer start saves a `TimerSession` row; single medium-impact haptic on commit.
- Re:Log widget decoupled from `TimerSession` count (Slice 8.1) — see semantic correction above.

## Slice sequence (forward)

| Slice | Goal | Status |
|---|---|---|
| **Slice P-doc** | Lock the corrected architecture (this document + CLAUDE.md update + inline comments) | done |
| **Slice E1** | Engagement model + creation-surface design proposal (documentation-only) | done |
| **Slice E2** | Implement `CuriosityEngagement` SwiftData model + add to schema + tests | done |
| **Slice E3A** | First engagement creation surface: Re:Log "+ log a rabbit hole" sheet | done |
| **Slice E3B** | Dashboard Re:Log widget reads `CuriosityEngagement` count | done |
| **re:tuals Slice A** | Card copy reframed as method lanes | done |
| **re:tuals Slice B** | Tap-to-flip empty-state shell | done |
| **re:tuals Slice C** | Back face renders recent `CuriosityEngagement` rows for the lane | done |
| **re:tuals Slice C.1** | Card flip surface polish | done |
| **re:tuals Slice C.2** | Tactile 3D flip motion | done |
| **Slice T-shared** | Shared active method state. Timer writes `activeRedirectMethodSlug`; re:tuals reads it (highlight or scroll-to), `WhenTimerEndsCard` reads it. re:tuals never writes. Unblocks "choose this" retirement. | proposed |
| **re:tuals "choose this" retirement** | Remove the prototype `DeckControls.onChoose` path and the `selectedRitual` binding once `WhenTimerEndsCard` is driven by `activeRedirectMethodSlug` instead. No replacement selection CTA. | proposed, depends on T-shared |
| **Slice 9.1** | Re:Log shows `TimerSession` stats as a section (separate from rabbit hole count) | proposed |
| **Slice 7.1** | Apple Sign-In capability enable + end-to-end verification | proposed, manual Xcode step required |
| **Slice REF0** | Reflection architecture brief (documentation-only) — `docs/REFLECTION_ARCHITECTURE.md`. Distinguishes Reflect-method (ritual *is* writing → dual-write) from post-ritual reflection (follow-up record → attach only). | done |
| **Slice REF1** | `ReflectionPrompt` model + seed schema v2 + bundled reflection prompts (tagged by `context: "reflect-method"` / `"post-ritual"` / nil) | proposed |
| **Slice REF2** | Reflect-method writing surface. Triggered only when active method is `reflect`. Saves `ReflectionEntry` + new `CuriosityEngagement(methodSlug: "reflect", reflection: entry)`. No standalone Re:Log entry-point. Current trigger is a `#if DEBUG`-only verification hook at `TimerView`'s `start boundary`; release builds do not present from arming. | proposed, depends on REF1 |
| **Slice REF2.1** | Replace the REF2 DEBUG verification hook with the real production trigger fired by the reminder / DeviceActivity completion event. Remove the `#if DEBUG` block from `TimerView`. | proposed, depends on REF2 + Phase 7B |
| **Slice REF3-doc** | Post-ritual reflection contract — `docs/REFLECTION_ARCHITECTURE.md §11`. Triggers, eligible methods, prompt pool, save semantics, data-relationship analysis, edge cases, testing plan. | done |
| **Slice REF3** | Post-ritual reflection view + pure helpers + tests, per §11. **Ships with no trigger** (no production, no DEBUG hook); reachable only from tests until REF3.1. Saves `ReflectionEntry` linked to the just-finished `TimerSession`; attaches to first reflection-less `CuriosityEngagement` from that session if any. **Does not create a new engagement.** | proposed, depends on REF2 |
| **Slice REF3.1** | Wire the REF3 trigger. Path of least resistance: a `#if DEBUG` hook at `stop early` for verification, plus a production trigger from the real reminder / DeviceActivity completion event once Phase 7B lands. | proposed, depends on REF3 + Phase 7B |
| **Slice REF4** | Re:Log reflections section, **read-only**. Lists recent `ReflectionEntry` rows with tap-to-detail. No standalone "+ write a reflection" button. | proposed, depends on REF3 |
| **Slice REF5** | AI-generated reflection prompts via proxy (opt-in, gated, in-sheet only); reflection text never transmitted | proposed, depends on REF1 + Phase 6 |
| **Phase 6** | AI lane — promoted to next major effort. See `docs/AI_INTEGRATION_PLAN.md`. Has **no FamilyControls dependency**; can ship while Phase 7B is parked. | active |
| **Phase 6A** | Strategy / privacy / workflow plan — `docs/AI_INTEGRATION_PLAN.md`. Locks privacy boundary, fallback ladder, slice sequence 6B–6E + optional 6F. | done |
| **Phase 6A.1** | Personalization seeds plan — `docs/AI_INTEGRATION_PLAN.md §12`. User-declared interest seeds become Daily Direct's primary bootstrap signal while DeviceActivity is parked. Personal v1 defaults: Apple / Machine Learning / AI / Neuroscience / Software Engineering. Future storage home: likely a `UserProfile.interestSeeds: [String]` field, decided in a future coding slice before 6C/6D. | done |
| **Phase 6B-plan** | AI proxy skeleton implementation plan — `docs/AI_PROXY_IMPLEMENTATION_PLAN.md`. Locks proxy location (`re_direct_ai_proxy/` sibling folder), runtime (Cloudflare Workers + TypeScript), endpoint surface, request/response schemas, validation, provider abstraction, env vars, logging rules, dev/deploy commands, wire-error mapping. | done |
| **Phase 6B** | AI proxy skeleton implementation. Sibling repo at `re_direct_ai_proxy/`. Cloudflare Workers + TypeScript, single `POST /v1/recommendation` endpoint, Anthropic adapter, validation mirror, `wrangler dev` + `wrangler deploy`, no iOS code. Acceptance per `AI_PROXY_IMPLEMENTATION_PLAN.md §17`. | proposed, depends on Phase 6B-plan |
| **Phase 6C** | iOS `AIProxyHTTPClient` + integration with existing `SwiftDataAIRecommendationCache` and `AIRecommendationResolver`. Disabled unless proxy URL configured; fast timeout; fallback ladder; no `ReflectionEntry.body` ever transmitted. | proposed, depends on Phase 6B |
| **Phase 6D** | Dashboard Daily Direct — first user-visible AI feature. AI fills `topicTitle` / `promptBody` / `topicSlug` / `suggestedMinutes` on the daily card; visual design unchanged; no "AI generated" badge; provenance lives in Settings. | proposed, depends on Phase 6C |
| **Phase 6E** | Rabbit-hole deepening — extends one `CuriosityEngagement` into a 3–5-step intentional trail (article / video / question / reflection / topic). Trigger: single `deepen` affordance on loose-end rows in v1. Transient until user accepts; on accept materializes one `.aiDeepened` `RabbitHoleThread` + N `CuriosityEngagement` rows per `docs/RABBIT_HOLE_THREADS.md §6`. Seeded `TopicTrail` fallback when AI unavailable. Full plan: `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md`. End-to-end loop shipped through 6E-D2. | **done (through 6E-D2)** |
| **Phase 6E-A** | Trail plan brief — `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md`. Locks trigger, payload, persistence bridge, fallback, cost controls, slice sequence. Documentation-only. | done |
| **Phase 6E-B** | Proxy `POST /v1/trail` endpoint: handler, Zod-strict validation, denylist extension, provider adapter for trail prompts, response normalization, tests. Proxy repo only. Deployed to the shared Cloudflare Worker. | done |
| **Phase 6E-C** | iOS DTOs + HTTP client: `AITrailRequest` (final class for ARM64e safety), `AITrailResponse` + `AITrailStep` Codables, `AIProxyHTTPClient.callTrail(_:)`. Hardened JSONSerialization encode path. 19 tests in the existing `AIProxyHTTPClient` `.serialized` suite. No UI. | done |
| **Phase 6E-D1** | `AITrailMaterializer` pure helper: turns an accepted `AITrailResponse` + root `CuriosityEngagement` into one `.aiDeepened` `RabbitHoleThread` + N step `CuriosityEngagement` rows in a single transaction. Branch A (root unthreaded → attached) vs Branch B (root already threaded → new thread carries `seedTopic`/`seedPrompt` from the root). Schema additive: `RabbitHoleThread.seedTopic` + `seedPrompt` (both nullable, default nil; lightweight migration verified by simulator cold-launch). 30 tests. No UI. | done |
| **Phase 6E-D2** | UI: `[deepen]` pill on `LooseEndRow` sibling to `[thread?]`. `TrailPreviewSheet` state machine (`.loading` / `.success(response)` / `.failure`). `AITrailRequestBuilder` pure helper extracts only allowlisted fields from a `CuriosityEngagement` (title, methodSlug, coarse recency bucket). Single-hop MainActor→URLSession→MainActor pattern (matches Daily Direct's post-ARM64e-fix shape). Accept invokes `AITrailMaterializer.materialize` then dismisses. 18 tests. | done |
| **Phase 6E-E** | Seeded `TopicTrail` fallback when proxy unavailable. May require a seed-content audit. | proposed, depends on 6E-D2 |
| **Phase 6E-F** | Deferred follow-on triggers (from Daily Direct card; from existing thread "extend with AI"). Revisit after 6E quality is validated in real use. | deferred |
| **QA0** | Post-6E core-loop audit. Read-only product/UX review of the shipped v1 spine — findings ordered by severity, three small polish slices proposed (A/B/C). Documentation-only output. | done |
| **QA0 Slice A** | `fix(nav): rename re:tuals tab` — `SharedNavBar.tabs[2]` updated from `("hourglass", "usage")` (a leftover from before the Timer→Rabbit Hole tab swap) to `("rectangle.stack.fill", "re:tuals")`. | done |
| **QA0 Slice B** | `feat(ai): cache trail previews per session` — `AITrailSessionStore` `@MainActor` in-memory singleton with 1h TTL per `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md §7`. `AITrailRequestBuilder.cacheKey(forRoot:)` derives the Hashable key. `TrailPreviewSheet.load()` routes through `loadingResponse(for:call:)`; failures do not cache. In-memory only — no SwiftData persistence. | done |
| **QA0 Slice C** | `polish(settings): clarify parked capability copy` — `DeviceActivity` → `screen-time connection`, `FamilyControls` → `app-boundary permission`, `fallback signal` → `your logged rabbit holes`, `TimerSession` / `feasibility doc · Phase 7B spike` hints → `parked for v2` family. Data-control behavior unchanged. | done |
| **MILESTONE-QA1** | Product hardening / manual QA pass over the shipped v1 spine on simulator + physical device. Output is a bug list ordered by severity; bugs addressed one-per-commit if found. No new feature scope. | proposed (recommended next) |
| **Phase 6F** | AI-generated reflection prompts (= REF5 under the AI-lane name). Opt-in, in-sheet only, no reflection text transmitted. | proposed, depends on Phase 6C + REF1 |
| **Phase 7** | Screen Time API research lane. See `docs/DEVICE_ACTIVITY_FEASIBILITY.md`. **Parked**, not abandoned — Family Controls entitlement unavailable on current Personal Team. | parked |
| **Phase 7A-doc** | Feasibility brief — `docs/DEVICE_ACTIVITY_FEASIBILITY.md` §1–§9 + §11–§15. | done |
| **Phase 7B-doc** | Workflow guardrails for the 7B spike — `docs/DEVICE_ACTIVITY_FEASIBILITY.md §10`. Charter, branch policy, 7B-0…7B-5 step sequence, scope-creep rule, stop conditions, deliverable. | done |
| **Phase 7B** | DeviceActivity feasibility spike on `phase-7b-device-activity-spike` branch. Bounded by §10 guardrails; deliverable is `docs/DEVICE_ACTIVITY_SPIKE_RESULTS.md`, not an app feature. | parked, pending Apple Developer Program + Family Controls entitlement |
| **Phase 7C** | Production integration of Screen Time stack on `main`, only if Phase 7B returns go. Replaces REF2's and REF3's DEBUG triggers with real reminder/DeviceActivity events. | parked, depends on Phase 7B (go) |
| **Phase 8** | CloudKit private database sync | future |
| **Phase 9** | TestFlight family/internal distribution | future |
| **RH0** | Rabbit Hole Threads architecture brief — `docs/RABBIT_HOLE_THREADS.md`. Defines `RabbitHoleThread`, its optional, cross-method relationship to `CuriosityEngagement`, the Phase 6E → thread persistence bridge, and the RH1–RH5 slice sequence. Documentation-only. | done |
| **RH1** | `RabbitHoleThread` SwiftData model + `ThreadStatus` / `ThreadSourceKind` enums + ordering mechanism + tests. No UI; threads creatable only in tests. | done |
| **RH2** | First user-facing thread surface: `RabbitHoleView` at tab 1 (Timer parked), today card + your-threads list + loose-ends section, `ThreadPreviewSheet`, `NewRabbitHoleThreadSheet`, `AttachToThreadSheet`. **Shipped as the design plan's RH3-B/C/D/E series.** | done |
| **RH3** | Joint Phase 6E ↔ thread persistence — accepted AI trail materializes one `.aiDeepened` thread per `docs/RABBIT_HOLE_THREADS.md §6`. | proposed, depends on RH1 + Phase 6E |
| **RH4** | re:tuals back-face groups engagements by thread (read-only). | proposed, depends on RH2 |
| **RH5** | Dashboard "continue an open thread" Daily Direct variant — local-only selection; no proxy contract change. | proposed, depends on RH3 |

### Slice T-shared (notes)

The single piece of state to introduce:

```
activeRedirectMethodSlug: String?    // one of the 5 canonical slugs, or nil
```

Likely shape: a small `@Observable` model held at app scope (or scene scope), injected via `@Environment` or a custom `@EnvironmentObject`. Persistence is optional for v1 — in-memory is fine; if persisted, use `@AppStorage` with a string key.

Write surface (single):
- Timer's method picker on commit / start.

Read surfaces:
- `WhenTimerEndsCard` — shows the active lane's title/copy.
- re:tuals deck — may highlight the active lane (e.g. small dot on its pagination index) or scroll-to-active on appear. **Read-only**. re:tuals must not write to `activeRedirectMethodSlug`.

After this lands:
- `DeckControls.onChoose` and the `selectedRitual` binding both retire.
- The "choose this" button is removed.
- No replacement CTA is added on the re:tuals back face.

### Explicitly killed / dropped slices

- **Original Slice 6.4** ("wire re:tuals deck to seeded `CuriosityTopic`") — based on the wrong mapping; superseded by re:tuals Slices A–C.
- **Slice 6.5** (ThemeGrid seeded read) — no visible delta possible until the seed schema extends with gradient/swatch data.
- **"continue this lane →"** (any variant of a re:tuals back-face selection CTA) — would reintroduce a chooser in re:tuals and conflict with the corrected architecture. Replaced by Slice T-shared above. Do not implement.

## Risks and carry-forward

| Risk | Severity | Mitigation |
|---|---|---|
| Engagement data structure may need iteration | Medium | Slice E1 is documentation before any model code lands |
| `Ritual` / `RitualSelection` sit unused | Low | Tagged provisional in source; revisit when a real driver appears or at CloudKit migration |
| Re:tuals card editorial copy stays hardcoded | Low | Acceptable until either a seed schema extension or a content-design pass |
| `TimerSession` rows accumulate from preview taps with no completion path | Low | Slice 8.1's `0` count means they're invisible; Slice 8.1 + inline doc comment is sufficient until completion lands |
| Screen Time API uncertainty | High | re:tuals (user-declared engagement) becomes the canonical signal; Screen Time is enrichment when available |
| CloudKit migration debt (`@Attribute(.unique)` everywhere) | Known | Phase 8 task — drop unique attributes, move uniqueness to repository layer |
| Apple Sign-In runtime gated on Team setup | Known | Slice 7.1 captures the manual Xcode steps |

## Conventions

- **Commits**: subject + optional body only. No trailers, no co-author tags. See `docs/GIT_WORKFLOW.md`.
- **Tests**: Swift Testing (`@Test`, `#expect`). New behavior covered before merge; environment-dependent tests auto-skip cleanly.
- **Build**: `xcodebuild ... CODE_SIGNING_ALLOWED=NO` for CLI; entitlement-gated paths fail silently in unsigned builds.
- **Privacy disclosure**: any change that expands what data leaves the device pauses and asks before proceeding.
