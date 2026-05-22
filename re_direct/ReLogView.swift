import SwiftUI
import SwiftData

// ─────────────────────────────────────────────
// MARK: - Re:Log View
// ─────────────────────────────────────────────

struct ReLogView: View {

    @State private var revealed = false
    @State private var selectedTopic: ReDirectTopic? = nil
    @State private var showLogSheet = false

    var body: some View {
        GeometryReader { geo in
            ZStack {

                PaperBackground(variant: .warm)

                ReLogGrain()
                    .drawingGroup()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        Text("Re:Log")
                            .font(.custom("InstrumentSerif-Italic", size: 38))
                            .foregroundColor(Color(hex: "#1F1B18"))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, geo.safeAreaInsets.top + 10)
                            .padding(.bottom, 16)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 10)
                            .animation(.smooth.delay(0.05), value: revealed)

                        HStack {
                            Spacer()
                            Button {
                                showLogSheet = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .regular))
                                    Text("log a rabbit hole")
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
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 14)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 6)
                        .animation(.smooth.delay(0.10), value: revealed)

                        TopFiveSection(
                            topics: ReDirectTopicData.topFive,
                            revealed: revealed,
                            selectedTopic: $selectedTopic
                        )
                        .padding(.horizontal, 24)

                        if let topic = selectedTopic {
                            TopicDetailCard(topic: topic)
                                .padding(.horizontal, 24)
                                .padding(.top, 18)
                                .transition(
                                    .opacity
                                    .combined(with: .move(edge: .top))
                                    .combined(with: .scale(scale: 0.96))
                                )
                        }

                        RecentRabbitHolesSection(revealed: revealed)
                            .padding(.horizontal, 24)
                            .padding(.top, 26)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 12)
                            .animation(.smooth.delay(0.55), value: revealed)

                        ReflectionsSection(revealed: revealed)
                            .padding(.horizontal, 24)
                            .padding(.top, 22)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 12)
                            .animation(.smooth.delay(0.62), value: revealed)

                        BoundarySessionsSection(revealed: revealed)
                            .padding(.horizontal, 24)
                            .padding(.top, 22)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 12)
                            .animation(.smooth.delay(0.70), value: revealed)

                        ScreenTimeSection(revealed: revealed)
                            .padding(.horizontal, 24)
                            .padding(.top, 22)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 14)
                            .animation(.smooth.delay(0.85), value: revealed)

                        Spacer().frame(height: DSMetric.bottomNavClearance)
                    }
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .navigationBarHidden(true)
        .onAppear {
            withAnimation { revealed = true }
        }
        .sheet(isPresented: $showLogSheet) {
            LogRabbitHoleSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Log Rabbit Hole Input (testable)
// ─────────────────────────────────────────────

/// Pure data + validation for the "log a rabbit hole" flow.
/// Extracted so behavior can be tested without instantiating SwiftUI views
/// or SwiftData containers.
struct LogRabbitHoleInput: Equatable {
    var title: String = ""
    var methodSlug: String = "read"
    var durationMinutes: Int = 15

    static let canonicalMethodSlugs: [String] = [
        "watch", "read", "mini-game", "reflect", "deep-dive"
    ]

    static let durationChoices: [Int] = [5, 10, 15, 20, 30, 45, 60]

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        trimmedTitle.count >= 3
            && Self.canonicalMethodSlugs.contains(methodSlug)
            && durationMinutes > 0
    }

    func makeEngagement(at date: Date = Date()) -> CuriosityEngagement {
        let engagement = CuriosityEngagement()
        engagement.methodSlug = methodSlug
        engagement.contentTitle = trimmedTitle
        engagement.durationSeconds = durationMinutes * 60
        engagement.engagedAt = date
        return engagement
    }
}

// ─────────────────────────────────────────────
// MARK: - Log Rabbit Hole Sheet
// ─────────────────────────────────────────────

private struct LogRabbitHoleSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var input = LogRabbitHoleInput()
    @State private var savedId: UUID? = nil
    @FocusState private var titleFocused: Bool

    private let methodLabels: [(slug: String, label: String)] = [
        ("watch",     "Watch"),
        ("read",      "Read"),
        ("mini-game", "Mini Game"),
        ("reflect",   "Reflect"),
        ("deep-dive", "Deep Dive")
    ]

    var body: some View {
        ZStack {
            PaperBackground(variant: .warm)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {

                HStack {
                    Button("cancel") { dismiss() }
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(DSColor.ink.opacity(0.55))

                    Spacer()

                    Button("save") { save() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(input.isValid ? DSColor.ink : DSColor.ink.opacity(0.28))
                        .disabled(!input.isValid)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 22)

                Text("a rabbit hole, logged.")
                    .font(.custom("InstrumentSerif-Italic", size: 28))
                    .foregroundColor(DSColor.ink)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)

                titleField
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                methodPicker
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                durationPicker
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: savedId)
        .onAppear { titleFocused = true }
    }

    private var titleField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("what did you fall into?")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.55))
                .tracking(0.1)

            TextField(
                "e.g. why deep-sea creatures glow blue",
                text: $input.title,
                axis: .horizontal
            )
            .font(.custom("InstrumentSerif-Italic", size: 19))
            .foregroundColor(DSColor.ink)
            .submitLabel(.done)
            .focused($titleFocused)
            .onSubmit { if input.isValid { save() } }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.40))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var methodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("which lane?")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.55))
                .tracking(0.1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(methodLabels, id: \.slug) { entry in
                        chip(
                            label: entry.label,
                            isSelected: input.methodSlug == entry.slug
                        ) {
                            input.methodSlug = entry.slug
                        }
                    }
                }
            }
        }
    }

    private var durationPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("how long?")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.55))
                .tracking(0.1)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(LogRabbitHoleInput.durationChoices, id: \.self) { mins in
                        chip(
                            label: "\(mins)m",
                            isSelected: input.durationMinutes == mins
                        ) {
                            input.durationMinutes = mins
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundColor(isSelected ? .white : DSColor.ink)
                .background {
                    Capsule()
                        .fill(isSelected ? DSColor.ink.opacity(0.85) : Color.white.opacity(0.55))
                        .overlay {
                            Capsule()
                                .stroke(DSColor.ink.opacity(isSelected ? 0.45 : 0.25), lineWidth: 1)
                        }
                        .shadow(color: DSColor.ink.opacity(0.06),
                                radius: 0, x: 1, y: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func save() {
        guard input.isValid else { return }
        let engagement = input.makeEngagement()
        context.insert(engagement)
        try? context.save()
        savedId = engagement.id
        dismiss()
    }
}

// ─────────────────────────────────────────────
// MARK: - Top Five Section
// ─────────────────────────────────────────────

struct TopFiveSection: View {

    let topics: [ReDirectTopic]
    let revealed: Bool
    @Binding var selectedTopic: ReDirectTopic?

    private var tipText: String {
        guard let t = selectedTopic else {
            return "tip: click on one of the\npicture icons to see details"
        }
        return "showing: \(t.totalTime) on\n\(t.title.prefix(24))…"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            SectionHeader(title: "Top 5",
                          caption: "topics you've dived in",
                          captionAlignment: .trailing)
                .opacity(revealed ? 1 : 0)
                .offset(y: revealed ? 0 : 8)
                .animation(.smooth.delay(0.12), value: revealed)
                .padding(.bottom, 14)

            HStack {
                Spacer()
                Text(tipText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(DSColor.ink.opacity(0.78))
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(DSColor.highlightYellow.opacity(0.55))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(DSColor.ink.opacity(0.20), lineWidth: 1)
                            }
                            .shadow(color: DSColor.ink.opacity(0.12),
                                    radius: 0, x: 1.5, y: 1.5)
                    }
                    .frame(width: 148, alignment: .leading)
                    .opacity(revealed ? 1 : 0)
                    .animation(.smooth.delay(0.75), value: revealed)
                    .animation(.easeInOut(duration: 0.2), value: selectedTopic?.id)
            }
            .padding(.bottom, 6)

            HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                        let isSelected = selectedTopic?.id == topic.id
                        let hasSelection = selectedTopic != nil
                        let barDelay = 0.22 + Double(index) * 0.06

                        VStack(spacing: 10) {

                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(
                                        stops: [
                                            .init(color: Color(hex: topic.barColorHex).opacity(0.80), location: 0.0),
                                            .init(color: Color(hex: topic.barColorHex), location: 1.0)
                                        ],
                                        startPoint: UnitPoint.top,
                                        endPoint: UnitPoint.bottom
                                    )
                                )
                                .frame(height: revealed ? topic.barHeight : 0)
                                .padding(.horizontal, 4)
                                .opacity(hasSelection && !isSelected ? 0.55 : 1.0)
                                .shadow(
                                    color: .black.opacity(0.10),
                                    radius: isSelected ? 6 : 3,
                                    x: 0, y: 2
                                )
                                .animation(.spring(duration: 0.55, bounce: 0.15).delay(barDelay), value: revealed)
                                .animation(.spring(duration: 0.3, bounce: 0.2), value: selectedTopic?.id)

                            Button(action: {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                                    if selectedTopic?.id == topic.id {
                                        selectedTopic = nil
                                    } else {
                                        selectedTopic = topic
                                    }
                                }
                            }) {
                                ZStack {
                                    if isSelected {
                                        Circle()
                                            .fill(.thinMaterial)
                                            .overlay(
                                                Circle()
                                                    .fill(Color(hex: "#FFF8EC").opacity(0.55))
                                            )
                                            .frame(width: 36, height: 36)
                                            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
                                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                                    }

                                    AsyncImage(url: URL(string: topic.imageURL)) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().scaledToFill()
                                        case .empty, .failure:
                                            Circle().fill(Color(hex: "#C8C2BA").opacity(0.5))
                                        @unknown default:
                                            Circle().fill(Color(hex: "#C8C2BA").opacity(0.5))
                                        }
                                    }
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(
                                            DSColor.paperCream,
                                            lineWidth: 0.5
                                        )
                                    )
                                    .shadow(
                                        color: .black.opacity(isSelected ? 0.16 : 0.08),
                                        radius: isSelected ? 7 : 3,
                                        x: 0, y: isSelected ? 4 : 1
                                    )
                                }
                                .scaleEffect(isSelected ? 1.08 : 1.0)
                            }
                            .buttonStyle(TactileButtonStyle())
                            .opacity(revealed ? 1 : 0)
                            .scaleEffect(revealed ? 1 : 0.6)
                            .animation(.spring(duration: 0.45, bounce: 0.2).delay(barDelay + 0.28), value: revealed)
                            .animation(.spring(response: 0.38, dampingFraction: 0.88), value: selectedTopic?.id)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Topic Detail Card
// ─────────────────────────────────────────────

struct TopicDetailCard: View {
    let topic: ReDirectTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text(topic.title)
                .font(.custom("InstrumentSerif-Italic", size: 17))
                .foregroundColor(Color(hex: "#1F1B18"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                LiquidStatChip(text: "\(topic.articleCount) articles")
                LiquidStatChip(text: "\(topic.videoCount) videos")
                LiquidStatChip(text: topic.totalTime)
            }

            if !topic.platformStats.isEmpty {
                VStack(spacing: 8) {
                    ForEach(topic.platformStats) { stat in
                        HStack(spacing: 8) {
                            Text(stat.platform)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color(hex: "#2C2825").opacity(0.7))
                                .frame(width: 72, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(.thinMaterial)
                                        .overlay(
                                            Capsule()
                                                .fill(Color(hex: "#FFF8EC").opacity(0.5))
                                        )
                                        .overlay(
                                            Capsule()
                                                .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                                        )

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(hex: topic.barColorHex),
                                                    Color(hex: topic.barColorHex).opacity(0.75)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * stat.percentage)
                                        .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
                                }
                            }
                            .frame(height: 7)

                            Text(stat.timeSpent)
                                .font(.system(size: 11, weight: .light))
                                .foregroundColor(Color(hex: "#2C2825").opacity(0.55))
                                .frame(width: 44, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .fill(DSColor.paperCream)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.clear],
                                startPoint: UnitPoint.top,
                                endPoint: UnitPoint(x: 0.5, y: 0.12)
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                }
        }
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
    }
}

// ─────────────────────────────────────────────
// MARK: - Liquid Stat Chip
// ─────────────────────────────────────────────

struct LiquidStatChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(hex: "#2C2825").opacity(0.72))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule()
                            .fill(Color(hex: "#FFF8EC").opacity(0.45))
                    }
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.30), Color.clear],
                                    startPoint: UnitPoint.top,
                                    endPoint: UnitPoint(x: 0.5, y: 0.5)
                                )
                            )
                    }
                    .overlay {
                        Capsule()
                            .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                    }
            }
            .shadow(color: .black.opacity(0.045), radius: 5, x: 0, y: 2)
    }
}

// ─────────────────────────────────────────────
// MARK: - Recent Rabbit Holes Section
// ─────────────────────────────────────────────

/// A ledger of the user's most recent CuriosityEngagement rows. Read-only,
/// editorial-typography list — not a dashboard.
struct RecentRabbitHolesSection: View {

    let revealed: Bool

    @Query(
        filter: #Predicate<CuriosityEngagement> { $0.deletedAt == nil },
        sort: \.engagedAt,
        order: .reverse
    )
    private var engagements: [CuriosityEngagement]

    private var visibleRows: [CuriosityEngagement] {
        Array(engagements.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            SectionHeader(
                title: "Rabbit holes",
                caption: "what you've fallen into",
                captionAlignment: .trailing
            )
            .padding(.bottom, 12)

            if engagements.isEmpty {
                emptyState
            } else {
                populatedList
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("no rabbit holes logged yet.")
                .font(.custom("InstrumentSerif-Italic", size: 17))
                .foregroundColor(DSColor.ink.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            Text("tap + log above to record one.")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.45))
        }
        .padding(.vertical, 8)
    }

    private var populatedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleRows.enumerated()), id: \.element.id) { idx, engagement in
                if idx > 0 {
                    Rectangle()
                        .fill(DSColor.ink.opacity(0.12))
                        .frame(height: 0.5)
                }
                engagementRow(engagement)
            }
        }
    }

    @ViewBuilder
    private func engagementRow(_ engagement: CuriosityEngagement) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(engagement.contentTitle)
                .font(.custom("InstrumentSerif-Italic", size: 17))
                .foregroundColor(DSColor.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                methodChip(slug: engagement.methodSlug)
                Text(EngagementCaption.caption(for: engagement))
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(DSColor.ink.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func methodChip(slug: String) -> some View {
        Text(RecentRabbitHolesSection.displayLabel(for: slug))
            .font(.custom("InstrumentSerif-Italic", size: 11))
            .foregroundColor(DSColor.ink.opacity(0.72))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(Color(hex: "#FFFDF2").opacity(0.85))
                    .overlay {
                        Capsule()
                            .stroke(DSColor.ink.opacity(0.22), lineWidth: 0.5)
                    }
            }
    }

    /// Editorial lowercase label for a method slug. Static + pure so it can be
    /// unit-tested in isolation.
    static func displayLabel(for slug: String) -> String {
        switch slug {
        case "watch":     return "watch"
        case "read":      return "read"
        case "mini-game": return "mini game"
        case "reflect":   return "reflect"
        case "deep-dive": return "deep dive"
        default:          return slug
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Reflections Section
// ─────────────────────────────────────────────

/// Read-only ledger of the user's most recent `ReflectionEntry` rows. The
/// only writing surface is the REF2 reflect-method ritual; this section
/// surfaces what got saved. Tapping a row opens a paper-style detail sheet
/// for read-only viewing — no edit / delete / share.
struct ReflectionsSection: View {

    let revealed: Bool

    @Query(
        filter: #Predicate<ReflectionEntry> { $0.deletedAt == nil },
        sort: \.createdAt,
        order: .reverse
    )
    private var reflections: [ReflectionEntry]

    @State private var selectedReflection: ReflectionEntry? = nil

    private var visibleRows: [ReflectionEntry] {
        Array(reflections.prefix(5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            SectionHeader(
                title: "Reflections",
                caption: "what you wrote down",
                captionAlignment: .trailing
            )
            .padding(.bottom, 12)

            if reflections.isEmpty {
                emptyState
            } else {
                populatedList
            }
        }
        // Custom floating paper overlay — not a bottom sheet. Uses
        // `.fullScreenCover` with a clear presentation background so the
        // system layer is just transparent canvas; the popup renders its
        // own dim backdrop + centered card with fade-and-lift animation.
        .fullScreenCover(
            isPresented: Binding(
                get: { selectedReflection != nil },
                set: { presented in
                    if !presented { selectedReflection = nil }
                }
            )
        ) {
            if let entry = selectedReflection {
                FloatingReflectionPopup(
                    entry: entry,
                    onClose: { selectedReflection = nil }
                )
                .presentationBackground(.clear)
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("no reflections yet.")
                .font(.custom("InstrumentSerif-Italic", size: 17))
                .foregroundColor(DSColor.ink.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            Text("saved reflections appear here.")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.45))
        }
        .padding(.vertical, 8)
    }

    private var populatedList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(visibleRows.enumerated()), id: \.element.id) { idx, entry in
                if idx > 0 {
                    Rectangle()
                        .fill(DSColor.ink.opacity(0.12))
                        .frame(height: 0.5)
                }
                Button {
                    selectedReflection = entry
                } label: {
                    reflectionRow(entry)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Open reflection")
            }
        }
    }

    @ViewBuilder
    private func reflectionRow(_ entry: ReflectionEntry) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(ReflectionPreview.preview(entry.body))
                .font(.custom("InstrumentSerif-Italic", size: 17))
                .foregroundColor(DSColor.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Text(EngagementCaption.relativeDate(entry.createdAt))
                .font(.system(size: 11, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// ─────────────────────────────────────────────
// MARK: - Reflection Preview Helper
// ─────────────────────────────────────────────

/// Pure word-based truncation for reflection previews in Re:Log rows.
/// Extracted so the rule ("first N words; append `...` only when truncated")
/// can be unit-tested without exercising the view.
enum ReflectionPreview {

    /// Returns the body unchanged if it has `<= wordLimit` words; otherwise
    /// returns the first `wordLimit` words joined by single spaces with a
    /// trailing `...`. Whitespace and newlines are treated as word separators;
    /// leading/trailing whitespace is trimmed from the result.
    static func preview(_ body: String, wordLimit: Int = 12) -> String {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard wordLimit > 0 else { return trimmed }
        let words = trimmed.split(whereSeparator: { $0.isWhitespace })
        if words.count <= wordLimit { return trimmed }
        return words.prefix(wordLimit).joined(separator: " ") + "..."
    }
}

// ─────────────────────────────────────────────
// MARK: - Floating Reflection Popup
// ─────────────────────────────────────────────

/// Read-only floating paper card for viewing a saved `ReflectionEntry`.
/// Presented as a centered overlay (not a bottom sheet) over a dim backdrop,
/// with a fade-and-lift entrance and exit. No edit / delete / share.
///
/// When a `CuriosityEngagement` links back to this reflection (via
/// `engagement.reflection?.id == entry.id`), its `contentTitle` is shown
/// above the body as the original prompt, with the same per-line marker
/// highlight used on the REF2 ritual surface. If no link exists (e.g. a
/// future post-ritual reflection that doesn't attach), the prompt is
/// omitted gracefully — the body just sits at the top of the card.
struct FloatingReflectionPopup: View {

    let entry: ReflectionEntry
    let onClose: () -> Void

    @Query private var linkedEngagements: [CuriosityEngagement]

    @State private var visible = false

    init(entry: ReflectionEntry, onClose: @escaping () -> Void) {
        self.entry = entry
        self.onClose = onClose
        let entryId = entry.id
        _linkedEngagements = Query(
            filter: #Predicate<CuriosityEngagement> {
                $0.deletedAt == nil && $0.reflection?.id == entryId
            }
        )
    }

    private var promptText: String? {
        guard let title = linkedEngagements.first?.contentTitle,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return title
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dim backdrop. Tap to dismiss.
                Color.black
                    .opacity(visible ? 0.34 : 0.0)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { close() }

                // Floating paper card — sized to content, capped at 72% of
                // screen height. ViewThatFits picks the non-scrolling
                // variant when the content fits; otherwise the scrolling
                // variant is used and clamped by the maxHeight. This avoids
                // ScrollView's tendency to claim more vertical space than
                // its content needs (which was painting a ghost shadow).
                paperCard(maxHeight: geo.size.height * 0.72)
                    .padding(.horizontal, 24)
                    .scaleEffect(visible ? 1.0 : 0.96)
                    .opacity(visible ? 1.0 : 0.0)
                    .offset(y: visible ? 0 : 8)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            withAnimation(.smooth(duration: 0.32)) { visible = true }
        }
    }

    private func paperCard(maxHeight: CGFloat) -> some View {
        // The VStack inside `cardContents` is naturally content-sized — its
        // ideal height equals the sum of its children's heights. Painting
        // the background directly on it keeps the card visually tight.
        // `.frame(maxHeight:)` caps the whole thing; very long bodies clip
        // at the cap (real reflection bodies are short enough today that
        // this is acceptable for MVP — internal scroll for unusually long
        // bodies can be added back as a follow-on if needed).
        cardContents
            .background { cardBackground }
            .overlay(alignment: .topTrailing) { closeButton }
            .frame(maxHeight: maxHeight)
    }

    private var cardContents: some View {
        VStack(alignment: .leading, spacing: 14) {

            Text(EngagementCaption.relativeDate(entry.createdAt))
                .font(.system(size: 12, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.55))

            if let prompt = promptText {
                Text(prompt)
                    .font(.custom("InstrumentSerif-Italic", size: 20))
                    .foregroundColor(DSColor.inkSoft)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .lineSpacing(4)
                    .textRenderer(RelogLineHighlightRenderer(
                        color: DSColor.highlightYellow.opacity(0.7)
                    ))
                    .padding(.trailing, 36) // breathing room from ✕
                    .padding(.top, 2)
            }

            Text(entry.body)
                .font(.system(size: 17))
                .foregroundColor(DSColor.ink)
                .lineSpacing(4)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, promptText == nil ? 0 : 4)

            Text("local · not shared")
                .font(.system(size: 11, weight: .light).italic())
                .foregroundColor(DSColor.ink.opacity(0.45))
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 22)
    }

    private var cardBackground: some View {
        // Use Rectangle (a Shape that always fills its proposed frame with
        // no intrinsic aspect ratio) as the cream layer, with the paper
        // texture as an overlay on top. A previous ZStack-based version
        // picked up the Image's intrinsic portrait ratio and grew the card
        // beyond its host frame; Rectangle has no such preference.
        Rectangle()
            .fill(DSColor.paperCream)
            .overlay {
                Image("Paper Sheet")
                    .resizable()
                    .scaledToFill()
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: DSColor.ink.opacity(0.14),
                    radius: 0, x: 1.5, y: 1.5)
            .shadow(color: Color(red: 0.35, green: 0.25, blue: 0.22).opacity(0.10),
                    radius: 14, x: 0, y: 8)
    }

    private var closeButton: some View {
        Button {
            close()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(DSColor.ink.opacity(0.70))
                .frame(width: 30, height: 30)
                .background {
                    Circle()
                        .fill(DSColor.paperCream)
                        .overlay {
                            Circle()
                                .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
                        }
                        .shadow(color: DSColor.ink.opacity(0.10),
                                radius: 0, x: 1, y: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close reflection")
        .padding(.top, 12)
        .padding(.trailing, 12)
    }

    private func close() {
        withAnimation(.smooth(duration: 0.22)) { visible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onClose()
        }
    }
}

// `TextRenderer` that paints a flat marker-yellow swipe behind each rendered
// line of text. Local duplicate of the renderer used in
// `ReflectMethodRitualView` so REF2.6 doesn't need to alter that file's
// visibility. Behavior must stay identical.
private struct RelogLineHighlightRenderer: TextRenderer {
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
// MARK: - Boundary Sessions Section
// ─────────────────────────────────────────────

/// Honest local boundary-session telemetry. Reads TimerSession rows (the
/// model is boundary commitment, not curiosity engagement). Intentionally
/// avoids any Screen Time / DeviceActivity / app-usage framing.
///
/// "completed" is future system-driven: when DeviceActivity / a local-fallback
/// countdown lands, boundaries can complete automatically and that count
/// becomes meaningful. Today the only manual end path is "stop early"
/// (interrupted). The completed chip will read as 0 for installs that never
/// used the now-retired manual "done" button.
struct BoundarySessionsSection: View {

    let revealed: Bool

    @Query(filter: #Predicate<TimerSession> { $0.deletedAt == nil })
    private var sessions: [TimerSession]

    private var stats: BoundaryStats {
        BoundaryStats.compute(from: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            SectionHeader(
                title: "Boundary sessions",
                caption: "starts, completions, stops",
                captionAlignment: .trailing
            )
            .padding(.bottom, 12)

            if stats.total == 0 {
                emptyState
            } else {
                populatedState
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("no boundary sessions yet.")
                .font(.custom("InstrumentSerif-Italic", size: 17))
                .foregroundColor(DSColor.ink.opacity(0.70))
                .fixedSize(horizontal: false, vertical: true)

            Text("start a boundary to begin one.")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(DSColor.ink.opacity(0.45))
        }
        .padding(.vertical, 8)
    }

    private var populatedState: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(spacing: 6) {
                statChip(label: "\(stats.total) started")
                statChip(label: "\(stats.completed) completed")
                statChip(label: "\(stats.interrupted) stopped early")
            }

            if let last = stats.lastStartedRelative {
                Text("last started \(last).")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(DSColor.ink.opacity(0.50))
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func statChip(label: String) -> some View {
        Text(label)
            .font(.custom("InstrumentSerif-Italic", size: 12))
            .foregroundColor(DSColor.ink.opacity(0.78))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(Color(hex: "#FFFDF2").opacity(0.82))
                    .overlay {
                        Capsule()
                            .stroke(DSColor.ink.opacity(0.22), lineWidth: 0.5)
                    }
            }
    }
}

/// Pure aggregation over a list of (non-deleted) TimerSession rows. Extracted
/// for unit testing; the view holds no business logic beyond a single
/// `compute(from:)` call.
struct BoundaryStats: Equatable {
    let total: Int
    let active: Int
    let completed: Int
    let interrupted: Int
    let lastStartedAt: Date?
    let lastStartedRelative: String?

    static func compute(
        from sessions: [TimerSession],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> BoundaryStats {
        let live = sessions.filter { $0.isDeleted == false }
        let total = live.count
        let active = live.filter { $0.isActive }.count
        let completed = live.filter { $0.isCompleted }.count
        let interrupted = live.filter { $0.isInterrupted }.count
        let lastStart = live.map { $0.startedAt }.max()
        let lastRel = lastStart.map {
            EngagementCaption.relativeDate($0, now: now, calendar: calendar)
        }
        return BoundaryStats(
            total: total,
            active: active,
            completed: completed,
            interrupted: interrupted,
            lastStartedAt: lastStart,
            lastStartedRelative: lastRel
        )
    }
}

// ─────────────────────────────────────────────
// MARK: - Screen Time Section
// ─────────────────────────────────────────────

struct ScreenTimeSection: View {

    let revealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            SectionHeader(title: "Screen Time",
                          caption: "your average this week")
                .padding(.bottom, 14)

            ScreenTimeCard(revealed: revealed)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Screen Time Card
// ─────────────────────────────────────────────

struct ScreenTimeCard: View {

    let revealed: Bool

    @State private var cardVisible    = false
    @State private var timeVisible    = false
    @State private var arrowOffset: CGFloat = -4
    @State private var barsFilled     = false
    @State private var noteVisible    = false

    @State private var selectedRow: Int? = nil

    private let rowDetails = [
        "2h 10m  •  mostly after 9 PM",
        "45m  •  visual rabbit holes",
        "15m  •  news drift"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            HStack(alignment: .top) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("5h 15m")
                        .font(.custom("InstrumentSerif-Italic", size: 36))
                        .foregroundColor(Color(hex: "#1F1B18"))
                        .opacity(timeVisible ? 1 : 0)
                        .animation(.smooth.delay(0.0), value: timeVisible)

                    Image(systemName: "arrow.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(hex: "#6B9A6A"))
                        .offset(y: arrowOffset)
                        .opacity(timeVisible ? 1 : 0)
                        .animation(.spring(duration: 0.5, bounce: 0.35).delay(0.2), value: arrowOffset)
                        .animation(.smooth.delay(0.2), value: timeVisible)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text("last week")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(Color(hex: "#2C2825").opacity(0.45))
                    Text("6h 5m")
                        .font(.custom("InstrumentSerif-Regular", size: 20))
                        .foregroundColor(Color(hex: "#2C2825").opacity(0.65))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(DSColor.paperCream)
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(DSColor.ink.opacity(0.38), lineWidth: 1)
                        }
                        .shadow(color: DSColor.ink.opacity(0.10),
                                radius: 0, x: 1, y: 1)
                }
                .opacity(timeVisible ? 1 : 0)
                .animation(.smooth.delay(0.05), value: timeVisible)
            }

            VStack(spacing: 0) {
                AnimatedUsageRow(
                    index: 0,
                    name: "TikTok",
                    targetPercentage: 0.65,
                    displayLabel: "65%",
                    fillColor: AnyShapeStyle(Color(hex: "#9A9A9A")),
                    labelColor: .white,
                    isItalic: false,
                    fillDelay: 0.0,
                    detail: rowDetails[0],
                    isSelected: selectedRow == 0,
                    isFocused: selectedRow != nil,
                    barsFilled: barsFilled,
                    onTap: {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            selectedRow = selectedRow == 0 ? nil : 0
                        }
                    }
                )

                Divider()
                    .opacity(0.08)
                    .padding(.vertical, 2)

                AnimatedUsageRow(
                    index: 1,
                    name: "Instagram",
                    targetPercentage: 0.25,
                    displayLabel: "25%",
                    fillColor: AnyShapeStyle(
                        LinearGradient(
                            colors: [Color(hex: "#D4849A"), Color(hex: "#E8B87A")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    ),
                    labelColor: .white,
                    isItalic: true,
                    fillDelay: 0.08,
                    detail: rowDetails[1],
                    isSelected: selectedRow == 1,
                    isFocused: selectedRow != nil,
                    barsFilled: barsFilled,
                    onTap: {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            selectedRow = selectedRow == 1 ? nil : 1
                        }
                    }
                )

                Divider()
                    .opacity(0.08)
                    .padding(.vertical, 2)

                AnimatedUsageRow(
                    index: 2,
                    name: "X",
                    targetPercentage: 0.10,
                    displayLabel: "10%",
                    fillColor: AnyShapeStyle(Color(hex: "#1A1A1A")),
                    labelColor: .white,
                    isItalic: false,
                    fillDelay: 0.16,
                    detail: rowDetails[2],
                    isSelected: selectedRow == 2,
                    isFocused: selectedRow != nil,
                    barsFilled: barsFilled,
                    onTap: {
                        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                            selectedRow = selectedRow == 2 ? nil : 2
                        }
                    }
                )
            }

            Text("Keep it up! You've spent 2h 10m of deep diving this week. That's 25% more than last week.")
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(DSColor.inkSoft.opacity(0.8))
                .lineSpacing(1.5)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(DSColor.highlightYellowPaper)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(DSColor.ink.opacity(0.20), lineWidth: 1)
                )
                .shadow(color: DSColor.ink.opacity(0.12), radius: 0, x: 1.5, y: 1.5)
                .opacity(noteVisible ? 1 : 0)
                .offset(y: noteVisible ? 0 : 8)
                .animation(.smooth, value: noteVisible)
        }
        .padding(16)
        .background(Color(hex: "#FDFAF6"))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.07), radius: 8, x: 0, y: 3)
        .opacity(cardVisible ? 1 : 0)
        .offset(y: cardVisible ? 0 : 12)
        .animation(.smooth, value: cardVisible)
        .onChange(of: revealed) { _, newValue in
            guard newValue else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                cardVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                timeVisible = true
                withAnimation(.spring(duration: 0.5, bounce: 0.35)) {
                    arrowOffset = 0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.easeOut(duration: 0.5)) {
                    barsFilled = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                withAnimation(.smooth) {
                    noteVisible = true
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Animated Usage Row
// ─────────────────────────────────────────────

struct AnimatedUsageRow: View {
    let index: Int
    let name: String
    let targetPercentage: Double
    let displayLabel: String
    let fillColor: AnyShapeStyle
    let labelColor: Color
    var isItalic: Bool = false
    var fillDelay: Double = 0
    let detail: String
    let isSelected: Bool
    let isFocused: Bool
    let barsFilled: Bool
    let onTap: () -> Void

    @State private var sweepOffset: CGFloat = -1.0
    @State private var sweepVisible = false

    private var currentPercentage: Double {
        barsFilled ? targetPercentage : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(spacing: 8) {

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(hex: "#2C2825").opacity(0.06))
                            .overlay(
                                Capsule().stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1)
                            )

                        Capsule()
                            .fill(fillColor)
                            .frame(width: max(geo.size.width * currentPercentage, currentPercentage > 0 ? 70 : 0))
                            .overlay(alignment: .leading) {
                                if currentPercentage > 0.05 {
                                    Text(name)
                                        .font(isItalic
                                            ? .system(size: 14, weight: .medium).italic()
                                            : .system(size: 14, weight: .medium))
                                        .foregroundColor(labelColor)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .padding(.leading, 14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .opacity(currentPercentage > 0.08 ? 1 : 0)
                                        .animation(.easeIn(duration: 0.15), value: currentPercentage)
                                }
                            }
                            .overlay(alignment: .leading) {
                                if index == 0 && sweepVisible {
                                    Rectangle()
                                        .fill(
                                            LinearGradient(
                                                colors: [.clear, Color.white.opacity(0.28), .clear],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: 40)
                                        .offset(x: sweepOffset * geo.size.width)
                                        .clipped()
                                        .allowsHitTesting(false)
                                }
                            }
                            .animation(.easeOut(duration: 0.5).delay(fillDelay), value: currentPercentage)
                    }
                    .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
                }
                .frame(height: isSelected ? 36 : 32)
                .animation(.spring(duration: 0.3, bounce: 0.15), value: isSelected)

                Text(displayLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(
                        isSelected
                            ? Color(hex: "#1F1B18")
                            : Color(hex: "#2C2825").opacity(0.58)
                    )
                    .frame(width: 38, alignment: .trailing)
                    .animation(.spring(duration: 0.25, bounce: 0.1), value: isSelected)
            }
            .padding(.vertical, 6)
            .opacity(isFocused && !isSelected ? 0.45 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .scaleEffect(isSelected ? 1.015 : 1.0, anchor: .leading)
            .animation(.spring(duration: 0.3, bounce: 0.15), value: isSelected)
            .contentShape(Rectangle())
            .onTapGesture { onTap() }

            if isSelected {
                Text(detail)
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(Color(hex: "#2C2825").opacity(0.55))
                    .padding(.leading, 4)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onChange(of: barsFilled) { _, filled in
            guard filled && index == 0 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                sweepVisible = true
                withAnimation(.easeInOut(duration: 0.6)) {
                    sweepOffset = 1.2
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    sweepVisible = false
                    sweepOffset = -1.0
                }
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Tactile Button Style
// ─────────────────────────────────────────────

struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.35), value: configuration.isPressed)
    }
}

// ─────────────────────────────────────────────
// MARK: - Legacy Helpers
// ─────────────────────────────────────────────

struct AppUsageRow: View {
    let name: String
    let percentage: Double
    let label: String
    let barColor: AnyShapeStyle
    var isItalic: Bool = false
    var darkLabel: Bool = false
    var body: some View {
        HStack(spacing: 10) {
            Text(name)
                .font(isItalic ? .system(size: 13).italic() : .system(size: 13))
                .foregroundColor(darkLabel ? .white : Color(hex: "#2C2825"))
                .padding(.horizontal, 12).padding(.vertical, 5)
                .background(darkLabel ? AnyShapeStyle(Color(hex: "#1A1A1A")) : AnyShapeStyle(Color(hex: "#2C2825").opacity(0.08)))
                .clipShape(Capsule()).frame(width: 90, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "#2C2825").opacity(0.07))
                    Capsule().fill(barColor).frame(width: geo.size.width * percentage)
                }
            }.frame(height: 7)
            Text(label).font(.system(size: 12, weight: .light))
                .foregroundColor(Color(hex: "#2C2825").opacity(0.55))
                .frame(width: 36, alignment: .trailing)
        }
    }
}

struct ReLogNavBar: View {
    private let icons = ["leaf.fill","clock.fill","hourglass","waveform.path.ecg","gearshape.fill"]
    private let selectedIndex = 3
    var body: some View {
        HStack(spacing: 0) {
            ForEach(icons.indices, id: \.self) { index in
                ZStack {
                    if index == selectedIndex {
                        Circle().fill(Color(hex: "#2C2825")).frame(width: 44, height: 44)
                    }
                    Image(systemName: icons[index])
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(index == selectedIndex ? .white : Color(hex: "#2C2825").opacity(0.4))
                }
                .frame(maxWidth: .infinity).frame(height: 56)
            }
        }
        .padding(.horizontal, 8).background(.ultraThinMaterial).cornerRadius(40)
        .overlay(Capsule().stroke(Color(hex: "#1F1B18").opacity(0.38), lineWidth: 1))
        .shadow(color: .black.opacity(0.07), radius: 16, x: 0, y: 4)
    }
}

// ─────────────────────────────────────────────
// MARK: - Re:Log Grain + RNG
// ─────────────────────────────────────────────

struct ReLogGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = ReLogRNG(seed: 42)
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

struct ReLogRNG: RandomNumberGenerator {
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
    ReLogView()
}
