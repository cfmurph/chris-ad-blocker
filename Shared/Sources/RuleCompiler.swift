import Foundation

public enum RuleCompilerError: Error {
    case emptyInput
}

public struct RuleCompiler {
    public init() {}

    public func compile(
        rawFilterText: String,
        configuration: RuleCompilerConfiguration = .safariDefault
    ) throws -> [SafariContentBlockerRule] {
        try compileResult(rawFilterText: rawFilterText, configuration: configuration).rules
    }

    public func compileToJSON(
        rawFilterText: String,
        configuration: RuleCompilerConfiguration = .safariDefault
    ) throws -> Data {
        let rules = try compile(rawFilterText: rawFilterText, configuration: configuration)
        return try JSONEncoder.safariRulesEncoder.encode(rules)
    }

    public func encodeRules(_ rules: [SafariContentBlockerRule]) throws -> Data {
        try JSONEncoder.safariRulesEncoder.encode(rules)
    }

    public func compileResult(
        rawFilterText: String,
        configuration: RuleCompilerConfiguration = .safariDefault
    ) throws -> RuleCompilationResult {
        let rawLines = rawFilterText.split(whereSeparator: \.isNewline).map(String.init)
        if rawLines.isEmpty {
            throw RuleCompilerError.emptyInput
        }

        var parsedRules: [SafariContentBlockerRule] = []
        var unsupportedRuleCount = 0
        var sourceRuleCount = 0

        for rawLine in rawLines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || isCommentOrMetadataLine(line) {
                continue
            }
            sourceRuleCount += 1

            guard let entry = parseABPEntry(from: line),
                  let trigger = buildTrigger(for: entry.pattern, options: entry.options) else {
                unsupportedRuleCount += 1
                continue
            }

            let actionType = entry.isException ? "ignore-previous-rules" : "block"
            parsedRules.append(SafariContentBlockerRule(trigger: trigger, action: Action(type: actionType)))
        }

        let canonicalRules = parsedRules.map { $0.canonicalized() }
        let deduplicated = deduplicate(canonicalRules)
        let limited = applySafariLimitPolicy(to: deduplicated, configuration: configuration)

        let report = RuleCompilationReport(
            inputLineCount: sourceRuleCount,
            parsedRuleCount: parsedRules.count,
            unsupportedRuleCount: unsupportedRuleCount,
            deduplicatedRuleCount: parsedRules.count - deduplicated.count,
            truncatedRuleCount: deduplicated.count - limited.count,
            outputRuleCount: limited.count
        )

        return RuleCompilationResult(rules: limited, report: report)
    }

    private func isCommentOrMetadataLine(_ line: String) -> Bool {
        line.hasPrefix("!") ||
        line.hasPrefix("[") ||
        line.contains("##") ||
        line.contains("#@#") ||
        line.hasPrefix("#")
    }

    private func parseABPEntry(from line: String) -> ABPEntry? {
        let isException = line.hasPrefix("@@")
        let working = isException ? String(line.dropFirst(2)) : line

        let split = working.split(separator: "$", maxSplits: 1, omittingEmptySubsequences: false)
        let pattern = String(split[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        if pattern.isEmpty {
            return nil
        }

        let optionString = split.count > 1 ? String(split[1]) : nil
        let options = parseOptions(optionString)
        return ABPEntry(isException: isException, pattern: pattern, options: options)
    }

    private func parseOptions(_ options: String?) -> RuleOptions {
        guard let options, !options.isEmpty else {
            return RuleOptions()
        }

        let knownResourceMap: [String: String] = [
            "script": "script",
            "image": "image",
            "stylesheet": "style-sheet",
            "font": "font",
            "media": "media",
            "popup": "popup",
            "xmlhttprequest": "raw",
            "subdocument": "document",
            "ping": "raw",
            "svg": "svg-document"
        ]
        let allResourceTypes = Set(knownResourceMap.values)

        var includeResources = Set<String>()
        var excludeResources = Set<String>()
        var includeDomains = Set<String>()
        var excludeDomains = Set<String>()
        var loadType: [String]?
        var caseSensitive = false

        for rawToken in options.split(separator: ",").map(String.init) {
            let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if token.isEmpty {
                continue
            }

            if token == "match-case" {
                caseSensitive = true
                continue
            }

            if token == "third-party" {
                loadType = ["third-party"]
                continue
            }
            if token == "~third-party" {
                loadType = ["first-party"]
                continue
            }

            if token.hasPrefix("domain=") {
                let domains = String(token.dropFirst("domain=".count))
                parseDomainScope(
                    value: domains,
                    includeDomains: &includeDomains,
                    excludeDomains: &excludeDomains
                )
                continue
            }

            if token.hasPrefix("~"), let mapped = knownResourceMap[String(token.dropFirst())] {
                excludeResources.insert(mapped)
                continue
            }
            if let mapped = knownResourceMap[token] {
                includeResources.insert(mapped)
                continue
            }
        }

        let resolvedResources: Set<String>
        if includeResources.isEmpty && !excludeResources.isEmpty {
            resolvedResources = allResourceTypes.subtracting(excludeResources)
        } else {
            resolvedResources = includeResources.subtracting(excludeResources)
        }

        return RuleOptions(
            ifDomain: includeDomains.isEmpty ? nil : includeDomains.sorted(),
            unlessDomain: excludeDomains.isEmpty ? nil : excludeDomains.sorted(),
            resourceType: resolvedResources.isEmpty ? nil : resolvedResources.sorted(),
            loadType: loadType,
            urlFilterIsCaseSensitive: caseSensitive ? true : nil
        )
    }

    private func parseDomainScope(
        value: String,
        includeDomains: inout Set<String>,
        excludeDomains: inout Set<String>
    ) {
        for candidate in value.split(separator: "|").map(String.init) {
            var normalized = candidate.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized.isEmpty {
                continue
            }

            let isExclude = normalized.hasPrefix("~")
            if isExclude {
                normalized.removeFirst()
            }
            normalized = sanitizeDomain(normalized)
            if normalized.isEmpty {
                continue
            }
            if isExclude {
                excludeDomains.insert(normalized)
            } else {
                includeDomains.insert(normalized)
            }
        }
    }

    private func buildTrigger(for pattern: String, options: RuleOptions) -> Trigger? {
        guard let regex = translatePatternToRegex(pattern) else {
            return nil
        }

        return Trigger(
            urlFilter: regex,
            urlFilterIsCaseSensitive: options.urlFilterIsCaseSensitive,
            ifDomain: options.ifDomain,
            unlessDomain: options.unlessDomain,
            resourceType: options.resourceType,
            loadType: options.loadType
        )
    }

    private func translatePatternToRegex(_ pattern: String) -> String? {
        var working = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if working.isEmpty {
            return nil
        }

        if working.hasPrefix("/") && working.hasSuffix("/") && working.count > 1 {
            let rawRegex = String(working.dropFirst().dropLast())
            return rawRegex.isEmpty ? nil : rawRegex
        }

        var prefix = ""
        var suffix = ""
        if working.hasPrefix("||") {
            prefix = #"^https?://([^/]+\.)?"#
            working.removeFirst(2)
        } else if working.hasPrefix("|") {
            prefix = "^"
            working.removeFirst()
        }
        if working.hasSuffix("|") {
            suffix = "$"
            working.removeLast()
        }

        var output = ""
        output.reserveCapacity(working.count * 2)

        for character in working {
            switch character {
            case "*":
                output.append(".*")
            case "^":
                output.append(#"([^A-Za-z0-9_\-.%]|$)"#)
            default:
                output.append(NSRegularExpression.escapedPattern(for: String(character)))
            }
        }

        if output.isEmpty {
            output = ".*"
        }
        return "\(prefix)\(output)\(suffix)"
    }

    private func sanitizeDomain(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "*.", with: "")
    }

    private func deduplicate(_ rules: [SafariContentBlockerRule]) -> [SafariContentBlockerRule] {
        var seen = Set<String>()
        var output: [SafariContentBlockerRule] = []
        output.reserveCapacity(rules.count)

        for rule in rules {
            if seen.insert(rule.canonicalKey).inserted {
                output.append(rule)
            }
        }
        return output
    }

    private func applySafariLimitPolicy(
        to rules: [SafariContentBlockerRule],
        configuration: RuleCompilerConfiguration
    ) -> [SafariContentBlockerRule] {
        guard rules.count > configuration.maxRuleCount else {
            return rules
        }

        let exceptionRules = rules.filter { $0.action.type == "ignore-previous-rules" }
        let blockRules = rules.filter { $0.action.type != "ignore-previous-rules" }

        let reservedExceptionBudget = min(
            exceptionRules.count,
            configuration.reservedExceptionRuleSlots,
            configuration.maxRuleCount
        )
        var selectedExceptions = Array(exceptionRules.prefix(reservedExceptionBudget))

        let initialBlockBudget = max(0, configuration.maxRuleCount - selectedExceptions.count)
        var selectedBlocks = Array(blockRules.prefix(initialBlockBudget))

        // If there is still capacity, prioritize additional exceptions first.
        var remaining = configuration.maxRuleCount - selectedBlocks.count - selectedExceptions.count
        if remaining > 0 {
            let extraExceptions = exceptionRules.dropFirst(selectedExceptions.count)
            let additionalExceptionCount = min(remaining, extraExceptions.count)
            selectedExceptions += extraExceptions.prefix(additionalExceptionCount)
            remaining -= additionalExceptionCount
        }
        if remaining > 0 {
            let extraBlocks = blockRules.dropFirst(selectedBlocks.count)
            selectedBlocks += extraBlocks.prefix(remaining)
        }

        return selectedBlocks + selectedExceptions
    }
}

private struct ABPEntry {
    let isException: Bool
    let pattern: String
    let options: RuleOptions
}

private struct RuleOptions {
    let ifDomain: [String]?
    let unlessDomain: [String]?
    let resourceType: [String]?
    let loadType: [String]?
    let urlFilterIsCaseSensitive: Bool?

    init(
        ifDomain: [String]? = nil,
        unlessDomain: [String]? = nil,
        resourceType: [String]? = nil,
        loadType: [String]? = nil,
        urlFilterIsCaseSensitive: Bool? = nil
    ) {
        self.ifDomain = ifDomain
        self.unlessDomain = unlessDomain
        self.resourceType = resourceType
        self.loadType = loadType
        self.urlFilterIsCaseSensitive = urlFilterIsCaseSensitive
    }
}
