import SwiftUI
import SwiftData

// ─────────────────────────────────────────────
// MARK: - Settings View
// ─────────────────────────────────────────────

/// Read-only "dossier" surface. Each row reports a single truth about the
/// device-local state; there are no toggles, chevrons, or destructive
/// controls in S1. Toggles arrive slice-by-slice as backing behavior lands.
struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var revealed = false
    @State private var pendingAction: DataAction? = nil

    @Query private var topics: [CuriosityTopic]
    @Query(filter: #Predicate<CuriosityEngagement> { $0.deletedAt == nil })
    private var engagements: [CuriosityEngagement]
    @Query(filter: #Predicate<TimerSession> { $0.deletedAt == nil })
    private var sessions: [TimerSession]
    @Query(filter: #Predicate<ReflectionEntry> { $0.deletedAt == nil })
    private var reflections: [ReflectionEntry]

    @AppStorage("redirect.seed.installed_version") private var installedSeedVersion: Int = 0

    /// A single, confirmable, on-device mutation. Each case carries its own
    /// editorial copy so the confirmation dialog can stay declarative.
    enum DataAction: Identifiable {
        case clearRabbitHoles
        case clearBoundarySessions
        case clearReflections
        case resetSeedVersion

        var id: Self { self }

        var title: String {
            switch self {
            case .clearRabbitHoles:      return "Clear rabbit holes?"
            case .clearBoundarySessions: return "Clear boundary sessions?"
            case .clearReflections:      return "Clear reflections?"
            case .resetSeedVersion:      return "Reset seed version?"
            }
        }

        var message: String {
            switch self {
            case .clearRabbitHoles:
                return "This hides your logged rabbit holes on this device. Seeded curiosity content stays."
            case .clearBoundarySessions:
                return "This hides your boundary session history on this device."
            case .clearReflections:
                return "This hides your saved reflections on this device."
            case .resetSeedVersion:
                return "Seed content will import again on next launch. Your rabbit holes and sessions stay untouched."
            }
        }

        var confirmLabel: String {
            switch self {
            case .resetSeedVersion: return "Reset"
            default:                return "Clear"
            }
        }
    }

    private let buildLabel = "build 26.05.21"
    private let prototypeLabel = "prototype 0.3.1"
    private let currentSliceLabel = "TL4.1"

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PaperBackground(variant: .cool)

                RetualsGrain()
                    .drawingGroup()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        header(topInset: geo.safeAreaInsets.top + 10)

                        identityStrip
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 6)
                            .padding(.bottom, 28)
                            .opacity(revealed ? 1 : 0)
                            .offset(y: revealed ? 0 : 6)
                            .animation(.smooth.delay(0.08), value: revealed)

                        section(
                            title: "Local data",
                            caption: "what you own",
                            delay: 0.16
                        ) {
                            SettingsRow(icon: "tray.full",
                                        label: "rabbit holes",
                                        hint: "CuriosityEngagement") {
                                italicValue("\(engagements.count)")
                            }
                            SettingsRow(icon: "hourglass.bottomhalf.filled",
                                        label: "boundary sessions",
                                        hint: "TimerSession") {
                                italicValue("\(sessions.count)")
                            }
                            SettingsRow(icon: "text.quote",
                                        label: "reflections",
                                        hint: "ReflectionEntry") {
                                italicValue("\(reflections.count)")
                            }
                            SettingsRow(icon: "leaf",
                                        label: "seeded topics",
                                        hint: "CuriosityTopic") {
                                italicValue("\(topics.count)")
                            }
                            SettingsRow(icon: "internaldrive",
                                        label: "storage",
                                        hint: "derived sum · helper TBD") {
                                italicValue("—")
                            }
                        }

                        section(
                            title: "Privacy",
                            caption: "what leaves this device",
                            delay: 0.24
                        ) {
                            SettingsRow(icon: "antenna.radiowaves.left.and.right.slash",
                                        label: "network calls this week",
                                        hint: "logged out of process") {
                                StatusChip(text: "none", variant: .positive)
                            }
                            SettingsRow(icon: "lock.shield",
                                        label: "apple identity",
                                        hint: "AfterFirstUnlockThisDeviceOnly") {
                                italicValue("this device only")
                            }
                            SettingsRow(icon: "sparkles",
                                        label: "AI proxy",
                                        hint: "provider-agnostic · Phase 6") {
                                italicValue("contract only · disabled")
                            }
                            SettingsRow(icon: "chart.bar.xaxis",
                                        label: "analytics",
                                        hint: nil) {
                                StatusChip(text: "off", variant: .muted)
                            }
                        }

                        section(
                            title: "Seed content",
                            caption: "curated curiosity",
                            delay: 0.32
                        ) {
                            SettingsRow(icon: "leaf.circle",
                                        label: "current seed version",
                                        hint: nil) {
                                italicValue(installedSeedVersion > 0
                                            ? "v\(installedSeedVersion)"
                                            : "—")
                            }
                            SettingsRow(icon: "clock.arrow.circlepath",
                                        label: "last refreshed",
                                        hint: "import timestamp · helper TBD") {
                                italicValue("—")
                            }
                            SettingsRow(icon: "globe",
                                        label: "locale",
                                        hint: "BCP-47") {
                                italicValue("en-US")
                            }
                        }

                        section(
                            title: "Sign in with Apple",
                            caption: "identity surface",
                            delay: 0.40
                        ) {
                            SettingsRow(icon: "apple.logo",
                                        label: "coordinator",
                                        hint: "AppleSignInCoordinator") {
                                StatusChip(text: "ready", variant: .positive)
                            }
                            SettingsRow(icon: "checkmark.seal",
                                        label: "capability",
                                        hint: "manual Xcode step · Slice 7.1") {
                                StatusChip(text: "not enabled", variant: .pending)
                            }
                            SettingsRow(icon: "key",
                                        label: "keychain",
                                        hint: "KeychainAppleIDStore") {
                                italicValue("ready")
                            }
                        }

                        section(
                            title: "Screen Time",
                            caption: "platform research",
                            delay: 0.48
                        ) {
                            SettingsRow(icon: "iphone.gen3.radiowaves.left.and.right",
                                        label: "DeviceActivity",
                                        hint: "feasibility doc · Phase 7B spike") {
                                italicValue("feasibility planned · not enabled")
                            }
                            SettingsRow(icon: "person.2.badge.gearshape",
                                        label: "FamilyControls",
                                        hint: "entitlement request gated on 7B") {
                                italicValue("not enabled")
                            }
                            SettingsRow(icon: "hand.raised",
                                        label: "fallback signal",
                                        hint: "user-declared CuriosityEngagement") {
                                StatusChip(text: "ready", variant: .positive)
                            }
                        }

                        section(
                            title: "Local data controls",
                            caption: "soft-delete · stays on this device",
                            delay: 0.52
                        ) {
                            SettingsRow(icon: "archivebox",
                                        label: "clear rabbit holes",
                                        hint: "soft-delete · sets deletedAt") {
                                actionPill("clear", enabled: !engagements.isEmpty) {
                                    pendingAction = .clearRabbitHoles
                                }
                            }
                            SettingsRow(icon: "archivebox",
                                        label: "clear boundary sessions",
                                        hint: "soft-delete · sets deletedAt") {
                                actionPill("clear", enabled: !sessions.isEmpty) {
                                    pendingAction = .clearBoundarySessions
                                }
                            }
                            SettingsRow(icon: "archivebox",
                                        label: "clear reflections",
                                        hint: "soft-delete · sets deletedAt") {
                                actionPill("clear", enabled: !reflections.isEmpty) {
                                    pendingAction = .clearReflections
                                }
                            }
                            SettingsRow(icon: "arrow.clockwise",
                                        label: "reset seed version",
                                        hint: "clears AppStorage key") {
                                actionPill("reset", enabled: installedSeedVersion > 0) {
                                    pendingAction = .resetSeedVersion
                                }
                            }
                        }

                        section(
                            title: "About",
                            caption: "this app",
                            delay: 0.60
                        ) {
                            SettingsRow(icon: "bookmark",
                                        label: "current slice",
                                        hint: "see docs/ROADMAP.md") {
                                StatusChip(text: currentSliceLabel, variant: .highlight)
                            }
                            SettingsRow(icon: "hand.raised.circle",
                                        label: "privacy policy",
                                        hint: nil) {
                                italicValue("your data, your device.")
                            }
                            SettingsRow(icon: "info.circle",
                                        label: "build",
                                        hint: nil) {
                                italicValue(buildLabel.replacingOccurrences(of: "build ",
                                                                              with: ""))
                            }
                        }

                        Spacer().frame(height: DSMetric.bottomNavClearance)
                    }
                    .padding(.horizontal, DSMetric.pageHorizontal)
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        // Using `.alert` (not `.confirmationDialog`) so the Cancel button is
        // visible inline next to the destructive action. The system action-
        // sheet renders Cancel in a separate bottom block that's easy to
        // miss; for a data-mutating choice we want both options clearly
        // adjacent in a single modal.
        .alert(
            pendingAction?.title ?? "",
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { presented in
                    if !presented { pendingAction = nil }
                }
            ),
            presenting: pendingAction
        ) { action in
            Button("Cancel", role: .cancel) {
                pendingAction = nil
            }
            Button(action.confirmLabel, role: .destructive) {
                perform(action)
                pendingAction = nil
            }
        } message: { action in
            Text(action.message)
        }
        .onAppear {
            withAnimation { revealed = true }
        }
    }

    // MARK: header

    @ViewBuilder
    private func header(topInset: CGFloat) -> some View {
        VStack(spacing: 4) {
            Text("Settings")
                .font(.custom("InstrumentSerif-Italic", size: 38))
                .foregroundColor(DSColor.ink)

            Text("every row, a single truth.")
                .font(.system(size: 13, weight: .light))
                .foregroundColor(DSColor.inkSoft.opacity(0.55))
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, topInset)
        .padding(.bottom, 12)
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 8)
        .animation(.smooth.delay(0.04), value: revealed)
    }

    // MARK: identity strip

    private var identityStrip: some View {
        Text("local-first · \(prototypeLabel) · \(buildLabel)")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(DSColor.ink.opacity(0.65))
            .tracking(0.1)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay {
                        Capsule()
                            .fill(Color.white.opacity(0.40))
                    }
                    .overlay {
                        Capsule()
                            .stroke(DSColor.ink.opacity(0.22), lineWidth: 0.5)
                    }
                    .shadow(color: DSColor.ink.opacity(0.10),
                            radius: 0, x: 1, y: 1)
            }
    }

    // MARK: section template

    /// A section header followed by a vertical stack of independent
    /// paper-glass rows. The tight 1.5pt spacing keeps the rows reading
    /// as a connected group while letting each one carry its own
    /// fill / stroke / hard shadow.
    @ViewBuilder
    private func section<Content: View>(
        title: String,
        caption: String,
        delay: Double,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: title,
                caption: caption,
                captionAlignment: .trailing
            )

            VStack(spacing: 6) {
                content()
            }
        }
        .padding(.bottom, 22)
        .opacity(revealed ? 1 : 0)
        .offset(y: revealed ? 0 : 10)
        .animation(.smooth.delay(delay), value: revealed)
    }

    // MARK: row primitives

    @ViewBuilder
    private func italicValue(_ text: String) -> some View {
        Text(text)
            .font(.custom("InstrumentSerif-Italic", size: 17))
            .foregroundColor(DSColor.ink.opacity(0.92))
            .lineLimit(1)
            .truncationMode(.middle)
            .minimumScaleFactor(0.82)
    }

    /// Small destructive-but-calm action pill. Reuses the dusty-rose tint
    /// that `StatusChip.pending` already uses, so destructive intent reads
    /// without resorting to emergency red. Disables itself when there is
    /// nothing to act on, so the user never confirms a no-op.
    @ViewBuilder
    private func actionPill(_ label: String,
                            enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(DSColor.ink.opacity(enabled ? 0.82 : 0.40))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background {
                    Capsule()
                        .fill(Color(hex: "#F4E2DC")
                                .opacity(enabled ? 1.0 : 0.55))
                        .overlay {
                            Capsule()
                                .stroke(DSColor.ink.opacity(enabled ? 0.32 : 0.18),
                                        lineWidth: 1)
                        }
                        .shadow(color: DSColor.ink.opacity(enabled ? 0.14 : 0.0),
                                radius: 0, x: 1.5, y: 1.5)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    // MARK: mutations

    private func perform(_ action: DataAction) {
        let now = Date()
        switch action {
        case .clearRabbitHoles:
            for row in engagements { row.deletedAt = now }
        case .clearBoundarySessions:
            for row in sessions { row.deletedAt = now }
        case .clearReflections:
            for row in reflections { row.deletedAt = now }
        case .resetSeedVersion:
            installedSeedVersion = 0
        }
        try? modelContext.save()
    }
}

// ─────────────────────────────────────────────
// MARK: - Settings Row
// ─────────────────────────────────────────────

/// A single row inside a settings paper tile. The `trailing` slot accepts
/// either an italic value (`Text`) or a `StatusChip` — never both. Hints
/// appear under the label and may reference SwiftData entity names or
/// platform-API explanations to anchor the engineering-reader.
private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let label: String
    var hint: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(DSColor.ink.opacity(0.68))
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(DSColor.ink.opacity(0.86))

                if let hint = hint {
                    Text(hint)
                        .font(.system(size: 11, weight: .light))
                        .foregroundColor(DSColor.ink.opacity(0.42))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            // Layered paper-glass pill. The shape is drawn five times:
            //   1. base cream-gradient fill (brighter top, deeper bottom)
            //   2. top specular bloom (white, plusLighter)
            //   3. bottom warm-shade band (multiply) for curvature
            //   4. rim-light hairline along the top edge
            //   5. ink stroke for the paper outline
            // Two shadows: a 1px hard paper shadow + a soft ambient lift.
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FFFEF6"),
                            DSColor.paperCream,
                            Color(hex: "#F2EAD8")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.78),
                                    Color.white.opacity(0.18),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color(red: 0.34, green: 0.24, blue: 0.18).opacity(0.10)
                                ],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.multiply)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.90),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            lineWidth: 1
                        )
                        .blendMode(.plusLighter)
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(DSColor.ink.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: DSColor.ink.opacity(0.10),
                        radius: 0, x: 1.0, y: 1.0)
                .shadow(color: Color(red: 0.35, green: 0.25, blue: 0.22).opacity(0.10),
                        radius: 12, x: 0, y: 6)
        }
        .contentShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: ReDirectSchema.allModels, inMemory: true)
}
