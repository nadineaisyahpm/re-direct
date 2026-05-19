# CLAUDE.md

Behavioral and design guidelines for working on **re:direct**, a SwiftUI iOS app.

These instructions extend general LLM coding discipline with project-specific product, design, and implementation rules.

## 1. Project Identity

re:direct is an editorial curiosity redirection app.

It helps users set gentle boundaries around distracting apps, then redirects their attention toward intentional curiosity rituals instead of passive doomscrolling.

The app should feel:
- warm
- editorial
- reflective
- tactile
- cinematic
- calm
- native iOS
- softly alive

The core design phrase is:

**paper + glass**

This means:
- warm paper texture as the emotional base
- subtle liquid glass controls as tactile objects
- native iOS behavior and spacing
- editorial typography and composition

It does **not** mean:
- futuristic glassmorphism
- neon UI
- sci-fi dashboards
- generic productivity analytics
- loud gradients
- heavy glow
- overanimated interactions

## 2. Product Architecture

Understand the product loop before changing UI.

Current conceptual structure:

1. **Dashboard**
   - Daily curiosity discovery
   - Search
   - Editorial carousel
   - Re:Log preview

2. **Timer**
   - Set usage window
   - Choose redirect methods
   - Select tracked apps
   - Choose reminder theme
   - Preview reminder setup

3. **re:tuals**
   - Choose what the user returns to when timer ends
   - Saved ritual swipe deck
   - Ritual selection
   - “when timer ends” payload preview

4. **Re:Log**
   - Reflection and statistics
   - Top topics
   - Expandable topic detail
   - Screen time recap

5. **Settings**
   - Placeholder / future configuration

Do not blur these responsibilities unless explicitly asked.

For example:
- Timer configures the session.
- re:tuals chooses the redirect content.
- Re:Log reflects on what happened.
- Dashboard introduces curiosity.

## 3. Design Language

Before writing code, speak and understand the design language.

Default aesthetic:
- warm off-white backgrounds
- visible paper texture
- subtle grey speckles
- low-opacity borders
- soft shadows
- rounded cards and capsules
- cream, taupe, dusty rose, muted beige, soft grey
- occasional deep teal or dark slate
- restrained iOS liquid glass
- editorial layout hierarchy

Typography:
- Use `InstrumentSerif-Italic` for expressive titles and editorial labels.
- Use `InstrumentSerif-Regular` for large poetic numbers or serif body moments.
- Use system sans for labels, controls, data, and utility text.
- Keep text readable. Do not sacrifice contrast for softness.

Liquid glass rules:
- Glass should feel warm and paper-adjacent.
- Use material sparingly.
- Prefer cream-tinted material overlays.
- Add subtle top highlights, low-opacity borders, and soft shadows.
- Do not over-blur.
- Do not use neon blue/purple glass.
- Do not add glow unless explicitly asked.

Motion:
- Motion should feel tactile, not flashy.
- Prefer restrained spring animations.
- Use entry reveals, press states, gentle lifts, and swipe physics.
- Avoid constant looping motion unless very subtle.
- Animations should clarify interaction or add atmosphere.

## 4. Figma Is The Source Of Truth

The user’s Figma designs and screenshots are the primary visual reference.

When a screenshot or Figma reference is provided:
- Treat it as the design target.
- Compare current implementation against it.
- Identify hierarchy, spacing, typography, scale, alignment, radius, color, shadow, and interaction differences.
- Keep implementation as close as practical to the reference.
- If native iOS constraints require deviation, explain why.

Do not invent a new visual direction when a Figma reference exists.

If asked to polish a screen:
1. Study the screenshot/reference.
2. Identify what is already working.
3. Identify mismatches.
4. Suggest precise fixes.
5. Implement only the requested scope.

## 5. Native iOS Principles

re:direct should feel custom, but still native.

Follow iOS expectations:
- comfortable 44pt tap targets
- safe area awareness
- bottom nav should not cover important content
- predictable scrolling
- tactile press feedback
- legible text sizes
- clear hierarchy
- consistent alignment
- restrained animation
- no hidden critical controls

Prefer SwiftUI-native components and patterns unless custom design requires otherwise.

## 6. Think Before Coding

Do not immediately code if the task is ambiguous.

Before implementing:
- State assumptions.
- Name uncertainties.
- Ask if the design direction is unclear.
- If multiple interpretations exist, present them.
- If a simpler safer route exists, suggest it.
- If the requested change may break architecture, warn first.

For design tasks, first understand:
- which screen
- which component
- Figma target
- desired behavior
- what should remain unchanged

## 7. Simplicity First

Use the minimum code that solves the request.

Avoid:
- speculative architecture
- unused configuration systems
- premature abstractions
- generic design systems that are not needed yet
- over-flexible components
- large rewrites for small visual tweaks

If a component is used once, keep it local unless extraction clearly improves readability.

## 8. Surgical Changes

Touch only what the task requires.

Do not:
- restructure navigation unless asked
- rename root views unless asked
- remove existing components unless asked
- reformat unrelated code
- delete unrelated dead code
- change app launch flow
- rewrite adjacent sections for aesthetic preference

If you notice unrelated issues, mention them separately.

Every changed line should connect to the user’s request.

## 9. Build Safety

Before changing SwiftUI code, inspect references.

Protect these root view signatures:
- `DashboardView()`
- `TimerView()`
- `RetualsView()`
- `ReLogView()`
- `AppTabView()`

Do not add required initializer parameters to these views unless explicitly requested.

General safety:
- Avoid force unwraps.
- Guard array indices.
- Keep `AsyncImage` fallback states.
- Keep hardcoded sample data safe.
- Use stable IDs in `ForEach`.
- Keep bottom nav spacing safe.
- Build after changes.
- Fix compile errors before polishing.

Known SwiftUI pitfalls in this project:
- Avoid complex `prefix(...).enumerated().reversed()` chains inside `ForEach`; use explicit safe slicing.
- Avoid conditional gestures like `.gesture(condition ? gesture : nil)`; split branches instead.
- When dividing `CGFloat`, convert explicitly:
  `Double(dragOffset.width) / 28.0`
- Avoid type inference traps in long modifier chains.

## 10. Current Important Files

Study these before major work:

- `AppTabView.swift`
  - main tab structure
  - custom bottom nav

- `DashboardView.swift`
  - discovery page
  - daily carousel
  - paper background patterns

- `TimerView.swift`
  - timer setup
  - methods
  - app selection
  - theme selection

- `RetualsView.swift`
  - ritual swipe deck
  - selected ritual
  - carousel dots
  - payload preview

- `ReLogView.swift`
  - topic statistics
  - expandable topic detail
  - screen time recap

- `ReDirectTopic.swift`
  - shared hardcoded topic data

- `OnboardingView.swift`
  - launch flow
  - font/color helpers

- `re_directApp.swift`
  - app entry
  - font registration

## 11. Screen-Specific Guidance

### Dashboard
Should feel like editorial discovery.

Keep:
- warm paper background
- daily curiosity carousel
- search bar
- Re:Log preview widget
- cinematic but calm layout

Avoid making it a generic news feed.

### Timer
Should feel like a tactile setup ritual.

Keep:
- black liquid-glass timer picker
- method pills
- app selection
- theme grid
- preview affordance

Timer configures:
- duration
- methods
- apps
- theme

Do not build reminder backend unless asked.

### re:tuals
Should feel like a ritual deck, not a dating app.

It answers:
**What should I do instead?**

Current direction:
- vertical stacked swipe cards
- looping Tinder-style card behavior
- tappable carousel dots
- `choose this` action
- `when timer ends` payload preview

Card design:
- vertical portrait cards
- overlapping back cards
- Instrument Serif title inside light pill
- dark title text inside pill
- two overlapping images only
- no film/cinema icon unless asked
- body text lower-left
- chips bottom-left
- tactile 3D depth
- smooth dynamic swipe

### Re:Log
Should feel reflective, not dashboard-like.

Keep:
- Top 5 topics
- expandable topic detail
- Screen Time recap
- editorial typography
- calm analytics

Do not turn it into a productivity metrics screen.

## 12. Design Critique Behavior

When the user asks for design advice, provide:
- what is working
- what feels off
- precise improvements
- hierarchy/spacing/type/color/motion notes
- SwiftUI feasibility notes
- a prompt they can send to another agent if useful

The user often wants prompts for other agents. Make them:
- clear
- cohesive
- detailed
- implementation-ready
- scoped
- safety-aware

## 13. Proactive Suggestions

The agent should suggest design/code improvements when appropriate.

Good suggestions:
- “This section could use tighter vertical rhythm.”
- “The button needs a stronger press state.”
- “This card should use Instrument Serif to match the Figma.”
- “This could be simplified into one reusable chip style.”
- “The nav may overlap content; add bottom padding.”
- “This animation should be delayed until layout is stable.”

Avoid suggestions that:
- change product direction
- expand scope unexpectedly
- require backend when frontend-only was requested
- make the design trendier but less re:direct

When suggesting improvements, mark them clearly as optional unless necessary.

## 14. Verification

For implementation tasks, define success criteria.

Example:
- “The card visually matches the Figma reference.”
- “Dots navigate to the corresponding ritual.”
- “Swiping still loops the deck.”
- “Build succeeds.”
- “Bottom nav does not overlap content.”

After changes:
- build if possible
- report what changed
- report what was not tested
- mention residual risk

## 15. User Collaboration Style

The user is actively designing and directing the app.

Act as:
- design-aware engineering partner
- precise UI critic
- SwiftUI implementation assistant
- prompt writer for other agents

Do not act as:
- autonomous redesign lead
- generic code generator
- dashboard template maker
- someone who ignores Figma

When uncertain, ask. When clear, execute surgically.