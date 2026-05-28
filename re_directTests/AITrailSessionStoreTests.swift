import Testing
import Foundation
@testable import re_direct

@MainActor
@Suite("AITrailSessionStore (Phase 6E QA0 Slice B)")
struct AITrailSessionStoreTests {

    // MARK: - Fixtures

    private func makeKey(
        engagementID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        title: String = "bioluminescence",
        slug: String = "read",
        bucket: String = "today",
        seeds: String = "ai|machine learning|neuroscience",
        locale: String = "en-US",
        maxSteps: Int = 4
    ) -> AITrailCacheKey {
        AITrailCacheKey(
            engagementID: engagementID,
            normalizedRootTitle: title,
            methodSlug: slug,
            recencyBucket: bucket,
            seedsFingerprint: seeds,
            locale: locale,
            maxSteps: maxSteps
        )
    }

    private func makeResponse(
        id: String = "01HZX",
        title: String = "Trail title",
        rootTitle: String = "bioluminescence",
        steps: [AITrailStep] = []
    ) -> AITrailResponse {
        AITrailResponse(
            id: id,
            title: title,
            summary: "summary",
            rootTitle: rootTitle,
            steps: steps,
            provider: "deepseek",
            modelVersion: "deepseek-v4-flash",
            promptInputHash: "h",
            cached: false,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    // MARK: - Defaults

    @Test("Default TTL is 1 hour")
    func defaultTTLIsOneHour() {
        #expect(AITrailSessionStore.defaultTTL == 60 * 60)
    }

    @Test("Fresh instance has no entries (lookup returns nil)")
    func freshInstanceLookupReturnsNil() {
        let store = AITrailSessionStore()
        let key = makeKey()
        #expect(store.lookup(key) == nil)
    }

    // MARK: - Lookup / store

    @Test("Stored response is returned on lookup")
    func storedResponseReturnedOnLookup() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = AITrailSessionStore(now: { now })
        let key = makeKey()
        let response = makeResponse(title: "stored")

        store.store(response, for: key)

        let cached = store.lookup(key)
        #expect(cached?.title == "stored")
    }

    @Test("Store overwrites an existing entry under the same key")
    func storeOverwritesExistingEntry() {
        let store = AITrailSessionStore()
        let key = makeKey()

        store.store(makeResponse(title: "first"),  for: key)
        store.store(makeResponse(title: "second"), for: key)

        #expect(store.lookup(key)?.title == "second")
    }

    @Test("Different keys do not collide")
    func differentKeysDoNotCollide() {
        let store = AITrailSessionStore()

        let key1 = makeKey(slug: "read")
        let key2 = makeKey(slug: "watch")

        store.store(makeResponse(title: "read trail"),  for: key1)
        store.store(makeResponse(title: "watch trail"), for: key2)

        #expect(store.lookup(key1)?.title == "read trail")
        #expect(store.lookup(key2)?.title == "watch trail")
    }

    // MARK: - TTL

    @Test("Entry within TTL is returned")
    func entryWithinTTLReturned() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var clock = start
        let store = AITrailSessionStore(ttl: 60 * 60, now: { clock })

        let key = makeKey()
        store.store(makeResponse(title: "fresh"), for: key)

        // 59 minutes later → still fresh.
        clock = start.addingTimeInterval(59 * 60)
        #expect(store.lookup(key)?.title == "fresh")
    }

    @Test("Entry past TTL is treated as a miss")
    func entryPastTTLIsMiss() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var clock = start
        let store = AITrailSessionStore(ttl: 60 * 60, now: { clock })

        let key = makeKey()
        store.store(makeResponse(title: "stale"), for: key)

        // Exactly at TTL → miss (>= comparison).
        clock = start.addingTimeInterval(60 * 60)
        #expect(store.lookup(key) == nil)

        // Past TTL → miss.
        clock = start.addingTimeInterval(60 * 60 + 1)
        #expect(store.lookup(key) == nil)
    }

    @Test("Stale entries are pruned on lookup")
    func staleEntryPrunedOnLookup() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var clock = start
        let store = AITrailSessionStore(ttl: 60 * 60, now: { clock })

        let key = makeKey()
        store.store(makeResponse(title: "stale"), for: key)

        // Advance past TTL and look up — should prune.
        clock = start.addingTimeInterval(60 * 60 + 10)
        _ = store.lookup(key)

        // Rewind the clock to before TTL boundary — entry should still
        // be gone (we pruned it on the stale read).
        clock = start.addingTimeInterval(10)
        #expect(store.lookup(key) == nil)
    }

    // MARK: - Remove / reset

    @Test("Remove deletes a single key")
    func removeDeletesSingleKey() {
        let store = AITrailSessionStore()
        let key1 = makeKey(slug: "read")
        let key2 = makeKey(slug: "watch")

        store.store(makeResponse(title: "a"), for: key1)
        store.store(makeResponse(title: "b"), for: key2)

        store.remove(key1)

        #expect(store.lookup(key1) == nil)
        #expect(store.lookup(key2)?.title == "b")
    }

    @Test("Reset clears every entry")
    func resetClearsEverything() {
        let store = AITrailSessionStore()
        store.store(makeResponse(title: "a"), for: makeKey(slug: "read"))
        store.store(makeResponse(title: "b"), for: makeKey(slug: "watch"))
        store.store(makeResponse(title: "c"), for: makeKey(slug: "reflect"))

        store.reset()

        #expect(store.lookup(makeKey(slug: "read")) == nil)
        #expect(store.lookup(makeKey(slug: "watch")) == nil)
        #expect(store.lookup(makeKey(slug: "reflect")) == nil)
    }

    // MARK: - loadingResponse(for:call:)

    @Test("loadingResponse: cache hit short-circuits without invoking call")
    func loadingResponseCacheHitSkipsCall() async throws {
        let store = AITrailSessionStore()
        let key = makeKey()
        let prefetched = makeResponse(title: "from-cache")
        store.store(prefetched, for: key)

        var callInvocations = 0
        let result = try await store.loadingResponse(for: key) {
            callInvocations += 1
            return self.makeResponse(title: "from-network")
        }

        #expect(callInvocations == 0)
        #expect(result.title == "from-cache")
    }

    @Test("loadingResponse: cache miss invokes call and stores the result")
    func loadingResponseCacheMissCallsAndStores() async throws {
        let store = AITrailSessionStore()
        let key = makeKey()

        var callInvocations = 0
        let result = try await store.loadingResponse(for: key) {
            callInvocations += 1
            return self.makeResponse(title: "freshly-fetched")
        }

        #expect(callInvocations == 1)
        #expect(result.title == "freshly-fetched")
        // Subsequent lookup hits the cache.
        #expect(store.lookup(key)?.title == "freshly-fetched")
    }

    @Test("loadingResponse: failure propagates and does NOT cache")
    func loadingResponseFailureDoesNotCache() async throws {
        let store = AITrailSessionStore()
        let key = makeKey()

        enum TestError: Error, Equatable { case boom }

        do {
            _ = try await store.loadingResponse(for: key) {
                throw TestError.boom
            }
            Issue.record("Expected throw")
        } catch let error as TestError {
            #expect(error == .boom)
        }

        // Cache must remain empty after a failure.
        #expect(store.lookup(key) == nil)
    }

    @Test("loadingResponse: second call after failure re-tries (no negative cache)")
    func loadingResponseSecondCallAfterFailureRetries() async throws {
        let store = AITrailSessionStore()
        let key = makeKey()

        enum TestError: Error { case boom }

        var callInvocations = 0
        do {
            _ = try await store.loadingResponse(for: key) {
                callInvocations += 1
                throw TestError.boom
            }
            Issue.record("Expected throw")
        } catch {
            // expected
        }

        // Second call should attempt the network again — no negative caching.
        let result = try await store.loadingResponse(for: key) {
            callInvocations += 1
            return self.makeResponse(title: "recovered")
        }

        #expect(callInvocations == 2)
        #expect(result.title == "recovered")
        #expect(store.lookup(key)?.title == "recovered")
    }
}
