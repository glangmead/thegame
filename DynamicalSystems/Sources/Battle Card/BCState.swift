//
//  BCState.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import Foundation

extension BattleCard: StatePredicates {
  typealias StatePredicate = (State) -> Bool

  struct State: Equatable, Sendable, GameState, CustomStringConvertible {
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
    var weatherCleared: Bool = false
    var ended: Bool = false
    var endedInVictoryFor = [Player]()
    var endedInDefeatFor = [Player]()
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
    var control: [TrackPos: BattleCardComponents.Control] = [:]
    var turnNumber = 1

    var alliesOnBoard = Piece.allies()
    var germansOnBoard = Piece.germans()

    var alliesToAirdrop = Piece.allies()

    var alliesToAttack = Piece.allies()
    var germansToReinforce = Piece.germans()

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
    
    var cityPastXXXCorps: TrackPos? {
      switch position[Piece.thirtycorps] {
      case .none:
        return nil
      case .some(let pos):
        switch pos {
        case .offBoard:
          return nil
        case .onTrack(let trackPos):
          if trackPos + 1 < BattleCardComponents().track.length {
            return trackPos + 1
          } else {
            return nil
          }
        }
      }
    }
    
    mutating func removePiece(_ piece: Piece) {
      germansToReinforce.removeAll(where: { $0 == piece })
      alliesToAttack.removeAll(where: { $0 == piece })
      alliesToAirdrop.removeAll(where: { $0 == piece })
      germansOnBoard.removeAll(where: {$0 == piece})
      alliesOnBoard.removeAll(where: {$0 == piece})
      position[piece] = Position.offBoard
      strength.removeValue(forKey: piece)
    }
    
    var description: String {
      let fog = weather == .fog ? "☁️" : "🌤️"
      var result = "\(turnNumber)\(fog): "
      let track = BattleCardComponents().track
      for cityIndex in (0..<track.length).reversed() {
        let city = Position.onTrack(cityIndex)
        var allyStrength = "0"
        if let ally = allyIn(pos: city) {
          allyStrength = "\(strength[ally]!.rawValue)"
        }
        var germanStrength = "0"
        if let german = germanIn(pos: city) {
          germanStrength = "\(strength[german]!.rawValue)"
        }
        let xxxCorps = piecesIn(city).contains(.thirtycorps) ? "X" : ""
        let control = control[cityIndex] == .allies ? "🇺🇸" : "🇩🇪"
        result.append("\(xxxCorps)\(allyStrength)\(germanStrength)\(control) ")
      }
      var ended = ""
      if endedInDefeatFor.isNonEmpty {
        ended = "❌"
      } else if endedInVictoryFor.isNonEmpty {
        ended = "✅"
      }
      result += ended
      return result
    }
  }
}
