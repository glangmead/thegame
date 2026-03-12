//
//  GameScene.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import SpriteKit
import UIKit

extension SKLabelNode {
  func applySystemFont(
    size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor
  ) {
    let font = UIFont.systemFont(ofSize: size, weight: weight)
    attributedText = NSAttributedString(
      string: text ?? "",
      attributes: [.font: font, .foregroundColor: color])
  }

  func updateSystemText(_ newText: String) {
    guard let existing = attributedText, existing.length > 0 else {
      text = newText
      return
    }
    let attrs = existing.attributes(at: 0, effectiveRange: nil)
    attributedText = NSAttributedString(string: newText, attributes: attrs)
  }
}

class GameScene<
  State: GameState & CustomStringConvertible,
  Action: Hashable & Equatable & CustomStringConvertible
>: SKScene {
  let model: GameModel<State, Action>
  let config: SceneConfig
  let cellSize: CGFloat

  var siteNodes: [SiteID: SKNode] = [:]
  var pieceNodes: [Int: SKNode] = [:]  // keyed by GamePiece.id

  init(
    model: GameModel<State, Action>,
    config: SceneConfig,
    size: CGSize,
    cellSize: CGFloat = 30
  ) {
    self.model = model
    self.config = config
    self.cellSize = cellSize
    super.init(size: size)
    self.backgroundColor = .white
    buildScene(from: config, parent: self)
  }

  required init?(coder aDecoder: NSCoder) { nil }

  // MARK: - Build node tree from config

  @discardableResult
  private func buildScene(from config: SceneConfig, parent: SKNode) -> SKNode {
    switch config {
    case .container(let name, let children):
      let node = SKNode()
      node.name = name
      parent.addChild(node)
      for (index, child) in children.enumerated() {
        let childNode = buildScene(from: child, parent: node)
        childNode.zPosition = CGFloat(index)
      }
      return node

    case .board(_, let style):
      let boardNode = SKNode()
      boardNode.name = "board"
      parent.addChild(boardNode)
      buildBoardSites(style: style, parent: boardNode)
      return boardNode

    case .columnar, .grid:
      // Direct geometry cases are handled via board() wrapper
      return parent

    case .piece, .die, .card:
      // Component config is declarative — pieces are created during syncState
      return parent

    // swiftlint:disable:next identifier_name
    case .positioned(let inner, let x, let y):
      let wrapper = SKNode()
      wrapper.position = CGPoint(x: CGFloat(x), y: CGFloat(y))
      parent.addChild(wrapper)
      buildScene(from: inner, parent: wrapper)
      return wrapper

    case .scaled(let inner, let factor):
      let wrapper = SKNode()
      wrapper.setScale(CGFloat(factor))
      parent.addChild(wrapper)
      buildScene(from: inner, parent: wrapper)
      return wrapper
    }
  }

  /// Creates SKNodes for each site in the graph.
  private func buildBoardSites(style: StyleConfig?, parent: SKNode) {
    let strokeColor = colorFromString(style?.stroke) ?? .black
    let fillColor = colorFromString(style?.fill) ?? .clear
    let lineWidth = CGFloat(style?.lineWidth ?? 1)
    let fontSize = cellSize * 0.35

    for siteID in model.graph.sites.keys.sorted(by: { $0.raw < $1.raw }) {
      guard let site = model.graph.sites[siteID] else { continue }

      if site.tags.contains("header") {
        let labelNode = SKLabelNode(text: site.label ?? "")
        labelNode.applySystemFont(
          size: cellSize * 0.4, weight: .bold, color: .darkGray)
        labelNode.horizontalAlignmentMode = .left
        labelNode.verticalAlignmentMode = .center
        labelNode.position = CGPoint(
          x: site.position.x,
          y: site.position.y + cellSize / 2
        )
        labelNode.name = "header_\(siteID.raw)"
        parent.addChild(labelNode)
        siteNodes[siteID] = labelNode
        continue
      }

      let node = SKShapeNode(rect: CGRect(
        x: 0, y: 0,
        width: cellSize, height: cellSize
      ))
      node.strokeColor = strokeColor
      node.fillColor = fillColor
      node.lineWidth = lineWidth
      node.position = site.position
      node.name = siteID.description
      parent.addChild(node)
      siteNodes[siteID] = node

      if let label = site.label {
        let labelNode = SKLabelNode(text: label)
        labelNode.applySystemFont(
          size: fontSize, color: .darkGray)
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .top
        labelNode.position = CGPoint(x: cellSize / 2, y: cellSize - 2)
        labelNode.name = "siteLabel_\(siteID.raw)"
        node.addChild(labelNode)
      }
    }
  }

  // MARK: - Piece node creation

  func makePieceNode(for piece: GamePiece) -> SKNode {
    switch piece.kind {
    case .token:
      let radius = cellSize / 2.5
      let node = SKShapeNode(circleOfRadius: radius)
      node.fillColor = colorForOwner(piece.owner)
      node.name = "piece_\(piece.id)"
      if let label = piece.label {
        let labelNode = SKLabelNode(text: label)
        labelNode.applySystemFont(
          size: radius * 0.8, weight: .bold, color: .white)
        labelNode.horizontalAlignmentMode = .center
        labelNode.verticalAlignmentMode = .center
        labelNode.name = "pieceLabel"
        node.addChild(labelNode)
      }
      return node
    case .die:
      let node = makeDieNode(label: piece.label, owner: piece.owner)
      node.name = "die_\(piece.id)"
      return node
    case .card:
      let width = cellSize * 0.8
      let height = cellSize * 1.2
      let node = SKShapeNode(rectOf: CGSize(width: width, height: height))
      node.fillColor = .white
      node.strokeColor = .black
      node.name = "card_\(piece.id)"
      let label = SKLabelNode(text: "?")
      label.applySystemFont(size: width * 0.4, color: .black)
      label.horizontalAlignmentMode = .center
      label.verticalAlignmentMode = .center
      label.name = "cardLabel"
      node.addChild(label)
      return node
    }
  }

  private func makeDieNode(label pieceLabel: String?, owner: PlayerID?) -> SKNode {
    let size = cellSize * 0.8
    let node = SKShapeNode(
      rect: CGRect(x: -size / 2, y: -size / 2, width: size, height: size),
      cornerRadius: size * 0.15
    )
    node.fillColor = colorForOwner(owner)
    node.strokeColor = .black
    let faceLabel = SKLabelNode(text: "")
    faceLabel.name = "dieLabel"
    faceLabel.applySystemFont(
      size: size * 0.45, weight: .bold, color: .white)
    faceLabel.verticalAlignmentMode = .center
    faceLabel.horizontalAlignmentMode = .center
    faceLabel.position = CGPoint(x: 0, y: size * 0.05)
    node.addChild(faceLabel)
    if let pieceLabel {
      let nameLabel = SKLabelNode(text: pieceLabel)
      nameLabel.name = "pieceLabel"
      nameLabel.applySystemFont(
        size: size * 0.28, color: .white)
      nameLabel.verticalAlignmentMode = .top
      nameLabel.horizontalAlignmentMode = .center
      nameLabel.position = CGPoint(x: 0, y: -size * 0.15)
      node.addChild(nameLabel)
    }
    return node
  }

  private func colorForOwner(_ owner: PlayerID?) -> SKColor {
    guard let owner else { return .gray }
    let colors: [SKColor] = [.blue, .red, .yellow, .green, .orange, .purple]
    return colors[owner.raw % colors.count]
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func colorFromString(_ name: String?) -> SKColor? {
    guard let name else { return nil }
    switch name.lowercased() {
    case "black": return .black
    case "white": return .white
    case "red": return .red
    case "blue": return .blue
    case "green": return .green
    case "darkgreen": return SKColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 1.0)
    case "yellow": return .yellow
    case "gray", "grey": return .gray
    case "lightgray", "lightgrey": return .lightGray
    case "orange": return .orange
    case "purple": return .purple
    case "clear": return .clear
    default: return nil
    }
  }

  // MARK: - State sync

  func syncState(
    pieces: [GamePiece],
    section: GameSection,
    siteHighlights: [SiteID: SKColor] = [:]
  ) {
    updateSiteHighlights(siteHighlights)
    let sitePieces = buildSitePieceMap(pieces: pieces, section: section)
    syncPieces(pieces: pieces, section: section, sitePieces: sitePieces)
    hideMissingPieces(pieces: pieces, section: section)
  }
}
