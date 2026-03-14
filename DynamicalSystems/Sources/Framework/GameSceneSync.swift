//
//  GameSceneSync.swift
//  DynamicalSystems
//
//  GameScene state sync helpers.
//

import SpriteKit

extension GameScene {

  func convertToLocal(_ scenePos: CGPoint, for node: SKNode) -> CGPoint {
    guard let parent = node.parent, parent !== self else { return scenePos }
    return parent.convert(scenePos, from: self)
  }

  // MARK: - Sync Helpers

  func updateSiteHighlights(_ highlights: [SiteID: SKColor]) {
    let animDuration: TimeInterval = 0.2
    for (siteID, node) in siteNodes {
      if let shapeNode = node as? SKShapeNode {
        let target = highlights[siteID] ?? baseFillColors[siteID] ?? .clear
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
      case .cardState(_, _, _, _, let siteID): site = siteID
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
      let layout = pieceLayouts[piece.kind.layoutKey]
      let scale = layout?.scale ?? 1

      if pieceNodes[piece.id] == nil {
        let node = makePieceNode(for: piece)
        let parent = layout?.parent ?? self
        parent.addChild(node)
        pieceNodes[piece.id] = node
      }

      guard let node = pieceNodes[piece.id],
         let value = section[piece] else { continue }

      if node.alpha < 1 {
        node.run(SKAction.fadeIn(withDuration: animDuration))
      }

      switch value {
      case .at(let site):
        movePiece(node, id: piece.id, to: site,
                  sitePieces: sitePieces, duration: animDuration, scale: scale)

      case .dieShowing(let face, let site):
        if let sprite = node.childNode(withName: "dieFace") as? SKSpriteNode {
          let size = sprite.size.width
          if let tex = dieTexture(face: face, pointSize: size) {
            sprite.texture = tex
            sprite.isHidden = false
          } else {
            sprite.isHidden = true
          }
        }
        if let site {
          movePiece(node, id: piece.id, to: site,
                    sitePieces: sitePieces, duration: animDuration, scale: scale)
        }

      case .cardState(let name, let faceUp, let isRed, let rotation, let site):
        if let label = node.childNode(withName: "cardLabel") as? SKLabelNode {
          label.updateSystemText(faceUp ? name : "?")
          label.fontColor = faceUp && isRed ? .red : .black
        }
        node.zRotation = rotation
        if let site, let dest = siteNodes[site] {
          let spacing = (faceUp ? cellSize * 0.7 : cellSize * 0.25) * scale
          let group = sitePieces[site] ?? []
          let count = group.count
          let idx = group.firstIndex(of: piece.id) ?? 0
          let span = spacing * CGFloat(count - 1)
          let off: CGFloat = count > 1 ? CGFloat(idx) * spacing - span / 2 : 0
          let isVertical = abs(rotation).truncatingRemainder(dividingBy: .pi) > 0.1
          let scenePos = CGPoint(
            x: dest.position.x + cellSize / 2 + (isVertical ? 0 : off),
            y: dest.position.y + cellSize / 2 + (isVertical ? off : 0))
          node.run(SKAction.move(to: convertToLocal(scenePos, for: node), duration: animDuration))
        }
      }
    }
  }

  private func movePiece(
    _ node: SKNode, id pieceID: Int, to site: SiteID,
    sitePieces: [SiteID: [Int]], duration: TimeInterval, scale: CGFloat = 1
  ) {
    guard let dest = siteNodes[site] else { return }
    let offset = stackingOffset(pieceID: pieceID, at: site, sitePieces: sitePieces, scale: scale)
    let scenePos = CGPoint(
      x: dest.position.x + cellSize / 2 + offset.x,
      y: dest.position.y + cellSize / 2 + offset.y
    )
    node.run(SKAction.move(to: convertToLocal(scenePos, for: node), duration: duration))
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
    pieceID: Int, at site: SiteID, sitePieces: [SiteID: [Int]], scale: CGFloat = 1
  ) -> CGPoint {
    guard let group = sitePieces[site], group.count > 1,
       let index = group.firstIndex(of: pieceID) else {
      return .zero
    }
    let count = group.count
    let spacing = cellSize * 0.7 * scale
    let totalWidth = spacing * CGFloat(count - 1)
    let xOffset = CGFloat(index) * spacing - totalWidth / 2
    return CGPoint(x: xOffset, y: 0)
  }
}
