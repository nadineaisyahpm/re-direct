import SwiftUI
import SwiftData

// ─────────────────────────────────────────────
// MARK: - Rabbit Hole View (RH3-C: read-only data)
// ─────────────────────────────────────────────

/// Tab-1 surface. RH3-C turns the RH3-B shell into a read-only overview
/// of the user's curiosity threads:
///
/// - **Today card** — first thread by `lastEngagedAt`, colored by the
///   currently active redirect method (from `ActiveMethodStore`).
/// - **Your threads** — next 3 open/resting threads, with left accent bars.
/// - **Loose ends** — most recent unthreaded `CuriosityEngagement` rows,
///   each with an inert `thread?` pill (wired in RH3-E).
/// - **Empty state** — when no threads and no loose ends exist.
/// - **Loose-only state** — when loose ends exist but no threads yet.
///
/// Invariants honored (load-bearing):
/// - `ReflectionEntry.body` **never appears** on this screen, by construction.
///   The preview sheet renders `EngagementPreviewRowModel` values only, and
///   that model structurally excludes reflection text — the privacy
///   guarantee is enforced at the type level, not by review.
/// - `TimerSession` / `TimerView` are not referenced here.
/// - No thread creation, attachment, edit, or delete in RH3-C. The
///   `+ new thread` capsule and the loose-end `thread?` pill are inert.
struct RabbitHoleView: View {

    // MARK: Queries

    /// Live, non-deleted, non-closed threads sorted by most-recently
    /// engaged. The query returns `.open` and `.resting` threads (and any
    /// future unknown status); closed threads are hidden by design.
    @Query(
        filter: #Predicate<RabbitHoleThread> {
            $0.deletedAt == nil && $0.statusRaw != "closed"
        },
        sort: \.lastEngagedAt,
        order: .reverse
    ) private var threads: [RabbitHoleThread]

    /// Live, non-deleted engagements that are not part of any thread.
    /// These are the "loose ends" — candidate seeds for future threads.
    @Query(
        filter: #Predicate<CuriosityEngagement> {
            $0.deletedAt == nil && $0.thread == nil
        },
        sort: \.engagedAt,
        order: .reverse
    ) private var looseEnds: [CuriosityEngagement]

    @Environment(ActiveMethodStore.self) private var activeMethodStore
    @Environment(\.modelContext) private var modelContext

    @State private var revealed: Bool = false
    @State private var selectedThread: RabbitHoleThread? = nil
    @State private var showCreateSheet: Bool = false
    @State private var attachingEngagement: CuriosityEngagement? = nil

    // MARK: Derived view state

    private var mode: RabbitHoleMode {
        RabbitHoleMode.resolve(threadCount: threads.count, looseCount: looseEnds.count)
    }

    private var todayThread: RabbitHoleThread? { threads.first }

    private var listThreads: [RabbitHoleThread] {
        Array(threads.dropFirst().prefix(3))
    }

    private var overflowCount: Int {
        max(0, threads.count - 4)
    }

    private var visibleLooseEnds: [CuriosityEngagement] {
        Array(looseEnds.prefix(3))
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            ZStack {

                PaperBackground(variant: .warm)

                ReLogGrain()
                    .drawingGroup()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        // Title
                        Text("rabbit hole")
                            .font(.custom("InstrumentSerif-Italic", size: 38))
                            .foregroundColor(DSColor.ink)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, geo.safeAreaInsets.top + 10)
                            .padding(.bottom, 14)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 10)
                            .animation(.smooth.delay(0.05), value: revealed)

                        // + new thread capsule — opens the creation sheet.
                        HStack {
                            Spacer()
                            NewThreadCapsule { showCreateSheet = true }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 18)
                        .opacity(revealed ? 1 : 0)
                        .offset(y: revealed ? 0 : 6)
                        .animation(.smooth.delay(0.10), value: revealed)

                        // Content by mode
                        Group {
                            switch mode {
                            case .empty:
                                emptyInvitation
                            case .looseOnly:
                                looseEndsOnly
                            case .populated:
                                populatedContent
                            }
                        }
                        .padding(.horizontal, 24)

                        Spacer().frame(height: DSMetric.bottomNavClearance)
                    }
                }
            }
            .ignoresSafeArea()
            .onAppear { revealed = true }
            .sheet(item: $selectedThread) { thread in
                ThreadPreviewSheet(thread: thread)
            }
            .sheet(isPresented: $showCreateSheet) {
                NewRabbitHoleThreadSheet()
            }
            .sheet(item: $attachingEngagement) { engagement in
                AttachToThreadSheet(engagement: engagement)
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Empty state

    private var emptyInvitation: some View {
        VStack {
            Spacer(minLength: 24)
            EmptyStateBlock { showCreateSheet = true }
            Spacer(minLength: 0)
        }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 8)
        .animation(.smooth.delay(0.18), value: revealed)
    }

    // MARK: - Loose-only state

    private var looseEndsOnly: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "loose ends",
                caption: "these could become threads."
            )

            VStack(spacing: 0) {
                ForEach(Array(visibleLooseEnds.enumerated()), id: \.element.id) { idx, engagement in
                    if idx > 0 {
                        Rectangle()
                            .fill(DSColor.ink.opacity(0.08))
                            .frame(height: 0.5)
                    }
                    LooseEndRow(engagement: engagement) {
                        attachingEngagement = engagement
                    }
                }
            }
            .padding(.top, 4)
        }
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 8)
        .animation(.smooth.delay(0.22), value: revealed)
    }

    // MARK: - Populated state

    @ViewBuilder
    private var populatedContent: some View {
        if let today = todayThread {
            TodayCard(
                thread: today,
                activeMethodSlug: activeMethodStore.activeRedirectMethodSlug,
                onTap: { selectedThread = today }
            )
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 8)
            .animation(.smooth.delay(0.18), value: revealed)
        }

        if !listThreads.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "your threads",
                    caption: "open arcs"
                )

                VStack(spacing: 0) {
                    ForEach(Array(listThreads.enumerated()), id: \.element.id) { idx, thread in
                        if idx > 0 {
                            Rectangle()
                                .fill(DSColor.ink.opacity(0.10))
                                .frame(height: 0.5)
                        }
                        ThreadListRow(thread: thread) {
                            selectedThread = thread
                        }
                    }
                }
                .padding(.top, 4)

                if let overflow = ThreadOverflowCopy.display(overflowCount) {
                    Text(overflow)
                        .font(.custom("InstrumentSerif-Italic", size: 12))
                        .foregroundColor(DSColor.inkSoft.opacity(0.45))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 18)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 8)
            .animation(.smooth.delay(0.26), value: revealed)
        }

        if !visibleLooseEnds.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionHeader(
                    title: "loose ends",
                    caption: "unthreaded"
                )

                VStack(spacing: 0) {
                    ForEach(Array(visibleLooseEnds.enumerated()), id: \.element.id) { idx, engagement in
                        if idx > 0 {
                            Rectangle()
                                .fill(DSColor.ink.opacity(0.08))
                                .frame(height: 0.5)
                        }
                        LooseEndRow(engagement: engagement) {
                        attachingEngagement = engagement
                    }
                    }
                }
                .padding(.top, 4)
            }
            .padding(.top, 18)
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 8)
            .animation(.smooth.delay(0.34), value: revealed)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Today Card
// ─────────────────────────────────────────────

private struct TodayCard: View {
    let thread: RabbitHoleThread
    let activeMethodSlug: String?
    let onTap: () -> Void

    private var cardHex: String {
        RabbitHoleColorPalette.cardHex(forActiveSlug: activeMethodSlug)
    }

    private var usesLightText: Bool {
        RabbitHoleColorPalette.usesLightText(forHex: cardHex)
    }

    private var primaryTextColor: Color {
        usesLightText
            ? Color(hex: "#FFF8EC").opacity(0.95)
            : DSColor.ink
    }

    private var secondaryTextColor: Color {
        usesLightText
            ? Color(hex: "#FFF8EC").opacity(0.55)
            : DSColor.inkSoft.opacity(0.55)
    }

    private var dotColor: Color {
        usesLightText
            ? Color(hex: "#FFF8EC").opacity(0.30)
            : DSColor.ink.opacity(0.22)
    }

    private var displayTitle: String {
        thread.title.isEmpty ? "untitled thread" : thread.title
    }

    private var dateString: String {
        EngagementCaption.relativeDate(thread.lastEngagedAt ?? thread.createdAt)
    }

    private var stepText: String {
        ThreadStepCount.display(thread.engagements.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            HStack(alignment: .center, spacing: 7) {
                Text("continue")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(0.14 * 10)
                    .foregroundColor(secondaryTextColor)
                    .textCase(.uppercase)

                Spacer(minLength: 0)

                if let chipLabel = activeMethodChipLabel {
                    Text(chipLabel)
                        .font(.custom("InstrumentSerif-Italic", size: 11))
                        .foregroundColor(secondaryTextColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(usesLightText
                                      ? Color.white.opacity(0.12)
                                      : Color.white.opacity(0.55))
                                .overlay {
                                    Capsule()
                                        .stroke(usesLightText
                                                ? Color.white.opacity(0.20)
                                                : DSColor.ink.opacity(0.22),
                                                lineWidth: 0.75)
                                }
                        }
                }
            }
            .padding(.bottom, 8)

            Text(displayTitle)
                .font(.custom("InstrumentSerif-Italic", size: 21))
                .foregroundColor(primaryTextColor)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                .padding(.bottom, 10)

            HStack(alignment: .center, spacing: 7) {
                Text(stepText)
                Circle()
                    .fill(dotColor)
                    .frame(width: 3, height: 3)
                Text(dateString)
                if thread.status == .resting {
                    Circle()
                        .fill(dotColor)
                        .frame(width: 3, height: 3)
                    Text("resting")
                }
            }
            .font(.system(size: 11))
            .foregroundColor(secondaryTextColor)
            .padding(.bottom, 14)

            Button(action: onTap) {
                HStack {
                    Text("pick up here")
                        .font(.custom("InstrumentSerif-Italic", size: 15))
                        .foregroundColor(usesLightText
                                         ? Color(hex: "#FFF8EC").opacity(0.92)
                                         : DSColor.ink.opacity(0.92))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(usesLightText
                                         ? Color(hex: "#FFF8EC").opacity(0.78)
                                         : DSColor.ink.opacity(0.70))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(usesLightText
                              ? Color.white.opacity(0.13)
                              : Color.white.opacity(0.70))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(usesLightText
                                        ? Color.white.opacity(0.22)
                                        : DSColor.ink.opacity(0.30),
                                        lineWidth: 1)
                        }
                        .shadow(color: DSColor.ink.opacity(usesLightText ? 0 : 0.08),
                                radius: 0, x: 1, y: 1)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: thread.id)
            .accessibilityLabel("Continue thread: \(displayTitle). \(stepText).")
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(hex: cardHex))
                .overlay {
                    // Top shine edge — subtle highlight on the cinematic cards
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                }
                .shadow(color: DSColor.ink.opacity(0.18),
                        radius: 0, x: 2, y: 2)
                .shadow(color: usesLightText
                        ? Color.black.opacity(0.28)
                        : DSColor.ink.opacity(0.12),
                        radius: 14, x: 0, y: 12)
        }
    }

    /// Reads the active method label from the canonical RedirectRitual
    /// samples. Hidden when no active method is set.
    private var activeMethodChipLabel: String? {
        guard let slug = activeMethodSlug,
              let lane = RedirectRitual.samples.first(where: { $0.id == slug })
        else { return nil }
        return lane.label.lowercased()
    }
}

// ─────────────────────────────────────────────
// MARK: - Thread List Row
// ─────────────────────────────────────────────

private struct ThreadListRow: View {
    let thread: RabbitHoleThread
    let onTap: () -> Void

    private var accentColor: Color {
        switch thread.status {
        case .open:     return Color(hex: "#1B4D4A").opacity(0.75)
        case .resting:  return Color(hex: "#B8A8B0")
        default:        return DSColor.ink.opacity(0.22)
        }
    }

    private var displayTitle: String {
        thread.title.isEmpty ? "untitled thread" : thread.title
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 2.5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.custom("InstrumentSerif-Italic", size: 15))
                        .foregroundColor(DSColor.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if thread.status == .resting {
                            Text("resting")
                                .font(.system(size: 10))
                                .foregroundColor(DSColor.ink.opacity(0.60))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 1)
                                .background {
                                    Capsule()
                                        .fill(Color(hex: "#B8A8B0").opacity(0.22))
                                        .overlay {
                                            Capsule()
                                                .stroke(Color(hex: "#B8A8B0").opacity(0.50),
                                                        lineWidth: 0.5)
                                        }
                                }
                        }

                        Text(ThreadStepCount.display(thread.engagements.count))
                        Circle()
                            .fill(DSColor.ink.opacity(0.22))
                            .frame(width: 2, height: 2)
                        Text(EngagementCaption.relativeDate(
                            thread.lastEngagedAt ?? thread.createdAt
                        ))
                    }
                    .font(.system(size: 10))
                    .foregroundColor(DSColor.inkSoft.opacity(0.55))
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Thread: \(displayTitle), \(ThreadStepCount.display(thread.engagements.count))")
    }
}

// ─────────────────────────────────────────────
// MARK: - Loose End Row
// ─────────────────────────────────────────────

private struct LooseEndRow: View {
    let engagement: CuriosityEngagement
    let onAttach: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(engagement.contentTitle)
                .font(.custom("InstrumentSerif-Italic", size: 13))
                .foregroundColor(DSColor.ink.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            // "thread?" pill — opens the attach-to-thread sheet (RH3-E).
            Button(action: onAttach) {
                Text("thread?")
                    .font(.custom("InstrumentSerif-Italic", size: 10))
                    .foregroundColor(DSColor.ink.opacity(0.55))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background {
                        Capsule()
                            .fill(DSColor.highlightYellowSoft.opacity(0.55))
                            .overlay {
                                Capsule()
                                    .stroke(DSColor.ink.opacity(0.14), lineWidth: 0.5)
                            }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add '\(engagement.contentTitle)' to a thread")
        }
        .padding(.vertical, 9)
    }
}

// ─────────────────────────────────────────────
// MARK: - Thread Preview Sheet
// ─────────────────────────────────────────────

/// Bottom sheet showing a thread's engagements, read-only.
///
/// **Privacy invariant:** rows render `EngagementPreviewRowModel` only.
/// That model structurally excludes `ReflectionEntry.body` — the sheet
/// physically cannot display reflection text.
///
/// **Memory cap:** displays at most `engagementDisplayCap` rows even if
/// the thread has more engagements. Overflow surfaces as a quiet
/// footnote rather than as a paginated list. Keeps the SwiftData fault
/// + view allocation bounded regardless of thread size.
struct ThreadPreviewSheet: View {
    let thread: RabbitHoleThread

    /// Hard cap on rows rendered inside the sheet. RH3-C is read-only;
    /// a user with more than this many steps in one thread sees the most
    /// recent N + a "showing first N of M" footnote. The full list will
    /// land in the future thread-detail screen (a later slice).
    static let engagementDisplayCap: Int = 25

    private var sortedEngagements: [CuriosityEngagement] {
        Array(
            thread.engagements
                .sorted { $0.engagedAt > $1.engagedAt }
                .prefix(Self.engagementDisplayCap)
        )
    }

    private var overflowCount: Int {
        max(0, thread.engagements.count - Self.engagementDisplayCap)
    }

    /// Pure helper for the overflow footnote inside the sheet. Lifted so
    /// the message text can be unit-tested without mounting a view.
    static func overflowFootnote(shown: Int, total: Int) -> String {
        "showing the latest \(shown) of \(total) steps"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            VStack(alignment: .leading, spacing: 6) {
                Text(thread.title.isEmpty ? "untitled thread" : thread.title)
                    .font(.custom("InstrumentSerif-Italic", size: 24))
                    .foregroundColor(DSColor.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    Text(ThreadStepCount.display(thread.engagements.count))
                    Circle()
                        .fill(DSColor.ink.opacity(0.22))
                        .frame(width: 2, height: 2)
                    Text(EngagementCaption.relativeDate(
                        thread.lastEngagedAt ?? thread.createdAt
                    ))
                    if thread.status == .resting {
                        Circle()
                            .fill(DSColor.ink.opacity(0.22))
                            .frame(width: 2, height: 2)
                        Text("resting")
                    }
                }
                .font(.system(size: 11))
                .foregroundColor(DSColor.inkSoft.opacity(0.55))
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Rectangle()
                .fill(DSColor.ink.opacity(0.10))
                .frame(height: 0.5)

            // Engagement list
            ScrollView {
                if sortedEngagements.isEmpty {
                    VStack(spacing: 8) {
                        Text("no steps logged yet.")
                            .font(.custom("InstrumentSerif-Italic", size: 16))
                            .foregroundColor(DSColor.ink.opacity(0.55))
                        Text("steps will appear here as you log them.")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(DSColor.inkSoft.opacity(0.45))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(sortedEngagements.enumerated()), id: \.element.id) { idx, eng in
                            if idx > 0 {
                                Rectangle()
                                    .fill(DSColor.ink.opacity(0.08))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 24)
                            }
                            EngagementPreviewRow(
                                model: EngagementPreviewRowModel(eng)
                            )
                        }

                        if overflowCount > 0 {
                            Text(ThreadPreviewSheet.overflowFootnote(
                                shown: sortedEngagements.count,
                                total: thread.engagements.count
                            ))
                            .font(.custom("InstrumentSerif-Italic", size: 12))
                            .foregroundColor(DSColor.inkSoft.opacity(0.45))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 14)
                        }
                    }
                }
            }
        }
        .background {
            PaperBackground(variant: .warm).ignoresSafeArea()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

/// Renders a single engagement row inside the preview sheet. Takes a
/// `EngagementPreviewRowModel`, not the raw model, to make it
/// structurally impossible to display reflection text.
private struct EngagementPreviewRow: View {
    let model: EngagementPreviewRowModel

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.title)
                    .font(.custom("InstrumentSerif-Italic", size: 15))
                    .foregroundColor(DSColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    Text(model.methodSlug)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(DSColor.ink.opacity(0.65))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 1)
                        .background {
                            Capsule()
                                .fill(Color.white.opacity(0.55))
                                .overlay {
                                    Capsule()
                                        .stroke(DSColor.ink.opacity(0.18),
                                                lineWidth: 0.5)
                                }
                        }
                    Text(model.dateCaption)
                        .font(.system(size: 10))
                        .foregroundColor(DSColor.inkSoft.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 11)
    }
}

// ─────────────────────────────────────────────
// MARK: - Engagement Preview Row Model (privacy-safe)
// ─────────────────────────────────────────────

/// Display model for engagement rows inside `ThreadPreviewSheet`.
///
/// **By construction this model contains only fields safe to display on
/// the Rabbit Hole surface.** Notably it has no reference to
/// `ReflectionEntry`, no `body` field, no derived reflection text. A
/// future change cannot accidentally leak reflection content through
/// this row — the type itself doesn't carry the data.
///
/// If a future slice needs to surface additional engagement fields here,
/// add them explicitly to this struct. Reflection bodies are forbidden
/// per `docs/RABBIT_HOLE_THREADS.md §13`.
struct EngagementPreviewRowModel: Equatable, Sendable {
    let id: UUID
    let title: String
    let methodSlug: String
    let dateCaption: String

    init(id: UUID, title: String, methodSlug: String, dateCaption: String) {
        self.id = id
        self.title = title
        self.methodSlug = methodSlug
        self.dateCaption = dateCaption
    }

    init(_ engagement: CuriosityEngagement, now: Date = .now) {
        self.id = engagement.id
        self.title = engagement.contentTitle
        self.methodSlug = engagement.methodSlug
        self.dateCaption = EngagementCaption.relativeDate(engagement.engagedAt, now: now)
    }
}

// ─────────────────────────────────────────────
// MARK: - + new thread capsule
// ─────────────────────────────────────────────

/// Visual twin of `ReLogView`'s "log a rabbit hole" capsule. Wired in
/// RH3-D to present `NewRabbitHoleThreadSheet`.
private struct NewThreadCapsule: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
    }
}

// ─────────────────────────────────────────────
// MARK: - Empty state
// ─────────────────────────────────────────────

private struct EmptyStateBlock: View {
    let onCTA: () -> Void

    var body: some View {
        VStack(spacing: 14) {
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

            Button(action: onCTA) {
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
            .accessibilityLabel(RabbitHoleEmptyCopy.cta)
        }
        .padding(.horizontal, 28)
        .padding(.top, 40)
    }
}

// ─────────────────────────────────────────────
// MARK: - Pure helpers (testable)
// ─────────────────────────────────────────────

/// Three-way state for the Rabbit Hole overview.
enum RabbitHoleMode: Equatable, Sendable {
    /// No threads, no loose ends → render the empty-state invitation.
    case empty
    /// No threads but loose ends exist → render only the loose-ends list
    /// with the "these could become threads." caption.
    case looseOnly
    /// At least one thread exists → render today card + (optional) list
    /// + (optional) loose ends.
    case populated

    static func resolve(threadCount: Int, looseCount: Int) -> RabbitHoleMode {
        if threadCount > 0 { return .populated }
        if looseCount > 0 { return .looseOnly }
        return .empty
    }
}

/// `"1 step"` / `"N steps"` formatter.
enum ThreadStepCount {
    static func display(_ count: Int) -> String {
        count == 1 ? "1 step" : "\(count) steps"
    }
}

/// Overflow hint copy under the "your threads" list. Returns `nil` when
/// no overflow exists so callers can hide the row entirely.
enum ThreadOverflowCopy {
    static func display(_ count: Int) -> String? {
        guard count > 0 else { return nil }
        return count == 1 ? "and 1 more arc" : "and \(count) more arcs"
    }
}

/// Pure helpers for resolving the today card's color treatment from the
/// currently active redirect method.
enum RabbitHoleColorPalette {
    /// Returns the hex code that should fill the today card background
    /// for a given active method slug. Falls back to paper cream when no
    /// slug is provided or the slug is unrecognized.
    static func cardHex(forActiveSlug slug: String?) -> String {
        guard let slug,
              let lane = RedirectRitual.samples.first(where: { $0.id == slug })
        else { return "#FFFDF2" }
        return lane.cardHex
    }

    /// Whether the today card needs light text — mirrors
    /// `RitualSwipeCard.usesLightText` so the two surfaces stay in sync.
    static func usesLightText(forHex hex: String) -> Bool {
        ["#B8A8B0", "#1B4D4A", "#2C2F3A"].contains(hex)
    }
}

/// Empty-state and section-caption copy strings, extracted so tests can
/// pin them and copy edits don't require view-tree inspection.
enum RabbitHoleEmptyCopy {
    static let headline      = "no threads yet."
    static let sub           = "a thread starts with a rabbit hole you've already logged."
    static let cta           = "start your first thread"
    static let looseCaption  = "these could become threads."
}

// ─────────────────────────────────────────────
// MARK: - New thread input validator (pure)
// ─────────────────────────────────────────────

/// Pure sanitize / validate helpers for the create-thread sheet.
/// Trims leading/trailing whitespace and newlines; an all-whitespace
/// title is invalid. Summary follows the same trim rule but is optional.
enum NewThreadInputValidator {

    /// Returns the trimmed title, or `nil` when the result is empty.
    /// Callers should treat `nil` as "do not save."
    static func sanitizedTitle(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Returns the trimmed summary, or `nil` when the result is empty.
    /// Optional field — an empty summary saves cleanly as nil on the
    /// thread, matching the model's default.
    static func sanitizedSummary(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Convenience for the save button's `disabled` binding — true iff a
    /// non-empty title would survive sanitization.
    static func isValidTitle(_ raw: String) -> Bool {
        sanitizedTitle(raw) != nil
    }
}

// ─────────────────────────────────────────────
// MARK: - New thread inserter (pure side-effect helper)
// ─────────────────────────────────────────────

/// Pure data-side helper for inserting a new `RabbitHoleThread` from
/// the create-thread sheet's inputs. Lifted out of the view so we can
/// unit-test that a save:
/// - Creates exactly one thread row.
/// - Sets status / sourceKind / timestamps to the documented defaults.
/// - Attaches no engagements.
/// - Rejects whitespace-only titles without inserting anything.
enum NewThreadInserter {

    /// Inserts a single `RabbitHoleThread` into `context` if `title`
    /// sanitizes to non-empty. Returns the inserted thread, or `nil`
    /// when the title was rejected (caller should keep the sheet open).
    @discardableResult
    static func insert(
        title rawTitle: String,
        summary rawSummary: String?,
        into context: ModelContext,
        now: Date = Date()
    ) -> RabbitHoleThread? {
        guard let cleanTitle = NewThreadInputValidator.sanitizedTitle(rawTitle) else {
            return nil
        }
        let thread = RabbitHoleThread()
        thread.title = cleanTitle
        thread.summary = (rawSummary).flatMap(NewThreadInputValidator.sanitizedSummary)
        thread.statusRaw = ThreadStatus.open.rawValue
        thread.sourceRaw = ThreadSourceKind.manual.rawValue
        thread.createdAt = now
        thread.updatedAt = now
        // Stamp lastEngagedAt at creation so a fresh thread sorts to the
        // top of the @Query (which orders by lastEngagedAt desc).
        // Future engagement inserts will overwrite this with the
        // engagement's engagedAt; the field is sort-stability, not
        // engagement history.
        thread.lastEngagedAt = now
        thread.deletedAt = nil
        // No engagements attached in RH3-D — that's RH3-E (loose-end
        // attach) and any future seed-from-existing flow.
        context.insert(thread)
        try? context.save()
        return thread
    }
}

// ─────────────────────────────────────────────
// MARK: - New Rabbit Hole Thread Sheet
// ─────────────────────────────────────────────

/// Bottom sheet that creates a single `RabbitHoleThread` from a title
/// (required) and an optional short summary. Presented from both the
/// top-right `+ new thread` capsule and the empty-state CTA.
///
/// Behavior contract (RH3-D):
/// - Save is disabled while the title sanitizes to empty.
/// - Tapping save writes exactly one thread, dismisses, and the
///   overview picks it up via the existing `@Query`.
/// - Tapping cancel or dragging to dismiss writes nothing.
/// - No engagements are created or attached in this slice.
struct NewRabbitHoleThreadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var titleInput: String = ""
    @State private var summaryInput: String = ""
    @FocusState private var titleFocused: Bool

    private var isValid: Bool {
        NewThreadInputValidator.isValidTitle(titleInput)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header: cancel · title · save
            HStack(alignment: .center) {
                Button("cancel") { dismiss() }
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(DSColor.inkSoft.opacity(0.65))
                    .buttonStyle(.plain)

                Spacer()

                Text("new thread")
                    .font(.custom("InstrumentSerif-Italic", size: 17))
                    .foregroundColor(DSColor.ink)

                Spacer()

                Button(action: save) {
                    Text("save")
                        .font(.custom("InstrumentSerif-Italic", size: 15))
                        .foregroundColor(isValid
                                         ? DSColor.ink
                                         : DSColor.ink.opacity(0.30))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            Capsule()
                                .fill(isValid
                                      ? DSColor.paperCream
                                      : DSColor.paperCream.opacity(0.55))
                                .overlay {
                                    Capsule()
                                        .stroke(DSColor.ink.opacity(isValid ? 0.30 : 0.15),
                                                lineWidth: 1)
                                }
                                .shadow(color: DSColor.ink.opacity(isValid ? 0.10 : 0),
                                        radius: 0, x: 1, y: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!isValid)
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 18)

            Rectangle()
                .fill(DSColor.ink.opacity(0.10))
                .frame(height: 0.5)

            // Form fields
            VStack(alignment: .leading, spacing: 18) {

                fieldGroup(label: "title") {
                    TextField("what's this thread about?", text: $titleInput)
                        .font(.custom("InstrumentSerif-Italic", size: 17))
                        .foregroundColor(DSColor.ink)
                        .focused($titleFocused)
                        .submitLabel(.next)
                        .onSubmit { if isValid { save() } }
                }

                fieldGroup(label: "summary  ·  optional") {
                    TextField(
                        "one line about the arc — what you're curious about",
                        text: $summaryInput,
                        axis: .vertical
                    )
                    .font(.system(size: 14))
                    .foregroundColor(DSColor.ink.opacity(0.78))
                    .lineLimit(2...4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .background {
            PaperBackground(variant: .warm).ignoresSafeArea()
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Brief delay so the sheet finishes its presentation before
            // the keyboard pops up — feels less jumpy on device.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                titleFocused = true
            }
        }
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.custom("InstrumentSerif-Italic", size: 12))
                .foregroundColor(DSColor.inkSoft.opacity(0.55))

            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DSColor.paperCream)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
                        }
                        .shadow(color: DSColor.ink.opacity(0.08),
                                radius: 0, x: 1, y: 1)
                }
        }
    }

    private func save() {
        let inserted = NewThreadInserter.insert(
            title: titleInput,
            summary: summaryInput,
            into: modelContext
        )
        if inserted != nil {
            dismiss()
        }
        // If `inserted == nil`, the title was whitespace-only and the
        // save button shouldn't have been tappable. Keep the sheet open
        // as a safety net rather than silently dismissing.
    }
}

// ─────────────────────────────────────────────
// MARK: - Attachable threads picker (pure filter)
// ─────────────────────────────────────────────

/// Pure filter helper for the attach-to-thread picker. Mirrors the
/// overview's `@Query` filter so the picker shows exactly the same set
/// of threads that the user sees on the main surface.
enum AttachableThreadsPicker {

    /// Returns only the threads that can receive an engagement
    /// attachment: not deleted, not closed.
    static func attachable(from all: [RabbitHoleThread]) -> [RabbitHoleThread] {
        all.filter { $0.deletedAt == nil && $0.status != .closed }
    }
}

// ─────────────────────────────────────────────
// MARK: - Engagement thread attacher (pure side-effect helper)
// ─────────────────────────────────────────────

/// Pure data-side helper for attaching a loose `CuriosityEngagement`
/// to an existing `RabbitHoleThread`. Lifted out of the view so we
/// can unit-test the writes:
/// - sets `engagement.thread = thread` (which also populates
///   `thread.engagements` via the inverse relationship)
/// - bumps `thread.lastEngagedAt` to `max(existing, engagement.engagedAt)`
///   so sort order on the overview stays honest
/// - stamps `thread.updatedAt = now`
///
/// Returns `true` on success, `false` if the engagement was already
/// attached to this same thread (no-op short-circuit).
enum EngagementThreadAttacher {

    @discardableResult
    static func attach(
        engagement: CuriosityEngagement,
        to thread: RabbitHoleThread,
        context: ModelContext,
        now: Date = Date()
    ) -> Bool {
        // Idempotent guard: already attached to this thread → no-op.
        // Belt-and-suspenders since the sheet only renders for
        // unthreaded engagements, but defensive against a future
        // re-entry from a different surface.
        if engagement.thread === thread { return false }

        engagement.thread = thread

        // Keep the thread's sort key honest. The engagement may have
        // happened before the thread's most recent step; max() makes
        // sure the thread doesn't accidentally regress in sort order.
        let existing = thread.lastEngagedAt ?? .distantPast
        thread.lastEngagedAt = max(existing, engagement.engagedAt)
        thread.updatedAt = now

        try? context.save()
        return true
    }
}

// ─────────────────────────────────────────────
// MARK: - Attach to Thread Sheet
// ─────────────────────────────────────────────

/// Bottom sheet that attaches a single loose `CuriosityEngagement` to
/// an existing `RabbitHoleThread`. Presented by tapping a loose-end
/// row's `thread?` pill.
///
/// Behavior contract (RH3-E):
/// - Tap a thread row → attach + dismiss (single-step confirm; the
///   loose-end pill is the deliberate gesture).
/// - Cancel / drag-dismiss writes nothing.
/// - No new-thread creation from this sheet; if the user has no
///   threads, the sheet shows an informational empty state and they
///   close it to use `+ new thread` on the overview.
/// - Closed and deleted threads never appear (filtered by `@Query`
///   and re-asserted by `AttachableThreadsPicker`).
/// - Engagement context displayed: title only. **No reflection body,
///   no method-slug-derived sensitive info, no notes.** Even though
///   the engagement object is in scope, only the title is rendered.
struct AttachToThreadSheet: View {
    let engagement: CuriosityEngagement

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Same filter as the overview's threads query — kept in sync so a
    /// user sees the same set in both surfaces.
    @Query(
        filter: #Predicate<RabbitHoleThread> {
            $0.deletedAt == nil && $0.statusRaw != "closed"
        },
        sort: \.lastEngagedAt,
        order: .reverse
    ) private var threads: [RabbitHoleThread]

    /// Hard cap on rows rendered, matching the RH3-C engagement-list
    /// cap. Realistic active-thread counts are well below this.
    static let threadDisplayCap: Int = 25

    private var visibleThreads: [RabbitHoleThread] {
        Array(threads.prefix(Self.threadDisplayCap))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header: leading cancel + true-centered title. No trailing
            // action — confirm is the row tap, so the header explicitly
            // has no right-side button rather than a placeholder slot.
            ZStack {
                Text("add to thread")
                    .font(.custom("InstrumentSerif-Italic", size: 17))
                    .foregroundColor(DSColor.ink)

                HStack {
                    Button("cancel") { dismiss() }
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(DSColor.inkSoft.opacity(0.65))
                        .buttonStyle(.plain)
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Engagement context — title only.
            VStack(alignment: .leading, spacing: 4) {
                Text("adding")
                    .font(.custom("InstrumentSerif-Italic", size: 11))
                    .foregroundColor(DSColor.inkSoft.opacity(0.50))
                Text(engagement.contentTitle)
                    .font(.custom("InstrumentSerif-Italic", size: 16))
                    .foregroundColor(DSColor.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            Rectangle()
                .fill(DSColor.ink.opacity(0.10))
                .frame(height: 0.5)

            // Thread picker
            if visibleThreads.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(visibleThreads.enumerated()), id: \.element.id) { idx, thread in
                            if idx > 0 {
                                Rectangle()
                                    .fill(DSColor.ink.opacity(0.08))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 24)
                            }
                            AttachThreadRow(thread: thread) {
                                attach(to: thread)
                            }
                        }
                    }
                }
            }
        }
        .background {
            PaperBackground(variant: .warm).ignoresSafeArea()
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 28)

            Text("no threads to attach to.")
                .font(.custom("InstrumentSerif-Italic", size: 17))
                .foregroundColor(DSColor.ink.opacity(0.65))

            Text("start one first with + new thread.")
                .font(.system(size: 12, weight: .light))
                .foregroundColor(DSColor.inkSoft.opacity(0.50))
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private func attach(to thread: RabbitHoleThread) {
        let attached = EngagementThreadAttacher.attach(
            engagement: engagement,
            to: thread,
            context: modelContext
        )
        if attached {
            dismiss()
        } else {
            // Idempotent no-op (already on this thread). Dismiss anyway
            // so the user doesn't get stuck.
            dismiss()
        }
    }
}

/// Row in the attach-to-thread picker. Tap is the confirm gesture —
/// no separate save step.
private struct AttachThreadRow: View {
    let thread: RabbitHoleThread
    let onSelect: () -> Void

    private var accentColor: Color {
        switch thread.status {
        case .open:     return Color(hex: "#1B4D4A").opacity(0.75)
        case .resting:  return Color(hex: "#B8A8B0")
        default:        return DSColor.ink.opacity(0.22)
        }
    }

    private var displayTitle: String {
        thread.title.isEmpty ? "untitled thread" : thread.title
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 2.5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(.custom("InstrumentSerif-Italic", size: 15))
                        .foregroundColor(DSColor.ink)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        if thread.status == .resting {
                            Text("resting")
                                .font(.system(size: 10))
                                .foregroundColor(DSColor.ink.opacity(0.60))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 1)
                                .background {
                                    Capsule()
                                        .fill(Color(hex: "#B8A8B0").opacity(0.22))
                                        .overlay {
                                            Capsule()
                                                .stroke(Color(hex: "#B8A8B0").opacity(0.50),
                                                        lineWidth: 0.5)
                                        }
                                }
                        }
                        Text(ThreadStepCount.display(thread.engagements.count))
                        Circle()
                            .fill(DSColor.ink.opacity(0.22))
                            .frame(width: 2, height: 2)
                        Text(EngagementCaption.relativeDate(
                            thread.lastEngagedAt ?? thread.createdAt
                        ))
                    }
                    .font(.system(size: 10))
                    .foregroundColor(DSColor.inkSoft.opacity(0.55))
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(DSColor.ink.opacity(0.35))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Attach to \(displayTitle), \(ThreadStepCount.display(thread.engagements.count))")
    }
}

// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    RabbitHoleView()
        .environment(ActiveMethodStore())
}
