# Agent Handoff

Use this as the first read for any new chat picking up re:direct work. Pair it with `docs/ROADMAP.md` for the full architecture and slice history.

## Repo

- GitHub: <https://github.com/nadineaisyahpm/re-direct>
- Local root: `/Users/mac/Desktop/re_direct`
- App folder: `re_direct/`
- Default branch: `main`
- **First step every session:** `git status --short`

## Read first

- `README.md`
- `re_direct/CLAUDE.md`
- `docs/ROADMAP.md`
- `docs/GIT_WORKFLOW.md`
- `docs/SLICE_E1_ENGAGEMENT.md`
- `docs/AUTH_SETUP.md`

## Core concept

re:direct helps people set gentle boundaries around distracting apps and redirect attention toward intentional curiosity rituals instead of passive doomscrolling.

## Surface architecture (load-bearing)

- **Dashboard** discovers curiosity.
- **Timer** commits to a boundary and a redirect method/category.
- **re:tuals** remembers per-method ritual history (read-only).
- **Re:Log** summarizes across topics, methods, sessions, and reflections.
- **Settings** is a read-only dossier of device-local state (no toggles in S1).

## Semantic rules — never cross these

- `TimerSession` is **boundary telemetry**, not a rabbit hole.
- `CuriosityEngagement` is the **rabbit hole / user-declared content engagement** record.
- Timer chooses the method (single-select).
- re:tuals never chooses a method. No `continue this lane` or any replacement selection CTA.
- Re:Log summarizes.
- `start boundary` **arms** a boundary. It does not start counting app usage immediately. In the future, usage will count only while the tracked app is in use.
- Completion is **system-driven** (DeviceActivity threshold / local-fallback countdown). `finishSession()` exists in source as the reserved path; it is not exposed in UI.
- Manual user end action is `stop early`.
- TimerView must not become a generic stopwatch / countdown timer.

## Design language

Modern editorial, warm paper texture, subtle iOS liquid glass, tactile, cinematic, reflective, minimal but alive. Instrument Serif for editorial titles and numerics; system sans for controls/data/status. Palette: warm cream, off-white, taupe, dusty rose, soft grey, deep teal, dark slate.

Avoid: neon, futuristic glassmorphism, generic dashboard/settings UI, heavy glow, clutter, broad redesigns.

## Current implementation state

Shipped (in `origin/main`):
- v0.1.0 SwiftUI prototype.
- Local-first SwiftData foundation; seed importer wired at launch.
- AI proxy contract + types (no runtime client yet).
- Apple Sign-In coordinator + Keychain store (entitlement step deferred to Slice 7.1).
- Swift Testing target.
- `CuriosityEngagement` model registered.
- Re:Log "+ log a rabbit hole" sheet creates rows.
- Dashboard Re:Log widget counts `CuriosityEngagement` rows.
- Re:Log full screen has Recent Rabbit Holes section + Boundary Sessions section.
- re:tuals cards are method lanes with tap-to-flip; back face shows recent engagement rows filtered by `methodSlug`.
- re:tuals flip motion polish C.1 + C.2.
- `choose this` retired after shared active method state landed.
- Shared active redirect method state (`ActiveMethodStore`).
- Timer method selection is single-select.
- Timer arms a boundary session and prevents duplicate active sessions.
- Timer active state has only `stop early`; manual `done` removed (reserved as system-driven).
- TimerSession lifecycle helpers (`status`, `isActive`, `isCompleted`, `isInterrupted`, `isDeleted`, `elapsedSeconds/Minutes`).
- **Settings S1 is shipped** — `SettingsView` is at tag 4 of `AppTabView`. Six read-only sections (Local data / Privacy / Seed content / Sign in with Apple / Screen Time / About). Paper-glass rows. `StatusChip` primitive in `DesignSystem.swift`. No destructive controls. Live `@Query` reads where wired; honest em-dash placeholders elsewhere.

## Privacy posture

Local-first. No backend, no runtime AI, no Screen Time / DeviceActivity, no notifications. Any remaining outbound traffic is legacy `picsum.photos` placeholder imagery. **No new data leaves the device without explicit approval.**

## Git workflow

- Local commits allowed under `docs/GIT_WORKFLOW.md`.
- Do **not** push unless explicitly instructed.
- `git status --short` before any work.
- Don't stage unrelated files. `.kiro/` is ignored and stays unstaged.
- Build/test after code changes.
- Simulator verification often needs a manual tap from the user — automated osascript clicks miss the small bottom-nav icons.

## Protected root view initializers

- `DashboardView()`
- `TimerView()`
- `RetualsView()`
- `ReLogView()`
- `AppTabView()`
- `SettingsView()`

## Do not

- Restructure navigation.
- Casually change root view initializers.
- Add backend / AI / Screen Time / notifications without explicit approval.
- Reintroduce re:tuals method selection.
- Treat `TimerSession` as a rabbit-hole count.
- Overbuild `TimerView` as a generic countdown timer.

## Likely next slices (proposed, not started)

- **Slice 7.1** — Apple Sign-In capability + end-to-end verification (manual Xcode UI step required).
- **Settings S2+** — toggles arrive only when backing behavior lands. No toggles until then.
- **Phase 6** — AI proxy implementation (Cloudflare Worker + iOS client).
- **Phase 7** — Screen Time / DeviceActivity research spike.

## First task in next chat

1. Run `git status --short`. Confirm repo is clean and in sync with `origin/main`.
2. Read the docs listed under "Read first".
3. Ask the user what to work on — or, if a Settings prototype was provided and Settings work still needs continuation, take direction from the user. (Settings S1 itself is already shipped, so the natural next move is either a follow-on polish, a backing-behavior slice that retires an S1 em-dash placeholder, or unrelated work like Slice 7.1.)
