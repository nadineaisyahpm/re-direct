import Testing
import Foundation
@testable import re_direct

private func makeTopic(id: Int = 7, title: String = "Stored") -> ReDirectTopic {
    ReDirectTopic(
        id: id,
        title: title,
        subtitle: "stored body",
        imageURL: "stored_cover",
        colorHex: "#111111",
        barHeight: 0,
        barColorHex: "",
        articleCount: 0,
        videoCount: 0,
        totalTime: "",
        platformStats: []
    )
}

/// A small helper that simulates Dashboard's `.task` body so we can prove
/// the throttling contract without instantiating SwiftUI. Each invocation
/// of `runOnce()` decides whether to call `attempt` based on the store's
/// state — exactly the way `DailyDirectSection.task` does.
@MainActor
private func runOnce(
    on store: DailyDirectSessionStore,
    attempt: () async -> ReDirectTopic?
) async -> ReDirectTopic? {
    if let cached = store.aiCard { return cached }
    if store.hasAttempted { return nil }
    store.hasAttempted = true
    if let topic = await attempt() {
        store.aiCard = topic
        return topic
    }
    return nil
}

@MainActor
@Suite("DailyDirectSessionStore")
struct DailyDirectSessionStoreTests {

    @Test func startsEmptyAndNotAttempted() {
        let store = DailyDirectSessionStore()
        #expect(store.aiCard == nil)
        #expect(store.hasAttempted == false)
    }

    @Test func instancesAreIndependent() {
        // Tests should NOT mutate `.shared`; they instantiate fresh stores.
        // Sanity-check that two instances don't bleed state.
        let a = DailyDirectSessionStore()
        let b = DailyDirectSessionStore()
        a.aiCard = makeTopic()
        a.hasAttempted = true
        #expect(b.aiCard == nil)
        #expect(b.hasAttempted == false)
    }

    @Test func attemptsExactlyOnceWhenProxySucceeds() async {
        let store = DailyDirectSessionStore()
        var attemptCount = 0
        let attempt: () async -> ReDirectTopic? = {
            attemptCount += 1
            return makeTopic()
        }

        let first = await runOnce(on: store, attempt: attempt)
        #expect(first?.title == "Stored")
        #expect(attemptCount == 1)
        #expect(store.hasAttempted == true)
        #expect(store.aiCard?.title == "Stored")

        // Second appearance: hits the in-memory card, no new attempt.
        let second = await runOnce(on: store, attempt: attempt)
        #expect(second?.title == "Stored")
        #expect(attemptCount == 1)

        // Third: still cached.
        _ = await runOnce(on: store, attempt: attempt)
        #expect(attemptCount == 1)
    }

    @Test func doesNotRetryAfterFailureWithinSameSession() async {
        let store = DailyDirectSessionStore()
        var attemptCount = 0
        let failingAttempt: () async -> ReDirectTopic? = {
            attemptCount += 1
            return nil  // simulates resolver returning .seedFallback
        }

        // First appearance: tries, fails.
        let first = await runOnce(on: store, attempt: failingAttempt)
        #expect(first == nil)
        #expect(attemptCount == 1)
        #expect(store.hasAttempted == true)
        #expect(store.aiCard == nil)

        // Second appearance: hasAttempted is true; no retry.
        let second = await runOnce(on: store, attempt: failingAttempt)
        #expect(second == nil)
        #expect(attemptCount == 1, "Should not retry after a failed attempt in the same session")
    }

    @Test func freshStoreSimulatesColdLaunchRetry() async {
        // After a "cold launch" (new store instance), the gate resets and
        // a new attempt happens. This is the only way iOS gets a retry
        // after a failed-during-this-session attempt.
        let coldStoreA = DailyDirectSessionStore()
        var attemptCount = 0
        let failingAttempt: () async -> ReDirectTopic? = {
            attemptCount += 1
            return nil
        }
        _ = await runOnce(on: coldStoreA, attempt: failingAttempt)
        #expect(attemptCount == 1)

        // Simulate cold launch with a fresh store.
        let coldStoreB = DailyDirectSessionStore()
        _ = await runOnce(on: coldStoreB, attempt: failingAttempt)
        #expect(attemptCount == 2, "A fresh app session should attempt once")
    }

    @Test func successCachesAcrossSimulatedAppearances() async {
        // Many `runOnce(...)` calls against the same store with a failing
        // attempt callable shouldn't be invoked once the store has
        // cached a topic.
        let store = DailyDirectSessionStore()
        store.aiCard = makeTopic(id: 99, title: "Already Cached")
        store.hasAttempted = true

        var attemptCount = 0
        let attempt: () async -> ReDirectTopic? = {
            attemptCount += 1
            return makeTopic(id: 0, title: "Should Not Be Used")
        }

        for _ in 0..<5 {
            _ = await runOnce(on: store, attempt: attempt)
        }
        #expect(attemptCount == 0, "Pre-populated card short-circuits all attempts")
        #expect(store.aiCard?.title == "Already Cached")
    }
}
