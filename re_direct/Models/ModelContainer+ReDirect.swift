import Foundation
import SwiftData

enum ReDirectSchema {
    static let allModels: [any PersistentModel.Type] = [
        UserProfile.self,
        CuriosityTopic.self,
        CuriosityPrompt.self,
        TopicTrail.self,
        TopicTrailStep.self,
        ReminderTheme.self,
        RedirectMethod.self,
        Ritual.self,
        RitualSelection.self,
        TimerSession.self,
        ReflectionEntry.self,
        TrackedAppSelection.self,
        ScreenTimeSummary.self,
        AIRecommendation.self,
        CuriosityEngagement.self,
        RabbitHoleThread.self,
        ReflectionPrompt.self,
    ]

    @MainActor
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(allModels)
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [config])
    }
}
