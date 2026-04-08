import Foundation

public enum RuleListUpdaterError: Error {
    case missingBodyForModifiedResponse
    case invalidChecksumBody
}

public struct RuleListUpdater {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func fetchFilterText(from url: URL) async throws -> String {
        let response = try await fetch(from: url, metadata: nil)
        guard response.status == .modified, let filterText = response.filterText else {
            throw RuleListUpdaterError.missingBodyForModifiedResponse
        }
        return filterText
    }

    public func fetch(from url: URL, metadata: RuleSourceMetadata?) async throws -> RuleFetchResponse {
        var request = URLRequest(url: url)
        request.setValue("ChrisAdBlocker/0.2", forHTTPHeaderField: "User-Agent")
        if let etag = metadata?.etag, !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let lastModified = metadata?.lastModified, !lastModified.isEmpty {
            request.setValue(lastModified, forHTTPHeaderField: "If-Modified-Since")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 304 {
            return RuleFetchResponse(
                status: .notModified,
                filterText: nil,
                etag: http.value(forHTTPHeaderField: "ETag"),
                lastModified: http.value(forHTTPHeaderField: "Last-Modified")
            )
        }
        guard (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let body = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        return RuleFetchResponse(
            status: .modified,
            filterText: body,
            etag: http.value(forHTTPHeaderField: "ETag"),
            lastModified: http.value(forHTTPHeaderField: "Last-Modified")
        )
    }

    public func fetchRemoteSHA256(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("ChrisAdBlocker/0.2", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        guard let body = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        let token = body
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .first?
            .lowercased()

        guard let token, token.count == 64 else {
            throw RuleListUpdaterError.invalidChecksumBody
        }
        return token
    }
}
