import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("ReflectionPrompt")
struct ReflectionPromptTests {

    // MARK: helpers

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = UUID().uuidString
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    private static let seedJSON = """
    {
      "seed_version": 1,
      "generated_at": "2026-01-01T00:00:00Z",
      "locale": "en-US",
      "topics": [
        {
          "slug": "t",
          "title": "T",
          "summary": "s",
          "cover_asset_name": "C",
          "accent_color_hex": "#111111",
          "prompts": [
            { "slug": "p", "body": "b", "source": "seed", "tier": "free", "estimated_minutes": 5 }
          ]
        }
      ],
      "reminder_themes": [
        { "slug": "warm-paper", "display_name": "Warm Paper", "asset_name": "Reminder_WarmPaper" }
      ],
      "redirect_methods": [
        { "slug": "reflect", "display_name": "Reflect", "summary": "Quiet minutes." }
      ],
      "reflection_prompts": [
        {
          "slug": "what-were-you-looking-for",
          "body": "What were you actually looking for?",
          "tone": "honest",
          "estimated_minutes": 2,
          "source": "seed",
          "mood_affinity": ["restless"],
          "context": "post-ritual"
        },
        {
          "slug": "five-small-things",
          "body": "List five small things.",
          "tone": "curious",
          "estimated_minutes": 3,
          "source": "seed",
          "mood_affinity": [],
          "context": "reflect-method"
        },
        {
          "slug": "what-question-are-you-carrying",
          "body": "What question are you carrying?",
          "tone": "tender",
          "estimated_minutes": 3,
          "source": "seed",
          "context": null
        }
      ]
    }
    """

    private func decode(_ json: String, seedVersion: Int = 1) throws -> CuriositySeedDTO {
        let raw = json.replacingOccurrences(
            of: "\"seed_version\": 1,",
            with: "\"seed_version\": \(seedVersion),"
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CuriositySeedDTO.self, from: Data(raw.utf8))
    }

    private func source(_ seedVersion: Int = 1) -> InMemorySeedSource {
        InMemorySeedSource(seed: try! decode(Self.seedJSON, seedVersion: seedVersion))
    }

    private func fetchAllPrompts(_ context: ModelContext) throws -> [ReflectionPrompt] {
        try context.fetch(FetchDescriptor<ReflectionPrompt>())
    }

    // MARK: tests

    @Test func decodeIncludesReflectionPrompts() throws {
        let seed = try decode(Self.seedJSON)
        #expect(seed.reflectionPrompts?.count == 3)
        #expect(seed.reflectionPrompts?.first?.slug == "what-were-you-looking-for")
        #expect(seed.reflectionPrompts?.first?.context == "post-ritual")
    }

    @Test func decodeWithoutReflectionPromptsLeavesNil() throws {
        // The minimal fixture in TestSeedFixtures has no reflection_prompts key —
        // back-compat assertion that the field is truly optional.
        let seed = try TestSeedFixtures.decode(TestSeedFixtures.minimalJSON)
        #expect(seed.reflectionPrompts == nil)
    }

    @Test func roundTripPersistence() throws {
        let context = try makeContext()
        let p = ReflectionPrompt()
        p.slug = "x"
        p.body = "body"
        p.tone = "gentle"
        p.estimatedMinutes = 4
        p.source = "seed"
        p.moodAffinity = ["restless", "curious"]
        p.context = "reflect-method"
        context.insert(p)
        try context.save()

        let rows = try fetchAllPrompts(context)
        let one = try #require(rows.first)
        #expect(one.slug == "x")
        #expect(one.body == "body")
        #expect(one.tone == "gentle")
        #expect(one.estimatedMinutes == 4)
        #expect(one.source == "seed")
        #expect(one.moodAffinity == ["restless", "curious"])
        #expect(one.context == "reflect-method")
        #expect(one.deletedAt == nil)
    }

    @Test func sourceAndContextValuesArePersistedPermissively() throws {
        // Model is permissive at storage; importer / surface enforces canon.
        let context = try makeContext()
        for (slug, src, ctx) in [
            ("a", "seed",        "reflect-method"),
            ("b", "ai-runtime",  "post-ritual"),
            ("c", "ai-bootstrap", nil as String?)
        ] {
            let p = ReflectionPrompt()
            p.slug = slug
            p.body = "b"
            p.source = src
            p.context = ctx
            context.insert(p)
        }
        try context.save()

        let rows = try fetchAllPrompts(context)
        #expect(rows.count == 3)
        #expect(Set(rows.map { $0.source }) == ["seed", "ai-runtime", "ai-bootstrap"])
        #expect(rows.contains(where: { $0.context == nil }))
    }

    @Test func importerInsertsReflectionPrompts() throws {
        let context = try makeContext()
        let importer = SeedImporter(
            loader: source(),
            userDefaults: makeDefaults(),
            seedVersionKey: "test.ref.version"
        )
        try importer.importIfNeeded(into: context)

        let rows = try fetchAllPrompts(context)
        #expect(rows.count == 3)

        let bySlug = Dictionary(uniqueKeysWithValues: rows.map { ($0.slug, $0) })
        let looking = try #require(bySlug["what-were-you-looking-for"])
        #expect(looking.body == "What were you actually looking for?")
        #expect(looking.tone == "honest")
        #expect(looking.estimatedMinutes == 2)
        #expect(looking.source == "seed")
        #expect(looking.moodAffinity == ["restless"])
        #expect(looking.context == "post-ritual")

        let carrying = try #require(bySlug["what-question-are-you-carrying"])
        #expect(carrying.context == nil)
        #expect(carrying.moodAffinity == [])
    }

    @Test func importerIsIdempotent() throws {
        let context = try makeContext()
        let defaults = makeDefaults()
        let importer1 = SeedImporter(
            loader: source(1),
            userDefaults: defaults,
            seedVersionKey: "test.ref.idem"
        )
        try importer1.importIfNeeded(into: context)
        let firstCount = try fetchAllPrompts(context).count

        // Same version → importIfNeeded is a no-op.
        try importer1.importIfNeeded(into: context)
        #expect(try fetchAllPrompts(context).count == firstCount)

        // forceImport with the same seed should also not duplicate by slug.
        try importer1.forceImport(into: context)
        #expect(try fetchAllPrompts(context).count == firstCount)
    }

    @Test func versionBumpUpdatesChangedFields() throws {
        let context = try makeContext()
        let defaults = makeDefaults()

        // v1: original.
        let importer1 = SeedImporter(
            loader: source(1),
            userDefaults: defaults,
            seedVersionKey: "test.ref.bump"
        )
        try importer1.importIfNeeded(into: context)

        // v2: a fresh JSON with edits to "five-small-things". Avoiding
        // string-substitution on the seedJSON literal because the """
        // indentation strip makes anchor patterns fragile.
        let editedJSON = """
        {
          "seed_version": 2,
          "generated_at": "2026-01-01T00:00:00Z",
          "locale": "en-US",
          "topics": [
            {
              "slug": "t",
              "title": "T",
              "summary": "s",
              "cover_asset_name": "C",
              "accent_color_hex": "#111111",
              "prompts": [
                { "slug": "p", "body": "b", "source": "seed", "tier": "free", "estimated_minutes": 5 }
              ]
            }
          ],
          "reminder_themes": [
            { "slug": "warm-paper", "display_name": "Warm Paper", "asset_name": "Reminder_WarmPaper" }
          ],
          "redirect_methods": [
            { "slug": "reflect", "display_name": "Reflect", "summary": "Quiet minutes." }
          ],
          "reflection_prompts": [
            { "slug": "what-were-you-looking-for", "body": "What were you actually looking for?", "tone": "honest", "estimated_minutes": 2, "source": "seed", "mood_affinity": ["restless"], "context": "post-ritual" },
            { "slug": "five-small-things", "body": "List five small things you noticed today.", "tone": "gentle", "estimated_minutes": 4, "source": "seed", "mood_affinity": [], "context": "reflect-method" },
            { "slug": "what-question-are-you-carrying", "body": "What question are you carrying?", "tone": "tender", "estimated_minutes": 3, "source": "seed", "context": null }
          ]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let v2 = try decoder.decode(CuriositySeedDTO.self, from: Data(editedJSON.utf8))
        let importer2 = SeedImporter(
            loader: InMemorySeedSource(seed: v2),
            userDefaults: defaults,
            seedVersionKey: "test.ref.bump"
        )
        try importer2.importIfNeeded(into: context)

        let rows = try fetchAllPrompts(context)
        #expect(rows.count == 3) // no new rows, upsert by slug
        let edited = try #require(rows.first(where: { $0.slug == "five-small-things" }))
        #expect(edited.body == "List five small things you noticed today.")
        #expect(edited.tone == "gentle")
        #expect(edited.estimatedMinutes == 4)
    }
}
