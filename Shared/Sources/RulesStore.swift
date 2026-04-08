import Foundation

public enum RulesStoreError: Error {
    case metadataCorrupted
}

public final class RulesStore: RuleStoring {
    private let fileManager: FileManager
    private let groupIdentifier: String
    private let fallbackDirectoryName = "ChrisAdBlocker"
    private let baseDirectoryOverride: URL?

    public init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String = AppConfiguration.appGroupIdentifier,
        baseDirectoryOverride: URL? = nil
    ) {
        self.fileManager = fileManager
        self.groupIdentifier = appGroupIdentifier
        self.baseDirectoryOverride = baseDirectoryOverride
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
        if let baseDirectoryOverride {
            try? fileManager.createDirectory(at: baseDirectoryOverride, withIntermediateDirectories: true)
            return baseDirectoryOverride.appendingPathComponent(AppConfiguration.blockerListFileName)
        }

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

    public func loadRulesJSONIfExists() -> Data? {
        guard fileManager.fileExists(atPath: blockerListURL.path) else {
            return nil
        }
        return try? Data(contentsOf: blockerListURL)
    }

    public func restoreRulesFromBackup(_ backup: Data?) throws {
        if let backup {
            try writeRulesJSON(backup)
        } else if fileManager.fileExists(atPath: blockerListURL.path) {
            try fileManager.removeItem(at: blockerListURL)
        }
    }

    public func loadSourceMetadata(for sourceKey: String) -> RuleSourceMetadata? {
        guard let index = try? readMetadataIndex() else {
            return nil
        }
        return index.bySource[sourceKey]
    }

    public func writeSourceMetadata(_ metadata: RuleSourceMetadata, for sourceKey: String) throws {
        var index = try readMetadataIndex()
        index.bySource[sourceKey] = metadata
        try writeMetadataIndex(index)
    }

    private var metadataURL: URL {
        blockerListURL
            .deletingLastPathComponent()
            .appendingPathComponent(AppConfiguration.sourceMetadataFileName)
    }

    private func readMetadataIndex() throws -> RuleSourceMetadataIndex {
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            return RuleSourceMetadataIndex(bySource: [:])
        }
        let data = try Data(contentsOf: metadataURL)
        do {
            return try JSONDecoder().decode(RuleSourceMetadataIndex.self, from: data)
        } catch {
            throw RulesStoreError.metadataCorrupted
        }
    }

    private func writeMetadataIndex(_ index: RuleSourceMetadataIndex) throws {
        let data = try JSONEncoder.safariRulesEncoder.encode(index)
        try data.write(to: metadataURL, options: .atomic)
    }
}
