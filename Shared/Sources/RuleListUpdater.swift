import Foundation

public struct RuleListUpdater {
    public init() {}

    public func fetchFilterText(from url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue("ChrisAdBlocker/0.1", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let body = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }

        return body
    }
}
