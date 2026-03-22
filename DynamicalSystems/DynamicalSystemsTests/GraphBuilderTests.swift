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
    let reservesSite = graph.sites.values.first { $0.displayName == "reserves" }
    #expect(reservesSite != nil)
  }

  @Test func verticalLayoutWithDisplayNames() throws {
    let input = """
    (graph
      (track "allied" length: 4
        displayNames: {"Eindhoven" "Grave" "Nijmegen" "Arnhem"}
        tags: {"allied"})
      (track "road" length: 5
        displayNames: {"Belgium" "Eindhoven" "Grave" "Nijmegen" "Arnhem"}
        tags: {"road"}))
    """
    let sexpr = try SExprParser.parse(input)
    let graph = try GraphBuilder.build(sexpr)

    // Track counts
    #expect(graph.tracks["allied"]?.count == 4)
    #expect(graph.tracks["road"]?.count == 5)

    // Track order preserved
    #expect(graph.trackOrder == ["allied", "road"])

    // Labels applied
    let alliedFirst = graph.tracks["allied"]![0]
    #expect(graph.sites[alliedFirst]?.displayName == "Eindhoven")

    // Tags applied to sites
    #expect(graph.sites[alliedFirst]?.tags.contains("allied") == true)

    // Track tags stored
    #expect(graph.trackTags["allied"]?.contains("allied") == true)

    // Vertical layout: x varies by track, y varies by site index
    let allied0 = graph.sites[graph.tracks["allied"]![0]]!
    let allied1 = graph.sites[graph.tracks["allied"]![1]]!
    let road0 = graph.sites[graph.tracks["road"]![0]]!
    // Same track = same x
    #expect(allied0.position.x == allied1.position.x)
    // Different tracks = different x
    #expect(allied0.position.x != road0.position.x)
    // Higher index = higher y (within same track)
    #expect(allied1.position.y > allied0.position.y)
  }

  @Test func crossConnect() throws {
    let input = """
    (graph
      (track "allied" length: 4)
      (track "road" length: 5)
      (crossConnect "allied" "road" offset: 1))
    """
    let sexpr = try SExprParser.parse(input)
    let graph = try GraphBuilder.build(sexpr)

    // Allied site 0 should connect to road site 1 via .custom("road")
    let allied0 = graph.tracks["allied"]![0]
    let road1 = graph.tracks["road"]![1]
    #expect(graph.sites[allied0]?.adjacency[.custom("road")] == road1)
    // Reverse: road site 1 connects back to allied site 0
    #expect(graph.sites[road1]?.adjacency[.custom("allied")] == allied0)
  }

  @Test func namedSitesAboveTracks() throws {
    let input = """
    (graph
      (track "road" length: 3)
      (site "reserves")
      (site "discard"))
    """
    let sexpr = try SExprParser.parse(input)
    let graph = try GraphBuilder.build(sexpr)

    #expect(graph.sites.count == 5) // 3 track + 2 named
    let reserves = graph.sites.values.first { $0.displayName == "reserves" }
    #expect(reserves != nil)
    // Named sites should be above the tallest track
    let maxTrackY = graph.tracks["road"]!.compactMap { graph.sites[$0]?.position.y }.max() ?? 0
    #expect(reserves!.position.y > maxTrackY)
  }
}
