import SwiftUI
import SwiftData

// ─────────────────────────────────────────────
// MARK: - Onboarding View
// ─────────────────────────────────────────────

struct OnboardingView: View {

    // Persisted across cold launches. Flipping this to `true` causes the
    // RootView in re_directApp.swift to swap to AppTabView on the next
    // render — no fullScreenCover needed.
    //
    // v2 forward-pointer: the next onboarding slice (per
    // `docs/AI_INTEGRATION_PLAN.md` §12.6) will turn this screen into an
    // interest-collection step — "what do you want to be more curious
    // about?" — that writes `UserProfile.interestSeeds` so Daily Direct
    // and trail generation can personalize from day one instead of
    // relying on the hardcoded personal seed list in §12.2. The flag
    // here will move alongside `interestSeeds` into a single
    // `onboardingState` value at that point.
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    @State private var signInCoordinator = AppleSignInCoordinator()
    @Environment(\.modelContext) private var modelContext

    var body: some View {

        GeometryReader { geo in

            ZStack {

                LinearGradient(
                    colors: [
                        Color(hex: "#FFFFFF"),
                        Color(hex: "#B1B1B1")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                GrainOverlay()
                    .drawingGroup()
                    .ignoresSafeArea()

                CollageLayer(geo: geo)

                VStack(spacing: 0) {

                    Spacer()
                        .frame(height: geo.size.height * 0.28)

                    VStack(spacing: 0) {

                        (
                            Text("re:")
                                .font(.custom("InstrumentSerif-Italic", size: 58))
                            +
                            Text("direct")
                                .font(.custom("InstrumentSerif-Regular", size: 58))
                        )
                        .foregroundColor(Color(hex: "#2C2825"))
                        .tracking(-0.5)

                        Text("reshape your brain's algorithm")
                            .font(.system(size: 15, weight: .light))
                            .italic()
                            .foregroundColor(Color(hex: "#2C2825").opacity(0.6))
                            .tracking(0.1)
                            .padding(.top, 8)

                        Spacer().frame(height: 28)

                        Button(action: { onboardingComplete = true }) {
                            Text("sign up")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                                .frame(width: 260)
                                .padding(.vertical, 15)
                                .background(Color(hex: "#1A1410"))
                                .cornerRadius(28)
                        }

                        Spacer().frame(height: 12)

                        Button(action: { onboardingComplete = true }) {
                            Text("log in")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(Color(hex: "#2C2825"))
                                .frame(width: 260)
                                .padding(.vertical, 15)
                                .background(Color.clear)
                                .cornerRadius(28)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 28)
                                        .stroke(Color(hex: "#2C2825"), lineWidth: 1)
                                )
                        }

                        Text("or log in with")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(Color(hex: "#2C2825").opacity(0.45))
                            .padding(.top, 16)

                        HStack(spacing: 12) {
                            SocialButton(icon: "apple.logo", action: { Task { await signInWithApple() } })
                            SocialButton(icon: "globe",      action: { print("google tapped") })
                            SocialButton(icon: "xmark",      action: { print("x tapped") })
                        }
                        .padding(.top, 12)
                    }

                    Spacer()
                }
            }
            .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
    }

    @MainActor
    private func signInWithApple() async {
        // Apple Sign-In is wired but optional in v1 — see the deferral
        // notes in re_directApp.swift's RootView comment. The button
        // remains available because the entitlement is already configured
        // and the coordinator + Keychain persister are already on disk
        // (low-cost preservation in case App Store distribution becomes
        // real later). On success, the same `onboardingComplete` flag is
        // flipped as the plain sign-up/log-in buttons, so the post-auth
        // user journey is identical.
        do {
            let result = try await signInCoordinator.signIn()
            let persister = AppleSignInPersister(
                keychain: KeychainAppleIDStore(),
                context: modelContext
            )
            try persister.persist(result)
            onboardingComplete = true
        } catch {
            #if DEBUG
            print("⚠️ Apple Sign-In failed: \(error)")
            #endif
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Collage Layer
// ─────────────────────────────────────────────

struct CollageLayer: View {
    let geo: GeometryProxy

    var body: some View {
        ZStack {

            Image("collage-embryo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .offset(x: 0, y: -geo.size.height * 0.5 + 110)

            Image("collage-cat")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .offset(x: -(geo.size.width / 2 - 70), y: -geo.size.height * 0.25)
                .rotationEffect(.degrees(-5))

            Image("collage-doll")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .offset(x: geo.size.width / 2 - 30, y: geo.size.height * 0.15)
                .rotationEffect(.degrees(5))

            Image("collage-books")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 398, height: 398)
                .rotationEffect(.degrees(-8))
                .offset(x: -geo.size.width * 0.5 + 160, y: geo.size.height * 0.5 - 200)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Social Button
// ─────────────────────────────────────────────

struct SocialButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(Color(hex: "#2C2825"))
                .frame(width: 54, height: 46)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Grain Overlay
// ─────────────────────────────────────────────

struct GrainOverlay: View {

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandomGenerator(seed: 42)

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

// ─────────────────────────────────────────────
// MARK: - Seeded Random Generator
// ─────────────────────────────────────────────

struct SeededRandomGenerator: RandomNumberGenerator {
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
// MARK: - Hex Colour Extension
// ─────────────────────────────────────────────

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// ─────────────────────────────────────────────
// MARK: - Preview
// ─────────────────────────────────────────────

#Preview {
    OnboardingView()
}
