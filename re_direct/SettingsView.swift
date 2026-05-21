import SwiftUI
import SwiftData

// ─────────────────────────────────────────────
// MARK: - Settings View
// ─────────────────────────────────────────────

/// Read-only "dossier" surface. Each row reports a single truth about the
/// device-local state; there are no toggles, chevrons, or destructive
/// controls in S1. Toggles arrive slice-by-slice as backing behavior lands.
struct SettingsView: View {

    @State private var revealed = false

    @Query private var topics: [CuriosityTopic]
    @Query(filter: #Predicate<CuriosityEngagement> { $0.deletedAt == nil })
    private var engagements: [CuriosityEngagement]
    @Query(filter: #Predicate<TimerSession> { $0.deletedAt == nil })
    private var sessions: [TimerSession]

    @AppStorage("redirect.seed.installed_version") private var installedSeedVersion: Int = 0

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
                            SettingsRow(label: "rabbit holes",
                                        hint: "CuriosityEngagement") {
                                italicValue("\(engagements.count)")
                            }
                            SettingsRow(label: "boundary sessions",
                                        hint: "TimerSession") {
                                italicValue("\(sessions.count)")
                            }
                            SettingsRow(label: "seeded topics",
                                        hint: "CuriosityTopic") {
                                italicValue("\(topics.count)")
                            }
                            SettingsRow(label: "storage",
                                        hint: "derived sum · helper TBD") {
                                italicValue("—")
                            }
                        }

                        section(
                            title: "Privacy",
                            caption: "what leaves this device",
                            delay: 0.24
                        ) {
                            SettingsRow(label: "network calls this week",
                                        hint: "logged out of process") {
                                StatusChip(text: "none", variant: .positive)
                            }
                            SettingsRow(label: "apple identity",
                                        hint: "AfterFirstUnlockThisDeviceOnly") {
                                italicValue("this device only")
                            }
                            SettingsRow(label: "AI proxy",
                                        hint: "provider-agnostic · Phase 6") {
                                italicValue("not configured")
                            }
                            SettingsRow(label: "analytics",
                                        hint: nil) {
                                StatusChip(text: "off", variant: .muted)
                            }
                        }

                        section(
                            title: "Seed content",
                            caption: "curated curiosity",
                            delay: 0.32
                        ) {
                            SettingsRow(label: "current seed version",
                                        hint: nil) {
                                italicValue(installedSeedVersion > 0
                                            ? "v\(installedSeedVersion)"
                                            : "—")
                            }
                            SettingsRow(label: "last refreshed",
                                        hint: "import timestamp · helper TBD") {
                                italicValue("—")
                            }
                            SettingsRow(label: "locale",
                                        hint: "BCP-47") {
                                italicValue("en-US")
                            }
                        }

                        section(
                            title: "Sign in with Apple",
                            caption: "identity surface",
                            delay: 0.40
                        ) {
                            SettingsRow(label: "coordinator",
                                        hint: "AppleSignInCoordinator") {
                                StatusChip(text: "ready", variant: .positive)
                            }
                            SettingsRow(label: "capability",
                                        hint: "manual Xcode step · Slice 7.1") {
                                StatusChip(text: "not enabled", variant: .pending)
                            }
                            SettingsRow(label: "keychain",
                                        hint: "KeychainAppleIDStore") {
                                italicValue("ready")
                            }
                        }

                        section(
                            title: "Screen Time",
                            caption: "platform research",
                            delay: 0.48
                        ) {
                            SettingsRow(label: "DeviceActivity",
                                        hint: "Phase 7 spike") {
                                italicValue("not integrated")
                            }
                            SettingsRow(label: "FamilyControls",
                                        hint: "Phase 7 spike") {
                                italicValue("not integrated")
                            }
                            SettingsRow(label: "fallback signal",
                                        hint: "user-declared CuriosityEngagement") {
                                StatusChip(text: "ready", variant: .positive)
                            }
                        }

                        section(
                            title: "About",
                            caption: "this app",
                            delay: 0.56
                        ) {
                            SettingsRow(label: "current slice",
                                        hint: "see docs/ROADMAP.md") {
                                StatusChip(text: currentSliceLabel, variant: .highlight)
                            }
                            SettingsRow(label: "privacy policy",
                                        hint: nil) {
                                italicValue("your data, your device.")
                            }
                            SettingsRow(label: "build",
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

            VStack(spacing: 1.5) {
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
            .font(.custom("InstrumentSerif-Italic", size: 14))
            .foregroundColor(DSColor.ink.opacity(0.72))
            .lineLimit(1)
            .truncationMode(.middle)
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
    let label: String
    var hint: String? = nil
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
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
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(DSColor.paperCream)
                .overlay {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: DSColor.ink.opacity(0.10),
                        radius: 0, x: 1.0, y: 1.0)
        }
        .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: ReDirectSchema.allModels, inMemory: true)
}
