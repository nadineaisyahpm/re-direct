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

    @State private var revealed: Bool = false
    @State private var selectedThread: RabbitHoleThread? = nil

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

                        // + new thread capsule (inert in RH3-C)
                        HStack {
                            Spacer()
                            NewThreadCapsuleStub()
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
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Empty state

    private var emptyInvitation: some View {
        VStack {
            Spacer(minLength: 24)
            EmptyStateBlock()
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
                    LooseEndRow(engagement: engagement)
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
                        LooseEndRow(engagement: engagement)
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

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(engagement.contentTitle)
                .font(.custom("InstrumentSerif-Italic", size: 13))
                .foregroundColor(DSColor.ink.opacity(0.72))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            // Inert "thread?" pill — wired in RH3-E.
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
                .accessibilityHidden(true)
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loose rabbit hole: \(engagement.contentTitle)")
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
// MARK: - + new thread capsule (stub)
// ─────────────────────────────────────────────

/// Visual twin of `ReLogView`'s "log a rabbit hole" capsule. Inert in
/// RH3-B/C; wired in RH3-D when thread creation ships.
private struct NewThreadCapsuleStub: View {
    var body: some View {
        Button {
            // Intentionally empty. RH3-D wires the creation flow.
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

private struct EmptyStateBlock: View {
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

            Button {
                // Intentionally empty. Wired in RH3-D.
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
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    RabbitHoleView()
        .environment(ActiveMethodStore())
}
