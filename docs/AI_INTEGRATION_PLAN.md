# AI Integration Plan — Phase 6

Documentation-only. No Swift code, no proxy code, no API keys, no UI edits. This document is the strategic brief for Phase 6: the AI lane that becomes re:direct's primary forward path while DeviceActivity / FamilyControls remains parked on a Personal Team without Family Controls entitlement access (see `docs/DEVICE_ACTIVITY_FEASIBILITY.md`).

Phase 6 is divided into five gated sub-slices (6A–6E) plus an optional follow-on (6F). This is the **6A** deliverable.

---

## 1. Why this brief exists

re:direct was originally going to lean on Apple Screen Time / DeviceActivity / FamilyControls to make the "boundary → redirect → reflect" loop feel real. With Family Controls unavailable on the current developer team, that path is **parked, not abandoned** — the feasibility brief stands as the resumption plan. In the meantime, the product still has to feel like more than a static prototype.

**AI is the lever that makes the local-first fallback feel intentional.** The app cannot yet automatically observe app usage. It cannot shield apps. It cannot fire a system reminder when the user crosses a threshold. But it *can*:

- Notice what the user logged manually as a rabbit hole.
- Suggest a curated next step for *today* on the Dashboard.
- Turn an isolated logged rabbit hole into a bounded trail of deeper, intentional next steps.
- Generate gentle, mood-aware reflection prompts (later, opt-in).

AI does **not** replace DeviceActivity. It does not pretend to track app usage. It does not claim automatic boundary completion. It augments the surfaces the user manually engages with and makes the local-first MVP feel like a thinking partner — without ever sending the user's reflection text off-device.

---

## 2. Product framing — what AI is, and isn't

### 2.1 What AI is in re:direct

- A **curation engine** for one good next step on the Dashboard (Daily Direct).
- A **trail extender** that turns one logged rabbit hole into 3–5 intentional next steps (rabbit-hole deepening).
- A **gentle prompt generator** for reflection writing (later, opt-in only).

### 2.2 What AI is NOT in re:direct

- ❌ A chat surface. No chatbot UI. No conversational chrome.
- ❌ A substitute for DeviceActivity. AI doesn't see app usage. It doesn't know when the user opens Instagram.
- ❌ A reader of the user's reflection text. Reflection `body` never enters a request payload.
- ❌ An always-on background service. All AI calls are explicit, user-initiated, and bounded.
- ❌ A vendor lock-in. The proxy uses a provider-agnostic contract that's already defined in `re_direct/AIRecommendationRequest.swift` and `AIRecommendationResponse.swift`. Swapping providers should be a config change, not a refactor.

### 2.3 Editorial constraint

re:direct's voice is editorial — warm paper, gentle italics, small honest copy. AI output that reads as "generated content" breaks the aesthetic. The Dashboard's Daily Direct card already has a visual language; AI fills the fields, **the chrome stays the same**. No "AI generated" badges on the card itself. Provenance lives in Settings (a row that reads "AI: configured · last success 2h ago" or similar), not on the editorial surface.

---

## 3. The existing AI contract (what's already on disk)

Before any of Phase 6 ships, the contract surface is already half-built. These files exist on `main` today and are the canonical types Phase 6 will use and extend:

| File | What it is |
|---|---|
| `re_direct/AIRecommendationRequest.swift` | The provider-agnostic request DTO. Fields: `interests: [String]`, `mood: String?`, `timeAvailableMinutes: Int`, `excludePromptHashes: [String]`, `providerPreference: AIProviderPreference`, `locale: String`. **No raw user text.** |
| `re_direct/AIRecommendationResponse.swift` | The provider-agnostic response DTO. Fields: `id`, `topicSlug?`, `topicTitle`, `promptBody`, `suggestedMinutes`, `provider`, `modelVersion`, `promptInputHash`, `cached`, `createdAt`. |
| `re_direct/AIProviderPreference.swift` | Enum of provider preferences (including `.disabled`). |
| `re_direct/AIRequestValidator.swift` | Pure validation of outbound requests. |
| `re_direct/AIFallbackStrategy.swift` | `SeededCuriosityPromptProvider` protocol + `AIRecommendationResolver` that wraps the proxy-or-seed decision. `AIRecommendationSource` enum exposes whether a response came from `proxy`, `cache`, or `fallback`. |
| `re_direct/AICacheLookup.swift` | Local cache lookup by fingerprint. |
| `re_direct/SwiftDataAIRecommendationCache.swift` | SwiftData-backed cache with SHA-256 fingerprint that never leaves the device. |
| `re_direct/Models/AI/AIRecommendation.swift` | The persisted-recommendation `@Model`. |
| `re_direct/AIProxyError.swift` | Normalized proxy-side errors. |

**Phase 6 doesn't redesign these.** It builds:
1. A proxy that speaks this contract (6B).
2. A real iOS HTTP client that calls the proxy and falls through to cache or fallback (6C).
3. A Dashboard wiring that uses the resolver (6D).
4. A deepening surface that extends the contract for trails (6E).

The contract may **extend** in 6E (a new endpoint for trails, a new response shape for steps), but the existing single-recommendation surface should not break.

---

## 4. Privacy boundary

This is non-negotiable. If a slice would violate this, the slice stops and asks.

### 4.1 What is allowed to leave the device

- Recent rabbit-hole **titles** (`CuriosityEngagement.contentTitle`), trimmed to the first 80 characters and capped to the most recent N entries (N ≤ 8).
- Method slugs (`"watch"`, `"read"`, `"mini-game"`, `"reflect"`, `"deep-dive"`).
- Seed topic slugs / titles / summaries (these are bundled content, not user data).
- Coarse time budget (`timeAvailableMinutes`, integer minutes).
- Locale / language (`locale`, BCP-47).
- Coarse recency bucket per engagement (`today` / `this_week` / `older`) — never precise timestamps.
- Optional user-selected mood (one of a short canonical set: `restless`, `tired`, `curious`, `tender`, etc.). Mood is **user-selected**, never inferred from text or behavior.
- Excluded prompt hashes (`excludePromptHashes`) — opaque local SHA-256s of slugs the user has already seen. They are dedup tokens, not content.
- **User-declared personalization seeds** (added by §12 Phase 6A.1):
  - `interest_seeds` — short list of user-declared interest keywords (e.g. `"Machine Learning"`, `"Neuroscience"`). Each is a plain noun phrase the user explicitly typed or selected. Bounded length per entry (≤ 40 chars), bounded list size (≤ 12).
  - Optional `preferred_tone` — a short user-supplied tone descriptor string.
  - Optional `preferred_formats` — a small list of method slugs the user prefers (subset of the five canonical method slugs above).
  All three are **user-declared**, never inferred from reflection text, app usage, or any private signal.

### 4.2 What must never leave the device

- ❌ Raw `ReflectionEntry.body` content.
- ❌ Apple user identifier (Keychain Sign-In-with-Apple value).
- ❌ App-usage logs (when Phase 7 eventually lands, these stay on-device).
- ❌ DeviceActivity opaque tokens.
- ❌ Full `TimerSession` history. (Counts/aggregates over a small window may be sent if explicitly approved later — not in 6A.)
- ❌ Precise timestamps (use recency buckets instead).
- ❌ Private notes, mood inferences from text, screenshots, "proof" images.
- ❌ The user's display name or any personally-identifying string beyond what they've voluntarily put into a public-facing seed title.

### 4.3 Provenance & disclosure

- Every AI-derived row in local storage records its `provider`, `modelVersion`, and a `source: "ai-runtime"` flag.
- Settings (eventually) shows AI status as one row: "AI: disabled / configured / last success ⟨recency⟩ / fallback active." No telemetry, no analytics, no opt-in flag for anonymized analytics in v1.
- The user can disable AI entirely via `AIProviderPreference.disabled`. When disabled, the app falls through to seed + hardcoded fallback for every surface.

### 4.4 Safety check before any new payload field

For each Phase 6 slice, the implementer must answer **yes** to all of these before adding a field to an outbound request:

- [ ] Is this field listed in §4.1?
- [ ] If it's derived from user content, is the derivation sanitized (trim, hash, bucket)?
- [ ] If it's new, has §4 been updated to allow it?

A no on any answer pauses the slice.

---

## 5. Fallback ladder

Every AI-using surface must declare its fallback ladder up front. The canonical ladder is:

1. **Fresh local cache hit** (proxy-derived, within TTL, fingerprint matches the current request).
2. **Live proxy recommendation** (network call, normalized timeout, normalized error).
3. **Seeded local fallback** (curated bundle content via `AIFallbackStrategy.pickPrompt(matching:excluding:)`).
4. **Hardcoded fallback** (a single safe default if even the seed is missing — e.g. fresh install with a corrupt bundle).

A surface that doesn't gracefully degrade to step 4 is not shipped. The Dashboard's existing daily card already has hardcoded fallback copy; Daily Direct extends that ladder upward.

For surfaces that need a *result* even if AI is disabled, step 3 is the canonical answer. The user should never see "AI unavailable" or any error chrome — the surface just shows the seed-derived option quietly.

---

## 6. Slice sequence — Phase 6A through 6E

### Phase 6A — Strategy / Privacy / Workflow Plan (this slice)

**Status**: done with this commit.

**Deliverable**: this document + ROADMAP update marking Phase 7B parked and promoting Phase 6.

**Defines**: §2 product framing, §3 contract recap, §4 privacy boundary, §5 fallback ladder, §6 slice sequence, §7 payload concepts, §8 stop conditions, §9 open questions.

**Does not**: implement anything, choose a provider, choose a proxy host, write a single line of Swift or server code.

---

### Phase 6B — Proxy Skeleton

**Status**: proposed.

**Purpose**: stand up the server-side AI proxy that the iOS client will call. The proxy is the trust boundary: the API key lives there, never in the app.

**Recommended host**: Cloudflare Workers, unless a lighter-weight option proves better during 6B's planning. Cloudflare offers free-tier requests, durable execution, near-zero cold start, native fetch, no server to maintain, and `wrangler secret put` for the provider key.

**Endpoint shape (proposed)**:
- `POST /v1/recommendation` — request body: `AIRecommendationRequest` JSON. Response body: `AIRecommendationResponse` JSON or normalized error.
- `POST /v1/trail` — used by 6E for rabbit-hole deepening. Request: `TrailRequest` (concept in §7.3). Response: `TrailResponse` (concept in §7.4).

**Required behavior**:
- Request validation. Reject any field outside §4.1's allowlist. Reject `interests` over a canonical length (e.g. 20). Reject `mood` outside the canonical set. Reject titles over 80 chars.
- Provider abstraction. The proxy speaks a normalized internal contract; a thin provider adapter (OpenAI / Anthropic / Gemini / whatever) maps to/from. **Provider choice is config**, not code.
- API key in env var (`PROVIDER_API_KEY`). Never in repo. Never returned to client.
- Tight timeout (≤ 6s end-to-end). Provider timeout normalized to a 504 with a quiet body — no stack traces.
- Error normalization to the existing `AIProxyError` shape so the iOS client doesn't branch on vendor codes.
- **Minimal or no logging.** If logs are needed for debugging, they're short-TTL (≤ 7 days), structured, and they **must not** include request payload content beyond status codes and timing. Logs are deleted by default at TTL.
- **No persistence of request payloads** unless a future slice explicitly adds it with user consent. The proxy is stateless.
- CORS not required for iOS, but documented for completeness (future web reflections).
- Optional: per-installation rate limit on a hashed install ID to prevent runaway usage (concept only; not in 6B's MVP).

**Stop conditions for 6B**:
- No host can be chosen (Cloudflare account unavailable + no acceptable alternative).
- No provider key / billing account available.
- Required env-var / secret mechanism not supported by chosen host.

**6A does not implement 6B.** It commits to the design surface only.

---

### Phase 6C — iOS AI Client + Cache

**Status**: proposed.

**Purpose**: build the in-app HTTP client that calls the proxy, integrates with the existing cache, and feeds the fallback ladder.

**Required behavior**:
- A new `AIProxyHTTPClient` (Swift) that:
  - **Is disabled unless a proxy URL is configured** (e.g. `Info.plist` value, build-time injection, or a Settings field). Default: disabled.
  - Uses a short timeout (≤ 6s).
  - Speaks the existing `AIRecommendationRequest` / `AIRecommendationResponse` contract.
  - Consults `SwiftDataAIRecommendationCache` first via `AICacheLookup`. Cache hit → return without network call.
  - On cache miss, calls the proxy. On success, persists to cache via `SwiftDataAIRecommendationCache` with a TTL (initial proposal: 12 hours for Daily Direct, 1 hour for trail steps).
  - On any failure, returns the existing `AIRecommendationResolver`'s seed fallback via `AIFallbackStrategy`.
  - **Never sends `ReflectionEntry.body` or any §4.2 field.** A pre-flight runtime assertion against the outbound payload catches accidental field additions.
  - Maps provider errors to `AIProxyError` cases.
- TTL + fingerprint strategy:
  - Fingerprint = SHA-256(`AIRecommendationRequest`-canonical-JSON, locale, methodSlug-set-stable-order).
  - TTL per surface, declared in code, not in the proxy response unless `cacheTTL` is provided.
- Settings AI row eventually shows: `disabled` / `configured` / `last success ⟨relative⟩` / `fallback active` (which is reading the cache + last source).

**Out of scope for 6C**: UI wiring on Dashboard (that's 6D).

**Stop conditions**:
- The existing `AIRecommendationResolver` doesn't compose cleanly with an HTTP client (refactor required → split into its own slice first).
- The proxy contract diverges from the existing DTOs in a way that breaks back-compat (the response shape changes during 6B → 6C requires sync).

---

### Phase 6D — Dashboard Daily Direct

**Status**: proposed.

**Purpose**: the **first user-visible AI feature**. The Dashboard's daily curiosity card becomes AI-aware: it can suggest *one good redirect for today* based on what's seeded, what the user has logged, and a coarse time budget.

**Fallback ladder for Daily Direct**:
1. Fresh cache hit (proxy-derived, ≤ 12h old, matches today's signal fingerprint).
2. Live proxy recommendation.
3. Seeded local fallback (`AIFallbackStrategy` picks from `CuriosityTopic.prompts`).
4. Hardcoded fallback (existing daily card copy if seeded content is missing).

**What fields AI may fill**:
- `topicTitle` — shown in the card.
- `promptBody` — shown in the card.
- `topicSlug` — used to look up cover image / accent color from the seed (the proxy doesn't choose visuals).
- `suggestedMinutes` — shown as a small chip.

**What fields stay editorial / local**:
- Card visual: paper texture, accent color, cover image — all driven by the seed `CuriosityTopic` row, never by the proxy.
- Greeting, search affordance, Re:Log preview widget — untouched.
- No "AI generated" badge on the card. Provenance lives in Settings.

**How to keep visual design unchanged**:
- The proxy response maps to the existing `DailyCard` view's fields one-for-one.
- If the proxy returns a topic slug, the card uses the seeded topic's accent + cover.
- If the proxy returns a slug that doesn't exist in the seed (or no slug), the card uses a neutral accent + a neutral cover from a small default set. No new visual variants.

**How to avoid AI-chatbot chrome**:
- No "Ask AI…" field. No regeneration button. No thumbs-up/thumbs-down. No "powered by ⟨vendor⟩" footer.
- The user's affordance is: read the card, tap to engage, or scroll past. Same as today.

**How to show failures quietly**:
- If 6C returns the seed-fallback source, the card looks identical to a seeded card. The user doesn't know whether AI was involved. Settings row shows the truth.
- Network spinners are unwelcome here. The Dashboard renders the cache hit (or seed fallback) immediately on appear, and *upgrades* the card to a fresher recommendation only if the proxy responds within the timeout window of the same appear cycle.

**How to preserve local-first trust**:
- The first thing the user sees on a fresh install — no proxy configured, no cache, no network — is a seeded curiosity card. Same as today. AI absence is invisible.

**Stop conditions for 6D**:
- The proxy quality is too vague — recommendations don't feel like editorial picks, they feel generic. Pull back to seed-only for Daily Direct.
- The card layout requires variants that contradict re:direct's visual language.
- Cost-per-call against expected daily-active-user count makes the personal-use trial infeasible.

---

### Phase 6E — Rabbit-Hole Deepening / Guided Trail

**Status**: proposed.

**Purpose**: when a user logs a rabbit hole (e.g. "bioluminescence"), AI suggests an **intentional, bounded next-step trail** — one article, one video, one question, one reflection prompt, one deeper adjacent topic. The metaphor: Alice in Wonderland, but with a map.

**Source data**:
- One `CuriosityEngagement` row as the **root** (the rabbit hole the user just logged or tapped).
- Sanitized payload only (per §4): title, methodSlug, recency bucket. **No reflection body**, no notes.
- Optionally: nearby seed `CuriosityTopic` slugs the proxy can reference.

**Output shape (concept — see §7.4)**:
- A `TrailResponse` with `rootTitle` + `steps[]`.
- Each step has `type` (`article` / `video` / `question` / `reflection` / `topic`), `title`, short `rationale`, optional `url`, `estimatedMinutes`.
- **Max 3–5 steps** for v1. Hard ceiling. No infinite scroll, no "load more."

**Persistence question — open**:
- Option A: AI output is **transient** — the user sees a sheet with the proposed trail, can read it, tap a step to mark engagement (which creates a `CuriosityEngagement` per step they actually engaged with), and the trail itself is never persisted.
- Option B: AI output creates a **`TopicTrail` draft** in local SwiftData (with `TopicTrailStep` rows), unsaved until the user explicitly accepts.
- Option C: Hybrid — transient by default; an explicit "save this trail" action persists a draft.
- **Recommendation**: ship A first. Adds zero new storage. The user already has `CuriosityEngagement` as the unit of "I did this." A trail is just a presentation of those over the next session. Persisting a trail before the user actually walks it is premature.

**User action required**:
- The trail does **not** auto-insert anything. The user explicitly accepts the trail (or dismisses it). Saving an engagement only happens when the user marks a step done.
- The first version of the surface is read-only and exploratory: see the proposed steps, decide whether to commit.

**Fallback**:
- When AI is unavailable, the deepening sheet shows a **seeded trail** — pulled from `TopicTrail` / `TopicTrailStep` rows that already exist in `seed/curiosity_seed_v1.json` for the root topic, if one matches.
- If no seeded trail matches, the sheet shows a quiet "no deeper path yet" empty state. Not an error.

**Privacy boundary (extra-strict for 6E)**:
- The outbound payload contains only: `rootTitle` (capped 80 chars), `rootMethodSlug`, `locale`, optionally a small set of seed topic slugs.
- No reflection body. No user identifier. No usage history beyond the single root engagement title.

**Bounded-depth rule**:
- Each generated trail has ≤ 5 steps.
- A trail doesn't beget a sub-trail in v1. The user finishes (or doesn't). If they want to go deeper from one of the steps, that step becomes a new root via a separate explicit action.

**Stop conditions for 6E**:
- Recommendation quality at this granularity is too vague (the steps are generic clickbait, not editorial).
- URLs returned by the proxy are unreliable (404s, paywalled, off-topic).
- The user-action-required flow ends up feeling like work; the trail becomes a chore rather than an invitation.

**Future model proposal (not in 6E v1)**:
- If trails are eventually persisted (Option B/C), the existing `TopicTrail` / `TopicTrailStep` schema may be extended with `source: "seed" | "ai-runtime"` and `acceptedAt: Date?`. Document only — no migration in 6E v1.

---

### Phase 6F (optional, deferred) — AI Reflection Prompt Generation

**Status**: future, gated.

**Purpose**: extend REF5's plan (`docs/REFLECTION_ARCHITECTURE.md §7 REF5`) — when the user is inside a reflection writing surface, tapping "give me another prompt" calls the proxy with mood / time / interest signals and inserts a new `ReflectionPrompt(source: "ai-runtime")` row.

**This is the same slice as REF5.** Phase 6F is its rename inside the AI-lane narrative; the work is one slice, listed twice for cross-referencing.

**Boundary**: §4 still applies, and the existing REF5 acceptance test asserts no `ReflectionEntry.body` content appears in any outbound payload.

---

## 7. Payload shape concepts

These are **concepts, not contracts**. The real DTOs evolve in 6B / 6C / 6E and land as code there. Use these as the conversation-starting shape for those slices.

### 7.1 Daily Direct request (concept)

```jsonc
{
  "locale": "en-US",
  "timeBudgetMinutes": 15,
  "preferredMethodSlug": "read",     // optional; the user's active method
  "interestSeeds": ["Apple", "Machine Learning", "AI", "Neuroscience", "Software Engineering"],
  "preferredTone": "curious, warm, technically literate",   // optional
  "preferredFormats": ["read", "deep-dive", "reflect"],     // optional; subset of method slugs
  "recentEngagements": [
    { "title": "deep-sea glow",     "methodSlug": "read",  "recencyBucket": "today" },
    { "title": "self sabotage",     "methodSlug": "reflect","recencyBucket": "this_week" }
  ],
  "seededTopics": [
    { "slug": "bioluminescence", "title": "Bioluminescence", "summary": "Living things that make their own light." }
  ],
  "excludePromptHashes": ["a4f2…", "9c0e…"],
  "privacyMode": "minimal"
}
```

Notes:
- `interestSeeds` capped at N=12; each entry ≤ 40 chars; user-declared keywords only (see §12). On a fresh install with no engagement history, this is the **primary** personalization signal.
- `preferredTone` optional, ≤ 80 chars, user-supplied.
- `preferredFormats` optional, each entry is a canonical method slug, list ≤ 5.
- `recentEngagements` capped at N=8.
- `recencyBucket` ∈ {`today`, `this_week`, `older`}.
- `privacyMode: "minimal"` is the default and the only supported value in v1 — declares the payload-content constraints we agreed to in §4.

### 7.2 Daily Direct response (concept)

```jsonc
{
  "title": "What the deep sea remembers",
  "body": "Find one short documentary about the species you almost forgot existed.",
  "methodSlug": "watch",
  "estimatedMinutes": 12,
  "topicSlug": "bioluminescence",
  "trailSeed": null,                  // reserved for 6E linkage
  "provider": "anthropic",
  "model": "claude-sonnet-4-7",
  "cacheTTL": 43200,                  // 12h in seconds; iOS may cap
  "safetyFlags": []                   // empty in normal case
}
```

Notes:
- `cacheTTL` is advisory; the iOS client may override with a shorter cap.
- `safetyFlags` is reserved for the proxy to mark responses that should not be shown (e.g. the model returned something off-tone). Non-empty → fallback ladder kicks in.

### 7.3 Rabbit-hole deepening request (concept)

```jsonc
{
  "locale": "en-US",
  "rootTitle": "bioluminescence",
  "rootMethodSlug": "read",
  "rootRecencyBucket": "today",
  "seededTopicSlugs": ["bioluminescence", "cartography"],
  "maxSteps": 5,
  "privacyMode": "minimal"
}
```

### 7.4 Rabbit-hole deepening response (concept)

```jsonc
{
  "rootTitle": "bioluminescence",
  "steps": [
    {
      "type": "article",
      "title": "Why deep-sea creatures glow blue",
      "rationale": "Direct extension of your root; explains the chemistry.",
      "url": "https://...",
      "estimatedMinutes": 8
    },
    {
      "type": "video",
      "title": "Living light: a 6-minute tour",
      "rationale": "Visualizes what the article describes.",
      "url": "https://...",
      "estimatedMinutes": 6
    },
    {
      "type": "question",
      "title": "What would your day look like if you could only see in the dark?",
      "rationale": "Carries the deep-sea metaphor into your own life.",
      "url": null,
      "estimatedMinutes": 3
    },
    {
      "type": "reflection",
      "title": "Write about something you've been ignoring because it doesn't glow.",
      "rationale": "Bridge from topic to self.",
      "url": null,
      "estimatedMinutes": 5
    },
    {
      "type": "topic",
      "title": "Cartography of the invisible",
      "rationale": "If bioluminescence pulled you, this adjacent topic may too.",
      "url": null,
      "estimatedMinutes": null
    }
  ],
  "provider": "anthropic",
  "model": "claude-sonnet-4-7"
}
```

Notes:
- `type` ∈ {`article`, `video`, `question`, `reflection`, `topic`}.
- `url` is required for `article` and `video`, null for `question`, `reflection`, `topic`.
- Steps come back in **suggested order**; the iOS surface displays them in that order.
- 3 ≤ steps.count ≤ 5. Counts outside that range are normalized at the proxy.

---

## 8. Stop conditions (for the entire Phase 6 lane)

Any of these triggers a pause + re-plan:

- **No proxy host chosen** (Cloudflare or alternative).
- **No provider key / billing account available.**
- **Privacy payload would require raw `ReflectionEntry.body`** to produce useful output. We don't relax §4 to make a slice ship.
- **UI would need to claim automatic Screen Time / app-usage tracking** to make AI suggestions land. We don't fake DeviceActivity.
- **Recommendation quality is too vague** with sanitized data (the proxy keeps returning generic copy that doesn't feel curated).
- **Cost is too high for personal use** at expected call volumes.
- **Fallback behavior is not good enough** to ship — seed-only results read as obviously degraded.

A stop triggers `docs/AI_INTEGRATION_BLOCKER.md` (mirroring the DeviceActivity blocker pattern) and the lane pauses until cleared.

---

## 9. Open questions (sign off before 6B)

1. **Proxy host**: Cloudflare Workers vs. a tiny FastAPI on Fly.io vs. an Anthropic-direct call via a Workers Functions deployment. Recommendation: Cloudflare Workers for free tier + secret management. Confirm before 6B.
2. **Provider choice for v1**: Anthropic Sonnet (current Anthropic SDK familiarity, editorial-friendly tone) or OpenAI (broader model selection). Recommendation: Anthropic Sonnet. Confirm before 6B.
3. **Daily Direct cache TTL**: 12h proposed. Should it be shorter to feel fresh, longer to control cost? Recommendation: 12h with a "rotate at local midnight" rule so morning use feels fresh.
4. **Trail persistence (6E)**: Option A (transient) vs Option B (draft) vs Option C (hybrid). Recommendation: A.
5. **Mood input**: Does Daily Direct need mood at all in v1, or is the time-budget + recent-engagements signal enough? Recommendation: ship without mood in 6D; reintroduce in 6F when reflection prompts need it.
6. **Settings AI row design**: where in the existing Settings dossier does the AI status row live, and what copy variants does it surface? Recommendation: under "Privacy," next to the existing "AI proxy: contract only · disabled" row, which gets retired in 6C.
7. **Cost ceiling**: what monthly spend is acceptable for personal-use trial? Recommendation: set a hard ceiling ($10/mo to start) and a soft ceiling ($3/mo) that triggers a review.

---

## 10. What 6A did NOT do

- Did not write any Swift code.
- Did not write any proxy code (no Worker, no FastAPI, no anything).
- Did not configure any host or API key.
- Did not touch any view file.
- Did not add a model.
- Did not extend a DTO.
- Did not modify the existing `AIRecommendationRequest` / `Response` types.
- Did not promise a ship date for any of 6B–6F.

What 6A *did* do is lock the strategic surface so 6B's host/provider decision and 6C's client work can proceed without re-litigating privacy or scope.

---

## 11. Acceptance of this brief

This brief is accepted when:

- The privacy boundary in §4 is non-controversial and the team agrees no future slice will erode it.
- The fallback ladder in §5 is the default for every AI-touching surface.
- The five-slice sequence (6B → 6E) is unambiguous to whoever picks up the next step.
- DeviceActivity (Phase 7B) is acknowledged as parked, not abandoned, and AI is acknowledged as not pretending to replace it.

Once accepted, **Phase 6B begins** — and 6B is the first slice that touches a server.

---

## 12. Personalization seeds (Phase 6A.1 amendment)

This section amends §4, §6, and §7. DeviceActivity is parked, so the first cohort of AI requests has **no app-usage signal** to lean on. Until enough manually-logged `CuriosityEngagement` rows accumulate, the primary personalization signal must come from somewhere honest, local, and explicit. That signal is **user-declared interest seeds**.

### 12.1 What personalization seeds are

A small, local, user-declared list of interest keywords that tells the AI proxy "this is what this person finds curious." Seeds are:

- **Local-first** — they live in SwiftData (§12.5) and stay on the device unless an AI request explicitly takes them. They are not synced anywhere in v1.
- **User-declared** — the user types or selects them, ideally at onboarding (§12.6). Nothing infers them from text or behavior.
- **Editable** — the user can add, remove, or rewrite seeds at any time via Settings or onboarding flow (the surface lands in a future slice; the *capability* is reserved here).
- **Not DeviceActivity data** — no app-usage logs, no Apple Screen Time material, no FamilyControls tokens.
- **Not inferred from private reflection text** — `ReflectionEntry.body` never feeds seed generation. Period.

Seeds exist to **bootstrap** Daily Direct on day-one and to **anchor** rabbit-hole deepening when engagement history is thin.

### 12.2 Default personal v1 seed interests

For the **personal/local v1 build** (Nadine's current device), the default seed list is:

- `Apple`
- `Machine Learning`
- `AI`
- `Neuroscience`
- `Software Engineering`

These are **personal defaults**, not universal product defaults. They sit in the local store as the initial value when the SwiftData seed importer runs against a fresh profile. When the user editing surface lands, the user can rewrite or clear them.

**They must not be hardcoded as product defaults for all future users.** A future generalization slice will either:
- Ship empty defaults and force onboarding to collect them, or
- Ship a calmer "starter set" of broad-curiosity prompts that doesn't presume the user's interests.

The choice is deferred — but a comment in whatever Swift code eventually seeds these values must mark them clearly as "personal v1, replace before any third-party install."

### 12.3 Daily Direct input priority

When Phase 6D wires Daily Direct, the AI request payload assembles signals in this priority order:

1. **User-declared interest seeds** (§12.1, §12.2) — primary signal.
2. **Recent manually-logged `CuriosityEngagement` titles + method slugs + recency buckets** (capped at 8 entries) — augmentation as engagement history builds.
3. **Seeded `CuriosityTopic` titles/summaries** — content the bundle already curated; helps the proxy stay close to what the app can actually visualize.
4. **Active or preferred redirect method** (`activeRedirectMethodSlug` from `ActiveMethodStore`, falls back to `UserProfile.activeRedirectMethod.slug` if any).
5. **Coarse time budget and locale** — `timeAvailableMinutes` clamped 5–120; `locale` BCP-47.

**DeviceActivity / app-usage data is explicitly NOT in this priority list.** The list does not need it to be useful, and the privacy boundary does not include it.

### 12.4 Privacy boundary (clarification)

Adding to §4:

| Signal | Leaves device? | Notes |
|---|---|---|
| Interest seeds (user-declared keywords) | yes — as plain noun phrases | Bounded list size + per-entry length; user can edit/clear. |
| Preferred tone (optional) | yes — as a short user-supplied string | Plain text, not derived from any private content. |
| Preferred formats (optional) | yes — as method slugs | Subset of the five canonical slugs only. |
| Recent engagement titles (≤ 8) | yes — title only, 80-char cap | Per §4.1. |
| Method slug per engagement | yes | Per §4.1. |
| Recency bucket per engagement | yes — `today` / `this_week` / `older` | Per §4.1; precise timestamp never sent. |
| Mood (if user selects one) | yes — canonical set only | Per §4.1; never inferred. |
| Seed topic slug/title/summary | yes — bundled content, not user data | Per §4.1. |
| Locale, time budget, exclude-prompt hashes | yes | Per §4.1. |
| **Raw `ReflectionEntry.body`** | **NO** | Never, no exception. |
| **Apple identity (Sign-In-with-Apple value)** | **NO** | Stays in Keychain. |
| **DeviceActivity tokens / app-usage logs** | **NO** | Inapplicable today (parked) and disallowed always. |
| **Engagement notes / private user text** | **NO** | Unless an explicit future consent surface ships. |

When AI is disabled (`AIProviderPreference.disabled`), interest seeds stay local; Daily Direct falls through to seeded curiosity content + hardcoded fallback. Seeds existing on-device do not, by themselves, send anything anywhere.

### 12.5 Future data home (not implemented)

A future coding slice — **before Phase 6C or 6D wires anything live** — needs to land the storage for these seeds. Two candidate shapes:

**Option A — extend `UserProfile`** with a `var interestSeeds: [String] = []` field.

- ✅ Single local identity row; same place `displayName`, `activeRedirectMethod`, `activeReminderTheme` live.
- ✅ Smallest schema change (one field).
- ✅ Already wired into `ReDirectSchema.allModels`.
- ⚠️ If personalization preferences grow past a simple list (toned, formats, mood-history, etc.), the row gets crowded.

**Option B — new `PersonalizationPreferences` model**.

- ✅ Room to grow (tone, formats, future mood preferences, future content-language preferences).
- ✅ Decoupled from identity; easier to clear without touching `UserProfile`.
- ⚠️ Adds a new model, a new `@Query` site, and one-to-one-with-`UserProfile` semantics that need policing.

**Recommendation**: ship Option A first (one `interestSeeds: [String]` field on `UserProfile`). Migrate to Option B if/when the preference surface clearly exceeds a single list. Document this choice when the implementation slice opens; do not pre-commit it here.

### 12.6 Onboarding surface (not implemented)

Today's `OnboardingView` doesn't collect interest seeds. A future onboarding slice should:

- Present a small editorial screen — "what do you want to be more curious about?" or similar — at first-launch.
- Accept 3–8 short keywords (typed or selected from a starter set).
- Persist them to `UserProfile.interestSeeds` (Option A) or the new model (Option B).
- Skippable; defaults from §12.2 fill in for the personal v1 build.

A Settings row should later allow the user to edit/clear the list. That surface ships in a future slice — not in 6A.1 and not in 6B.

### 12.7 Rabbit-hole deepening tie-in (§6 Phase 6E amendment)

When `Phase 6E` lands the deepening surface, the trail-generation payload uses the **same priority order** from §12.3, with one adjustment: interest seeds are the **north star** that keeps the trail thematically coherent. Specifically:

1. **Interest seeds** — north star. The trail must stay in the user's declared interest gravity well. A bioluminescence root for a user whose seeds are `Apple, Machine Learning, Neuroscience` may legitimately bridge into `neural perception of low-light environments` but should not drift into `Renaissance maritime cartography` without an explicit user pivot.
2. **Engagement history** — recent context. What the user just logged (the root) and what they've logged nearby tells the proxy what depth they're at.
3. **Seeded topics** — safe fallback. When AI is unavailable, the deepening sheet renders a seeded `TopicTrail` for the root topic if one matches, with no AI involvement.
4. **Bounded depth** — 3–5 steps. The 6E response shape (`steps[]`) already enforces this; the input priority doesn't change the cap.

The trail-request payload in §7.3 will gain an `interest_seeds` field in the same shape used by Daily Direct. That extension is documented in §7 as a forward note when the trail endpoint actually ships.

### 12.8 What 6A.1 did NOT do

- Did not add the `interestSeeds` field to `UserProfile` (or any other model).
- Did not modify `OnboardingView`.
- Did not add a Settings surface for editing seeds.
- Did not extend the proxy contract DTOs in `re_direct/AI*.swift`.
- Did not write a single line of Swift.
- Did not promise a ship date for the storage slice (§12.5) or onboarding slice (§12.6).

What 6A.1 *did* do is establish that **personalization seeds are the first-class bootstrap signal** for Daily Direct, anchor the personal v1 defaults, and clarify the privacy boundary for those signals. The storage and surface slices follow as separate coding work before Phase 6D ships.
