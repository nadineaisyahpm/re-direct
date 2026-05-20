import Testing
import Foundation
@testable import re_direct

@MainActor
@Suite("ActiveMethodStore")
struct ActiveMethodStoreTests {

    @Test func initialStateIsNil() {
        let store = ActiveMethodStore()
        #expect(store.activeRedirectMethodSlug == nil)
    }

    @Test func setSlugIsObservable() {
        let store = ActiveMethodStore()
        store.activeRedirectMethodSlug = "watch"
        #expect(store.activeRedirectMethodSlug == "watch")
    }

    @Test func overwriteReplacesPreviousSlug() {
        let store = ActiveMethodStore()
        store.activeRedirectMethodSlug = "watch"
        store.activeRedirectMethodSlug = "read"
        #expect(store.activeRedirectMethodSlug == "read")
    }

    @Test func clearingToNilIsAllowed() {
        let store = ActiveMethodStore()
        store.activeRedirectMethodSlug = "deep-dive"
        store.activeRedirectMethodSlug = nil
        #expect(store.activeRedirectMethodSlug == nil)
    }

    @Test func initializerSeedsSlug() {
        let store = ActiveMethodStore(activeRedirectMethodSlug: "reflect")
        #expect(store.activeRedirectMethodSlug == "reflect")
    }
}
