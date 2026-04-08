import Foundation

public enum RuleUpdateError: Error {
    case notModifiedWithoutStoredRules
    case missingModifiedBody
    case signatureMismatch
}

public struct RuleUpdateService {
    private let updater: RuleListUpdater
    private let compiler: RuleCompiler
    private let store: RuleStoring
    private let signer: RuleSigner
    private let now: () -> Date

    public init(
        updater: RuleListUpdater = RuleListUpdater(),
        compiler: RuleCompiler = RuleCompiler(),
        store: RuleStoring = RulesStore(),
        signer: RuleSigner = RuleSigner(),
        now: @escaping () -> Date = Date.init
    ) {
        self.updater = updater
        self.compiler = compiler
        self.store = store
        self.signer = signer
        self.now = now
    }

    public func updateRules(
        from sourceURL: URL,
        signaturePolicy: RuleSignaturePolicy = .none,
        compilerConfiguration: RuleCompilerConfiguration = .safariDefault
    ) async throws -> RuleUpdateResult {
        let sourceKey = sourceURL.absoluteString
        var metadata = store.loadSourceMetadata(for: sourceKey) ?? RuleSourceMetadata()

        let fetchResponse = try await updater.fetch(from: sourceURL, metadata: metadata)
        switch fetchResponse.status {
        case .notModified:
            let existingRules = try store.loadRules()
            guard !existingRules.isEmpty else {
                throw RuleUpdateError.notModifiedWithoutStoredRules
            }
            if let etag = fetchResponse.etag {
                metadata.etag = etag
            }
            if let lastModified = fetchResponse.lastModified {
                metadata.lastModified = lastModified
            }
            try store.writeSourceMetadata(metadata, for: sourceKey)
            return RuleUpdateResult(status: .notModified, appliedRuleCount: existingRules.count, report: nil)

        case .modified:
            guard let filterText = fetchResponse.filterText else {
                throw RuleUpdateError.missingModifiedBody
            }
            let normalizedFilterText = filterText.replacingOccurrences(of: "\r\n", with: "\n")
            let digest = signer.sha256Hex(of: normalizedFilterText)
            try await verifySignature(
                digest: digest,
                metadata: metadata,
                sourceURL: sourceURL,
                policy: signaturePolicy
            )

            let compilation = try compiler.compileResult(
                rawFilterText: normalizedFilterText,
                configuration: compilerConfiguration
            )
            let previousData = store.loadRulesJSONIfExists()
            try store.writeRules(compilation.rules)

            do {
                metadata.etag = fetchResponse.etag ?? metadata.etag
                metadata.lastModified = fetchResponse.lastModified ?? metadata.lastModified
                metadata.lastKnownSHA256 = digest
                metadata.lastSuccessfulUpdate = now()
                if case .pinToFirstSeen = signaturePolicy, metadata.pinnedSHA256 == nil {
                    metadata.pinnedSHA256 = digest
                }
                try store.writeSourceMetadata(metadata, for: sourceKey)
                return RuleUpdateResult(
                    status: .updated,
                    appliedRuleCount: compilation.rules.count,
                    report: compilation.report
                )
            } catch {
                try? store.restoreRulesFromBackup(previousData)
                throw error
            }
        }
    }

    private func verifySignature(
        digest: String,
        metadata: RuleSourceMetadata,
        sourceURL: URL,
        policy: RuleSignaturePolicy
    ) async throws {
        switch policy {
        case .none:
            return
        case .expectedSHA256(let expected):
            guard digest == expected.lowercased() else {
                throw RuleUpdateError.signatureMismatch
            }
        case .remoteSHA256File(let checksumURL):
            let remoteChecksum = try await updater.fetchRemoteSHA256(from: checksumURL)
            guard digest == remoteChecksum else {
                throw RuleUpdateError.signatureMismatch
            }
        case .pinToFirstSeen:
            if let pinned = metadata.pinnedSHA256 {
                guard digest == pinned.lowercased() else {
                    throw RuleUpdateError.signatureMismatch
                }
            } else if let sourceHost = sourceURL.host, sourceHost.isEmpty {
                throw RuleUpdateError.signatureMismatch
            }
        }
    }

}
