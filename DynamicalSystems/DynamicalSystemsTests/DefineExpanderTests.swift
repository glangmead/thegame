import Testing
@testable import DynamicalSystems

@Suite("DefineExpander")
struct DefineExpanderTests {
  @Test func parameterlessDefine() throws {
    let defines = try SExprParser.parseMultiple("""
    (define "drawsFromDayDeck" (< timePosition 6))
    """)
    let expander = try DefineExpander(defines)
    let expr = try SExprParser.parse("(drawsFromDayDeck)")
    let expanded = try expander.expand(expr)
    let expected = try SExprParser.parse("(< timePosition 6)")
    #expect(expanded == expected)
  }

  @Test func parameterizedDefine() throws {
    let defines = try SExprParser.parseMultiple("""
    (define "AdvanceArmy" (slot)
      (setEntry armyPosition $slot (- (lookup armyPosition $slot) 1)))
    """)
    let expander = try DefineExpander(defines)
    let expr = try SExprParser.parse("(AdvanceArmy east)")
    let expanded = try expander.expand(expr)
    let expected = try SExprParser.parse(
      "(setEntry armyPosition east (- (lookup armyPosition east) 1))"
    )
    #expect(expanded == expected)
  }

  @Test func cyclicDefineThrows() throws {
    let defines = try SExprParser.parseMultiple("""
    (define "A" () (B))
    (define "B" () (A))
    """)
    #expect(throws: DSLError.self) {
      try DefineExpander(defines)
    }
  }
}
