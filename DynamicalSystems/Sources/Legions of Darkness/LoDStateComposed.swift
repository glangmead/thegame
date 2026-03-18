//
//  LoDStateComposed.swift
//  DynamicalSystems
//
//  Legions of Darkness — Quest/spell dispatch, housekeeping, DRM helpers, and setup.
//

import Foundation

extension LoD.State {

  /// Check if the current card's quest has a penalty for not attempting (Last Ditch Efforts).
  /// Called during housekeeping. Returns true if penalty was applied.
  mutating func applyQuestPenaltyIfNeeded(history: [LoD.Action]) -> Bool {
    guard let card = currentCard, card.number == 15 else { return false }

    // Check if quest was attempted this turn (scan history backwards from housekeeping)
    for action in history.reversed() {
      switch action {
      case .drawCard:
        // Reached start of turn without finding quest attempt
        questLastDitchPenalty()
        return true
      case .quest:
        return false  // quest was attempted
      default:
        continue
      }
    }
    questLastDitchPenalty()
    return true
  }

  // MARK: - Housekeeping (rule 3.0 step 5)

  /// Perform housekeeping at the end of a turn.
  /// Advances time by the current card's time value, resets per-turn tracking,
  /// and checks for victory.
  mutating func performHousekeeping() {
    guard let card = currentCard else { return }

    // Advance time by the card's time value
    advanceTime(by: card.time)

    // Reset per-turn tracking
    resetTurnTracking()

    // Check victory (only matters on Final Twilight)
    checkVictory()
  }

  /// Reset per-turn tracking at the start of a new turn.
  mutating func resetTurnTracking() {
    bloodyBattlePaidThisTurn = false
    acidUsedThisTurn = false
    acidEligibleSlots = []
    paladinRerollUsed = false
    pendingDieRollAction = nil
    phaseBeforePaladinReact = nil
    firstDieRoll = nil
    inspireDRMActive = false
    eventAttackDRMBonus = 0
    noMeleeThisTurn = false
    woundedHeroesCannotAct = false
    snapshotActionBudget = nil
    bloodyBattleArmy = nil
    pendingBloodyBattleChoices = nil
    questPenaltyAppliedThisTurn = false
    questRewardPending = false
  }

  // MARK: - DRM Helpers (for RulePages)

  /// Compute attack-related DRM from a list of card DRM entries.
  /// Matches entries whose action is .attack, .melee (if melee), or .ranged (if ranged),
  /// and whose track is nil (applies to all) or matches the given slot's track.
  private func attackDRMFromCardEntries(
    _ entries: [LoD.CardDRM],
    slot: LoD.ArmySlot,
    attackType: AttackType
  ) -> Int {
    var drm = 0
    for entry in entries {
      let trackMatches = entry.track == nil || entry.track == slot.track
      guard trackMatches else { continue }
      switch entry.action {
      case .attack:
        drm += entry.value
      case .melee where attackType == .melee:
        drm += entry.value
      case .ranged where attackType == .ranged:
        drm += entry.value
      default:
        break
      }
    }
    return drm
  }

  /// Total DRM for an attack action, combining card DRMs, upgrades, event bonuses, and Inspire.
  func totalAttackDRM(slot: LoD.ArmySlot, attackType: AttackType) -> Int {
    var drm = 0
    if let card = currentCard {
      drm += attackDRMFromCardEntries(card.actionDRMs, slot: slot, attackType: attackType)
    }
    // Upgrade DRM (only for space 1)
    if armyPosition[slot] == 1 {
      drm += upgradeDRM(on: slot.track, attackType: attackType)
    }
    // Event attack bonus
    drm += eventAttackDRMBonus
    // Inspire bonus
    if inspireDRMActive { drm += 1 }
    return drm
  }

  /// Total DRM for a build action from card DRMs, Rogue bonus, and Inspire.
  func totalBuildDRM() -> Int {
    var drm = 0
    if let card = currentCard {
      for cardDRM in card.actionDRMs where cardDRM.action == .build {
        drm += cardDRM.value
      }
    }
    // Rogue adds +1 DRM to build rolls (rule 10.4)
    if heroLocation[.rogue] != nil && !heroDead.contains(.rogue) {
      drm += 1
    }
    if inspireDRMActive { drm += 1 }
    return drm
  }

  /// Total DRM for a chant action from card DRMs and Inspire.
  func totalChantDRM() -> Int {
    var drm = 0
    // Priests provide +1 DRM per priest
    drm += defenderValue(for: .priests)
    if let card = currentCard {
      for cardDRM in card.actionDRMs where cardDRM.action == .chant {
        drm += cardDRM.value
      }
    }
    if inspireDRMActive { drm += 1 }
    return drm
  }

  /// Total DRM for a rally heroic action from card DRMs, Paladin bonus, and Inspire.
  func totalRallyDRM() -> Int {
    var drm = 0
    if let card = currentCard {
      for cardDRM in card.heroicDRMs where cardDRM.action == .rally {
        drm += cardDRM.value
      }
    }
    // Paladin gives +1 to rally regardless of location (rule 10.2)
    if heroLocation[.paladin] != nil, !heroDead.contains(.paladin) {
      drm += 1
    }
    if inspireDRMActive { drm += 1 }
    return drm
  }

  /// Total DRM for a heroic attack, combining hero combat DRM, card heroicDRMs, and Inspire.
  func totalHeroicAttackDRM(hero: LoD.HeroType, slot: LoD.ArmySlot) -> Int {
    var drm = hero.combatDRM
    let attackType: AttackType = hero.isRangedCombatant ? .ranged : .melee
    if let card = currentCard {
      drm += attackDRMFromCardEntries(card.heroicDRMs, slot: slot, attackType: attackType)
    }
    if inspireDRMActive { drm += 1 }
    return drm
  }

  /// Total DRM for quest attempts. Ranger adds +1 (rule 10.3).
  func questDRM() -> Int {
    var drm = 0
    if heroLocation[.ranger] != nil && !heroDead.contains(.ranger) {
      drm += 1
    }
    return drm
  }

}
