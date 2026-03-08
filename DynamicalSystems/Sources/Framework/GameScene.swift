//
//  GameScene.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import SpriteKit

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

        for siteID in model.graph.sites.keys.sorted(by: { $0.raw < $1.raw }) {
            guard let site = model.graph.sites[siteID] else { continue }
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
        }
    }

    // MARK: - Piece node creation

    func makePieceNode(for piece: GamePiece) -> SKNode {
        switch piece.kind {
        case .token:
            let node = SKShapeNode(circleOfRadius: cellSize / 2.5)
            node.fillColor = colorForOwner(piece.owner)
            node.name = "piece_\(piece.id)"
            return node
        case .die:
            let node = makeDieNode()
            node.name = "die_\(piece.id)"
            return node
        case .card:
            let node = SKShapeNode(rectOf: CGSize(
                width: cellSize * 0.8,
                height: cellSize * 1.2
            ))
            node.fillColor = .white
            node.strokeColor = .black
            node.name = "card_\(piece.id)"
            return node
        }
    }

    private func makeDieNode() -> SKNode {
        let size = cellSize * 0.8
        let node = SKShapeNode(
            rect: CGRect(x: -size / 2, y: -size / 2, width: size, height: size),
            cornerRadius: size * 0.15
        )
        node.fillColor = .lightGray
        node.strokeColor = .black
        let label = SKLabelNode(text: "")
        label.name = "dieLabel"
        label.fontColor = .black
        label.fontSize = size * 0.5
        label.fontName = "Helvetica-Bold"
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        node.addChild(label)
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

    // Synchronize all piece nodes with current game state.
    // Iterates the full section unconditionally, moving/updating all pieces via SKAction.
    // swiftlint:disable:next cyclomatic_complexity
    func syncState(pieces: [GamePiece], section: GameSection) {
        let animDuration: TimeInterval = 0.2

        for piece in pieces {
            // Ensure piece node exists
            if pieceNodes[piece.id] == nil {
                let node = makePieceNode(for: piece)
                self.addChild(node)
                pieceNodes[piece.id] = node
            }

            guard let node = pieceNodes[piece.id],
                  let value = section[piece] else { continue }

            switch value {
            case .at(let site):
                if let dest = siteNodes[site] {
                    let pos = CGPoint(
                        x: dest.position.x + cellSize / 2,
                        y: dest.position.y + cellSize / 2
                    )
                    node.run(SKAction.move(to: pos, duration: animDuration))
                }

            case .dieShowing(let face, let site):
                if let label = node.childNode(withName: "dieLabel") as? SKLabelNode {
                    label.text = face > 0 ? "\(face)" : ""
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

        // Hide pieces not in section (removed from play)
        for (id, node) in pieceNodes {
            let piece = pieces.first { $0.id == id }
            if let piece, section[piece] == nil {
                node.run(SKAction.fadeOut(withDuration: animDuration))
            }
        }
    }
}
