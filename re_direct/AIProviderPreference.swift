import Foundation

enum AIProviderPreference: String, Codable, CaseIterable, Sendable {
    case auto
    case openai
    case anthropic
    case ollama
    case mistral
}
