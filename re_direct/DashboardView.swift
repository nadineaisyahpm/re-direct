//
//  DashboardView.swift
//  re_direct
//
//  Main home screen after login.
//  Beginner-friendly — every section is commented.
//

import SwiftUI

// ─────────────────────────────────────────────
// MARK: - Dashboard View
// ─────────────────────────────────────────────
// Root view. ZStack layers background + grain behind everything.
// ScrollView holds all content. Navbar floats outside the scroll.

struct DashboardView: View {

    var body: some View {

        GeometryReader { geo in
            ZStack {

                // ── Background: warm beige gradient ───────────────
                // #EDE8DF at top — parchment/cream tone matching Figma.
                // Fades to a slightly deeper warm sand at the bottom.
                LinearGradient(
                    colors: [
                        Color(hex: "#EDE8DF"),
                        Color(hex: "#D4CCC0")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // ── Grain texture ─────────────────────────────────
                // Coarse film grain — same as OnboardingView.
                DashboardGrain()
                    .drawingGroup()
                    .ignoresSafeArea()

                // ── Scrollable content ────────────────────────────
                // All sections live inside this ScrollView.
                // Bottom padding clears the floating navbar.
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        HeaderSection()
                            .padding(.top, geo.safeAreaInsets.top + 16)
                            .padding(.horizontal, 20)

                        SearchBarView()
                            .padding(.top, 14)
                            .padding(.horizontal, 20)

                        DailyDirectSection()
                            .padding(.top, 22)

                        ReLogWidget()
                            .padding(.top, 22)
                            .padding(.horizontal, 20)
                            // Extra bottom padding so the widget doesn't
                            // visually merge with the floating navbar below.
                            .padding(.bottom, 8)

                        // Clears the floating navbar at the bottom.
                        Spacer().frame(height: 100)
                    }
                }

                // ── Floating navbar ───────────────────────────────
                // Pinned to the bottom using a VStack with a Spacer.
                // Lives outside the ScrollView so it never scrolls away.
                VStack {
                    Spacer()
                    NavBar()
                        .padding(.bottom, geo.safeAreaInsets.bottom + 8)
                        .padding(.horizontal, 24)
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
    }
}

// ─────────────────────────────────────────────
// MARK: - Header Section
// ─────────────────────────────────────────────
// "hello," on one line, "Nadine." on the next with a yellow highlight.
// The highlight uses .background() with padding so it hugs the text
// tightly rather than being a fixed-width rectangle.

struct HeaderSection: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // "hello," — smaller, italic serif, no highlight
            Text("hello,")
                .font(.custom("InstrumentSerif-Italic", size: 22))
                .foregroundColor(Color(hex: "#2C2825"))

            // "Nadine." — yellow highlight hugs only the text width.
            // Applying .background() directly on the Text view means
            // the highlight is exactly as wide as the text — never full width.
            // The thin Rectangle below acts as an underline inside the box.
            VStack(alignment: .leading, spacing: 0) {
                Text("Nadine.")
                    .font(.custom("InstrumentSerif-Italic", size: 38))
                    .foregroundColor(Color(hex: "#2C2825"))
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                    .background(
                        // .background on Text itself — width matches text exactly.
                        Color(hex: "#F0E68C").opacity(0.7)
                    )

                // Thin underline drawn as a separate Rectangle.
                // Width matches the text by being inside the same VStack
                // with fixedSize applied — it won't stretch full width.
                Rectangle()
                    .fill(Color(hex: "#2C2825").opacity(0.45))
                    .frame(height: 1.5)
                    .padding(.horizontal, 6)
            }
            // fixedSize(horizontal: true) is the key — it tells SwiftUI
            // to size this VStack to fit its content width, not stretch
            // to fill the parent. Without this, the highlight goes full width.
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Search Bar
// ─────────────────────────────────────────────
// Non-functional visual search bar.
// Placeholder text is centred. Icon on the right.

struct SearchBarView: View {

    var body: some View {
        HStack {

            Spacer()

            // Centred placeholder text
            Text("Search curiosities...")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(Color(hex: "#2C2825").opacity(0.35))

            Spacer()

            // Magnifying glass — right side
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .light))
                .foregroundColor(Color(hex: "#2C2825").opacity(0.35))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.6))
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(Color(hex: "#2C2825").opacity(0.12), lineWidth: 1)
        )
    }
}

// ─────────────────────────────────────────────
// MARK: - Daily Direct Section
// ─────────────────────────────────────────────
// Section label + date row, then the animated snap carousel.

struct DailyDirectSection: View {

    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: Date())
    }

    // Card data: background colour, title, subtitle.
    // Colours are dark atmospheric tones from the spec.
    private let cards: [(color: String, imageURL: String, title: String, subtitle: String)] = [
        (
            "#1B4D4A",
            "https://picsum.photos/seed/ocean/400/500",
            "What did NASA really found in the deep sea?",
            "Find out why scientists stopped diving deeper to the trench..."
        ),
        (
            "#2C1810",
            "https://picsum.photos/seed/desert/400/500",
            "The forgotten cities under the Sahara",
            "Ancient civilizations buried beneath the sand for centuries..."
        ),
        (
            "#2C2F3A",
            "https://picsum.photos/seed/dream/400/500",
            "Why do we dream in other people's voices?",
            "Scientists still can't explain this strange phenomenon..."
        ),
        (
            "#1A1A2E",
            "https://picsum.photos/seed/memory/400/500",
            "The science of déjà vu — why your brain fakes memories",
            "Researchers finally have a theory for this eerie sensation..."
        ),
        (
            "#1C1C1C",
            "https://picsum.photos/seed/japan/400/500",
            "Japan's evaporating people — the Johatsu phenomenon",
            "Thousands vanish every year completely by choice..."
        )
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Section header: label left, date right
            HStack(alignment: .firstTextBaseline) {
                Text("dailydirect")
                    .font(.custom("InstrumentSerif-Italic", size: 20))
                    .foregroundColor(Color(hex: "#2C2825"))
                Spacer()
                Text(dateString)
                    .font(.system(size: 14, weight: .light))
                    .foregroundColor(Color(hex: "#2C2825").opacity(0.5))
            }
            .padding(.horizontal, 20)

            // ── Carousel ──────────────────────────────────────────
            // contentMargins centres the focused card and controls
            // how much of the side cards peek in.
            // Using GeometryReader to calculate the exact centre margin
            // so the focused card is always perfectly centred regardless
            // of device width.
            GeometryReader { scrollGeo in
                let cardWidth: CGFloat = 200
                // This puts the focused card dead centre.
                // Side cards peek in by whatever is left: ~(screenWidth - cardWidth)/2 - margin
                // At 390pt screen: (390-200)/2 = 95pt margin → ~55pt of side card visible.
                let margin = (scrollGeo.size.width - cardWidth) / 2

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(cards.indices, id: \.self) { index in
                            DailyCard(
                                cardColor: cards[index].color,
                                imageURL: cards[index].imageURL,
                                title: cards[index].title,
                                subtitle: cards[index].subtitle
                            )
                            .scrollTransition(.animated(.spring(duration: 0.3))) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.82)
                                    // Side cards drop down so their bottom edge
                                    // aligns with the centre card's bottom edge.
                                    // The scale makes them shorter by ~18%, so we
                                    // offset down by roughly that difference.
                                    .offset(y: phase.isIdentity ? 0 : 22)
                                    .rotationEffect(
                                        phase.isIdentity
                                            ? .degrees(0)
                                            : phase.value < 0 ? .degrees(-6) : .degrees(6),
                                        anchor: .bottom
                                    )
                                    .opacity(phase.isIdentity ? 1.0 : 0.85)
                            }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, margin, for: .scrollContent)
                .frame(height: 290)
            }
            .frame(height: 290)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Daily Card
// ─────────────────────────────────────────────
// A single card. Dark atmospheric fill, gradient overlay, white text.
// Fixed 200×260pt — the carousel handles scale via scrollTransition.

struct DailyCard: View {
    let cardColor: String
    let imageURL: String
    let title: String
    let subtitle: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {

            // ── Background image via AsyncImage ───────────────────
            // AsyncImage is SwiftUI's built-in URL image loader.
            // It has three states: loading, success, failure.
            // While loading, we show the solid colour placeholder.
            // On success, the image fills the card.
            AsyncImage(url: URL(string: imageURL)) { phase in
                switch phase {

                case .empty:
                    // Still loading — show the colour placeholder.
                    Color(hex: cardColor)

                case .success(let image):
                    // Image loaded — fill the card, crop to fit.
                    image
                        .resizable()
                        .scaledToFill()

                case .failure:
                    // Network error — fall back to colour placeholder.
                    Color(hex: cardColor)

                @unknown default:
                    Color(hex: cardColor)
                }
            }

            // ── Gradient overlay ──────────────────────────────────
            // Dark gradient at the bottom keeps white text readable
            // over any photo content.
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            // ── Text block ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.custom("InstrumentSerif-Regular", size: 16))
                    .foregroundColor(.white)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 12, weight: .light))
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .padding(.top, 14)
        }
        // frame + clipShape together bound everything to 200×240pt.
        // clipShape also crops the AsyncImage to the rounded card shape.
        .frame(width: 200, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// ─────────────────────────────────────────────
// MARK: - Re:Log Widget
// ─────────────────────────────────────────────
// Three parts: stamp label (top right), yellow banner, white stat card.

struct ReLogWidget: View {

    private let topicColors: [Color] = [
        Color(hex: "#8B7355"),
        Color(hex: "#6B8B7A"),
        Color(hex: "#7A6B8B"),
        Color(hex: "#8B6B6B"),
        Color(hex: "#6B7A8B")
    ]

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {

            // ── "re:log" stamp label ──────────────────────────────
            // White background, dark border — looks like a rubber stamp.
            // Right-aligned to match the Figma layout.
            Text("re:log")
                .font(.custom("InstrumentSerif-Italic", size: 20))
                .foregroundColor(Color(hex: "#2C2825"))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.9))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(hex: "#2C2825").opacity(0.25), lineWidth: 1)
                )

            // ── Yellow banner ─────────────────────────────────────
            // Narrower than full width — 32pt margin each side via padding.
            // Pill shape, warm yellow fill.
            Text("Track your rabbit hole journey in re:log")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(Color(hex: "#2C2825"))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "#F5ECD7"))
                .cornerRadius(20)
                // Inset the banner from the widget edges.
                .padding(.horizontal, 8)

            // ── Stat card ─────────────────────────────────────────
            // White rounded card. Left column: number stat.
            // Right column: topic circles + arrow.
            // A visible divider separates the two columns.
            HStack(alignment: .top, spacing: 0) {

                // -- Left: dive count ─────────────────────────────
                VStack(alignment: .leading, spacing: 0) {

                    Text("You've dived into")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(Color(hex: "#2C2825").opacity(0.6))

                    // Large thin number — editorial, Instrument Serif.
                    Text("10")
                        .font(.custom("InstrumentSerif-Regular", size: 64))
                        .foregroundColor(Color(hex: "#2C2825"))
                        .frame(height: 70)

                    Text("topics this week.")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(Color(hex: "#2C2825").opacity(0.6))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Visible divider line between columns.
                Rectangle()
                    .fill(Color(hex: "#2C2825").opacity(0.12))
                    .frame(width: 1)
                    .padding(.vertical, 16)

                // -- Right: Top 5 Topics ───────────────────────────
                VStack(alignment: .center, spacing: 10) {

                    // "Top 5 Topics" pill
                    Text("Top 5 Topics")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(Color(hex: "#2C2825"))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Color(hex: "#2C2825").opacity(0.07))
                        .cornerRadius(20)

                    // Scattered overlapping circles.
                    // ZStack with manual offsets gives an organic cluster feel.
                    ZStack {
                        // Circle 1 — top left
                        Circle()
                            .fill(topicColors[0])
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: -22, y: -16)

                        // Circle 2 — top right
                        Circle()
                            .fill(topicColors[1])
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: 10, y: -20)

                        // Circle 3 — centre
                        Circle()
                            .fill(topicColors[2])
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: -8, y: 4)

                        // Circle 4 — bottom left
                        Circle()
                            .fill(topicColors[3])
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: -26, y: 20)

                        // Circle 5 — bottom right
                        Circle()
                            .fill(topicColors[4])
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .offset(x: 18, y: 16)
                    }
                    .frame(width: 80, height: 80)

                    // Arrow button — bottom right of the right column.
                    HStack {
                        Spacer()
                        Button(action: { print("re:log tapped") }) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(hex: "#2C2825"))
                                .frame(width: 30, height: 30)
                                .background(Color(hex: "#2C2825").opacity(0.07))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
            }
            .background(Color.white.opacity(0.85))
            .cornerRadius(16)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Nav Bar
// ─────────────────────────────────────────────
// Floating white pill, 5 icon tabs.
// First tab has a filled dark circle — selected state.
// Completely separate from the scroll content.

struct NavBar: View {

    private let icons = [
        "leaf.fill",
        "clock.fill",
        "hourglass",
        "waveform.path.ecg",
        "gearshape.fill"
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(icons.indices, id: \.self) { index in
                ZStack {
                    // Dark circle behind the selected (first) tab only.
                    if index == 0 {
                        Circle()
                            .fill(Color(hex: "#2C2825"))
                            .frame(width: 44, height: 44)
                    }

                    Image(systemName: icons[index])
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(
                            index == 0
                                ? .white
                                : Color(hex: "#2C2825").opacity(0.45)
                        )
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
            }
        }
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.95))
        .cornerRadius(40)
        .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 4)
    }
}

// ─────────────────────────────────────────────
// MARK: - Dashboard Grain
// ─────────────────────────────────────────────
// Coarse film grain — same parameters as OnboardingView.
// Renamed struct to avoid conflicts with OnboardingView's grain.

struct DashboardGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = DashboardRNG(seed: 42)
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

struct DashboardRNG: RandomNumberGenerator {
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
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    DashboardView()
}
