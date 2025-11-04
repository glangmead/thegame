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
    typealias Player        = BattleCard.Player
    typealias Phase         = BattleCard.Phase
    typealias Piece         = BattleCard.Piece
    typealias Position      = BattleCard.Position
    typealias PiecePosition = BattleCard.PiecePosition
    var player: Player = .solo
    var players: [Player] = [.solo]
    var phase: Phase = .setup
    var ended: Bool = false
    var position: [Piece: Position] = [:]
    var strength: [Piece: DSix] = [:]
    var advantage: [Position: Advantage] = [:]
    var facing: [Piece: Piece] = [:]
    var turnNumber = 1
    // the set of allied armies can shrink
    var allies: [Piece] = [.allied101st, .allied82nd, .allied1st]
    var alliesToAttack: [Piece] = [.allied101st, .allied82nd, .allied1st]
    var alliesToAirdrop: [Piece] = [.allied101st, .allied82nd, .allied1st]
    var germansToReinforce: [Piece] = [.germanEindhoven, .germanGrave, .germanNijmegen, .germanArnhem]
    
    func germanFacing(_ army: Piece) -> Piece {
      Piece.germanFacing(position[army]!)!
    }
    func advantageFacing(_ army: Piece) -> Advantage {
      advantage[position[army]!]!
    }
    mutating func updateControl(germanArmy: Piece) {
      let germanStrength = strength[germanArmy]!
      var facingStrength = DSix.none
      if let ally = facing[germanArmy] {
        facingStrength = strength[ally]!
      }
      if germanStrength.rawValue > facingStrength.rawValue {
        advantage[Piece.cityContaining(germanArmy)!] = .germans
      }
    }
  }
}
