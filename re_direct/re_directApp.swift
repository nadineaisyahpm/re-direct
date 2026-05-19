import SwiftUI
import SwiftData
import CoreText

@main
struct re_directApp: App {

    init() {
        registerFont(named: "InstrumentSerif-Regular", extension: "ttf")
        registerFont(named: "InstrumentSerif-Italic", extension: "ttf")
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

    var body: some Scene {
        WindowGroup {
            OnboardingView()
        }
        .modelContainer(Self.sharedModelContainer)
    }
}
