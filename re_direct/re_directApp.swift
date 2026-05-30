import SwiftUI
import SwiftData
import CoreText

@main
struct re_directApp: App {

    init() {
        registerFont(named: "InstrumentSerif-Regular", extension: "ttf")
        registerFont(named: "InstrumentSerif-Italic", extension: "ttf")
        bootstrapSeedContent()
    }

    private func bootstrapSeedContent() {
        let context = Self.sharedModelContainer.mainContext
        do {
            try SeedImporter().importIfNeeded(into: context)
            #if DEBUG
            let topics = (try? context.fetch(FetchDescriptor<CuriosityTopic>()))?.count ?? 0
            let prompts = (try? context.fetch(FetchDescriptor<CuriosityPrompt>()))?.count ?? 0
            let trails = (try? context.fetch(FetchDescriptor<TopicTrail>()))?.count ?? 0
            print("✅ Seed import OK — topics=\(topics) prompts=\(prompts) trails=\(trails)")
            #endif
        } catch {
            // Non-fatal: app continues with whatever content is in the store.
            #if DEBUG
            print("⚠️ Seed import failed: \(error)")
            #endif
        }
    }

    private func registerFont(named name: String, extension ext: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            print("❌ Font file not found in bundle: \(name).\(ext)")
            return
        }
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if let error = error {
            print("❌ Failed to register \(name): \(error.takeRetainedValue())")
        } else {
            print("✅ Registered font: \(name)")
        }
    }

    @MainActor
    static let sharedModelContainer: ModelContainer = {
        do {
            return try ReDirectSchema.makeContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @MainActor
    static let sharedActiveMethodStore = ActiveMethodStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(Self.sharedActiveMethodStore)
        }
        .modelContainer(Self.sharedModelContainer)
    }
}

// ─────────────────────────────────────────────
// MARK: - Root view (onboarding gate)
// ─────────────────────────────────────────────
//
// Branches between `OnboardingView` and `AppTabView` based on a single
// UserDefaults flag set the first time the user finishes onboarding.
//
// Why UserDefaults (and not Keychain or SwiftData):
// - The flag has no security requirement — it's "did this device complete
//   the editorial onboarding screen once." Anyone with the device already
//   has full read access to all local data, so a Keychain wrapper would
//   add ceremony without security gain.
// - It correctly resets on uninstall, which is the desired behavior:
//   a fresh install should see the onboarding screen once.
// - SwiftData would be overkill for a single boolean.
//
// To reset the flag during testing: delete the app from the simulator/device
// and reinstall, OR in DEBUG: `UserDefaults.standard.removeObject(forKey:
// "onboardingComplete")` in lldb.
//
// Replaces the previous always-show-OnboardingView behavior which forced
// the user to re-tap "sign up" on every cold launch (QA1 finding F4.1).
// Apple Sign-In + Keychain identity (originally Slice 7.1) is intentionally
// deferred indefinitely — the app is single-user local-first by design and
// has no identity differentiation problem to solve.
private struct RootView: View {
    @AppStorage("onboardingComplete") private var onboardingComplete = false

    var body: some View {
        if onboardingComplete {
            AppTabView()
        } else {
            OnboardingView()
        }
    }
}
