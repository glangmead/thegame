import Testing
@testable import DynamicalSystems

@Suite("StateSchema")
struct StateSchemaTests {

  @Test func parseCounterAndFlag() throws {
    let input = """
    (state
      (counter arcaneEnergy 0 6)
      (flag ended))
    """
    let sexpr = try SExprParser.parse(input)
    let schema = try StateSchema(sexpr)
    let arcaneEnergy = schema.field("arcaneEnergy")
    #expect(arcaneEnergy?.kind == .counter(min: 0, max: 6))
    let ended = schema.field("ended")
    #expect(ended?.kind == .flag)
  }

  @Test func parseAllFieldKinds() throws {
    let input = """
    (state
      (counter energy 0 6)
      (flag ended)
      (field phase Phase)
      (dict armyPosition ArmySlot Int)
      (set breaches Track)
      (deck dayDrawPile Card)
      (optional currentCard Card))
    """
    let sexpr = try SExprParser.parse(input)
    let schema = try StateSchema(sexpr)
    #expect(schema.fields.count == 7)
    #expect(schema.field("energy")?.kind == .counter(min: 0, max: 6))
    #expect(schema.field("ended")?.kind == .flag)
    #expect(schema.field("phase")?.kind == .field(type: "Phase"))
    #expect(schema.field("armyPosition")?.kind == .dict(keyType: "ArmySlot", valueType: "Int"))
    #expect(schema.field("breaches")?.kind == .set(elementType: "Track"))
    #expect(schema.field("dayDrawPile")?.kind == .deck(cardType: "Card"))
    #expect(schema.field("currentCard")?.kind == .optional(valueType: "Card"))
  }

  @Test func rejectsNonStateForm() throws {
    let input = "(notstate (flag x))"
    let sexpr = try SExprParser.parse(input)
    #expect(throws: DSLError.self) {
      try StateSchema(sexpr)
    }
  }

  @Test func rejectsUnknownFieldKind() throws {
    let input = "(state (bogus x))"
    let sexpr = try SExprParser.parse(input)
    #expect(throws: DSLError.self) {
      try StateSchema(sexpr)
    }
  }

  @Test func counterWithInfMax() throws {
    let input = "(state (counter hp 0 inf))"
    let sexpr = try SExprParser.parse(input)
    let schema = try StateSchema(sexpr)
    #expect(schema.field("hp")?.kind == .counter(min: 0, max: Int.max))
  }

  @Test func allFieldNamesReturnsEveryField() throws {
    let input = """
    (state
      (flag a)
      (flag b)
      (counter c 0 1))
    """
    let sexpr = try SExprParser.parse(input)
    let schema = try StateSchema(sexpr)
    #expect(Set(schema.allFieldNames) == Set(["a", "b", "c"]))
  }
}
