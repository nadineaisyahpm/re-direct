# Auth Setup

re:direct uses **Sign in with Apple** as the only auth path in v1 (personal/family use). The auth code is in place; enabling the capability is a one-time Xcode UI step that requires a configured Team.

## What's wired (no manual step needed)

- `AppleSignInCoordinator` (`re_direct/Identity/AppleSignInCoordinator.swift`) — drives the `ASAuthorizationController` flow and returns an `AppleSignInResult`.
- `AppleSignInPersister` (`re_direct/Identity/AppleSignInPersister.swift`) — writes the Apple `user` identifier to the Keychain (via `KeychainAppleIDStore`) and creates/updates a single `UserProfile` row in SwiftData with the user's display name.
- Onboarding's Apple `SocialButton` calls the coordinator → persister → sets `showDashboard = true` on success.
- Tests (`re_directTests/AppleSignInPersisterTests.swift`) verify the persistence logic against a stub Keychain and an in-memory SwiftData container.

## What you need to do once

In Xcode, open `re_direct.xcodeproj` and:

1. Select the **re_direct** target → **Signing & Capabilities** tab.
2. **Team**: choose your personal Apple ID team. (Required for any code-signed build, and for the capability below to be provisionable.)
3. Click **`+ Capability`** in the top-left of the same tab.
4. Pick **Sign in with Apple**. Xcode auto-generates a `re_direct.entitlements` file and references it from the target's build settings (`CODE_SIGN_ENTITLEMENTS`).
5. Build once (Cmd+B). The first build with the new capability triggers automatic provisioning profile generation.

After step 5, tapping the Apple button on the onboarding screen will present the real Sign in with Apple sheet on a physical device or signed simulator.

## What happens without those steps

- Build still succeeds (we don't add the capability ourselves).
- Tapping the Apple button calls `ASAuthorizationController.performRequests()`, which fails with `ASAuthorizationError.unknown` (or `errSecMissingEntitlement -7026` on some OS versions).
- `AppleSignInCoordinator` maps that to `AppleSignInError.missingEntitlement` (or `.unknown`).
- `OnboardingView`'s catch block silently swallows the failure (DEBUG-only log). The user stays on the onboarding screen.
- The existing "sign up" / "log in" pill buttons continue to bypass auth entirely (they set `showDashboard = true` directly). This preserves the local-only/anonymous development flow.

## Side effects once enabled

- The `KeychainAppleIDStore` test suite (`re_directTests/KeychainAppleIDStoreTests.swift`) currently auto-skips under `CODE_SIGNING_ALLOWED=NO`. Once a Team is set and code signing runs, those 5 tests start running automatically.
- The first sign-in for a given Apple ID returns `credential.fullName` populated; returning sign-ins return `nil`. `AppleSignInPersister` only writes the display name when it's non-empty, preserving the prior value otherwise.

## What's intentionally NOT in this slice

- The existing **sign up** / **log in** pill buttons in onboarding still route via `showDashboard = true` without invoking auth. Unifying them through Sign in with Apple is a separate slice (it would touch button copy and the onboarding flow architecture).
- No sign-out flow.
- No "delete account" path.
- No backend account — the Apple user identifier lives only in the device Keychain and the single local `UserProfile` row.
