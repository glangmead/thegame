//
//  BCEngine.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import ComposableArchitecture
import Foundation

@Reducer
struct BattleCard: LookaheadReducer {
  enum Action: Hashable, Equatable, Sendable {
    case initialize
    case setPhase(Phase)
    case airdrop(Piece)
    case rollForAttack(Piece)
    case rollForDefend(Piece)
    case reinforceGermans(Piece)
    case advanceAllies(Piece)
    case advance30Corps
    case roll1stAirborne
    case perform1stAirborneReinforcement
    case advanceTurn
    case claimVictory
    case declareLoss
    case sequence([Action])
  }
  
  /// A Rule is a conditional action
  struct Rule {
    let condition: StatePredicate
    let actions: (State) -> [Action]
    
    func also(_ cond: @escaping StatePredicate) -> Rule {
      return Rule(
        condition: { self.condition($0) && cond($0) },
        actions: self.actions
      )
    }
  }
  
  static func rules() -> [Rule] {

    let initRule = Rule(
      condition: { $0.phase == .setup },
      actions: { _ in return [Action.sequence([.initialize, .setPhase(.airdrop)])] }
    )
    
    let airdropRule = Rule(
      condition: { $0.phase == .airdrop },
      actions: { state in
        return state.alliesToAirdrop.map { .airdrop($0) }
      }
    )
    
    let battleRule = Rule(
      condition: { $0.phase == .battle },
      actions: { state in
        return state.alliesToAttack.flatMap { [.rollForAttack($0), .rollForDefend($0)] }
      }
    )
    
    let battlesOverRule = Rule(
      condition: { $0.phase == .battle && $0.alliesToAttack.isEmpty },
      actions: { _ in [Action.setPhase(.reinforceGermans)] }
    )
    
    let reinforceGermansRule = Rule(
      condition: { $0.phase == .reinforceGermans },
      actions: { state in
        state.germansToReinforce.map { Action.reinforceGermans($0) }
      }
    )
    
    return [initRule, airdropRule, battleRule, battlesOverRule, reinforceGermansRule]
  }

  static func allowedActions(state: State) -> [Action] {
    if state.ended {
      return []
    }
    return rules().flatMap { rule in
      if rule.condition(state) {
        return rule.actions(state)
      } else {
        return [Action]()
      }
    }
  }
  
  static func airdropPenalty(_ roll: DSix) -> DSix {
    switch roll {
    case .one, .two:
      DSix.two
    case .three, .four:
      DSix.one
    default:
      DSix.none
    }
  }
  
  static func attackOutcome(roll: DSix, advantage: Advantage) -> (DSix, DSix, Bool) {
    switch roll {
    case DSix.one:
      switch advantage {
      case .allies:
        (DSix.one, DSix.none, false)
      case .germans:
        (DSix.three, DSix.none, false)
      case .tied:
        (DSix.two, DSix.none, false)
      }
    case DSix.two, DSix.three, DSix.four:
      switch advantage {
      case .allies:
        (DSix.one, DSix.one, true)
      case .germans:
        (DSix.two, DSix.one, false)
      case .tied:
        (DSix.one, DSix.one, false)
      }
    default:
      switch advantage {
      case .allies:
        (DSix.none, DSix.one, true)
      case .germans:
        (DSix.one, DSix.none, true) // fascinating, never noticed playing digitally
      case .tied:
        (DSix.one, DSix.one, true)
      }
    }
  }
  
  static func defendOutcome(roll: DSix, advantage: Advantage) -> (DSix, DSix) {
    switch roll {
    case DSix.one:
      switch advantage {
      case .allies:
        (DSix.one, DSix.one)
      case .germans:
        (DSix.two, DSix.none)
      case .tied:
        (DSix.one, DSix.none)
      }
    case DSix.two, DSix.three, DSix.four:
      switch advantage {
      case .allies:
        (DSix.none, DSix.none)
      case .germans:
        (DSix.one, DSix.none)
      case .tied:
        (DSix.one, DSix.one)
      }
    default:
      (DSix.none, DSix.none)
    }
  }
  
  static func reduce(state: inout State, action: Action) {
    switch action {
    case .initialize:
      state.player = .solo
      state.players = [.solo]
      state.ended = false
      state.facing[.allied101st] = .germanEindhoven
      state.facing[.germanEindhoven] = .allied101st
      state.facing[.allied82nd] = .germanGrave
      state.facing[.germanGrave] = .allied82nd
      state.facing[.allied1st] = .germanArnhem
      state.facing[.germanArnhem] = .allied1st
    case .setPhase(let phase):
      state.phase = phase
    case .airdrop(let ally):
      let roll = DSix.allFaces().randomElement()!
      let penalty = airdropPenalty(roll)
      state.strength[ally] = DSix.minus(state.strength[ally]!, penalty)
    case .rollForAttack(let army):
      let roll = DSix.allFaces().randomElement()!
//      let german = state.germanFacing(army)
//      let advantage = state.advantageFacing(army)
//      let (allyHit, germanHit, advantageAllies) = attackOutcome(roll: roll, advantage: advantage)
//      state.strength[army]   = DSix.minus(state.strength[army]!,   allyHit)
//      state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
//      if advantageAllies {
//        state.advantage[state.position[army]!] = Advantage.allies
//      }
    case .rollForDefend(let army):
      let roll = DSix.allFaces().randomElement()!
//      let german = state.germanFacing(army)
//      let advantage = state.advantageFacing(army)
//      let (allyHit, germanHit) = defendOutcome(roll: roll, advantage: advantage)
//      state.strength[army]   = DSix.minus(state.strength[army]!,   allyHit)
//      state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
    case .reinforceGermans(let germanArmy):
//      switch germanArmy {
//      case .germanArnhem, .germanEindhoven, .germanGrave:
//        state.strength[germanArmy]! = DSix.sum(state.strength[germanArmy]!, DSix.one)
//      case .germanNijmegen:
//        if state.advantage[.arnhem] == .germans {
//          state.strength[germanArmy]! = DSix.sum(state.strength[germanArmy]!, DSix.one)
//        }
//      default:
//        ()
//      }
      state.updateControl(germanArmy: germanArmy)
    case .advanceAllies(let ally):
      ()
    case .advance30Corps:
      ()
    case .roll1stAirborne:
      ()
    case .perform1stAirborneReinforcement:
      ()
    case .advanceTurn:
      state.turnNumber += 1
    case .claimVictory:
      state.ended = true
    case .declareLoss:
      state.ended = true
    case let .sequence(actions):
      for action in actions {
        reduce(state: &state, action: action)
      }
    }
  }

  var body: some Reducer<State, Action> {
    Reduce { st, act in
      BattleCard.reduce(state: &st, action: act)
      return .none
    }
  }
}
