import SwiftUI
import SwiftData

struct DashboardView: View {

    var body: some View {

        GeometryReader { geo in
            ZStack {

                PaperBackground(variant: .cool)

                DashboardGrain()
                    .drawingGroup()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        HeaderSection()
                            .padding(.top, geo.safeAreaInsets.top + 16)
                            .padding(.horizontal, 20)

                        SearchBarView()
                            .padding(.top, 10)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)

                        DailyDirectSection()
                            .padding(.top, 5)

                        ReLogWidget()
                            .padding(.top, 35)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 25)

                        Spacer().frame(height: DSMetric.bottomNavClearance)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
    }
}


    struct HeaderSection: View {

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                Text("hello,")
                    .font(.custom("InstrumentSerif-Italic", size: 22))
                    .foregroundColor(Color(hex: "#2C2825"))

                VStack(alignment: .leading, spacing: 0) {
                    HighlighterText(text: "Nadine.", size: 38)

                    Rectangle()
                        .fill(Color(hex: "#2C2825").opacity(0.45))
                        .frame(height: 1.0)
                        .padding(.horizontal, 6)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
        }
    }


    struct SearchBarView: View {

        private let seedPlaceholders = [
            "Search curiosities…",
            "Abandoned soviet cosmonauts…",
            "Did Pythagoras really kill over irrationals?",
            "Why don't we know the deep ocean floor?",
            "What's actually at the bottom of the Mariana Trench?"
        ]

        @State private var dummyText: String = ""

        var body: some View {
            PaperSearchBar(
                placeholder: "Search curiosities…",
                text: $dummyText,
                focused: nil,
                rotatingPlaceholders: seedPlaceholders,
                rotationInterval: 6
            )
        }
    }


    struct DailyDirectSection: View {

        private var dateString: String {
            let f = DateFormatter()
            f.dateFormat = "dd/MM/yyyy"
            return f.string(from: Date())
        }

        @State private var activeIndex: Int = 0
        @State private var aiCard: ReDirectTopic? = nil
        @Environment(\.modelContext) private var modelContext

        @Query(sort: \CuriosityTopic.slug) private var seededTopics: [CuriosityTopic]

        /// Seeded card list — unchanged behavior from before Phase 6D-B.
        private var seededCards: [ReDirectTopic] {
            guard !seededTopics.isEmpty else { return ReDirectTopicData.topFive }
            return seededTopics.enumerated().map { offset, topic in
                Self.adapt(topic: topic, indexedAt: offset)
            }
        }

        /// Active content source. AI override (1 card) wins; otherwise the
        /// seeded list (N cards) renders. Defensively capped by the helper.
        private var cards: [ReDirectTopic] {
            DailyDirectMapping.displayCards(aiOverride: aiCard, seeded: seededCards)
        }

        private static let hexPattern = #"^#[0-9A-Fa-f]{6}$"#

        private static func adapt(topic: CuriosityTopic, indexedAt index: Int) -> ReDirectTopic {
            let fallback = ReDirectTopicData.topFive[index % ReDirectTopicData.topFive.count]

            let subtitle: String = {
                if !topic.summary.isEmpty { return topic.summary }
                let firstPrompt = (topic.prompts ?? []).min { $0.slug < $1.slug }
                if let body = firstPrompt?.body, !body.isEmpty {
                    return trimToWords(body, max: 100)
                }
                return fallback.subtitle
            }()

            let imageSource: String = {
                if !topic.coverAssetName.isEmpty, UIImage(named: topic.coverAssetName) != nil {
                    return topic.coverAssetName
                }
                return fallback.imageURL
            }()

            let cardHex: String = {
                if topic.accentColorHex.range(of: hexPattern, options: .regularExpression) != nil {
                    return topic.accentColorHex
                }
                return fallback.colorHex
            }()

            return ReDirectTopic(
                id: index,
                title: topic.title,
                subtitle: subtitle,
                imageURL: imageSource,
                colorHex: cardHex,
                barHeight: 0,
                barColorHex: "",
                articleCount: 0,
                videoCount: 0,
                totalTime: "",
                platformStats: []
            )
        }

        private static func trimToWords(_ s: String, max limit: Int) -> String {
            if s.count <= limit { return s }
            let prefix = String(s.prefix(limit))
            if let lastSpace = prefix.lastIndex(of: " ") {
                return String(prefix[..<lastSpace]) + "…"
            }
            return prefix + "…"
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                SectionHeader(title: "dailydirect", caption: dateString)
                    .padding(.horizontal, 20)

                GeometryReader { scrollGeo in
                    let cardWidth: CGFloat = 200
                    let margin = (scrollGeo.size.width - cardWidth) / 2

                    ZStack(alignment: .bottom) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 2) {
                                ForEach(Array(cards.enumerated()), id: \.element.id) { index, topic in
                                    DailyCard(
                                        cardColor: topic.colorHex,
                                        imageURL: topic.imageURL,
                                        title: topic.title,
                                        subtitle: topic.subtitle
                                    )
                                    .scrollTransition(.animated(.spring(duration: 0.3))) { content, phase in
                                        content
                                            .scaleEffect(phase.isIdentity ? 1.0 : 0.82)
                                            .offset(y: phase.isIdentity ? 0 : 22)
                                            .rotationEffect(
                                                phase.isIdentity
                                                ? .degrees(0)
                                                : phase.value < 0 ? .degrees(-6) : .degrees(6),
                                                anchor: .bottom
                                            )
                                            .opacity(phase.isIdentity ? 1.0 : 0.85)
                                    }
                                    .onScrollVisibilityChange(threshold: 0.5) { isVisible in
                                        if isVisible {
                                            withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                                                activeIndex = index
                                            }
                                        }
                                    }
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.vertical, 20)
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .contentMargins(.horizontal, margin, for: .scrollContent)
                        .scrollClipDisabled()

                        CarouselPageIndicator(count: cards.count, activeIndex: activeIndex)
                            .offset(y: -10)
                            .allowsHitTesting(false)
                    }
                    .frame(height: 320 + 28)
                }
                .frame(height: 320 + 28)
            }
            // Daily Direct AI hook: one network attempt per app launch,
            // gated by the session store. Subsequent Dashboard appearances
            // reuse the cached result (or stay seeded on prior failure)
            // without re-hitting the proxy.
            .task {
                let store = DailyDirectSessionStore.shared

                // Already loaded earlier this session → reuse silently.
                if let cached = store.aiCard {
                    if aiCard == nil { aiCard = cached }
                    return
                }

                // Tried earlier this session and failed → stay with seeded
                // display; don't retry until next cold launch.
                if store.hasAttempted { return }

                // First attempt this session.
                store.hasAttempted = true
                if let topic = await loadAICardFromProxy() {
                    store.aiCard = topic
                    aiCard = topic
                }
            }
        }

        /// Composition root for the Dashboard's Daily Direct AI path.
        /// Built lazily inside `.task` so the view's normal seeded path
        /// has zero AI dependencies. No spinner, no error chrome — any
        /// failure silently keeps the seeded display.
        ///
        /// Returns the mapped `ReDirectTopic` on `.proxy` or `.localCache`,
        /// or `nil` on `.seedFallback` (Dashboard already owns its own
        /// seeded display; the resolver's seed result is unused here).
        private func loadAICardFromProxy() async -> ReDirectTopic? {
            // DIAGNOSTIC SIMPLIFICATION (post-RH2 AI debugging).
            //
            // The full `DailyDirectLoader → AIRecommendationResolver →
            // callProxy(request) → AIProxyHTTPClient.call` chain crashed on
            // physical ARM64e device with EXC_BAD_ACCESS at the proxy
            // client's request access. The `request` arrived at the proxy
            // with corrupted bytes / de-authenticated pointer despite being
            // valid at construction. Tests pass in the simulator (which is
            // not ARM64e), so this is suspected Swift 6 strict-concurrency
            // × ARM64e codegen interaction at the multi-hop async boundary.
            //
            // To unblock Daily Direct on device, this method now bypasses
            // the resolver/loader entirely and calls the proxy directly
            // from MainActor. Trade-offs:
            //   - Lost: 24h SwiftData cache lookup before the call.
            //   - Lost: write-back of fresh proxy responses to that cache.
            //   - Lost: resolver's seeded-fallback ladder on proxy error
            //          (the Dashboard's own seeded display is still shown
            //           when `nil` is returned here, so the user always
            //           sees something — the loss is the resolver-level
            //           seed prompt selection, which Dashboard ignored
            //           anyway via the .seedFallback → nil branch below).
            //
            // The cache + resolver paths remain fully covered by tests and
            // can be re-attached once the device crash is understood.
            let client = AIProxyHTTPClient(config: AIEnvironment.dailyDirect)

            // Build the request right here on MainActor. The struct lives
            // in this function's frame for its entire lifetime — only one
            // async hop (into `client.call`) instead of three.
            let request = AIRecommendationRequest(
                interests: DailyDirectLoader.defaultPersonalInterestSeeds,
                timeAvailableMinutes: DailyDirectLoader.defaultTimeBudgetMinutes,
                locale: DailyDirectLoader.normalizeLocale(Locale.current.identifier)
            )

            // Snapshot seeded topics for slug-keyed cover/accent lookup
            // (mapping helper remains pure).
            let coverByTopic = Dictionary(uniqueKeysWithValues:
                seededTopics.map { ($0.slug, $0.coverAssetName) }
            )
            let hexByTopic = Dictionary(uniqueKeysWithValues:
                seededTopics.map { ($0.slug, $0.accentColorHex) }
            )

            do {
                let response = try await client.call(request)
                return DailyDirectMapping.adapt(
                    response: response,
                    coverAssetByTopicSlug: { coverByTopic[$0] },
                    accentHexByTopicSlug: { hexByTopic[$0] }
                )
            } catch {
                // Any failure (network, decoding, proxy error) silently
                // falls back to the Dashboard's seeded display.
                return nil
            }
        }
    }


    struct CarouselPageIndicator: View {
        let count: Int
        let activeIndex: Int

        var body: some View {
            Group {
                if count > 7 {
                    Text("\(activeIndex + 1) of \(count)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(DSColor.ink.opacity(0.6))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                } else {
                    HStack(spacing: 6) {
                        ForEach(0..<count, id: \.self) { index in
                            let isActive = index == activeIndex

                            if isActive {
                                Capsule()
                                    .fill(DSColor.ink.opacity(0.65))
                                    .frame(width: 28, height: 8)
                                    .overlay(
                                        Capsule()
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color.white.opacity(0.35), Color.clear],
                                                    startPoint: UnitPoint.top,
                                                    endPoint: UnitPoint.bottom
                                                )
                                            )
                                    )
                                    .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 1)
                                    .animation(.spring(duration: 0.35, bounce: 0.2), value: activeIndex)
                            } else {
                                Circle()
                                    .fill(Color(hex: "#2C2825").opacity(0.18))
                                    .frame(width: 8, height: 8)
                                    .animation(.spring(duration: 0.35, bounce: 0.2), value: activeIndex)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
            }
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
    }


    struct DailyCard: View {
        let cardColor: String
        /// Image source identifier: a bundled asset catalog name OR a remote URL.
        /// The body tries `UIImage(named:)` first; on nil, falls back to AsyncImage.
        let imageURL: String
        let title: String
        let subtitle: String

        var body: some View {
            ZStack(alignment: .bottomLeading) {
                if let bundled = UIImage(named: imageURL) {
                    Image(uiImage: bundled)
                        .resizable()
                        .scaledToFill()
                } else {
                    AsyncImage(url: URL(string: imageURL)) { phase in
                        switch phase {

                        case .empty:
                            Color(hex: cardColor)

                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()

                        case .failure:
                            Color(hex: cardColor)

                        @unknown default:
                            Color(hex: cardColor)
                        }
                    }
                }

                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.custom("InstrumentSerif-Regular", size: 19))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, title.count < 20 ? 22 : 28)
                .padding(.top, 14)
            }
            .frame(width: 200, height: 270)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
            }
            .shadow(color: Color(hex: "#1F1B18").opacity(0.14), radius: 0, x: 1.5, y: 1.5)
            .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
        }
    }


    struct ReLogWidget: View {

        private let topicSeeds = ["clouds", "desert", "cosmos", "dusk", "hands"]
        @State private var appeared = false
        @State private var isPressed = false
        // A "rabbit hole" is a content-engagement event (read, watched,
        // completed a prompt) — tracked via CuriosityEngagement. TimerSession
        // rows are deliberately not counted here; starting a timer is a
        // boundary commitment, not a rabbit hole.
        @Query(filter: #Predicate<CuriosityEngagement> { $0.deletedAt == nil })
        private var engagements: [CuriosityEngagement]

        private var rabbitHoleCount: Int { engagements.count }

        private var rabbitHoleLine: String {
            switch rabbitHoleCount {
            case 0:  return "no rabbit holes\nyet."
            case 1:  return "through 1\nrabbit hole."
            default: return "through \(rabbitHoleCount)\nrabbit holes."
            }
        }

        var body: some View {
            Button(action: { print("re:log widget tapped") }) {
                ZStack {

                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(hex: "#F5F0E8").opacity(0.88))

                    RoundedRectangle(cornerRadius: 20)
                        .stroke(DSColor.ink.opacity(0.38), lineWidth: 1)

                    VStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.45), Color.clear],
                                    startPoint: UnitPoint.top,
                                    endPoint: UnitPoint(x: 0.5, y: 0.08)
                                )
                            )
                            .frame(height: 32)
                        Spacer()
                    }

                    HStack(alignment: .center, spacing: 0) {

                        VStack(alignment: .leading, spacing: 0) {

                            Text("your mind\nwandered")
                                .font(.custom("InstrumentSerif-Italic", size: 27))
                                .foregroundColor(Color(hex: "#2C2825"))
                                .lineSpacing(1)
                                .fixedSize(horizontal: false, vertical: true)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 10)
                                .animation(.smooth.delay(0.24), value: appeared)

                            Spacer().frame(height: 8)

                            Text(rabbitHoleLine)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(Color(hex: "#2C2825").opacity(0.72))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .contentTransition(.numericText())
                                .animation(.smooth, value: rabbitHoleCount)
                                .opacity(appeared ? 1 : 0)
                                .offset(y: appeared ? 0 : 8)
                                .animation(.smooth.delay(0.30), value: appeared)
                        }
                        .padding(.leading, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ZStack {
                            MemoryCircle(seed: topicSeeds[0], size: 56, delay: 0.10)
                                .offset(x: -28, y: -36)
                            MemoryCircle(seed: topicSeeds[1], size: 46, delay: 0.16)
                                .offset(x: 14, y: -42)
                            MemoryCircle(seed: topicSeeds[2], size: 60, delay: 0.22)
                                .offset(x: -6, y: 2)
                            MemoryCircle(seed: topicSeeds[3], size: 48, delay: 0.28)
                                .offset(x: -36, y: 38)
                            MemoryCircle(seed: topicSeeds[4], size: 40, delay: 0.34)
                                .offset(x: 16, y: 34)
                        }
                        .frame(width: 120, height: 155)
                        .padding(.trailing, 48)
                        .opacity(appeared ? 1 : 0)
                        .animation(.smooth.delay(0.12), value: appeared)
                    }
                    .padding(.vertical, 20)

                    VStack {
                        HStack {
                            Spacer()
                            ChipCapsule(
                                text: "re:log",
                                variant: .filled(DSColor.highlightYellow)
                            )
                            .opacity(appeared ? 1 : 0)
                            .scaleEffect(appeared ? 1 : 0.88)
                            .animation(.spring(duration: 0.4, bounce: 0.15).delay(0.08), value: appeared)
                        }
                        Spacer()
                    }
                    .padding(.top, 13)
                    .padding(.trailing, 13)

                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.system(size: 13, weight: .light))
                                .foregroundColor(Color(hex: "#2C2825").opacity(0.55))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.65))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1))
                                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
                                .opacity(appeared ? 1 : 0)
                                .animation(.smooth.delay(0.38), value: appeared)
                                .accessibilityLabel("Open re:log")
                        }
                    }
                    .padding(.bottom, 13)
                    .padding(.trailing, 13)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .scaleEffect(appeared ? 1.0 : 0.94)
                .opacity(appeared ? 1.0 : 0)
                .animation(.smooth.delay(0.05), value: appeared)
                .scaleEffect(isPressed ? 0.97 : 1.0)
                .animation(.spring(duration: 0.25, bounce: 0.3), value: isPressed)
                .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded   { _ in isPressed = false }
            )
            .accessibilityLabel("re:log — \(rabbitHoleLine.replacingOccurrences(of: "\n", with: " ")) Tap to explore your curiosity trail.")
            .onAppear {
                withAnimation { appeared = true }
            }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Memory Circle
    // ─────────────────────────────────────────────

    struct MemoryCircle: View {
        let seed: String
        let size: CGFloat
        let delay: Double

        @State private var appeared = false
        @State private var isFloating = false

        private var floatAmount: CGFloat { (size - 40) * 0.18 + 1.5 }
        private var floatDuration: Double { 3.0 + Double(size) * 0.04 }

        var body: some View {
            AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/120/120")) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .empty, .failure:
                    Circle().fill(Color(hex: "#C8C2BA").opacity(0.5))
                @unknown default:
                    Circle().fill(Color(hex: "#C8C2BA").opacity(0.5))
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 2.5))
            .shadow(color: .black.opacity(0.08), radius: 5, x: 0, y: 2)
            .scaleEffect(appeared ? 1.0 : 0.3)
            .opacity(appeared ? 1.0 : 0)
            .animation(.spring(duration: 0.5, bounce: 0.3).delay(delay), value: appeared)
            .offset(y: isFloating ? -floatAmount : floatAmount)
            .animation(
                .easeInOut(duration: floatDuration)
                .repeatForever(autoreverses: true)
                .delay(delay * 0.5),
                value: isFloating
            )
            .onAppear { appeared = true; isFloating = true }
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Legacy Components
    // ─────────────────────────────────────────────

    struct ConstellationBubble: View {
        let seed: String; let size: CGFloat; let delay: Double
        @State private var isFloating = false
        private var floatAmount: CGFloat { (size - 36) * 0.25 + 1.5 }
        private var floatDuration: Double { 2.6 + Double(size) * 0.045 }
        var body: some View {
            AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/80/80")) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                case .empty, .failure: Circle().fill(Color(hex: "#D4CEC8").opacity(0.55))
                @unknown default: Circle().fill(Color(hex: "#D4CEC8").opacity(0.55))
                }
            }
            .frame(width: size, height: size).clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(0.09), radius: 5, x: 0, y: 2)
            .offset(y: isFloating ? -floatAmount : floatAmount)
            .animation(.easeInOut(duration: floatDuration).repeatForever(autoreverses: true).delay(delay), value: isFloating)
            .onAppear { isFloating = true }
        }
    }

    struct TopicCircle: View {
        let seed: String
        var body: some View {
            AsyncImage(url: URL(string: "https://picsum.photos/seed/\(seed)/80/80")) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                case .empty, .failure: Circle().fill(Color(hex: "#C0B8B0").opacity(0.5))
                @unknown default: Circle().fill(Color(hex: "#C0B8B0").opacity(0.5))
                }
            }
            .frame(width: 44, height: 44).clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Nav Bar
    // ─────────────────────────────────────────────

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
                                : Color(hex: "#2C2825").opacity(0.4)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                }
            }
            .padding(.horizontal, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(40)
            .overlay(
                Capsule()
                    .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 4)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: - Dashboard Grain
    // ─────────────────────────────────────────────

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

#Preview {
    DashboardView()
}
