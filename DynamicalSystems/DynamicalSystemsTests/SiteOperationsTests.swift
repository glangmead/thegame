import Testing
import CoreGraphics
@testable import DynamicalSystems

@Suite("Site Operations")
// swiftlint:disable:next type_body_length
struct SiteOperationsTests {

  let interner = StringInterner()

  private func makeCompiler(
    graph: SiteGraph = SiteGraph()
  ) throws -> (JSONExpressionCompiler, StateSchema) {
    let registry = ComponentRegistry(
      enums: ["Phase": EnumDefinition(
        name: "Phase", cases: ["play"],
        associatedTypes: [:], displayNames: [:]
      )],
      structs: [:], functions: [:], cards: [],
      crts: [:], playerIndex: [:]
    )
    let schema = StateSchema(fields: [
      "x": FieldDefinition(name: "x", kind: .counter(min: 0, max: 10))
    ])
    let defines = try JSONDefineExpander(.array([]))
    return (
      JSONExpressionCompiler(
        components: registry, schema: schema,
        graph: graph, defines: defines,
        interner: interner
      ),
      schema
    )
  }

  @Test func siteConstruction() throws {
    let (compiler, schema) = try makeCompiler()
    let json: JSONValue = .object(["site": .array([.string("road"), .int(0)])])
    let compiled = compiler.expr(json)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema, interner: interner)
    )
    let result = try compiled(env)
    #expect(result == .site(track: "road", index: 0))
  }

  @Test func siteLabelConstruction() throws {
    var graph = SiteGraph()
    let site0 = graph.addSite(position: .zero, displayName: "Belgium")
    let site1 = graph.addSite(
      position: CGPoint(x: 0, y: 40), displayName: "Eindhoven"
    )
    graph.addTrack("road", sites: [site0, site1])
    let (compiler, schema) = try makeCompiler(graph: graph)

    let json: JSONValue = .object([
      "site": .array([.string("road"), .string("Eindhoven")])
    ])
    let compiled = compiler.expr(json)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema, interner: interner)
    )
    let result = try compiled(env)
    #expect(result == .site(track: "road", index: 1))
  }

  // swiftlint:disable:next function_body_length
  @Test func posAndAdvance() throws {
    var graph = SiteGraph()
    let site0 = graph.addSite(position: .zero)
    let site1 = graph.addSite(position: CGPoint(x: 0, y: 40))
    let site2 = graph.addSite(position: CGPoint(x: 0, y: 80))
    graph.connect(site0, to: site1, direction: .next)
    graph.connect(site1, to: site2, direction: .next)
    graph.addTrack("road", sites: [site0, site1, site2])

    let registry = ComponentRegistry(
      enums: ["Piece": EnumDefinition(
        name: "Piece", cases: ["corps", "tank"],
        associatedTypes: [:], displayNames: [:]
      )],
      structs: [:], functions: [:], cards: [],
      crts: [:], playerIndex: [:]
    )
    let schema = StateSchema(fields: [
      "x": FieldDefinition(name: "x", kind: .counter(min: 0, max: 10))
    ])
    let defines = try JSONDefineExpander(.array([]))
    let compiler = JSONExpressionCompiler(
      components: registry, schema: schema,
      graph: graph, defines: defines,
      interner: interner
    )

    var state = InterpretedState(schema: schema, interner: interner)
    state.place(
      "corps", at: .site(track: "road", index: 0), enumType: "Piece"
    )
    let env = ExpressionCompiler.Env(state: state)

    // {"pos": ["corps"]} returns its site
    let posExpr = compiler.expr(
      .object(["pos": .array([.string("corps")])])
    )
    let pos = try posExpr(env)
    #expect(pos == .site(track: "road", index: 0))

    // {"advance": [{"pos": ["corps"]}, "road", 1]} moves one step
    let advExpr = compiler.expr(.object([
      "advance": .array([
        .object(["pos": .array([.string("corps")])]),
        .string("road"),
        .int(1)
      ])
    ]))
    let adv = try advExpr(env)
    #expect(adv == .site(track: "road", index: 1))

    // Advance clamps at end
    let advFar = compiler.expr(.object([
      "advance": .array([
        .object(["pos": .array([.string("corps")])]),
        .string("road"),
        .int(10)
      ])
    ]))
    let far = try advFar(env)
    #expect(far == .site(track: "road", index: 2)) // clamped to last

    // pieceAt
    let pieceAtExpr = compiler.expr(.object([
      "pieceAt": .array([
        .object(["site": .array([.string("road"), .int(0)])])
      ])
    ]))
    let found = try pieceAtExpr(env)
    #expect(found.displayString(interner: interner) == "corps")
  }

  @Test func trackOfAndIndexOf() throws {
    let (compiler, schema) = try makeCompiler()
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema, interner: interner)
    )
    let trackExpr = compiler.expr(.object([
      "trackOf": .array([
        .object(["site": .array([.string("road"), .int(2)])])
      ])
    ]))
    #expect(try trackExpr(env) == .string("road"))
    let idxExpr = compiler.expr(.object([
      "indexOf": .array([
        .object(["site": .array([.string("road"), .int(2)])])
      ])
    ]))
    #expect(try idxExpr(env) == .int(2))
  }

  @Test func adjacentExpression() throws {
    var graph = SiteGraph()
    let alliedSite = graph.addSite(position: .zero)
    let roadSite = graph.addSite(position: CGPoint(x: 40, y: 0))
    graph.addTrack("allied", sites: [alliedSite])
    graph.addTrack("road", sites: [roadSite])
    graph.sites[alliedSite]?.adjacency[.custom("road")] = roadSite
    graph.sites[roadSite]?.adjacency[.custom("allied")] = alliedSite

    let registry = ComponentRegistry(
      enums: ["Piece": EnumDefinition(
        name: "Piece", cases: ["ally"],
        associatedTypes: [:], displayNames: [:]
      )],
      structs: [:], functions: [:], cards: [],
      crts: [:], playerIndex: [:]
    )
    let schema = StateSchema(fields: [
      "x": FieldDefinition(name: "x", kind: .counter(min: 0, max: 10))
    ])
    let defines = try JSONDefineExpander(.array([]))
    let compiler = JSONExpressionCompiler(
      components: registry, schema: schema,
      graph: graph, defines: defines,
      interner: interner
    )
    var state = InterpretedState(schema: schema, interner: interner)
    state.place(
      "ally",
      at: .site(track: "allied", index: 0),
      enumType: "Piece"
    )
    let env = ExpressionCompiler.Env(state: state)

    let adj = compiler.expr(.object([
      "adjacent": .array([
        .object(["pos": .array([.string("ally")])]),
        .string("road")
      ])
    ]))
    let result = try adj(env)
    #expect(result == .site(track: "road", index: 0))
  }

  @Test func namedSiteConstruction() throws {
    var graph = SiteGraph()
    let resID = graph.addSite(position: .zero, displayName: "reserves")
    let (compiler, schema) = try makeCompiler(graph: graph)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema, interner: interner)
    )

    let json: JSONValue = .object([
      "site": .array([.string("reserves")])
    ])
    let result = try compiler.expr(json)(env)
    #expect(result == .site(track: "", index: resID.raw))
  }

  // swiftlint:disable:next function_body_length
  @Test func pieceAdapterTransposes() throws {
    let registry = ComponentRegistry(
      enums: [
        "Piece": EnumDefinition(
          name: "Piece", cases: ["corps", "tank"],
          associatedTypes: [:], displayNames: [:]
        ),
        "Phase": EnumDefinition(
          name: "Phase", cases: ["play"],
          associatedTypes: [:], displayNames: [:]
        )
      ],
      structs: [:], functions: [:], cards: [],
      crts: [:], playerIndex: ["Piece": 0]
    )
    let schema = StateSchema(fields: [
      "strength": FieldDefinition(
        name: "strength",
        kind: .dict(keyType: "Piece", valueType: "Int")
      ),
      "phase": FieldDefinition(
        name: "phase",
        kind: .field(type: "Phase")
      )
    ])

    var graph = SiteGraph()
    let site0 = graph.addSite(position: .zero)
    let site1 = graph.addSite(position: CGPoint(x: 0, y: 40))
    graph.addTrack("road", sites: [site0, site1])

    var state = InterpretedState(schema: schema, interner: interner)
    state.place(
      "corps", at: .site(track: "road", index: 0), enumType: "Piece"
    )
    state.place(
      "tank", at: .site(track: "road", index: 1), enumType: "Piece"
    )
    state.setDictEntry("strength", key: "corps", value: .int(6))
    state.setDictEntry("strength", key: "tank", value: .int(4))

    let adapter = InterpretedPieceAdapter(
      state: state,
      schema: schema,
      graph: graph,
      playerIndex: registry.playerIndex
    )

    #expect(adapter.pieces.count == 2)

    let corpsID = "corps".hashValue & 0x7FFFFFFF
    let corpsPiece = adapter.pieces.first { $0.id == corpsID }
    #expect(corpsPiece != nil)
    #expect(corpsPiece?.owner == PlayerID(0))
    #expect(corpsPiece?.displayValues["strength"] == 6)

    // Section maps piece to its site
    if let corps = corpsPiece {
      #expect(adapter.section[corps]?.site == site0)
    }
  }

  @Test func placeAndMoveStatements() throws {
    let registry = ComponentRegistry(
      enums: ["Piece": EnumDefinition(
        name: "Piece", cases: ["corps", "tank"],
        associatedTypes: [:], displayNames: [:]
      )],
      structs: [:], functions: [:], cards: [],
      crts: [:], playerIndex: [:]
    )
    let schema = StateSchema(fields: [
      "x": FieldDefinition(name: "x", kind: .counter(min: 0, max: 10))
    ])
    var graph = SiteGraph()
    let siteA = graph.addSite(position: .zero)
    let siteB = graph.addSite(position: CGPoint(x: 0, y: 40))
    graph.connect(siteA, to: siteB, direction: .next)
    graph.addTrack("road", sites: [siteA, siteB])
    let defines = try JSONDefineExpander(.array([]))
    let compiler = JSONExpressionCompiler(
      components: registry, schema: schema,
      graph: graph, defines: defines,
      interner: interner
    )

    let state = InterpretedState(schema: schema, interner: interner)
    let env = ExpressionCompiler.Env(state: state)

    // place
    let placeStmt = compiler.stmt(.object([
      "place": .array([
        .string("corps"),
        .object(["site": .array([.string("road"), .int(0)])])
      ])
    ]))
    _ = try placeStmt(env)
    #expect(env.state.positions["corps"] == .site(track: "road", index: 0))
    #expect(env.state.pieceTypes["corps"] == "Piece")

    // move
    let moveStmt = compiler.stmt(.object([
      "move": .array([
        .string("corps"),
        .object(["site": .array([.string("road"), .int(1)])])
      ])
    ]))
    _ = try moveStmt(env)
    #expect(env.state.positions["corps"] == .site(track: "road", index: 1))

    // remove
    let removeStmt = compiler.stmt(.object([
      "remove": .array([.string("corps")])
    ]))
    _ = try removeStmt(env)
    #expect(env.state.positions["corps"] == nil)
  }
}
