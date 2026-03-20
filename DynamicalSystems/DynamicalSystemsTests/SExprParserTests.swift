import Testing
@testable import DynamicalSystems

@Suite("SExprParser")
struct SExprParserTests {

  @Test func parseSingleAtom() throws {
    let result = try SExprParser.parse("hello")
    #expect(result == .atom("hello"))
  }

  @Test func parseInteger() throws {
    let result = try SExprParser.parse("42")
    #expect(result == .atom("42"))
  }

  @Test func parseSimpleList() throws {
    let result = try SExprParser.parse("(hello world)")
    #expect(result == .list([.atom("hello"), .atom("world")]))
  }

  @Test func parseNestedList() throws {
    let result = try SExprParser.parse("(a (b c) d)")
    #expect(result == .list([
      .atom("a"),
      .list([.atom("b"), .atom("c")]),
      .atom("d")
    ]))
  }

  @Test func parseBraces() throws {
    let result = try SExprParser.parse("{a b c}")
    #expect(result == .list([.atom("a"), .atom("b"), .atom("c")]))
  }

  @Test func parseQuotedString() throws {
    let result = try SExprParser.parse("(title \"Goblin Assault\")")
    #expect(result == .list([.atom("title"), .atom("\"Goblin Assault\"")]))
  }

  @Test func parseMultipleForms() throws {
    let results = try SExprParser.parseMultiple("(a b) (c d)")
    #expect(results == [
      .list([.atom("a"), .atom("b")]),
      .list([.atom("c"), .atom("d")])
    ])
  }

  @Test func unmatchedParenThrows() throws {
    #expect(throws: SExprParser.ParseError.unmatchedParen) {
      try SExprParser.parse("(a b")
    }
  }

  @Test func atomAccessors() throws {
    let expr = SExpr.atom("42")
    #expect(expr.atomValue == "42")
    #expect(expr.intValue == 42)
    #expect(expr.stringValue == nil)
    #expect(expr.children == nil)
  }

  @Test func stringAccessor() throws {
    let expr = SExpr.atom("\"Goblin Assault\"")
    #expect(expr.stringValue == "Goblin Assault")
    #expect(expr.atomValue == "\"Goblin Assault\"")
  }

  @Test func listAccessors() throws {
    let expr = SExpr.list([.atom("title"), .atom("Goblins")])
    #expect(expr.tag == "title")
    #expect(expr.children == [.atom("title"), .atom("Goblins")])
    #expect(expr.atomValue == nil)
  }

  @Test func parseComment() throws {
    let result = try SExprParser.parse("(a ;comment\nb)")
    #expect(result == .list([.atom("a"), .atom("b")]))
  }
}
