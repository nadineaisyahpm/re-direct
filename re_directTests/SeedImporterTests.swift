import Testing
import Foundation
import SwiftData
@testable import re_direct

@MainActor
@Suite("SeedImporter")
struct SeedImporterTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema(ReDirectSchema.allModels)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    private func makeDefaults(suite: String = UUID().uuidString) -> UserDefaults {
        let d = UserDefaults(suiteName: suite)!
        d.removePersistentDomain(forName: suite)
        return d
    }

    @Test func importsAllEntitiesOnFreshStore() throws {
        let context = try makeContext()
        let importer = SeedImporter(
            loader: TestSeedFixtures.minimalSource(),
            userDefaults: makeDefaults(),
            seedVersionKey: "test.seed.version"
        )
        try importer.importIfNeeded(into: context)

        let topics = try context.fetch(FetchDescriptor<CuriosityTopic>())
        #expect(topics.count == 1)
        #expect(topics.first?.slug == "bioluminescence")

        let prompts = try context.fetch(FetchDescriptor<CuriosityPrompt>())
        #expect(prompts.count == 2)

        let trails = try context.fetch(FetchDescriptor<TopicTrail>())
        #expect(trails.count == 1)
        #expect(trails.first?.steps?.count == 2)

        let themes = try context.fetch(FetchDescriptor<ReminderTheme>())
        #expect(themes.count == 1)

        let methods = try context.fetch(FetchDescriptor<RedirectMethod>())
        #expect(methods.count == 1)
    }

    @Test func isIdempotentAcrossRunsAtSameVersion() throws {
        let context = try makeContext()
        let defaults = makeDefaults()
        let importer = SeedImporter(
            loader: TestSeedFixtures.minimalSource(),
            userDefaults: defaults,
            seedVersionKey: "test.seed.version"
        )
        try importer.importIfNeeded(into: context)
        try importer.importIfNeeded(into: context)
        try importer.importIfNeeded(into: context)

        let topics = try context.fetch(FetchDescriptor<CuriosityTopic>())
        #expect(topics.count == 1)
        let prompts = try context.fetch(FetchDescriptor<CuriosityPrompt>())
        #expect(prompts.count == 2)
    }

    @Test func skipsImportWhenInstalledVersionMatchesOrExceeds() throws {
        let context = try makeContext()
        let defaults = makeDefaults()
        defaults.set(5, forKey: "test.seed.version")

        let importer = SeedImporter(
            loader: TestSeedFixtures.minimalSource(seedVersion: 1),
            userDefaults: defaults,
            seedVersionKey: "test.seed.version"
        )
        try importer.importIfNeeded(into: context)

        let topics = try context.fetch(FetchDescriptor<CuriosityTopic>())
        #expect(topics.isEmpty)
    }

    @Test func reImportsOnVersionBump() throws {
        let context = try makeContext()
        let defaults = makeDefaults()
        let key = "test.seed.version"

        try SeedImporter(
            loader: TestSeedFixtures.minimalSource(seedVersion: 1),
            userDefaults: defaults,
            seedVersionKey: key
        ).importIfNeeded(into: context)

        // Bump version, simulating new seed file shipped in a build.
        try SeedImporter(
            loader: TestSeedFixtures.minimalSource(seedVersion: 2),
            userDefaults: defaults,
            seedVersionKey: key
        ).importIfNeeded(into: context)

        let topics = try context.fetch(FetchDescriptor<CuriosityTopic>())
        #expect(topics.count == 1)
        #expect(topics.first?.seedVersion == 2)
    }

    @Test func throwsOnTrailReferencingMissingPrompt() throws {
        let context = try makeContext()
        let importer = SeedImporter(
            loader: TestSeedFixtures.brokenTrailSource(),
            userDefaults: makeDefaults(),
            seedVersionKey: "test.seed.version"
        )
        #expect(throws: SeedImporterError.self) {
            try importer.importIfNeeded(into: context)
        }
    }
}
