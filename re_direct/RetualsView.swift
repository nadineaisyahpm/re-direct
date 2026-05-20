import SwiftUI
import SwiftData

// ─────────────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────────────

enum RedirectRitualType: String, CaseIterable, Identifiable {
    case read     = "Read"
    case watch    = "Watch"
    case miniGame = "Mini Game"
    case reflect  = "Reflect"
    case deepDive = "Deep Dive"
    var id: String { rawValue }
}

struct RedirectRitual: Identifiable, Hashable {
    let id: String
    let label: String
    let title: String
    let description: String
    let type: RedirectRitualType
    let estimatedMinutes: Int
    let mood: String
    let cardHex: String
    let accentHex: String
    let thumbnailSeeds: [String]

    // Each entry represents a redirect method lane, identified by its
    // canonical slug. The local enum names (RedirectRitual / RedirectRitualType)
    // predate the corrected re:tuals semantics — they stay for now because
    // renaming would ripple beyond this slice. A future flip-flow slice can
    // align the types.
    static let samples: [RedirectRitual] = [
        RedirectRitual(
            id: "watch",
            label: "Watch",
            title: "Watch",
            description: "Longer videos you actually finish.",
            type: .watch,
            estimatedMinutes: 12,
            mood: "curious",
            cardHex: "#B8A8B0",
            accentHex: "#8A7A82",
            thumbnailSeeds: ["capitol","film"]
        ),
        RedirectRitual(
            id: "read",
            label: "Read",
            title: "Read",
            description: "One article, intentionally chosen.",
            type: .read,
            estimatedMinutes: 7,
            mood: "calm",
            cardHex: "#1B4D4A",
            accentHex: "#2A6A66",
            thumbnailSeeds: ["library","desert"]
        ),
        RedirectRitual(
            id: "mini-game",
            label: "Mini Game",
            title: "Mini Game",
            description: "A three-minute puzzle to reset attention.",
            type: .miniGame,
            estimatedMinutes: 3,
            mood: "focused",
            cardHex: "#C8B898",
            accentHex: "#A89878",
            thumbnailSeeds: ["puzzle","geometry"]
        ),
        RedirectRitual(
            id: "deep-dive",
            label: "Deep Dive",
            title: "Deep Dive",
            description: "Pick up a thread you already started.",
            type: .deepDive,
            estimatedMinutes: 20,
            mood: "immersive",
            cardHex: "#2C2F3A",
            accentHex: "#4A4D5A",
            thumbnailSeeds: ["cosmos","ocean"]
        ),
        RedirectRitual(
            id: "reflect",
            label: "Reflect",
            title: "Reflect",
            description: "Two minutes, one question, no algorithm.",
            type: .reflect,
            estimatedMinutes: 2,
            mood: "still",
            cardHex: "#D4C4B8",
            accentHex: "#B8A898",
            thumbnailSeeds: ["journal","candle"]
        ),
    ]
}

// ─────────────────────────────────────────────
// MARK: - Re:tuals View
// ─────────────────────────────────────────────

struct RetualsView: View {

    @State private var rituals: [RedirectRitual]    = RedirectRitual.samples
    @State private var selectedRitual: RedirectRitual? = RedirectRitual.samples.first
    @State private var dragOffset: CGSize           = .zero
    @State private var isAnimatingOut               = false
    @State private var isFlipped                    = false

    private let swipeThreshold: CGFloat = 90

    private var activeRitualIndex: Int {
        guard let first = rituals.first else { return 0 }
        return RedirectRitual.samples.firstIndex(where: { $0.id == first.id }) ?? 0
    }

    private func bringRitualToFront(_ index: Int) {
        guard RedirectRitual.samples.indices.contains(index) else { return }
        isFlipped = false
        let samples = RedirectRitual.samples
        let reordered = Array(samples[index...]) + Array(samples[..<index])
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            rituals = reordered
            dragOffset = .zero
        }
    }

    private func sendTopCardToBack(direction: CGFloat) {
        guard !rituals.isEmpty else { return }
        isFlipped = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            dragOffset = CGSize(width: direction * 600, height: 40)
            isAnimatingOut = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            if let first = rituals.first {
                rituals.removeFirst()
                rituals.append(first)
            }
            dragOffset = .zero
            isAnimatingOut = false
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {

                PaperBackground(variant: .cool)

                RetualsGrain()
                    .drawingGroup()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {

                        VStack(spacing: 6) {
                            Text("Re:Tuals")
                                .font(DSFont.pageTitle())
                                .foregroundColor(DSColor.ink)

                            Text("customize how we redirect your brain's algorithm.")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(DSColor.inkSoft.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .lineSpacing(1)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, geo.safeAreaInsets.top + 14)
                        .padding(.bottom, 24)
                        .padding(.horizontal, 24)

                        RitualDeck(
                            rituals: $rituals,
                            dragOffset: $dragOffset,
                            isAnimatingOut: $isAnimatingOut,
                            isFlipped: $isFlipped,
                            swipeThreshold: swipeThreshold,
                            onSwipe: sendTopCardToBack
                        )
                        .frame(height: 470)

                        DeckPagination(
                            count: RedirectRitual.samples.count,
                            activeIndex: activeRitualIndex,
                            onSelect: bringRitualToFront
                        )
                        .padding(.bottom, 20)
                        .sensoryFeedback(.selection, trigger: activeRitualIndex)

                        DeckControls(
                            onShuffle: { sendTopCardToBack(direction: -1) },
                            onChoose: {
                                isFlipped = false
                                if let top = rituals.first {
                                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                                        selectedRitual = top
                                    }
                                }
                            },
                            onNext: { sendTopCardToBack(direction: 1) }
                        )
                        .padding(.top, 12)
                        .padding(.horizontal, 20)

                        WhenTimerEndsCard(selectedRitual: selectedRitual)
                            .padding(.horizontal, 20)
                            .padding(.top, 42)

                        Spacer().frame(height: DSMetric.bottomNavClearance)
                    }
                }
            }
            .ignoresSafeArea()
            .onChange(of: rituals.first?.id) { _, _ in
                selectedRitual = rituals.first
            }
        }
        .preferredColorScheme(.light)
    }
}

// ─────────────────────────────────────────────
// MARK: - Today's Redirect Card
// ─────────────────────────────────────────────

struct TodaysRedirectCard: View {
    let ritual: RedirectRitual?

    var body: some View {
        let r = ritual ?? RedirectRitual.samples[0]

        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {

                Text("today's redirect")
                    .font(.custom("InstrumentSerif-Italic", size: 12))
                    .foregroundColor(Color(hex: "#2C2825").opacity(0.45))

                Text("after TikTok")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(Color(hex: "#2C2825").opacity(0.4))

                Text(r.title)
                    .font(.custom("InstrumentSerif-Italic", size: 18))
                    .foregroundColor(Color(hex: "#1F1B18"))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    RitualChip(text: r.type.rawValue.lowercased())
                    RitualChip(text: "\(r.estimatedMinutes) min")
                    RitualChip(text: r.mood)
                }
            }

            Spacer()

            VStack(spacing: 8) {
                AsyncImage(url: URL(string: "https://picsum.photos/seed/\(r.thumbnailSeeds.first ?? "calm")/80/80")) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    default: Circle().fill(Color(hex: "#C8C2BA").opacity(0.4))
                    }
                }
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.6), lineWidth: 1.5))

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(Color(hex: "#2C2825").opacity(0.5))
                    .frame(width: 30, height: 30)
                    .background(Color(hex: "#2C2825").opacity(0.06))
                    .clipShape(Circle())
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(hex: "#FFF8EC").opacity(0.45))
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 18)
                        .blur(radius: 8)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "#2C2825").opacity(0.09), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        .animation(.spring(duration: 0.35, bounce: 0.15), value: r.id)
    }
}

// ─────────────────────────────────────────────
// MARK: - Ritual Chip
// ─────────────────────────────────────────────

struct RitualChip: View {
    let text: String
    var dark: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(hex: "#1F1B18").opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.80))
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(Color.white.opacity(0.35))
                            .frame(height: 8)
                            .blur(radius: 4)
                    }
                    .overlay {
                        Capsule().stroke(Color(hex: "#2C2825").opacity(0.08), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
    }
}

// ─────────────────────────────────────────────
// MARK: - Ritual Deck
// ─────────────────────────────────────────────

struct RitualDeck: View {
    @Binding var rituals: [RedirectRitual]
    @Binding var dragOffset: CGSize
    @Binding var isAnimatingOut: Bool
    @Binding var isFlipped: Bool
    let swipeThreshold: CGFloat
    let onSwipe: (CGFloat) -> Void

    @State private var isDragging = false

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.86)) {
                    dragOffset = value.translation
                }
            }
            .onEnded { value in
                isDragging = false
                if abs(value.translation.width) > swipeThreshold {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                        dragOffset = CGSize(width: value.translation.width > 0 ? 520 : -520, height: 20)
                    }
                    onSwipe(value.translation.width > 0 ? 1 : -1)
                } else {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.84)) {
                        dragOffset = .zero
                    }
                }
            }
    }

    var body: some View {
        let dragProgress = min(abs(dragOffset.width) / 180.0, 1.0)
        let dynamicScale = 1.0 + dragProgress * 0.018
        let lift         = dragProgress * -8.0
        let dynamicShadowOpacity = 0.16 + dragProgress * 0.10
        let dynamicShadowRadius  = 20.0 + dragProgress * 10.0
        let dynamicShadowY       = 10.0 + dragProgress * 8.0

        ZStack {
            let visibleCount = Swift.min(3, rituals.count)
            let visibleRituals: [RedirectRitual] = Array(rituals[..<visibleCount])
            let indexedRituals = Array(visibleRituals.enumerated()).reversed()

            ForEach(indexedRituals, id: \.element.id) { index, ritual in
                if index == 0 {
                    frontCard(ritual: ritual,
                              dynamicScale: dynamicScale,
                              lift: lift,
                              dynamicShadowOpacity: dynamicShadowOpacity,
                              dynamicShadowRadius: dynamicShadowRadius,
                              dynamicShadowY: dynamicShadowY)
                } else {
                    let backScale = 1.0 - CGFloat(index) * 0.025
                        + (index == 1 ? CGFloat(dragProgress) * 0.018 : 0)
                    let backY = CGFloat(index) * -18
                        - (index == 1 ? CGFloat(dragProgress) * 8.0 : 0)

                    RitualSwipeCard(ritual: ritual)
                        .scaleEffect(backScale)
                        .offset(x: CGFloat(index) * -24, y: backY)
                        .rotationEffect(.degrees(Double(index) * -2.0))
                        .zIndex(Double(3 - index))
                        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 4)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: dragProgress)
                }
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.88), value: rituals.first?.id)
        .sensoryFeedback(.impact(weight: .medium), trigger: rituals.first?.id)
    }

    /// Envelope of motion values driven by `keyframeAnimator` on each flip.
    /// Idle = all values neutral. The keyframe arc rises at the midpoint of
    /// the flip and returns to idle, so both flip-out and flip-back get the
    /// same tactile envelope without direction-aware logic.
    private struct FlipMotion {
        var scale: Double = 1.0
        var lift: Double = 0.0
        var shadowSwell: Double = 0.0
        var shadowRadiusSwell: Double = 0.0
        var shadowYSwell: Double = 0.0
        var shineOpacity: Double = 0.0
    }

    @ViewBuilder
    private func frontCard(ritual: RedirectRitual,
                           dynamicScale: Double,
                           lift: Double,
                           dynamicShadowOpacity: Double,
                           dynamicShadowRadius: Double,
                           dynamicShadowY: Double) -> some View {

        let card = ZStack {
            RitualSwipeCard(ritual: ritual)
                .opacity(isFlipped ? 0 : 1)

            RitualBackFaceCard(ritual: ritual)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)
        }
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: isFlipped)
        .scaleEffect(CGFloat(dynamicScale))
        .offset(x: dragOffset.width, y: dragOffset.height * 0.25 + CGFloat(lift))
        .rotationEffect(.degrees(Double(dragOffset.width) / 18.0))
        .zIndex(3)
        .shadow(
            color: .black.opacity(dynamicShadowOpacity),
            radius: dynamicShadowRadius,
            x: 0, y: dynamicShadowY
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isDragging)
        .keyframeAnimator(initialValue: FlipMotion(), trigger: isFlipped) { content, value in
            content
                .scaleEffect(CGFloat(value.scale))
                .offset(y: CGFloat(value.lift))
                .shadow(
                    color: .black.opacity(value.shadowSwell),
                    radius: CGFloat(value.shadowRadiusSwell),
                    x: 0,
                    y: CGFloat(value.shadowYSwell)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.45),
                                    Color.clear
                                ],
                                startPoint: UnitPoint(x: 0.38, y: 0.5),
                                endPoint: UnitPoint(x: 0.62, y: 0.5)
                            )
                        )
                        .opacity(value.shineOpacity)
                        .allowsHitTesting(false)
                }
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.96, duration: 0.25)
                CubicKeyframe(1.0,  duration: 0.30)
            }
            KeyframeTrack(\.lift) {
                CubicKeyframe(-6.0, duration: 0.25)
                CubicKeyframe(0.0,  duration: 0.30)
            }
            KeyframeTrack(\.shadowSwell) {
                CubicKeyframe(0.20, duration: 0.25)
                CubicKeyframe(0.0,  duration: 0.30)
            }
            KeyframeTrack(\.shadowRadiusSwell) {
                CubicKeyframe(14.0, duration: 0.25)
                CubicKeyframe(0.0,  duration: 0.30)
            }
            KeyframeTrack(\.shadowYSwell) {
                CubicKeyframe(8.0, duration: 0.25)
                CubicKeyframe(0.0, duration: 0.30)
            }
            KeyframeTrack(\.shineOpacity) {
                CubicKeyframe(0.55, duration: 0.27)
                CubicKeyframe(0.0,  duration: 0.28)
            }
        }
        .onTapGesture {
            isFlipped.toggle()
        }

        // Split-branch the drag gesture per CLAUDE.md (avoid conditional nil gesture).
        // Drag is only attached when the card is showing its front face.
        if isFlipped {
            card
        } else {
            card.gesture(dragGesture)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Ritual Swipe Card
// ─────────────────────────────────────────────

struct RitualSwipeCard: View {
    let ritual: RedirectRitual

    private var usesLightText: Bool {
        ["#B8A8B0", "#1B4D4A", "#2C2F3A"].contains(ritual.cardHex)
    }

    private var textColor: Color {
        usesLightText ? Color(hex: "#FFF8EC").opacity(0.94) : Color(hex: "#2C2825").opacity(0.82)
    }

    private var chipTextColor: Color {
        usesLightText ? .white.opacity(0.80) : Color(hex: "#2C2825").opacity(0.70)
    }

    private var metadataLine: String {
        "\(ritual.estimatedMinutes) min · \(ritual.mood)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .top, spacing: 8) {
                Text(ritual.label)
                    .font(.custom("InstrumentSerif-Italic", size: 17))
                    .foregroundColor(Color(hex: "#1F1B18"))
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 14, bottomLeadingRadius: 14,
                            bottomTrailingRadius: 4, topTrailingRadius: 14,
                            style: .continuous
                        )
                        .fill(Color(hex: "#FFFDF2"))
                        .overlay {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 14, bottomLeadingRadius: 14,
                                bottomTrailingRadius: 4, topTrailingRadius: 14,
                                style: .continuous
                            )
                            .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                        }
                        .shadow(color: Color(hex: "#1F1B18").opacity(0.14),
                                radius: 0, x: 1.5, y: 1.5)
                    }

                Spacer()

                Text("memory")
                    .font(.custom("InstrumentSerif-Italic", size: 12))
                    .foregroundColor(textColor.opacity(0.55))
                    .padding(.top, 8)
            }
            .padding(.top, 18)
            .padding(.horizontal, 18)

            Spacer().frame(height: 22)

            RitualImageCollage(ritual: ritual)
                .frame(maxWidth: .infinity)
                .frame(height: 150)

            Spacer().frame(height: 18)

            Rectangle()
                .fill(textColor.opacity(0.18))
                .frame(height: 0.5)
                .padding(.horizontal, 22)
                .padding(.bottom, 12)

            Text(ritual.description)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundColor(textColor)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)
                .lineLimit(4)
                .minimumScaleFactor(0.94)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)

            Spacer().frame(height: 10)

            Text(metadataLine)
                .font(.custom("InstrumentSerif-Italic", size: 13))
                .foregroundColor(textColor.opacity(0.72))
                .padding(.horizontal, 22)
                .padding(.bottom, 22)
        }
        .frame(width: 300, height: 370)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: ritual.cardHex))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.clear)
                        .overlay {
                            Image("paper texture")
                                .resizable()
                                .scaledToFill()
                                .blendMode(.multiply)
                                .opacity(0.08)
                                .allowsHitTesting(false)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    Color.clear,
                                    Color.black.opacity(0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(hex: "#1F1B18").opacity(0.45), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 90)
                        .blur(radius: 24)
                        .offset(x: -20, y: -25)
                }
        }
        .shadow(color: Color(red: 0.35, green: 0.25, blue: 0.22).opacity(0.22),
                radius: 22, x: 0, y: 14)
    }
}

// ─────────────────────────────────────────────
// MARK: - Ritual Image Collage
// ─────────────────────────────────────────────

struct RitualImageCollage: View {
    let ritual: RedirectRitual

    var body: some View {
        let firstSeed  = ritual.thumbnailSeeds.indices.contains(0) ? ritual.thumbnailSeeds[0] : "calm"
        let secondSeed = ritual.thumbnailSeeds.indices.contains(1) ? ritual.thumbnailSeeds[1] : firstSeed

        ZStack {
            RitualThumbnail(seed: firstSeed)
                .frame(width: 155, height: 105)
                .rotationEffect(.degrees(-5))
                .offset(x: -34, y: -4)
                .zIndex(1)

            RitualThumbnail(seed: secondSeed)
                .frame(width: 130, height: 90)
                .rotationEffect(.degrees(7))
                .offset(x: 50, y: 30)
                .zIndex(2)
        }
        .frame(height: 150)
        .frame(maxWidth: .infinity)
    }
}

// ─────────────────────────────────────────────
// MARK: - Ritual Thumbnail
// ─────────────────────────────────────────────

struct RitualThumbnail: View {
    let seed: String

    var body: some View {
        AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/260/180")) { phase in
            switch phase {
            case .success(let img):
                img.resizable().scaledToFill()
            default:
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.white.opacity(0.35))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .padding(5)
        .background(Color(hex: "#FFFDF2"))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: "#1F1B18").opacity(0.45), lineWidth: 1)
        }
        .shadow(color: Color(hex: "#1F1B18").opacity(0.18),
                radius: 0, x: 1.5, y: 1.5)
        .shadow(color: .black.opacity(0.18),
                radius: 8, x: 0, y: 4)
    }
}

// ─────────────────────────────────────────────
// MARK: - Deck Controls
// ─────────────────────────────────────────────

struct DeckControls: View {
    let onShuffle: () -> Void
    let onChoose: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 18) {

            Button(action: onShuffle) {
                Image(systemName: "shuffle")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hex: "#1F1B18"))
                    .frame(width: 48, height: 48)
                    .background {
                        Circle()
                            .fill(Color(hex: "#FFFDF2"))
                            .overlay {
                                Circle()
                                    .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                            }
                            .shadow(color: Color(hex: "#1F1B18").opacity(0.14),
                                    radius: 0, x: 1.5, y: 1.5)
                    }
            }
            .buttonStyle(PaperCircleButtonStyle())

            Spacer()

            Button(action: onChoose) {
                Text("choose this")
                    .font(.custom("InstrumentSerif-Italic", size: 16))
                    .foregroundColor(Color(hex: "#1F1B18").opacity(0.78))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background {
                        Capsule()
                            .fill(Color(hex: "#FFFDF2").opacity(0.6))
                            .overlay {
                                Capsule()
                                    .stroke(Color(hex: "#1F1B18").opacity(0.22), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.96))

            Spacer()

            Button(action: onNext) {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(Color(hex: "#1F1B18"))
                    .frame(width: 48, height: 48)
                    .background {
                        Circle()
                            .fill(Color(hex: "#FFFDF2"))
                            .overlay {
                                Circle()
                                    .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                            }
                            .shadow(color: Color(hex: "#1F1B18").opacity(0.14),
                                    radius: 0, x: 1.5, y: 1.5)
                    }
            }
            .buttonStyle(PaperCircleButtonStyle())
        }
        .frame(height: 48)
    }
}

// ─────────────────────────────────────────────
// MARK: - Paper Circle Button Style
// ─────────────────────────────────────────────

private struct PaperCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
    }
}

// ─────────────────────────────────────────────
// MARK: - Deck Pagination
// ─────────────────────────────────────────────

struct DeckPagination: View {
    let count: Int
    let activeIndex: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<max(count, 0), id: \.self) { i in
                Button {
                    onSelect(i)
                } label: {
                    let isActive = i == activeIndex

                    if isActive {
                        Capsule()
                            .fill(DSColor.ink.opacity(0.65))
                            .frame(width: 28, height: 8)
                            .overlay(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.35), Color.clear],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                            )
                            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                            .animation(.spring(duration: 0.35, bounce: 0.2), value: activeIndex)
                    } else {
                        Circle()
                            .fill(Color(hex: "#1F1B18").opacity(0.35))
                            .frame(width: 8, height: 8)
                            .animation(.spring(duration: 0.35, bounce: 0.2), value: activeIndex)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show ritual \(i + 1)")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color(hex: "#1F1B18").opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color(hex: "#1F1B18").opacity(0.14), radius: 0, x: 1.5, y: 1.5)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// ─────────────────────────────────────────────
// MARK: - When Timer Ends Card
// ─────────────────────────────────────────────

struct WhenTimerEndsCard: View {
    let selectedRitual: RedirectRitual?

    private var methodEmoji: String {
        switch selectedRitual?.type {
        case .watch:    return "🎬"
        case .read:     return "📚"
        case .miniGame: return "🎲"
        case .reflect:  return "✍️"
        case .deepDive: return "🔭"
        case .none:     return "🎬"
        }
    }

    private let mockApps: [TrackedApp] = [
        TrackedApp(id: "tiktok",    name: "TikTok",    iconName: nil, colorHex: "#010101"),
        TrackedApp(id: "instagram", name: "Instagram", iconName: nil, colorHex: "#E1306C"),
    ]

    var body: some View {
        let panelFill = Color(hex: "#F5F0E8")

        ZStack(alignment: .topLeading) {

            VStack(alignment: .leading, spacing: 0) {

                Spacer().frame(height: 38)

                HStack(alignment: .top, spacing: 10) {

                    VStack(alignment: .leading, spacing: 6) {
                        Text("apps tracked")
                            .font(.custom("InstrumentSerif-Italic", size: 13))
                            .foregroundColor(Color(hex: "#1F1B18"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: "#B8D4EE").opacity(0.55))

                        HStack(spacing: 6) {
                            ForEach(mockApps) { app in
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color(hex: app.colorHex))
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        Text(app.name.prefix(2).uppercased())
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundColor(.white.opacity(0.92))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                                    }
                                    .shadow(color: Color(hex: "#1F1B18").opacity(0.10),
                                            radius: 0, x: 1, y: 1)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(minHeight: 46)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(hex: "#FFFDF2"))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                                }
                                .shadow(color: Color(hex: "#1F1B18").opacity(0.10),
                                        radius: 0, x: 1, y: 1)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("timer set")
                            .font(.custom("InstrumentSerif-Italic", size: 13))
                            .foregroundColor(Color(hex: "#1F1B18"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: "#C9B3E8").opacity(0.55))

                        HStack(spacing: 6) {
                            ForEach(["00", "45"], id: \.self) { digit in
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(hex: "#FFFDF2"))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 46)
                                    .overlay {
                                        Text(digit)
                                            .font(.custom("InstrumentSerif-Italic", size: 26))
                                            .foregroundColor(Color(hex: "#1F1B18"))
                                    }
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                                    }
                                    .shadow(color: Color(hex: "#1F1B18").opacity(0.10),
                                            radius: 0, x: 1, y: 1)
                            }
                        }
                        .id(selectedRitual?.id)
                        .transition(.opacity)
                        .animation(.smooth.delay(0.06), value: selectedRitual?.id)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("re:direction")
                            .font(.custom("InstrumentSerif-Italic", size: 13))
                            .foregroundColor(Color(hex: "#1F1B18"))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(hex: "#B8DEC0").opacity(0.55))

                        ZStack {
                            Text(methodEmoji)
                                .font(.system(size: 34))
                                .shadow(color: Color(hex: "#1F1B18").opacity(0.16),
                                        radius: 0, x: 1, y: 1)
                                .id(selectedRitual?.id)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                                .animation(.spring(response: 0.28, dampingFraction: 0.78), value: selectedRitual?.id)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 46)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(panelFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                    }
                    .shadow(color: Color(hex: "#1F1B18").opacity(0.12),
                            radius: 0, x: 1.5, y: 1.5)
                    .shadow(color: .black.opacity(0.08),
                            radius: 14, x: 0, y: 6)
            }

            Text("When Timer Ends")
                .font(.custom("InstrumentSerif-Italic", size: 18))
                .foregroundColor(Color(hex: "#1F1B18"))
                .padding(.horizontal, 17)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(hex: "#F2EFB8")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            Capsule()
                                .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                        }
                        .shadow(color: Color(hex: "#1F1B18").opacity(0.14),
                                radius: 0, x: 1.5, y: 1.5)
                }
                .offset(x: -3, y: -15)
        }
        .animation(.spring(duration: 0.3, bounce: 0.1), value: selectedRitual?.id)
    }
}

struct PayloadColumn: View {
    let label: String
    let value: String
    var accent: Color = Color(hex: "#2C2825")
    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .light))
                .foregroundColor(Color(hex: "#2C2825").opacity(0.45))
            Text(value)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(Color(hex: "#1F1B18"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ColumnDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(hex: "#2C2825").opacity(0.08))
            .frame(width: 1, height: 44)
    }
}

// ─────────────────────────────────────────────
// MARK: - Re:tuals Grain + RNG
// ─────────────────────────────────────────────

struct RetualsGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = RetualsRNG(seed: 42)
            for _ in 0..<1800 {
                let x       = CGFloat.random(in: 0...size.width,  using: &rng)
                let y       = CGFloat.random(in: 0...size.height, using: &rng)
                let radius  = CGFloat.random(in: 1.0...2.5,       using: &rng)
                let opacity = Double.random(in: 0.06...0.18,      using: &rng)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                    with: .color(Color.black.opacity(opacity))
                )
            }
        }
    }
}

struct RetualsRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

// ─────────────────────────────────────────────
// MARK: - Ritual Back Face (empty state)
// ─────────────────────────────────────────────

/// Back face of a re:tuals card. Shows up to 5 recent CuriosityEngagement rows
/// for this lane, or the universal empty-state copy when none exist.
struct RitualBackFaceCard: View {
    let ritual: RedirectRitual
    @Query private var engagements: [CuriosityEngagement]

    init(ritual: RedirectRitual) {
        self.ritual = ritual
        let slug = ritual.id
        _engagements = Query(
            filter: #Predicate<CuriosityEngagement> {
                $0.methodSlug == slug && $0.deletedAt == nil
            },
            sort: \.engagedAt,
            order: .reverse
        )
    }

    private var usesLightText: Bool {
        ["#B8A8B0", "#1B4D4A", "#2C2F3A"].contains(ritual.cardHex)
    }

    private var textColor: Color {
        usesLightText
            ? Color(hex: "#FFF8EC").opacity(0.94)
            : Color(hex: "#2C2825").opacity(0.82)
    }

    private var visibleRows: [CuriosityEngagement] {
        Array(engagements.prefix(5))
    }

    private var emptyStateSecondLine: String {
        switch ritual.id {
        case "watch":      return "your next watch starts a memory."
        case "read":       return "your next read starts a memory."
        case "mini-game":  return "your next puzzle starts a memory."
        case "reflect":    return "your next reflection starts a memory."
        case "deep-dive":  return "your next dive starts a memory."
        default:           return "the next one starts a memory."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            header

            if engagements.isEmpty {
                emptyState
            } else {
                populatedState
            }
        }
        .frame(width: 300, height: 370)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(hex: ritual.cardHex))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                }
                .overlay(alignment: .topLeading) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(usesLightText ? 0.18 : 0.30),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: UnitPoint(x: 0.55, y: 0.45)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .allowsHitTesting(false)
                }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("recent · \(ritual.type.rawValue.lowercased())")
                .font(.custom("InstrumentSerif-Italic", size: 17))
                .foregroundColor(Color(hex: "#1F1B18"))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 14, bottomLeadingRadius: 14,
                        bottomTrailingRadius: 4, topTrailingRadius: 14,
                        style: .continuous
                    )
                    .fill(Color(hex: "#FFFDF2"))
                    .overlay {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 14, bottomLeadingRadius: 14,
                            bottomTrailingRadius: 4, topTrailingRadius: 14,
                            style: .continuous
                        )
                        .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                    }
                    .shadow(color: Color(hex: "#1F1B18").opacity(0.14),
                            radius: 0, x: 1.5, y: 1.5)
                }

            Spacer()

            Text("front")
                .font(.custom("InstrumentSerif-Italic", size: 12))
                .foregroundColor(textColor.opacity(0.55))
                .padding(.top, 8)
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer().frame(height: 36)

            Text("no rabbit holes here yet —")
                .font(.custom("InstrumentSerif-Italic", size: 22))
                .foregroundColor(textColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Rectangle()
                .fill(textColor.opacity(0.30))
                .frame(width: 48, height: 0.5)

            Text(emptyStateSecondLine)
                .font(.system(size: 13, weight: .light))
                .foregroundColor(textColor.opacity(0.72))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
    }

    private var populatedState: some View {
        VStack(alignment: .leading, spacing: 0) {

            Spacer().frame(height: 18)

            Rectangle()
                .fill(textColor.opacity(0.22))
                .frame(height: 0.5)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(visibleRows.enumerated()), id: \.element.id) { idx, row in
                    if idx > 0 {
                        Rectangle()
                            .fill(textColor.opacity(0.14))
                            .frame(height: 0.5)
                    }
                    engagementRow(row, number: idx + 1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private func engagementRow(_ engagement: CuriosityEngagement, number: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.custom("InstrumentSerif-Italic", size: 13))
                .foregroundColor(textColor.opacity(0.40))
                .frame(width: 14, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(engagement.contentTitle)
                    .font(.custom("InstrumentSerif-Italic", size: 16))
                    .foregroundColor(textColor)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(EngagementCaption.caption(for: engagement, separator: "–"))
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(textColor.opacity(0.58))
            }
        }
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// ─────────────────────────────────────────────
// MARK: - Engagement Caption (testable helpers)
// ─────────────────────────────────────────────

/// Pure helpers for rendering CuriosityEngagement row captions on the back face.
/// Extracted so the relative-date and duration formatting can be unit-tested.
enum EngagementCaption {

    static func caption(
        for engagement: CuriosityEngagement,
        now: Date = .now,
        calendar: Calendar = .current,
        separator: String = "·"
    ) -> String {
        let date = relativeDate(engagement.engagedAt, now: now, calendar: calendar)
        if let duration = durationText(engagement.durationSeconds) {
            return "\(date) \(separator) \(duration)"
        }
        return date
    }

    static func relativeDate(
        _ date: Date,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "earlier today" }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))
        if let y = yesterday, calendar.isDate(date, inSameDayAs: y) { return "yesterday" }

        let daysAgo = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: now)
        ).day ?? 0

        if daysAgo <= 0 { return "earlier today" }
        if daysAgo <= 6 { return "\(daysAgo) days ago" }
        if daysAgo <= 13 { return "last week" }
        return "\(daysAgo) days ago"
    }

    static func durationText(_ seconds: Int?) -> String? {
        guard let s = seconds, s > 0 else { return nil }
        let minutes = Int((Double(s) / 60.0).rounded())
        return "\(max(1, minutes)) min"
    }
}

#Preview {
    RetualsView()
}
