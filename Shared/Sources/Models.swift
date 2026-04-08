import Foundation

public struct SafariContentBlockerRule: Codable, Equatable {
    public let trigger: Trigger
    public let action: Action

    public init(trigger: Trigger, action: Action) {
        self.trigger = trigger
        self.action = action
    }

    public func canonicalized() -> SafariContentBlockerRule {
        SafariContentBlockerRule(
            trigger: trigger.canonicalized(),
            action: action.canonicalized()
        )
    }

    public var canonicalKey: String {
        let triggerKey = [
            trigger.urlFilter,
            trigger.urlFilterIsCaseSensitive == true ? "1" : "0",
            trigger.ifDomain?.joined(separator: ",") ?? "-",
            trigger.unlessDomain?.joined(separator: ",") ?? "-",
            trigger.resourceType?.joined(separator: ",") ?? "-",
            trigger.loadType?.joined(separator: ",") ?? "-"
        ].joined(separator: "|")
        let actionKey = [action.type, action.selector ?? "-"].joined(separator: "|")
        return "\(triggerKey)|\(actionKey)"
    }
}

public typealias ContentBlockerRule = SafariContentBlockerRule

public struct Trigger: Codable, Equatable {
    public let urlFilter: String
    public let urlFilterIsCaseSensitive: Bool?
    public let ifDomain: [String]?
    public let unlessDomain: [String]?
    public let resourceType: [String]?
    public let loadType: [String]?

    enum CodingKeys: String, CodingKey {
        case urlFilter = "url-filter"
        case urlFilterIsCaseSensitive = "url-filter-is-case-sensitive"
        case ifDomain = "if-domain"
        case unlessDomain = "unless-domain"
        case resourceType = "resource-type"
        case loadType = "load-type"
    }

    public init(
        urlFilter: String,
        urlFilterIsCaseSensitive: Bool? = nil,
        ifDomain: [String]? = nil,
        unlessDomain: [String]? = nil,
        resourceType: [String]? = nil,
        loadType: [String]? = nil
    ) {
        self.urlFilter = urlFilter
        self.urlFilterIsCaseSensitive = urlFilterIsCaseSensitive
        self.ifDomain = ifDomain
        self.unlessDomain = unlessDomain
        self.resourceType = resourceType
        self.loadType = loadType
    }

    public func canonicalized() -> Trigger {
        Trigger(
            urlFilter: urlFilter.trimmingCharacters(in: .whitespacesAndNewlines),
            urlFilterIsCaseSensitive: urlFilterIsCaseSensitive,
            ifDomain: normalizeDomainArray(ifDomain),
            unlessDomain: normalizeDomainArray(unlessDomain),
            resourceType: normalizeTokenArray(resourceType),
            loadType: normalizeTokenArray(loadType)
        )
    }

    private func normalizeDomainArray(_ values: [String]?) -> [String]? {
        guard let values else { return nil }
        let normalized = Array(Set(values.map { $0.lowercased() })).sorted()
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizeTokenArray(_ values: [String]?) -> [String]? {
        guard let values else { return nil }
        let normalized = Array(Set(values.map { $0.lowercased() })).sorted()
        return normalized.isEmpty ? nil : normalized
    }
}

public struct Action: Codable, Equatable {
    public let type: String
    public let selector: String?

    public init(type: String, selector: String? = nil) {
        self.type = type
        self.selector = selector
    }

    public func canonicalized() -> Action {
        let trimmedSelector = selector?.trimmingCharacters(in: .whitespacesAndNewlines)
        return Action(type: type.lowercased(), selector: trimmedSelector?.isEmpty == true ? nil : trimmedSelector)
    }
}

public enum AppConfiguration {
    public static let appGroupIdentifier = "group.com.example.chrisadblocker"
    public static let blockerListFileName = "blockerList.json"
    public static let sourceMetadataFileName = "rule-source-metadata.json"
    public static let contentBlockerIdentifier = "com.example.chrisadblocker.content-blocker"
    public static let defaultMaxRuleCount = 50_000
    public static let reservedExceptionRuleSlots = 4_000
}

public struct RuleCompilerConfiguration: Equatable {
    public let maxRuleCount: Int
    public let reservedExceptionRuleSlots: Int

    public init(
        maxRuleCount: Int = AppConfiguration.defaultMaxRuleCount,
        reservedExceptionRuleSlots: Int = AppConfiguration.reservedExceptionRuleSlots
    ) {
        self.maxRuleCount = max(1, maxRuleCount)
        self.reservedExceptionRuleSlots = max(0, reservedExceptionRuleSlots)
    }

    public static let safariDefault = RuleCompilerConfiguration()
}

public struct RuleCompilationReport: Equatable {
    public let inputLineCount: Int
    public let parsedRuleCount: Int
    public let unsupportedRuleCount: Int
    public let deduplicatedRuleCount: Int
    public let truncatedRuleCount: Int
    public let outputRuleCount: Int

    public init(
        inputLineCount: Int,
        parsedRuleCount: Int,
        unsupportedRuleCount: Int,
        deduplicatedRuleCount: Int,
        truncatedRuleCount: Int,
        outputRuleCount: Int
    ) {
        self.inputLineCount = inputLineCount
        self.parsedRuleCount = parsedRuleCount
        self.unsupportedRuleCount = unsupportedRuleCount
        self.deduplicatedRuleCount = deduplicatedRuleCount
        self.truncatedRuleCount = truncatedRuleCount
        self.outputRuleCount = outputRuleCount
    }
}

public struct RuleCompilationResult: Equatable {
    public let rules: [SafariContentBlockerRule]
    public let report: RuleCompilationReport

    public init(rules: [SafariContentBlockerRule], report: RuleCompilationReport) {
        self.rules = rules
        self.report = report
    }
}

public struct RuleSourceMetadata: Codable, Equatable {
    public var etag: String?
    public var lastModified: String?
    public var lastKnownSHA256: String?
    public var pinnedSHA256: String?
    public var lastSuccessfulUpdate: Date?

    public init(
        etag: String? = nil,
        lastModified: String? = nil,
        lastKnownSHA256: String? = nil,
        pinnedSHA256: String? = nil,
        lastSuccessfulUpdate: Date? = nil
    ) {
        self.etag = etag
        self.lastModified = lastModified
        self.lastKnownSHA256 = lastKnownSHA256
        self.pinnedSHA256 = pinnedSHA256
        self.lastSuccessfulUpdate = lastSuccessfulUpdate
    }
}

public struct RuleSourceMetadataIndex: Codable, Equatable {
    public var bySource: [String: RuleSourceMetadata]

    public init(bySource: [String: RuleSourceMetadata]) {
        self.bySource = bySource
    }
}

public enum RuleFetchStatus: Equatable {
    case modified
    case notModified
}

public struct RuleFetchResponse: Equatable {
    public let status: RuleFetchStatus
    public let filterText: String?
    public let etag: String?
    public let lastModified: String?

    public init(
        status: RuleFetchStatus,
        filterText: String?,
        etag: String?,
        lastModified: String?
    ) {
        self.status = status
        self.filterText = filterText
        self.etag = etag
        self.lastModified = lastModified
    }
}

public enum RuleSignaturePolicy: Equatable {
    case none
    case expectedSHA256(String)
    case remoteSHA256File(URL)
    case pinToFirstSeen
}

public enum RuleUpdateStatus: Equatable {
    case updated
    case notModified
}

public struct RuleUpdateResult: Equatable {
    public let status: RuleUpdateStatus
    public let appliedRuleCount: Int
    public let report: RuleCompilationReport?

    public init(status: RuleUpdateStatus, appliedRuleCount: Int, report: RuleCompilationReport?) {
        self.status = status
        self.appliedRuleCount = appliedRuleCount
        self.report = report
    }
}

extension JSONEncoder {
    static var safariRulesEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
        return encoder
    }
}
