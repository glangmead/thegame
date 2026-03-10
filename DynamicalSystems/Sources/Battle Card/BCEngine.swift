//
//  BCEngine.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

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
/// ✅It's deriving a ternary advantage value from the strengths
/// ✅It's rolling a die
/// ✅It's looking up the (advantage, die roll) pair in a table.
/// It's applying three consequences: lowering the two strengths, updating control of the city.
/// Lastly it's marking this piece as having moved.
/// 
///
/// Marking a piece as needing to move.
/// Marking it as moved.
///
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
/// I'm in need of automation around "do this thing once" (roll for
/// weather) or "move these guys until they are all moved" (armies)
/// Is this a sub-reducer with its own actions? A "battle" reducer with battle actions? Maybe but that doesn't help.
/// I just need the idea of a state: there are 3 armies who have to either attack or defend. Then go to the next phase.
///
/// It's OK for the size of the spec to be the size of the rulebook.
/// It's about making it easy to enter, and easy to get right.
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

struct BattleCard {
  typealias Position = BattleCardComponents.Position
  typealias Piece = BattleCardComponents.Piece
  typealias Phase = BattleCardComponents.Phase
  typealias Control = BattleCardComponents.Control

  enum Action: Hashable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
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
    case skipAdvance
    case skipReinforce1st
    case addLog(String)
    case sequence([Action])

    var name: String {
      description
    }

    var debugDescription: String {
      description
    }

    var description: String {
      switch self {
      case .initialize:
        return "Perform setup"
      case .addLog:
        return ""
      case .setPhase(let phase):
        return "Go to \(phase) phase"
      case .airdrop(let ally):
        return "Airdrop for \(ally)"
      case .rollForAttack(let ally):
        return "Attack with \(ally)"
      case .rollForDefend(let ally):
        return "Defend with \(ally)"
      case .reinforceGermans(let german):
        return "Reinforce \(german)"
      case .advanceAllies(let ally):
        return "Advance \(ally)"
      case .advance30Corps:
        return "Advance XXX Corps"
      case .roll1stAirborne:
        return "Roll for weather"
      case .perform1stAirborneReinforcement:
        return "Reinforce 1st Airborne"
      case .advanceTurn:
        return "Next turn"
      case .claimVictory:
        return "Declare victory!"
      case .declareLoss:
        return "Declare loss."
      case .skipAdvance:
        return "Can't advance"
      case .skipReinforce1st:
        return "Skip 1st reinforcement"
      case .sequence(let actions):
        let name = actions.compactMap { action in "\(action)" }
          .joined(separator: "; ")
        return "\(name)"
      }
    }
  }

  // swiftlint:disable:next large_tuple
  let attackCRT = TwoParamCRT<Trichotomy, DSix, (DSix, DSix, Bool)>(
    result: { advantage, roll in
      switch roll {
      case DSix.one, DSix.none:
        switch advantage {
        case .larger:
          (DSix.one, DSix.none, false)
        case .smaller:
          (DSix.three, DSix.none, false)
        case .equal:
          (DSix.two, DSix.none, false)
        }
      case DSix.two, DSix.three, DSix.four:
        switch advantage {
        case .larger:
          (DSix.one, DSix.one, true)
        case .smaller:
          (DSix.two, DSix.one, false)
        case .equal:
          (DSix.one, DSix.one, false)
        }
      case DSix.five, DSix.six:
        switch advantage {
        case .larger:
          (DSix.none, DSix.one, true)
        case .smaller:
          (DSix.one, DSix.none, true) // fascinating, never noticed playing digitally
        case .equal:
          (DSix.one, DSix.one, true)
        }
      }
    }
  )

  let defendCRT = TwoParamCRT<Trichotomy, DSix, (DSix, DSix)>(
    result: { advantage, roll in
      switch roll {
      case DSix.one:
        switch advantage {
        case .larger:
          (DSix.one, DSix.one)
        case .smaller:
          (DSix.two, DSix.none)
        case .equal:
          (DSix.one, DSix.none)
        }
      case DSix.two, DSix.three, DSix.four:
        switch advantage {
        case .larger:
          (DSix.none, DSix.none)
        case .smaller:
          (DSix.one, DSix.none)
        case .equal:
          (DSix.one, DSix.one)
        }
      default:
        (DSix.none, DSix.none)
      }
    }
  )

  func newState() -> State {
    State()
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

  func airdropPenalty(_ roll: DSix) -> DSix {
    switch roll {
    case .one, .two:
      DSix.two
    case .three, .four:
      DSix.one
    default:
      DSix.none
    }
  }
}
