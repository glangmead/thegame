import Testing
@testable import DynamicalSystems

@Suite("ComponentRegistry")
struct ComponentRegistryTests {

  @Test func parseSimpleEnum() throws {
    let input = """
    (components
      (enum Track {east west gate terror sky}))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    #expect(registry.enumCases("Track") == ["east", "west", "gate", "terror", "sky"])
  }

  @Test func parseSumTypeEnum() throws {
    let input = """
    (components
      (enum Location simple (onTrack Track)))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    let def = registry.enums["Location"]
    #expect(def != nil)
    #expect(def?.cases == ["simple", "onTrack"])
    #expect(def?.associatedTypes["onTrack"] == ["Track"])
    #expect(def?.associatedTypes["simple"] == nil)
  }

  @Test func parseFn() throws {
    let input = """
    (components
      (enum ArmyType {goblin orc dragon})
      (fn strength ArmyType {goblin 2 orc 3 dragon 4}))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    #expect(registry.lookupFn("strength", argument: "goblin") == .int(2))
    #expect(registry.lookupFn("strength", argument: "dragon") == .int(4))
  }

  @Test func parseStruct() throws {
    let input = """
    (components
      (struct CardDRM
        (field action String)
        (field value Int)))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    let def = registry.structs["CardDRM"]
    #expect(def != nil)
    #expect(def?.fields.count == 2)
    #expect(def?.fields[0].name == "action")
    #expect(def?.fields[1].type == "Int")
  }

  @Test func parseCards() throws {
    let input = """
    (components
      (cards
        (card 1 "Goblin Raid" action event: advance)
        (card 2 "Dragon Fire" action event: terror)))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    #expect(registry.cards.count == 2)
    let first = registry.cards[0].asStruct
    #expect(first?.type == "Card")
    #expect(first?.fields["number"] == .int(1))
    #expect(first?.fields["title"] == .string("Goblin Raid"))
    #expect(first?.fields["deck"] == .string("action"))
    #expect(first?.fields["event"] == .string("advance"))
  }

  @Test func isEnumCaseLookup() throws {
    let input = """
    (components
      (enum Track {east west gate})
      (enum Phase {dawn dusk}))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    #expect(registry.isEnumCase("east") == "Track")
    #expect(registry.isEnumCase("dawn") == "Phase")
    #expect(registry.isEnumCase("missing") == nil)
  }

  @Test func lookupFnMissing() throws {
    let input = """
    (components
      (enum ArmyType {goblin orc})
      (fn strength ArmyType {goblin 2 orc 3}))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    #expect(registry.lookupFn("strength", argument: "dragon") == nil)
    #expect(registry.lookupFn("nonexistent", argument: "goblin") == nil)
  }

  @Test func rejectsNonComponentsForm() {
    let sexpr = SExpr.list([.atom("notcomponents")])
    #expect(throws: DSLError.self) {
      _ = try ComponentRegistry(sexpr)
    }
  }

  @Test func unknownFormThrows() throws {
    let input = """
    (components
      (bogus foo))
    """
    let sexpr = try SExprParser.parse(input)
    #expect(throws: DSLError.self) {
      _ = try ComponentRegistry(sexpr)
    }
  }

  @Test func parseCrt2D() throws {
    let input = """
    (components
      (enum Advantage {allies equal germans})
      (crt attackCRT
        (row Advantage) (col 1 6)
        (results allyHits germanHits controlGained)
        (allies  {1 (1 0 false) 2-4 (1 1 true)  5-6 (0 1 true)})
        (equal   {1 (2 0 false) 2-4 (1 1 false) 5-6 (1 1 true)})
        (germans {1 (3 0 false) 2-4 (2 1 false) 5-6 (1 0 true)})))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    let crt = registry.crts["attackCRT"]
    #expect(crt != nil)
    #expect(crt?.rowEnumName == "Advantage")
    #expect(crt?.resultFields == ["allyHits", "germanHits", "controlGained"])
    #expect(crt?.rows.count == 3)
    #expect(crt?.lookup(row: "allies", dieRoll: 1)
      == [.int(1), .int(0), .bool(false)])
    #expect(crt?.lookup(row: "allies", dieRoll: 3)
      == [.int(1), .int(1), .bool(true)])
    #expect(crt?.lookup(row: "germans", dieRoll: 6)
      == [.int(1), .int(0), .bool(true)])
  }

  @Test func parseCrt1D() throws {
    let input = """
    (components
      (crt airdropPenalty
        (col 1 6)
        {1-2 2  3-4 1  5-6 0}))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    let crt = registry.crts["airdropPenalty"]
    #expect(crt != nil)
    #expect(crt?.rowEnumName == nil)
    #expect(crt?.resultFields.isEmpty == true)
    #expect(crt?.lookup(row: nil, dieRoll: 1) == [.int(2)])
    #expect(crt?.lookup(row: nil, dieRoll: 4) == [.int(1)])
    #expect(crt?.lookup(row: nil, dieRoll: 5) == [.int(0)])
  }

  @Test func crtLookupOutOfRange() throws {
    let input = """
    (components
      (crt test
        (col 1 6)
        {1-3 10  4-6 20}))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    let crt = registry.crts["test"]
    #expect(crt?.lookup(row: nil, dieRoll: 0) == nil)
    #expect(crt?.lookup(row: nil, dieRoll: 7) == nil)
    #expect(crt?.lookup(row: nil, dieRoll: 3) == [.int(10)])
  }

  @Test func fnWithBoolValues() throws {
    let input = """
    (components
      (enum Flag {on off})
      (fn active Flag {on true off false}))
    """
    let sexpr = try SExprParser.parse(input)
    let registry = try ComponentRegistry(sexpr)
    #expect(registry.lookupFn("active", argument: "on") == .bool(true))
    #expect(registry.lookupFn("active", argument: "off") == .bool(false))
  }
}
