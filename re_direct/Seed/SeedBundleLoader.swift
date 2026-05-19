import Foundation

enum SeedBundleError: Error, Equatable, Sendable {
    case resourceMissing(name: String)
    case decoding(message: String)
}

struct SeedBundleLoader: Sendable {
    let bundle: Bundle
    let resourceName: String
    let resourceExtension: String

    init(
        bundle: Bundle = .main,
        resourceName: String = "curiosity_seed_v1",
        resourceExtension: String = "json"
    ) {
        self.bundle = bundle
        self.resourceName = resourceName
        self.resourceExtension = resourceExtension
    }

    func load() throws -> CuriositySeedDTO {
        guard let url = bundle.url(forResource: resourceName, withExtension: resourceExtension) else {
            throw SeedBundleError.resourceMissing(name: "\(resourceName).\(resourceExtension)")
        }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(CuriositySeedDTO.self, from: data)
        } catch {
            throw SeedBundleError.decoding(message: String(describing: error))
        }
    }
}
