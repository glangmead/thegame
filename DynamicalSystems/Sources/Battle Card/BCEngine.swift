//
//  BCEngine.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import ComposableArchitecture
import Foundation

/// Thoughts on this engine having a lot of code. It has a bunch of Perl scripts in it.
/// The opposite of that would be to have some higher-level ideas that it's making use of instead.
/// My intuition tells me that the Track and Board concepts from Ludii offer a clue. Come up
/// with a suite of typical patterns, and invoke those. Look at the attacking reducer:
///
/// case .rollForAttack(let army):
///   // properties of relevant pieces
///   let german = state.opponentFacing(piece: army)!
///   let armyStrength = state.strength[army]!
///   let germanStrength = state.strength[german]!
///
///   // ternary comparison
///   var advantage = Advantage.tied
///   if DSix.greater(armyStrength, germanStrength) {
///     advantage = Advantage.allies
///   } else if DSix.greater(germanStrength, armyStrength) {
///     advantage = Advantage.germans
///   }
///
///   let roll = DSix.roll()
///   let (allyHit, germanHit, alliedControl) = attackOutcome(roll: roll, advantage: advantage)
///   state.strength[army]   = DSix.minus(state.strength[army]!,   allyHit)
///   state.strength[german] = DSix.minus(state.strength[german]!, germanHit)
///   logs.append(Log(msg: "Attack roll was \(roll.rawValue): -\(allyHit.rawValue) to ally, -\(germanHit) to german."))
///   if alliedControl {
///     let city = state.position[army]!
///     logs.append(Log(msg: "Allies control \(BattleCardComponents().track.names[city])."))
///     state.control[city] = Control.allies
///   }
///   state.alliesToAttack.removeAll(where: {$0 == army})
///
/// It's gathering some data from the state (the opposing army, the two strength values)
/// It's deriving a ternary advantage value from the strengths
/// It's rolling a die
/// It's looking up the (advantage, die roll) pair in a table.
/// It's applying three consequences: lowering the two strengths, updating control of the city.
/// Lastly it's marking this piece as having moved.
///
/// Maybe a combat results table should itself query the state to get all the info it needs.
/// Maybe we can have an expression for the inputs and outputs.
///
/// Are some of these lines of code Effects of the Action?
/// In Ludii, a rule expresses a decision move, then Effects that happen after.
/// For me this would imply two kinds of Action: decision actions and effect actions.
/// All that would do, though, is to interrupt my spaghetti with "case sideEffectAction:," right?
/// Sure, but what if these were reusable actions across many games? That would make it "higher level."
/// 
/// I'm in need of automation around "do this thing once" (roll for weather) or "move these guys until they are all moved" (armies)
/// Is this a sub-reducer with its own actions? A "battle" reducer with battle actions? Maybe but that doesn't help.
/// I just need the idea of a state: there are 3 armies who have to either attack or defend. Then go to the next phase.
///
/// It's OK for the size of the spec to be the size of the rulebook. It's about making it easy to enter, and easy to get right.
/// It's fiddly to work through a list of 3 armies -- need a higher-level construct.
/// Is it an emitter of rules? A meta-rule?
///
/// Could the CRT be a thing that has bindings in it?
///
/// struct AttackCRT {
///   @Binding let germanStrength: DSix
///   @Binding let alliedStrength: DSix
///
///
/// }
///
/// Combat takes in state and two pieces. In this game there is also the choice to defend or attack.
/// The manual expresses this function as a table. The T in CRT.

@Reducer
struct BattleCard: LookaheadReducer {
  typealias Piece = BattleCardComponents.Piece
  typealias Phase = BattleCardComponents.Phase
  typealias Advantage = BattleCardComponents.Advantage
  typealias Control = BattleCardComponents.Control
  
  struct Log: Hashable, Equatable, Sendable {
    let msg: String
  }

  enum Action: Hashable, Equatable, Sendable {
    // to organize actions, we need to have effects
    // e.g. an action "generate decision actions for these 3 armies" that pushes that onto a stack?
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
    case addLog(String)
    case sequence([Action])
    
    var name: String {
      switch self {
      case .initialize:
        return "Init"
      case .addLog(let str):
        return "Logging msg '\(str)'"
      case .setPhase(let phase):
        return "Next phase: \(phase)"
      case .airdrop(let ally):
        return "Airdrop for \(ally)"
      case .rollForAttack(let ally):
        return "\(ally) attacking"
      case .rollForDefend(let ally):
        return "\(ally) defending"
      case .reinforceGermans(let german):
        return "Reinforcements: \(german)"
      case .advanceAllies(let ally):
        return "Advancing \(ally)"
      case .advance30Corps:
        return "Advancing XXX Corps"
      case .roll1stAirborne:
        return "Rolling for weather"
      case .perform1stAirborneReinforcement:
        return "Sunny! Reinforcing 1st Airborne"
      case .advanceTurn:
        return "Next turn"
      case .claimVictory:
        return "You win"
      case .declareLoss:
        return "You lose"
      case .sequence(let actions):
        let name = actions.compactMap { $0.name.isEmpty ? nil : $0.name }
          .joined(separator: "; ")
        return "\(name)"
      }
    }
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
        return state.alliesToAirdrop.reversed().map { .airdrop($0) }
      }
    )
    
    let endAirdropRule = Rule(
      condition: { $0.phase == .airdrop && $0.alliesToAirdrop.isEmpty },
      actions: { _ in return [Action.setPhase(.battle)] }
    )
    
    let battleRule = Rule(
      condition: { $0.phase == .battle },
      actions: { state in
        return state.alliesToAttack.reversed().flatMap { [.rollForAttack($0), .rollForDefend($0)] }
      }
    )
    
    let battlesOverRule = Rule(
      condition: { $0.phase == .battle && $0.alliesToAttack.isEmpty },
      actions: { _ in [Action.setPhase(.reinforceGermans)] }
    )
    
    let reinforceGermansRule = Rule(
      condition: { $0.phase == .reinforceGermans },
      actions: { state in
        state.germansToReinforce.reversed().map { Action.reinforceGermans($0) }
      }
    )

    let reinforcementOverRule = Rule(
      condition: { $0.phase == .reinforceGermans && $0.germansToReinforce.isEmpty },
      actions: { _ in [Action.setPhase(Phase.advance)] }
    )

    let advanceRule = Rule(
      condition: { state in
        state.phase == Phase.advance && state.control[state.position[.thirtycorps]! + 1]! == .allies
      },
      actions: { state in
        var actions = [Action.sequence([Action.advance30Corps, Action.setPhase(Phase.rollForWeather)])]
        let corpsPos = state.position[.thirtycorps]!
        if let ally = state.allyIn(pos: corpsPos) {
          actions.append(Action.sequence([Action.advanceAllies(ally), Action.setPhase(Phase.rollForWeather)]))
        }
        return actions
      }
    )
    
    let cantAdvanceRule = Rule(
      condition: { state in
        state.phase == Phase.advance && state.control[state.position[.thirtycorps]! + 1]! == .germans
      },
      actions: { _ in [Action.addLog("Can't advance into German control"), Action.setPhase(Phase.rollForWeather)] }
    )
    
    let checkWeather = Rule(
      condition: { $0.phase == Phase.rollForWeather },
      actions: { _ in [Action.sequence([Action.roll1stAirborne, Action.setPhase(.reinforce1st)])] }
    )
    
    let reinforce1st = Rule(
      condition: { $0.phase == Phase.reinforce1st },
      actions: { state in
        if state.weatherJustCleared {
          [Action.sequence([Action.perform1stAirborneReinforcement, Action.advanceTurn, Action.setPhase(.battle)])]
        } else {
          [Action.sequence([Action.advanceTurn, Action.setPhase(.battle)])]
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
      endAirdropRule,
      battleRule,
      battlesOverRule,
      reinforceGermansRule,
      reinforcementOverRule,
      advanceRule,
      cantAdvanceRule,
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
  
  // my reducer doesn't report back to the user what happened.
  // for example, after executing Airdrop for allied1st, I observed its strength go from 6 to 4
  // but I should have printed something like "roll 1: -2 strength!"
  // such I/O is obviously what they mean by Effect!
  static func reduce(state: inout State, action: Action) -> [Log] {
    var logs = [Log]()
    switch action {
    case .initialize:
      state.player = .solo
      state.players = [.solo]
      state.ended = false
      state.position[.thirtycorps] = 0
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
      logs.append(Log(msg: "Phase is now \(phase)"))
    case .airdrop(let ally):
      let roll = DSix.roll()
      let penalty = airdropPenalty(roll)
      state.strength[ally] = DSix.minus(state.strength[ally]!, penalty)
      state.alliesToAirdrop.removeAll(where: {$0 == ally})
      logs.append(Log(msg: "Airdrop roll was \(roll.rawValue): -\(penalty.rawValue) to strength"))
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
      logs.append(Log(msg: "Attack roll was \(roll.rawValue): -\(allyHit.rawValue) to ally, -\(germanHit) to german."))
      if alliedControl {
        let city = state.position[army]!
        logs.append(Log(msg: "Allies control \(BattleCardComponents().track.names[city])."))
        state.control[city] = Control.allies
      }
      state.alliesToAttack.removeAll(where: {$0 == army})
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
      logs.append(Log(msg: "Defend roll was \(roll.rawValue): -\(allyHit.rawValue) to ally, -\(germanHit) to german."))
      if DSix.greater(state.strength[german]!, state.strength[army]!) {
        let city = state.position[army]!
        state.control[city] = Control.germans
        logs.append(Log(msg: "Germans control \(BattleCardComponents().track.names[city])."))
      }
      state.alliesToAttack.removeAll(where: {$0 == army})
    case .reinforceGermans(let germanArmy):
      let city = state.position[germanArmy]!
      switch germanArmy {
      case .germanArnhem, .germanEindhoven, .germanGrave:
        state.strength[germanArmy]! = DSix.sum(state.strength[germanArmy]!, DSix.one)
        logs.append(Log(msg:"+1 to \(germanArmy.name)"))
      case .germanNijmegen:
        if state.control[4] == .germans {
          state.strength[germanArmy]! = DSix.sum(state.strength[germanArmy]!, DSix.one)
          logs.append(Log(msg:"+1 to \(germanArmy.name)"))
        } else {
          logs.append(Log(msg:"+0 to \(germanArmy.name) (Allies control Arnhem)"))
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
      state.germansToReinforce.removeAll(where: {$0 == germanArmy})
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
        logs.append(Log(msg:"Rolling to see if the fog clears."))
        if DSix.greater(DSix(rawValue: state.turnNumber)!, DSix.roll()) {
          logs.append(Log(msg:"Weather clear!"))
          state.weather = .clear
          state.weatherJustCleared = true
        }
      }
    case .perform1stAirborneReinforcement:
      state.weatherJustCleared = false
      logs.append(Log(msg:"Dropping reinforcements for 1st."))
      state.strength[.allied1st] = DSix.sum(DSix.one, state.strength[.allied1st]!)
    case .advanceTurn:
      logs.append(Log(msg:"Next turn."))
      state.turnNumber += 1
    case .claimVictory:
      state.ended = true
    case .declareLoss:
      state.ended = true
    case let .addLog(str):
      logs.append(Log(msg: str))
    case let .sequence(actions):
      logs.append(contentsOf: actions.flatMap { reduce(state: &state, action: $0)})
    }
    state.actionsTaken.append(action)
    state.loggedActions.append(contentsOf: logs)
    return logs
  }

  var body: some Reducer<State, Action> {
    Reduce { st, act in
      let _ = BattleCard.reduce(state: &st, action: act)
      return .none
    }
  }
}
