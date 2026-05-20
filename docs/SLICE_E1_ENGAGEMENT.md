# Slice E1 — CuriosityEngagement Design Proposal

Documentation-only. No SwiftData model is created in this slice. No view is touched.

This document defines the `CuriosityEngagement` model, its candidate creation surfaces, and how re:tuals and Re:Log will eventually consume it. Acceptance of this proposal unlocks Slice E2 (model implementation) and Slice E3 (first creation surface).

---

## 1. What this model is for

A **rabbit hole** is a moment when the user actually engaged with curiosity content — read an article, watched a video, completed a prompt, walked through a trail step, or jotted a brief note about what they noticed. It is a content-engagement event, distinct from a `TimerSession` (boundary commitment) and a `ReflectionEntry` (post-session reflection text).

`CuriosityEngagement` is the canonical record of these moments. It is the single source of truth for:

- The Re:Log widget's rabbit hole count.
- The re:tuals deck's future per-lane history (tap-to-flip back face).
- Future Re:Log analytics: top topics, time-by-method aggregates, "you returned to X three times this month".
- A fallback for engagement tracking when Apple's Screen Time APIs are not available or are restrictive — `CuriosityEngagement` is user-declared and local-first; Screen Time is enrichment.

---

## 2. Model proposal

```swift
@Model
final class CuriosityEngagement {
    @Attribute(.unique) var id: UUID = UUID()

    // What method category does this engagement belong to?
    // Joins to RedirectMethod.slug — the single source of truth for the 5 lanes.
    // Allowed values: "watch", "read", "mini-game", "reflect", "deep-dive".
    var methodSlug: String = ""

    // What did the user engage with? Free-form so users can log content that
    // isn't tied to a seeded CuriosityTopic / CuriosityPrompt.
    var contentTitle: String = ""

    // Optional pointer to the source. Kept local; never transmitted.
    var sourceURL: String? = nil

    // When did the engagement happen? Defaults to now at creation.
    var engagedAt: Date = Date()

    // Optional self-reported duration. Many engagements won't have one;
    // making this nullable avoids inventing 0-minute defaults.
    var durationSeconds: Int? = nil

    // Optional one-line user note ("loved the part about whales"). Stays local.
    var note: String? = nil

    // Soft delete, consistent with the rest of the user-owned schema.
    var deletedAt: Date? = nil

    // Optional links into seeded content when applicable.
    var topic: CuriosityTopic? = nil
    var prompt: CuriosityPrompt? = nil

    // Optional link to the timer session the engagement occurred during.
    // Allows future analytics like "engagements per session".
    var session: TimerSession? = nil

    init() {}
}
```

### Field rationale

| Field | Why it's shaped this way |
|---|---|
| `methodSlug: String` (not enum) | Joins to seeded `RedirectMethod.slug` directly. Keeps a single source of truth and avoids parallel enum drift. Validators at the creation site assert the slug is in the canonical set. |
| `contentTitle: String` | Required free-form so users can log content not in the seed (e.g., an article they found themselves). When seeded content is the source, the creator can prefill with `topic.title` and let the user edit. |
| `sourceURL: String?` | Optional, plain string (not `URL`) so storing user-typed values that may be malformed doesn't crash decode. Local only. |
| `engagedAt: Date` | The event timestamp. Almost always `.now` at creation; settable so backfill ("I read this yesterday") is possible. |
| `durationSeconds: Int?` | Nullable on purpose — most engagements won't have measured duration. Defaulting to 0 would be a lie that pollutes analytics. |
| `note: String?` | Nullable, intentionally narrow ("one line of context"), to keep the field's purpose tight. Not a reflection — reflections live in `ReflectionEntry`. |
| `deletedAt: Date?` | Soft delete for parity with the rest of the user-owned schema. Engagement history is precious; we never hard-delete behind the user's back. |
| `topic: CuriosityTopic?` | Optional link to a seeded topic. When set, re:tuals can group engagements by topic in addition to method. |
| `prompt: CuriosityPrompt?` | Optional link to a seeded prompt (e.g., the user completed a specific Curiosity Prompt presented earlier). |
| `session: TimerSession?` | Optional link to the timer the engagement occurred during. Enables "this engagement happened inside Session #14" lookups. Not required — engagement can happen without a timer running. |

### Indexing & uniqueness

- `id` is `@Attribute(.unique)` for parity. Drops at CloudKit migration (Phase 8), same known carry-forward as the rest of the schema.
- No other unique constraints. Two engagements with the same `methodSlug` and `contentTitle` at different times are legitimately distinct events.

### What this model is NOT

- Not a `Ritual`. Rituals (in the corrected architecture) are method lanes — five categories — not per-engagement records.
- Not a `Reflection`. Reflections are post-session prose; engagements are content events.
- Not a `TimerSession`. A timer commit can happen without engagement; engagement can happen without a timer.

---

## 3. Candidate creation surfaces

Slice E3 will pick **one** surface to ship first. The others can land later. Each surface is described with the data path and a guardrail rule.

### Surface A — Dashboard topic card swipe action

**Where**: long-press or swipe on a `DailyCard` in the dashboard carousel.

**Flow**: The action opens a compact sheet (`InstrumentSerif-Italic` title "I just …", chip selector for method, optional duration field, optional note field, Save / Cancel). Save creates a `CuriosityEngagement` with `topic` prefilled from the seeded card and `contentTitle` defaulted to `topic.title`.

**Pros**: lives where curiosity content is discovered; encourages logging at the moment of interest; doesn't require building a new screen.

**Cons**: adds an action to an existing tactile card — needs design care to avoid disrupting the editorial feel. Sheet presentation is a notification-ish pattern, which the project has been cautious about.

### Surface B — Manual "+ log a rabbit hole" entry in Re:Log

**Where**: a small `+` affordance at the top of `ReLogView`, or a tappable empty-state CTA when the engagement list is empty.

**Flow**: opens the same compact sheet as Surface A, but without seeded topic prefill — the user types `contentTitle` directly and picks a method.

**Pros**: maximally honest empty-state path; logging is a deliberate, reflective act fitting Re:Log's voice; no risk of disrupting Dashboard layout.

**Cons**: friction — the user has to navigate to Re:Log to log something they just read elsewhere. Mitigated by also shipping Surface A later.

### Surface C — Post-timer prompt

**Where**: when a `TimerSession` completes (or is cancelled), a sheet appears: "did you fall down a rabbit hole?" with method chips + optional content title.

**Flow**: declines and confirms both close the sheet; confirm creates an engagement linked to the just-finished `TimerSession`.

**Pros**: turns the timer end into a reflective beat; pairs naturally with future `ReflectionEntry` capture.

**Cons**: requires the timer to actually tick and have a completion event — i.e. depends on Slice 8.1+ work that doesn't exist yet. Not viable as the *first* creation surface.

### Surface D — re:tuals back-face "+ add" button

**Where**: inside the future flipped state of a re:tuals card (Slice 6.4 redesigned).

**Flow**: tap a method lane's card to flip; back face shows recent engagements in that lane plus a "+ log one" affordance.

**Pros**: keeps re:tuals self-sufficient — the user can both see and add engagement within the lane.

**Cons**: depends on Slice 6.4 redesigned shipping first, which itself depends on `CuriosityEngagement` existing. Circular. Not first.

### Surface ordering recommendation

For Slice E3, pick **Surface B (Re:Log "+ log")** first. Reasons:

1. Smallest dependency graph — needs only the new model + a single sheet view + a `ModelContext` insert.
2. No risk to existing Dashboard tactile interactions.
3. Honest empty-state pairing: the Re:Log widget shows "no rabbit holes yet" and the same screen offers the path to log one.
4. Surface A can be added next as a convenience shortcut; it shares the sheet component.

This is a Slice E3 decision — not locked here. The Slice E3 prompt should re-evaluate after Slice E2 lands.

---

## 4. How re:tuals will consume `CuriosityEngagement`

Future (Slice 6.4 redesigned, after E2/E3):

```swift
@Query private var allEngagements: [CuriosityEngagement]
// Inside the per-lane flipped view:
private var laneEngagements: [CuriosityEngagement] {
    allEngagements
        .filter { $0.methodSlug == lane.slug && $0.deletedAt == nil }
        .sorted { $0.engagedAt > $1.engagedAt }
        .prefix(10)
        .map { $0 }
}
```

The flipped view renders this as a vertical list of `contentTitle` (Instrument Serif Italic, 16pt) + relative timestamp ("2 days ago", "just now") + optional `note` preview clipped to 60 characters. Empty state: "no rabbit holes yet in this lane — try setting a [Watch] timer to start one."

No additional model fields needed; the existing relationships are sufficient.

The current `RedirectRitual.samples` array stays for the card front face (editorial copy and visuals). Only the back face is new.

---

## 5. How Re:Log will consume `CuriosityEngagement`

Two surfaces:

### Re:Log widget on Dashboard

Replace the current hardcoded `0` with a live query:

```swift
@Query(filter: #Predicate<CuriosityEngagement> { $0.deletedAt == nil })
private var engagements: [CuriosityEngagement]

private var rabbitHoleCount: Int { engagements.count }
```

The existing 0 / 1 / N copy branches and `.contentTransition(.numericText())` animation work unchanged. The `FIXME(Slice E)` comment removes when this lands.

### Re:Log full screen

A new section "rabbit holes" appears alongside the existing Top 5 topics card and Screen Time recap. Possible visualizations:

1. **Latest 5 engagements**, each with title + method chip + relative timestamp. Tap to expand into a longer list.
2. **Method-distribution sparkline**: small horizontal bars showing engagement-counts-per-method-this-month. Decorative, not a chart.
3. **Streak indicator** (optional): "you've logged something 4 days this week" — calm framing, not gamified.

For Slice E3 we ship only the count change in the widget. The full Re:Log section is its own follow-up slice (Slice 9.2 or similar), gated on enough engagement rows existing to make the design decisions meaningful.

---

## 6. Tests

When `CuriosityEngagement` lands in Slice E2, the test suite gains a new file:

```
re_directTests/CuriosityEngagementTests.swift
```

Covering:

- **Round-trip persistence**: create, save, fetch, verify all fields persist.
- **`methodSlug` is honored**: filtering by slug returns only matching rows.
- **Soft-delete semantics**: setting `deletedAt` excludes rows from default queries.
- **Optional relationship integrity**: topic/prompt/session nullable links don't break encode/decode.
- **Canonical slug guardrail** (optional): a similar pattern to `bundledRedirectMethodSlugsMatchCanonicalSet` — if we want to be strict, a creation-time validator on `methodSlug` rejects values outside the canonical set. Open question: should the model enforce this, or should the creation surface (the sheet) be the only validator? Recommendation: enforce at the creation surface, not in the model — the model stays permissive so future content design (subcategories, custom user-defined lanes) doesn't require migrations.

---

## 7. Schema impact

Adding `CuriosityEngagement` to `ReDirectSchema.allModels` is the only schema change. No migrations are needed because no production stores have shipped yet (still pre-release / local-first per the schema-validity policy).

### CloudKit carry-forward

Same known debt as the rest of the schema: `@Attribute(.unique)` on `id` comes off at Phase 8 when CloudKit sync turns on. Application-layer uniqueness — already the pattern in `SeedImporter` — takes over.

---

## 8. Open questions for sign-off before Slice E2

1. **Should `methodSlug` be validated at the model layer or only at the creation surface?** Recommendation: creation surface only.
2. **Should `sourceURL` be `URL` or `String`?** Recommendation: `String` (lenient encoding of user-typed values).
3. **Should `contentTitle` be required (non-empty) at the model layer?** Recommendation: yes — empty rabbit holes have no semantic value. Default value `""` exists for SwiftData defaulting; the creation surface enforces non-empty before insert.
4. **Should the first creation surface be Surface B (Re:Log "+ log") or Surface A (Dashboard card swipe)?** Recommendation: Surface B for Slice E3; Surface A is a fast follow-on.
5. **Should we ship Slice E2 (model only) and Slice E3 (creation surface) as two commits, or bundle them?** Recommendation: two commits. Model and tests first; surface second. Easier to revert each independently.

---

## 9. What this slice did NOT do

- ❌ Added the `CuriosityEngagement` model to the SwiftData schema.
- ❌ Wrote any view, sheet, or `@Query`.
- ❌ Modified `RetualsView`, `ReLogView`, or the Dashboard.
- ❌ Removed the re:tuals "choose this" button.
- ❌ Changed any model file's class declaration.
- ❌ Added or modified tests.

All of the above are explicit future slice work, gated on acceptance of this proposal.

---

## 10. Next slice (suggested prompt)

```
Run Slice E2: implement CuriosityEngagement.

Scope:
- Add re_direct/Models/Engagement/CuriosityEngagement.swift per the spec
  in docs/SLICE_E1_ENGAGEMENT.md §2.
- Register the model in ReDirectSchema.allModels.
- Add re_directTests/CuriosityEngagementTests.swift with at minimum:
  - round-trip persistence
  - methodSlug filtering
  - soft-delete excludes from default queries

Do not:
- Touch any view file.
- Wire the Re:Log widget to the new model yet.
- Build a creation surface.
- Remove the FIXME comment in DashboardView yet.

Acceptance:
- Build green.
- Tests still all pass.
- New tests pass.
- No view, no UI change.
- Commit as: feat: add CuriosityEngagement model
```

After E2 lands, Slice E3 (first creation surface — recommended Surface B) follows.
