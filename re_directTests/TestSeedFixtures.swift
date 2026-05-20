import Foundation
@testable import re_direct

struct InMemorySeedSource: CuriositySeedSource {
    let seed: CuriositySeedDTO
    func load() throws -> CuriositySeedDTO { seed }
}

enum TestSeedFixtures {

    static let minimalJSON = """
    {
      "seed_version": 1,
      "generated_at": "2026-01-01T00:00:00Z",
      "locale": "en-US",
      "topics": [
        {
          "slug": "bioluminescence",
          "title": "Bioluminescence",
          "summary": "Things that glow.",
          "cover_asset_name": "Cover_Bio",
          "accent_color_hex": "#1B4D4A",
          "prompts": [
            { "slug": "deep-sea-glow", "body": "Why blue?", "source": "seed", "tier": "free", "estimated_minutes": 10 },
            { "slug": "firefly", "body": "Flash patterns.", "source": "seed", "tier": "free", "estimated_minutes": 12 }
          ]
        }
      ],
      "trails": [
        {
          "slug": "bio-intro",
          "topic_slug": "bioluminescence",
          "title": "Walk",
          "summary": "Two prompts.",
          "steps": [
            { "step_order": 1, "prompt_slug": "deep-sea-glow", "estimated_minutes": 10 },
            { "step_order": 2, "prompt_slug": "firefly", "estimated_minutes": 12 }
          ]
        }
      ],
      "reminder_themes": [
        { "slug": "warm-paper", "display_name": "Warm Paper", "asset_name": "ReminderWarmPaper" }
      ],
      "redirect_methods": [
        { "slug": "read", "display_name": "Read", "summary": "Open a long article." }
      ]
    }
    """

    static let brokenTrailJSON = """
    {
      "seed_version": 1,
      "generated_at": "2026-01-01T00:00:00Z",
      "locale": "en-US",
      "topics": [
        {
          "slug": "bioluminescence",
          "title": "Bioluminescence",
          "summary": "Things that glow.",
          "cover_asset_name": "Cover_Bio",
          "accent_color_hex": "#1B4D4A",
          "prompts": [
            { "slug": "deep-sea-glow", "body": "Why blue?", "source": "seed", "tier": "free", "estimated_minutes": 10 }
          ]
        }
      ],
      "trails": [
        {
          "slug": "broken",
          "topic_slug": "bioluminescence",
          "title": "Broken",
          "summary": "Bad step ref.",
          "steps": [
            { "step_order": 1, "prompt_slug": "does-not-exist", "estimated_minutes": 5 }
          ]
        }
      ],
      "reminder_themes": [
        { "slug": "warm-paper", "display_name": "Warm Paper", "asset_name": "ReminderWarmPaper" }
      ],
      "redirect_methods": [
        { "slug": "read", "display_name": "Read", "summary": "Open a long article." }
      ]
    }
    """

    static func decode(_ json: String, seedVersion: Int? = nil) throws -> CuriositySeedDTO {
        var raw = json
        if let v = seedVersion {
            raw = raw.replacingOccurrences(of: "\"seed_version\": 1,", with: "\"seed_version\": \(v),")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CuriositySeedDTO.self, from: Data(raw.utf8))
    }

    static func minimalSource(seedVersion: Int = 1) -> InMemorySeedSource {
        InMemorySeedSource(seed: try! decode(minimalJSON, seedVersion: seedVersion))
    }

    static func brokenTrailSource() -> InMemorySeedSource {
        InMemorySeedSource(seed: try! decode(brokenTrailJSON))
    }
}
