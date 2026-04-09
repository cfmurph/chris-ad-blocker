import Foundation

public protocol RuleStoring: AnyObject {
    func writeRules(_ rules: [SafariContentBlockerRule]) throws
    func writeRulesJSON(_ data: Data) throws
    func loadRules() throws -> [SafariContentBlockerRule]
    func loadRulesJSONIfExists() -> Data?
    func restoreRulesFromBackup(_ backup: Data?) throws
    func loadSourceMetadata(for sourceKey: String) -> RuleSourceMetadata?
    func writeSourceMetadata(_ metadata: RuleSourceMetadata, for sourceKey: String) throws
}
