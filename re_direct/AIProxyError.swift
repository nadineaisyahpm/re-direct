import Foundation

enum AIProxyError: Error, Equatable, Sendable {
    case invalidInput(message: String)
    case invalidToken
    case providerBlocked
    case rateLimited(retryAfterSeconds: Int?)
    case upstreamFailed
    case proxyUnavailable
    case upstreamTimeout
    case clientUpgradeRequired
    case decoding
    case network(message: String)
    case unknown(status: Int, message: String?)

    struct WireError: Decodable {
        struct Body: Decodable {
            let code: String
            let message: String
            let retryAfterSeconds: Int?

            enum CodingKeys: String, CodingKey {
                case code
                case message
                case retryAfterSeconds = "retry_after_seconds"
            }
        }
        let error: Body
    }

    static func from(status: Int, data: Data) -> AIProxyError {
        let wire = try? JSONDecoder().decode(WireError.self, from: data)
        switch wire?.error.code {
        case "invalid_input": return .invalidInput(message: wire?.error.message ?? "Invalid input.")
        case "invalid_token": return .invalidToken
        case "provider_blocked": return .providerBlocked
        case "rate_limited": return .rateLimited(retryAfterSeconds: wire?.error.retryAfterSeconds)
        case "upstream_failed": return .upstreamFailed
        case "proxy_unavailable": return .proxyUnavailable
        case "upstream_timeout": return .upstreamTimeout
        case "client_upgrade_required": return .clientUpgradeRequired
        default: return .unknown(status: status, message: wire?.error.message)
        }
    }

    var triggersSeededFallback: Bool {
        switch self {
        case .rateLimited, .upstreamFailed, .proxyUnavailable, .upstreamTimeout, .network, .unknown:
            return true
        case .invalidInput, .invalidToken, .providerBlocked, .clientUpgradeRequired, .decoding:
            return false
        }
    }
}
