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
///
/// SKSpriteNode from SF Symbols character: https://stackoverflow.com/questions/59886426/creating-an-skspritenode-from-the-sf-symbols-font-in-a-different-color

// this will observe a CantStopState and draw stuff accordingly
class CantStopScene: SKScene {
  @SharedReader var store: StoreOf<CantStop>
  
  var CELL: CGFloat {
    min(self.size.height, self.size.width) / 13.0
  }
  
  class DieNode: SKShapeNode {
    var labelNode: SKLabelNode
    var label: String {
      didSet {
        labelNode.text = label
      }
    }
    
    init(_ die: CantStop.Die, rect: CGRect) {
      labelNode = SKLabelNode(text: "")
      label = ""
      super.init()
      
      self.name = String(describing: die)
      self.path = UIBezierPath(rect: rect).cgPath
      self.fillColor = UIColor.lightGray
      labelNode.name = "label"
      self.addChild(labelNode)
      labelNode.position = CGPoint(x: rect.size.width / 2.0, y: 0)
      labelNode.fontColor = UIColor.black
      labelNode.fontSize = 24
      labelNode.fontName = UIFont.init(name: "Helvetica", size: 24)?.fontName
    }
    
    required init?(coder aDecoder: NSCoder) {
      // nope
      return nil
    }
  }
  
  // Map from components to SpriteKit
  var pieceNode: [CantStop.Piece:SKNode] = [:]
  var positionNode: [CantStop.Position:SKNode] = [:]
  var columnNode: [CantStop.Column:SKNode] = [:]
  var dieNode: [CantStop.Die:DieNode] = [:]
  
  init(store: SharedReader<StoreOf<CantStop>>, size: CGSize) {
    self._store = store
    super.init(size: size)

    let boardNode = SKNode()
    let whiteTrayNode = SKShapeNode(rect: CGRect(x: 0, y: 0, width: CELL, height: CELL))
    let placeholderTrayNode = SKShapeNode(rect: CGRect(x: 0, y: 0, width: CELL, height: CELL))
    let diceComponentsNode = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 4 * CELL, height: CELL))
    boardNode.addChild(whiteTrayNode)
    boardNode.addChild(placeholderTrayNode)
    boardNode.addChild(diceComponentsNode)
    whiteTrayNode.strokeColor = UIColor.red
    whiteTrayNode.lineWidth = 1
    placeholderTrayNode.strokeColor = UIColor.green
    placeholderTrayNode.lineWidth = 1
    diceComponentsNode.strokeColor = UIColor.blue
    diceComponentsNode.lineWidth = 1
    placeholderTrayNode.position = CGPoint(x: 1 * CELL, y: 8  * CELL)
    whiteTrayNode.position       = CGPoint(x: 1 * CELL, y: 9  * CELL)
    diceComponentsNode.position =  CGPoint(x: 1 * CELL, y: 10 * CELL)

    for col in CantStop.Column.allCases {

      if col == CantStop.Column.none {
        columnNode[col] = placeholderTrayNode
        positionNode[CantStop.Position.init(col: col, row: 0)] = placeholderTrayNode
      } else {
        let colNode = trayNode(x: col.rawValue + 2, y: -1, w: 1, h: 1 + CantStop.colHeights()[col]!, parent: boardNode)
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
        placeholderNode.position = CGPoint(x: 0.5 * CELL, y: 0.5 * CELL)
      }
      
    }
    
    for (index, die) in CantStop.Die.allCases.enumerated() {
      let aDieNode = DieNode(die, rect: CGRect(x: 0, y: 0, width: CELL, height: CELL))
      dieNode[die] = aDieNode
      diceComponentsNode.addChild(aDieNode)
      aDieNode.position = CGPoint(x: CGFloat(index) * CELL, y: 0)
    }
    
    for whitePiece in CantStop.WhitePiece.allCases {
      let whiteNode = whiteNode(whitePiece)
      pieceNode[.white(whitePiece)] = whiteNode
      whiteTrayNode.addChild(whiteNode)
    }
    
    self.backgroundColor = UIColor.white
    self.addChild(boardNode)
  }
  
  func trayNode(x: Int, y: Int, w: Int, h: Int, parent: SKNode) -> SKNode {
    let rect = CGRect(x: CGFloat(x) * CELL, y: CGFloat(y) * CELL, width: CGFloat(w) * CELL, height: CGFloat(h) * CELL)
    let node = SKShapeNode()
    parent.addChild(node)
    node.path = UIBezierPath(rect: CGRect(x: 0, y: 0, width: rect.width, height: rect.height)).cgPath
    node.strokeColor = UIColor.black
    node.lineWidth = 2
    node.position = CGPoint(x: CGFloat(x) * CELL, y: CGFloat(y) * CELL)
    return node
  }
  
  func whiteNode(_ whitePiece: CantStop.WhitePiece) -> SKNode {
    let node = SKShapeNode(circleOfRadius: CELL / 2.0)
    node.name = String(describing: whitePiece)
    node.fillColor = UIColor.gray
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
    nil
  }
  
  // helper to move a piece to a board position
  func actionThatPuts(node: SKNode!, on destination: SKNode!) -> SKAction {
    node.move(toParent: destination)
    return SKAction.move(to: CGPoint(x: 0.5 * CELL, y: 0.5 * CELL), duration: TimeInterval.zero)
  }

  override func didMove(to view: SKView) {
    observe { [weak self] in
      guard let self else { return }
      // move every component to its position
      for (piece, pos) in store.position {
        pieceNode[piece]!.run(actionThatPuts(node: pieceNode[piece], on: positionNode[pos]))
      }
      for (die, val) in store.dice {
        dieNode[die]!.label = val.rawValue > 0 ? "\(val.rawValue)" : ""
      }
    }
  }
}

