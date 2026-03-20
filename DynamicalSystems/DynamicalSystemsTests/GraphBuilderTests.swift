import Testing
@testable import DynamicalSystems

@Suite("GraphBuilder")
struct GraphBuilderTests {
  @Test func parseTracks() throws {
    let input = """
    (graph
      (track "east" length: 6 wall: true)
      (track "sky" length: 6)
      (site reserves))
    """
    let sexpr = try SExprParser.parse(input)
    let graph = try GraphBuilder.build(sexpr)
    // Track "east" should have 6 sites, "sky" 6 sites, plus "reserves" = 13
    #expect(graph.sites.count == 13)
    // Track "east" should be registered
    #expect(graph.tracks["east"]?.count == 6)
    // Named site "reserves" should exist
    let reservesSite = graph.sites.values.first { $0.label == "reserves" }
    #expect(reservesSite != nil)
  }
}
