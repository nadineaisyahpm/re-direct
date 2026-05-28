# Rabbit Hole Threads — Architecture (RH0)

Status: **documentation-only**. No source code lands from this slice. Implementation begins at RH1, after this document is accepted.

This document defines `RabbitHoleThread` — the next architectural layer above `CuriosityEngagement` — and locks the contract every later slice (RH1+, Phase 6E, future Daily Direct surfaces) has to honor.

It supersedes any earlier informal use of the word "thread" in commit messages, chat logs, or `AGENT_HANDOFF.md`. Where this document and an older note disagree, this document wins.

---

## 1. Purpose

re:direct already records "I went down this rabbit hole" as a flat `CuriosityEngagement` row. That row is correct but lonely — it cannot express the most common shape of real curiosity:

> *"I read this article, which led me to that video, which left me with a question I want to reflect on tomorrow."*

A **Rabbit Hole Thread** is the connective tissue that turns a sequence of related engagements into one continuous, resumable rabbit hole. It is the unit Daily Direct, Re:Log, and (eventually) AI deepening will speak about when they say "continue this rabbit hole."

### Non-goals

A thread is **not**:

- A `TimerSession` aggregate. Threads have nothing to do with boundary commitments. Timer/Boundary remains parked as v2 (`docs/DEVICE_ACTIVITY_FEASIBILITY.md`); threads must not depend on it.
- A reflection container. `ReflectionEntry.body` continues to live only on `ReflectionEntry`, attached as it is today. Threads link to reflections through their engagements; they do not own reflection text.
- A replacement for `CuriosityEngagement`. Engagements remain the atomic record of "the user actually engaged with something." Threads are a grouping/ordering layer above them.
- A new AI surface. RH0 specifies the *data shape* AI will eventually write into (see §7); it does not introduce new AI capability beyond what `docs/AI_INTEGRATION_PLAN.md` already documents.

---

## 2. Conceptual definition

A **Rabbit Hole Thread** is an ordered, user- or AI-acknowledged sequence of `CuriosityEngagement` rows that the user considers one continuous curiosity arc.

Key properties:

- **Topic-centric, not method-centric.** A thread may contain engagements across any of the five `RedirectMethod` slugs (`read`, `watch`, `mini-game`, `reflect`, `deep-dive`). A thread that begins with a `read` engagement and continues with a `watch` and a `reflect` is the normal case, not the exception.
- **Optional.** Engagements do not have to belong to a thread. An engagement logged from the existing Re:Log "+ log a rabbit hole" sheet remains valid as a standalone row. There is no migration that forces existing rows into threads.
- **Ordered.** Engagements inside a thread carry a stable order — the order the user traversed them, not just `engagedAt` sort. Order is needed because two engagements can share the same minute, and because AI-generated trails (§7) arrive as an inherently ordered list.
- **Resumable.** A thread has a notion of "where I left off" so Daily Direct and Re:Log can suggest a next step inside an open thread. RH0 defines the status field; the actual "next step" UX is a later slice.
- **Local-first.** Threads are SwiftData rows on device. No thread metadata is added to any outbound AI payload beyond the sanitized interest signals the proxy already accepts.

A thread is **memory and continuity**. It is not a commitment, a schedule, or a timer.

---

## 3. Proposed data model — `RabbitHoleThread`

The exact SwiftData syntax lands in RH1. RH0 fixes the field set and the relationships.

```
RabbitHoleThread
  id: UUID
  title: String                       // short editorial title, user- or AI-supplied
  summary: String?                    // optional one-paragraph "what this thread is about"
  createdAt: Date
  lastEngagedAt: Date                 // mirrors max(engagements.engagedAt); cached for sort
  status: ThreadStatus                // .open | .resting | .closed
  sourceKind: ThreadSourceKind        // .manual | .aiDeepened | .autoGrouped
  seedTopic: CuriosityTopic?          // optional link if the thread germinated from seeded content
  seedPrompt: CuriosityPrompt?        // optional link
  deletedAt: Date?                    // soft-delete; consistent with the rest of the schema
  engagements: [CuriosityEngagement]  // ordered; see §4
```

### Enumerations

```
ThreadStatus
  .open       // user is actively traversing it; eligible for "continue" suggestions
  .resting    // user paused; still listed; can be reactivated by logging into it
  .closed     // user explicitly finished it; hidden from default "continue" suggestions

ThreadSourceKind
  .manual         // user created via "+ start a thread" or "thread this engagement"
  .aiDeepened     // materialized from an accepted Phase 6E trail (see §7)
  .autoGrouped    // future: heuristic grouping of unthreaded engagements; not in RH1
```

Status transitions are user-initiated in RH1. Automatic resting (e.g. "no engagements for N days → resting") is deferred; do not implement it without an explicit slice.

### What is *not* on the thread

Intentional omissions, called out so later slices do not silently add them:

- No `methodSlug`. Threads are cross-method (§2). The lane displayed in re:tuals is derived from the engagements inside, not stored on the thread.
- No reflection body, ever. Reflection text lives on `ReflectionEntry`. A thread reaches reflection only through an engagement that links to one.
- No `TimerSession` field. Threads are not boundary-aware.
- No outbound-AI fields (no `lastSentToProxyAt`, no `aiPromptInputHash`). Threads stay local.

---

## 4. Relationship to `CuriosityEngagement`

`CuriosityEngagement` is unchanged in shape by RH0. The relationship is additive:

- A `CuriosityEngagement` may belong to **zero or one** `RabbitHoleThread`. Threading is optional.
- The thread owns the ordering of its engagements (`engagements: [CuriosityEngagement]`, ordered). RH1 will choose the SwiftData mechanism (an explicit `orderIndex: Int` on the engagement side is the most likely shape, decided in RH1).
- Adding an engagement to a thread does not mutate the engagement's existing fields (`methodSlug`, `engagedAt`, `note`, etc.). Threading is a join, not a rewrite.
- Removing an engagement from a thread does not delete the engagement. It becomes unthreaded again.
- Soft-deleting a thread (`deletedAt`) does not soft-delete its engagements. Engagements outlive their thread.

### Backwards compatibility

All existing `CuriosityEngagement` rows in the wild remain valid and visible after RH1 ships. They simply have no thread relationship. Re:Log, re:tuals, and Dashboard continue to show them exactly as today.

No data migration runs. No backfill creates "singleton threads" for legacy rows. If a user wants to thread a historical engagement, they do so manually in a later slice's UI (the affordance is defined no earlier than RH2).

---

## 5. Relationship to `ReflectionEntry`

`ReflectionEntry` is untouched.

- A thread reaches a reflection only via an engagement: `thread → engagement → reflectionEntry` (the engagement-reflection link defined in `docs/REFLECTION_ARCHITECTURE.md`).
- A thread never carries `ReflectionEntry.body` in any field, derived value, summary, or outbound payload.
- The Reflect-method dual-write (REF2) and post-ritual reflection (REF3) flows are unchanged. They may, in a later slice, opt to attach the resulting engagement to an active thread — but that is an RH2+ decision, not an RH0 mandate.
- Reflection bodies still never leave the device. RH0 introduces no new exception.

---

## 6. Relationship to Daily Direct and future AI deepening

### Daily Direct (Phase 6D, shipped)

Daily Direct today produces *one fresh suggestion* per cold launch from sanitized interest seeds. RH0 does not change that contract.

What RH0 unlocks for a future Daily Direct slice (not part of RH1):

- Daily Direct may, in a later slice, choose between **"fresh topic"** and **"continue an open thread you already started"** as the day's recommendation. The selection logic is local. No thread content is sent to the proxy.
- If Daily Direct surfaces a "continue thread X" card, tapping it is logging a new engagement into that thread — not creating a new thread.

These behaviors are explicitly out of scope for RH1.

### Phase 6E — rabbit-hole deepening (the locked bridge)

`docs/ROADMAP.md` defines Phase 6E as: "extends one `CuriosityEngagement` into a 3–5-step intentional trail (article / video / question / reflection / topic). Ships transient-first (no auto-persist)."

RH0 locks the persistence contract that 6E must use when it does persist:

1. The user is shown an AI-generated trail of 3–5 steps. The trail is transient.
2. The user explicitly **accepts** the trail (the accept affordance is a 6E concern; RH0 only requires that acceptance be explicit, not implicit-on-view).
3. On acceptance, the app materializes **exactly one** `RabbitHoleThread`:
   - `sourceKind = .aiDeepened`
   - `status = .open`
   - `title` = AI-supplied trail title (sanitized; falls back to seed topic title if missing)
   - `seedTopic` / `seedPrompt` = the originating engagement's topic/prompt if any
   - `engagements` = N `CuriosityEngagement` rows in trail order, one per step
4. Each materialized engagement carries the `methodSlug` implied by its step kind (article → `read`, video → `watch`, question/reflection → `reflect`, deeper-topic → `deep-dive`). Steps that do not map cleanly to a method are skipped, not coerced.
5. The originating engagement (the one the user was on when 6E fired) is added to the thread as the **first** engagement if it isn't already part of another thread; otherwise the new thread starts at the trail's step 1 and the originating engagement is linked via `seedTopic`/`seedPrompt` instead. The exact rule lands in the joint RH1/6E coding slice; RH0 fixes that there must be exactly one outcome, not both.
6. If the user does not accept the trail, **no thread is created**. 6E remains transient-first.

This is the only AI→thread path RH0 sanctions. Auto-threading of unaccepted trails, background AI grouping of existing engagements, and AI-suggested thread merges are all out of scope. They require their own slice and their own privacy review.

### Privacy posture (unchanged but worth restating)

- Thread titles, summaries, status, and engagement contents stay on device.
- Outbound proxy payloads continue to carry only the sanitized signals the proxy denylist already permits.
- Reflection bodies remain forbidden. A thread that contains a reflect-method engagement does not pull that engagement's reflection body into any AI request.

---

## 7. Relationship to Re:Log

Re:Log's job is unchanged: **summarize across methods, topics, sessions, and reflections.**

Once threads ship (RH2 or later — RH1 is model-only), Re:Log's Recent Rabbit Holes section evolves:

- Threaded engagements collapse under their thread, shown as one row with a count ("3 steps"), expandable to the underlying engagements.
- Unthreaded engagements continue to render exactly as they do today — flat, one row per engagement.
- The Re:Log Dashboard widget count remains "rabbit holes." Whether the headline number counts threads, engagements, or "threads + unthreaded engagements" is an RH2 decision. RH0 only requires that the chosen counting rule be documented in that slice and stay honest to the empty-state convention (`0 / 1 / N`).

Re:Log never writes threads. Thread creation surfaces are Dashboard (via accepted 6E trails) and a future explicit "thread this" affordance (RH2). Re:Log is read-only on threads, consistent with how it treats `TimerSession` and `ReflectionEntry` today.

---

## 8. Relationship to re:tuals method lanes

re:tuals is per-method memory. Threads are cross-method (§2). The reconciliation:

- A thread's engagements appear on the back face of **every** method lane whose slug matches at least one of its engagements. A `read → watch → reflect` thread is visible from the `read`, `watch`, and `reflect` lanes — once per lane, scoped to the engagements that actually carry that lane's slug.
- The back face groups visually: engagements that belong to a thread render under a small thread header ("part of: *thread title*"); unthreaded engagements continue to render as today.
- re:tuals never writes threads. It never reassigns an engagement to a different thread. It never closes or reopens a thread. The re:tuals back face is inspection-only, consistent with the existing invariant.

The `activeRedirectMethodSlug` shared state (Slice T-shared, proposed) is unaffected by threads. The active method is still chosen by Timer. Threads do not introduce a `currentThreadID` shared state in RH1; if one is ever needed (e.g. for a Dashboard "resume" card), it lands in its own slice.

---

## 9. What happens to unthreaded engagements

Nothing changes for them. Concretely:

- They keep rendering in Re:Log Recent Rabbit Holes.
- They keep counting in the Dashboard Re:Log widget.
- They keep appearing on the re:tuals back face for their lane.
- They are not auto-grouped into threads in RH1 or RH2. `ThreadSourceKind.autoGrouped` exists in the enum so the schema does not need to widen later, but no producer for it ships until a dedicated slice approves the heuristic and its privacy implications.

Unthreaded is a first-class state, not a transitional one.

---

## 10. What happens to Timer / Boundary in v1

Unchanged and uninvolved.

- `TimerSession` is not touched, not deleted, not migrated.
- Threads carry no reference to `TimerSession` and no derived field from it.
- The Timer surface is not modified by any RH slice.
- Phase 7 / Phase 7B / Phase 7C remain parked per `docs/DEVICE_ACTIVITY_FEASIBILITY.md`. The thread architecture must not assume DeviceActivity ever ships.

If a future slice (post-Phase 7C, hypothetical) wants to associate a thread with the boundary session during which it grew, that link lands on the engagement side (`CuriosityEngagement.session`, already proposed) — not on the thread. Threads stay boundary-agnostic.

---

## 11. Proposed slice sequence

Status as of this revision: **RH0, RH1, RH2, and RH3 are done.** RH4 onward remain proposed and ship only with explicit approval. Phase 6E (the proxy + iOS sides of AI-deepened trails) shipped through 6E-D2, which is what implements the canonical RH3 contract (the 6E ↔ thread persistence bridge per §6).

| Slice | Goal | Status | Depends on |
|---|---|---|---|
| **RH0** | This document — architecture, invariants, slice sequence | **done** | — |
| **RH1** | `RabbitHoleThread` SwiftData model + `ThreadStatus` / `ThreadSourceKind` enums + relationship to `CuriosityEngagement` (ordering mechanism chosen here) + tests. **No UI.** Model is invisible to the user; threads can only be created in tests. | **done** | RH0 accepted |
| **RH2** | First user-facing thread surface. **Implemented as the design plan's RH3-B/C/D/E series** (`RabbitHoleView` at tab 1; today card + your-threads list + loose-ends section; `NewRabbitHoleThreadSheet` for manual `.manual` creation; `AttachToThreadSheet` for engagement attachment; read-only `ThreadPreviewSheet`). Re:Log Recent Rabbit Holes grouping is **not** part of this slice — deferred. | **done** | RH1 |
| **RH3** | Joint 6E ↔ thread persistence slice. Implements the §6 contract: accepted AI trail materializes one `.aiDeepened` thread + N step `CuriosityEngagement` rows. **Implemented as Phase 6E-D1 (`AITrailMaterializer` + the additive `seedTopic`/`seedPrompt` fields on `RabbitHoleThread`) + 6E-D2 (the `TrailPreviewSheet` accept gesture).** Branch A (root unthreaded → attached) vs Branch B (root already threaded → seed metadata carried) both honored. | **done** | RH1, Phase 6E |
| **RH4** | re:tuals back-face grouping by thread (§8). Read-only. | proposed | RH2 |
| **RH5** | Dashboard "continue an open thread" Daily Direct variant (§6). Local-only selection logic; no proxy contract change. | proposed | RH3 |
| **RH6 (speculative)** | Auto-grouping heuristic (`.autoGrouped` producer). Requires a privacy review and an explicit user toggle in Settings. Not on the v1 critical path. | speculative | RH4 + Settings work |

**Naming note.** Through implementation, the design plan numbered its sub-slices as RH3-B/C/D/E (B = tab swap + shell, C = read-only overview, D = manual create, E = attach loose ends). Those four commits collectively implement what this document calls canonical **RH2**. The "RH3" prefix in commit history refers to the design plan, **not** to the canonical RH3 (Phase 6E bridge). The canonical RH3 was shipped separately under the Phase 6E-D1 + 6E-D2 commits (`feat(ai): materialize trails into rabbit-hole threads`, `feat(ai): deepen loose ends into trail previews`).

RH1 through RH4 are the realistic v1 envelope. RH5 and RH6 are listed so the dependency graph is honest, not because they are committed.

---

## 12. Open questions

These do not block RH0 acceptance. They are recorded so RH1 (and later slices) inherit the list instead of rediscovering it.

1. **Ordering mechanism.** Explicit `orderIndex: Int` on `CuriosityEngagement`, an array stored on the thread, or a join table? RH1 decides. Trade-off is SwiftData ergonomics vs. reorder cost.
2. **Engagement-in-two-threads.** RH0 says an engagement belongs to *zero or one* thread. Is this strict, or do we eventually want many-to-many for cross-referenced rabbit holes? RH0 holds the line at zero-or-one; revisit only if a real user signal forces it.
3. **Thread title editing.** Can the user rename a thread after creation? Likely yes, RH2. Confirm in RH2's design.
4. **Thread soft-delete cascade UX.** Deleting a thread leaves engagements behind (§4). Is that the right default, or should the user be offered "delete thread + its engagements"? RH2 design call.
5. **6E originating-engagement rule (§7 step 5).** RH0 mandates exactly one outcome; the joint RH1/6E slice picks which.
6. **Auto-resting threshold.** If we ever auto-transition `.open → .resting`, on what signal? RH6 territory; do not pre-decide.
7. **Re:Log counting rule.** Threads vs. engagements vs. union in the Dashboard widget headline number — RH2 decides and documents.
8. **Re:tuals lane scoping.** Confirm that a thread visible on multiple lanes (§8) is the right UX, vs. surfacing it on only the lane of its most recent engagement. RH4 design call.

---

## 13. Anti-scope-creep rules (load-bearing)

Future slices, including those listed in §11, must not cross these lines without an explicit doc update to this file:

- **Do not** add `methodSlug` to `RabbitHoleThread`. Threads are cross-method by design (§2).
- **Do not** add reflection body, summary derived from reflection body, or any reflection text to a thread field. Reflection bodies stay on `ReflectionEntry` (§5).
- **Do not** add `TimerSession`-derived fields to a thread. Threads are boundary-agnostic (§10).
- **Do not** send thread metadata, titles, summaries, or engagement contents to the AI proxy. The proxy contract in `docs/AI_INTEGRATION_PLAN.md` is unchanged (§6 privacy).
- **Do not** auto-create threads from unaccepted AI trails or from background heuristics in RH1–RH5. `.autoGrouped` is reserved for an explicitly approved RH6.
- **Do not** force a backfill that wraps existing `CuriosityEngagement` rows in singleton threads. Unthreaded is permanent and first-class (§9).
- **Do not** let re:tuals or Re:Log write threads. Write surfaces are Dashboard (via 6E acceptance) and the explicit RH2 affordance (§7, §8).
- **Do not** introduce a `currentThreadID` shared state in RH1. If needed later, it lands in its own slice (§8).
- **Do not** treat a thread as equivalent to a `TimerSession`. They are independent records (§1 non-goals).
- **Do not** delete `TimerSession`, demote it from the schema, or treat its rows as thread inputs. Timer remains parked, not removed (`AGENT_HANDOFF.md` invariants).
- **Do not** resume Timer/DeviceActivity work under the banner of "threads need it." Threads explicitly do not need it (§10).

If a future slice has a legitimate reason to cross one of these lines, the correct response is to amend this document first, get approval, and only then write the code.

---

## 14. Acceptance for RH0

RH0 is documentation-only. Acceptance means:

1. This file lands on `main`.
2. `docs/ROADMAP.md` lists RH0 as done and RH1–RH5 as proposed.
3. `docs/AGENT_HANDOFF.md` updates the "Likely next slices" section to point at RH1 as the next implementation slice.
4. No Swift source changes. No schema changes. No tests added or removed.

Once accepted, RH1 may begin.
