//
//  RenderingTests.swift
//  DynamicalSystems
//
//  Tests for GameScene track background rendering.
//

import CoreGraphics
import Foundation
import SpriteKit
import Testing
@testable import DynamicalSystems

// MARK: - Stub types for GameScene instantiation

private struct StubState: GameState, CustomStringConvertible {
  typealias Phase = Int
  typealias Piece = Int
  typealias PiecePosition = Int
  typealias Player = Int
  typealias Position = Int

  var name: String { "Stub" }
  var player: Int = 0
  var players: [Int] = [0]
  var ended: Bool = false
  var endedInVictoryFor: [Int] = []
  var endedInDefeatFor: [Int] = []
  var position: [Int: Int] = [:]
  var description: String { "stub" }
}

private enum StubAction: Hashable, CustomStringConvertible {
  case noop
  var description: String { "noop" }
}

private struct StubGame: PlayableGame {
  var gameName: String { "Stub" }
  func newState() -> StubState { StubState() }
  func allowedActions(state: StubState) -> [StubAction] { [.noop] }
  func reduce(into state: inout StubState, action: StubAction) -> [Log] { [] }
  func isTerminal(state: StubState) -> Bool { state.ended }
}

// MARK: - RenderingTests

struct RenderingTests {
  @MainActor
  private func makeStubScene() -> GameScene<StubState, StubAction> {
    var graph = SiteGraph()
    _ = graph.addSite(position: CGPoint(x: 0, y: 0))
    _ = graph.addSite(position: CGPoint(x: 30, y: 0))
    _ = graph.addSite(position: CGPoint(x: 60, y: 0))
    let game = StubGame()
    let model = GameModel(game: game, graph: graph)
    return GameScene(
      model: model,
      config: .container("test", [
        .board(.grid(rows: 1, cols: 3), style: nil),
        .piece(.circle, color: .byPlayer)
      ]),
      size: CGSize(width: 200, height: 200),
      cellSize: 30
    )
  }

  @Test @MainActor
  func testStackingOffsetFanReturnsHorizontalSpread() {
    let scene = makeStubScene()
    let sitePieces: [SiteID: [Int]] = [SiteID(0): [1, 2, 3]]
    // pieceID 1 is at index 0 (leftmost), so x-offset is negative and non-zero.
    let offset = scene.stackingOffset(
      pieceID: 1, at: SiteID(0), sitePieces: sitePieces, policy: .fan)
    #expect(offset.y == 0)
    #expect(offset.x != 0)
  }

  @Test @MainActor
  func testStackingOffsetVerticalReturnsYOffset() {
    let scene = makeStubScene()
    let sitePieces: [SiteID: [Int]] = [SiteID(0): [1, 2, 3]]
    let offset = scene.stackingOffset(
      pieceID: 2, at: SiteID(0), sitePieces: sitePieces, policy: .vertical)
    #expect(offset.x == 0)
    #expect(offset.y != 0)
  }

  @Test @MainActor
  func testStackingOffsetBadgeReturnsZero() {
    let scene = makeStubScene()
    let sitePieces: [SiteID: [Int]] = [SiteID(0): [1, 2, 3]]
    let offset = scene.stackingOffset(
      pieceID: 3, at: SiteID(0), sitePieces: sitePieces, policy: .badge)
    #expect(offset == .zero)
  }

  @Test @MainActor
  func testTrackBackgroundCreated() {
    // Build a graph with 3 sites in a row, registered as a tagged track.
    var graph = SiteGraph()
    let site0 = graph.addSite(position: CGPoint(x: 0, y: 0))
    let site1 = graph.addSite(position: CGPoint(x: 30, y: 0))
    let site2 = graph.addSite(position: CGPoint(x: 60, y: 0))
    graph.addTrack("east", sites: [site0, site1, site2], tags: ["trackBg"])

    // Merge trackBg appearance into the defaults.
    let appearances = SiteAppearance.defaultAppearances.merging([
      "trackBg": SiteAppearance(fill: "steelblue", cornerRadius: 6, padding: 4)
    ]) { _, new in new }

    let game = StubGame()
    let model = GameModel(game: game, graph: graph)
    let config: SceneConfig = .container("test", [
      .board(.grid(rows: 1, cols: 3), style: nil),
      .piece(.circle, color: .byPlayer)
    ])
    let scene = GameScene<StubState, StubAction>(
      model: model,
      config: config,
      size: CGSize(width: 200, height: 200),
      cellSize: 30,
      appearances: appearances
    )

    // The board node should contain a background node named "trackBg_east".
    let boardNode = scene.childNode(withName: "test")?.childNode(withName: "board")
    #expect(boardNode != nil)

    let bgNode = boardNode?.childNode(withName: "trackBg_east")
    #expect(bgNode != nil)

    // Must be an SKShapeNode with non-clear fill and zPosition == -1.
    let shape = bgNode as? SKShapeNode
    #expect(shape != nil)
    #expect(shape?.fillColor != .clear)
    #expect(shape?.zPosition == -1)
  }
}
