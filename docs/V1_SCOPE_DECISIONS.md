# re:direct v1 — scope decisions and pivot narrative

**Purpose:** A single consolidated doc explaining what re:direct's v1 deliberately *doesn't* do and why. Written for portfolio context so a reviewer can understand the design judgement behind the scope, not just the shipped feature set. Each section links out to deeper technical docs for anyone who wants the full story.

**Last updated:** 2026-05-31

---

## 1. What v1 is

A single-user, local-first iOS app for noticing and redirecting attention. Manual rabbit-hole logging, editorial curation, AI-assisted trail generation (via a privacy-bounded Cloudflare Workers proxy), and reflection writing — all stored on-device in SwiftData. No accounts, no servers holding user data, no Screen Time integration.

**Distribution:** local build only. Not on the App Store.

---

## 2. The major deferrals

### 2.1 Screen Time / DeviceActivity / FamilyControls integration — deferred indefinitely

**Original ambition:** the app was originally designed around Apple's Screen Time, DeviceActivity, and FamilyControls APIs. The idea was for the app to *automatically* notice when the user crossed an app-usage threshold and present a redirect prompt in the moment.

**What blocked it:** the FamilyControls entitlement is only granted to teams with App Store distribution capability and an approved use case. The personal developer account this app is built on doesn't have access to it. See `docs/DEVICE_ACTIVITY_FEASIBILITY.md` for the full feasibility analysis.

**The pivot:** rather than fake or stub the Screen Time integration, the app was re-scoped around **manual rabbit-hole logging** (Re:Log) plus **AI-assisted curiosity curation** (Daily Direct, Trail) as the v1 path. The Screen Time substrate was preserved in the schema (`BoundarySession`, `TimerSession`) as a forward-compatibility scaffold but is not on any user flow in v1.

**Where the pivot is documented:**
- `docs/DEVICE_ACTIVITY_FEASIBILITY.md` — original feasibility brief and "parked-not-abandoned" framing
- `docs/AI_INTEGRATION_PLAN.md` — the AI lane as the alternative forward path, with explicit framing in §1 ("Why this brief exists")
- `docs/ROADMAP.md` — Phase 7B is the named resumption slice if entitlement access changes

**In-app surface:** none in v1. The Settings → Screen Time section was removed on 2026-05-31 because showing inert "not enabled" rows added noise without providing user value. The capability remains scaffolded in code and schema; only the in-app surface is removed.

### 2.2 Apple Sign-In + Keychain identity persistence — deferred indefinitely

**Original ambition:** multi-user identity via Apple Sign-In, with sign-in state persisting across cold launches via Keychain. Originally tracked as Slice 7.1.

**What changed:** the app is scoped single-user local-first. There is no multi-user identity differentiation problem to solve, and the only person who experiences the "re-tap signup on cold launch" friction is the developer during development.

**The fix that shipped instead:** a 10-minute `@AppStorage("onboardingComplete")` flag in `re_directApp.swift`'s `RootView`. On first launch, OnboardingView appears; tapping any entry button flips the flag; subsequent cold launches branch straight to AppTabView. UserDefaults-backed because there's no security requirement (anyone with the device already has full local data access).

**Forward compatibility preserved:** `AppleSignInCoordinator`, `AppleSignInPersister`, `KeychainAppleIDStore`, and the `UserProfile.onboardingComplete` schema slot are all preserved on disk. If App Store distribution is ever pursued, Slice 7.1 is the ready-to-resume entry point with all contract files in place.

**Where it's documented:**
- `docs/QA1_REPORT.md` F4.1 entry — reclassification rationale and resolution
- iOS commit `3ea3774` — the actual fix
- Code comment in `re_direct/OnboardingView.swift` — v2 forward-pointer

### 2.3 App Store distribution — deferred indefinitely

**Why:** the Indonesian Apple Developer Program fee (~IDR 1.8M / ~USD 110) is substantial for a student building a first portfolio app. The trade-off — shipping vs. portfolio quality on the same budget — favored quality.

**Consequence:** all features that require App Store distribution (FamilyControls, multi-user identity, push notifications, App Store review, paid/free tiers, etc.) are off the v1 critical path. The app runs as a personal development build.

### 2.4 The original v1.5 ambitions that quietly folded

A handful of secondary features were considered and dropped during scope tightening:

- **Social authentication** (Google, X) — onboarding row remains as visual placeholder per the editorial design (QA1 F1.5), but the buttons are intentionally inert. Removing them would unbalance the social-button row visually; activating them adds OAuth complexity for no v1 user value.
- **Cross-device sync via CloudKit** — requires identity, requires Apple Developer Program, requires data model that doesn't currently exist.
- **Analytics / telemetry** — privacy boundary already excludes this; surfaced in Settings as `analytics: off`.

---

## 3. The AI lane — what shipped instead of Screen Time automation

When Screen Time was parked, the AI integration became the primary forward path because it produced the same psychological effect (the app feels like it's *doing something for you*) through different means.

**What it actually does:**
- **Daily Direct:** one editorial-quality "next step" suggestion per launch, generated by a Cloudflare Workers proxy that fronts a DeepSeek-hosted LLM
- **Trail (rabbit-hole deepening):** tap `[deepen]` on a manually-logged loose end → AI generates a 3–5 step bounded trail (article / video / question / reflection / topic) → user accepts to materialize a `RabbitHoleThread` with `sourceKind = .aiDeepened`
- **Privacy boundary:** reflection bodies never leave the device. Engagement notes never leave the device. Apple identity never leaves the device. The full denylist is enforced at the proxy's JSON-parse layer via Zod, *and* fixture-tested via `re_direct_ai_proxy/test/contract/`.

**The architecture story (worth telling in portfolio):**
- Two-repo split: iOS app + sibling proxy repo. iOS never holds a provider API key.
- Cost-controlled allowlists at provider selection (`ALLOWED_DEEPSEEK_MODELS`, `ALLOWED_OPENROUTER_MODELS`) — a stray `MODEL_NAME` env var fails closed at `proxy_unavailable` instead of silently routing onto a pricier tier.
- Contract fixture tests across both repos — the iOS payload shape is checked against the proxy schema at CI time, so silent schema drift fails a test instead of becoming a production 400.
- Latency observability decomposed into `provider_fetch_request_ms` (TTFB) / `provider_fetch_body_ms` (transport) / `provider_parse_ms` (our overhead) — measurement infrastructure that turns future perf work into provable changes instead of folkloric ones.

**Deep links:**
- `docs/AI_INTEGRATION_PLAN.md` — strategic brief, privacy boundary, slice sequence
- `docs/AI_PROXY_IMPLEMENTATION_PLAN.md` — proxy patterns, validation, cost controls
- `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md` — Phase 6E trail contract and persistence bridge
- `re_direct_ai_proxy/docs/TRAIL_LATENCY_DEBUG.md` — closed-operation writeup of the F6.1 debug session

---

## 4. The F6.1 debug story — worth telling

The most representative engineering moment in the project history is the F6.1 closed-operation. It went like this:

1. QA1 captured that tapping `[deepen]` always failed. Classified P0 CRITICAL.
2. Initial hypothesis: proxy timeout too aggressive vs. DeepSeek tail latency. Real, partially correct, partially misleading.
3. Phase 1–3 of a structured debug op (reproduce → isolate → diagnose) raised the proxy ceiling, ran perf experiments, found that prompt-trimming made things *worse* (a falsified hypothesis), and shipped progressive latency instrumentation.
4. After enabling Workers Logs observability, the first iOS-originated log entry showed `validation_failed: true / status: 400 / duration_ms: 0` — the proxy was rejecting iOS requests before ever calling DeepSeek.
5. Root cause: `Locale.current.identifier` on iOS returns `"en_US"` (Apple's underscore format); the proxy regex requires `"en-US"` (BCP-47 hyphen). Every iOS request — trail and recommendation both — had been silently 400'd since day one.
6. Fix: one helper method (`bcp47Locale()`) plus three layers of regression armor (proxy contract fixtures, iOS encoder tests, `verify-contract.sh` script) so the same class of bug fails CI rather than production.

**Why this is worth telling:** it's the canonical example of how good observability infrastructure, structured debugging, and contract test layers turn an undiagnosable production problem into a one-character fix. It also shows the failure modes — phases of work that didn't directly solve the bug but produced legitimate hardening (ceiling raise, latency instrumentation, Workers Logs config). Honest engineering with the falsified hypotheses left in the historical record.

Full writeup: `re_direct_ai_proxy/docs/TRAIL_LATENCY_DEBUG.md`.

---

## 5. Reading order for portfolio reviewers

If a reviewer wants to understand the project in 30 minutes, the recommended path is:

1. **This doc** — scope decisions and why
2. `docs/AI_INTEGRATION_PLAN.md` §1–§4 — the AI lane's framing and privacy boundary
3. `docs/AI_RABBIT_HOLE_TRAILS_PLAN.md` §1–§9 — the trail product framing and proxy contract
4. `re_direct_ai_proxy/docs/TRAIL_LATENCY_DEBUG.md` — the F6.1 debug story end-to-end
5. `docs/QA1_REPORT.md` — what was tested, what was found, what was deferred

For 90 minutes: add `docs/DEVICE_ACTIVITY_FEASIBILITY.md`, `docs/AI_PROXY_IMPLEMENTATION_PLAN.md`, and the proxy repo's `README.md` + `test/contract/`.

---

## 6. What's intentionally NOT in this doc

- Implementation tutorials. The deep docs already cover those.
- A feature list. The README is the right place for that.
- An apology for the deferrals. They're deliberate scope choices, not omissions.
