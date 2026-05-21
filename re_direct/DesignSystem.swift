import SwiftUI

// ─────────────────────────────────────────────
// MARK: - Color Tokens
// ─────────────────────────────────────────────

enum DSColor {
    static let ink                  = Color(hex: "#1F1B18")
    static let inkSoft              = Color(hex: "#2C2825")
    static let paperCream           = Color(hex: "#FFFDF2")
    static let paperCreamSoft       = Color(hex: "#FFF8EC")
    static let highlightYellow      = Color(hex: "#F0E68C")
    static let highlightYellowSoft  = Color(hex: "#F2EFB8")
    static let highlightYellowPaper = Color(hex: "#F5EDD0")
}

// ─────────────────────────────────────────────
// MARK: - Font Tokens
// ─────────────────────────────────────────────

enum DSFont {
    static func pageTitle()      -> Font { .custom("InstrumentSerif-Italic", size: 38) }
    static func pageSubtitle()   -> Font { .system(size: 13, weight: .light) }
    static func sectionTitle()   -> Font { .custom("InstrumentSerif-Italic", size: 22) }
    static func sectionCaption() -> Font { .system(size: 11, weight: .light) }
    static func body()           -> Font { .system(size: 14) }
    static func label()          -> Font { .system(size: 12, weight: .medium) }
    static func editorialValue() -> Font { .custom("InstrumentSerif-Italic", size: 15) }
}

// ─────────────────────────────────────────────
// MARK: - Metric Tokens
// ─────────────────────────────────────────────

enum DSMetric {
    static let bottomNavClearance: CGFloat = 120
    static let pageHorizontal: CGFloat     = 24
    static let sectionRuleOpacity: Double  = 0.22
    static let hairlineOpacity: Double     = 0.38
}

// ─────────────────────────────────────────────
// MARK: - Paper Background
// ─────────────────────────────────────────────

struct PaperBackground: View {
    enum Variant { case cool, warm }
    let variant: Variant

    var body: some View {
        let stops: [Color] = (variant == .cool)
            ? [Color(hex: "#FCFAF5"), Color(hex: "#C2BBB1")]
            : [Color(hex: "#FAF6EF"), Color(hex: "#DAD2C7")]

        LinearGradient(colors: stops, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
            .overlay {
                Image("paper texture")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.06)
                    .blendMode(.multiply)
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
    }
}

// ─────────────────────────────────────────────
// MARK: - Section Header
// ─────────────────────────────────────────────

struct SectionHeader: View {
    let title: String
    let caption: String?
    var captionAlignment: Alignment = .trailing
    var numeral: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                if let n = numeral {
                    Text(n)
                        .font(.custom("InstrumentSerif-Italic", size: 13))
                        .foregroundColor(DSColor.ink.opacity(0.45))
                        .tracking(0.4)
                }
                Text(title)
                    .font(DSFont.sectionTitle())
                    .foregroundColor(DSColor.ink)
                if let c = caption {
                    Text(c)
                        .font(DSFont.sectionCaption())
                        .foregroundColor(DSColor.inkSoft.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: captionAlignment)
                        .lineSpacing(1.5)
                        .lineLimit(2)
                        .minimumScaleFactor(0.95)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Rectangle()
                .fill(DSColor.inkSoft.opacity(DSMetric.sectionRuleOpacity))
                .frame(height: 1)
                .padding(.top, 2)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Highlighter Text
// ─────────────────────────────────────────────

struct HighlighterText: View {
    let text: String
    var size: CGFloat = 38
    var color: Color = DSColor.highlightYellow.opacity(0.7)

    var body: some View {
        Text(text)
            .font(.custom("InstrumentSerif-Italic", size: size))
            .foregroundColor(DSColor.inkSoft)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
    }
}

// ─────────────────────────────────────────────
// MARK: - Chip Capsule
// ─────────────────────────────────────────────

struct ChipCapsule: View {
    enum Variant {
        case light
        case filled(Color)
        case dark
    }

    let text: String
    var variant: Variant = .light

    var body: some View {
        let (bg, fg): (Color, Color) = {
            switch variant {
            case .light:         return (Color.white.opacity(0.80), DSColor.ink.opacity(0.75))
            case .filled(let c): return (c, DSColor.ink)
            case .dark:          return (DSColor.ink, .white.opacity(0.9))
            }
        }()

        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(fg)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(bg)
                    .overlay {
                        Capsule()
                            .stroke(DSColor.inkSoft.opacity(0.08), lineWidth: 1)
                    }
            }
    }
}

// ─────────────────────────────────────────────
// MARK: - Status Chip
// ─────────────────────────────────────────────

/// Small read-only status pill for `SettingsView` rows. Five variants
/// share the same paper-card shape, 1px ink hairline, and 1.5/1.5 hard
/// shadow used by other paper objects in the design system. A 6pt dot
/// prefix appears for `.positive` to read as a status light.
struct StatusChip: View {
    enum Variant {
        case paper       // cream, default — neutral status
        case positive    // faint teal with leading dot — "ready" / "none"
        case muted       // low-opacity ink — "off"
        case pending     // dusty rose tint — capability not yet enabled
        case highlight   // #F2EFB8 — reserved for current slice marker
    }

    let text: String
    var variant: Variant = .paper

    private var palette: (bg: Color, fg: Color, stroke: Color, dot: Color?) {
        switch variant {
        case .paper:
            return (DSColor.paperCream, DSColor.ink.opacity(0.78),
                    DSColor.ink.opacity(0.32), nil)
        case .positive:
            return (Color(hex: "#E4EEEA"), DSColor.ink.opacity(0.78),
                    DSColor.ink.opacity(0.28), Color(hex: "#1B4D4A"))
        case .muted:
            return (DSColor.paperCream.opacity(0.45), DSColor.ink.opacity(0.45),
                    DSColor.ink.opacity(0.22), nil)
        case .pending:
            return (Color(hex: "#F4E2DC"), DSColor.ink.opacity(0.72),
                    DSColor.ink.opacity(0.28), nil)
        case .highlight:
            return (DSColor.highlightYellowSoft, DSColor.ink,
                    DSColor.ink.opacity(0.34), nil)
        }
    }

    var body: some View {
        let p = palette
        HStack(spacing: 5) {
            if let dot = p.dot {
                Circle()
                    .fill(dot)
                    .frame(width: 6, height: 6)
            }
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(p.fg)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule()
                .fill(p.bg)
                .overlay {
                    Capsule()
                        .stroke(p.stroke, lineWidth: 1)
                }
                .shadow(color: DSColor.ink.opacity(0.14),
                        radius: 0, x: 1.5, y: 1.5)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Ink Card Modifier
// ─────────────────────────────────────────────

extension View {
    func inkCard(cornerRadius: CGFloat = 18) -> some View {
        self
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DSColor.ink.opacity(DSMetric.hairlineOpacity), lineWidth: 1)
            }
            .shadow(color: DSColor.ink.opacity(0.14), radius: 0, x: 1.5, y: 1.5)
            .shadow(color: Color(red: 0.35, green: 0.25, blue: 0.22).opacity(0.08),
                    radius: 14, x: 0, y: 6)
    }
}

// ─────────────────────────────────────────────
// MARK: - Paper Search Bar
// ─────────────────────────────────────────────

struct PaperSearchBar: View {
    let placeholder: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding?
    var rotatingPlaceholders: [String]? = nil
    var rotationInterval: TimeInterval = 6

    @State private var placeholderIndex: Int = 0

    private var currentPlaceholder: String {
        if let placeholders = rotatingPlaceholders {
            return placeholders[placeholderIndex % placeholders.count]
        }
        return placeholder
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(DSColor.inkSoft.opacity(0.5))

            if let focusBinding = focused {
                TextField(currentPlaceholder, text: $text)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(DSColor.inkSoft.opacity(0.75))
                    .focused(focusBinding)
                    .submitLabel(.done)
            } else {
                Text(currentPlaceholder)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(DSColor.inkSoft.opacity(0.45))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .id(placeholderIndex)
                    .transition(.opacity)
                    .animation(.smooth, value: placeholderIndex)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.white.opacity(0.35))
                )
        )
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(DSColor.ink.opacity(0.38), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .onAppear {
            if rotatingPlaceholders != nil {
                Timer.scheduledTimer(withTimeInterval: rotationInterval, repeats: true) { _ in
                    withAnimation(.smooth) {
                        placeholderIndex += 1
                    }
                }
            }
        }
    }
}

