# QA1 Milestone Findings Report

**Date:** 2026-05-29 (initial) · **F6.1 + Areas 6/7/13 closed 2026-05-30**  
**Tester:** Manual (Nadine) + automated inspection (Claude)  
**Build:** post-6E-D2 / post-QA0-Slices-A/B/C; F6.1 fix landed in iOS `da1776e` / `2e6b49f`, proxy `a39d7de`  
**Branch:** main  
**Tests at start:** 357 / 357 passing  
**Scope:** v1 spine hardening pass — simulator detailed QA + code inspection

---

## What Was Tested

| Area | Description | Result |
|---|---|---|
| 1 | Cold launch / onboarding | ✅ Pass |
| 2 | Dashboard Daily Direct | ✅ Pass |
| 3 | Re:Log manual rabbit-hole logging | ✅ Pass |
| 4 | Rabbit Hole loose end appears | ✅ Pass |
| 5 | Deepen flow (sheet presentation) | ✅ Pass |
| 6 | TrailPreviewSheet loading/success/failure | ✅ Pass (F6.1 closed 2026-05-30) |
| 7 | Accept trail → `.aiDeepened` thread | ✅ Pass — verified end-to-end on simulator 2026-05-30 |
| 8 | Manual thread creation | ✅ Pass |
| 9 | Attach loose end to thread | ✅ Pass |
| 10 | Thread preview | ✅ Pass |
| 11 | Settings local data / parked capabilities | ✅ Pass (with F12.2) |
| 12 | Privacy — no reflection body leaks | ✅ Pass |
| 13 | Cost — deepen cache behavior | ✅ Pass — verified on simulator 2026-05-30 (tap 2 instant + dashboard silent) |
| 14 | Physical device sanity check | ✅ Covered by existing sentinel/privacy tests (see note) |

**Area 13 note (updated 2026-05-30):** Cache hit behavior verified end-to-end on simulator after F6.1 fix landed. Tap 2 on the same loose end produced an instant trail sheet with identical content and zero new log lines in the Cloudflare dashboard — confirming the proxy was never called and `AITrailSessionStore` returned the cached response. Original blocker (no successful trail response) is resolved; cache logic now exercised live in addition to existing `AITrailSessionStoreTests` unit coverage.

**Area 14 note:** Reflection body exclusion is enforced at the type level via `EngagementPreviewRowModel` (structurally excludes reflection text) and is sentinel-tested in `AITrailMaterializerTests` and `AITrailRequestBuilderTests`. No separate manual injection pass was run. A dedicated physical-device injection pass can be scheduled if desired.

---

## Severity-Ordered Findings

### 🔴 P0 — Critical (blocks core feature)

#### F6.1 — `/v1/trail` 504 upstream_timeout — trail feature unusable in field  ✅ CLOSED 2026-05-30

**Area:** 6 (TrailPreviewSheet)  
**Original reproduction:**
1. Log a rabbit hole via Re:Log
2. Navigate to Rabbit Hole tab → loose ends section
3. Tap `[deepen]` on any loose end
4. Wait — TrailPreviewSheet enters loading state
5. After ~8s timeout, sheet shows failure state

**Original suspected cause (later proved incorrect):** proxy trail handler upstream timeout too short, or provider prompt too large for the configured token budget.

**Actual root cause:** `Locale.current.identifier` on iOS returns Apple's underscore format (`en_US`). The proxy trail/recommendation schemas validate locale against the BCP-47 regex `^[a-z]{2}(-[A-Z]{2})?$` which requires hyphen format (`en-US`). Every iOS request — trail and recommendation both — was silently rejected at proxy validation with HTTP 400 `invalid_input` before DeepSeek was ever called. The 504-timeout symptoms observed were a red herring; the proxy never reached its provider call. The timeout-raise mitigation (8s → 28s on the proxy) was real and useful work but did not and could not address the iOS-side failure.

**Resolution:**
- iOS commit `da1776e` introduced `bcp47Locale()` helpers on both `AITrailRequestBuilder` and `AIRecommendationRequest`. Helper swaps `_` → `-` and strips script subtags (`zh_Hans_CN` → `zh-CN`).
- Proxy commit `a39d7de` added contract fixture tests (`test/contract/`) and a `verify-contract.sh` script to catch this class of bug at CI time.
- iOS commit `2e6b49f` added wire-format encoder tests to `AITrailRequestBuilderTests` (BCP-47 assertion, no-underscore guard, complete-keys, no-extra-keys).
- Proxy logs were silent until commit `3357359` enabled Workers Logs observability in `wrangler.toml`. The root cause was diagnosable only after that change.

**Verified live on simulator 2026-05-30:**
- Tap `[deepen]` → `.success(response)` → trail sheet with 4 valid steps
- Tap `accept trail` → thread materialized as `sourceKind = .aiDeepened`
- Tap `[deepen]` again on a fresh loose end (cache test) → instant return, zero proxy log lines → Area 13 also closed

**Lesson:** the contract-fixture test layer added in `a39d7de` would have caught this bug at Phase 6E-B ship time. The full closed-operation writeup with phases, falsified hypotheses, and lessons is in `re_direct_ai_proxy/docs/TRAIL_LATENCY_DEBUG.md`.

---

### 🟠 P1 — High (major UX degradation)

#### F4.1 — Auth state does not persist across cold launches

**Area:** 4 (onboarding / identity)  
**Reproduction:**
1. Complete onboarding
2. Terminate app (cold kill)
3. Relaunch
4. Observe: auth/identity state not restored

**Expected:** Sign-in state persists via Keychain across cold launches  
**Actual:** Auth state resets on cold launch; user sees onboarding or unauthenticated state again  
**Suspected location:** `re_direct/Identity/KeychainAppleIDStore.swift`, `re_direct/Identity/AppleSignInPersister.swift` — Keychain read on launch not wired, or Sign-in-with-Apple capability not enabled (Slice 7.1 deferred)  
**Recommended fix slice:** Slice 7.1 — Apple Sign-In capability enable + end-to-end Keychain persistence verification. Manual Xcode step required (entitlement toggle).

---

### 🟡 P2 — Medium (noticeable, workaround exists)

#### F2.1 — Rabbit Hole empty state not vertically centered

**Area:** 2 (Rabbit Hole tab)  
**Reproduction:**
1. Launch app with no threads and no loose ends (fresh install or after clearing data)
2. Navigate to Rabbit Hole tab
3. Observe empty state

**Expected:** Empty state invitation text vertically centered in available space  
**Actual:** Empty state sits near top of scroll area; large blank space below  
**Suspected location:** `re_direct/RabbitHoleView.swift` — `emptyInvitation` container missing `frame(maxHeight: .infinity)` or equivalent vertical centering  
**Recommended fix slice:** Layout-only fix, single commit. Add `Spacer()` or `frame(maxHeight: .infinity, alignment: .center)` to the empty state container.

#### F12.2 — Settings Screen Time hint text truncated

**Area:** 11 (Settings)  
**Reproduction:**
1. Navigate to Settings tab
2. Scroll to Screen Time / parked capabilities section
3. Observe hint text on "screen-time connection" and "app-boundary permission" rows

**Expected:** Hint text reads fully  
**Actual:** "screen-time connection" hint truncates to `tracks app usage when thi...`; "app-boundary permission" hint truncates to `lets re:direct gently limit apps...`  
**Suspected location:** `re_direct/SettingsView.swift` — hint text strings too long for the row's available width; either shorten copy or increase row height  
**Recommended fix slice:** Copy-only or layout fix, single commit. Can be combined with F2.1 in one "layout polish" commit.

---

### 🟢 P3 — Low (minor / edge case)

#### F1.3 — Core Data error log spike on first install

**Area:** 1 (cold launch)  
**Reproduction:**
1. Delete app
2. Fresh install and launch
3. Observe Xcode console

**Expected:** Clean launch, no errors  
**Actual:** Spike of Core Data / SwiftData errors in console during first launch (likely `Library/Application Support` directory not pre-created before SwiftData container initializes)  
**Impact:** No user-visible effect; errors resolve after first launch. Noise in crash logs.  
**Suspected location:** `re_direct/re_directApp.swift` — add `Library/Application Support` directory creation before `ModelContainer` init  
**Recommended fix slice:** Single small commit. Pre-create directory in app init before SwiftData container setup.

#### F5.2 — Loose-end row pill differentiation could be stronger

**Area:** 5 (loose ends)  
**Reproduction:**
1. Navigate to Rabbit Hole tab → loose ends section
2. Observe `[thread?]` and `[deepen]` pills side by side

**Expected:** Pills are visually distinct enough to communicate different actions  
**Actual:** Pills are close in visual weight; `[deepen]` sparkle glyph is subtle; users may not immediately understand the distinction  
**Impact:** Discoverability of the deepen feature may be lower than intended  
**Suspected location:** `re_direct/RabbitHoleView.swift` — `LooseEndRow` pill styling  
**Recommended fix slice:** Polish slice. Increase visual differentiation (color, icon weight, or label copy). Scope to be defined before implementing.

#### F12.3 — Screen Time section in Settings: consider removing while parked

**Area:** 11 (Settings)  
**Status:** Decision pending — user message was cut off mid-thought  
**Proposal:** Remove or collapse the entire Screen Time / parked capabilities section from Settings while Timer/DeviceActivity remains parked for v2. Rationale: (a) "not enabled" rows for parked features add noise without actionable user value; (b) the `your logged rabbit holes` row arguably belongs in the **Local data** section above, not under Screen Time.  
**Suspected location:** `re_direct/SettingsView.swift`  
**Recommended fix slice:** Decision needed first. If approved: single commit, Settings-only.

---

### ℹ️ Informational (no action required)

| ID | Area | Observation |
|---|---|---|
| F3.1 | 3 | Re:Log preview widget arrow is inert — known deferred feature |
| F3.2 | 3 | Search bar focus not wired — under discussion |
| F1.5 | 1 | Social-auth row inert by design — Slice 7.1 |
| F8.1 | 8 | Manual thread creation works end-to-end; new thread becomes today card correctly |
| F8.2 | 8 | Zero-engagement thread renders as `0 steps · earlier today` — edge case handled gracefully |
| F12.1 | 11 | All four QA0-C renames in Settings landed correctly; status text reads as parked/dormant, not broken |
| F10.1 | 10 | ThreadPreviewSheet presents correctly; engagement list renders; reflection bodies absent (privacy invariant holds) |
| F9.1 | 9 | AttachToThreadSheet picker correctly excludes closed/deleted threads |

---

## Recommended Slice Ordering

1. ~~**Proxy slice** — fix F6.1 in `re_direct_ai_proxy/`.~~ **✅ Done 2026-05-30.** Root cause was iOS locale format (`en_US` vs `en-US`), not proxy timeout. Resolved across iOS commits `da1776e` + `2e6b49f` and proxy commit `a39d7de`. Contract fixture tests + iOS encoder tests added as regression armor. Areas 6, 7, 13 all closed.

2. **iOS Slice 7.1** — Apple Sign-In capability enable + Keychain persistence. Closes F4.1 + F1.5 together. Requires manual Xcode entitlement step. **← Next slice.**

3. **iOS layout/copy polish slice** — F2.1 (Rabbit Hole empty state centering) + F12.2 (Settings hint truncation). Same file family (`RabbitHoleView.swift`, `SettingsView.swift`), single small commit.

4. **iOS launch polish slice** — F1.3 (Core Data error spike on first install). Tiny change in `re_directApp.swift`.

5. **Decision: F12.3** — Screen Time section removal. Needs explicit user direction before touching Settings.

6. **Deferred** — F5.2 (loose-end pill differentiation), F10.4 (progress-oriented thread UI). Scope to be defined.

7. **Latency follow-ups** (conditional, in proxy repo) — §5.3 in-proxy retry, §5.4 iOS cooldown, vestigial `provider_preference` cleanup. Gated on observed production data via the `provider_fetch_request_ms` / `provider_fetch_body_ms` / `provider_parse_ms` instrumentation now live in proxy commit `83a7bd5`. First real iOS-originated sample (2026-05-30) showed TTFB-dominant latency at 15.7s on a 28s ceiling — within budget but with a real tail. Accumulate more samples before shipping defensive retry infrastructure.

---

## What Not to Touch

- `re_direct.xcodeproj/project.pbxproj` — personal signing drift, leave unstaged
- `re_direct.xcodeproj/xcshareddata/xcschemes/re_direct.xcscheme` — debug diagnostics drift, leave unstaged
- Root view initializers (`DashboardView()`, `RabbitHoleView()`, `TimerView()`, `RetualsView()`, `ReLogView()`, `AppTabView()`, `SettingsView()`)
- `TimerView` source and `TimerSession` model — parked, not removed
- Phase 7 / DeviceActivity work — parked pending Apple Developer Program + Family Controls entitlement
- Proxy privacy denylist — do not relax without explicit approval
