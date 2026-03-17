//
//  LoDAutoRules.swift
//  DynamicalSystems
//
//  Legions of Darkness — AutoRules for cross-cutting game consequences.
//

import Foundation

extension LoD {

  /// All auto-rules for Legions of Darkness, in canonical firing order.
  ///
  /// 1. Bloody battle marker placement (non-tie)
  /// 2. Bloody battle gate tie
  /// 3. Quest penalty (Last Ditch Efforts)
  ///
  /// Rules #1 and #2 are mutually exclusive.
  static var autoRules: [AutoRule<State>] {
    [bloodyBattlePlacementRule, bloodyBattleGateTieRule, questPenaltyRule]
  }

  // MARK: - Bloody Battle Marker Placement

  static var bloodyBattlePlacementRule: AutoRule<State> {
    AutoRule(
      name: "bloodyBattlePlacement",
      when: { state in
        guard state.history.last == .advanceArmies else { return false }
        guard let card = state.currentCard,
              let bbTrack = card.bloodyBattle else { return false }
        guard state.bloodyBattleArmy == nil,
              state.pendingBloodyBattleChoices == nil else { return false }

        let slotsOnTrack = ArmySlot.allCases.filter {
          $0.track == bbTrack && state.armyPosition[$0] != nil
        }

        if bbTrack == .gate && slotsOnTrack.count == 2 {
          let pos1 = state.armyPosition[slotsOnTrack[0]]!
          let pos2 = state.armyPosition[slotsOnTrack[1]]!
          if pos1 == pos2 { return false }
        }

        return !slotsOnTrack.isEmpty
      },
      apply: { state in
        guard let card = state.currentCard,
              let bbTrack = card.bloodyBattle else { return [] }

        let slotsOnTrack = ArmySlot.allCases.filter {
          $0.track == bbTrack && state.armyPosition[$0] != nil
        }

        if bbTrack == .gate && slotsOnTrack.count == 2 {
          let pos1 = state.armyPosition[slotsOnTrack[0]]!
          let pos2 = state.armyPosition[slotsOnTrack[1]]!
          let closest = pos1 < pos2 ? slotsOnTrack[0] : slotsOnTrack[1]
          state.bloodyBattleArmy = closest
          return [Log(msg: "Bloody battle marker placed on \(closest)")]
        } else if let first = slotsOnTrack.first {
          state.bloodyBattleArmy = first
          return [Log(msg: "Bloody battle marker placed on \(first)")]
        }
        return []
      }
    )
  }

  // MARK: - Bloody Battle Gate Tie

  static var bloodyBattleGateTieRule: AutoRule<State> {
    AutoRule(
      name: "bloodyBattleGateTie",
      when: { state in
        guard state.history.last == .advanceArmies else { return false }
        guard let card = state.currentCard,
              card.bloodyBattle == .gate else { return false }
        guard state.bloodyBattleArmy == nil,
              state.pendingBloodyBattleChoices == nil else { return false }

        let slotsOnTrack = ArmySlot.allCases.filter {
          $0.track == .gate && state.armyPosition[$0] != nil
        }
        guard slotsOnTrack.count == 2 else { return false }

        let pos1 = state.armyPosition[slotsOnTrack[0]]!
        let pos2 = state.armyPosition[slotsOnTrack[1]]!
        return pos1 == pos2
      },
      apply: { state in
        let slotsOnTrack = ArmySlot.allCases.filter {
          $0.track == .gate && state.armyPosition[$0] != nil
        }
        state.pendingBloodyBattleChoices = slotsOnTrack
        state.phase = .army
        return [Log(msg: "Bloody battle: Gate armies tied — choose placement")]
      }
    )
  }

  // MARK: - Quest Penalty (Last Ditch Efforts)

  static var questPenaltyRule: AutoRule<State> {
    AutoRule(
      name: "questPenalty",
      when: { state in
        guard state.history.last == .performHousekeeping else { return false }
        guard !state.questPenaltyAppliedThisTurn else { return false }
        guard let card = state.currentCard, card.number == 10 else { return false }

        for action in state.history.dropLast().reversed() {
          switch action {
          case .drawCard:
            return true
          case .quest:
            return false
          default:
            continue
          }
        }
        return true
      },
      apply: { state in
        state.questPenaltyAppliedThisTurn = true
        state.questLastDitchPenalty()
        return [Log(msg: "Last Ditch Efforts penalty: quest not attempted")]
      }
    )
  }
}
