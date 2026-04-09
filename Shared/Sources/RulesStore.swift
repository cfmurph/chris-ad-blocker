import Foundation

public final class RulesStore {
    private let fileManager: FileManager
    private let groupIdentifier: String
    private let fallbackDirectoryName = "ChrisAdBlocker"

    public init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String = AppConfiguration.appGroupIdentifier
    ) {
        self.fileManager = fileManager
        self.groupIdentifier = appGroupIdentifier
    }

    public func writeRules(_ rules: [SafariContentBlockerRule]) throws {
        let data = try RuleCompiler().encodeRules(rules)
        try data.write(to: blockerListURL, options: .atomic)
    }

    public func writeRulesJSON(_ data: Data) throws {
        try data.write(to: blockerListURL, options: .atomic)
    }

    public func loadRules() throws -> [SafariContentBlockerRule] {
        let data = try Data(contentsOf: blockerListURL)
        return try JSONDecoder().decode([SafariContentBlockerRule].self, from: data)
    }

    public var blockerListURL: URL {
        if let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) {
            return containerURL.appendingPathComponent(AppConfiguration.blockerListFileName)
        }

        // Allows local unit tests / non-sandbox execution in starter scaffold.
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let fallbackDir = appSupport.appendingPathComponent(fallbackDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
        return fallbackDir.appendingPathComponent(AppConfiguration.blockerListFileName)
    }

    public func ensureSeedRulesFromBundleIfNeeded(bundle: Bundle = .main) {
        guard !fileManager.fileExists(atPath: blockerListURL.path),
              let bundledURL = bundle.url(forResource: "blockerList", withExtension: "json"),
              let data = try? Data(contentsOf: bundledURL) else {
            return
        }

        try? writeRulesJSON(data)
    }
}
