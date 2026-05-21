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

### REF3 — Post-ritual reflection flow

**Scope**
- Detect non-reflect `TimerSession` completion (planned end past + foreground reconciliation, or `stop early`, or — future — DeviceActivity threshold).
- Present the post-ritual writing sheet (§5.3) using a `ReflectionPrompt` with `context = "post-ritual"` (or untagged).
- On save: per §3.2 — new `ReflectionEntry` linked to the just-finished `TimerSession`, attached to the first reflection-less `CuriosityEngagement` from that session if any. **No new `CuriosityEngagement` insertion.**
- A small persistent "open ritual" indicator on Re:Log when a non-reflect session has completed and the reflection is unwritten.
- Tests: post-ritual save does not increment `CuriosityEngagement.count`; `ReflectionEntry.count` increments by 1; existing engagement's `reflection` field gets the new entry; multi-engagement session attaches to first reflection-less engagement only.

**Out of scope**
- No Reflect-method changes.
- No AI.
- No Re:Log read view yet.

**Acceptance**
- A non-reflect session completes; the post-ritual sheet appears.
- Writing and saving creates one `ReflectionEntry`; `CuriosityEngagement.count` does not change.
- Dismissing without writing leaves the session in a "reflection-pending" state; the sheet re-presents on next foreground.

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
