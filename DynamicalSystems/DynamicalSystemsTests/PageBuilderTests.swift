import Testing
@testable import DynamicalSystems

@Suite("PageBuilder")
struct PageBuilderTests {
  func makeContext() throws -> PageBuilder.BuildContext {
    let compInput = "(components (enum Phase {card army event action}))"
    let stateInput = "(state (field phase Phase) (flag ended))"
    let registry = try ComponentRegistry(try SExprParser.parse(compInput))
    let schema = try StateSchema(try SExprParser.parse(stateInput))
    return PageBuilder.BuildContext(
      components: registry, schema: schema, randomSource: nil,
      actionSchema: ActionSchema.empty(),
      defines: try DefineExpander([])
    )
  }

  @Test func parseSimplePage() throws {
    let ctx = try makeContext()
    let input = try SExprParser.parse("""
    (page "Card Phase"
      (rule (when (== phase card))
            (offer drawCard))
      (reduce drawCard
        (set ended true)))
    """)
    let page = try PageBuilder.buildPage(input, context: ctx)
    #expect(page.name == "Card Phase")
    #expect(page.rules.count == 1)
  }

  @Test func parsePriorityPage() throws {
    let ctx = try makeContext()
    let input = try SExprParser.parse("""
    (priority "Victory"
      (rule (when (and (== phase action) (not ended)))
            (offer claimVictory))
      (reduce claimVictory
        (set ended true)))
    """)
    let page = try PageBuilder.buildPage(input, context: ctx)
    #expect(page.name == "Victory")
  }

  @Test func parseReaction() throws {
    let ctx = try makeContext()
    let input = try SExprParser.parse("""
    (reaction "Test"
      (when (== phase action))
      (apply (set ended true)))
    """)
    let reaction = try PageBuilder.buildReaction(input, context: ctx)
    #expect(reaction.name == "Test")
  }

  @Test func parseForEachPage() throws {
    let compInput = """
    (components
      (enum Phase {card army event action})
      (enum ArmySlot {east west}))
    """
    let stateInput = """
    (state
      (field phase Phase)
      (flag ended)
      (dict armyPosition ArmySlot Int))
    """
    let registry = try ComponentRegistry(try SExprParser.parse(compInput))
    let schema = try StateSchema(try SExprParser.parse(stateInput))
    let ctx = PageBuilder.BuildContext(
      components: registry, schema: schema, randomSource: nil,
      actionSchema: ActionSchema.empty(),
      defines: try DefineExpander([])
    )
    let input = try SExprParser.parse("""
    (rules
      (forEachPage "Army Advance"
        (when (== phase army))
        (items (list east west))
        (transition enterEvent)
        (reduce advanceArmy
          (log "advanced"))))
    """)
    let result = try PageBuilder.buildRules(input, context: ctx)
    #expect(result.pages.count == 1)
    #expect(result.pages[0].name == "Army Advance")
  }
}
