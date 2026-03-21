import Testing
import CoreGraphics
@testable import DynamicalSystems

@Suite("InterpretedState")
struct InterpretedStateTests {
  @Test func constructFromSchema() throws {
    let input = """
    (state
      (counter energy 0 6)
      (flag ended)
      (set breaches Track))
    """
    let schema = try StateSchema(try SExprParser.parse(input))
    let state = InterpretedState(schema: schema)
    #expect(state.getCounter("energy") == 0)
    #expect(state.getFlag("ended") == false)
    #expect(state.getSet("breaches").isEmpty)
  }

  @Test func counterClamping() throws {
    let input = "(state (counter energy 0 6))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)
    state.setCounter("energy", 10)
    #expect(state.getCounter("energy") == 6)
    state.setCounter("energy", -5)
    #expect(state.getCounter("energy") == 0)
  }

  @Test func setOperations() throws {
    let input = "(state (set breaches Track))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)
    state.insertIntoSet("breaches", "east")
    #expect(state.getSet("breaches").contains("east"))
    state.removeFromSet("breaches", "east")
    #expect(state.getSet("breaches").isEmpty)
  }

  @Test func dictOperations() throws {
    let input = "(state (dict armyPosition ArmySlot Int))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)
    state.setDictEntry("armyPosition", key: "east", value: .int(5))
    #expect(state.getDict("armyPosition")["east"] == .int(5))
    state.removeDictEntry("armyPosition", key: "east")
    #expect(state.getDict("armyPosition")["east"] == nil)
  }

  @Test func historyTracking() throws {
    let input = "(state (counter energy 0 6))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)
    state.history.append(ActionValue("drawCard"))
    state.phase = "card"
    #expect(state.history.count == 1)
    #expect(state.phase == "card")
  }

  @Test func positionOperations() throws {
    let input = "(state (counter energy 0 6))"
    let schema = try StateSchema(try SExprParser.parse(input))
    var state = InterpretedState(schema: schema)

    // Initially no positions
    #expect(state.positions.isEmpty)

    // Place
    let site = DSLValue.site(track: "road", index: 0)
    state.place("corps", at: site, enumType: "CorpsPiece")
    #expect(state.positions["corps"] == site)
    #expect(state.pieceTypes["corps"] == "CorpsPiece")

    // Move
    let newSite = DSLValue.site(track: "road", index: 1)
    state.place("corps", at: newSite, enumType: "CorpsPiece")
    #expect(state.positions["corps"] == newSite)

    // Remove
    state.removePiece("corps")
    #expect(state.positions["corps"] == nil)
    #expect(state.pieceTypes["corps"] == nil)
  }

  @Test func siteValueBasics() {
    let site = DSLValue.site(track: "road", index: 2)
    #expect(site.asSite != nil)
    #expect(site.asSite?.track == "road")
    #expect(site.asSite?.index == 2)
    #expect(site.displayString == "road:2")
    #expect(!site.isNil)

    let named = DSLValue.site(track: "", index: 42)
    #expect(named.displayString == ":42")
  }

  @Test func siteGraphResolve() {
    var graph = SiteGraph()
    let site0 = graph.addSite(position: .zero)
    let site1 = graph.addSite(position: CGPoint(x: 40, y: 0))
    graph.addTrack("road", sites: [site0, site1])

    // Track site resolves by index
    let resolved = graph.resolve(.site(track: "road", index: 0))
    #expect(resolved == site0)
    let resolved1 = graph.resolve(.site(track: "road", index: 1))
    #expect(resolved1 == site1)

    // Out of bounds returns nil
    #expect(graph.resolve(.site(track: "road", index: 5)) == nil)

    // Named site resolves by raw SiteID
    let namedID = graph.addSite(position: CGPoint(x: 100, y: 0), label: "reserves")
    let namedResolved = graph.resolve(.site(track: "", index: namedID.raw))
    #expect(namedResolved == namedID)

    // Non-existent named site returns nil
    #expect(graph.resolve(.site(track: "", index: 9999)) == nil)

    // Non-site value returns nil
    #expect(graph.resolve(.int(3)) == nil)
  }
}
