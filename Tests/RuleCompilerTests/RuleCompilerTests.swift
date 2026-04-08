import XCTest
@testable import AdBlockerCore

final class RuleCompilerTests: XCTestCase {
    func testCompilesSimpleDomainRule() throws {
        let compiler = RuleCompiler()
        let input = """
        ! comment
        ||doubleclick.net^
        """

        let rules = try compiler.compile(rawFilterText: input)

        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].action.type, "block")
        XCTAssertEqual(rules[0].trigger.urlFilter, "^https?://([^/]+\\.)?doubleclick\\.net([^A-Za-z0-9_\\-.%]|$)")
        XCTAssertNil(rules[0].trigger.ifDomain)
    }

    func testCompilesExceptionRule() throws {
        let compiler = RuleCompiler()
        let input = """
        @@||allowed.example^$script,domain=example.com|~shop.example.com
        """

        let rules = try compiler.compile(rawFilterText: input)

        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].action.type, "ignore-previous-rules")
        XCTAssertEqual(rules[0].trigger.resourceType, ["script"])
        XCTAssertEqual(rules[0].trigger.ifDomain, ["example.com"])
        XCTAssertEqual(rules[0].trigger.unlessDomain, ["shop.example.com"])
    }

    func testCompileToJSONProducesDecodableRules() throws {
        let compiler = RuleCompiler()
        let input = """
        ||ads.example.com^
        tracker.example
        """

        let data = try compiler.compileToJSON(rawFilterText: input)
        let decoded = try JSONDecoder().decode([ContentBlockerRule].self, from: data)
        XCTAssertEqual(decoded.count, 2)
    }

    func testCompilesResourceExclusionsAndThirdPartyFlags() throws {
        let compiler = RuleCompiler()
        let input = "||ads.example^$~image,~script,third-party"
        let rules = try compiler.compile(rawFilterText: input)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].trigger.loadType, ["third-party"])
        let resourceTypes = Set(rules[0].trigger.resourceType ?? [])
        XCTAssertFalse(resourceTypes.contains("image"))
        XCTAssertFalse(resourceTypes.contains("script"))
        XCTAssertTrue(resourceTypes.contains("document"))
    }

    func testCompilesDomainScopeOptions() throws {
        let compiler = RuleCompiler()
        let input = "||tracker.example^$domain=example.com|foo.com|~bar.com"
        let rules = try compiler.compile(rawFilterText: input)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].trigger.ifDomain, ["example.com", "foo.com"])
        XCTAssertEqual(rules[0].trigger.unlessDomain, ["bar.com"])
    }

    func testCompilesAnchoredAndRegexPatterns() throws {
        let compiler = RuleCompiler()
        let input = """
        |https://banner.example.com/ads.js|
        /advert\\d+/
        """
        let rules = try compiler.compile(rawFilterText: input)
        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(rules[0].trigger.urlFilter, "^https://banner\\.example\\.com/ads\\.js$")
        XCTAssertEqual(rules[1].trigger.urlFilter, "advert\\d+")
    }

    func testCaseSensitivityOption() throws {
        let compiler = RuleCompiler()
        let input = "||ads.example^$match-case"
        let rules = try compiler.compile(rawFilterText: input)
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual(rules[0].trigger.urlFilterIsCaseSensitive, true)
    }

    func testLimitPolicyTruncatesDeterministically() throws {
        let compiler = RuleCompiler()
        let input = """
        ||a.example^
        ||b.example^
        ||c.example^
        @@||x.example^
        @@||y.example^
        """
        let config = RuleCompilerConfiguration(maxRuleCount: 3, reservedExceptionRuleSlots: 1)
        let result = try compiler.compileResult(rawFilterText: input, configuration: config)
        XCTAssertEqual(result.rules.count, 3)
        XCTAssertEqual(result.report.truncatedRuleCount, 2)
        XCTAssertEqual(result.rules.filter { $0.action.type == "ignore-previous-rules" }.count, 1)
    }
}
