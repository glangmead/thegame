import Testing
import CoreGraphics
@testable import DynamicalSystems

@Suite("Site Operations")
struct SiteOperationsTests {

  private func makeCompiler(
    graph: SiteGraph = SiteGraph()
  ) -> (ExpressionCompiler, StateSchema) {
    // swiftlint:disable:next force_try
    let registry = try! ComponentRegistry(try! SExprParser.parse(
      "(components (enum Phase {play}))"
    ))
    // swiftlint:disable:next force_try
    let schema = try! StateSchema(try! SExprParser.parse(
      "(state (counter x 0 10))"
    ))
    return (
      ExpressionCompiler(
        components: registry, schema: schema, graph: graph
      ),
      schema
    )
  }

  @Test func siteConstruction() throws {
    let (compiler, schema) = makeCompiler()
    let sexpr = try SExprParser.parse("(site \"road\" 0)")
    let compiled = compiler.expr(sexpr)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema)
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
    let (compiler, schema) = makeCompiler(graph: graph)

    let sexpr = try SExprParser.parse("(site \"road\" \"Eindhoven\")")
    let compiled = compiler.expr(sexpr)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema)
    )
    let result = try compiled(env)
    #expect(result == .site(track: "road", index: 1))
  }

  @Test func posAndAdvance() throws {
    var graph = SiteGraph()
    let site0 = graph.addSite(position: .zero)
    let site1 = graph.addSite(position: CGPoint(x: 0, y: 40))
    let site2 = graph.addSite(position: CGPoint(x: 0, y: 80))
    graph.connect(site0, to: site1, direction: .next)
    graph.connect(site1, to: site2, direction: .next)
    graph.addTrack("road", sites: [site0, site1, site2])

    let compSrc = "(components (enum Piece {corps}))"
    let stateSrc = "(state (counter x 0 10))"
    let registry = try ComponentRegistry(
      try SExprParser.parse(compSrc)
    )
    let schema = try StateSchema(try SExprParser.parse(stateSrc))
    let compiler = ExpressionCompiler(
      components: registry, schema: schema, graph: graph
    )

    var state = InterpretedState(schema: schema)
    state.place(
      "corps", at: .site(track: "road", index: 0), enumType: "Piece"
    )
    let env = ExpressionCompiler.Env(state: state)

    // (pos corps) returns its site
    let posExpr = compiler.expr(
      try SExprParser.parse("(pos corps)")
    )
    let pos = try posExpr(env)
    #expect(pos == .site(track: "road", index: 0))

    // (advance (pos corps) "road" 1) moves one step
    let advExpr = compiler.expr(try SExprParser.parse(
      "(advance (pos corps) \"road\" 1)"
    ))
    let adv = try advExpr(env)
    #expect(adv == .site(track: "road", index: 1))

    // Advance clamps at end
    let advFar = compiler.expr(try SExprParser.parse(
      "(advance (pos corps) \"road\" 10)"
    ))
    let far = try advFar(env)
    #expect(far == .site(track: "road", index: 2)) // clamped to last

    // pieceAt
    let pieceAtExpr = compiler.expr(try SExprParser.parse(
      "(pieceAt (site \"road\" 0))"
    ))
    let found = try pieceAtExpr(env)
    #expect(found.asEnumValue == "corps")
  }

  @Test func trackOfAndIndexOf() throws {
    let (compiler, schema) = makeCompiler()
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema)
    )
    let trackExpr = compiler.expr(try SExprParser.parse(
      "(trackOf (site \"road\" 2))"
    ))
    #expect(try trackExpr(env) == .string("road"))
    let idxExpr = compiler.expr(try SExprParser.parse(
      "(indexOf (site \"road\" 2))"
    ))
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

    let compSrc = "(components (enum Piece {ally}))"
    let stateSrc = "(state (counter x 0 10))"
    let registry = try ComponentRegistry(
      try SExprParser.parse(compSrc)
    )
    let schemaParsed = try StateSchema(
      try SExprParser.parse(stateSrc)
    )
    let compiler = ExpressionCompiler(
      components: registry, schema: schemaParsed, graph: graph
    )
    var state = InterpretedState(schema: schemaParsed)
    state.place(
      "ally",
      at: .site(track: "allied", index: 0),
      enumType: "Piece"
    )
    let env = ExpressionCompiler.Env(state: state)

    let adj = compiler.expr(try SExprParser.parse(
      "(adjacent (pos ally) \"road\")"
    ))
    let result = try adj(env)
    #expect(result == .site(track: "road", index: 0))
  }

  @Test func namedSiteConstruction() throws {
    var graph = SiteGraph()
    let resID = graph.addSite(position: .zero, displayName: "reserves")
    let (compiler, schema) = makeCompiler(graph: graph)
    let env = ExpressionCompiler.Env(
      state: InterpretedState(schema: schema)
    )

    let sexpr = try SExprParser.parse("(site \"reserves\")")
    let result = try compiler.expr(sexpr)(env)
    #expect(result == .site(track: "", index: resID.raw))
  }

  @Test func pieceAdapterTransposes() throws {
    let compSrc = """
    (components
      (enum Piece {corps tank} player: 0)
      (enum Phase {play}))
    """
    let stateSrc = """
    (state
      (dict strength Piece Int)
      (field phase Phase))
    """
    let registry = try ComponentRegistry(try SExprParser.parse(compSrc))
    let schema = try StateSchema(try SExprParser.parse(stateSrc))

    var graph = SiteGraph()
    let site0 = graph.addSite(position: .zero)
    let site1 = graph.addSite(position: CGPoint(x: 0, y: 40))
    graph.addTrack("road", sites: [site0, site1])

    var state = InterpretedState(schema: schema)
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
    let compSrc = "(components (enum Piece {corps tank}))"
    let stateSrc = "(state (counter x 0 10))"
    let registry = try ComponentRegistry(try SExprParser.parse(compSrc))
    let schema = try StateSchema(try SExprParser.parse(stateSrc))
    var graph = SiteGraph()
    let s0 = graph.addSite(position: .zero)
    let s1 = graph.addSite(position: CGPoint(x: 0, y: 40))
    graph.connect(s0, to: s1, direction: .next)
    graph.addTrack("road", sites: [s0, s1])
    let compiler = ExpressionCompiler(
      components: registry, schema: schema, graph: graph
    )

    let state = InterpretedState(schema: schema)
    let env = ExpressionCompiler.Env(state: state)

    // place
    let placeStmt = compiler.stmt(try SExprParser.parse(
      "(place corps (site \"road\" 0))"
    ))
    _ = try placeStmt(env)
    #expect(env.state.positions["corps"] == .site(track: "road", index: 0))
    #expect(env.state.pieceTypes["corps"] == "Piece")

    // move
    let moveStmt = compiler.stmt(try SExprParser.parse(
      "(move corps (site \"road\" 1))"
    ))
    _ = try moveStmt(env)
    #expect(env.state.positions["corps"] == .site(track: "road", index: 1))

    // remove
    let removeStmt = compiler.stmt(try SExprParser.parse(
      "(remove corps)"
    ))
    _ = try removeStmt(env)
    #expect(env.state.positions["corps"] == nil)
  }
}
