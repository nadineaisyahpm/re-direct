import Testing
import Foundation
@testable import re_direct

@Suite("AIEnvironment")
struct AIEnvironmentTests {

    @Test func exposesDevWorkerURL() {
        // The single source of truth — nowhere else in iOS source should
        // own this string (the pre-push grep enforces this externally).
        #expect(
            AIEnvironment.dailyDirectProxyURL.absoluteString
            == "https://re-direct-ai-proxy-dev.nadineaisyah170806.workers.dev"
        )
    }

    @Test func dailyDirectConfigUsesTheDevURL() {
        let config = AIEnvironment.dailyDirect
        #expect(config.baseURL == AIEnvironment.dailyDirectProxyURL)
    }

    @Test func dailyDirectConfigUsesDefaultTimeout() {
        // 20s default from AIProxyConfig — confirm we're not silently
        // overriding to something tighter / looser.
        #expect(AIEnvironment.dailyDirect.timeoutSeconds == 20)
    }

    @Test func trailConfigUsesLongerTimeout() {
        // Trail proxy ceiling is 28s (proxy fix 4803f16); iOS must allow
        // headroom beyond that. Daily Direct keeps its 20s default.
        #expect(AIEnvironment.trail.timeoutSeconds == 35)
        #expect(AIEnvironment.dailyDirect.timeoutSeconds == 20)
    }

    @Test func dailyDirectURLHostIsCloudflareWorkers() {
        // The hostname must be the Cloudflare Worker subdomain —
        // never a vendor (DeepSeek, OpenRouter, OpenAI, Anthropic) direct
        // endpoint. The iOS app calls only the proxy.
        let host = AIEnvironment.dailyDirectProxyURL.host ?? ""
        #expect(host.hasSuffix(".workers.dev"))
        for vendorHost in ["api.deepseek.com", "openrouter.ai", "api.openai.com", "api.anthropic.com"] {
            #expect(!host.contains(vendorHost))
        }
    }
}
