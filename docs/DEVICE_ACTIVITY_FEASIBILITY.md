# Phase 7A — DeviceActivity Feasibility Plan

Documentation-only. No SwiftData model is created, no view is touched, no entitlement is requested in this slice. This document is the brief for a future spike (Phase 7B) that will decide whether re:direct uses Apple's Screen Time frameworks for selected-app usage boundaries, and on what terms.

This brief is authored against publicly documented Apple framework behavior on iOS 16+ and the current SDK. Specific API shapes may shift between releases; re-verify against the SDK in use when Phase 7B starts. Anything described here in the future tense is a *plan*, not a shipped feature.

---

## 1. Why this brief exists

re:direct's Timer surface arms a **boundary**, not a stopwatch (see `docs/ROADMAP.md` → *Timer / Boundary note → Arming semantics*). The intended future behavior is:

- The user arms a boundary for selected apps and a duration.
- The boundary waits until the tracked app is actually used.
- Usage time accumulates only while the tracked app is in use.
- Completion is **system-driven** when tracked-app usage reaches the configured threshold.
- Manual `stop early` is the only user-controlled end.

That future behavior is only possible if Apple's Screen Time stack (FamilyControls + DeviceActivity + ManagedSettings) is **viable** for an `.individual`-mode self-monitoring iOS app, approvable for the App Store, and a sensible fit for re:direct's editorial product surface.

This brief enumerates what "viable" requires, what could block it, and what the fallback looks like if the answer is no.

---

## 2. Framework overview

Apple exposes four frameworks for this domain. They are designed to be used together; they do not stand alone.

### 2.1 FamilyControls

- Mediates **authorization** to use the other three frameworks.
- One-time per-install user grant via `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
- `.individual` is the self-monitoring mode (adult user monitoring their own usage). `.child` is the parental-monitoring mode and requires a Family Sharing relationship.
- Provides `FamilyActivityPicker` — the **only** UI for the user to pick which apps, categories, and Safari domains to scope. The app never sees bundle IDs or human-readable names; it receives opaque `ApplicationToken`, `ActivityCategoryToken`, and `WebDomainToken` values bundled inside a `FamilyActivitySelection`.

### 2.2 DeviceActivity

- Schedules monitoring of a `DeviceActivitySelection` over a date window (`DeviceActivitySchedule`).
- Defines `DeviceActivityEvent` rules — usage thresholds against `ApplicationToken`s / `ActivityCategoryToken`s.
- Threshold and schedule lifecycle callbacks (`intervalDidStart`, `intervalDidEnd`, `eventDidReachThreshold`, warnings) fire **inside a DeviceActivityMonitor app extension**, not the main app.
- The schedule persists across reboots once registered.

### 2.3 DeviceActivityMonitor (app extension)

- Separate target — a sandboxed extension subclassing `DeviceActivityMonitor`.
- Short execution budget per callback. No UI. Limited APIs (`ManagedSettings`, `UserDefaults` via app group, `URLSession` only for background-safe traffic — but re:direct does **no** network here).
- The extension is where shielding turns on/off in response to threshold/interval events.
- Communicates with the main app via a **shared App Group** (`UserDefaults(suiteName:)`, shared files, or App Group SwiftData store).

### 2.4 ManagedSettings

- `ManagedSettingsStore` applies system-enforced restrictions: shield specific applications / categories / web domains, hide app installation, block specific settings panes.
- The shield is an opaque system overlay. The user is shown a system-provided block screen unless `ManagedSettingsUI` customization is shipped.
- Restrictions persist until the store clears them or the app is uninstalled (uninstall clears managed state for `.individual` mode).

### 2.5 ManagedSettingsUI (app extension)

- Separate target — extensions subclassing `ShieldConfigurationDataSource` and `ShieldActionDelegate`.
- Lets re:direct customize the shield's title, subtitle, icon, accent color, and up to two action buttons.
- Action buttons can only request the extension to dismiss the shield, defer it, or close. They cannot launch arbitrary URLs or main-app routes. Any custom routing has to round-trip through the App Group + a `UserNotifications` ping or wait until the user opens the main app.

---

## 3. Authorization model

- `AuthorizationCenter.shared.requestAuthorization(for: .individual)` triggers a system sheet. The user can grant or deny; denial is sticky and revocable only from Settings → Screen Time.
- The status is queryable as `AuthorizationCenter.shared.authorizationStatus`.
- For `.individual`, **no Family Sharing relationship is required**. The acting user is the same as the monitored user.
- The grant is per-install; reinstalling the app revokes prior state.
- Without a successful grant, every other framework in this brief throws / no-ops.

re:direct implication: the authorization request needs an editorial pre-explanation screen (one short page) that frames *why* the app is asking and that **nothing leaves the device**. The request should not happen at launch — gate it on the user's first tap that needs it (e.g., the first time they pick tracked apps in Timer).

---

## 4. App architecture impact

Adopting Screen Time is not a single-target change. It introduces two new targets and one new shared layer:

| Target | Purpose | Notes |
|---|---|---|
| `re_direct` (existing) | Main app. Owns the picker UI and reads back stored selections. | Embeds Screen Time entitlement. |
| `re_directMonitor` (new) | `DeviceActivityMonitor` extension. Fires threshold / interval callbacks; applies/lifts `ManagedSettingsStore` restrictions. | New target in `re_direct.xcodeproj`. Embedded in the app. |
| `re_directShield` (new, optional) | `ManagedSettingsUI` extension. Customizes the shield screen with re:direct copy + paper-glass styling. | Optional for the spike; recommended for production polish. |
| App Group (new) | `group.com.nadinepm.redirect` (or similar). Shared `UserDefaults` and optionally a shared SwiftData store. | Carries `FamilyActivitySelection`, active boundary metadata, last shield-action timestamps. |

Token handling note: `ApplicationToken` and `WebDomainToken` are **opaque, device-bound, and not portable**. They `Codable`-encode but the encoded bytes cannot be transmitted off-device or shared across devices. They cannot be turned back into bundle IDs by re:direct. They can be persisted in the App Group's `UserDefaults` via the framework's own encoding helpers.

This is privacy-positive (re:direct learns nothing about which apps the user picked) and product-constraining (re:direct cannot display "you blocked Instagram" — only "you blocked 3 apps" or a `Label(token)` rendered by the system inside the picker UI).

---

## 5. Entitlement and capability requirements

| Requirement | Where | Who can grant | Notes |
|---|---|---|---|
| `com.apple.developer.family-controls` entitlement | `re_direct.entitlements` | Apple, via request form | **Restricted entitlement**. Requires an approval request submitted at the developer portal *before* App Store submission. Approval is human-reviewed and not instant. |
| Same entitlement on each extension | `re_directMonitor.entitlements`, `re_directShield.entitlements` | Apple, same approval | Each target with Screen Time API access needs the entitlement embedded. |
| App Group entitlement | All three targets | Self-managed via Apple Developer portal | Required for main app ↔ extension communication. |
| Sign in with Apple entitlement | (existing, Slice 7.1) | Self-managed | Unrelated to Screen Time but in the same `entitlements` file. |
| `NSFamilyControlsUsageDescription` | `Info.plist` of main app | Self-managed | Short purpose string shown on the authorization sheet. |
| iOS 16.0+ deployment target | Project setting | Self-managed | `.individual` mode is iOS 16+. (iOS 15 supports parental mode only.) |

The Family Controls entitlement is the gating risk. The request asks for justification, intended monitored audience, and use case. Self-monitoring digital-wellbeing apps have historically been approved when the request makes clear that the user *only ever monitors themselves*, no third party is involved, and no data leaves the device. Vague or B2B-flavored use cases have been rejected.

---

## 6. Simulator vs real device

| Capability | Simulator | Real device (signed) |
|---|---|---|
| `FamilyControls.requestAuthorization(for: .individual)` | Returns immediately, often `.approved` or `.notDetermined` without showing a sheet. **Unreliable.** | System sheet appears; user choice persists. |
| `FamilyActivityPicker` UI | Renders, but the application list is empty or stubbed. **Not usable for end-to-end test.** | Real installed apps and Safari domains appear. |
| `DeviceActivityCenter.startMonitoring` | Accepts schedules silently. Threshold callbacks fire inconsistently or not at all. | Threshold and interval callbacks fire as scheduled. |
| `DeviceActivityMonitor` extension lifecycle | Effectively untested by Apple. **Do not rely on simulator results.** | Authoritative environment. |
| `ManagedSettingsStore.shield.applications = …` | No visible system shield overlay. | Real shield overlay on home screen and inside apps. |
| `ManagedSettingsUI` shield customization | Not visible. | Visible after the shield is applied. |

**Conclusion: every Phase 7B spike acceptance test must be run on a physical iPhone with Screen Time enabled under the developer's Apple ID, signed with the Family Controls entitlement.** The simulator is useful only for compile-checking the target wiring and the picker UI shell.

This is a meaningful constraint for re:direct's CI story — the test suite cannot exercise this layer in `xcodebuild ... -destination 'platform=iOS Simulator'`. Phase 7B acceptance is **manual on-device** and is documented as such.

---

## 7. App Store / TestFlight approval risks

| Risk | Severity | Notes |
|---|---|---|
| Family Controls entitlement request denied | High | The request form must clearly describe self-monitoring (`.individual`), local-first data handling, and that re:direct never transmits app usage data. A denied request blocks the entire shielding stack. |
| Review rejection on first submission even with entitlement | Medium | Reviewers occasionally reject Screen Time apps for unclear shield purpose, dark-pattern shield UI, or paywalled access to monitoring features. re:direct is free / non-paywalled, so this is mitigated but not zero. |
| Privacy nutrition label expansion | Low | The label needs a *Screen Time Information* declaration; we already declare "data not collected" because tokens never leave the device. The label needs updating but the substance doesn't change. |
| TestFlight gating | Low | TestFlight builds need the entitlement provisioning profile. Internal testing should work as soon as the entitlement is in the profile. |
| Future API deprecation | Medium | Screen Time APIs have changed shape across iOS 15 → 16 → 17 → 18. Plan for one-version-behind tolerance and re-verify each WWDC. |
| Shield action button limits | Low | We cannot deep-link from the shield to a specific re:direct route. Mitigate via a notification or a "open re:direct" affordance after the user taps the shield. |

---

## 8. Mapping to re:direct's Timer / Boundary model

The corrected Timer/Boundary semantics (per `docs/ROADMAP.md`) line up cleanly with the Screen Time stack. The mapping is:

| re:direct concept | Screen Time mechanism |
|---|---|
| User picks "apps to set a boundary around" in Timer | `FamilyActivityPicker` → `FamilyActivitySelection` stored in App Group |
| User taps **start boundary** to arm | `DeviceActivityCenter.startMonitoring(activityName, during: schedule, events: [.threshold(duration): event])` |
| Boundary waits until tracked app is in use (no countdown UI) | DeviceActivity counts foreground time for the selected tokens automatically. re:direct shows armed state, not elapsed seconds. |
| Usage accumulates only while tracked app is in use | DeviceActivity is the source of truth. re:direct does **not** sample, poll, or estimate. |
| System-driven completion at threshold | `DeviceActivityMonitor.eventDidReachThreshold(_:activity:)` fires → extension applies `ManagedSettingsStore.shield.applications = selection.applicationTokens` → user sees the shield |
| The shield message is the "redirect" moment | `ManagedSettingsUI` shield extension renders re:direct copy ("take a breath. redirect.") and one CTA back to re:direct |
| Manual `stop early` | Main app writes a flag to the App Group; the monitor extension reads it on next callback and lifts the shield + ends the schedule. Or: main app directly calls `DeviceActivityCenter.stopMonitoring(activityName)` and clears `ManagedSettingsStore.shield`. |
| `TimerSession` row | Still the local boundary-telemetry record. Started when the user arms; closed with `interrupted` (stop early) or `completed` (threshold reached) based on the callback that closed it. Persisted via App Group write from the extension, or written by the main app on its next foreground read. |
| `CuriosityEngagement` row | **Unchanged**. User-declared rabbit holes remain canonical. Screen Time enriches when available; it does not replace `CuriosityEngagement`. |

What this mapping does **not** add:

- No usage charts in re:direct's UI.
- No "you spent 47 minutes on X today" surfacing.
- No category-level shaming.
- No background-fetch traffic. The extension is the only thing reacting to thresholds and it has no network calls.

The product surface that changes: Timer's app-selection step becomes a real `FamilyActivityPicker` presentation, the start affordance arms a real monitor, and the shield is a real system overlay re:direct can style.

---

## 9. Phase 7B — Spike plan

Phase 7A (this document) is the brief. **Phase 7B** is the actual spike. Phase 7B should run as a short-lived branch and **must not be merged into `main`** until acceptance is met.

### 9.1 Scope of the spike (minimum viable)

1. Add Family Controls capability to a spike branch only; commit the `.entitlements` and `Info.plist` `NSFamilyControlsUsageDescription` change, but do not submit the entitlement request to Apple yet — request as part of Phase 7C if 7B passes.
2. Add a `DeviceActivityMonitor` extension target named `re_directMonitor`.
3. Add an App Group on both targets.
4. Stand up an editorial pre-explanation screen + authorization request, gated behind a hidden debug entry point (not Timer yet).
5. Present `FamilyActivityPicker`; persist the `FamilyActivitySelection` to the App Group.
6. Arm a 2-minute test schedule with a 60-second threshold event against the selection.
7. In the extension, apply a `ManagedSettingsStore.shield` on threshold and clear it on `intervalDidEnd`.
8. Surface the schedule's lifecycle in a debug log readable from the main app.

No `ManagedSettingsUI` extension in 7B unless authorization + shield-on-threshold already passes; the customized shield is Phase 7C polish.

### 9.2 Success criteria (must hit all)

- [ ] On a real device, `AuthorizationCenter.requestAuthorization(for: .individual)` shows the system sheet and returns `.approved` after the user accepts.
- [ ] `FamilyActivityPicker` renders the user's real installed apps; the selection persists across an app kill/relaunch via the App Group.
- [ ] `DeviceActivityCenter.startMonitoring` accepts a `[.threshold:]` schedule without throwing.
- [ ] After ~60 s of real foreground use of a picked app, `eventDidReachThreshold` fires inside the extension (verified via App Group log).
- [ ] The extension successfully sets `ManagedSettingsStore.shield.applications = …`; the system shield overlay appears on the picked app.
- [ ] The shield can be lifted by the main app calling `ManagedSettingsStore().clearAllSettings()` (or equivalent for the named store).
- [ ] `intervalDidEnd` fires at the schedule's `intervalEnd` and the schedule does not auto-restart.
- [ ] The full arm → use → shield → clear flow remains stable for a 25-minute real-duration test.
- [ ] No data leaves the device. Network log empty during the entire spike session.

### 9.3 Stop conditions (any one halts the spike)

- Family Controls entitlement cannot be added to the developer profile in the spike's signing setup (blocker for everything downstream).
- Authorization sheet fails to appear on physical device on iOS 17/18 after three configuration attempts.
- `eventDidReachThreshold` fires unreliably (≥2 of 5 test runs miss).
- Extension binary crashes on dispatch and crashlog references private framework symbols outside our control.
- Shield application succeeds but cannot be cleared without uninstalling re:direct.
- Persistent off-device traffic appears during the test session (would mean a misconfiguration we cannot diagnose locally).
- The user (Nadine) decides the editorial product surface degrades — e.g., the system shield is too jarring for a "gentle boundary" product, or the authorization sheet copy creates friction that conflicts with the calm onboarding tone.

If a stop condition triggers, capture the failure mode in a follow-up doc (`docs/DEVICE_ACTIVITY_BLOCKER.md`) and move to the fallback plan in §10.

### 9.4 Deliverables of Phase 7B

- A branch (`phase-7b-device-activity-spike`) with the targets wired but **gated behind a debug flag** so `main` builds continue to work without the entitlement.
- A short on-device verification note in `docs/PHASE_7B_RESULTS.md` recording which acceptance criteria passed, which failed, and what each failure looked like.
- A go/no-go recommendation for Phase 7C (production integration).

---

## 10. Fallback plan (if Phase 7B fails or Phase 7C is blocked)

re:direct's product loop **does not depend on Screen Time succeeding**. The fallback is already partially built:

- **`CuriosityEngagement`** stays the canonical user-declared signal for "you actually went down a rabbit hole." It is local-first, user-controlled, and needs no entitlement.
- **`TimerSession`** stays as lightweight local boundary telemetry — armed, stopped-early, or marked complete by a local fallback timer running while the main app is foregrounded.
- **Local fallback completion** stands in for `eventDidReachThreshold`. When the user arms a boundary, re:direct schedules a local `UNUserNotificationCenter` notification for the configured duration that nudges the user to redirect. The `TimerSession` row is only **marked complete when the app next foregrounds** — either via the user tapping the notification, opening re:direct directly, or responding to a notification action. Without DeviceActivity there is **no guaranteed background completion**: if the user never returns to the app, the session stays open until it does, and the next foreground pass reconciles it (e.g. closing as `interrupted` if its scheduled end is in the past). This is honest about what it is — a soft, app-side reminder, not a usage measurement.
- **No shielding**. The Re:Log "rabbit holes" count, the re:tuals lane history, and the editorial framing carry the product value. No system overlay means re:direct stays a calmer surface — arguably a better product for a "gentle boundary" thesis.
- **Re:Log Screen Time recap** would be removed from the roadmap (or recharacterized as user-entered "what did you do today" reflection).

The fallback is the product re:direct already is today, with one extra honest line in Settings ("DeviceActivity: not integrated · we tried; here's why we stopped"). Shipping the fallback does not block TestFlight or App Store submission, since no restricted entitlement is required.

---

## 11. What this slice did NOT do

- Did not add or request the Family Controls entitlement.
- Did not create any new Xcode target.
- Did not modify `Info.plist`, `.entitlements`, or signing settings.
- Did not write any Swift source.
- Did not commit a feature branch.
- Did not contact Apple developer support.

All of the above are explicit Phase 7B / 7C work, gated on this document being accepted as the brief.

---

## 12. Open questions for sign-off before Phase 7B

1. **Is the entitlement-request risk acceptable?** Apple can deny. If denied, weeks of integration work are wasted. Recommendation: write the request justification now, against this brief, *before* Phase 7B starts, so we know what the pitch sounds like.
2. **Is the .individual mode the right scope?** re:direct could theoretically support parental mode later; v1 should ship `.individual` only. Recommendation: confirm `.individual` and move on.
3. **Do we ship `ManagedSettingsUI` (customized shield) in Phase 7C, or accept the default system shield in v1?** Customization is editorial-product-aligned but doubles the extension footprint. Recommendation: ship the customized shield only if Phase 7B passes cleanly; default shield is acceptable as a first cut.
4. **Where does the shield's "redirect" CTA land — Dashboard, re:tuals, or Timer's post-session view?** This affects the deep-link plumbing. Recommendation: re:tuals, because the shield moment *is* the redirect moment, and re:tuals is the lane-history surface.
5. **What's the rollback story if Apple changes APIs in iOS 19?** Recommendation: gate the entire Screen Time path behind a feature flag from day one; the fallback (`§10`) becomes the always-available branch.

---

## 13. References

- [Apple — FamilyControls](https://developer.apple.com/documentation/familycontrols)
- [Apple — DeviceActivity](https://developer.apple.com/documentation/deviceactivity)
- [Apple — ManagedSettings](https://developer.apple.com/documentation/managedsettings)
- [Apple — ManagedSettingsUI](https://developer.apple.com/documentation/managedsettingsui)
- [Apple — Meet the Screen Time API (WWDC 2021)](https://developer.apple.com/videos/play/wwdc2021/10123/)
- [Apple — What's new in Screen Time API (WWDC 2022)](https://developer.apple.com/videos/play/wwdc2022/110336/)
- Family Controls entitlement request form: developer portal → *Account → Membership → Request additional Apple services*.

---

## 14. Acceptance of this brief

This document is accepted when:

- The Phase 7B spike scope (§9.1) is unambiguous to whoever runs it next.
- The success criteria (§9.2) and stop conditions (§9.3) are clear enough that "the spike passed" is a binary call, not a judgment.
- The fallback plan (§10) is plausible enough that **declining Screen Time entirely is a real product option**, not a hidden loss.

Once accepted, Phase 7B can begin on its own branch. Until accepted, no entitlement is requested, no target is added, and `main` continues to ship as the local-first prototype it already is.
