import SwiftUI

// ─────────────────────────────────────────────
// MARK: - Rabbit Hole View (RH3-B shell)
// ─────────────────────────────────────────────

/// Tab-1 surface as of RH3-B. Replaces the v0.1 Timer occupant of the
/// primary tab bar slot. This slice ships an **inert shell only** — no
/// `@Query`, no thread data, no preview sheet, no method chip. The screen
/// always renders the empty state from `docs/RH3 extraction.html`.
///
/// What lands later:
/// - RH3-C: `@Query` for `RabbitHoleThread` + `CuriosityEngagement`,
///   today card, your-threads list, loose ends, `ThreadPreviewSheet`.
/// - RH3-D: wires the `+ new thread` capsule to a creation flow.
/// - RH3-E: wires the loose-end "thread?" pill to attach engagements.
///
/// Invariants honored:
/// - `TimerSession` model + `TimerView` source remain in the codebase;
///   only the tab-bar occupant changes. See `docs/AGENT_HANDOFF.md`.
/// - No reflection body display, ever. Trivially upheld here — there is
///   no engagement display on this surface in RH3-B.
/// - Protected root view initializer.
struct RabbitHoleView: View {

    /// Reveal flag mirrors the `ReLogView` / `RetualsView` pattern so future
    /// stagger animations in RH3-C can layer in without churning this file.
    @State private var revealed: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {

                PaperBackground(variant: .warm)

                ReLogGrain()
                    .drawingGroup()
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    // Page title — same shape as Re:Log's "Re:Log" title.
                    Text("rabbit hole")
                        .font(.custom("InstrumentSerif-Italic", size: 38))
                        .foregroundColor(DSColor.ink)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, geo.safeAreaInsets.top + 10)
                        .padding(.bottom, 16)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 10)
                        .animation(.smooth.delay(0.05), value: revealed)

                    // Right-aligned "+ new thread" capsule — INERT in RH3-B.
                    // Wired to a creation flow in RH3-D. Styled identically
                    // to ReLogView's "log a rabbit hole" capsule.
                    HStack {
                        Spacer()
                        NewThreadCapsuleStub()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
                    .opacity(revealed ? 1 : 0)
                    .offset(y: revealed ? 0 : 6)
                    .animation(.smooth.delay(0.10), value: revealed)

                    // Empty state — always rendered in RH3-B. RH3-C will
                    // gate this on `threads.isEmpty && looseEnds.isEmpty`.
                    Spacer(minLength: 0)
                    EmptyStateBlock()
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 8)
                        .animation(.smooth.delay(0.18), value: revealed)
                    Spacer(minLength: 0)

                    Spacer().frame(height: DSMetric.bottomNavClearance)
                }
            }
            .ignoresSafeArea()
            .onAppear { revealed = true }
        }
        .preferredColorScheme(.light)
    }
}

// ─────────────────────────────────────────────
// MARK: - + new thread capsule (stub)
// ─────────────────────────────────────────────

/// Visual twin of `ReLogView`'s "log a rabbit hole" capsule. **Inert** in
/// RH3-B: tap produces no state change. Wired in RH3-D when thread creation
/// ships. Kept as a real `Button` (not a static label) so the tap target,
/// hit area, and accessibility role match the eventual wired version —
/// only the `action` becomes meaningful later.
private struct NewThreadCapsuleStub: View {
    var body: some View {
        Button {
            // Intentionally empty. RH3-D wires creation flow.
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .regular))
                Text("new thread")
                    .font(.custom("InstrumentSerif-Italic", size: 15))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundColor(DSColor.ink)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .fill(Color.white.opacity(0.45))
                    }
                    .overlay {
                        Capsule()
                            .stroke(DSColor.ink.opacity(0.30), lineWidth: 1)
                    }
                    .shadow(color: DSColor.ink.opacity(0.10),
                            radius: 0, x: 1, y: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New thread")
        .accessibilityHint("Coming soon")
    }
}

// ─────────────────────────────────────────────
// MARK: - Empty state
// ─────────────────────────────────────────────

/// Pure layout — no state, no data. RH3-C will gate this on query results;
/// for now it is the entire visible surface.
private struct EmptyStateBlock: View {
    var body: some View {
        VStack(spacing: 14) {

            // Quiet icon disc — matches the paper-cream + ink-stroke
            // language used elsewhere in the design system.
            ZStack {
                Circle()
                    .fill(DSColor.paperCream)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Circle()
                            .stroke(DSColor.ink.opacity(0.30), lineWidth: 1)
                    }
                    .shadow(color: DSColor.ink.opacity(0.10),
                            radius: 0, x: 1, y: 1)

                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(DSColor.ink.opacity(0.55))
            }

            Text(RabbitHoleEmptyCopy.headline)
                .font(.custom("InstrumentSerif-Italic", size: 22))
                .foregroundColor(DSColor.ink)
                .multilineTextAlignment(.center)

            Text(RabbitHoleEmptyCopy.sub)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(DSColor.inkSoft.opacity(0.55))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 260)
                .padding(.top, 2)

            // Quiet CTA stub — inert in RH3-B. Wired in RH3-D alongside
            // the top-right capsule.
            Button {
                // Intentionally empty.
            } label: {
                Text(RabbitHoleEmptyCopy.cta)
                    .font(.custom("InstrumentSerif-Italic", size: 14))
                    .foregroundColor(DSColor.ink.opacity(0.85))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay {
                                Capsule()
                                    .fill(Color.white.opacity(0.40))
                            }
                            .overlay {
                                Capsule()
                                    .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
                            }
                            .shadow(color: DSColor.ink.opacity(0.08),
                                    radius: 0, x: 1, y: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .accessibilityHint("Coming soon")
        }
        .padding(.horizontal, 28)
    }
}

// ─────────────────────────────────────────────
// MARK: - Copy (pure, testable)
// ─────────────────────────────────────────────

/// Empty-state copy strings, extracted so the test suite can pin them and
/// future copy edits don't require view-tree inspection. Matches the
/// design extraction in `docs/RH3 extraction.html`.
enum RabbitHoleEmptyCopy {
    static let headline = "no threads yet."
    static let sub      = "a thread starts with a rabbit hole you've already logged."
    static let cta      = "start your first thread"
}

// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    RabbitHoleView()
        .environment(ActiveMethodStore())
}
