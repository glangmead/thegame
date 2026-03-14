//
//  FrameworkGraphTests.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/7/26.
//

import CoreGraphics
import Foundation
import Testing

// MARK: - GameModel Test Types

private struct TrivialState: GameState, CustomStringConvertible {
  typealias Phase = Int
  typealias Piece = Int
  typealias PiecePosition = Int
  typealias Player = Int
  typealias Position = Int

  var name: String { "Trivial" }
  var player: Int = 0
  var players: [Int] = [0]
  var ended: Bool = false
  var endedInVictoryFor: [Int] = []
  var endedInDefeatFor: [Int] = []
  var position: [Int: Int] = [:]
  var stepCount: Int = 0
  var description: String { "step=\(stepCount)" }
}

private enum TrivialAction: Hashable, CustomStringConvertible {
  case step
  var description: String { "step" }
}

private struct TrivialGame: PlayableGame {
  var gameName: String { "Trivial" }
  func isTerminal(state: TrivialState) -> Bool {
    state.ended
  }

  func newState() -> TrivialState { TrivialState() }
  func allowedActions(state: TrivialState) -> [TrivialAction] {
    state.ended ? [] : [.step]
  }
  func reduce(into state: inout TrivialState, action: TrivialAction) -> [Log] {
    state.stepCount += 1
    if state.stepCount >= 3 { state.ended = true }
    return []
  }
}

// MARK: - SiteGraph Tests

struct SiteGraphTests {
  @Test
  func testDirectionOpposites() {
    #expect(Direction.next.opposite == .previous)
    #expect(Direction.previous.opposite == .next)
    #expect(Direction.top.opposite == .bottom)
    #expect(Direction.north.opposite == .south)
    #expect(Direction.northwest.opposite == .southeast)
  }

  @Test
  func testSiteGraphBasic() {
    let site0 = SiteID(0)
    let site1 = SiteID(1)
    var graph = SiteGraph()
    graph.addSite(id: site0, position: CGPoint(x: 0, y: 0))
    graph.addSite(id: site1, position: CGPoint(x: 1, y: 0))
    graph.connect(site0, to: site1, direction: .next)

    #expect(graph.sites.count == 2)
    #expect(graph.sites[site0]?.adjacency[.next] == site1)
    #expect(graph.sites[site1]?.adjacency[.previous] == site0)
  }

  @Test
  func testSiteCursor() {
    var graph = SiteGraph()
    let site0 = graph.addSite(position: CGPoint(x: 0, y: 0))
    let site1 = graph.addSite(position: CGPoint(x: 0, y: 1))
    let site2 = graph.addSite(position: CGPoint(x: 0, y: 2))
    graph.connect(site0, to: site1, direction: .next)
    graph.connect(site1, to: site2, direction: .next)

    let cursor = graph.site(site0)
    #expect(cursor.next?.id == site1)
    #expect(cursor.next?.next?.id == site2)
    #expect(cursor.next?.next?.next == nil)
    #expect(cursor.next?.next?.previous?.id == site1)
    #expect(graph.site(site2).top == nil)
  }

  @Test
  func testColumnarGenerator() {
    let graph = SiteGraph.columnar(heights: [3, 2])

    #expect(graph.sites.count == 5)
    #expect(graph.tracks.count == 2)
    #expect(graph.tracks["col0"]?.count == 3)
    #expect(graph.tracks["col1"]?.count == 2)

    let col0Bottom = graph.tracks["col0"]![0]
    let cursor = graph.site(col0Bottom)
    #expect(cursor.next != nil)
    #expect(cursor.next?.next != nil)
    #expect(cursor.next?.next?.next == nil)

    let col0Top = graph.tracks["col0"]![2]
    #expect(graph.site(col0Bottom).top?.id == col0Top)
    #expect(graph.site(col0Top).bottom?.id == col0Bottom)
  }

  @Test
  func testCrossTrackAdjacency() {
    let graph = SiteGraph.parallelTracks(
      names: ["allied", "road", "german"],
      length: 3,
      crossDirections: true
    )

    #expect(graph.tracks.count == 3)
    #expect(graph.tracks["allied"]?.count == 3)
    #expect(graph.tracks["road"]?.count == 3)
    #expect(graph.tracks["german"]?.count == 3)

    let alliedSite0 = graph.tracks["allied"]![0]
    let roadSite0 = graph.tracks["road"]![0]
    let germanSite0 = graph.tracks["german"]![0]

    #expect(graph.sites[alliedSite0]?.adjacency[.custom("road")] == roadSite0)
    #expect(graph.sites[alliedSite0]?.adjacency[.custom("german")] == germanSite0)
    #expect(graph.sites[germanSite0]?.adjacency[.custom("allied")] == alliedSite0)

    let alliedSite1 = graph.tracks["allied"]![1]
    #expect(graph.site(alliedSite0).next?.id == alliedSite1)
  }

  @Test
  func testSiteCursorCustomDirection() {
    let graph = SiteGraph.parallelTracks(
      names: ["allied", "road", "german"],
      length: 2,
      crossDirections: true
    )
    let alliedSite0 = graph.tracks["allied"]![0]
    let germanSite0 = graph.tracks["german"]![0]

    let cursor = graph.site(alliedSite0)
    #expect(cursor.adjacent(.custom("german"))?.id == germanSite0)

    let germanSite1 = graph.tracks["german"]![1]
    #expect(cursor.adjacent(.custom("german"))?.next?.id == germanSite1)
  }

  @Test
  func testPieceAndPieceValue() {
    let token = GamePiece(id: 0, kind: .token)
    let die = GamePiece(id: 1, kind: .die(sides: 6))

    let site0 = SiteID(0)
    let site1 = SiteID(1)

    var section: GameSection = [:]
    section[token] = .at(site0)
    section[die] = .dieShowing(face: 4, at: site1)

    #expect(section[token] == .at(site0))
    #expect(section[die] == .dieShowing(face: 4, at: site1))
    #expect(section[token]?.site == site0)
    #expect(section[die]?.site == site1)
  }

  @Test
  func testSectionPiecesAt() {
    let piece0 = GamePiece(id: 0, kind: .token, owner: PlayerID(0))
    let piece1 = GamePiece(id: 1, kind: .token, owner: PlayerID(1))
    let piece2 = GamePiece(id: 2, kind: .die(sides: 6), owner: PlayerID(0))
    let site0 = SiteID(0)
    let site1 = SiteID(1)

    let section: GameSection = [
      piece0: .at(site0),
      piece1: .at(site0),
      piece2: .dieShowing(face: 3, at: site1)
    ]

    #expect(section.piecesAt(site0).count == 2)
    #expect(section.piecesAt(site1).count == 1)
    #expect(section.piecesAt(SiteID(99)).isEmpty)
    #expect(section.pieceAt(site1) == piece2)
  }

  @Test
  func testGraphAwareSectionQuery() {
    // Simulate BattleCard: 2-city board with allied/german tracks
    let graph = SiteGraph.parallelTracks(
      names: ["allied", "german"],
      length: 2,
      crossDirections: true
    )
    let alliedSite0 = graph.tracks["allied"]![0]
    let germanSite0 = graph.tracks["german"]![0]

    let ally = GamePiece(id: 0, kind: .die(sides: 6), owner: PlayerID(0))
    let german = GamePiece(id: 1, kind: .die(sides: 6), owner: PlayerID(1))

    let section: GameSection = [
      ally: .dieShowing(face: 5, at: alliedSite0),
      german: .dieShowing(face: 2, at: germanSite0)
    ]

    // Find piece across the custom direction from ally's site
    let oppositeSite = graph.site(alliedSite0).adjacent(.custom("german"))!.id
    let opponent = section.pieceAt(oppositeSite)
    #expect(opponent == german)
  }

  @Test
  func testAddTrackWithTags() {
    var graph = SiteGraph()
    let s0 = graph.addSite(position: CGPoint(x: 0, y: 0))
    let s1 = graph.addSite(position: CGPoint(x: 1, y: 0))
    graph.addTrack("east", sites: [s0, s1], tags: ["trackBg", "dropShadow"])

    #expect(graph.tracks["east"]?.count == 2)
    #expect(graph.trackTags["east"] == ["trackBg", "dropShadow"])
  }

  @Test
  func testAddTrackWithoutTags() {
    var graph = SiteGraph()
    let s0 = graph.addSite(position: CGPoint(x: 0, y: 0))
    graph.addTrack("time", sites: [s0])

    #expect(graph.tracks["time"]?.count == 1)
    #expect(graph.trackTags["time"] == nil)
  }

  @Test
  func testSceneConfigCodable() throws {
    let config: SceneConfig = .container("cantstop", [
      .board(.columnar(heights: [3, 5, 7]), style: StyleConfig(stroke: "black")),
      .container("dice", [.die(.labeledSquare)]),
      .piece(.circle, color: .byPlayer, stacking: .fan)
    ])

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(SceneConfig.self, from: data)
    #expect(decoded == config)
  }

  @Test @MainActor
  func testGameModelBasic() {
    let graph = SiteGraph.columnar(heights: [3])
    let game = TrivialGame()
    let model = GameModel(game: game, graph: graph)

    #expect(!model.state.ended)
    #expect(model.allowedActions.count == 1)

    model.perform(.step)
    #expect(model.state.stepCount == 1)

    model.perform(.step)
    model.perform(.step)
    #expect(model.state.ended)
    #expect(model.allowedActions.isEmpty)
  }
}

// MARK: - SiteAppearance Tests

struct SiteAppearanceTests {
  @Test
  func testEmptyTagsReturnsEmptyAppearance() {
    let appearances: [String: SiteAppearance] = [
      "crown": SiteAppearance(fill: "yellow")
    ]
    let resolved = SiteAppearance.resolve(tags: [], from: appearances)
    #expect(resolved.fill == nil)
    #expect(resolved.shape == nil)
  }

  @Test
  func testSingleTagResolution() {
    let appearances: [String: SiteAppearance] = [
      "crown": SiteAppearance(fill: "yellow", lineWidth: 2)
    ]
    let resolved = SiteAppearance.resolve(tags: ["crown"], from: appearances)
    #expect(resolved.fill == "yellow")
    #expect(resolved.lineWidth == 2)
    #expect(resolved.stroke == nil)
  }

  @Test
  func testUnknownTagIgnored() {
    let appearances: [String: SiteAppearance] = [
      "crown": SiteAppearance(fill: "yellow")
    ]
    let resolved = SiteAppearance.resolve(tags: ["unknown"], from: appearances)
    #expect(resolved.fill == nil)
  }

  @Test
  func testMultipleTagsCompose() {
    let appearances: [String: SiteAppearance] = [
      "base": SiteAppearance(fill: "gray", stroke: "black"),
      "highlight": SiteAppearance(fill: "yellow")
    ]
    // "base" < "highlight" alphabetically, so highlight's fill wins
    let resolved = SiteAppearance.resolve(tags: ["base", "highlight"], from: appearances)
    #expect(resolved.fill == "yellow")
    #expect(resolved.stroke == "black")
  }

  @Test
  func testLabelStyleMergesFieldByField() {
    let appearances: [String: SiteAppearance] = [
      "a": SiteAppearance(labelStyle: LabelAppearance(size: 0.4, weight: .bold)),
      "b": SiteAppearance(labelStyle: LabelAppearance(color: "red"))
    ]
    let resolved = SiteAppearance.resolve(tags: ["a", "b"], from: appearances)
    #expect(resolved.labelStyle?.size == 0.4)
    #expect(resolved.labelStyle?.weight == .bold)
    #expect(resolved.labelStyle?.color == "red")
  }

  @Test
  func testDefaultAppearancesReplicateExistingBehavior() {
    let defaults = SiteAppearance.defaultAppearances
    let header = SiteAppearance.resolve(tags: ["header"], from: defaults)
    #expect(header.shape == .label)
    #expect(header.labelStyle?.weight == .bold)

    let invisible = SiteAppearance.resolve(tags: ["invisible"], from: defaults)
    #expect(invisible.shape == .none)

    let crown = SiteAppearance.resolve(tags: ["crown"], from: defaults)
    #expect(crown.fill == "yellow")
    #expect(crown.lineWidth == 2)
    #expect(crown.labelStyle?.alignment == .center)
  }
}
