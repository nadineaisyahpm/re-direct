import Foundation

enum AIRequestValidationError: Error, Equatable, Sendable {
    case interestsEmpty
    case interestsTooMany
    case interestInvalid(String)
    case moodTooLong
    case timeOutOfRange
    case tooManyExcludeHashes
    case localeInvalid
}

enum AIRequestValidator {

    static let interestRegex = #"^[A-Za-z][A-Za-z \-]{0,39}$"#
    static let localeRegex = #"^[a-z]{2}(-[A-Z]{2})?$"#

    static let maxInterests = 8
    static let maxMoodLength = 32
    static let minTime = 5
    static let maxTime = 120
    static let maxExcludeHashes = 20

    static func validate(_ request: AIRecommendationRequest) -> AIRequestValidationError? {
        if request.interests.isEmpty { return .interestsEmpty }
        if request.interests.count > maxInterests { return .interestsTooMany }
        for interest in request.interests {
            if interest.range(of: interestRegex, options: .regularExpression) == nil {
                return .interestInvalid(interest)
            }
        }
        if let mood = request.mood, mood.count > maxMoodLength { return .moodTooLong }
        if request.timeAvailableMinutes < minTime || request.timeAvailableMinutes > maxTime {
            return .timeOutOfRange
        }
        if request.excludePromptHashes.count > maxExcludeHashes { return .tooManyExcludeHashes }
        if request.locale.range(of: localeRegex, options: .regularExpression) == nil {
            return .localeInvalid
        }
        return nil
    }
}
