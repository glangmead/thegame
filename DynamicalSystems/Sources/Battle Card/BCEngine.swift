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
  typealias Piece = BattleCardComponents.Piece
  typealias Phase = BattleCardComponents.Phase
  typealias Advantage = BattleCardComponents.Advantage
  typealias Control = BattleCardComponents.Control

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
        state.germansToReinforce.map { Action.reinforceGermans($0) } + [Action.setPhase(Phase.advance)]
      }
    )
    
    let advanceRule = Rule(
      condition: { state in
        state.phase == Phase.advance && state.control[state.position[.thirtycorps]! + 1]! == .allies
      },
      actions: { state in
        var actions = [Action.sequence([Action.advance30Corps, Action.setPhase(Phase.reinforce1st)])]
        let corpsPos = state.position[.thirtycorps]!
        if let ally = state.allyIn(pos: corpsPos) {
          actions.append(Action.sequence([Action.advanceAllies(ally), Action.setPhase(Phase.reinforce1st)]))
        }
        return actions
      }
    )
    
    let checkWeather = Rule(
      condition: { $0.phase == Phase.reinforce1st },
      actions: { _ in [Action.roll1stAirborne] }
    )
    
    let reinforce1st = Rule(
      condition: { $0.phase == Phase.reinforce1st },
      actions: { state in
        if state.weatherJustCleared {
          [Action.sequence([Action.perform1stAirborneReinforcement, Action.advanceTurn])]
        } else {
          [Action.advanceTurn]
        }
      }
    )
    
    let loseRule = Rule(
      condition: { $0.turnNumber >= 7 },
      actions: { _ in [Action.declareLoss] }
    )
    
    let winRule = Rule(
      condition: { $0.position[.thirtycorps] == 5 },
      actions: { _ in [Action.claimVictory] }
    )

    return [
      initRule,
      airdropRule,
      battleRule,
      battlesOverRule,
      reinforceGermansRule,
      advanceRule,
      checkWeather,
      reinforce1st,
      loseRule,
      winRule
    ]
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
    case DSix.one, DSix.none:
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
    case DSix.five, DSix.six:
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
      state.position[.allied101st] = 1
      state.position[.germanEindhoven] = 1
      state.position[.allied82nd] = 2
      state.position[.germanGrave] = 2
      state.position[.germanNijmegen] = 3
      state.position[.allied1st] = 4
      state.position[.germanArnhem] = 4
      state.strength[.allied101st] = DSix.six
      state.strength[.allied82nd] = DSix.six
      state.strength[.allied1st] = DSix.five
      state.strength[.germanEindhoven] = DSix.two
      state.strength[.germanGrave] = DSix.two
      state.strength[.germanNijmegen] = DSix.one
      state.strength[.germanArnhem] = DSix.two
      state.control[1] = .germans
      state.control[2] = .germans
      state.control[3] = .germans
      state.control[4] = .germans
      state.weather = .fog
    case .setPhase(let phase):
      state.phase = phase
    case .airdrop(let ally):
      let roll = DSix.roll()
      let penalty = airdropPenalty(roll)
      state.strength[ally] = DSix.minus(state.strength[ally]!, penalty)
    case .rollForAttack(let army):
      let german = state.opponentFacing(piece: army)!
      let armyStrength = state.strength[army]!
      let germanStrength = state.strength[german]!
      var advantage = Advantage.tied
      if DSix.greater(armyStrength, germanStrength) {
        advantage = Advantage.allies
      } else if DSix.greater(germanStrength, armyStrength) {
        advantage = Advantage.germans
      }
      let roll = DSix.roll()
      let (allyHit, germanHit, alliedControl) = attackOutcome(roll: roll, advantage: advantage)
      state.strength[army]   = DSix.minus(state.strength[army]!,   allyHit)
      state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
      if alliedControl {
        state.control[state.position[army]!] = Control.allies
      }
    case .rollForDefend(let army):
      let german = state.opponentFacing(piece: army)!
      let armyStrength = state.strength[army]!
      let germanStrength = state.strength[german]!
      var advantage = Advantage.tied
      if DSix.greater(armyStrength, germanStrength) {
        advantage = Advantage.allies
      } else if DSix.greater(germanStrength, armyStrength) {
        advantage = Advantage.germans
      }
      let roll = DSix.roll()
      let (allyHit, germanHit) = defendOutcome(roll: roll, advantage: advantage)
      state.strength[army]   = DSix.minus(state.strength[army]!,   allyHit)
      state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
      if DSix.greater(state.strength[german]!, state.strength[army]!) {
        state.control[state.position[army]!] = Control.germans
      }
    case .reinforceGermans(let germanArmy):
      let city = state.position[germanArmy]!
      switch germanArmy {
      case .germanArnhem, .germanEindhoven, .germanGrave:
        state.strength[germanArmy]! = DSix.sum(state.strength[germanArmy]!, DSix.one)
      case .germanNijmegen:
        if state.control[4] == .germans {
          state.strength[germanArmy]! = DSix.sum(state.strength[germanArmy]!, DSix.one)
        }
      default:
        ()
      }
      switch state.opponentFacing(piece: germanArmy) {
      case .none:
        state.control[city] = Control.germans
      case .some(let ally):
        if DSix.greater(state.strength[germanArmy]!, state.strength[ally]!) {
          state.control[city] = Control.germans
        }
      }
    case .advanceAllies(let ally):
      let startingCity = state.position[ally]!
      let destCity = startingCity + 1
      // make the move
      state.position[ally]! = destCity
      if let destAlly = state.allyIn(pos: destCity) {
        // sum the strength
        state.strength[ally] = DSix.sum(state.strength[ally]!, state.strength[destAlly]!)
        // remove the piece we moved onto
        state.alliesToAttack.removeAll(where: {$0 == destAlly})
      }
    case .advance30Corps:
      state.position[.thirtycorps]! += 1
    case .roll1stAirborne:
      // if d6 leq turn number and if fog, increase strength of All1, set to clear
      if state.weather == .fog {
        if DSix.greater(DSix(rawValue: state.turnNumber)!, DSix.roll()) {
          state.weather = .clear
          state.weatherJustCleared = true
        }
      }
    case .perform1stAirborneReinforcement:
      state.weatherJustCleared = false
      state.strength[.allied1st] = DSix.sum(DSix.one, state.strength[.allied1st]!)
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
