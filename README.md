# re:direct

An editorial curiosity redirection app for iOS.

re:direct helps users set gentle boundaries around distracting apps, then redirects attention toward intentional curiosity rituals instead of passive doomscrolling.

## Product Concept

re:direct is built around a simple loop:

1. Discover curiosity on the Dashboard.
2. Set a usage boundary in Timer.
3. Choose what to return to in re:tuals.
4. Reflect afterward in Re:Log.

The app is currently a SwiftUI prototype focused on interaction language, visual direction, and product flow.

## Design Language

The core visual direction is:

**paper + glass**

The app should feel:

- editorial
- warm
- tactile
- cinematic
- reflective
- native iOS
- minimal but alive

Avoid:

- neon
- futuristic glassmorphism
- generic dashboard UI
- heavy glow
- excessive blur
- overanimated interactions

Typography:

- `InstrumentSerif-Italic` and `InstrumentSerif-Regular` for editorial titles, poetic labels, and expressive numbers.
- System sans-serif for controls, captions, utility labels, and data.

## Main Screens

### Dashboard

The home/discovery page. It includes the greeting, search bar, daily curiosity carousel, and a Re:Log preview widget.

### Timer

The setup page for app usage boundaries. It includes the duration picker, redirect method selector, tracked app selection, reminder theme grid, and preview affordance.

### re:tuals

The redirect ritual page. It answers: "What should I do instead?"

It includes a vertical looping swipe deck for saved rituals, tappable carousel dots, skip/choose/next controls, and a compact "when timer ends" payload preview.

### Re:Log

The reflection and analytics page. It includes Top 5 curiosity topics, tappable topic details, and a Screen Time recap.

## Project Structure

```text
re_direct/
  AppTabView.swift        # Main TabView and custom floating bottom nav
  DashboardView.swift     # Home/discovery screen
  TimerView.swift         # Timer setup screen
  RetualsView.swift       # re:tuals swipe deck screen
  ReLogView.swift         # Reflection/statistics screen
  ReDirectTopic.swift     # Shared hardcoded topic data
  DesignSystem.swift      # Shared colors, fonts, metrics, and UI helpers
  OnboardingView.swift    # Launch/onboarding flow
  re_directApp.swift      # App entry and font registration
  fonts/                  # Instrument Serif font files
  design_refs/            # Figma/reference exports
  Assets.xcassets/        # App assets and paper texture
```

## Design References

Design references live in:

```text
re_direct/design_refs/
```

Current references:

- `Dashboard.png`
- `Timer.png`
- `Re_Log.png`
- `Reminder.png`

These Figma exports are the primary visual source of truth for UI polish.

## Current Status

Prototype stage.

Implemented:

- Custom floating bottom nav
- Shared paper background and design tokens
- Dashboard discovery carousel
- Timer setup UI
- App selection/search prototype
- Theme selection grid
- re:tuals swipe deck
- Tappable re:tuals carousel indicators
- "When timer ends" preview card
- Re:Log topic expansion
- Screen Time recap

Not implemented yet:

- Real Screen Time API integration
- FamilyControls / DeviceActivity / ManagedSettings
- Reminder backend
- Notification scheduling
- Authentication
- Persistent user settings
- Real app usage tracking

## Setup

Open the Xcode project:

```text
re_direct.xcodeproj
```

Run the app from Xcode on an iPhone simulator.

Fonts are registered manually in `re_directApp.swift`:

- `InstrumentSerif-Regular.ttf`
- `InstrumentSerif-Italic.ttf`

## Agent Instructions

Coding and design agents should read `CLAUDE.md` before making changes.

Current project instruction file:

```text
re_direct/CLAUDE.md
```

Important rules:

- Study existing files before editing.
- Match the design language.
- Use Figma/reference exports as the visual source of truth.
- Keep changes surgical.
- Do not restructure navigation unless explicitly asked.
- Do not casually change root view initializers.
- Avoid force unwraps.
- Guard array indexing.
- Preserve `AsyncImage` fallback states.
- Build after changes.

## Future Technical Direction

Likely future integrations:

- Apple FamilyControls
- DeviceActivity
- ManagedSettings
- Local notifications or backend-triggered reminders
- Persistent ritual/timer/theme settings
- App Intents / Shortcuts

The current prototype keeps data hardcoded/local so product flow and design language can stabilize before backend and Screen Time API work begins.
