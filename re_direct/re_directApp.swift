//
//  re_directApp.swift
//  re_direct
//
//  Created by nadine on 17/5/26.
//

import SwiftUI
import SwiftData
import CoreText

@main
struct re_directApp: App {

    init() {
        // Register Instrument Serif fonts manually using CoreText.
        // This bypasses UIAppFonts / Info.plist entirely — we find the
        // font files directly in the app bundle and register them at launch.
        // This is the most reliable approach for multi-platform Xcode projects.
        registerFont(named: "InstrumentSerif-Regular", extension: "ttf")
        registerFont(named: "InstrumentSerif-Italic", extension: "ttf")
    }

    // Finds a font file in the bundle and registers it with CoreText.
    // Once registered, SwiftUI's .custom("PostScriptName", size:) can use it.
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

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Show the onboarding screen on launch.
            // Swap this back to ContentView() once auth is wired up.
            OnboardingView()
        }
        .modelContainer(sharedModelContainer)
    }
}
