//
//  LoDVassalScene.swift
//  DynamicalSystems
//
//  Legions of Darkness -- SpriteKit scene backed by Vassal board image.
//

import SpriteKit
import UIKit

// swiftlint:disable:next type_body_length
class LoDVassalScene: SKScene {
  private var siteNodes: [SiteID: SKNode] = [:]
  private var siteSizes: [SiteID: CGSize] = [:]
  private var pieceNodes: [Int: SKNode] = [:]
  private let imageWidth: CGFloat
  private let imageHeight: CGFloat
  private(set) var vassalGraph = SiteGraph()

  init(boardImage: UIImage, sites: LoDVassalAssetLoader.SitesFile) {
    self.imageWidth = CGFloat(sites.imageWidth)
    self.imageHeight = CGFloat(sites.imageHeight)
    super.init(size: CGSize(width: imageWidth, height: imageHeight))
    self.scaleMode = .aspectFit
    self.backgroundColor = .black

    let texture = SKTexture(image: boardImage)
    let background = SKSpriteNode(texture: texture, size: self.size)
    background.anchorPoint = .zero
    background.position = .zero
    background.zPosition = -1
    addChild(background)

    buildGraphAndAnchors(from: sites)
  }

  required init?(coder aDecoder: NSCoder) { nil }

  // MARK: - Group -> Track Key Mapping

  private static let groupToTrackKey: [String: String] = [
    "East Wall": "east",
    "West Wall": "west",
    "Gate": "gate",
    "Sky": "sky",
    "Terror": "terror",
    "Morale": "morale",
    "Fighters": "menAtArms",
    "Archers": "archers",
    "Priests": "priests",
    "Time": "time",
    "Spells": "spells"
  ]

  private static func trackKey(for entry: LoDVassalAssetLoader.SiteEntry) -> String? {
    if entry.group == "Energy" {
      return entry.id.hasPrefix("arcane") ? "arcane" : "divine"
    }
    return groupToTrackKey[entry.group]
  }

  private static func numericSuffix(of entryID: String) -> Int? {
    guard let range = entryID.range(of: "\\d+$", options: .regularExpression) else { return nil }
    return Int(entryID[range])
  }

  private static func sortKey(
    for entry: LoDVassalAssetLoader.SiteEntry, jsonIndex: Int
  ) -> Int {
    numericSuffix(of: entry.id) ?? jsonIndex
  }

  // MARK: - Graph Building

  private func buildGraphAndAnchors(from sites: LoDVassalAssetLoader.SitesFile) {
    var graph = SiteGraph()

    for entry in sites.sites where entry.siteID != nil {
      let pos = pixelToScene(entry)
      let siteID = SiteID(entry.siteID!)
      graph.addSite(id: siteID, position: pos)
      graph.sites[siteID]?.label = entry.label
      siteSizes[siteID] = CGSize(width: entry.width, height: entry.height)
    }

    let indexed = sites.sites.enumerated().map { ($0.offset, $0.element) }
    let trackEntries = indexed.filter { $0.1.siteID == nil }

    var trackGroups: [String: [(Int, LoDVassalAssetLoader.SiteEntry)]] = [:]
    for (jsonIdx, entry) in trackEntries {
      guard let key = Self.trackKey(for: entry) else { continue }
      trackGroups[key, default: []].append((jsonIdx, entry))
    }

    for (trackKey, entries) in trackGroups {
      let sorted = entries.sorted {
        Self.sortKey(for: $0.1, jsonIndex: $0.0)
          < Self.sortKey(for: $1.1, jsonIndex: $1.0)
      }
      var trackIDs: [SiteID] = []
      for (_, entry) in sorted {
        let pos = pixelToScene(entry)
        let siteID = graph.addSite(position: pos)
        graph.sites[siteID]?.label = entry.label
        siteSizes[siteID] = CGSize(width: entry.width, height: entry.height)
        trackIDs.append(siteID)
      }
      graph.tracks[trackKey] = trackIDs
    }

    for (siteID, site) in graph.sites {
      let node = SKNode()
      node.position = site.position
      node.name = "site_\(siteID.raw)"
      addChild(node)
      siteNodes[siteID] = node
    }

    self.vassalGraph = graph
  }

  private func pixelToScene(_ entry: LoDVassalAssetLoader.SiteEntry) -> CGPoint {
    CGPoint(
      x: CGFloat(entry.x) + CGFloat(entry.width) / 2,
      y: imageHeight - (CGFloat(entry.y) + CGFloat(entry.height) / 2)
    )
  }

  // MARK: - Piece Nodes

  private let defaultPieceSize = CGSize(width: 60, height: 60)

  /// Fit a piece into a bounding box, preserving its native aspect ratio.
  /// If the piece has no loaded image, returns a square fitting the box.
  private func fittedSize(
    for piece: GamePiece, in box: CGSize
  ) -> CGSize {
    guard let filename = LoDVassalAssetLoader.pieceImageNames[piece.id],
          let image = LoDVassalAssetLoader.loadImage(named: filename) else {
      let side = min(box.width, box.height)
      return CGSize(width: side, height: side)
    }
    let imgW = image.size.width
    let imgH = image.size.height
    guard imgW > 0, imgH > 0 else { return box }
    let scale = min(box.width / imgW, box.height / imgH)
    return CGSize(width: imgW * scale, height: imgH * scale)
  }

  /// When N pieces share a site, each gets 1/N of the site width.
  private func slottedBox(
    site: SiteID, count: Int
  ) -> CGSize {
    let full = siteSizes[site] ?? defaultPieceSize
    guard count > 1 else { return full }
    return CGSize(width: full.width / CGFloat(count), height: full.height)
  }

  func makePieceNode(for piece: GamePiece, size: CGSize) -> SKNode {
    if piece.kind == .card {
      return makeCardNode(for: piece, size: size)
    }
    if let filename = LoDVassalAssetLoader.pieceImageNames[piece.id],
       let image = LoDVassalAssetLoader.loadImage(named: filename) {
      let texture = SKTexture(image: image)
      let sprite = SKSpriteNode(texture: texture, size: size)
      let wrapper = SKNode()
      wrapper.name = "piece_\(piece.id)"
      wrapper.addChild(sprite)
      let isCircular = filename.hasSuffix(".png")
      addBorder(to: wrapper, size: size, circular: isCircular)
      addShadow(to: wrapper, size: size, circular: isCircular)
      return wrapper
    }
    return makeFallbackToken(for: piece, size: size)
  }

  private func makeFallbackToken(for piece: GamePiece, size: CGSize) -> SKNode {
    let radius = min(size.width, size.height) / 2
    let node = SKShapeNode(circleOfRadius: radius)
    node.fillColor = piece.owner?.raw == 1 ? .red : .blue
    node.strokeColor = .white
    node.lineWidth = 2
    node.name = "piece_\(piece.id)"
    if let label = piece.label {
      let labelNode = SKLabelNode(text: label)
      labelNode.applySystemFont(
        size: radius * 0.7, weight: .bold, color: .white)
      labelNode.verticalAlignmentMode = .center
      node.addChild(labelNode)
    }
    addShadow(to: node, size: size)
    return node
  }

  private func makeCardNode(for piece: GamePiece, size: CGSize) -> SKNode {
    let node = SKShapeNode(rectOf: size)
    node.fillColor = .white
    node.strokeColor = .black
    node.name = "card_\(piece.id)"
    let label = SKLabelNode(text: "?")
    label.applySystemFont(
      size: min(size.width, size.height) * 0.3, color: .black)
    label.verticalAlignmentMode = .center
    label.name = "cardLabel"
    node.addChild(label)
    addShadow(to: node, size: size)
    return node
  }

  private func addBorder(
    to node: SKNode, size: CGSize, circular: Bool = false
  ) {
    let border: SKShapeNode
    let inset: CGFloat = 1
    if circular {
      let radius = min(size.width, size.height) / 2 + inset
      border = SKShapeNode(circleOfRadius: radius)
    } else {
      let rect = CGRect(
        x: -size.width / 2 - inset,
        y: -size.height / 2 - inset,
        width: size.width + inset * 2,
        height: size.height + inset * 2)
      let corner = min(size.width, size.height) * 0.1
      border = SKShapeNode(rect: rect, cornerRadius: corner)
    }
    border.strokeColor = SKColor.black.withAlphaComponent(0.7)
    border.fillColor = .clear
    border.lineWidth = 2
    border.zPosition = 0.5
    node.addChild(border)
  }

  private func addShadow(
    to node: SKNode, size: CGSize, circular: Bool = false
  ) {
    let shadow: SKShapeNode
    if circular {
      let radius = min(size.width, size.height) / 2 * 0.9
      shadow = SKShapeNode(circleOfRadius: radius)
    } else {
      shadow = SKShapeNode(
        ellipseOf: CGSize(width: size.width * 0.9, height: size.height * 0.4))
    }
    shadow.fillColor = SKColor.black.withAlphaComponent(0.25)
    shadow.strokeColor = .clear
    shadow.position = CGPoint(x: 2, y: -3)
    shadow.zPosition = -0.5
    node.addChild(shadow)
  }

  // MARK: - State Sync

  func syncState(
    pieces: [GamePiece],
    section: GameSection,
    siteHighlights: [SiteID: SKColor] = [:]
  ) {
    let sitePieces = buildSitePieceMap(pieces: pieces, section: section)
    syncPieces(pieces: pieces, section: section, sitePieces: sitePieces)
    hideMissingPieces(pieces: pieces, section: section)
  }

  private func buildSitePieceMap(
    pieces: [GamePiece], section: GameSection
  ) -> [SiteID: [Int]] {
    var result: [SiteID: [Int]] = [:]
    for piece in pieces {
      guard let value = section[piece], let site = value.site else { continue }
      result[site, default: []].append(piece.id)
    }
    return result
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func syncPieces(
    pieces: [GamePiece],
    section: GameSection,
    sitePieces: [SiteID: [Int]]
  ) {
    let anim: TimeInterval = 0.2
    for piece in pieces {
      guard let value = section[piece] else { continue }
      let targetSite = value.site
      let count = targetSite.flatMap { sitePieces[$0]?.count } ?? 1
      let box = targetSite.map { slottedBox(site: $0, count: count) }
        ?? defaultPieceSize
      let targetSize = fittedSize(for: piece, in: box)

      if pieceNodes[piece.id] == nil {
        let node = makePieceNode(for: piece, size: targetSize)
        addChild(node)
        pieceNodes[piece.id] = node
      }
      guard let node = pieceNodes[piece.id] else { continue }
      if node.alpha < 1 { node.run(SKAction.fadeIn(withDuration: anim)) }
      resizePieceNode(node, to: targetSize, duration: anim)

      switch value {
      case .at(let site):
        if let dest = siteNodes[site] {
          let offset = tileOffset(
            pieceID: piece.id, at: site, sitePieces: sitePieces)
          let pos = CGPoint(
            x: dest.position.x + offset.x,
            y: dest.position.y + offset.y)
          node.run(SKAction.move(to: pos, duration: anim))
        }
      case .cardState(let name, let faceUp, _, _, let site):
        if let label = node.childNode(withName: "cardLabel") as? SKLabelNode {
          label.updateSystemText(faceUp ? name : "?")
        }
        if let site, let dest = siteNodes[site] {
          node.run(SKAction.move(to: dest.position, duration: anim))
        }
      case .dieShowing(_, let site):
        if let site, let dest = siteNodes[site] {
          node.run(SKAction.move(to: dest.position, duration: anim))
        }
      }
    }
  }

  private func resizePieceNode(
    _ node: SKNode, to size: CGSize, duration: TimeInterval
  ) {
    // Wrapper node containing a sprite child (image pieces with border)
    if let sprite = node.children.first(where: { $0 is SKSpriteNode }) as? SKSpriteNode {
      sprite.run(SKAction.resize(
        toWidth: size.width, height: size.height, duration: duration))
      return
    }
    if let sprite = node as? SKSpriteNode {
      sprite.run(SKAction.resize(
        toWidth: size.width, height: size.height, duration: duration))
    }
    if let shape = node as? SKShapeNode {
      let cur = shape.frame.size
      guard cur.width > 0, cur.height > 0 else { return }
      shape.run(SKAction.scaleX(
        to: size.width / cur.width,
        y: size.height / cur.height,
        duration: duration))
    }
  }

  private func hideMissingPieces(pieces: [GamePiece], section: GameSection) {
    for (pieceID, node) in pieceNodes {
      if let piece = pieces.first(where: { $0.id == pieceID }),
         section[piece] == nil {
        node.run(SKAction.fadeOut(withDuration: 0.2))
      }
    }
  }

  /// Tile pieces side-by-side within the site bounding box, no overlap.
  private func tileOffset(
    pieceID: Int, at site: SiteID, sitePieces: [SiteID: [Int]]
  ) -> CGPoint {
    guard let group = sitePieces[site], group.count > 1,
          let index = group.firstIndex(of: pieceID) else { return .zero }
    let siteWidth = siteSizes[site]?.width ?? defaultPieceSize.width
    let slotWidth = siteWidth / CGFloat(group.count)
    // Center of slot i, relative to site center
    let xOff = slotWidth * (CGFloat(index) + 0.5) - siteWidth / 2
    return CGPoint(x: xOff, y: 0)
  }
}
