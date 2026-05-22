# Slice REF0 — Reflection Architecture and Roadmap

Documentation-only. No SwiftData model is added, no UI is touched, no AI call is wired, no seed field is created in this slice. This document is the brief for the REF1–REF5 sequence that turns the dormant `reflect` lane and the dormant `ReflectionEntry` model into a working reflection ritual without breaking the corrected product architecture in `docs/ROADMAP.md`.

This brief is authored against the current source state — `reflect` exists as a method lane, `ReflectionEntry` exists as a SwiftData model, Settings counts and clears reflections, no UI creates them, and Re:Log doesn't surface them.

---

## 1. Why this brief exists

Today, `reflect` is real on the **method-lane axis** (re:tuals has a Reflect card, Timer offers `.reflect` as a redirect method category) and `ReflectionEntry` is real on the **data axis** (the model is in `ReDirectSchema.allModels`, Settings reads its count via `@Query`, S3 can soft-delete its rows). The two are not connected. No surface creates a `ReflectionEntry` row. The model exists in anticipation of this slice family.

Before any code lands, the team needs to decide:

- Whether reflections are their own data type or a flavor of `CuriosityEngagement`.
- Whether seeded reflection prompts share the `CuriosityPrompt` table or get their own.
- Where the writing surface lives.
- How AI eventually contributes prompts without ever seeing the user's text.
- **How reflection-as-the-ritual differs from reflection-after-the-ritual.**

REF0 (this doc) answers those questions. REF1–REF5 implement them.

---

## 2. Two reflection moments, not one

The single biggest decision in this brief: **there are two different reflection flows, and they save different data.** Conflating them produced the original v1 of this doc and was the reason for revision.

### 2.1 Reflect-as-method (the ritual *is* writing)

When Timer's active redirect method is `reflect`, the user **intentionally chose reflection itself as their redirect action**. There is no other ritual to perform — the writing screen is the ritual.

- Trigger: boundary fires *and* `activeRedirectMethodSlug == "reflect"`.
- What the user sees: a seeded `ReflectionPrompt` and a writing surface.
- What gets saved: a **`ReflectionEntry`** + a **`CuriosityEngagement(methodSlug: "reflect", reflection: entry)`**.
- The `CuriosityEngagement` write is correct here because the act of writing is itself the rabbit hole — there is no other engagement that could fill that slot.
- There is **no separate post-ritual reflection step afterward.** The ritual completed when the entry saved.

### 2.2 Post-ritual reflection (the ritual happened, now reflect on it)

When Timer's active redirect method is `watch`, `read`, `mini-game`, or `deep-dive`, the user already did the ritual (watched a thing, read an article, played, deep-dove). The reflection is a **follow-up record**, asking *what did you notice?* — it is not itself a rabbit hole.

- Trigger: boundary completes (or `stop early`) *and* `activeRedirectMethodSlug != "reflect"`.
- What the user sees: a short post-ritual prompt and a writing surface.
- What gets saved: a **`ReflectionEntry`** linked to the just-finished `TimerSession`. If a `CuriosityEngagement` exists for that session (the user logged a rabbit hole during it), the entry is also linked to that engagement via `CuriosityEngagement.reflection = entry`.
- **No new `CuriosityEngagement(methodSlug: "reflect")` is created.** The rabbit hole already happened in its own lane (Watch / Read / etc.); creating a reflect engagement here would double-count.
- The reflection is the closing beat of the ritual loop. The product treats it as **mandatory for closing the loop** — see §5.

### 2.3 Why this distinction is load-bearing

- The rabbit-hole count in Re:Log must remain *the number of distinct content-engagement events*. Counting post-ritual reflections as their own rabbit holes would inflate the number with metadata about other rabbit holes — exactly the Slice 8 confusion we already rolled back.
- The re:tuals Reflect-lane back face must show *moments the user reflected as their primary ritual*, not *moments the user reflected after a Watch ritual*. Without this split, the Reflect lane would silently swell with post-ritual entries that belong elsewhere.
- The data shape supports the split with **zero new fields beyond REF2's `CuriosityEngagement.reflection: ReflectionEntry?`**. Reflect-method populates the relationship on a brand-new engagement; post-ritual populates the same relationship on an existing engagement. One link, two flows.

---

## 3. Save rules per flow

### 3.1 Reflect-method save (REF2)

```
let session  = activeBoundarySession        // may be nil if no boundary armed
let prompt   = chosenReflectionPrompt        // from REF1 seeded pool
let entry    = ReflectionEntry(body: …, mood: …, session: session)
let engage   = CuriosityEngagement(
                  methodSlug: "reflect",
                  contentTitle: prompt.body,
                  session: session,
                  reflection: entry         // new field, added in REF2
              )
// one ModelContext.save()
```

Counts after save:
- `CuriosityEngagement.count` += 1 (in lane `reflect`)
- `ReflectionEntry.count` += 1
- `TimerSession.count` unchanged

### 3.2 Post-ritual save (REF3)

```
let session  = justFinishedSession                                   // required
let existing = engagementsLoggedDuring(session)                       // 0..N
let entry    = ReflectionEntry(body: …, mood: …, session: session)
for engagement in existing where engagement.reflection == nil {
    engagement.reflection = entry        // attach; do not create
}
// one ModelContext.save()
// no new CuriosityEngagement is inserted
```

Counts after save:
- `CuriosityEngagement.count` **unchanged**
- `ReflectionEntry.count` += 1
- `TimerSession.count` unchanged

Edge cases handled in REF3:
- **No engagement was logged during the session.** Entry still saves, linked to the `TimerSession` only via `ReflectionEntry.session`. Re:Log can still surface it as "you reflected after a Watch session" without inventing a rabbit hole.
- **Multiple engagements during one session.** Attach the entry to the first engagement that has no existing reflection. The remaining engagements are not back-filled — they were separate moments and should not share one reflection.
- **`stop early` with zero elapsed time.** Same as the no-engagement case; we still allow a reflection. The user can write "I bailed before I started" if they want.

### 3.3 Why dual-write is preserved only for Reflect-method

Reflect-method genuinely *is* an engagement — the user spent N minutes in re:direct typing. Post-ritual is *about* an engagement that already exists. Counting one event in `CuriosityEngagement` and an *adjunct* record in `ReflectionEntry` matches the underlying reality.

---

## 4. Seed strategy — where do prompts come from?

The seed file (`re_direct/Resources/curiosity_seed_v1.json`, schema in `seed/curiosity_seed_v1.schema.json`) currently has prompts only *as children of topics* (`Topic.prompts[].Prompt`). A reflection prompt isn't usually topic-specific — "what's one thing you didn't expect to notice today?" doesn't belong under a topic like "deep-sea biology."

**Decision (approved):** introduce a new top-level `reflection_prompts` array in the seed and a new `ReflectionPrompt` SwiftData model. Topic prompts and reflection prompts are conceptually different enough that one model would carry a discriminator forever; better to make them siblings.

### Proposed `ReflectionPrompt` model (for REF1)

```swift
@Model
final class ReflectionPrompt {
    @Attribute(.unique) var id: UUID = UUID()
    /// Stable identifier from seed; AI-runtime prompts use uuid-based slugs.
    var slug: String = ""
    /// The reflection question, shown verbatim to the user.
    var body: String = ""
    /// Optional editorial tone tag ("gentle", "curious", "honest", "tender").
    var tone: String? = nil
    /// Rough time budget — 1 to 5 minutes typically.
    var estimatedMinutes: Int = 2
    /// Provenance — "seed" or "ai-runtime". Mirrors the existing prompt source enum.
    var source: String = "seed"
    /// Optional mood tags this prompt fits ("restless", "tired", "curious"...).
    var moodAffinity: [String] = []
    /// Optional context tag indicating which flow the prompt is meant for:
    ///   "reflect-method"  — used as the prompt for a Reflect-method ritual
    ///   "post-ritual"     — used as the closing prompt after Watch/Read/etc.
    ///   nil               — usable in either flow
    /// Seeded prompts may be tagged or untagged; the writing surfaces filter
    /// by context but fall back to untagged prompts if a context-specific
    /// pool is empty.
    var context: String? = nil
    /// Soft delete (e.g. user dismissed an AI-generated prompt forever).
    var deletedAt: Date? = nil
    /// When this row first entered the local store.
    var createdAt: Date = Date()
    init() {}
}
```

The `context` field is the only addition beyond REF0-v1's proposal. It separates the two pools without forcing a separate model per flow.

### Proposed seed-schema v2 additions

A new top-level array, mirroring the existing top-level structure:

```jsonc
"reflection_prompts": [
  {
    "slug": "noticed-something-small",
    "body": "What's one small thing you noticed today that you almost didn't?",
    "tone": "gentle",
    "estimated_minutes": 2,
    "source": "seed",
    "mood_affinity": ["tired", "curious"],
    "context": "post-ritual"
  },
  {
    "slug": "what-stayed-with-you",
    "body": "Write about one thing that stayed with you from the last few minutes.",
    "tone": "honest",
    "estimated_minutes": 3,
    "source": "seed",
    "mood_affinity": [],
    "context": "reflect-method"
  }
]
```

Bundle ~10–14 prompts in v2 of the seed — a small balanced pool, half `reflect-method`, half `post-ritual`, with a couple of untagged general prompts.

---

## 5. UI surface — where does writing happen?

The original v1 of this doc recommended a Re:Log "+ write a reflection" sheet as the first creation surface. **That recommendation is retired.** Manual reflection entry in Re:Log risks becoming another fallback/manual log surface, parallel to "+ log a rabbit hole." Reflection should be integrated into the ritual/reminder flow, not exposed as a standalone log button.

### 5.1 Where reflection lives in the loop

The intended full loop (mapped to the four-verb architecture in `docs/ROADMAP.md`):

1. **Boundary armed** — Timer commits a `TimerSession` with `activeRedirectMethodSlug`.
2. **User uses the tracked app** — usage accumulates (eventually system-driven; currently local-fallback).
3. **Boundary fires / user returns to re:direct** — completion event raised (DeviceActivity threshold when Phase 7 lands, foreground reconciliation as the current fallback).
4. **Ritual** — depends on method:
   - `reflect` → REF2's writing surface (the ritual itself).
   - `watch` / `read` / `mini-game` / `deep-dive` → user does the ritual outside the app, optionally logs a `CuriosityEngagement`, then returns.
5. **Post-ritual reflection** — REF3's writing surface presents *only for non-reflect methods*. Mandatory for closing the loop in the UI sense (see §5.4).
6. **Loop closes** — `TimerSession` marked complete or interrupted; reflection entry attached; counts update.

### 5.2 Reflect-method surface (REF2)

A modal sheet, presented by the boundary/ritual flow when the active method is `reflect`. **Not a standalone tab. Not a Re:Log entry-point.** Surface details:

- Header: the chosen `ReflectionPrompt.body` in Instrument Serif Italic.
- Body: a multiline editor with calm placeholder copy.
- Optional mood chip(s) at the bottom.
- Single primary action: **save**.
- Dismissible only via save or an explicit "save without writing" (so the loop never strands).
- On save: dual-write per §3.1; the sheet dismisses and the loop closes.

The sheet is reachable only through the ritual flow. There is no Settings entry, no Dashboard button, no Re:Log button.

### 5.3 Post-ritual surface (REF3)

A modal sheet, presented automatically when:

- A non-reflect `TimerSession` completes via the local-fallback (boundary's planned end time has passed and the user returns to re:direct), **or**
- The user taps `stop early` on a non-reflect active boundary, **or** (future) DeviceActivity fires `eventDidReachThreshold` and the user returns to the app.

Surface details:

- Header: a `ReflectionPrompt` with `context = "post-ritual"` (or fallback to untagged).
- Body: a multiline editor; tone is slightly more reflective ("what did you notice?").
- Optional mood chip(s).
- Primary action: **save**.
- A secondary "skip for now" action exists, but logs a deferred state on the `TimerSession` so the prompt re-appears on next foreground until written or explicitly dismissed (see §5.4).

### 5.4 "Mandatory" — what does it actually mean?

The product treats post-ritual reflection as the loop-closing beat, but mandatory does **not** mean blocking the entire app. It means:

- The sheet re-presents on next foreground if dismissed without writing.
- A small persistent indicator (e.g., a dot on the Re:Log tab) signals an open ritual until the reflection is written or **the session is explicitly abandoned** ("dismiss this reflection" — a quieter destructive option inside the sheet, *not* on first present).
- The user can always abandon. The product's job is to make returning to the reflection the path of least resistance.

This UX detail belongs to REF3's design pass; REF0 fixes the contract, not the exact pixels.

### 5.5 What is *not* a first surface

- ❌ Re:Log "+ write a reflection" standalone button.
- ❌ Dashboard reflection card.
- ❌ Settings "write a reflection" link.
- ❌ A re:tuals Reflect-card "+ write one" affordance.

REF4 adds a **read-only** reflections section to Re:Log. None of these standalone create-buttons land in the REF sequence unless explicitly approved later as an exception.

---

## 6. AI proxy + privacy guardrails (unchanged from REF0-v1, approved)

The AI proxy contract (`re_direct/AIRecommendationRequest.swift`) already takes only:

- `interests: [String]` — topic/method slugs and tags
- `mood: String?`
- `timeAvailableMinutes: Int`
- `excludePromptHashes: [String]` — client-computed local fingerprints, dedup-only
- `providerPreference`
- `locale: String`

For reflections, the **hard rules**:

1. **Reflection body text never leaves the device.** Not to the AI proxy, not to crash reports, not to analytics, not to CloudKit (until/unless CloudKit private database lands in Phase 8, and even then encrypted-at-rest, never transmitted to third parties).
2. **AI-generated reflection prompts are seeded from interest signals only** — the same interest/mood/time-budget triple the existing contract accepts. The AI never sees what the user previously wrote.
3. **Provenance is recorded.** `ReflectionPrompt.source = "ai-runtime"` for any AI-generated row; the user can tell where a prompt came from, and a future Settings row could expose "AI-generated prompts: hide / show."
4. **Excluded fingerprints are local-only.** `excludePromptHashes` is computed by the device from prompt slugs the user has already seen; the fingerprint scheme matches the existing `AICacheKey.localFingerprint` pattern that already never leaves the device.
5. **User can disable AI prompts entirely.** A future Settings toggle (slice TBD) sets `AIProviderPreference.disabled` and the app falls back to seeded prompts. The current `"contract only · disabled"` Settings copy is honest about the default.
6. **No prompt generation happens passively.** AI generation runs only on explicit user action (e.g., a "give me another prompt" affordance in REF5), never as a background fetch and never on app launch.

A future "is this safe?" checklist for any reflection-adjacent change:

- [ ] Does any new code path read `ReflectionEntry.body`?
- [ ] Does that path write to a non-local destination (network, file outside the app sandbox, pasteboard, share sheet)?
- [ ] If yes — does the user explicitly invoke it (share button), with text shown back to them before transmit?

If any answer is wrong, the change pauses and asks.

---

## 7. Proposed slice sequence

### REF1 — `ReflectionPrompt` model + seed schema v2 + bundled prompts

**Scope**
- Add `re_direct/Models/Reflection/ReflectionPrompt.swift` per §4.
- Register in `ReDirectSchema.allModels`.
- Bump seed schema to v2: add top-level `reflection_prompts` array (schema + example).
- Bundle ~10–14 reflection prompts in `re_direct/Resources/curiosity_seed_v1.json` (or rename to v2 — decide in REF1). Half `context: "reflect-method"`, half `context: "post-ritual"`, with 2–3 untagged generals.
- Extend `SeedImporter` to import reflection prompts idempotently.
- Tests: round-trip persistence, importer idempotency, canonical-source enum (`"seed"` / `"ai-runtime"`), context-tag honored.

**Out of scope**
- No UI.
- No write surface for `ReflectionEntry`.
- No `CuriosityEngagement.reflection` field yet.
- No AI calls.

**Acceptance**
- Build green; tests pass.
- On fresh launch, the local store contains ≥ 10 `ReflectionPrompt` rows with `source = "seed"`.

### REF2 — Reflect-method writing surface

**Scope**
- Add `CuriosityEngagement.reflection: ReflectionEntry?` relationship.
- Build the modal writing sheet (§5.2) that picks a `ReflectionPrompt` with `context = "reflect-method"` (or untagged).
- Triggered only by the boundary/ritual flow when `activeRedirectMethodSlug == "reflect"`. **No Re:Log / Dashboard / Settings entry point.**
- On save: dual-write per §3.1 — new `ReflectionEntry` + new `CuriosityEngagement(methodSlug: "reflect", reflection: entry)`.
- Tests: dual-write atomicity (one `ModelContext.save()`), link integrity, count invariants (engagement +1, reflection +1).

**Out of scope**
- No post-ritual flow.
- No Re:Log section.
- No AI.

**Acceptance**
- Choosing `reflect` as the method, arming a boundary, and completing the ritual results in exactly one new `CuriosityEngagement` (lane `reflect`) and exactly one new `ReflectionEntry`, linked.
- Re:Log rabbit-hole count increments by 1.
- Settings reflection count increments by 1.

**Current trigger status (REF2 as shipped)**
- The production trigger is the real reminder / DeviceActivity completion event, which does not yet exist (gated on Phase 7B — see `docs/DEVICE_ACTIVITY_FEASIBILITY.md`).
- Until that lands, REF2 presents the writing surface from `TimerView`'s `start boundary` action **only in `#if DEBUG` builds**, as a manual-verification hook so the dual-write save path can be exercised end-to-end. Release builds do not present the surface from arming.
- The DEBUG hook is temporary. Replacing it with the real reminder trigger and removing the hook is REF2.1 (see ROADMAP).

### REF3 — Post-ritual reflection flow

The full REF3 contract is documented in **§11 — Post-ritual reflection contract**. The short version:

- Triggered after a *non-reflect* `TimerSession` completes (real trigger is reminder / DeviceActivity, future; no manual fake trigger ships until the data relationship is finalized).
- Presents the post-ritual writing sheet using a `ReflectionPrompt` with `context = "post-ritual"` (fallback: untagged → hardcoded).
- Saves a new `ReflectionEntry` linked to the just-finished `TimerSession`. If a `CuriosityEngagement` already exists from that session and has no reflection yet, the new entry is attached to it via `CuriosityEngagement.reflection`.
- **Never creates a new `CuriosityEngagement(methodSlug: "reflect")`** — that's REF2's job, not REF3's.
- Empty/dismiss writes nothing.

See §11 for triggers, eligible methods, prompt pool, save semantics, data-relationship analysis, edge cases, testing plan, and acceptance criteria.

### REF4 — Re:Log reflections section (read-only)

**Scope**
- New Re:Log section showing recent `ReflectionEntry` rows.
- Each row: relative date, mood (if set), single-line body preview, source-method chip (the `methodSlug` of the linked `CuriosityEngagement.reflection ← entry` lookup, or "post-ritual" if linked only via `session`).
- Tap a row → read-only detail sheet with full body, mood, tags, timestamp, link back to the session if any.
- **No standalone "+ write a reflection" affordance.** Creation remains gated to the REF2 / REF3 flows.

**Out of scope**
- No editing.
- No standalone create button.
- No AI.

**Acceptance**
- Re:Log shows the most recent ~10 reflections.
- Tapping a row reveals full text.
- No path in Re:Log creates a new reflection.

### REF5 — AI-generated reflection prompts (opt-in, gated)

**Scope**
- Thin client for the AI proxy contract (depends on Phase 6 progress).
- A "give me another prompt" affordance inside both REF2 and REF3 writing sheets. On tap, call the proxy with `interests`, `mood`, `timeAvailableMinutes`, `excludePromptHashes` (derived from local prompt slugs only). On success, insert a `ReflectionPrompt(source: "ai-runtime", context: <current-flow>, …)` and show it.
- Provenance UI: a small italic "AI-suggested" caption under AI-source prompts.
- Settings row that flips `AIProviderPreference` to `.disabled` and hides AI-generated prompts.

**Hard guardrails (verified in tests)**
- The request payload does **not** include any `ReflectionEntry.body` content.
- The request payload does **not** include `excludePromptHashes` that derive from reflection body text — only from prompt slugs.
- A unit test fingerprints all outgoing payloads and asserts no substring overlap with any local `ReflectionEntry.body`.

**Out of scope**
- No background generation.
- No multi-prompt batching.

**Acceptance**
- Build green; tests pass including the privacy assertions above.
- AI generation only fires on explicit user tap inside an open writing sheet.
- Disabling AI in Settings stops generation and hides existing `ai-runtime` prompts from the pool.

---

## 8. Open questions (sign off before REF1)

1. **Is `CuriosityEngagement.reflection` the right link direction?** Recommendation: yes. One engagement → one reflection. Cleaner than putting an engagement link on `ReflectionEntry`.
2. **Do we bump the seed file to v2, or extend v1 additively?** Recommendation: bump to v2 (schema additions get a version bump per the existing schema policy).
3. **Should the REF2 sheet allow free-form (no prompt) writing?** Recommendation: yes — "skip the prompt" stays as an affordance inside the writing screen.
4. **Should mood be required?** Recommendation: optional. Required-mood UIs feel like therapy intake forms; that's not the editorial tone re:direct sets.
5. **Should `ReflectionEntry.tags` be exposed in REF2/REF3 or deferred?** Recommendation: defer. The field exists on the model; no UI yet.
6. **Are seed reflection prompts localized, and how?** Recommendation: same locale-per-file policy as the existing seed. REF1 ships `en-US` only.
7. **What exactly triggers REF3 today, before Phase 7B?** Recommendation: foreground reconciliation when a session's `plannedEndAt < now` and method is not `reflect`; plus the immediate path when the user taps `stop early`. REF3's spec must enumerate these triggers explicitly.

---

## 9. What this slice did NOT do

- Did not add `ReflectionPrompt` or any other model.
- Did not change `ReflectionEntry`.
- Did not modify `CuriosityEngagement` (no `reflection:` relationship yet).
- Did not extend the seed schema.
- Did not bundle reflection prompts.
- Did not touch `RetualsView`, `ReLogView`, `TimerView`, or Settings.
- Did not write or wire any AI call.

All of the above are explicit REF1–REF5 work, gated on this brief being accepted.

---

## 10. Next coding prompt (if REF1 is approved)

```
Run Slice REF1: ReflectionPrompt model + seed schema v2.

Scope:
- Add re_direct/Models/Reflection/ReflectionPrompt.swift per the spec in
  docs/REFLECTION_ARCHITECTURE.md §4 (including the `context: String?` field).
- Register the new model in ReDirectSchema.allModels.
- Bump seed schema to v2: add top-level `reflection_prompts` array; update
  seed/curiosity_seed_v1.schema.json and seed/curiosity_seed_v1.example.json.
- Add ~10–14 bundled reflection prompts in en-US: roughly half
  `context: "reflect-method"`, half `context: "post-ritual"`, with 2–3
  untagged generals.
- Extend re_direct/Seed/SeedImporter.swift to import reflection prompts
  idempotently against the new top-level array.
- Add re_directTests/ReflectionPromptTests.swift with at minimum:
  - round-trip persistence
  - source enum honored ("seed" / "ai-runtime")
  - context tag honored ("reflect-method" / "post-ritual" / nil)
  - importer idempotency (second import does not duplicate rows)
  - 10+ rows present after first import on a fresh in-memory container

Do not:
- Touch any view file.
- Build a writing surface for ReflectionEntry.
- Modify CuriosityEngagement (no `reflection` relationship yet — that lands in REF2).
- Make any AI call.

Acceptance:
- Build green.
- All existing tests still pass.
- New tests pass.
- A fresh launch contains ≥ 10 ReflectionPrompt rows with source = "seed".
- Commit as: feat: add ReflectionPrompt model + seed v2 reflection prompts
```

REF2, REF3, REF4, REF5 prompts follow once each predecessor lands.

---

## 11. Post-ritual reflection contract (REF3)

This chapter is the load-bearing brief for the post-ritual writing surface. It expands on §2.2, §3.2, and §5.3, and it is what REF3's implementer should treat as canonical. Until this brief is fully accepted, **no code lands** — not even a DEBUG verification hook.

### 11.1 What REF3 is, in one sentence

After a non-reflect ritual finishes, the user is invited to write a short follow-up record about what they noticed; the record is saved as a `ReflectionEntry` linked to the session and attached to that session's existing `CuriosityEngagement` if one exists. **No new `CuriosityEngagement` is ever created by REF3.**

### 11.2 Trigger

There are three trigger sources, in order of intended preference:

1. **DeviceActivity threshold reached** (production, future). When Phase 7B lands and a real boundary completion fires on-device, that's the canonical trigger. The reflection sheet presents when the user returns to re:direct after the threshold callback.
2. **Local-fallback foreground reconciliation** (production, fallback). When the user re-foregrounds re:direct and a non-reflect `TimerSession` exists whose `plannedEndAt` is in the past *and* whose `reflectionPending` flag is unset, the sheet presents. This is the path that ships if DeviceActivity is denied or deferred.
3. **`stop early`** (production, immediate). When the user manually ends a non-reflect boundary via `stop early`, the sheet presents immediately on dismiss of the Timer surface. This is the only trigger that can fire without leaving re:direct.

**Current status**: none of these are wired. REF3 ships with **no production trigger and no DEBUG hook**. A DEBUG verification hook may be added later only after §11.7 (data relationship) is signed off and §11.6's save shape is proven by tests against an in-memory store. The REF2 lesson — that a DEBUG hook can creep toward production semantics — informs this caution.

### 11.3 Eligible methods

REF3 only runs for sessions whose **active method at completion** was one of:

| Slug | Display |
|---|---|
| `watch` | Watch |
| `read` | Read |
| `mini-game` | Mini Game |
| `deep-dive` | Deep Dive |

**`reflect` is excluded.** Reflect-method sessions already wrote a `ReflectionEntry` via REF2 when the ritual completed — adding a second writing surface afterward would create two reflections for one ritual, which contradicts §3.3.

The implementation reads the method from `ActiveMethodStore.activeRedirectMethodSlug` at trigger time, not from the `TimerSession` row (the row currently doesn't store the method). When the method is `reflect` or `nil`, the post-ritual sheet must not present.

### 11.4 UI design

Source of truth: the **REF2 Reflect Screen** standalone HTML (note: the filename is historical — it is the post-ritual reference, **not** the REF2 reference) and `re_direct/design_refs/Post_Log 1.png` / `Post_Log 2.png` / `Post_Log 3.png`.

**Adopted from the references**:
- Warm `PaperBackground(.warm)` + grain (same chassis as REF2).
- Top-leading 36pt paper-glass `✕` dismiss circle. No top-trailing element.
- **Greeting cascade**:
  - `welcome back,` — Instrument Serif Italic 22pt, ink 0.55–0.62.
  - `{firstName}.` — Instrument Serif **Regular** 38pt, full ink. Pulled from `UserProfile.displayName`; falls back to `friend.` (lowercase, italic) when no profile name is set.
  - `a quiet minute.` — system sans light 13pt, ink 0.62.
- Highlighted prompt under the greeting — same per-line `LineHighlightRenderer` REF2 introduced, same 24pt Instrument Serif Italic, same `.lineLimit(2)`, same flat-yellow swipe.
- Paper note: cream `#FFFDF2`, ink hairline, 1.5/1.5 hard shadow + 14/22 soft shadow. **Min height 220pt** (lower than REF2's 320 — post-ritual is a *noticing*, not a sit-down).
- Input: **SF Pro 15pt** (not Instrument Serif). Italic placeholder `start with what you remember.` at ink 0.32, ink caret.
- Footer line: `{n} / 280` counter at left, light 11pt. Counter goes amber past 240, red past 280. `local · not shared` mark at right.
- Save pill: yellow gradient capsule, Instrument Serif **Regular** 20pt (matching REF2's post-polish), underlined, 1.5/1.5 hard shadow. Disabled when trimmed body is empty.

**Explicitly dropped from `Post_Log*.png`** (those mockups include surfaces beyond reflection):
- ❌ Content thumbnail / polaroid card attached to the prompt — REF3 has no content slot.
- ❌ Recommender feedback chips ("Would you like more recommendations like this? Yes / Maybe / No / Done"). Recommender feedback is a *recommender* concern, not a reflection concern.
- ❌ "congratulations!" celebratory copy under the greeting — too loud for the editorial tone.
- ❌ "one last small step before you go..." kicker — patronizing; the greeting + prompt already imply intent.

If a recommender-feedback surface ever ships, it's its own slice, presented after REF3's reflection is saved (or alongside it as an opt-in). REF3 does not own that.

### 11.5 Prompt pool

Selection priority for the post-ritual sheet, mirroring REF2's pattern:

1. Random `ReflectionPrompt` where `context == "post-ritual"` and `deletedAt == nil`.
2. Random `ReflectionPrompt` where `context == nil` and `deletedAt == nil` (untagged generals).
3. Hardcoded fallback: `"what's one thing you noticed in the last few minutes?"`

Pure helper signature parallels `ReflectMethodRitualHelpers.choosePrompt(from:pickIndex:)`. Reuse the same `Selection` enum shape from REF2 so call sites stay symmetric.

The REF1 seed bundle ships 5 prompts tagged `context: "post-ritual"` plus 2 untagged generals — enough to start the pool. The fallback hardcoded string is a safety net only.

### 11.6 Save semantics

Strict contract, mirroring §3.2 with code-shape:

```swift
@MainActor
static func performPostRitualSave(
    body: String,
    prompt: Selection,
    session: TimerSession,                       // REQUIRED (no nil; REF3 only fires from a session)
    in context: ModelContext
) -> ReflectionEntry? {
    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }   // empty → write nothing

    let now = Date()
    let entry = ReflectionEntry()
    entry.body      = trimmed
    entry.createdAt = now
    entry.updatedAt = now
    entry.session   = session                    // ALWAYS link to session
    context.insert(entry)

    // Attach to the first reflection-less engagement from that session, if any.
    // Do NOT iterate-and-attach-all: see §11.7.
    let engagements = (try? context.fetch(FetchDescriptor<CuriosityEngagement>(
        predicate: #Predicate { $0.deletedAt == nil }
    )))?.filter { $0.session?.id == session.id && $0.reflection == nil } ?? []
    if let first = engagements.first {
        first.reflection = entry
    }

    // No new CuriosityEngagement is inserted. Period.
    try? context.save()
    return entry
}
```

Count invariants after a successful post-ritual save:
- `ReflectionEntry.count` → +1
- `CuriosityEngagement.count` → **unchanged**
- `TimerSession.count` → unchanged

Count invariants when the user dismisses with an empty body:
- All three → unchanged. No row inserted, no row updated.

The function returns the inserted `ReflectionEntry` so the calling sheet can dismiss the cover and trigger a single `.sensoryFeedback(.success)`.

### 11.7 Data relationship analysis

`CuriosityEngagement.reflection: ReflectionEntry?` is currently a **single optional** added in REF2. This is the only place REF3 needs to write on the engagement side.

**What this supports**:
- Reflect-method (REF2): one new engagement ↔ one new reflection. ✅ Trivially one-to-one.
- Post-ritual with **zero** engagements during the session: reflection saves with `session` link only; no engagement to attach to. ✅ Supported.
- Post-ritual with **one** engagement during the session: reflection attaches via `engagement.reflection = entry`. ✅ Supported.
- Post-ritual with **multiple** engagements during the session: only the **first reflection-less** engagement gets the link. The other engagements stay unreflected. The reflection still appears in Re:Log via its `session` link.

**What this does NOT support yet** (open questions for REF3 sign-off):

1. **One reflection covering several engagements.** If a session had three rabbit holes and the user writes one post-ritual reflection, only one of the three gets the link. The other two will show no reflection on their detail surfaces. This is **acceptable for REF3** because we don't have an engagement-detail UI yet (REF4 is read-only list), and the data is recoverable: a future query can find a reflection's siblings via `entry.session == engagement.session`. We do not need to change the model now.

2. **Several reflections covering one engagement.** Not possible today — the engagement holds one reflection ref. REF3 doesn't need it (a user gets one post-ritual prompt per session), but a future "write a follow-up later" feature would require either making `CuriosityEngagement.reflections` a to-many relationship or moving the link to `ReflectionEntry.engagement`. This is a **Phase 8+** concern, not REF3.

**Decision for REF3**: ship with the existing one-to-one optional. Document in the implementation comment that "first reflection-less attach" is the policy. No schema migration in REF3.

### 11.8 Edge cases

| Scenario | REF3 behavior |
|---|---|
| Session ended via DeviceActivity (future), user reopens app | Sheet presents on foreground. Existing engagements from that session are queried; reflection attaches to first reflection-less one if any. |
| Session ended via `stop early` while app foregrounded | Sheet presents immediately after Timer dismisses. Same attach logic. |
| Session ended via planned-end-past local fallback | Sheet presents on next foreground. Same attach logic. |
| User dismisses without writing (✕ tap or swipe-down) | No rows written. `reflectionPending` flag stays set; sheet re-presents on next foreground (and we count those re-presentations to back off after N tries — REF3 design pass detail). |
| User saves a one-character body | `trimmingCharacters(in:.whitespacesAndNewlines)` keeps single characters; save proceeds. We do not enforce a minimum length beyond "non-empty after trim." |
| Active method is `reflect` when the trigger would fire | **Sheet must not present.** Reflect-method already wrote its reflection during REF2. |
| Active method is `nil` (no method picked) at trigger time | Sheet must not present. Without a method we don't know which prompt context to draw from, and the session lacks the editorial framing the post-ritual sheet implies. |
| Multiple sessions end in rapid succession before the user returns | One sheet per session, queued. Or: only the most recent unreflected session gets a sheet, with older ones marked "skipped." REF3 design pass picks one of these and documents it. **Default recommendation**: one sheet per re-foreground, surface the most recent unreflected session, leave older ones for the user to manually log via re:tuals (future REF4) if at all. |
| The seed pool has zero `post-ritual` prompts and zero untagged prompts | Hardcoded fallback string is used. The user sees a working sheet either way. |

### 11.9 Temporary testing plan

**No production fake trigger ships in REF3-first.** Until §11.7's relationship policy is signed off and §11.6's save shape is verified by tests against an in-memory store, the post-ritual surface does not get a trigger from `TimerView`, from Settings, or from anywhere else.

**The testable contract**:
- `performPostRitualSave(...)` is a pure-as-possible helper that takes a `ModelContext` and writes deterministic rows. Tests live in a new `re_directTests/PostRitualReflectionTests.swift` and assert:
  - Empty trimmed body → no rows written; returns `nil`.
  - Non-empty body + session with zero engagements → 1 `ReflectionEntry` row; `CuriosityEngagement.count` unchanged.
  - Non-empty body + session with one engagement → 1 `ReflectionEntry`; the engagement's `reflection` field points to it.
  - Non-empty body + session with multiple engagements → 1 `ReflectionEntry`; only the first reflection-less engagement is linked.
  - Non-empty body + session with all engagements already reflected → 1 `ReflectionEntry`, session-linked but no engagement attachment.
  - Soft-deleted engagements are not eligible for attachment.
- `chooseReflectionPrompt(...)` (the post-ritual sibling of REF2's helper) tests mirror the REF2 selection-priority tests.

**Only after those tests pass**, a DEBUG verification hook may be added at a single trigger site (most likely the `stop early` button in `TimerView`, since it's the only path that doesn't require Phase 7B or foreground reconciliation logic). Like REF2's hook, it must be:
- Wrapped in `#if DEBUG` / `#endif`.
- Documented at the trigger site with a comment naming it as a verification hook.
- Listed in a follow-on `REF3.1` slice for removal once the real trigger lands.

The hook is **not** part of REF3's first ship. It's a separate slice gated on this brief's acceptance.

### 11.10 What REF3 must NOT do

- ❌ Create a new `CuriosityEngagement(methodSlug: "reflect")`. Ever.
- ❌ Present the sheet when the active method is `reflect`.
- ❌ Add a standalone create button anywhere (Re:Log, Dashboard, Settings, re:tuals).
- ❌ Add a Yes/No/Maybe recommender feedback row.
- ❌ Attach content thumbnails.
- ❌ Call any AI proxy. Reflection text never leaves the device — §6 applies verbatim.
- ❌ Change the `CuriosityEngagement.reflection` relationship shape.
- ❌ Add a new SwiftData model.
- ❌ Ship a production trigger.
- ❌ Ship a DEBUG trigger as part of the first REF3 PR (see §11.9).

### 11.11 Acceptance criteria (when REF3 ships)

- Build green; tests pass.
- New `PostRitualReflectionTests` suite covers §11.9's six scenarios.
- The post-ritual sheet view exists and matches §11.4's design language.
- `performPostRitualSave(...)` honors §11.6's contract.
- The Re:Log reflections section (REF2.5) shows new post-ritual entries without code change (the existing `@Query` already covers them).
- The Settings reflection count increments only on non-empty save.
- The Re:Log rabbit-hole count is **untouched** by REF3 saves.
- No data leaves the device.
- No production trigger is wired.

### 11.12 Next coding prompt template

```
Run Slice REF3: post-ritual reflection writing surface (no trigger yet).

Scope:
- Add re_direct/PostRitualReflectionView.swift per the spec in
  docs/REFLECTION_ARCHITECTURE.md §11.4–§11.6.
- Reuse LineHighlightRenderer from ReflectMethodRitualView.swift (lift
  to a shared file or duplicate locally — implementer's call).
- Add the pure helpers:
    - PostRitualReflectionHelpers.choosePrompt(from:pickIndex:)
    - PostRitualReflectionHelpers.performSave(body:prompt:session:in:)
  matching the shape in §11.6.
- Add re_directTests/PostRitualReflectionTests.swift covering the six
  scenarios in §11.9 plus a prompt-selection priority test that mirrors
  REF2's.

Do not:
- Wire any trigger (no Timer, Settings, or anywhere else).
- Add a DEBUG verification hook in this PR — that's REF3.1.
- Create a new CuriosityEngagement on save.
- Change the CuriosityEngagement.reflection relationship.
- Touch TimerView, ReLogView, RetualsView, SettingsView, DashboardView.
- Add any AI call.

Acceptance:
- Build green.
- All existing tests still pass.
- New PostRitualReflectionTests pass.
- The view is fully implemented but unreachable from any user-facing
  path. A future REF3.1 slice adds the trigger.
- Commit as: feat(reflection): add post-ritual writing surface
```

REF3.1 (trigger wiring) and REF3.2 (recommender feedback, if ever) follow as separate slices.

