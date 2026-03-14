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

extension FontWeight {
  var uiWeight: UIFont.Weight {
    switch self {
    case .regular: .regular
    case .bold: .bold
    case .semibold: .semibold
    case .light: .light
    case .medium: .medium
    case .heavy: .heavy
    }
  }
}

// swiftlint:disable:next type_body_length
class GameScene<
  State: GameState & CustomStringConvertible,
  Action: Hashable & Equatable & CustomStringConvertible
>: SKScene {
  let model: GameModel<State, Action>
  let config: SceneConfig
  let cellSize: CGFloat
  let appearances: [String: SiteAppearance]

  var siteNodes: [SiteID: SKNode] = [:]
  var pieceNodes: [Int: SKNode] = [:]  // keyed by GamePiece.id
  var baseFillColors: [SiteID: SKColor] = [:]

  struct PieceLayout {
    let parent: SKNode
    let scale: CGFloat
  }
  var pieceLayouts: [String: PieceLayout] = [:]

  init(
    model: GameModel<State, Action>,
    config: SceneConfig,
    size: CGSize,
    cellSize: CGFloat = 30,
    appearances: [String: SiteAppearance] = SiteAppearance.defaultAppearances
  ) {
    self.model = model
    self.config = config
    self.cellSize = cellSize
    self.appearances = appearances
    super.init(size: size)
    self.backgroundColor = .white
    buildScene(from: config, parent: self, accumulatedScale: 1)
  }

  required init?(coder aDecoder: NSCoder) { nil }

  // MARK: - Build node tree from config

  @discardableResult
  private func buildScene(
    from config: SceneConfig, parent: SKNode, accumulatedScale: CGFloat
  ) -> SKNode {
    switch config {
    case .container(let name, let children):
      let node = SKNode()
      node.name = name
      parent.addChild(node)
      for (index, child) in children.enumerated() {
        let childNode = buildScene(from: child, parent: node, accumulatedScale: accumulatedScale)
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
      return parent

    case .piece:
      pieceLayouts["token"] = PieceLayout(parent: parent, scale: accumulatedScale)
      return parent
    case .die:
      pieceLayouts["die"] = PieceLayout(parent: parent, scale: accumulatedScale)
      return parent
    case .card:
      pieceLayouts["card"] = PieceLayout(parent: parent, scale: accumulatedScale)
      return parent

    // swiftlint:disable:next identifier_name
    case .positioned(let inner, let x, let y):
      let wrapper = SKNode()
      wrapper.position = CGPoint(x: CGFloat(x), y: CGFloat(y))
      parent.addChild(wrapper)
      buildScene(from: inner, parent: wrapper, accumulatedScale: accumulatedScale)
      return wrapper

    case .scaled(let inner, let factor):
      let wrapper = SKNode()
      parent.addChild(wrapper)
      buildScene(
        from: inner, parent: wrapper,
        accumulatedScale: accumulatedScale * CGFloat(factor)
      )
      return wrapper
    }
  }

  // swiftlint:disable:next function_body_length
  private func buildBoardSites(style: StyleConfig?, parent: SKNode) {
    let defaultStroke = colorFromString(style?.stroke) ?? .black
    let defaultFill = colorFromString(style?.fill) ?? .clear
    let defaultLineWidth = CGFloat(style?.lineWidth ?? 1)

    for siteID in model.graph.sites.keys.sorted(by: { $0.raw < $1.raw }) {
      guard let site = model.graph.sites[siteID] else { continue }

      let resolved = SiteAppearance.resolve(tags: site.tags, from: appearances)
      let shape = resolved.shape ?? .rect

      switch shape {
      case .none:
        let node = SKNode()
        node.position = site.position
        node.name = siteID.description
        parent.addChild(node)
        siteNodes[siteID] = node

      case .label:
        let labelStyle = resolved.labelStyle
        let labelNode = SKLabelNode(text: site.label ?? "")
        labelNode.applySystemFont(
          size: cellSize * (labelStyle?.size ?? 0.4),
          weight: labelStyle?.weight?.uiWeight ?? .bold,
          color: colorFromString(labelStyle?.color) ?? .darkGray)
        labelNode.horizontalAlignmentMode = .left
        labelNode.verticalAlignmentMode = .center
        labelNode.position = CGPoint(
          x: site.position.x,
          y: site.position.y + cellSize / 2)
        labelNode.name = "header_\(siteID.raw)"
        parent.addChild(labelNode)
        siteNodes[siteID] = labelNode

      case .rect:
        let fill = colorFromString(resolved.fill) ?? defaultFill
        let stroke = colorFromString(resolved.stroke) ?? defaultStroke
        let lineWidth = resolved.lineWidth ?? defaultLineWidth
        let cornerRadius = resolved.cornerRadius ?? 0

        let node: SKShapeNode
        if cornerRadius > 0 {
          node = SKShapeNode(
            rect: CGRect(x: 0, y: 0, width: cellSize, height: cellSize),
            cornerRadius: cornerRadius)
        } else {
          node = SKShapeNode(
            rect: CGRect(x: 0, y: 0, width: cellSize, height: cellSize))
        }
        node.strokeColor = stroke
        node.fillColor = fill
        node.lineWidth = lineWidth
        node.position = site.position
        node.name = siteID.description
        parent.addChild(node)
        siteNodes[siteID] = node

        if fill != defaultFill {
          baseFillColors[siteID] = fill
        }

        // Shadow
        if let shadow = resolved.shadow {
          let shadowNode = SKShapeNode(
            rect: CGRect(x: 0, y: 0, width: cellSize, height: cellSize),
            cornerRadius: cornerRadius)
          shadowNode.fillColor = colorFromString(shadow.color) ?? .black
          shadowNode.strokeColor = .clear
          shadowNode.alpha = 0.3
          shadowNode.position = CGPoint(x: shadow.offset, y: -shadow.offset)
          shadowNode.zPosition = -1
          node.addChild(shadowNode)
        }

        // Site label
        if let label = site.label {
          let labelStyle = resolved.labelStyle
          let fontSize = cellSize * (labelStyle?.size ?? 0.35)
          let weight = labelStyle?.weight?.uiWeight ?? .regular
          let color = colorFromString(labelStyle?.color) ?? .darkGray
          let alignment = labelStyle?.alignment ?? .top
          let labelNode = SKLabelNode(text: label)
          labelNode.applySystemFont(size: fontSize, weight: weight, color: color)
          labelNode.horizontalAlignmentMode = .center
          labelNode.verticalAlignmentMode = alignment == .center ? .center : .top
          labelNode.position = alignment == .center
            ? CGPoint(x: cellSize / 2, y: cellSize / 2)
            : CGPoint(x: cellSize / 2, y: cellSize - 2)
          labelNode.name = "siteLabel_\(siteID.raw)"
          node.addChild(labelNode)
        }
      }
    }
  }

  // MARK: - Piece node creation

  func makePieceNode(for piece: GamePiece) -> SKNode {
    let scale = pieceLayouts[piece.kind.layoutKey]?.scale ?? 1

    switch piece.kind {
    case .token:
      let radius = cellSize / 2.5 * scale
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
      let node = makeDieNode(label: piece.label, owner: piece.owner, scale: scale)
      node.name = "die_\(piece.id)"
      return node
    case .card:
      let width = cellSize * 0.8 * scale
      let height = cellSize * 1.2 * scale
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

  private func makeDieNode(label pieceLabel: String?, owner: PlayerID?, scale: CGFloat = 1) -> SKNode {
    let size = cellSize * 0.8 * scale
    let node = SKNode()
    let sprite = SKSpriteNode()
    sprite.name = "dieFace"
    sprite.size = CGSize(width: size, height: size)
    node.addChild(sprite)
    if let pieceLabel {
      let nameLabel = SKLabelNode(text: pieceLabel)
      nameLabel.name = "pieceLabel"
      nameLabel.applySystemFont(size: size * 0.28, color: .darkGray)
      nameLabel.verticalAlignmentMode = .top
      nameLabel.horizontalAlignmentMode = .center
      nameLabel.position = CGPoint(x: 0, y: -size / 2 - 2)
      node.addChild(nameLabel)
    }
    return node
  }

  func dieTexture(face: Int, pointSize: CGFloat) -> SKTexture? {
    guard face >= 1 && face <= 6 else { return nil }
    let symbolName = "die.face.\(face)"
    let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    guard let image = UIImage(systemName: symbolName, withConfiguration: config) else {
      return nil
    }
    return SKTexture(image: image)
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
    case "darkgray", "darkgrey": return .darkGray
    case "steelblue":
      return SKColor(red: 0.27, green: 0.51, blue: 0.71, alpha: 1.0)
    case "burlywood":
      return SKColor(red: 0.87, green: 0.72, blue: 0.53, alpha: 1.0)
    case "saddlebrown":
      return SKColor(red: 0.55, green: 0.27, blue: 0.07, alpha: 1.0)
    case "orange": return .orange
    case "purple": return .purple
    case "clear": return .clear
    default:
      if name.hasPrefix("#"), name.count == 7,
         let hex = UInt32(name.dropFirst(), radix: 16) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        return SKColor(red: red, green: green, blue: blue, alpha: 1.0)
      }
      return nil
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
