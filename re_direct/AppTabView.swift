import SwiftUI


struct AppTabView: View {

    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tag(0)
                .toolbar(.hidden, for: .tabBar)

            TimerView()
                .tag(1)
                .toolbar(.hidden, for: .tabBar)

            RetualsView()
                .tag(2)
                .toolbar(.hidden, for: .tabBar)

            ReLogView()
                .tag(3)
                .toolbar(.hidden, for: .tabBar)

            SettingsView()
                .tag(4)
                .toolbar(.hidden, for: .tabBar)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            SharedNavBar(selectedTab: $selectedTab)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .padding(.top, 8)
                .background(.clear)
        }
        .preferredColorScheme(.light)
    }
}


struct SharedNavBar: View {

    @Binding var selectedTab: Int

    @State private var indicatorIsSettling = false

    private let tabs: [(icon: String, label: String)] = [
        ("leaf.fill",         "home"),
        ("clock.fill",        "timer"),
        ("hourglass",         "usage"),
        ("waveform.path.ecg", "re:log"),
        ("gearshape.fill",    "settings")
    ]

    var body: some View {
        GeometryReader { geo in
            let tabWidth = geo.size.width / CGFloat(tabs.count)
            let capsuleInset: CGFloat = 6
            let capsuleX = tabWidth * CGFloat(selectedTab) + capsuleInset / 2

            ZStack(alignment: .leading) {

                PaperGlassIndicator()
                    .frame(width: tabWidth - capsuleInset, height: geo.size.height - 12)
                    .scaleEffect(
                        indicatorIsSettling
                            ? CGSize(width: 0.96, height: 0.93)
                            : CGSize(width: 1.0, height: 1.0)
                    )
                    .offset(x: capsuleX, y: 0)
                    .animation(.spring(response: 0.34, dampingFraction: 0.92), value: selectedTab)
                    .animation(
                        indicatorIsSettling
                            ? .spring(response: 0.22, dampingFraction: 0.74)
                            : .spring(response: 0.32, dampingFraction: 0.92),
                        value: indicatorIsSettling
                    )

                HStack(spacing: 0) {
                    ForEach(tabs.indices, id: \.self) { index in
                        let isSelected = selectedTab == index

                        Button(action: {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.92)) {
                                selectedTab = index
                            }
                            triggerSoftSettle()
                        }) {
                            VStack(spacing: 3) {
                                Image(systemName: tabs[index].icon)
                                    .font(.system(size: 17, weight: isSelected ? .medium : .regular))
                                    .foregroundColor(
                                        isSelected
                                            ? Color(hex: "#2C2825")
                                            : Color(hex: "#2C2825").opacity(0.38)
                                    )
                                    .animation(.spring(response: 0.32, dampingFraction: 0.9), value: selectedTab)

                                if isSelected {
                                    Text(tabs[index].label)
                                        .font(.custom("InstrumentSerif-Italic", size: 10))
                                        .foregroundColor(Color(hex: "#2C2825"))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                                }
                            }
                            .frame(width: tabWidth, height: geo.size.height)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: selectedTab)
                    }
                }
            }
        }
        .frame(height: 56)
        .padding(.horizontal, 10)
        .background(PaperGlassBarBackground())
    }

    private func triggerSoftSettle() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.74)) {
            indicatorIsSettling = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.92)) {
                indicatorIsSettling = false
            }
        }
    }
}


private struct PaperGlassBarBackground: View {
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay {
                Capsule().fill(Color(hex: "#FFF8EC").opacity(0.26))
            }
            .overlay {
                Capsule().stroke(Color(hex: "#2C2825").opacity(0.09), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 14, x: 0, y: 4)
    }
}


private struct PaperGlassIndicator: View {
    var body: some View {
        Capsule()
            .fill(.thinMaterial)
            .overlay {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFFDF7").opacity(0.78),
                                Color(hex: "#EFE4D1").opacity(0.58)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                Capsule().stroke(Color(hex: "#2C2825").opacity(0.10), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.045), radius: 7, x: 0, y: 2)
    }
}


struct PlaceholderTabView: View {
    let title: String
    let icon: String

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#FFFFFF"), Color(hex: "#B1B1B1")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(Color(hex: "#2C2825").opacity(0.3))

                Text(title)
                    .font(.custom("InstrumentSerif-Italic", size: 22))
                    .foregroundColor(Color(hex: "#2C2825").opacity(0.3))
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    AppTabView()
}
