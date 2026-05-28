# AI Rabbit Hole Trails — Phase 6E plan

Documentation-only. No Swift, no proxy code, no UI edits in this commit. This is the **6E-A** deliverable: it resolves the open decisions in `docs/AI_INTEGRATION_PLAN.md §6 Phase 6E` and `docs/RABBIT_HOLE_THREADS.md §6`, picks a single trigger surface for v1, locks the proxy endpoint contract, and sequences the coding slices.

Inputs that shaped this plan:
- `docs/AI_INTEGRATION_PLAN.md` — Phase 6 strategic brief, §6 Phase 6E sketch, §7.3/7.4 payload concepts, §12.7 personalization tie-in
- `docs/RABBIT_HOLE_THREADS.md` — §6 trail→thread persistence contract, §13 anti-scope-creep rules
- `docs/AI_PROXY_IMPLEMENTATION_PLAN.md` — proxy patterns, validation, cost-control allowlists
- Shipped state: tab 1 = `RabbitHoleView`; canonical RH2 (manual thread creation + overview + attach) is done; Daily Direct AI is live through Cloudflare Worker + DeepSeek `deepseek-v4-flash`
- `re_direct_ai_proxy/` Cloudflare Worker README — confirmed `/v1/recommendation` patterns to mirror

---

## 1. Purpose

Phase 6E turns one logged rabbit hole into a bounded, editorial **trail** of next steps that the user can review, accept, and walk through. On acceptance, the trail materializes as one `RabbitHoleThread` (`sourceKind = .aiDeepened`) with N `CuriosityEngagement` rows, per the locked contract in `docs/RABBIT_HOLE_THREADS.md §6`.

This is **not** a chat surface, not an auto-suggest, not a Daily-Direct-on-demand button. It is one explicit gesture, one bounded response, one accept-or-discard moment.

---

## 2. Product framing — what is an AI-deepened trail?

A trail is **a proposed sequence of 3–5 next steps** for a curiosity the user already cared enough to log. Each step is one of:

| Step type | Example | Maps to `methodSlug` |
|---|---|---|
| `article` | "Why deep-sea creatures glow blue" | `read` |
| `video` | "Living light: a 6-minute tour" | `watch` |
| `question` | "What would your day look like if you could only see in the dark?" | `reflect` |
| `reflection` | "Write about something you've been ignoring because it doesn't glow." | `reflect` |
| `topic` | "Cartography of the invisible" (adjacent rabbit hole) | `deep-dive` |

Step types that don't map cleanly to one of the five canonical method slugs are **dropped, not coerced** (per `RABBIT_HOLE_THREADS.md §6` step 4).

A trail is **not**:
- A chat thread or back-and-forth
- A re-generation surface (no "regenerate")
- A search result
- An auto-curated daily list (that's Daily Direct, Phase 6D)
- A sub-trail factory (each step is a leaf; deepening one step is a fresh root, separate gesture)

---

## 3. Trigger — where does a trail start in v1?

### Decision: **single trigger, from a loose engagement, in v1.**

A loose `CuriosityEngagement` (one with `thread == nil`) is the cleanest root: the user already declared a curiosity, hasn't organized it yet, and the "this could grow into something" mental model is already present (the existing inert `thread?` pill primes it).

**Implementation surface**: the existing `LooseEndRow` gets a **second affordance**, sibling to `thread?`:
- `thread?` (existing, yellow) — attach to existing thread (RH3-E)
- `✨ deepen` (new, paper-cream with a small sparkle glyph) — open the AI trail sheet

Tapping `deepen` presents `TrailSheet` with that engagement as the root.

### Why not other triggers in v1

| Considered trigger | Why deferred |
|---|---|
| From the Daily Direct card | Daily Direct already has its own one-card-per-launch lifecycle. Adding a "deepen this suggestion" would multiply AI calls per launch and confuse Daily Direct's "one good next step" mental model. Defer to 6E-F. |
| From an existing `RabbitHoleThread` ("extend with AI") | Threads already have an explicit user-driven extension path (log a new engagement, attach it). Adding AI extension on a curated user thread risks turning it into a feed. Defer to 6E-F. |
| From the empty-state CTA ("AI-suggest my first thread") | Empty state must always work without network — adding an AI branch there creates two empty states (with and without proxy). Defer. |

### Why this is honest about scope

One trigger keeps the slice testable. If trail quality is too vague or the acceptance UX feels like work (the §6 Phase 6E stop conditions in AI_INTEGRATION_PLAN.md), we have one place to evaluate. Adding triggers before we know the answer would smear the signal.

---

## 4. AI response shape — what comes back

Locked at the proxy contract level (full spec in §9):

- **`title`** — AI-supplied trail title, ≤ 80 chars, sanitized. Falls back to root engagement title if the AI returns nothing usable.
- **`summary`** — optional, ≤ 200 chars, one-line "what this trail is about." Used to seed `RabbitHoleThread.summary` on acceptance.
- **`steps[]`** — exactly 3–5 entries, in suggested walk order. Each step has:
  - `type` — one of `article | video | question | reflection | topic`
  - `title` — ≤ 80 chars
  - `rationale` — ≤ 200 chars, one-line "why this is next"
  - `url` — required for `article` and `video`, null otherwise
  - `estimated_minutes` — integer or null

The proxy normalizes count to 3–5, drops invalid steps, trims long strings to caps. **iOS does not re-validate** these caps — it trusts the proxy contract and renders what comes back.

`prompt_input_hash`, `cached`, `provider`, `model_version`, `created_at` follow the existing `AIRecommendationResponse` envelope for cache fingerprinting + provenance.

---

## 5. Privacy boundary

### What may leave the device for a trail request

- `locale` (BCP-47 short form)
- `root_title` — engagement `contentTitle`, capped at 80 chars (same as recent-engagements cap in §4.1 of AI_INTEGRATION_PLAN.md)
- `root_method_slug` — one of the 5 canonical slugs
- `root_recency_bucket` — `today` / `this_week` / `older`
- `interest_seeds` — user-declared keywords, ≤ 12 entries, ≤ 40 chars each (same shape as Daily Direct)
- `seeded_topic_slugs` — optional, ≤ 5 bundled-content slugs the proxy may reference
- `max_steps` — integer 3–5, advisory cap

### What must never leave the device for a trail request

Re-asserting `docs/AI_INTEGRATION_PLAN.md §4.2`, plus 6E-specific guards:

- ❌ `ReflectionEntry.body` — even when the root engagement has a linked reflection
- ❌ `CuriosityEngagement.note` — user-typed but private; not sent
- ❌ Engagement history beyond the **single root** (no recent-engagements list for trails; that's Daily Direct's thing)
- ❌ Thread metadata (titles, summaries, lists) — the trail asks about *this root*, not about the user's other threads
- ❌ Apple identity, DeviceActivity tokens, precise timestamps, screenshots
- ❌ The originating engagement's `id`, `engagedAt` timestamp, or any local SwiftData identifier

The denylist on the proxy (currently 14 forbidden fields) gains three new entries: `reflection_body`, `engagement_note`, `engagement_history`.

### Type-level enforcement on iOS

Following the RH3-C `EngagementPreviewRowModel` precedent: extract a `TrailRequestPayload` value type that contains **only** the allowlisted fields. The HTTP client takes this payload, not the engagement object. Any code that wants to send a trail request must explicitly construct the payload — there is no path that hands the raw engagement to the proxy.

---

## 6. Acceptance and persistence — the 6E ↔ thread bridge

The bridge is already locked in `docs/RABBIT_HOLE_THREADS.md §6` and reproduced here for ergonomics. Phase 6E implements it; it does not re-litigate it.

### Transient until accept

The proxy response lives in `@State` on `TrailSheet`. The user sees the proposed trail, reads each step's title and rationale. **Nothing is written to SwiftData until the user explicitly taps `accept`.** Dismissing the sheet (cancel, drag-to-dismiss, swipe-down) discards.

### On accept

The accept handler materializes:

1. **One** `RabbitHoleThread`:
   - `sourceKind = .aiDeepened`
   - `status = .open`
   - `title` = `response.title` (sanitized; fallback to root engagement's `contentTitle`)
   - `summary` = `response.summary` (optional)
   - `seedTopic` / `seedPrompt` = root engagement's `topic` / `prompt` if any
   - `createdAt`, `updatedAt`, `lastEngagedAt` all = `now`

2. **N `CuriosityEngagement` rows** in trail order — one per accepted step:
   - `contentTitle` = `step.title`
   - `methodSlug` per the type mapping in §2 (steps that don't map cleanly are skipped)
   - `sourceURL` = `step.url` (when present)
   - `note` = `step.rationale` (the rationale is editorial, user-visible context — safe to persist as the engagement's note; it's not reflection text)
   - `engagedAt` = `now` (these are *proposed* steps, but persisting with `now` keeps sort honest; future engagement-walking surfaces can overwrite)
   - `thread` = the materialized thread (the inverse relationship populates `thread.engagements`)
   - `topic` / `prompt` = nil (these are AI-generated, not seeded-content links)

3. **Root engagement handling** — per `RABBIT_HOLE_THREADS.md §6` step 5, the root engagement is either:
   - **Linked as the first engagement** of the new thread if it isn't already part of another thread, OR
   - **Linked via `seedTopic` / `seedPrompt`** if it carries those; the trail starts at step 1 fresh.

   **Decision for 6E**: when the root engagement is currently unthreaded (`engagement.thread == nil`), set `engagement.thread = newThread` and the trail's N steps become engagements 2…N+1 in the thread. When the root engagement is already in a different thread, the new trail starts at step 1, and the new thread carries `seedTopic`/`seedPrompt` if the root engagement had them. We need to pick exactly one outcome here, and the loose-end-trigger constraint guarantees the engagement is unthreaded at trigger time — so in v1 the second branch only matters in edge races (engagement attached after the trigger, before accept), which we resolve by re-checking at accept time.

### On reject / cancel / dismiss

Nothing is written. The proxy response is discarded. If the user wants to re-try, they tap `deepen` again — which may hit the cache (see §7) or fire a fresh proxy call.

---

## 7. Fallback ladder

The canonical four-step ladder from `AI_INTEGRATION_PLAN.md §5`, instantiated for trails:

1. **Fresh cache hit** — proxy-derived `TrailResponse`, ≤ 1h old, fingerprint matches `(root_title_normalized, root_method_slug, sorted interest_seeds, locale)`.
2. **Live proxy call** — one attempt, ≤ 8s timeout (slightly longer than recommendation since trails are larger).
3. **Seeded `TopicTrail` fallback** — if `CuriosityTopic.prompts` / `TopicTrail` has a matching trail for the root's topic slug, render it as the response with `provider = "seeded"`.
4. **Quiet empty state** — sheet shows `no deeper path yet · come back to this later.` No error chrome, no spinner, no "AI unavailable."

The sheet renders the cache hit (or seed fallback) immediately on appear; if the proxy completes within the timeout, it *replaces* the rendered trail with the fresher response (same UX pattern as Dashboard Daily Direct).

### Cache TTL choice

- Trails: **1 hour**.
- Reasoning: Daily Direct's 24h TTL makes sense because the user's "today" intent is stable. A trail is anchored to a specific root engagement *and* current attention; re-tapping `deepen` an hour later, the user may want a refreshed take. One hour balances cost (most users won't re-tap within an hour) and freshness (within an hour, the cached take is still relevant).

---

## 8. Cost controls

| Layer | Control | Value |
|---|---|---|
| **Proxy provider allowlist** | DeepSeek model allowlist | Only `deepseek-v4-flash` (no change) |
| **Proxy provider allowlist** | OpenRouter model allowlist | Only `meta-llama/llama-3.3-70b-instruct` (no change) |
| **Proxy strict parse** | iOS request cannot specify model | `model`, `model_name`, `MODEL_NAME` rejected as `invalid_input` (no change) |
| **Proxy response cap** | Max response tokens | 1500 (trails are larger than recommendations; cap to prevent runaway cost) |
| **Proxy request validation** | `max_steps` clamped to 3–5 | Anything outside → normalized to bounds, not rejected |
| **iOS one-attempt rule** | Tapping `deepen` triggers at most one proxy call | One attempt per user gesture; no retry loop |
| **iOS cache** | TTL 1h per fingerprint | Re-tap within the hour → cache hit |
| **iOS launch ceiling** | Hard cap on trail proxy calls per app launch | 3 per cold launch (configurable in `AIEnvironment`) |
| **iOS off-switch** | `AIProviderPreference.disabled` | When set, `deepen` button falls straight to seeded fallback; no proxy call |
| **No background trails** | Trails are user-gesture-only | No `.task`, no automatic generation, no pre-fetch |

The hard launch ceiling and the user-gesture-only rule are the primary cost firewalls. Average personal use should be 0–2 trail calls per day; the ceiling prevents an unintended loop or a UX bug from accumulating charges.

---

## 9. Proxy endpoint contract

### Endpoint

```
POST /v1/trail
Content-Type: application/json
```

### Request — `TrailRequest` (canonical JSON, snake_case wire)

```jsonc
{
  "locale": "en-US",
  "root_title": "bioluminescence",
  "root_method_slug": "read",
  "root_recency_bucket": "today",
  "interest_seeds": ["Apple", "Machine Learning", "AI", "Neuroscience", "Software Engineering"],
  "seeded_topic_slugs": ["bioluminescence", "cartography"],
  "max_steps": 5,
  "provider_preference": "auto"
}
```

**Validation (Zod-strict, like `/v1/recommendation`):**

| Field | Type | Constraints |
|---|---|---|
| `locale` | string | BCP-47 short form (e.g. `en-US`); regex `/^[a-z]{2}(-[A-Z]{2})?$/` |
| `root_title` | string | non-empty, ≤ 80 chars after trim |
| `root_method_slug` | string | one of `read | watch | mini-game | reflect | deep-dive` |
| `root_recency_bucket` | string | one of `today | this_week | older` |
| `interest_seeds` | string[] | length 0–12; each entry non-empty, ≤ 40 chars after trim |
| `seeded_topic_slugs` | string[]? | optional; length 0–5; each entry ≤ 60 chars |
| `max_steps` | integer? | optional; clamped to 3–5 server-side |
| `provider_preference` | string | one of `auto | deepseek | openrouter` (matches existing) |

**Strict-parse rejects unknown fields**, mirroring `/v1/recommendation`. New denylist entries added to `src/validation/denylist.ts`:

```
reflection_body, reflectionBody,
engagement_note, engagementNote,
engagement_history, engagementHistory,
root_engagement_id, rootEngagementId,
root_engaged_at, rootEngagedAt
```

### Response — `TrailResponse` (canonical JSON)

```jsonc
{
  "id": "01J...",
  "title": "What the deep sea remembers",
  "summary": "A short trail from bioluminescence into the chemistry, the visuals, and a quiet question about your own invisible signals.",
  "root_title": "bioluminescence",
  "steps": [
    {
      "type": "article",
      "title": "Why deep-sea creatures glow blue",
      "rationale": "Direct extension of your root; explains the chemistry.",
      "url": "https://example.com/glow",
      "estimated_minutes": 8
    },
    {
      "type": "video",
      "title": "Living light: a 6-minute tour",
      "rationale": "Visualizes what the article describes.",
      "url": "https://example.com/light",
      "estimated_minutes": 6
    },
    {
      "type": "question",
      "title": "What would your day look like if you could only see in the dark?",
      "rationale": "Carries the metaphor into your life.",
      "url": null,
      "estimated_minutes": 3
    }
  ],
  "provider": "deepseek",
  "model_version": "deepseek-v4-flash",
  "prompt_input_hash": "f3a1abc",
  "cached": false,
  "created_at": "2026-05-27T08:00:00Z"
}
```

**Response validation (proxy-side, before returning):**

- `steps.length` clamped to 3–5; if AI returns fewer than 3 valid steps after filtering, the proxy returns `upstream_failed` and iOS falls back to seeded.
- Each step's `type` must be in the canonical 5 (`article | video | question | reflection | topic`); invalid types drop the step.
- `url` required for `article` and `video`; missing or non-HTTPS URL drops the step.
- `title` and `rationale` trimmed and clamped to their caps.
- `estimated_minutes` clamped to 1–60 or set to null.

### Errors

Same shape as `/v1/recommendation`'s `AIProxyError` cases — `invalid_input`, `rate_limited`, `proxy_unavailable`, `upstream_failed`, `upstream_timeout`, `network`.

---

## 10. Slice sequence

**Status as of this revision:** the end-to-end Phase 6E loop is shipped through **6E-D2**. 6E-D was split into two sub-slices during implementation (D1 = pure materializer + schema additions; D2 = the UI and request builder) to keep each PR small and individually verifiable. The status column below reflects that split.

| Slice | Goal | Touches | Status |
|---|---|---|---|
| **6E-A** | **This document.** Locks trigger, payload, persistence bridge, fallback, cost controls, slice sequence. | `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md` (new); optional ROADMAP refresh | **done** |
| **6E-B** | Proxy `/v1/trail` endpoint: handler, Zod validation, denylist extension, provider adapter for trail prompts, response normalization, tests. **Proxy repo only, no iOS code.** | `re_direct_ai_proxy/src/handlers/trail.ts`, `src/validation/*`, `src/providers/*`, tests | **done** (deployed) |
| **6E-C** | iOS DTOs + HTTP client: `AITrailRequest` (final class for ARM64e safety), `AITrailResponse` + `AITrailStep` Codables, `AIProxyHTTPClient.callTrail(_:)` method, JSON-serialization path mirroring the Daily Direct hardening. 19 tests for encode/decode, allowlist key set, forbidden fields absent. **No UI.** | `re_direct/AITrailRequest.swift`, `re_direct/AITrailResponse.swift`, `re_direct/AIEnvironment.swift` (extend), `re_direct/AIProxyHTTPClient.swift` (extend), tests | **done** |
| **6E-D1** | Pure materializer: `AITrailMaterializer` turns an accepted `AITrailResponse` + root `CuriosityEngagement` into one `.aiDeepened` `RabbitHoleThread` + N step `CuriosityEngagement` rows in a single transaction. Branch A (root unthreaded → attached) vs Branch B (root already threaded → new thread carries `seedTopic`/`seedPrompt` from the root). Schema additive: `RabbitHoleThread.seedTopic` + `seedPrompt`, both nullable, default nil. 30 tests. No UI. | `re_direct/AITrailMaterializer.swift` (new), `re_direct/Models/Engagement/RabbitHoleThread.swift` (extend) | **done** |
| **6E-D2** | UI: `deepen` affordance on `LooseEndRow` (sibling to existing `thread?` pill). `TrailPreviewSheet` state machine `.loading / .success / .failure`. `AITrailRequestBuilder` pure helper builds the request from only allowlisted fields. Single-hop MainActor→URLSession→MainActor pattern. Accept invokes the 6E-D1 materializer. 18 tests. | `re_direct/AITrailRequestBuilder.swift` (new), `re_direct/RabbitHoleView.swift` (extend), tests | **done** |
| **6E-E** | Seeded `TopicTrail` fallback: when proxy unavailable, render a matching seeded trail for the root's topic if one exists; otherwise the existing quiet "couldn't fetch a trail just now." copy + `try again`. May require a seed-content audit. | `re_direct/RabbitHoleView.swift` (extend), seed schema check | proposed, depends on 6E-D2 |

**6E-F (deferred)** — additional triggers (from Daily Direct card; from existing thread "extend with AI"). Revisit after Phase 6E quality is validated in real use.

---

## 11. Out of scope (load-bearing)

This list mirrors the §13 anti-scope-creep rules in `RABBIT_HOLE_THREADS.md` for the AI surface specifically.

- ❌ **No auto-generation** of trails on app launch, on view appearance, or on any non-user gesture. Every trail comes from one explicit `deepen` tap.
- ❌ **No persistence of rejected trails.** The proposed trail lives in view state only until accept.
- ❌ **No multi-trail comparison UI.** The user sees one trail at a time; if they cancel, the next `deepen` may re-request.
- ❌ **No re-generation button** ("give me a different trail"). Per the editorial principle in AI_INTEGRATION_PLAN.md §2.3.
- ❌ **No regeneration of individual steps.** A step is what it is.
- ❌ **No sub-trail factory.** Tapping a step inside an accepted trail does not start a new trail. If the user wants to deepen from that step, they engage with it as a new root (separate gesture, separate slice).
- ❌ **No outbound reflection body.** Even if the root engagement has a linked reflection, its body never enters the request payload. Tests assert this at multiple layers.
- ❌ **No outbound engagement history.** Trails carry the single root engagement only — recent-engagements lists are a Daily Direct concept.
- ❌ **No URL-rendering polish.** v1 displays the URL as a quiet caption; tapping the URL uses the system browser. No in-app web view, no preview cards.
- ❌ **No "AI generated" badge** on the trail sheet. Provenance lives in the existing Settings AI status row.
- ❌ **No schema additions in 6E-D.** The 6E ↔ thread bridge uses the existing `RabbitHoleThread` + `CuriosityEngagement` shapes. The proposed `source: "seed" | "ai-runtime"` field on `TopicTrail` (AI_INTEGRATION_PLAN.md §6 future-model note) is **not** implemented in 6E v1.
- ❌ **No DeviceActivity / Timer wiring.** Phase 7B remains parked.
- ❌ **No Settings changes** unless 6E-C requires exposing a new AI status row variant; documented if so.

---

## 12. Open questions to resolve before each slice opens

Marked with the slice that needs the answer.

### Before 6E-B (proxy)

1. **Provider for trails — DeepSeek `deepseek-v4-flash` (current default) or switch to OpenRouter `meta-llama/llama-3.3-70b-instruct` for the trail use case?** Trails are more "editorial creative" than recommendations; OpenRouter's Llama may write better step rationales. Recommendation: ship with DeepSeek first (no provider variance from Daily Direct), evaluate quality, switch via `provider_preference` if needed. The proxy already supports both.
2. **Per-installation rate limiting on the proxy** — Cloudflare `rate-limiting` API or a simple in-memory counter on hashed install ID? Recommendation: out of scope for 6E-B; the iOS launch-ceiling is sufficient initial firewall. Revisit if cost telemetry shows abuse.

### Before 6E-C (iOS client)

3. **Should `TrailRequestPayload` be a `final class` (matching `AIRecommendationRequest`'s ARM64e workaround) or can it be a `struct`?** The ARM64e issue with struct copies across async boundaries was struct-specific. Recommendation: `final class` for consistency and safety. Cost is negligible.
4. **TTL precision** — 1h cache TTL noted in §7; should it be configurable per request (proxy `cacheTTL` field) or hardcoded iOS-side? Recommendation: hardcode iOS-side for 6E-C; revisit if Daily Direct's `cacheTTL` mechanism gains traction.

### Before 6E-D (UI)

5. **`deepen` affordance placement on `LooseEndRow`** — sibling to `thread?` (two pills) or a single combined `…` menu that opens an action sheet (attach / deepen / cancel)? Recommendation: two visible pills. The affordances are different enough that a menu hides them. Trade-off: row gets visually busier — needs design check at 6E-D start.
6. **Acceptance gesture** — single tap `accept`, or swipe-up commitment? Recommendation: single tap. Matches RH3-E's tap-to-confirm pattern.
7. **What happens if proxy returns 4 steps but only 2 map to canonical method slugs?** Per §6, dropped steps are skipped — so the materialized thread would have 2 engagements. Should the sheet show all 4 steps (with the unmappable ones disabled), or pre-filter to 2 before showing? Recommendation: pre-filter at iOS, show only what will materialize. Less confusing.

### Before 6E-E (seeded fallback)

8. **Does the existing `seed/curiosity_seed_v1.json` have `TopicTrail` entries with enough coverage to be useful as a real fallback?** Audit needed at 6E-E start. If coverage is too thin, 6E-E becomes a seed-content slice rather than a code slice.

---

## 13. Acceptance for this brief (6E-A)

This document is accepted when:

1. The trigger choice (single, from loose engagement, v1) is non-controversial.
2. The proxy endpoint contract in §9 is the conversation-starting shape for 6E-B.
3. The persistence bridge in §6 honors `RABBIT_HOLE_THREADS.md §6` without amendment.
4. The privacy boundary in §5 is non-negotiable and tests will enforce it at multiple layers.
5. The slice sequence in §10 is unambiguous to whoever picks up 6E-B.

Once accepted, **6E-B begins** — and 6E-B is the first slice that touches the proxy repo.

---

## 14. Next coding prompt — copy/paste for 6E-B

This prompt is self-contained for a fresh chat working in the **proxy repo** (`/Users/mac/Desktop/re_direct_ai_proxy`):

> Implement Phase 6E-B: AI trail proxy endpoint.
>
> Repo: `/Users/mac/Desktop/re_direct_ai_proxy`
>
> Read first:
> - `README.md` (proxy overview)
> - `src/handlers/recommendation.ts` (existing endpoint to mirror)
> - `src/validation/request.ts`, `src/validation/denylist.ts`, `src/validation/types.ts`
> - `src/providers/deepseek.ts`, `src/providers/openrouter.ts`
> - iOS repo: `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md` §4, §5, §6, §8, §9 (the full contract)
>
> Goal: add `POST /v1/trail` that mirrors `/v1/recommendation` patterns but speaks the `TrailRequest` / `TrailResponse` shape from §9 of the iOS-repo plan.
>
> Scope:
> 1. New handler `src/handlers/trail.ts` registered on `POST /v1/trail`.
> 2. New Zod schemas in `src/validation/trail.ts` for `TrailRequest` and `TrailResponse`. Strict-parse rejects unknown fields. Validation rules in iOS-repo §9.
> 3. Extend `src/validation/denylist.ts` to also reject `reflection_body`, `reflectionBody`, `engagement_note`, `engagementNote`, `engagement_history`, `engagementHistory`, `root_engagement_id`, `rootEngagementId`, `root_engaged_at`, `rootEngagedAt`.
> 4. Provider adapter functions `buildTrailPrompt(request)` and `parseTrailResponse(text)` per provider (DeepSeek first; OpenRouter scaffolded but not required to ship). Same provider allowlist as the recommendation endpoint — only `deepseek-v4-flash` for DeepSeek, only `meta-llama/llama-3.3-70b-instruct` for OpenRouter.
> 5. iOS request payload cannot specify `model` / `model_name` / `MODEL_NAME` — reject at strict parse.
> 6. Response post-processing per iOS-repo §9 "Response validation": clamp `steps.length` to 3–5 (return `upstream_failed` if <3 valid steps after filtering), validate step types, drop steps missing required URLs, trim long strings, clamp `estimated_minutes` to 1–60 or null.
> 7. Tests in `test/handlers/trail.test.ts` covering: happy path, allowlist key set, forbidden fields rejected, invalid `root_method_slug` rejected, `max_steps` clamping, response normalization (dropping invalid steps), `upstream_failed` when too few valid steps, denylist hits, model-spec rejection.
> 8. No persistence on the proxy. Stateless.
> 9. Same timeout / error-shape conventions as `/v1/recommendation`. Cap response tokens at 1500.
>
> Out of scope:
> - No iOS changes.
> - No per-installation rate limiting (deferred per iOS-repo §12.2).
> - No new provider beyond the existing DeepSeek + OpenRouter allowlists.
> - No `TopicTrail` seed-fallback logic (that's iOS 6E-E).
>
> Acceptance:
> - All existing proxy tests still pass.
> - New trail tests pass.
> - `wrangler deploy` (or whatever the current deploy command is) ships clean.
> - No secrets logged. No request payload bodies logged beyond status+timing.
>
> Commit message: `feat(trail): POST /v1/trail endpoint with strict validation`
>
> Stop and report before push.
