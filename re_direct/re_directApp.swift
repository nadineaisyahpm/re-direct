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
            OnboardingView()
                .environment(Self.sharedActiveMethodStore)
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
