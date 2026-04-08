import Foundation
import SafariServices
import AdBlockerCore

@MainActor
final class ContentBlockerViewModel: ObservableObject {
    enum State: String {
        case idle = "Idle"
        case updating = "Updating rules..."
        case success = "Rules updated."
        case failure = "Update failed."
    }

    @Published private(set) var status: State = .idle
    @Published private(set) var details: String = "No updates run yet."
    @Published var sourceURLString: String = "https://easylist.to/easylist/easylist.txt"

    private let ruleStore = RulesStore()
    private let updater = RuleListUpdater()
    private let compiler = RuleCompiler()
    private let contentBlockerIdentifier = AppConfiguration.contentBlockerIdentifier

    var statusText: String {
        "[\(status.rawValue)] \(details)"
    }

    func refreshRules() async {
        status = .updating
        details = "Downloading and compiling filter rules..."

        guard let url = URL(string: sourceURLString) else {
            status = .failure
            details = "Invalid source URL."
            return
        }

        do {
            let source = try await updater.fetchFilterText(from: url)
            let rules = try compiler.compile(rawFilterText: source)
            try ruleStore.writeRules(rules)
            try await reloadContentBlocker()
            status = .success
            details = "Generated \(rules.count) Safari content blocker rules."
        } catch {
            status = .failure
            details = error.localizedDescription
        }
    }

    func useBundledRules() async {
        status = .updating
        details = "Compiling bundled sample filters..."

        guard let sampleURL = Bundle.main.url(forResource: "sample_filters", withExtension: "txt") else {
            status = .failure
            details = "Bundled sample_filters.txt was not found."
            return
        }

        do {
            let source = try String(contentsOf: sampleURL, encoding: .utf8)
            let rules = try compiler.compile(rawFilterText: source)
            try ruleStore.writeRules(rules)
            try await reloadContentBlocker()
            status = .success
            details = "Loaded bundled sample and generated \(rules.count) Safari rules."
        } catch {
            status = .failure
            details = error.localizedDescription
        }
    }

    private func reloadContentBlocker() async throws {
        try await withCheckedThrowingContinuation { continuation in
            SFContentBlockerManager.reloadContentBlocker(withIdentifier: contentBlockerIdentifier) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}
