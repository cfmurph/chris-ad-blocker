import Foundation

public enum RuleCompilerError: Error {
    case emptyInput
}

public struct RuleCompiler {
    public init() {}

    /// Converts a minimal subset of EasyList-style lines into Safari rules.
    /// Supported:
    /// - `||domain.example^` -> block with `if-domain`
    /// - `domain.example` -> broad url-filter contains
    /// Skips comments (`!`), metadata (`[`), cosmetics (`##` / `#@#`), and exceptions (`@@`).
    public func compile(rawFilterText: String) throws -> [SafariContentBlockerRule] {
        let lines = rawFilterText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }

        guard !lines.isEmpty else {
            throw RuleCompilerError.emptyInput
        }

        var rules: [SafariContentBlockerRule] = []
        for line in lines where !line.isEmpty {
            guard !line.hasPrefix("!"),
                  !line.hasPrefix("["),
                  !line.hasPrefix("@@"),
                  !line.contains("##"),
                  !line.contains("#@#"),
                  !line.hasPrefix("#") else {
                continue
            }

            if let domainRule = parseDomainRule(from: line) {
                rules.append(domainRule)
            } else if let containsRule = parseContainsRule(from: line) {
                rules.append(containsRule)
            }
        }

        return deduplicate(rules)
    }

    public func compileToJSON(rawFilterText: String) throws -> Data {
        let rules = try compile(rawFilterText: rawFilterText)
        return try JSONEncoder.safariRulesEncoder.encode(rules)
    }

    public func encodeRules(_ rules: [SafariContentBlockerRule]) throws -> Data {
        try JSONEncoder.safariRulesEncoder.encode(rules)
    }

    private func parseDomainRule(from line: String) -> SafariContentBlockerRule? {
        guard line.hasPrefix("||"), line.hasSuffix("^") else {
            return nil
        }

        let host = sanitizeHost(String(line.dropFirst(2).dropLast()))
        guard !host.isEmpty else { return nil }

        return SafariContentBlockerRule(
            trigger: Trigger(urlFilter: ".*", ifDomain: [host]),
            action: Action(type: "block")
        )
    }

    private func parseContainsRule(from line: String) -> SafariContentBlockerRule? {
        let token = line
            .replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: "^", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.count >= 3 else { return nil }

        let escaped = NSRegularExpression.escapedPattern(for: token)
        return SafariContentBlockerRule(
            trigger: Trigger(urlFilter: ".*\(escaped).*"),
            action: Action(type: "block")
        )
    }

    private func sanitizeHost(_ candidate: String) -> String {
        candidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "*.", with: "")
    }

    private func deduplicate(_ rules: [SafariContentBlockerRule]) -> [SafariContentBlockerRule] {
        var seen = Set<String>()
        var output: [SafariContentBlockerRule] = []
        output.reserveCapacity(rules.count)

        for rule in rules {
            let key = "\(rule.trigger.urlFilter)|\(rule.trigger.ifDomain?.joined(separator: ",") ?? "-")|\(rule.action.type)"
            if seen.insert(key).inserted {
                output.append(rule)
            }
        }
        return output
    }
}
