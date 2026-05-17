//
//  OnboardingView.swift
//  re_direct
//
//  The first screen a new user sees. Goal: calm, editorial, dreamy.
//  No navigation logic yet — buttons just print to console.
//

import SwiftUI

// ─────────────────────────────────────────────
// MARK: - Onboarding View
// ─────────────────────────────────────────────

struct OnboardingView: View {

    // @State is a SwiftUI property wrapper that lets a view own and react to
    // a piece of data. When this flips to true, the fullScreenCover triggers.
    @State private var showDashboard = false

    var body: some View {

        // GeometryReader gives us the real screen dimensions so we can
        // position collage images proportionally on any device size.
        GeometryReader { geo in

            ZStack {

                // ── Layer 1: Warm beige gradient ──────────────────
                // #EDE8DF at the top — a warm parchment/cream tone.
                // Fades to a slightly deeper warm sand at the bottom.
                // Much warmer than the previous white/grey — matches Figma.
                LinearGradient(
                    colors: [
                        Color(hex: "#FFFFFF"),
                        Color(hex: "#B1B1B1")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // ── Layer 2: Coarse film grain ────────────────────
                // Larger dots, higher opacity than before —
                // reads like 35mm film grain rather than digital noise.
                GrainOverlay()
                    .drawingGroup()
                    .ignoresSafeArea()

                // ── Layer 3: Collage images ───────────────────────
                // Real PNG assets positioned to match the Figma layout.
                // Each image is partially cropped by the screen edge
                // using .clipped() on the parent ZStack + .ignoresSafeArea().
                // NOTE: Add these images to Assets.xcassets with the names:
                //   collage-embryo, collage-cat, collage-doll, collage-books
                // (Xcode strips the .png extension — use the name only)
                CollageLayer(geo: geo)

                // ── Layer 4: Main content block ───────────────────
                // Title → tagline → buttons → social, all in one tight VStack.
                // Positioned at ~36% from top to sit above screen centre.
                VStack(spacing: 0) {

                    Spacer()
                        .frame(height: geo.size.height * 0.28)

                    VStack(spacing: 0) {

                        // -- Title --------------------------------
                        // "re:" italic + "direct" regular — two Text views
                        // joined with + so each part has its own font style.
                        (
                            Text("re:")
                                .font(.custom("InstrumentSerif-Italic", size: 58))
                            +
                            Text("direct")
                                // Regular weight for "direct" — contrast with italic "re:"
                                .font(.custom("InstrumentSerif-Regular", size: 58))
                        )
                        .foregroundColor(Color(hex: "#2C2825"))
                        .tracking(-0.5)

                        // -- Tagline ------------------------------
                        // Italic, no underline, muted warm grey.
                        Text("reshape your brain's algorithm")
                            .font(.system(size: 15, weight: .light))
                            .italic()
                            .foregroundColor(Color(hex: "#2C2825").opacity(0.6))
                            .tracking(0.1)
                            .padding(.top, 8)

                        // Gap between tagline and buttons.
                        Spacer().frame(height: 28)

                        // -- Sign Up (solid black pill, white text) -
                        Button(action: { showDashboard = true }) {
                            Text("sign up")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.white)
                                .frame(width: 260)
                                .padding(.vertical, 15)
                                .background(Color(hex: "#1A1410"))
                                .cornerRadius(28)
                        }

                        // 12pt gap between buttons — as specified.
                        Spacer().frame(height: 12)

                        // -- Log In (transparent, dark border) ----
                        Button(action: { showDashboard = true }) {
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

                        // -- "or log in with" ---------------------
                        Text("or log in with")
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(Color(hex: "#2C2825").opacity(0.45))
                            .padding(.top, 16)

                        // -- Social icons -------------------------
                        // Three equal square cards, white bg, subtle shadow.
                        // Centered with equal spacing between them.
                        HStack(spacing: 12) {
                            SocialButton(icon: "apple.logo", action: { print("apple tapped") })
                            SocialButton(icon: "globe",      action: { print("google tapped") })
                            SocialButton(icon: "xmark",      action: { print("x tapped") })
                        }
                        .padding(.top, 12)
                    }

                    Spacer()
                }
            }
            // Clip the ZStack so collage images that hang off the edges
            // are cropped cleanly rather than overflowing.
            .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.light)
        // fullScreenCover presents DashboardView as a full-screen modal.
        // It triggers whenever showDashboard becomes true.
        // isPresented binds to our @State variable — when the cover is
        // dismissed, SwiftUI automatically sets showDashboard back to false.
        .fullScreenCover(isPresented: $showDashboard) {
            DashboardView()
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Collage Layer
// ─────────────────────────────────────────────
// Positions the four PNG collage images to match the Figma layout.
// Each image uses .offset() to place it relative to screen centre,
// and .rotationEffect() for the slight tilt.
// Images that hang off the edge are cropped by the parent .clipped().
//
// IMAGE SETUP — do this in Xcode before running:
//   1. Open Assets.xcassets in the navigator
//   2. Drag each PNG in and name it exactly:
//      collage-embryo, collage-cat, collage-doll, collage-books

struct CollageLayer: View {
    let geo: GeometryProxy

    var body: some View {
        ZStack {

            // ── collage-embryo ────────────────────────────────────
            // Top centre, 220x220pt, anchored to the very top edge.
            // y = -geo.size.height/2 + 110 puts the image centre at 110pt
            // from the top — so the top of the 220pt image sits at y=0
            // (the screen top), touching or overlapping the safe area.
            Image("collage-embryo")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 220)
                .offset(x: 0, y: -geo.size.height * 0.5 + 110)

            // ── collage-cat ───────────────────────────────────────
            // Left side, ~25% from top, -5° rotation.
            // 180x180pt — bigger so it reads well.
            // x: half the image (90pt) pushed past the left edge so it's
            // flush — no floating gap between image and screen edge.
            Image("collage-cat")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .offset(x: -(geo.size.width / 2 - 70), y: -geo.size.height * 0.25)
                .rotationEffect(.degrees(-5))

            // ── collage-doll ──────────────────────────────────────
            // Right side, ~65% from top, +5° rotation.
            // 180x180pt — bigger so it reads well.
            // x: half the image (90pt) pushed past the right edge so it's
            // flush — no floating gap between image and screen edge.
            Image("collage-doll")
                .renderingMode(.original)
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .offset(x: geo.size.width / 2 - 30, y: geo.size.height * 0.15)
                .rotationEffect(.degrees(5))

            // ── collage-books ─────────────────────────────────────
            // Bottom left, large and prominent — only the very bottom
            // edge should be cropped, not drowning into the screen.
            // 400x400pt so the books read clearly at full size.
            // y offset: geo.size.height/2 - 200 puts the centre of the image
            // 200pt above the bottom edge, so the bottom ~80pt is cropped.
            // x offset: flush left, left edge of image at screen left edge.
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
// Small square card for Apple / Google / X login.
// White background, subtle drop shadow, no hard border.
// Shadow gives it lift off the beige background without a harsh line.

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
                // Shadow replaces the border — softer, more elevated feel.
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: - Grain Overlay
// ─────────────────────────────────────────────
// Coarser grain than before — larger dots, higher opacity range.
// Reads like 35mm film grain rather than fine digital noise.
// Uses a seeded RNG so the pattern is stable across re-renders.

struct GrainOverlay: View {

    var body: some View {
        Canvas { context, size in
            var rng = SeededRandomGenerator(seed: 42)

            // 1800 dots but larger and more opaque than before —
            // fewer dots at bigger size = coarser, more visible grain.
            for _ in 0..<1800 {
                let x       = CGFloat.random(in: 0...size.width,  using: &rng)
                let y       = CGFloat.random(in: 0...size.height, using: &rng)
                // Dot size: 1–2.5pt — noticeably larger than the previous 0.5–1pt.
                let radius  = CGFloat.random(in: 1.0...2.5,       using: &rng)
                // Opacity: 0.06–0.18 — more visible than before (was 0.04–0.13).
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
// Fixed-seed RNG so grain pattern doesn't shift on re-render.

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
