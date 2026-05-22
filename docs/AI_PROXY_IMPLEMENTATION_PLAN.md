# AI Proxy Skeleton — Phase 6B Implementation Plan

Documentation-only. This document is the build plan for the AI proxy that Phase 6B implements. No proxy code, no Swift code, no API keys live in this commit.

Phase 6B's deliverable is a **skeleton** — a deployable, validating, provider-pluggable Worker that accepts the existing iOS-side `AIRecommendationRequest` and returns an `AIRecommendationResponse` (or a normalized `AIProxyError`). It does **not** require a polished Dashboard wiring (that's 6D), or even iOS network code (that's 6C). The skeleton must work end-to-end against `curl` before any iOS work begins.

Companion documents:
- `docs/AI_INTEGRATION_PLAN.md` — Phase 6 strategy and privacy boundary (Phase 6A).
- iOS contract surface: `re_direct/AIRecommendationRequest.swift`, `AIRecommendationResponse.swift`, `AIRequestValidator.swift`, `AIProxyError.swift`, `AIProviderPreference.swift`, `AIFallbackStrategy.swift`.

---

## 1. Goal of Phase 6B

Stand up a small, trustworthy HTTP proxy that:

1. Speaks the existing iOS DTO contract verbatim — snake_case JSON keys, exact field names, exact wire-error shape.
2. Holds the provider API key on the server side. **The iOS app never touches a key.**
3. Validates every inbound request against the same constraints the iOS validator already enforces (and rejects anything outside §4 of `AI_INTEGRATION_PLAN.md`'s privacy allowlist).
4. Calls one configured provider (initial: Anthropic), via a thin adapter that can be swapped without changing the route handler.
5. Returns a normalized response or a normalized error. No vendor stack traces, no provider-specific status codes leaking through.

Phase 6B is **done** when `curl -X POST` against the deployed proxy returns a valid `AIRecommendationResponse` for a valid request, and a properly-shaped `AIProxyError` wire-body for every failure mode.

---

## 2. Location and repository layout

### 2.1 Proxy lives in a sibling folder

```
re_direct/                    ← iOS app workspace (this repo, current root)
  re_direct.xcodeproj
  re_direct/
  re_directTests/
  docs/
  seed/

re_direct_ai_proxy/           ← NEW — proxy lives here, sibling to iOS app
  src/
    index.ts                  ← Worker entry
    routes/
      recommendation.ts       ← POST /v1/recommendation handler
    providers/
      anthropic.ts            ← initial provider adapter
      provider.ts             ← Provider interface
    validation/
      request.ts              ← inbound request validator
      response.ts             ← outbound response shaper
    errors/
      wire.ts                 ← AIProxyError wire shape + factory
    util/
      fingerprint.ts          ← SHA-256 prompt input hash
      log.ts                  ← redacted, short-TTL logger
  test/
    recommendation.test.ts
    validation.test.ts
    providers/
      anthropic.test.ts
  wrangler.toml               ← Cloudflare config
  package.json
  tsconfig.json
  README.md                   ← run + deploy instructions
  .gitignore
  .dev.vars.example           ← documented env, NOT committed
```

**Sibling, not nested.** The proxy is a separate deployable artifact with its own dependencies, CI, and release lifecycle. Putting it inside `re_direct/` would tangle Xcode's file-system membership and risk accidental bundling. Putting it as a sibling keeps both projects' tooling clean.

The iOS repo (this one) does **not** depend on the proxy at build time. The proxy URL is a runtime config string the iOS app reads from `Info.plist` or a build-time injection.

### 2.2 Optional submodule decision (deferred)

For now `re_direct_ai_proxy/` is its own git history, **not** a submodule of the iOS repo. Submodules add ceremony for one developer; the value comes only with multiple consumers. Phase 6B starts as a plain sibling repo. If a second client (web reflections, CLI tooling) ever appears, revisit.

---

## 3. Runtime choice

### 3.1 Recommendation: Cloudflare Workers + TypeScript

Reasons:

- **Free tier ample for personal use** (100k requests/day on the Workers free plan; we'll be far below that).
- **Native `fetch` + Web Streams** — no Node compat shim needed for calling Anthropic / OpenAI HTTP APIs.
- **`wrangler secret put`** for API key management — never lands in repo, never in env files.
- **Near-zero cold start** — important when Dashboard appearance triggers a call.
- **Built-in CORS, no separate server, no Dockerfile, no Postgres-or-anything.**
- **TypeScript out of the box** with `wrangler init`.
- **Easy local dev** via `wrangler dev`.

### 3.2 Alternatives considered (and not chosen)

| Option | Why not |
|---|---|
| Fly.io + FastAPI | More moving parts (Docker, machines, regions). Cold start measurable. Overkill for stateless inference. |
| Vercel Functions + Node | Comparable to Workers but lock-in to Vercel and weaker secret-management UX. |
| Anthropic-direct from iOS | Would require an API key on-device. Categorical no — violates §4 of `AI_INTEGRATION_PLAN.md`. |
| Apple's own provider (Apple Intelligence) | Not yet available for backend chat-style inference outside system surfaces. Revisit if/when. |
| AWS Lambda + API Gateway | Strong, but more YAML/IAM for one route than the project needs. |

**Lock in Workers + TypeScript unless during 6B the implementer hits an unmovable blocker** (e.g. Anthropic SDK requires Node-only API, payload size cap, regional latency from CF's points-of-presence). If a blocker emerges, the fallback is Fly.io + FastAPI, and the swap is documented in `docs/AI_PROXY_BLOCKER.md`.

---

## 4. Endpoint surface

### 4.1 Initial endpoint (Phase 6B scope)

```
POST /v1/recommendation
Content-Type: application/json
```

That's the entire surface for 6B. No `GET /health`, no metrics endpoint, no admin endpoint. Those can come later as their own slices when they're actually needed.

### 4.2 Future endpoints (NOT in 6B)

Documented here so the route table stays consistent when 6E lands:

- `POST /v1/trail` — Phase 6E rabbit-hole deepening.
- `POST /v1/reflection-prompt` — Phase 6F (= REF5) reflection-prompt generation.

Both follow the same versioned `/v1/` namespace.

### 4.3 No versioning gymnastics

Versioning is **URL-segment-based** (`/v1/...`). When a breaking change is needed, `/v2/...` ships side-by-side and the iOS client upgrades on its own schedule. The existing `AIProxyError.clientUpgradeRequired` code is the explicit signal.

---

## 5. Request schema (must match iOS DTO verbatim)

The iOS-side `AIRecommendationRequest` (`re_direct/AIRecommendationRequest.swift`) defines the canonical shape. The proxy parses **exactly this** off the wire:

```jsonc
{
  "interests": ["bioluminescence", "cartography"],
  "mood": "curious",                               // optional, ≤ 32 chars
  "time_available_minutes": 15,
  "exclude_prompt_hashes": ["a4f2...", "9c0e..."],
  "provider_preference": "auto",                   // matches AIProviderPreference rawValues
  "locale": "en-US"
}
```

**Field rules** (mirror `AIRequestValidator`):

| Field | Required | Constraint |
|---|---|---|
| `interests` | yes | 1 ≤ count ≤ 8; each matches `^[A-Za-z][A-Za-z \-]{0,39}$` |
| `mood` | no | ≤ 32 chars; canonical set documented in 6A §4.1 (`restless`, `tired`, `curious`, `tender`, `honest`) |
| `time_available_minutes` | yes | 5 ≤ n ≤ 120 |
| `exclude_prompt_hashes` | no | ≤ 20 entries; each lowercase-hex SHA-256 (64 chars) |
| `provider_preference` | yes | one of `AIProviderPreference` raw values |
| `locale` | yes | `^[a-z]{2}(-[A-Z]{2})?$` (BCP-47 short form) |

**Rejected silently or noisily**:

- Unknown top-level keys → 400 with `{ "error": { "code": "invalid_input", "message": "unknown field: …" } }`. (Strict parsing prevents accidental field additions from leaking through.)
- Any field shape mismatch → 400 with `invalid_input`.
- Body > 16 KiB → 413 mapped to `invalid_input`.

### 5.1 What the proxy MUST NOT accept

The proxy enforces the §4 privacy boundary from `AI_INTEGRATION_PLAN.md`. Even if a future iOS bug accidentally puts one of these on the wire, the proxy rejects:

- `reflection_body`, `note`, `engagement_body`, `body` — any free-text user content field.
- `apple_user_id`, `user_id`, `identity_*` — any user-identifier field.
- `device_activity_*`, `screen_time_*`, `family_*_token` — any Apple Screen Time material.
- `precise_timestamp`, `engaged_at`, `started_at` — precise timestamps (only `recency_bucket` allowed at request level, and that's a 6D extension; 6B's contract has no per-event timestamp field).

This is a denylist at the JSON-parse layer. The denylist lives in `src/validation/request.ts` and is unit-tested.

---

## 6. Response schema (must match iOS DTO verbatim)

The iOS-side `AIRecommendationResponse` is the canonical shape:

```jsonc
{
  "id": "01HZ...",                       // ULID or UUID; proxy-issued
  "topic_slug": "bioluminescence",       // optional; matches seed slug if known
  "topic_title": "Bioluminescence",      // editorial-cased title
  "prompt_body": "...",                  // the recommendation copy
  "suggested_minutes": 12,
  "provider": "anthropic",
  "model_version": "claude-sonnet-4-7",
  "prompt_input_hash": "f3a1...",        // SHA-256 of canonical request JSON
  "cached": false,                       // 6B always returns false; cache is iOS-side
  "created_at": "2026-05-22T12:34:56Z"   // ISO-8601 / RFC 3339
}
```

**Field rules**:

- `id`: server-generated; ULID preferred (sortable, URL-safe).
- `topic_slug`: nullable. The proxy may suggest a slug that doesn't exist in the iOS seed; the iOS client treats unknown slugs as "no seeded match" and uses neutral visuals.
- `prompt_body`: ≤ 600 chars; one-paragraph editorial copy; no Markdown, no HTML, no leading/trailing whitespace.
- `suggested_minutes`: 5 ≤ n ≤ 120 (proxy clamps).
- `provider`: lowercase vendor identifier (`anthropic`, `openai`, `gemini`).
- `model_version`: vendor-specific version string, opaque to iOS.
- `prompt_input_hash`: SHA-256 hex of the canonical-JSON request (deterministic key order). Used by iOS cache fingerprinting (6C).
- `cached`: always `false` in 6B (the proxy is stateless). Reserved for a future server-side cache slice; not 6B.
- `created_at`: ISO-8601 UTC.

### 6.1 What the proxy MUST NOT include

- No vendor-specific metadata fields (`anthropic_*`, `usage`, `tokens`, etc.). If we need observability, it goes to logs (§9), not to the iOS payload.
- No echoes of the input payload — request fields don't round-trip in the response.

---

## 7. Validation approach

### 7.1 Two layers

**Layer A — JSON-parse strict mode**. The body is parsed with a strict schema parser (Zod or similar). Unknown keys reject. Type mismatches reject. The denylist from §5.1 is applied at this layer.

**Layer B — semantic validation**. After parse succeeds, run the same constraints `AIRequestValidator.swift` enforces. This is duplicated logic by design — the proxy doesn't trust the client to validate.

A single helper `validate(request): { ok: true; value: Request } | { ok: false; error: WireError }` is the only entry point. The route handler never bypasses it.

### 7.2 Validation must reject before any provider call

If validation fails, the route returns the wire error and **never** calls the provider. This protects the provider quota and avoids leaking malformed inputs through to vendor logs.

### 7.3 Test coverage

`test/validation.test.ts` covers, at minimum:

- happy path with full payload
- happy path with only required fields
- each constraint boundary (interests 0, 1, 8, 9; time 4, 5, 120, 121; mood at 32 / 33 chars; locale shape)
- denylist field rejection (one test per denied field)
- unknown top-level key rejection
- invalid type at each field
- oversized body

---

## 8. Provider abstraction

### 8.1 Interface

```ts
// src/providers/provider.ts
export interface Provider {
  readonly name: string;          // "anthropic" / "openai" / ...
  readonly model: string;         // current model version
  generateRecommendation(
    input: NormalizedRequest,
    signal: AbortSignal
  ): Promise<NormalizedResponse>;
}
```

`NormalizedRequest` and `NormalizedResponse` are internal types — the provider speaks them, and the route handler converts between them and the wire DTOs. This keeps vendor-specific structure (chat messages, system prompts, function-call schemas) inside the adapter and out of the public API.

### 8.2 Initial implementation: Anthropic

`src/providers/anthropic.ts` implements `Provider` against the Anthropic Messages API. Concrete details:

- Reads `PROVIDER_API_KEY` from `env.PROVIDER_API_KEY` (Worker secret).
- Uses `MODEL_NAME` env var (default: `claude-sonnet-4-7`).
- One Messages API call per `generateRecommendation`.
- System prompt held inline in the adapter, version-tagged by `prompt_version` constant.
- Output is structured via the model's JSON-mode (or a tightly-prompted plain-text return parsed by a regex anchor — implementer's call during 6B, but JSON-mode preferred).
- Validation of provider response against `NormalizedResponse` shape before returning to the route handler.

### 8.3 Provider choice is config

`PROVIDER_NAME` env var (default `"anthropic"`) selects which adapter is instantiated at request time. Swapping to OpenAI is a future change of one env var + a new adapter file, no route changes.

### 8.4 Timeout discipline

- Provider call wrapped in an `AbortController` with **5-second** timeout (route-level timeout is 6s, leaving 1s for serialization).
- Timeout → `upstream_timeout` wire error.
- Provider 4xx (except 429) → `upstream_failed`.
- Provider 429 → `rate_limited` with `retry_after_seconds` parsed from header.
- Provider 5xx → `upstream_failed`.

---

## 9. Logging and privacy rules

### 9.1 What may be logged

- HTTP method + path.
- HTTP status code.
- Duration in milliseconds.
- `provider` name and `model_version`.
- An opaque request fingerprint (the same SHA-256 used for `prompt_input_hash`).
- Boolean flags: did validation fail, did provider call succeed.

### 9.2 What may NEVER be logged

- The request body (raw or transformed).
- The response body.
- Any field from `interests`, `mood`, `exclude_prompt_hashes`, `locale`.
- Any header that could identify a device (none should be sent by the iOS client; the proxy strips `User-Agent` from logs anyway).
- Anthropic / OpenAI / vendor IDs that reference content.

### 9.3 Retention

- Cloudflare Workers Logpush, if used, points at a destination with **7-day TTL**. Default Workers logs (Tail/Logs panel) are ephemeral; that's fine.
- No request-body persistence. Period.

### 9.4 Logger surface

```ts
// src/util/log.ts
log.event("request", { method, path, status, durationMs, provider, modelVersion, fingerprint });
log.error("provider_failed", { provider, status, durationMs, fingerprint });
```

Both helpers accept only the allowlisted keys; passing any other key is a TypeScript compile error.

---

## 10. Env vars and secrets

| Name | Type | Where | Notes |
|---|---|---|---|
| `PROVIDER_NAME` | env var (plain) | `wrangler.toml [vars]` | default `"anthropic"` |
| `MODEL_NAME` | env var (plain) | `wrangler.toml [vars]` | e.g. `"claude-sonnet-4-7"` |
| `PROVIDER_API_KEY` | **secret** | `wrangler secret put PROVIDER_API_KEY` | NEVER in repo, NEVER in `.dev.vars` committed file |
| `ALLOWED_ORIGINS` | env var | `wrangler.toml [vars]` | optional CORS allowlist; default empty (only iOS app, no origin) |
| `PROXY_VERSION` | env var | `wrangler.toml [vars]` | semver tag of the deployed Worker, surfaced in logs |

### 10.1 Local dev

A `.dev.vars` file (in `re_direct_ai_proxy/`, gitignored) sets local values:

```
PROVIDER_API_KEY=sk-ant-...        # local key, separate from prod
PROVIDER_NAME=anthropic
MODEL_NAME=claude-sonnet-4-7
```

A committed `.dev.vars.example` documents the keys with placeholders. `.gitignore` blocks `.dev.vars`.

### 10.2 Production secrets

`PROVIDER_API_KEY` is set via:

```
cd re_direct_ai_proxy
wrangler secret put PROVIDER_API_KEY
# prompts for value, stores encrypted in Cloudflare
```

The secret is never echoed back, never logged. Rotating it is a re-run of the same command.

---

## 11. Local dev and test commands

### 11.1 First-time setup

```
cd re_direct_ai_proxy
npm install
cp .dev.vars.example .dev.vars
# edit .dev.vars to set local PROVIDER_API_KEY
```

### 11.2 Local dev server

```
npm run dev          # = wrangler dev --local
```

This starts the Worker locally on `http://127.0.0.1:8787`. Hot-reloads on save.

### 11.3 Smoke test via curl

```
curl -X POST http://127.0.0.1:8787/v1/recommendation \
  -H 'Content-Type: application/json' \
  -d '{
    "interests": ["bioluminescence"],
    "time_available_minutes": 15,
    "exclude_prompt_hashes": [],
    "provider_preference": "auto",
    "locale": "en-US"
  }'
```

Should return `200` + a `AIRecommendationResponse` JSON.

### 11.4 Tests

```
npm test             # runs vitest test suite
npm run test:watch
```

`test/` covers validation, route handler, provider adapter (mocked), error normalization.

### 11.5 Type check + lint

```
npm run typecheck    # tsc --noEmit
npm run lint         # eslint
```

---

## 12. Deploy command

```
cd re_direct_ai_proxy
npm run deploy       # = wrangler deploy
```

`wrangler deploy` reads `wrangler.toml`, bundles the Worker, uploads to Cloudflare. The deployed URL is the value the iOS client will be configured with in Phase 6C.

### 12.1 Environments

`wrangler.toml` declares two environments:

- `dev` — `re-direct-ai-proxy-dev.<account>.workers.dev`, lower-volume key, freer rate limits.
- `prod` — `re-direct-ai-proxy.<account>.workers.dev`, production key, stricter rate limits.

Phase 6B targets `dev` only. Promoting to `prod` is a separate slice (`Phase 6B.1` if needed) gated on observed stability.

---

## 13. Error and fallback behavior

### 13.1 Wire-error shape (must match `AIProxyError.WireError`)

```jsonc
{
  "error": {
    "code": "rate_limited",                  // canonical string
    "message": "Provider rate limit exceeded.",
    "retry_after_seconds": 30                // optional, only for rate_limited
  }
}
```

HTTP status mapping:

| `code` | HTTP status | Triggers iOS seeded fallback? |
|---|---|---|
| `invalid_input` | 400 | no |
| `invalid_token` | 401 | no |
| `provider_blocked` | 403 | no |
| `rate_limited` | 429 | yes |
| `upstream_failed` | 502 | yes |
| `proxy_unavailable` | 503 | yes |
| `upstream_timeout` | 504 | yes |
| `client_upgrade_required` | 410 | no |

The "triggers iOS seeded fallback" column matches `AIProxyError.triggersSeededFallback`. The proxy doesn't decide what iOS does; it just emits the canonical code and lets the iOS resolver (`AIRecommendationResolver`) follow the existing fallback ladder.

### 13.2 Proxy-side fallback policy

The proxy itself has **no** local fallback. If the provider fails, the proxy returns `upstream_failed` (or `upstream_timeout` / `rate_limited`) and the iOS client falls through to its cache or seeded fallback. The proxy never invents a recommendation.

This keeps the proxy stateless, predictable, and easy to reason about. Adding a server-side seed-fallback is a future slice (6B.2 if ever) — not 6B.

---

## 14. CORS and origin policy

- Worker accepts only `POST` on `/v1/recommendation`.
- `OPTIONS` preflight: returns 204 with `Access-Control-Allow-Methods: POST` and `Access-Control-Allow-Headers: Content-Type` — only if `ALLOWED_ORIGINS` is non-empty.
- iOS clients don't send `Origin`; CORS is effectively a no-op for the only consumer in 6B.
- Future web reflections (if any) would set `ALLOWED_ORIGINS=https://...` to enable.

---

## 15. Rate limiting (deferred to 6B.1, NOT in 6B)

6B ships with **no** rate limiting beyond what Cloudflare's free tier already enforces. The proxy is for personal use; the volume is low. A per-installation rate limit (hashed install ID, sliding window) is a 6B.1 slice if real-world abuse appears.

---

## 16. Out of scope (explicitly NOT in 6B)

- Server-side caching of provider responses.
- Multi-provider load balancing.
- Trail endpoint (`/v1/trail`) — that's Phase 6E.
- Reflection-prompt endpoint — that's Phase 6F / REF5.
- Analytics, metrics dashboards, SLO instrumentation.
- A `prod` environment deployment.
- A status page.
- A `/health` endpoint.
- Provider-side prompt-versioning UI (the system prompt is a constant in the adapter for 6B).
- iOS HTTP client (Phase 6C).
- Anything that would require persisting a request payload (categorical no without a separate slice).

---

## 17. Acceptance criteria for Phase 6B

When all of these are true, 6B is done:

- [ ] `re_direct_ai_proxy/` exists as a sibling folder with its own `package.json`, `wrangler.toml`, `README.md`.
- [ ] `npm run dev` starts a local Worker that handles `POST /v1/recommendation`.
- [ ] A `curl` against `http://127.0.0.1:8787/v1/recommendation` with a valid payload returns a parseable `AIRecommendationResponse`.
- [ ] A `curl` with an invalid payload returns the corresponding wire error and HTTP status from §13.1.
- [ ] `npm test` passes with ≥ the validation tests listed in §7.3, plus one happy-path route test using a mocked provider.
- [ ] `npm run typecheck` and `npm run lint` are clean.
- [ ] `PROVIDER_API_KEY` is configured as a Cloudflare secret (not in repo, not in `.dev.vars.example`).
- [ ] `wrangler deploy` succeeds against the `dev` environment.
- [ ] A `curl` against the deployed `dev` URL returns a valid response.
- [ ] `.gitignore` blocks `.dev.vars`, `node_modules`, `.wrangler/`, `dist/`.

**Not** required for 6B done:
- iOS network code (6C).
- Dashboard wiring (6D).
- Production deploy (6B.1).
- Any observability beyond Worker logs.

---

## 18. Open questions to lock before 6B starts

1. **Provider for v1**: Anthropic Sonnet 4-7 vs OpenAI GPT-5 vs Gemini 2.5? Recommendation: Anthropic Sonnet 4-7, editorial-friendly tone, JSON-mode-friendly. Confirm before 6B.
2. **System prompt source of truth**: inline constant in adapter (`src/providers/anthropic.ts`) vs separate `prompts/recommendation.md` file. Recommendation: inline constant for 6B, with a `// prompt_version: 1` comment. Move to a separate file if the prompt grows past ~50 lines.
3. **JSON-mode vs prompted JSON**: Anthropic supports tool-use for structured output. Recommendation: tool-use call with a single "emit_recommendation" tool, schema matching `NormalizedResponse`. Failure to parse → `upstream_failed`.
4. **Cost ceiling for dev environment**: Anthropic billing alert threshold. Recommendation: $5/mo hard alert, $1/mo soft alert.
5. **Test framework**: Vitest vs Node's built-in test runner. Recommendation: Vitest — already standard in the Cloudflare community, good DX with Wrangler.
6. **Wrangler version**: pin in `package.json`. Recommendation: latest stable at start of 6B; pin exact, upgrade deliberately.

---

## 19. Next coding prompt (Phase 6B execution)

```
Run Phase 6B: AI proxy skeleton implementation.

Context:
docs/AI_PROXY_IMPLEMENTATION_PLAN.md is the canonical spec. Follow §2–§17.

Scope (sibling folder, NOT inside the iOS repo's app code):
- Create `re_direct_ai_proxy/` as a sibling to the iOS app root.
  Layout per §2.1.
- Initialize TypeScript Cloudflare Worker project via `npm create cloudflare`
  (or `wrangler init`).
- Implement:
  - `src/index.ts` — router with one POST /v1/recommendation route.
  - `src/validation/request.ts` — strict parse (Zod or equivalent) + denylist
    + AIRequestValidator-mirror semantic checks. Test coverage per §7.3.
  - `src/providers/provider.ts` — Provider interface.
  - `src/providers/anthropic.ts` — initial provider adapter (tool-use call,
    5s timeout, normalized errors).
  - `src/errors/wire.ts` — wire-error factory matching §13.1 canonical codes
    and HTTP status mapping.
  - `src/util/fingerprint.ts` — canonical-JSON SHA-256.
  - `src/util/log.ts` — typed allowlist logger per §9.
- wrangler.toml with [dev] and [vars]; secrets via `wrangler secret put`.
- .gitignore blocks .dev.vars, node_modules, .wrangler/, dist/.
- .dev.vars.example committed; .dev.vars NOT committed.
- README.md with the §11 dev commands and §12 deploy commands.
- Test suite covers validation + happy-path route with mocked provider.

Do not:
- Touch any iOS file in this commit.
- Hardcode a production URL anywhere in iOS code.
- Implement Phase 6C, 6D, 6E, 6F.
- Add a /v1/trail or /v1/reflection-prompt route.
- Add server-side response caching.
- Add a /health endpoint.
- Add observability beyond Worker logs.
- Implement Phase 6B.1 rate limiting.

Acceptance per §17:
- `npm run dev` + curl smoke test returns valid response.
- All wire-error codes from §13.1 produce the documented HTTP status.
- `npm test`, `npm run typecheck`, `npm run lint` all pass.
- `wrangler deploy` against `dev` env succeeds and curl works against the
  deployed URL.

Commit (inside `re_direct_ai_proxy/`, NOT in the iOS repo):
  feat: scaffold AI proxy skeleton

The iOS repo (this repo) gets no commits during Phase 6B execution. The next
iOS-side slice is Phase 6C.
```

---

## 20. What 6B-plan did NOT do

- Did not write any Worker code.
- Did not create `re_direct_ai_proxy/`.
- Did not configure any Cloudflare account.
- Did not request a provider API key.
- Did not touch any iOS file.
- Did not modify any existing DTO.
- Did not promise a Phase 6B ship date.
- Did not stage `re_direct.xcodeproj/project.pbxproj` signing drift.
