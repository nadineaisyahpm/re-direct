import Foundation
import SwiftData

enum SeedImporterError: Error, Equatable, Sendable {
    case bundleLoad(String)
    case persistence(String)
    case trailReferencesMissingTopic(trailSlug: String, topicSlug: String)
    case trailStepReferencesMissingPrompt(trailSlug: String, promptSlug: String)
}

@MainActor
struct SeedImporter {

    private let loader: any CuriositySeedSource
    private let userDefaults: UserDefaults
    private let seedVersionKey: String

    init(
        loader: any CuriositySeedSource = SeedBundleLoader(),
        userDefaults: UserDefaults = .standard,
        seedVersionKey: String = "redirect.seed.installed_version"
    ) {
        self.loader = loader
        self.userDefaults = userDefaults
        self.seedVersionKey = seedVersionKey
    }

    func importIfNeeded(into context: ModelContext) throws {
        let seed: CuriositySeedDTO
        do {
            seed = try loader.load()
        } catch {
            throw SeedImporterError.bundleLoad(String(describing: error))
        }

        let installedVersion = userDefaults.object(forKey: seedVersionKey) as? Int ?? 0
        guard seed.seedVersion > installedVersion else { return }

        try importSeed(seed, into: context)
        userDefaults.set(seed.seedVersion, forKey: seedVersionKey)
    }

    func forceImport(into context: ModelContext) throws {
        let seed: CuriositySeedDTO
        do {
            seed = try loader.load()
        } catch {
            throw SeedImporterError.bundleLoad(String(describing: error))
        }
        try importSeed(seed, into: context)
        userDefaults.set(seed.seedVersion, forKey: seedVersionKey)
    }

    private func importSeed(_ seed: CuriositySeedDTO, into context: ModelContext) throws {
        try upsertReminderThemes(seed.reminderThemes, into: context)
        try upsertRedirectMethods(seed.redirectMethods, into: context)
        let topicsBySlug = try upsertTopics(seed.topics, seedVersion: seed.seedVersion, into: context)
        let promptsByTopicAndSlug = try upsertPrompts(seed.topics, topicsBySlug: topicsBySlug, into: context)
        try upsertTrails(
            seed.trails ?? [],
            topicsBySlug: topicsBySlug,
            promptsByTopicAndSlug: promptsByTopicAndSlug,
            into: context
        )

        do {
            try context.save()
        } catch {
            throw SeedImporterError.persistence(String(describing: error))
        }
    }

    private func upsertReminderThemes(_ items: [ReminderThemeDTO], into context: ModelContext) throws {
        let existing = try fetchBySlug(ReminderThemeRecord.self, in: context)
        for dto in items {
            let record = existing[dto.slug] ?? {
                let r = ReminderThemeRecord()
                r.slug = dto.slug
                context.insert(r)
                return r
            }()
            record.displayName = dto.displayName
            record.assetName = dto.assetName
        }
    }

    private func upsertRedirectMethods(_ items: [RedirectMethodDTO], into context: ModelContext) throws {
        let existing = try fetchBySlug(RedirectMethodRecord.self, in: context)
        for dto in items {
            let record = existing[dto.slug] ?? {
                let r = RedirectMethodRecord()
                r.slug = dto.slug
                context.insert(r)
                return r
            }()
            record.displayName = dto.displayName
            record.summary = dto.summary
        }
    }

    private func upsertTopics(
        _ items: [TopicDTO],
        seedVersion: Int,
        into context: ModelContext
    ) throws -> [String: CuriosityTopic] {
        let existing = try fetchBySlug(CuriosityTopic.self, in: context)
        var result: [String: CuriosityTopic] = [:]
        for dto in items {
            let topic = existing[dto.slug] ?? {
                let t = CuriosityTopic()
                t.slug = dto.slug
                context.insert(t)
                return t
            }()
            topic.title = dto.title
            topic.summary = dto.summary
            topic.coverAssetName = dto.coverAssetName
            topic.accentColorHex = dto.accentColorHex
            topic.seedVersion = seedVersion
            result[dto.slug] = topic
        }
        return result
    }

    private func upsertPrompts(
        _ topics: [TopicDTO],
        topicsBySlug: [String: CuriosityTopic],
        into context: ModelContext
    ) throws -> [String: [String: CuriosityPrompt]] {
        var byTopicAndSlug: [String: [String: CuriosityPrompt]] = [:]

        for topicDTO in topics {
            guard let topic = topicsBySlug[topicDTO.slug] else { continue }
            let existing = (topic.prompts ?? []).reduce(into: [String: CuriosityPrompt]()) { acc, prompt in
                if !prompt.slug.isEmpty { acc[prompt.slug] = prompt }
            }
            var byPromptSlug: [String: CuriosityPrompt] = [:]
            for dto in topicDTO.prompts {
                let prompt = existing[dto.slug] ?? {
                    let p = CuriosityPrompt()
                    p.slug = dto.slug
                    p.topic = topic
                    context.insert(p)
                    return p
                }()
                prompt.body = dto.body
                prompt.source = dto.source
                prompt.tier = dto.tier ?? "free"
                prompt.estimatedMinutes = dto.estimatedMinutes
                byPromptSlug[dto.slug] = prompt
            }
            byTopicAndSlug[topicDTO.slug] = byPromptSlug
        }
        return byTopicAndSlug
    }

    private func upsertTrails(
        _ items: [TrailDTO],
        topicsBySlug: [String: CuriosityTopic],
        promptsByTopicAndSlug: [String: [String: CuriosityPrompt]],
        into context: ModelContext
    ) throws {
        let existing = try fetchBySlug(TopicTrail.self, in: context)

        for dto in items {
            guard let topic = topicsBySlug[dto.topicSlug] else {
                throw SeedImporterError.trailReferencesMissingTopic(trailSlug: dto.slug, topicSlug: dto.topicSlug)
            }
            let promptsForTopic = promptsByTopicAndSlug[dto.topicSlug] ?? [:]

            let trail = existing[dto.slug] ?? {
                let t = TopicTrail()
                t.slug = dto.slug
                t.topic = topic
                context.insert(t)
                return t
            }()
            trail.topic = topic
            trail.title = dto.title
            trail.summary = dto.summary

            let existingStepsByOrder = (trail.steps ?? []).reduce(into: [Int: TopicTrailStep]()) { acc, step in
                acc[step.stepOrder] = step
            }

            for stepDTO in dto.steps {
                guard let prompt = promptsForTopic[stepDTO.promptSlug] else {
                    throw SeedImporterError.trailStepReferencesMissingPrompt(
                        trailSlug: dto.slug,
                        promptSlug: stepDTO.promptSlug
                    )
                }
                let step = existingStepsByOrder[stepDTO.stepOrder] ?? {
                    let s = TopicTrailStep()
                    s.trail = trail
                    s.stepOrder = stepDTO.stepOrder
                    context.insert(s)
                    return s
                }()
                step.prompt = prompt
                step.estimatedMinutes = stepDTO.estimatedMinutes
            }
        }
    }

    private func fetchBySlug<T: PersistentModel>(
        _ type: T.Type,
        in context: ModelContext
    ) throws -> [String: T] where T: SlugIdentifiable {
        let descriptor = FetchDescriptor<T>()
        let rows: [T]
        do {
            rows = try context.fetch(descriptor)
        } catch {
            throw SeedImporterError.persistence(String(describing: error))
        }
        return rows.reduce(into: [String: T]()) { acc, row in
            if !row.slug.isEmpty { acc[row.slug] = row }
        }
    }
}

protocol SlugIdentifiable {
    var slug: String { get }
}

extension CuriosityTopic: SlugIdentifiable {}
extension TopicTrail: SlugIdentifiable {}
extension ReminderThemeRecord: SlugIdentifiable {}
extension RedirectMethodRecord: SlugIdentifiable {}
