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

### Timer — *commits*

- Picks a **redirect method category** (one of the 5: `watch`, `read`, `mini-game`, `reflect`, `deep-dive`) for the upcoming boundary session.
- Picks duration, theme, tracked apps.
- The preview/start affordance creates a `TimerSession` row representing the boundary commitment.

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
| **Slice REF3** | Post-ritual reflection flow for non-reflect methods. Saves `ReflectionEntry` linked to the just-finished `TimerSession`; attaches to first reflection-less `CuriosityEngagement` from that session if any. **Does not create a new engagement.** | proposed, depends on REF2 |
| **Slice REF4** | Re:Log reflections section, **read-only**. Lists recent `ReflectionEntry` rows with tap-to-detail. No standalone "+ write a reflection" button. | proposed, depends on REF3 |
| **Slice REF5** | AI-generated reflection prompts via proxy (opt-in, gated, in-sheet only); reflection text never transmitted | proposed, depends on REF1 + Phase 6 |
| **Phase 6** | AI proxy implementation (Cloudflare Worker) + iOS client | future |
| **Phase 7** | Screen Time API research spike | future |
| **Phase 8** | CloudKit private database sync | future |
| **Phase 9** | TestFlight family/internal distribution | future |

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
