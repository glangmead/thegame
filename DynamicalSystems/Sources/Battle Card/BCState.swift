//
//  BCState.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import Foundation

extension BattleCard: StatePredicates {
  typealias StatePredicate = (State) -> Bool

  struct State: Equatable, Sendable, GameState {
    typealias Player        = BattleCardComponents.Player
    typealias Phase         = BattleCardComponents.Phase
    typealias Piece         = BattleCardComponents.Piece
    typealias Position      = BattleCardComponents.Position
    typealias PiecePosition = BattleCardComponents.PiecePosition
    typealias Weather       = BattleCardComponents.Weather
    
    var name: String {
      "Battle Card: Market Garden"
    }

    var player: Player = .solo
    var players: [Player] = [.solo]
    var phase: Phase = .setup
    var weather: Weather = .fog
    var weatherJustCleared: Bool = false
    var ended: Bool = false
    var position: [Piece: Position] = [:]
    func piecesIn(_ pos: Position) -> [Piece] {
      var pieces: [Piece] = []
      for piece in Piece.allCases {
        if position[piece] == pos {
          pieces.append(piece)
        }
      }
      return pieces
    }

    var strength: [Piece: DSix] = [:]
    var control: [Position: BattleCardComponents.Control] = [:]
    var turnNumber = 1

    var alliesToAttack: [Piece] = Piece.allies()
    var alliesToAirdrop: [Piece] = Piece.allies()
    var germansToReinforce: [Piece] = Piece.germans()
    
    var actionsTaken = [Action]()
    var loggedActions = [Log]()
    
    func allyIn(pos: Position) -> Piece? {
      return piecesIn(pos).filter({ Piece.allies().contains($0) }).first
    }
    
    func germanIn(pos: Position) -> Piece? {
      return piecesIn(pos).filter({ Piece.germans().contains($0) }).first
    }
    
    func opponentFacing(piece: Piece) -> Piece? {
      if Piece.allies().contains(piece) || piece == .thirtycorps {
        return germanIn(pos: position[piece]!)
      } else {
        return allyIn(pos: position[piece]!)
      }
    }
    
    func asText() -> [[String]] {
      var text = [[String]]()
      let track = BattleCardComponents().track
      text.append(["Turn \(state.turnNumber)"])
      for city in (0..<track.length).reversed() {
        var cityText = [track.names[city]]
        
        var allyText = "none"
        var allyStrength = " "
        if let ally = allyIn(pos: city) {
          allyText = ally.name
          allyStrength = "\(strength[ally]!.rawValue)"
        }
        cityText.append(allyText)
        cityText.append(allyStrength)
        cityText.append(piecesIn(city).contains(.thirtycorps) ? "XXXCorps" : " ")
        var germanText = "none"
        var germanStrength = " "
        if let german = germanIn(pos: city) {
          germanText = "vs German"
          germanStrength = "\(strength[german]!.rawValue)"
        }
        cityText.append(germanText)
        cityText.append(germanStrength)
        cityText.append(control[city]?.rawValue ?? "")
        text.append(cityText)
      }
      return text
    }
  }
}
