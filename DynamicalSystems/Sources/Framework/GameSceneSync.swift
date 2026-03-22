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

  func syncPieces(
    pieces: [GamePiece],
    section: GameSection,
    sitePieces: [SiteID: [Int]]
  ) {
    let animDuration: TimeInterval = 0.2

    for piece in pieces {
      let layout = pieceLayouts[piece.kind.layoutKey]
      let scale = layout?.scale ?? 1

      ensurePieceNode(for: piece, layout: layout)

      guard let node = pieceNodes[piece.id],
         let value = section[piece] else { continue }

      syncDisplayValues(on: node, piece: piece)

      if node.alpha < 1 {
        node.run(SKAction.fadeIn(withDuration: animDuration))
      }

      let stacking = layout?.stacking ?? .fan

      switch value {
      case .at(let site):
        movePiece(node, id: piece.id, to: site,
                  sitePieces: sitePieces, duration: animDuration, scale: scale, policy: stacking)
        syncBadge(on: node, id: piece.id, site: site, stacking: stacking, sitePieces: sitePieces)

      case .dieShowing(let face, let site):
        syncDieFace(node: node, face: face)
        if let site {
          movePiece(node, id: piece.id, to: site,
                    sitePieces: sitePieces, duration: animDuration, scale: scale, policy: stacking)
          syncBadge(on: node, id: piece.id, site: site, stacking: stacking, sitePieces: sitePieces)
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

  private func syncDieFace(node: SKNode, face: Int) {
    guard let sprite = node.childNode(withName: "dieFace") as? SKSpriteNode else { return }
    let size = sprite.size.width
    if let tex = dieTexture(face: face, pointSize: size) {
      sprite.texture = tex
      sprite.isHidden = false
    } else {
      sprite.isHidden = true
    }
  }

  private func syncBadge(
    on node: SKNode, id pieceID: Int, site: SiteID,
    stacking: StackPolicy, sitePieces: [SiteID: [Int]]
  ) {
    if stacking == .badge, let group = sitePieces[site], group.count > 1 {
      let isLast = group.last == pieceID
      node.alpha = isLast ? 1 : 0
      if isLast {
        updateBadge(on: node, count: group.count)
      }
    } else {
      removeBadge(from: node)
    }
  }

  private func movePiece(
    _ node: SKNode, id pieceID: Int, to site: SiteID,
    sitePieces: [SiteID: [Int]], duration: TimeInterval,
    scale: CGFloat = 1, policy: StackPolicy = .fan
  ) {
    guard let dest = siteNodes[site] else { return }
    let offset = stackingOffset(
      pieceID: pieceID, at: site, sitePieces: sitePieces, scale: scale, policy: policy)
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
    pieceID: Int, at site: SiteID,
    sitePieces: [SiteID: [Int]],
    scale: CGFloat = 1,
    policy: StackPolicy = .fan
  ) -> CGPoint {
    guard let group = sitePieces[site], group.count > 1,
       let index = group.firstIndex(of: pieceID) else {
      return .zero
    }
    let count = group.count
    switch policy {
    case .fan:
      let spacing = cellSize * 0.7 * scale
      let totalWidth = spacing * CGFloat(count - 1)
      let xOffset = CGFloat(index) * spacing - totalWidth / 2
      return CGPoint(x: xOffset, y: 0)
    case .vertical:
      let spacing = cellSize * 0.3 * scale
      let yOffset = CGFloat(index) * spacing
      return CGPoint(x: 0, y: yOffset)
    case .badge:
      return .zero
    }
  }

  private func updateBadge(on node: SKNode, count: Int) {
    let badgeName = "stackBadge"
    if let existing = node.childNode(withName: badgeName) as? SKShapeNode {
      if let label = existing.childNode(withName: "badgeLabel") as? SKLabelNode {
        label.updateSystemText("\(count)")
      }
      return
    }
    let radius = cellSize * 0.15
    let badge = SKShapeNode(circleOfRadius: radius)
    badge.fillColor = .red
    badge.strokeColor = .white
    badge.lineWidth = 1
    badge.name = badgeName
    badge.position = CGPoint(x: radius * 2, y: radius * 2)
    badge.zPosition = 10

    let label = SKLabelNode(text: "\(count)")
    label.applySystemFont(size: radius * 1.2, weight: .bold, color: .white)
    label.horizontalAlignmentMode = .center
    label.verticalAlignmentMode = .center
    label.name = "badgeLabel"
    badge.addChild(label)
    node.addChild(badge)
  }

  private func removeBadge(from node: SKNode) {
    node.childNode(withName: "stackBadge")?.removeFromParent()
  }

  private func ensurePieceNode(
    for piece: GamePiece, layout: PieceLayout?
  ) {
    if pieceNodes[piece.id] == nil {
      let node = makePieceNode(for: piece)
      let parent = layout?.parent ?? self
      parent.addChild(node)
      pieceNodes[piece.id] = node
    }
  }

  private func syncDisplayValues(on node: SKNode, piece: GamePiece) {
    guard piece.kind == .token, !piece.displayValues.isEmpty else { return }
    for (key, value) in piece.displayValues {
      if let label = node.childNode(withName: ".//dv_\(key)") as? SKLabelNode {
        label.updateSystemText("\(value)")
      }
    }
  }
}
