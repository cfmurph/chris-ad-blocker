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
        XCTAssertEqual(rules[0].trigger.urlFilter, ".*")
        XCTAssertEqual(rules[0].trigger.ifDomain, ["doubleclick.net"])
    }

    func testSkipsUnsupportedSyntax() throws {
        let compiler = RuleCompiler()
        let input = """
        @@||allowed.example^
        """

        let rules = try compiler.compile(rawFilterText: input)

        XCTAssertEqual(rules.count, 0)
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
}
