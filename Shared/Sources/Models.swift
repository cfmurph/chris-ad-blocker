import Foundation

public struct SafariContentBlockerRule: Codable, Equatable {
    public let trigger: Trigger
    public let action: Action

    public init(trigger: Trigger, action: Action) {
        self.trigger = trigger
        self.action = action
    }
}

public typealias ContentBlockerRule = SafariContentBlockerRule

public struct Trigger: Codable, Equatable {
    public let urlFilter: String
    public let ifDomain: [String]?
    public let unlessDomain: [String]?
    public let resourceType: [String]?
    public let loadType: [String]?

    enum CodingKeys: String, CodingKey {
        case urlFilter = "url-filter"
        case ifDomain = "if-domain"
        case unlessDomain = "unless-domain"
        case resourceType = "resource-type"
        case loadType = "load-type"
    }

    public init(
        urlFilter: String,
        ifDomain: [String]? = nil,
        unlessDomain: [String]? = nil,
        resourceType: [String]? = nil,
        loadType: [String]? = nil
    ) {
        self.urlFilter = urlFilter
        self.ifDomain = ifDomain
        self.unlessDomain = unlessDomain
        self.resourceType = resourceType
        self.loadType = loadType
    }
}

public struct Action: Codable, Equatable {
    public let type: String
    public let selector: String?

    public init(type: String, selector: String? = nil) {
        self.type = type
        self.selector = selector
    }
}

public enum AppConfiguration {
    public static let appGroupIdentifier = "group.com.example.chrisadblocker"
    public static let blockerListFileName = "blockerList.json"
    public static let contentBlockerIdentifier = "com.example.chrisadblocker.content-blocker"
}

extension JSONEncoder {
    static var safariRulesEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        return encoder
    }
}
