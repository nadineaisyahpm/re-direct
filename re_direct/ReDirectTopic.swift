import SwiftUI

// ─────────────────────────────────────────────
// MARK: - Topic Platform Stat
// ─────────────────────────────────────────────

struct TopicPlatformStat: Identifiable, Hashable {
    let id: Int
    let platform: String
    let percentage: Double
    let timeSpent: String
}

// ─────────────────────────────────────────────
// MARK: - Re:Direct Topic
// ─────────────────────────────────────────────

struct ReDirectTopic: Identifiable, Hashable {
    let id: Int
    let title: String
    let subtitle: String
    let imageURL: String
    let colorHex: String
    let barHeight: CGFloat
    let barColorHex: String
    let articleCount: Int
    let videoCount: Int
    let totalTime: String
    let platformStats: [TopicPlatformStat]
}

// ─────────────────────────────────────────────
// MARK: - Re:Direct Topic Data
// ─────────────────────────────────────────────

enum ReDirectTopicData {

    static let topFive: [ReDirectTopic] = [

        ReDirectTopic(
            id: 0,
            title: "What did NASA really found in the deep sea?",
            subtitle: "Find out why scientists stopped diving deeper to the trench...",
            imageURL: "https://picsum.photos/seed/ocean/400/500",
            colorHex: "#1B4D4A",
            barHeight: 160,
            barColorHex: "#787878",
            articleCount: 12,
            videoCount: 4,
            totalTime: "3h 20m",
            platformStats: [
                TopicPlatformStat(id: 0, platform: "YouTube",   percentage: 0.55, timeSpent: "1h 50m"),
                TopicPlatformStat(id: 1, platform: "Instagram", percentage: 0.25, timeSpent: "50m"),
                TopicPlatformStat(id: 2, platform: "TikTok",    percentage: 0.20, timeSpent: "40m")
            ]
        ),

        ReDirectTopic(
            id: 1,
            title: "The forgotten cities under the Sahara",
            subtitle: "Ancient civilizations buried beneath the sand for centuries...",
            imageURL: "https://picsum.photos/seed/desert/400/500",
            colorHex: "#2C1810",
            barHeight: 130,
            barColorHex: "#C2B8A8",
            articleCount: 8,
            videoCount: 3,
            totalTime: "2h 10m",
            platformStats: [
                TopicPlatformStat(id: 0, platform: "YouTube",   percentage: 0.60, timeSpent: "1h 18m"),
                TopicPlatformStat(id: 1, platform: "TikTok",    percentage: 0.40, timeSpent: "52m")
            ]
        ),

        ReDirectTopic(
            id: 2,
            title: "Why do we dream in other people's voices?",
            subtitle: "Scientists still can't explain this strange phenomenon...",
            imageURL: "https://picsum.photos/seed/dream/400/500",
            colorHex: "#2C2F3A",
            barHeight: 104,
            barColorHex: "#A89880",
            articleCount: 6,
            videoCount: 5,
            totalTime: "1h 45m",
            platformStats: [
                TopicPlatformStat(id: 0, platform: "YouTube",   percentage: 0.45, timeSpent: "47m"),
                TopicPlatformStat(id: 1, platform: "Instagram", percentage: 0.35, timeSpent: "37m"),
                TopicPlatformStat(id: 2, platform: "TikTok",    percentage: 0.20, timeSpent: "21m")
            ]
        ),

        ReDirectTopic(
            id: 3,
            title: "The science of déjà vu — why your brain fakes memories",
            subtitle: "Researchers finally have a theory for this eerie sensation...",
            imageURL: "https://picsum.photos/seed/memory/400/500",
            colorHex: "#1A1A2E",
            barHeight: 82,
            barColorHex: "#B8A0AC",
            articleCount: 5,
            videoCount: 2,
            totalTime: "1h 20m",
            platformStats: [
                TopicPlatformStat(id: 0, platform: "YouTube",   percentage: 0.70, timeSpent: "56m"),
                TopicPlatformStat(id: 1, platform: "TikTok",    percentage: 0.30, timeSpent: "24m")
            ]
        ),

        ReDirectTopic(
            id: 4,
            title: "Japan's evaporating people — the Johatsu phenomenon",
            subtitle: "Thousands vanish every year completely by choice...",
            imageURL: "https://picsum.photos/seed/japan/400/500",
            colorHex: "#1C1C1C",
            barHeight: 52,
            barColorHex: "#E4E0DC",
            articleCount: 3,
            videoCount: 1,
            totalTime: "48m",
            platformStats: [
                TopicPlatformStat(id: 0, platform: "YouTube",   percentage: 0.80, timeSpent: "38m"),
                TopicPlatformStat(id: 1, platform: "Instagram", percentage: 0.20, timeSpent: "10m")
            ]
        )
    ]
}
