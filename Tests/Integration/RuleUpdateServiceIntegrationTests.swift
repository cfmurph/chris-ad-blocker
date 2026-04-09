import Foundation
import XCTest
@testable import AdBlockerCore

final class RuleUpdateServiceIntegrationTests: XCTestCase {
    func testUpdateRulesPersistsMetadataAndRules() async throws {
        let sourceURL = URL(string: "https://filters.example/list.txt")!
        let payload = "||ads.example.com^$image,third-party"
        let etag = "\"abc123\""
        let lastModified = "Wed, 08 Apr 2026 12:00:00 GMT"

        let response = RuleFetchResponse(
            status: .modified,
            filterText: payload,
            etag: etag,
            lastModified: lastModified
        )

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuleUpdateServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = RulesStore(baseDirectoryOverride: tempDir)
        let updater = RuleListUpdater(session: urlSession(for: sourceURL, response: response))
        let service = RuleUpdateService(updater: updater, store: store)

        let result = try await service.updateRules(
            from: sourceURL,
            signaturePolicy: .none,
            compilerConfiguration: .safariDefault
        )

        XCTAssertEqual(result.status, .updated)
        XCTAssertEqual(result.appliedRuleCount, 1)
        XCTAssertNotNil(result.report)

        let metadata = store.loadSourceMetadata(for: sourceURL.absoluteString)
        XCTAssertEqual(metadata?.etag, etag)
        XCTAssertEqual(metadata?.lastModified, lastModified)
        XCTAssertNotNil(metadata?.lastKnownSHA256)
        XCTAssertNotNil(metadata?.lastSuccessfulUpdate)

        let persisted = try store.loadRules()
        XCTAssertEqual(persisted.count, 1)
    }

    func testNotModifiedUsesStoredRules() async throws {
        let sourceURL = URL(string: "https://filters.example/not-modified.txt")!
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuleUpdateServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = RulesStore(baseDirectoryOverride: tempDir)
        try store.writeRules([
            SafariContentBlockerRule(
                trigger: Trigger(urlFilter: ".*", ifDomain: ["ads.example"]),
                action: Action(type: "block")
            )
        ])

        let notModified = RuleFetchResponse(
            status: .notModified,
            filterText: nil,
            etag: "\"etag2\"",
            lastModified: "Wed, 08 Apr 2026 13:00:00 GMT"
        )
        let updater = RuleListUpdater(session: urlSession(for: sourceURL, response: notModified))
        let service = RuleUpdateService(updater: updater, store: store)

        let result = try await service.updateRules(from: sourceURL)
        XCTAssertEqual(result.status, .notModified)
        XCTAssertEqual(result.appliedRuleCount, 1)
    }

    func testRollbackOnMetadataWriteFailureRestoresPreviousRules() async throws {
        let sourceURL = URL(string: "https://filters.example/mismatch.txt")!
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("RuleUpdateServiceTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let store = FailingMetadataStore(baseDirectoryOverride: tempDir)
        let originalRule = SafariContentBlockerRule(
            trigger: Trigger(urlFilter: ".*", ifDomain: ["keep.example"]),
            action: Action(type: "block")
        )
        try store.writeRules([originalRule])

        let modified = RuleFetchResponse(
            status: .modified,
            filterText: "||new.example^",
            etag: nil,
            lastModified: nil
        )
        let updater = RuleListUpdater(session: urlSession(for: sourceURL, response: modified))
        let service = RuleUpdateService(updater: updater, store: store)

        do {
            _ = try await service.updateRules(from: sourceURL)
            XCTFail("Expected metadata write failure")
        } catch FailingMetadataStoreError.intentionalFailure {
            // expected
        }

        let persisted = try store.loadRules()
        XCTAssertEqual(persisted, [originalRule])
    }

    // MARK: - Helpers

    private func urlSession(for expectedURL: URL, response: RuleFetchResponse) -> URLSession {
        URLProtocolStub.responseProvider = { request in
            guard request.url == expectedURL else {
                throw URLError(.badURL)
            }
            switch response.status {
            case .notModified:
                let http = HTTPURLResponse(
                    url: expectedURL,
                    statusCode: 304,
                    httpVersion: nil,
                    headerFields: headers(for: response)
                )!
                return (http, Data())
            case .modified:
                let http = HTTPURLResponse(
                    url: expectedURL,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: headers(for: response)
                )!
                return (http, Data((response.filterText ?? "").utf8))
            }
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: config)
    }

    private func headers(for response: RuleFetchResponse) -> [String: String] {
        var headers: [String: String] = [:]
        if let etag = response.etag {
            headers["ETag"] = etag
        }
        if let lastModified = response.lastModified {
            headers["Last-Modified"] = lastModified
        }
        return headers
    }
}

private enum FailingMetadataStoreError: Error {
    case intentionalFailure
}

private final class FailingMetadataStore: RuleStoring {
    private let backing: RulesStore

    init(baseDirectoryOverride: URL) {
        self.backing = RulesStore(baseDirectoryOverride: baseDirectoryOverride)
    }

    func writeRules(_ rules: [SafariContentBlockerRule]) throws {
        try backing.writeRules(rules)
    }

    func writeRulesJSON(_ data: Data) throws {
        try backing.writeRulesJSON(data)
    }

    func loadRules() throws -> [SafariContentBlockerRule] {
        try backing.loadRules()
    }

    func loadRulesJSONIfExists() -> Data? {
        backing.loadRulesJSONIfExists()
    }

    func restoreRulesFromBackup(_ backup: Data?) throws {
        try backing.restoreRulesFromBackup(backup)
    }

    func loadSourceMetadata(for sourceKey: String) -> RuleSourceMetadata? {
        backing.loadSourceMetadata(for: sourceKey)
    }

    func writeSourceMetadata(_ metadata: RuleSourceMetadata, for sourceKey: String) throws {
        throw FailingMetadataStoreError.intentionalFailure
    }
}

private final class URLProtocolStub: URLProtocol {
    static var responseProvider: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let provider = URLProtocolStub.responseProvider else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try provider(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
