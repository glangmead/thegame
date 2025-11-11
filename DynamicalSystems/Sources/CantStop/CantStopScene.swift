//
//  CantStopScene.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 11/7/25.
//

import ComposableArchitecture
import Foundation
import SpriteKit

// enum Player -> SKLabelNode
// enum Phase -> SKLabelNode
// enum WhitePiece -> SKShapeNode
// enum Piece -> SKShapeNode
// enum Die -> SKShapeNode
// enum Column -> SKShapeNode
// colHeights(), columnTops()
// struct Position: a key for obtaining a node
// struct PiecePosition
// struct DieValue

// var position = [Piece: Position]()
// var dice = [Die: DSix]()
// var assignedDicePair: Column
// var player: Player
// var players: [Player] // which players are playing
// var ended = false

/// The mathematical paradigm of state is: it's a section of a bundle.
/// The fibers are the space -- that should be a bunch of positions here in the Scene.
/// The state is a function/dictionary from pieces into that space.
/// So when the state changes, we'll
///   - enumerate every piece
///   - create an SKAction to move it to its new position
///   - we won't know the old position without extra work, so let's deprioritize that
/// What about dice? rather than moving them around we could have a drawn die face and change its face.
///

/// SKNode.addChild
/// SKNode.enumerateChildNodes(withName: "//co_*")
/// SKAction.sequence
/// SKAction.playSoundFileNamed("foo.wav", waitForCompletion: false)
/// SKAudioNode for background music
/// SKLabelNode (and .text, .name, .font{Name,Color,Size}, .{horizontal,vertical}AlignmentMode, .zPosition, .position)
/// add an SKLabelNode as a child of something, to add text to it
/// use an enum called Layer: CGFloat that creates the z-order with semantic names

/// GameplayKit: GKComponent, GKState.
/// One subclasses GKState to create a new state, similarly with GKComponent.

// this will observe a CantStopState and draw stuff accordingly
class CantStopScene: SKScene {
  @SharedReader var state: CantStop.State
  
  var CELL: CGFloat {
    min(self.size.height, self.size.width) / 15.0
  }

  var pieceNode: [CantStop.Piece:SKNode] = [:]
  var positionNode: [CantStop.Position:SKNode] = [:]
  var columnNode: [CantStop.Column:SKNode] = [:]
  var dieNode: [CantStop.Die:SKNode] = [:]
  
  init(state: SharedReader<CantStop.State>, size: CGSize) {
    self._state = state
    super.init(size: size)

    let boardNode = SKNode()
    let whiteTrayNode = SKShapeNode(rectOf: CGSize(width: CELL, height: CELL))
    let placeholderTrayNode = SKShapeNode(rectOf: CGSize(width: CELL, height: CELL))
    let diceComponentsNode = SKShapeNode(rectOf: CGSize(width: CELL, height: 4 * CELL))
    boardNode.addChild(whiteTrayNode)
    boardNode.addChild(placeholderTrayNode)
    boardNode.addChild(diceComponentsNode)
    whiteTrayNode.position = CGPoint(x: 2 * CELL, y: 3 * CELL)
    placeholderTrayNode.position = CGPoint(x: 2 * CELL, y: 2 * CELL)
    diceComponentsNode.position = CGPoint(x: 2 * CELL, y: 4 * CELL)

    for col in CantStop.Column.allCases {

      if col == CantStop.Column.none {
        columnNode[col] = placeholderTrayNode
        positionNode[CantStop.Position.init(col: col, row: 0)] = placeholderTrayNode
      } else {
        let colNode = trayNode(x: col.rawValue + 3, y: 0, w: 1, h: 1 + CantStop.colHeights()[col]!, parent: boardNode)
        columnNode[col] = colNode
        for row in 0...CantStop.colHeights()[col]! {
          let posNode = trayNode(x: 0, y: row, w: 1, h: 1, parent: colNode)
          positionNode[CantStop.Position.init(col: col, row: row)] = posNode
        }
      }
      
      for player in CantStop.Player.allCases {
        let placeholderNode = placeholderNode(player: player, column: col)
        pieceNode[.placeholder(player, col)] = placeholderNode
        placeholderTrayNode.addChild(placeholderNode)
      }
      
    }
    
    for (index, die) in CantStop.Die.allCases.enumerated() {
      let aDieNode = dieNode(die)
      dieNode[die] = aDieNode
      diceComponentsNode.addChild(aDieNode)
      diceComponentsNode.position = CGPoint(x: 0, y: CGFloat(index) * CELL)
    }
    
    for whitePiece in CantStop.WhitePiece.allCases {
      let whiteNode = whiteNode(whitePiece)
      pieceNode[.white(whitePiece)] = whiteNode
      whiteTrayNode.addChild(whiteNode)
    }
    
    self.backgroundColor = UIColor.white
    self.addChild(boardNode)
    print("frame: \(self.size)")
  }
  
  func trayNode(x: Int, y: Int, w: Int, h: Int, parent: SKNode) -> SKNode {
    let rect = CGRect(x: CGFloat(x) * CELL, y: CGFloat(y) * CELL, width: CGFloat(w) * CELL, height: CGFloat(h) * CELL)
    let node = SKShapeNode()
    parent.addChild(node)
    node.path = UIBezierPath(rect: rect).cgPath
    node.strokeColor = UIColor.black
    node.lineWidth = 4
    node.position = CGPoint(x: x, y: y)
    return node
  }
  
  func whiteNode(_ whitePiece: CantStop.WhitePiece) -> SKNode {
    let node = SKShapeNode(circleOfRadius: CELL / 2.0)
    node.name = String(describing: whitePiece)
    node.fillColor = UIColor.white
    return node
  }
  
  func dieNode(_ die: CantStop.Die) -> SKNode {
    let rect = CGRect(x: 0, y: 0, width: CELL, height: CELL)
    let node = SKShapeNode()
    node.name = String(describing: die)
    node.path = UIBezierPath(rect: rect).cgPath
    node.fillColor = UIColor.gray
    let labelNode = SKLabelNode(text: "")
    labelNode.name = "label"
    node.addChild(labelNode)
    return node
  }
  
  func placeholderNode(player: CantStop.Player, column: CantStop.Column) -> SKNode {
    let node = SKShapeNode(circleOfRadius: CELL / 2.0)
    node.fillColor = switch player {
    case .player1:
      UIColor.blue
    case .player2:
      UIColor.red
    case .player3:
      UIColor.yellow
    case .player4:
      UIColor.green
    }
    return node
  }

  required init?(coder aDecoder: NSCoder) {
    // this will not let us observe the model being used in the app
    self._state = SharedReader(value: CantStop.State())
    super.init(coder: aDecoder)
  }
  
  // helper to move a piece to a board position
  func actionThatPuts(node: SKNode!, on destination: SKNode!) -> SKAction {
    node.move(toParent: destination)
    return SKAction.move(to: CGPoint.zero, duration: TimeInterval.zero)
  }

  override func didMove(to view: SKView) {
    observe { [weak self] in
      print("\(self!.state.whitePositions)")
      // move every component to its position
      for (piece, pos) in self!.state.position {
        self?.pieceNode[piece]!.run(self!.actionThatPuts(node: self?.pieceNode[piece], on: self?.positionNode[pos]))
      }
      for (die, val) in self!.state.dice {
        if let labelNode = self?.dieNode[die]!.childNode(withName: "label") as SKLabelNode? {
          
        }
      }
    }
  }
}

