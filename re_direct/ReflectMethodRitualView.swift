import SwiftUI
import SwiftData

// ─────────────────────────────────────────────
// MARK: - Reflect-Method Ritual
// ─────────────────────────────────────────────

/// Full-screen writing surface for the Reflect-method ritual — REF2.
///
/// Presented as `.fullScreenCover` by the boundary/ritual flow when the active
/// redirect method is `reflect`. The writing *is* the ritual; saving non-empty
/// text dual-writes a `ReflectionEntry` and a `CuriosityEngagement(methodSlug:
/// "reflect")` linked to it. Dismiss/skip creates no rows.
///
/// Design reference: `REF2 Reflection Ritual _standalone_.html` — heading
/// cascade ("today, / write it out. / no rush — take all five."), highlighted
/// seeded prompt via `HighlighterText`, paper note with SF Pro 15pt input,
/// `{n} / ∞` counter, "local · not shared" mark, yellow underlined italic
/// save pill. See `docs/REFLECTION_ARCHITECTURE.md` §3.1 and §5.2.
struct ReflectMethodRitualView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<ReflectionPrompt> { $0.deletedAt == nil })
    private var prompts: [ReflectionPrompt]

    /// Optional active boundary session. Set when the ritual is launched from
    /// an armed boundary; nil if launched without one. Passed to both rows on
    /// save so future Re:Log surfaces can group reflections by session.
    let session: TimerSession?

    @State private var bodyText: String = ""
    @State private var selection: ReflectMethodRitualHelpers.Selection? = nil
    @State private var revealed = false

    private var trimmedCount: Int {
        bodyText.trimmingCharacters(in: .whitespacesAndNewlines).count
    }

    private var canSave: Bool { trimmedCount > 0 }

    private var promptBody: String {
        switch selection {
        case .seeded(let p):    return p.body
        case .fallback(let b):  return b
        case .none:             return ReflectMethodRitualHelpers.fallbackBody
        }
    }

    var body: some View {
        ZStack {
            PaperBackground(variant: .warm)
            RetualsGrain()
                .drawingGroup()
                .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    headingCascade
                        .padding(.top, 28)
                        .padding(.bottom, 22)

                    promptHighlight
                        .padding(.horizontal, 32)
                        .padding(.bottom, 22)

                    paperNote
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)

                    footerLine
                        .padding(.horizontal, 28)
                        .padding(.bottom, 24)

                    saveButton
                        .padding(.bottom, 36)
                }
                .frame(maxWidth: .infinity)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 10)
                .animation(.smooth.delay(0.04), value: revealed)
            }

            // Top-leading ✕ — paper-glass dismiss circle.
            VStack {
                HStack {
                    dismissCircle
                        .padding(.leading, 20)
                        .padding(.top, 18)
                    Spacer()
                }
                Spacer()
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            if selection == nil {
                selection = ReflectMethodRitualHelpers.choosePrompt(from: prompts)
            }
            withAnimation { revealed = true }
        }
    }

    // MARK: heading

    private var headingCascade: some View {
        VStack(spacing: 2) {
            Text("today,")
                .font(.custom("InstrumentSerif-Italic", size: 22))
                .foregroundColor(DSColor.ink.opacity(0.55))

            Text("write it out.")
                .font(.custom("InstrumentSerif-Italic", size: 38))
                .foregroundColor(DSColor.ink)

            Text("no rush — take all five.")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.62))
                .padding(.top, 6)
        }
    }

    // MARK: prompt

    private var promptHighlight: some View {
        // Marker-swipe yellow behind the seeded prompt — same vocabulary as
        // Dashboard's `HighlighterText`, but drawn per-line via a custom
        // `TextRenderer` so a two-line prompt gets two short swipes that hug
        // each line, not one big rectangular block. Flat fill, no border, no
        // shadow; the text is the object.
        Text(promptBody)
            .font(.custom("InstrumentSerif-Italic", size: 24))
            .foregroundColor(DSColor.inkSoft)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .lineSpacing(4)
            .textRenderer(LineHighlightRenderer(
                color: DSColor.highlightYellow.opacity(0.7)
            ))
            .frame(maxWidth: .infinity)
    }

    // MARK: paper note

    private var paperNote: some View {
        ZStack(alignment: .topLeading) {
            // Cream paper + ink hairline + 1.5/1.5 hard shadow + 14/22 soft.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(DSColor.paperCream)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: DSColor.ink.opacity(0.14),
                        radius: 0, x: 1.5, y: 1.5)
                .shadow(color: Color(red: 0.35, green: 0.25, blue: 0.22).opacity(0.08),
                        radius: 14, x: 0, y: 6)

            // SF Pro 15pt input per the Reflection Ritual ref. Italic
            // placeholder visible only while empty; ink caret.
            ZStack(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text("begin where you are.")
                        .font(.system(size: 15, weight: .regular).italic())
                        .foregroundColor(DSColor.ink.opacity(0.32))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $bodyText)
                    .font(.system(size: 15))
                    .foregroundColor(DSColor.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .tint(DSColor.ink)
            }
        }
        .frame(minHeight: 320)
    }

    // MARK: footer line — counter + local mark

    private var footerLine: some View {
        HStack(spacing: 8) {
            Text("\(trimmedCount) / ∞")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.45))
            Spacer()
            Text("local · not shared")
                .font(.system(size: 11, weight: .light).italic())
                .foregroundColor(DSColor.ink.opacity(0.45))
        }
    }

    // MARK: save

    private var saveButton: some View {
        Button {
            performSave()
        } label: {
            Text("save")
                .font(.custom("InstrumentSerif-Regular", size: 20))
                .underline()
                .foregroundColor(DSColor.ink.opacity(canSave ? 1.0 : 0.35))
                .padding(.horizontal, 26)
                .padding(.vertical, 10)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: canSave
                                    ? [DSColor.highlightYellow, DSColor.highlightYellowPaper]
                                    : [DSColor.paperCream, DSColor.paperCreamSoft],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            Capsule()
                                .stroke(DSColor.ink.opacity(canSave ? 0.34 : 0.18),
                                        lineWidth: 1)
                        }
                        .shadow(color: DSColor.ink.opacity(canSave ? 0.16 : 0.0),
                                radius: 0, x: 1.5, y: 1.5)
                }
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    // MARK: dismiss

    private var dismissCircle: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(DSColor.ink.opacity(0.70))
                .frame(width: 36, height: 36)
                .background {
                    Circle()
                        .fill(DSColor.paperCream)
                        .overlay {
                            Circle()
                                .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
                        }
                        .shadow(color: DSColor.ink.opacity(0.12),
                                radius: 0, x: 1, y: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss reflection")
    }

    // MARK: actions

    private func performSave() {
        let selectionForSave: ReflectMethodRitualHelpers.Selection =
            selection ?? .fallback(ReflectMethodRitualHelpers.fallbackBody)
        let result = ReflectMethodRitualHelpers.performSave(
            body: bodyText,
            prompt: selectionForSave,
            session: session,
            in: modelContext
        )
        if result != nil {
            dismiss()
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Per-line Highlight Renderer
// ─────────────────────────────────────────────

/// `TextRenderer` that draws a flat marker-yellow swipe behind each rendered
/// line of text, then draws the text on top. Used by `promptHighlight` so a
/// wrapped two-line prompt gets two short swipes hugging each line, instead
/// of a single rectangular block over the whole text frame.
private struct LineHighlightRenderer: TextRenderer {
    var color: Color
    var insetX: CGFloat = -6
    var insetY: CGFloat = -1

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            let rect = line.typographicBounds.rect.insetBy(dx: insetX, dy: insetY)
            context.fill(Path(rect), with: .color(color))
        }
        for line in layout {
            context.draw(line)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Pure Helpers (testable)
// ─────────────────────────────────────────────

/// Pure, testable helpers used by `ReflectMethodRitualView`. Lifted out so the
/// prompt-selection priority and the dual-write save logic can be exercised
/// in unit tests without instantiating the SwiftUI view.
enum ReflectMethodRitualHelpers {

    /// Hardcoded fallback prompt when no seeded reflection prompt exists.
    /// Quiet, gentle, no clinical framing — matches the editorial voice.
    static let fallbackBody = "take a minute. write down what's on your mind."

    /// What the writing surface ended up showing to the user.
    enum Selection: Equatable {
        case seeded(ReflectionPrompt)
        case fallback(String)

        static func == (lhs: Selection, rhs: Selection) -> Bool {
            switch (lhs, rhs) {
            case (.seeded(let a), .seeded(let b)):   return a.id == b.id
            case (.fallback(let a), .fallback(let b)): return a == b
            default: return false
            }
        }
    }

    /// Pick a prompt for the Reflect-method ritual.
    ///
    /// Priority:
    /// 1. Random `ReflectionPrompt` where `context == "reflect-method"` and
    ///    `deletedAt == nil`.
    /// 2. Random `ReflectionPrompt` where `context == nil` and
    ///    `deletedAt == nil` (untagged generals).
    /// 3. The hardcoded `fallbackBody` string.
    ///
    /// `pickIndex` lets tests pass a deterministic index function instead of
    /// relying on `randomElement()`. Default behavior uses `Int.random(in:)`.
    static func choosePrompt(
        from prompts: [ReflectionPrompt],
        pickIndex: (Int) -> Int = { count in Int.random(in: 0..<count) }
    ) -> Selection {
        let active = prompts.filter { $0.deletedAt == nil }

        let reflectMethod = active.filter { $0.context == "reflect-method" }
        if !reflectMethod.isEmpty {
            return .seeded(reflectMethod[pickIndex(reflectMethod.count)])
        }

        let untagged = active.filter { $0.context == nil }
        if !untagged.isEmpty {
            return .seeded(untagged[pickIndex(untagged.count)])
        }

        return .fallback(fallbackBody)
    }

    /// Dual-write the Reflect-method ritual save in a single `ModelContext`
    /// transaction. Returns the inserted rows on success, or `nil` if the
    /// trimmed body is empty (the surface must not call this on empty input,
    /// but the helper guards anyway).
    @discardableResult
    @MainActor
    static func performSave(
        body: String,
        prompt: Selection,
        session: TimerSession?,
        in context: ModelContext
    ) -> (entry: ReflectionEntry, engagement: CuriosityEngagement)? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let now = Date()

        let entry = ReflectionEntry()
        entry.body = trimmed
        entry.createdAt = now
        entry.updatedAt = now
        entry.session = session
        context.insert(entry)

        let engagement = CuriosityEngagement()
        engagement.methodSlug = "reflect"
        engagement.contentTitle = {
            switch prompt {
            case .seeded(let p):    return p.body
            case .fallback(let s):  return s
            }
        }()
        engagement.engagedAt = now
        engagement.session = session
        engagement.reflection = entry
        context.insert(engagement)

        try? context.save()
        return (entry, engagement)
    }
}
