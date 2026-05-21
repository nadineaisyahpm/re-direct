import SwiftUI
import SwiftData

// ─────────────────────────────────────────────
// MARK: - Data Models
// ─────────────────────────────────────────────

enum TimerRedirectMethod: String, CaseIterable, Identifiable {
    case watch    = "Watch"
    case read     = "Read"
    case miniGame = "Mini Game"
    case reflect  = "Reflect"
    case deepDive = "Deep Dive"
    var id: String { rawValue }
}

struct TrackedApp: Identifiable, Hashable {
    let id: String
    let name: String
    let iconName: String?
    let colorHex: String
}

struct TimerReminderTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let gradientHexes: [String]
    let swatches: [String]

    static let samples: [TimerReminderTheme] = [
        TimerReminderTheme(id: "dandelion", name: "Dandelion",
            gradientHexes: ["#FFFDF2","#EAC1D3"],
            swatches: ["#FFFDF2","#F5E8C0","#EAC1D3","#D4A8BE"]),
        TimerReminderTheme(id: "desert", name: "Desert",
            gradientHexes: ["#C8B898","#A89878"],
            swatches: ["#C8B898","#A89878","#887858","#685838"]),
        TimerReminderTheme(id: "sky",    name: "Sky",
            gradientHexes: ["#8AACCC","#5880A8"],
            swatches: ["#8AACCC","#6890B0","#4A7090","#2A5070"]),
        TimerReminderTheme(id: "mist",   name: "Mist",
            gradientHexes: ["#C8D4D8","#98B0B8"],
            swatches: ["#C8D4D8","#A8B8C0","#8898A0","#687880"]),
        TimerReminderTheme(id: "night",  name: "Night",
            gradientHexes: ["#2A2A3A","#0A0A18"],
            swatches: ["#2A2A3A","#1A1A28","#0A0A18","#3A3A50"]),
        TimerReminderTheme(id: "neon",   name: "Neon",
            gradientHexes: ["#1A1A2E","#2A1A3E"],
            swatches: ["#FF4488","#44FFCC","#4488FF","#FF8844"]),
        TimerReminderTheme(id: "dusk",   name: "Dusk",
            gradientHexes: ["#1C2A3A","#0C1A2A"],
            swatches: ["#1C2A3A","#2C4A6A","#4C7A9A","#8CAABA"]),
    ]
}

// ─────────────────────────────────────────────
// MARK: - Liquid Glass Surface Modifier
// ─────────────────────────────────────────────

struct LiquidGlassSurface: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let tintOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(tintOpacity))
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.white.opacity(0.28))
                            .frame(height: 18)
                            .blur(radius: 10)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(DSColor.ink.opacity(0.38), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            }
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 16,
                     tint: Color = DSColor.paperCreamSoft,
                     tintOpacity: Double = 0.35) -> some View {
        modifier(LiquidGlassSurface(cornerRadius: cornerRadius,
                                    tint: tint,
                                    tintOpacity: tintOpacity))
    }
}

// ─────────────────────────────────────────────
// MARK: - Timer View
// ─────────────────────────────────────────────

struct TimerView: View {

    @State private var selectedHours: Int   = 0
    @State private var selectedMinutes: Int = 45
    @State private var selectedMethod: TimerRedirectMethod = .watch

    @State private var selectedApps: [TrackedApp] = [
        TrackedApp(id: "instagram", name: "Instagram", iconName: nil, colorHex: "#E1306C"),
        TrackedApp(id: "tiktok",    name: "TikTok",    iconName: nil, colorHex: "#010101"),
    ]
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    @State private var selectedTheme: TimerReminderTheme = TimerReminderTheme.samples[0]
    @State private var previewPulse = false
    @State private var previewReady = false
    @State private var activeSessionId: UUID? = nil

    @State private var titleVisible        = false
    @State private var appSectionVisible  = false
    @State private var themeSectionVisible = false

    private let allApps: [TrackedApp] = [
        TrackedApp(id: "instagram", name: "Instagram", iconName: nil, colorHex: "#E1306C"),
        TrackedApp(id: "tiktok",    name: "TikTok",    iconName: nil, colorHex: "#010101"),
        TrackedApp(id: "youtube",   name: "YouTube",   iconName: nil, colorHex: "#FF0000"),
        TrackedApp(id: "x",         name: "X",         iconName: nil, colorHex: "#14171A"),
        TrackedApp(id: "reddit",    name: "Reddit",    iconName: nil, colorHex: "#FF4500"),
    ]

    private var suggestions: [TrackedApp] {
        guard !searchText.isEmpty else { return [] }
        return allApps.filter { app in
            !selectedApps.contains(app) &&
            app.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    func toggleApp(_ app: TrackedApp) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
            if selectedApps.contains(app) {
                selectedApps.removeAll { $0.id == app.id }
            } else if selectedApps.count < 4 {
                selectedApps.append(app)
                searchText = ""
                isSearchFocused = false
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {

                PaperBackground(variant: .cool)

                TimerGrain()
                    .drawingGroup()
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {

                        VStack(spacing: 5) {
                            Text("Timer")
                                .font(DSFont.pageTitle())
                                .foregroundColor(DSColor.ink)

                            Text("set the time window before we redirect you out of the algorithm.")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(DSColor.inkSoft.opacity(0.5))
                                .multilineTextAlignment(.center)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .opacity(titleVisible ? 1 : 0)
                        .offset(y: titleVisible ? 0 : 10)
                        .animation(.smooth.delay(0.05), value: titleVisible)
                        .padding(.top, geo.safeAreaInsets.top + 14)
                        .padding(.bottom, 20)
                        .padding(.horizontal, 24)

                        DurationPickerCard(
                            selectedHours: $selectedHours,
                            selectedMinutes: $selectedMinutes
                        )
                        .padding(.horizontal, 24)

                        SectionHeader(
                            title: "Method",
                            caption: "methods are things you have to complete in order to quit the reminder."
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        MethodSelector(selectedMethod: $selectedMethod)
                            .padding(.horizontal, 24)
                            .padding(.top, 10)

                        SectionHeader(
                            title: "App",
                            caption: "select apps in which you let us track your usage time and remind you once your time limit hits."
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        AppSelectionSection(
                            selectedApps: $selectedApps,
                            searchText: $searchText,
                            isSearchFocused: $isSearchFocused,
                            suggestions: suggestions,
                            onToggle: toggleApp
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 10)
                        .opacity(appSectionVisible ? 1 : 0)
                        .offset(y: appSectionVisible ? 0 : 12)
                        .animation(.smooth.delay(0.15), value: appSectionVisible)

                        SectionHeader(
                            title: "Theme",
                            caption: "customize your own reminder theme. change your atmosphere."
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                        ThemeGrid(selectedTheme: $selectedTheme)
                            .padding(.horizontal, 24)
                            .padding(.top, 10)
                            .opacity(themeSectionVisible ? 1 : 0)
                            .offset(y: themeSectionVisible ? 0 : 12)
                            .animation(.smooth.delay(0.25), value: themeSectionVisible)

                        EnhancedPreviewButton(
                            hours: selectedHours,
                            minutes: selectedMinutes,
                            selectedTheme: selectedTheme,
                            previewReady: $previewReady,
                            activeSessionId: $activeSessionId
                        )
                        .padding(.top, 24)
                        .padding(.bottom, 16)
                        .opacity(themeSectionVisible ? 1 : 0)
                        .animation(.smooth.delay(0.35), value: themeSectionVisible)

                        Spacer().frame(height: DSMetric.bottomNavClearance)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.light)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                titleVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                appSectionVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                themeSectionVisible = true
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Duration Picker Card
// ─────────────────────────────────────────────

struct DurationPickerCard: View {
    @Binding var selectedHours: Int
    @Binding var selectedMinutes: Int

    private let minuteOptions = [0, 5, 10, 15, 20, 30, 45, 60]

    var body: some View {
        HStack(spacing: 14) {
            TimerPickerCard(label: "Hours") {
                Picker("Hours", selection: $selectedHours) {
                    ForEach(0...12, id: \.self) { h in
                        Text(String(format: "%02d", h))
                            .font(.custom("InstrumentSerif-Italic", size: 38))
                            .tag(h)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)
                .colorScheme(.dark)
            }

            TimerPickerCard(label: "Minutes") {
                Picker("Minutes", selection: $selectedMinutes) {
                    ForEach(minuteOptions, id: \.self) { m in
                        Text(String(format: "%02d", m))
                            .font(.custom("InstrumentSerif-Italic", size: 38))
                            .tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 140)
                .colorScheme(.dark)
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Timer Picker Card
// ─────────────────────────────────────────────

struct TimerPickerCard<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.custom("InstrumentSerif-Italic", size: 13))
                .foregroundColor(.white.opacity(0.55))
                .padding(.bottom, 4)

            content
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.92),
                            Color(hex: "#191817").opacity(0.94),
                            Color.black.opacity(0.88)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        .blur(radius: 0.5)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.10),
                                    Color.clear,
                                    Color.black.opacity(0.20)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.screen)
                }
        }
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 10)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

// ─────────────────────────────────────────────
// MARK: - Method Selector
// ─────────────────────────────────────────────

struct MethodSelector: View {
    @Binding var selectedMethod: TimerRedirectMethod
    @Query private var seededMethods: [RedirectMethod]
    @Environment(ActiveMethodStore.self) private var activeMethodStore

    private func slug(for method: TimerRedirectMethod) -> String {
        switch method {
        case .watch:    return "watch"
        case .read:     return "read"
        case .miniGame: return "mini-game"
        case .reflect:  return "reflect"
        case .deepDive: return "deep-dive"
        }
    }

    private func label(for method: TimerRedirectMethod) -> String {
        let s = slug(for: method)
        if let seeded = seededMethods.first(where: { $0.slug == s }), !seeded.displayName.isEmpty {
            return seeded.displayName
        }
        return method.rawValue
    }

    private func cardColor(for method: TimerRedirectMethod) -> Color {        switch method {
        case .watch:    return Color(hex: "#B8A8B0")
        case .read:     return Color(hex: "#1B4D4A")
        case .miniGame: return Color(hex: "#C8B898")
        case .reflect:  return Color(hex: "#D4C4B8")
        case .deepDive: return Color(hex: "#2C2F3A")
        }
    }

    private func usesLightText(_ method: TimerRedirectMethod) -> Bool {
        [TimerRedirectMethod.read, .deepDive, .watch].contains(method)
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(TimerRedirectMethod.allCases) { method in
                let isSelected = selectedMethod == method
                let base = cardColor(for: method)
                let lightText = usesLightText(method)
                let labelColor: Color = isSelected && lightText ? .white.opacity(0.92) : DSColor.ink

                Button(action: {
                    // Single-select: tapping a method replaces the previous
                    // selection. Tapping the already-selected method is a no-op.
                    let methodSlug = slug(for: method)
                    withAnimation(.spring(duration: 0.3, bounce: 0.15)) {
                        selectedMethod = method
                    }
                    activeMethodStore.activeRedirectMethodSlug = methodSlug
                }) {
                    HStack(spacing: 12) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18, weight: .regular))
                                .foregroundColor(labelColor.opacity(0.85))
                                .frame(width: 26, height: 26)
                        } else {
                            Circle()
                                .fill(DSColor.inkSoft.opacity(0.07))
                                .frame(width: 26, height: 26)
                        }

                        Text(label(for: method))
                            .font(.custom("InstrumentSerif-Italic", size: 17))
                            .foregroundColor(labelColor)

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(base)
                                .overlay {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.22),
                                                    Color.clear,
                                                    Color.black.opacity(0.08)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                }
                                .overlay(alignment: .top) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.22))
                                        .frame(height: 12)
                                        .blur(radius: 6)
                                }
                                .overlay {
                                    Capsule()
                                        .stroke(DSColor.ink.opacity(0.38), lineWidth: 1)
                                }
                        } else {
                            Capsule()
                                .fill(DSColor.paperCream)
                                .overlay {
                                    Capsule()
                                        .stroke(DSColor.ink.opacity(0.38), lineWidth: 1)
                                }
                        }
                    }
                    .shadow(
                        color: isSelected
                            ? DSColor.ink.opacity(0.14)
                            : DSColor.ink.opacity(0.08),
                        radius: 0, x: 1.5, y: 1.5
                    )
                    .shadow(
                        color: .black.opacity(isSelected ? 0.10 : 0.03),
                        radius: isSelected ? 10 : 3,
                        x: 0, y: isSelected ? 4 : 1
                    )
                }
                .buttonStyle(TactileButtonStyle())
            }
        }
        .onAppear {
            // Sync the default selection into the shared store on first appear,
            // so re:tuals reflects "watch" (or whatever is selected) even
            // before the user actively taps a chip. Idempotent and safe to
            // overwrite — the user always sees one method selected.
            activeMethodStore.activeRedirectMethodSlug = slug(for: selectedMethod)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - App Selection Section
// ─────────────────────────────────────────────

struct AppSelectionSection: View {
    @Binding var selectedApps: [TrackedApp]
    @Binding var searchText: String
    @FocusState.Binding var isSearchFocused: Bool
    let suggestions: [TrackedApp]
    let onToggle: (TrackedApp) -> Void

    private var isAtMax: Bool { selectedApps.count >= 4 }

    var body: some View {
        VStack(spacing: 8) {

            PaperSearchBar(
                placeholder: "Search for an app…",
                text: $searchText,
                focused: $isSearchFocused
            )
            .animation(.spring(duration: 0.25, bounce: 0.1), value: isSearchFocused)

            if isSearchFocused && !suggestions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(suggestions) { app in
                        Button(action: { onToggle(app) }) {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: app.colorHex))
                                    .frame(width: 10, height: 10)

                                Text(app.name)
                                    .font(.system(size: 14, weight: .regular))
                                    .foregroundColor(DSColor.ink)

                                Spacer()

                                Image(systemName: "plus")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundColor(DSColor.inkSoft.opacity(0.4))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(ScaleButtonStyle(scale: 0.96))

                        if app.id != suggestions.last?.id {
                            Divider()
                                .opacity(0.08)
                                .padding(.horizontal, 14)
                        }
                    }
                }
                .liquidGlass(cornerRadius: 14, tint: DSColor.paperCreamSoft, tintOpacity: 0.4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                if selectedApps.isEmpty {
                    Text("choose apps to track")
                        .font(.system(size: 12, weight: .light))
                        .foregroundColor(DSColor.inkSoft.opacity(0.35))
                        .padding(.leading, 4)
                } else {
                    ForEach(selectedApps) { app in
                        InteractiveAppToken(app: app, onTap: { onToggle(app) })
                            .transition(.opacity.combined(with: .scale(scale: 0.7)))
                    }
                }

                Button(action: {
                    withAnimation(.spring(duration: 0.25, bounce: 0.15)) {
                        isSearchFocused = true
                    }
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                DSColor.inkSoft.opacity(0.22),
                                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
                            )
                            .frame(width: 54, height: 54)
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .light))
                            .foregroundColor(DSColor.inkSoft.opacity(isAtMax ? 0.18 : 0.38))
                    }
                }
                .buttonStyle(ScaleButtonStyle(scale: 0.96))
                .disabled(isAtMax)

                Spacer()
            }
            .padding(12)
            .liquidGlass(cornerRadius: 14, tint: DSColor.paperCreamSoft, tintOpacity: 0.3)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Interactive App Token
// ─────────────────────────────────────────────

struct InteractiveAppToken: View {
    let app: TrackedApp
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: app.colorHex), Color(hex: app.colorHex).opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 54)
                    .overlay {
                        Text(app.name.prefix(2).uppercased())
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.14))
                            .frame(height: 20)
                            .blur(radius: 4)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    }

                ZStack {
                    Circle()
                        .fill(DSColor.ink)
                        .frame(width: 17, height: 17)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: -3, y: 3)
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.96))
    }
}

// ─────────────────────────────────────────────
// MARK: - Theme Grid
// ─────────────────────────────────────────────

struct ThemeGrid: View {
    @Binding var selectedTheme: TimerReminderTheme

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(TimerReminderTheme.samples) { theme in
                ThemeCard(
                    theme: theme,
                    isSelected: selectedTheme.id == theme.id,
                    isAnySelected: true,
                    onTap: {
                        withAnimation(.spring(duration: 0.3, bounce: 0.1)) {
                            selectedTheme = theme
                        }
                    }
                )
            }
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Theme Card
// ─────────────────────────────────────────────

struct ThemeCard: View {
    let theme: TimerReminderTheme
    let isSelected: Bool
    let isAnySelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: theme.gradientHexes.map { Color(hex: $0) },
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(
                                    RadialGradient(
                                        colors: [Color.clear, Color.black.opacity(0.12)],
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 60
                                    )
                                )
                        }
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.14))
                                .frame(height: 18)
                                .blur(radius: 4)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    DSColor.ink.opacity(isSelected ? 0.38 : 0.22),
                                    lineWidth: 1
                                )
                        }
                }
                .frame(height: 68)
                .scaleEffect(isSelected ? 1.0 : 0.98)
                .animation(.spring(duration: 0.3, bounce: 0.15), value: isSelected)

                HStack(spacing: 3) {
                    ForEach(Array(theme.swatches.enumerated()), id: \.offset) { i, hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 7, height: 7)
                            .opacity(isSelected ? 1 : 0.7)
                            .animation(.easeIn(duration: 0.15).delay(Double(i) * 0.04), value: isSelected)
                    }
                    Spacer()
                }
                .padding(.horizontal, 2)
            }
            .padding(5)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.thinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(DSColor.highlightYellowPaper.opacity(0.65))
                        }
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(Color.white.opacity(0.25))
                                .frame(height: 16)
                                .blur(radius: 8)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(DSColor.ink.opacity(0.38), lineWidth: 1)
                        }
                } else {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(DSColor.paperCreamSoft.opacity(0.3))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .stroke(DSColor.ink.opacity(0.22), lineWidth: 1)
                        }
                }
            }
            .opacity(isAnySelected && !isSelected ? 0.6 : 1.0)
            .shadow(color: .black.opacity(isSelected ? 0.07 : 0.02),
                    radius: isSelected ? 6 : 3,
                    x: 0, y: isSelected ? 3 : 1)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.spring(duration: 0.3, bounce: 0.1), value: isSelected)
            .animation(.easeInOut(duration: 0.2), value: isAnySelected)
        }
        .buttonStyle(ScaleButtonStyle(scale: 0.97))
    }
}

// ─────────────────────────────────────────────
// MARK: - Enhanced Preview Button
// ─────────────────────────────────────────────

struct EnhancedPreviewButton: View {
    let hours: Int
    let minutes: Int
    let selectedTheme: TimerReminderTheme
    @Binding var previewReady: Bool
    @Binding var activeSessionId: UUID?

    @Environment(\.modelContext) private var context

    private var isActive: Bool { activeSessionId != nil }
    private var hasNonZeroDuration: Bool { hours > 0 || minutes > 0 }

    private var buttonLabel: String {
        isActive ? "boundary active" : "start boundary"
    }

    var body: some View {
        VStack(spacing: 8) {
            Button(action: {
                guard hasNonZeroDuration else {
                    print("⚠️ Duration is zero.")
                    return
                }
                // Dedup guard: TimerView holds the single active session id.
                // Repeated taps while a session is active do not create another row.
                // Completion / cancel paths will clear activeSessionId in a future slice.
                guard !isActive else { return }

                // A TimerSession represents a boundary commitment, NOT a rabbit hole.
                // Curiosity engagement (read / watched / completed a prompt) is a
                // separate domain event tracked via CuriosityEngagement.
                let session = TimerSession()
                session.startedAt = .now
                session.plannedMinutes = (hours * 60) + minutes
                context.insert(session)
                try? context.save()
                activeSessionId = session.id

                withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
                    previewReady = true
                }
                print("▶ Boundary started — \(hours)h \(minutes)m, theme: \(selectedTheme.name)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.smooth) { previewReady = false }
                }
            }) {
                Text(buttonLabel)
                    .font(.custom("InstrumentSerif-Italic", size: 22))
                    .foregroundColor(DSColor.ink.opacity(isActive ? 0.55 : 1.0))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background {
                        Capsule()
                            .fill(
                                isActive
                                    ? LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.85),
                                            Color.white.opacity(0.85)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        colors: [.white, DSColor.highlightYellowSoft],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                            )
                            .overlay {
                                Capsule()
                                    .stroke(
                                        DSColor.ink.opacity(isActive ? 0.20 : 0.38),
                                        lineWidth: 1
                                    )
                            }
                            .shadow(
                                color: DSColor.ink.opacity(isActive ? 0.06 : 0.16),
                                radius: 0, x: 1.5, y: 1.5
                            )
                    }
            }
            .buttonStyle(PreviewButtonStyle())
            .disabled(isActive)

            if previewReady {
                Text("boundary started ✓")
                    .font(.system(size: 11, weight: .light))
                    .foregroundColor(DSColor.inkSoft.opacity(0.5))
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: activeSessionId)
    }
}

// ─────────────────────────────────────────────
// MARK: - Scale Button Style
// ─────────────────────────────────────────────

struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
    }
}

// ─────────────────────────────────────────────
// MARK: - Preview Button Style
// ─────────────────────────────────────────────

struct PreviewButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(
                .interactiveSpring(response: 0.22, dampingFraction: 0.74),
                value: configuration.isPressed
            )
    }
}

// ─────────────────────────────────────────────
// MARK: - Timer Grain + RNG
// ─────────────────────────────────────────────
struct TimerGrain: View {
    var body: some View {
        Canvas { context, size in
            var rng = TimerRNG(seed: 42)
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

struct TimerRNG: RandomNumberGenerator {
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
    TimerView()
        .environment(ActiveMethodStore())
}
