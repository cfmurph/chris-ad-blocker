import Foundation
import XCTest
@testable import AdBlockerCore

final class RuleCompilerCorpusTests: XCTestCase {
    func testCorpusParsesAdvancedOptionsAndExceptions() throws {
        let corpusURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("abp_corpus.txt")
        let text = try String(contentsOf: corpusURL, encoding: .utf8)

        let compiler = RuleCompiler()
        let result = try compiler.compileResult(rawFilterText: text)
        let rules = result.rules

        XCTAssertGreaterThan(rules.count, 5)
        XCTAssertTrue(rules.contains(where: { $0.action.type == "ignore-previous-rules" }))
        XCTAssertTrue(rules.contains(where: { $0.trigger.loadType == ["third-party"] }))
        XCTAssertTrue(rules.contains(where: { $0.trigger.resourceType?.contains("image") == true }))
        XCTAssertTrue(rules.contains(where: { $0.trigger.ifDomain?.contains("example.com") == true }))
        XCTAssertTrue(rules.contains(where: { $0.trigger.unlessDomain?.contains("shop.example.com") == true }))
    }

    func testResourceExclusionExpandsWhenNoIncludesPresent() throws {
        let compiler = RuleCompiler()
        let input = "||ads.example^$~image,~script"
        let rules = try compiler.compile(rawFilterText: input)
        XCTAssertEqual(rules.count, 1)
        let resourceTypes = Set(rules[0].trigger.resourceType ?? [])
        XCTAssertFalse(resourceTypes.contains("image"))
        XCTAssertFalse(resourceTypes.contains("script"))
        XCTAssertTrue(resourceTypes.contains("document"))
    }

    func testDedupeAndCanonicalizationCollapseEquivalentRules() throws {
        let compiler = RuleCompiler()
        let input = """
        ||ads.example.com^$IMAGE,domain=EXAMPLE.COM|~shop.example.com
        ||ads.example.com^$image,domain=example.com|~shop.example.com
        """
        let result = try compiler.compileResult(rawFilterText: input)
        XCTAssertEqual(result.rules.count, 1)
        XCTAssertEqual(result.report.deduplicatedRuleCount, 1)
    }

    func testLimitPolicyReservesExceptionSlots() throws {
        let compiler = RuleCompiler()
        let input = """
        ||a.example^
        ||b.example^
        @@||c.example^
        @@||d.example^
        """
        let config = RuleCompilerConfiguration(maxRuleCount: 2, reservedExceptionRuleSlots: 1)
        let result = try compiler.compileResult(rawFilterText: input, configuration: config)
        XCTAssertEqual(result.rules.count, 2)
        XCTAssertEqual(result.rules.filter { $0.action.type == "ignore-previous-rules" }.count, 1)
    }
}
