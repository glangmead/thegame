//
//  GameSceneSync.swift
//  DynamicalSystems
//
//  GameScene state sync helpers.
//

import SpriteKit

extension GameScene {

  // MARK: - Sync Helpers

  func updateSiteHighlights(_ highlights: [SiteID: SKColor]) {
    let animDuration: TimeInterval = 0.2
    for (siteID, node) in siteNodes {
      if let shapeNode = node as? SKShapeNode {
        let target = highlights[siteID] ?? .clear
        if shapeNode.fillColor != target {
          shapeNode.run(SKAction.customAction(withDuration: animDuration) { node, _ in
            (node as? SKShapeNode)?.fillColor = target
          })
        }
      }
    }
  }

  func buildSitePieceMap(
    pieces: [GamePiece],
    section: GameSection
  ) -> [SiteID: [Int]] {
    var sitePieces: [SiteID: [Int]] = [:]
    for piece in pieces {
      guard let value = section[piece] else { continue }
      let site: SiteID?
      switch value {
      case .at(let siteID): site = siteID
      case .dieShowing(_, let siteID): site = siteID
      case .cardState(_, _, let siteID): site = siteID
      }
      if let site {
        sitePieces[site, default: []].append(piece.id)
      }
    }
    return sitePieces
  }

  // swiftlint:disable:next cyclomatic_complexity
  func syncPieces(
    pieces: [GamePiece],
    section: GameSection,
    sitePieces: [SiteID: [Int]]
  ) {
    let animDuration: TimeInterval = 0.2

    for piece in pieces {
      if pieceNodes[piece.id] == nil {
        let node = makePieceNode(for: piece)
        self.addChild(node)
        pieceNodes[piece.id] = node
      }

      guard let node = pieceNodes[piece.id],
         let value = section[piece] else { continue }

      if node.alpha < 1 {
        node.run(SKAction.fadeIn(withDuration: animDuration))
      }

      switch value {
      case .at(let site):
        if let dest = siteNodes[site] {
          let offset = stackingOffset(
            pieceID: piece.id, at: site, sitePieces: sitePieces
          )
          let pos = CGPoint(
            x: dest.position.x + cellSize / 2 + offset.x,
            y: dest.position.y + cellSize / 2 + offset.y
          )
          node.run(SKAction.move(to: pos, duration: animDuration))
        }

      case .dieShowing(let face, let site):
        if let label = node.childNode(withName: "dieLabel") as? SKLabelNode {
          label.updateSystemText(face > 0 ? "\(face)" : "")
        }
        if let site, let dest = siteNodes[site] {
          let pos = CGPoint(
            x: dest.position.x + cellSize / 2,
            y: dest.position.y + cellSize / 2
          )
          node.run(SKAction.move(to: pos, duration: animDuration))
        }

      case .cardState(let name, let faceUp, let site):
        if let label = node.childNode(withName: "cardLabel") as? SKLabelNode {
          label.text = faceUp ? name : "?"
        }
        if let site, let dest = siteNodes[site] {
          let pos = CGPoint(
            x: dest.position.x + cellSize / 2,
            y: dest.position.y + cellSize / 2
          )
          node.run(SKAction.move(to: pos, duration: animDuration))
        }
      }
    }
  }

  func hideMissingPieces(pieces: [GamePiece], section: GameSection) {
    let animDuration: TimeInterval = 0.2
    for (pieceID, node) in pieceNodes {
      let piece = pieces.first { $0.id == pieceID }
      if let piece, section[piece] == nil {
        node.run(SKAction.fadeOut(withDuration: animDuration))
      }
    }
  }

  func stackingOffset(
    pieceID: Int, at site: SiteID, sitePieces: [SiteID: [Int]]
  ) -> CGPoint {
    guard let group = sitePieces[site], group.count > 1,
       let index = group.firstIndex(of: pieceID) else {
      return .zero
    }
    let count = group.count
    let spacing = cellSize * 0.3
    let totalWidth = spacing * CGFloat(count - 1)
    let xOffset = CGFloat(index) * spacing - totalWidth / 2
    return CGPoint(x: xOffset, y: 0)
  }
}
