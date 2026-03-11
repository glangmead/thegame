//
//  LoDStateComposed.swift
//  DynamicalSystems
//
//  Legions of Darkness — Quest/spell dispatch, housekeeping, DRM helpers, and setup.
//

import Foundation

extension LoD.State {

  // MARK: - Quest Reward Dispatch (for composed game)

  // Apply the reward for a successful quest on the current card.
  // Dispatches by card number to the appropriate quest reward method.
  // swiftlint:disable:next cyclomatic_complexity
  mutating func applyQuestReward(params: LoD.QuestRewardParams) -> [Log] {
    guard let card = currentCard, card.quest != nil else { return [] }
    var logs: [Log] = []

    switch card.number {
    case 3: // Forlorn Hope — advance time +1
      questForlornHope()
      logs.append(Log(msg: "Quest reward: Forlorn Hope — time +1"))

    case 2: // Scrolls of the Dead — draw a spell
      if let spell = params.chosenSpell {
        questScrollsOfDead(chosenSpell: spell)
        logs.append(Log(msg: "Quest reward: Scrolls of the Dead — learned \(spell)"))
      }

    case 5: // Search for the Manastones
      questManastones()
      logs.append(Log(msg: "Quest reward: Manastones — +1 arcane, +1 divine"))

    case 6: // Arrows of the Dead — gain Magic Bow
      questMagicBow()
      logs.append(Log(msg: "Quest reward: Magic Bow acquired"))

    case 7: // Put Forth the Call — +1 defender
      if let defender = params.chosenDefender {
        questPutForthCall(defender: defender)
        logs.append(Log(msg: "Quest reward: Put Forth the Call — +1 \(defender)"))
      }

    case 10: // Last Ditch Efforts — add hero
      if let hero = params.chosenHero {
        questLastDitchEfforts(hero: hero)
        logs.append(Log(msg: "Quest reward: Last Ditch Efforts — added \(hero)"))
      }

    case 12: // The Vorpal Blade — gain Magic Sword
      questVorpalBlade()
      logs.append(Log(msg: "Quest reward: Vorpal Blade acquired"))

    case 22: // Pillars of the Earth — retreat army 2 spaces
      if let slot = params.chosenSlot {
        questPillarsOfEarth(slot: slot)
        logs.append(Log(msg: "Quest reward: Pillars of the Earth — retreated \(slot)"))
      }

    case 25: // Save the Mirror of the Moon — +2 arcane
      questMirrorOfMoon()
      logs.append(Log(msg: "Quest reward: Mirror of the Moon — +2 arcane"))

    case 28: // Prophecy Revealed — reveal/discard day cards
      if let idx = params.discardIndex {
        questProphecyRevealed(discardIndex: idx)
        logs.append(Log(msg: "Quest reward: Prophecy Revealed"))
      }

    default:
      break
    }

    return logs
  }

  /// Check if the current card's quest has a penalty for not attempting (Last Ditch Efforts).
  /// Called during housekeeping. Returns true if penalty was applied.
  mutating func applyQuestPenaltyIfNeeded(history: [LoD.Action]) -> Bool {
    guard let card = currentCard, card.number == 10 else { return false }

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

  // MARK: - Spell Cast Dispatch (for composed game)

  // Apply a spell's effect via the composed game.
  // Returns logs describing what happened.
  // swiftlint:disable:next cyclomatic_complexity
  mutating func applySpellEffect(
    spell: LoD.SpellType,
    heroic: Bool,
    params: LoD.SpellCastParams
  ) -> [Log] {
    var logs: [Log] = []

    switch spell {
    case .fireball:
      if let slot = params.targetSlot, let dieRoll = params.dieRolls.first {
        let result = applyFireball(on: slot, dieRoll: dieRoll)
        logs.append(Log(msg: "Fireball on \(slot): \(result)"))
      }

    case .slow:
      if let slot = params.targetSlot {
        applySlow(on: slot, heroic: heroic)
        logs.append(Log(msg: "Slow on \(slot)\(heroic ? " (heroic)" : "")"))
      }

    case .chainLightning:
      chainLightningState = LoD.ChainLightningState(heroic: heroic)
      logs.append(Log(msg: "Chain Lightning: choose bolt targets one at a time"))

    case .fortune:
      let cards = fortunePeek()
      fortuneState = LoD.FortuneState(heroic: heroic, drawnCards: cards)
      logs.append(Log(msg: "Fortune: viewing \(cards.count) cards"))

    case .cureWounds:
      applyCureWounds(heroes: params.heroes)
      logs.append(Log(msg: "Cure Wounds: healed \(params.heroes)"))

    case .massHeal:
      applyMassHeal(defenders: params.defenders)
      logs.append(Log(msg: "Mass Heal: +1 \(params.defenders)"))

    case .divineWrath:
      let targets = zip(params.targetSlots, params.dieRolls).map { (slot: $0.0, dieRoll: $0.1) }
      let results = applyDivineWrath(targets: targets)
      for (index, result) in results.enumerated() {
        logs.append(Log(msg: "Divine Wrath attack \(index+1): \(result)"))
      }

    case .inspire:
      applyInspire(heroic: heroic)
      logs.append(Log(msg: "Inspire\(heroic ? " (heroic)" : ""): morale=\(morale), +1 DRM all rolls"))

    case .raiseDead:
      applyRaiseDead(gainDefenders: params.defenders, returnHero: params.returnHero)
      logs.append(Log(msg: "Raise Dead: defenders \(params.defenders), hero \(String(describing: params.returnHero))"))
    }

    return logs
  }

  // MARK: - Housekeeping (rule 3.0 step 5)

  /// Perform housekeeping at the end of a turn.
  /// Advances time by the current card's time value, resets per-turn tracking,
  /// and checks for victory.
  mutating func performHousekeeping() {
    guard let card = currentCard else { return }

    // Apply quest penalty if applicable (Last Ditch Efforts)
    _ = applyQuestPenaltyIfNeeded(history: history)

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
    paladinRerollUsed = false
    pendingDieRollAction = nil
    phaseBeforePaladinReact = nil
    inspireDRMActive = false
    eventAttackDRMBonus = 0
    noMeleeThisTurn = false
    woundedHeroesCannotAct = false
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
    // Paladin on a wall track gives +1 to rally (rule 10.2)
    if let paladinLoc = heroLocation[.paladin], !heroDead.contains(.paladin) {
      if case .onTrack(let track) = paladinLoc, track.isWall {
        drm += 1
      }
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
