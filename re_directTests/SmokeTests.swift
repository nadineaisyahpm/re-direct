import Testing
@testable import re_direct

@Suite("Smoke")
struct SmokeTests {

    @Test("test target is wired and host module is importable")
    func targetIsWired() {
        #expect(AIProviderPreference.auto == .auto)
    }
}
