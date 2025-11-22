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
    var name: String {
      "Battle Card: Market Garden"
    }
    var player: Player = .solo
    var players: [Player] = [.solo]
    var phase: Phase = .setup
    var ended: Bool = false
    var position: [Piece: Position] = [:]
    var strength: [Piece: DSix] = [:]
    var control: [Position: Control] = [:]
    var facing: [Piece: Piece] = [:]
    var turnNumber = 1
    // the set of allied armies can shrink
    var allies: [Piece] = [.allied101st, .allied82nd, .allied1st]
    var alliesToAttack: [Piece] = [.allied101st, .allied82nd, .allied1st]
    var alliesToAirdrop: [Piece] = [.allied101st, .allied82nd, .allied1st]
    var germansToReinforce: [Piece] = [.germanEindhoven, .germanGrave, .germanNijmegen, .germanArnhem]
    
    func battleData(_ ally: Piece) -> (strength: DSix, city: Position, german: Piece, germanStrength: DSix, control: Control, advantage: Advantage) {
      let city = position[ally]!
      let german = Piece.germanFacing(city)!
      let allyStrength = self.strength[ally]!
      let germanStrength = self.strength[german]!
      var advantage = Advantage.tied
      if allyStrength.rawValue > germanStrength.rawValue {
        advantage = .allies
      } else if germanStrength.rawValue > allyStrength.rawValue {
        advantage = .germans
      }
      return (
        strength: allyStrength,
        city: city,
        german: german,
        germanStrength: germanStrength,
        control: control[city]!,
        advantage: advantage
      )
    }
    
    func advanceData() -> (
      fromCity: Position,
      toCity: Position,
      toControl: Control,
      fromArmy: Piece?,
      fromStrength: DSix?,
      toArmy: Piece?,
      toStrength: DSix?
    ){
      let fromCity = position[.thirtycorps]!
      let toCity = fromCity.next()
      var fromStrength = DSix.none
      var toStrength = DSix.none
      let fromArmy = allies.first(where: {position[$0] == fromCity})
      if fromArmy != nil {
        fromStrength = strength[fromArmy!]!
      }
      let toArmy = allies.first(where: {position[$0] == toCity})
      if toArmy != nil {
        toStrength = strength[toArmy!]!
      }
      return (
        fromCity: fromCity, toCity: toCity, toControl: control[toCity]!,
        fromArmy: fromArmy, fromStrength: fromStrength, toArmy: toArmy,
        toStrength: toStrength
      )
    }
    
    mutating func updateControl(germanArmy: Piece) {
      let germanStrength = strength[germanArmy]!
      var facingStrength = DSix.none
      if let ally = facing[germanArmy] {
        facingStrength = strength[ally]!
      }
      if germanStrength.rawValue > facingStrength.rawValue {
        control[Piece.cityContaining(germanArmy)!] = .germans
      }
    }
  }
}
