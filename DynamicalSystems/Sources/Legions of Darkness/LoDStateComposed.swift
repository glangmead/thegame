//
//  LoDStateComposed.swift
//  DynamicalSystems
//
//  Legions of Darkness — Quest/spell dispatch, housekeeping, DRM helpers, and setup.
//

import Foundation

extension LoD.State {

  // MARK: - Quest Reward Dispatch (for composed game)

  /// Apply the reward for a successful quest on the current card.
  /// Dispatches by card number to the appropriate quest reward method.
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
      case .questAction, .questHeroic:
        return false  // quest was attempted
      default:
        continue
      }
    }
    questLastDitchPenalty()
    return true
  }

  // MARK: - Spell Cast Dispatch (for composed game)

  /// Apply a spell's effect via the composed game.
  /// Returns logs describing what happened.
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
      let targets = zip(params.targetSlots, params.dieRolls).map { (slot: $0.0, dieRoll: $0.1) }
      let results = applyChainLightning(targets: targets, heroic: heroic)
      for (index, result) in results.enumerated() {
        logs.append(Log(msg: "Chain Lightning bolt \(index+1): \(result)"))
      }

    case .fortune:
      applyFortune(newOrder: params.newOrder, discardIndex: params.discardIndex)
      logs.append(Log(msg: "Fortune applied"))

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
      applyInspire()
      logs.append(Log(msg: "Inspire: morale raised, +1 DRM all rolls"))

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
    paladinRerollUsed = false
    pendingDieRollAction = nil
    phaseBeforePaladinReact = nil
    inspireDRMActive = false
    eventAttackDRMBonus = 0
    noMeleeThisTurn = false
    woundedHeroesCannotAct = false
  }

  // MARK: - DRM Helpers (for RulePages)

  /// Total DRM for an attack action, combining card DRMs, upgrades, event bonuses, and Inspire.
  func totalAttackDRM(slot: LoD.ArmySlot, attackType: AttackType) -> Int {
    var drm = 0
    if let card = currentCard {
      for cardDRM in card.actionDRMs {
        switch cardDRM.action {
        case .attack:
          if cardDRM.track == nil || cardDRM.track == slot.track {
            drm += cardDRM.value
          }
        case .melee:
          if attackType == .melee && (cardDRM.track == nil || cardDRM.track == slot.track) {
            drm += cardDRM.value
          }
        case .ranged:
          if attackType == .ranged && (cardDRM.track == nil || cardDRM.track == slot.track) {
            drm += cardDRM.value
          }
        default: break
        }
      }
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
    drm += defenders[.priests] ?? 0
    if let card = currentCard {
      for cardDRM in card.actionDRMs where cardDRM.action == .chant {
        drm += cardDRM.value
      }
    }
    if inspireDRMActive { drm += 1 }
    return drm
  }

  /// Total DRM for a rally heroic action from card DRMs and Inspire.
  func totalRallyDRM() -> Int {
    var drm = 0
    if let card = currentCard {
      for cardDRM in card.heroicDRMs where cardDRM.action == .rally {
        drm += cardDRM.value
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
      for cardDRM in card.heroicDRMs {
        switch cardDRM.action {
        case .attack:
          if cardDRM.track == nil || cardDRM.track == slot.track {
            drm += cardDRM.value
          }
        case .melee:
          if attackType == .melee && (cardDRM.track == nil || cardDRM.track == slot.track) {
            drm += cardDRM.value
          }
        case .ranged:
          if attackType == .ranged && (cardDRM.track == nil || cardDRM.track == slot.track) {
            drm += cardDRM.value
          }
        default: break
        }
      }
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

  // MARK: - Shared Die-Roll Action Resolution

  /// Whether the given action is a die-roll action eligible for Paladin re-roll.
  static func isDieRollAction(_ action: LoD.Action) -> Bool {
    switch action {
    case .meleeAttack, .rangedAttack, .buildUpgrade, .chant, .questAction:
      return true
    case .heroicAttack, .rally, .questHeroic:
      return true
    default:
      return false
    }
  }

  /// Replace the die roll in a die-roll action with a new value.
  static func withNewDieRoll(_ action: LoD.Action, newDieRoll: Int) -> LoD.Action {
    switch action {
    case .meleeAttack(let slot, _, let bb, let ms):
      return .meleeAttack(slot, dieRoll: newDieRoll, bloodyBattleDefender: bb, useMagicSword: ms)
    case .rangedAttack(let slot, _, let bb, let mb):
      return .rangedAttack(slot, dieRoll: newDieRoll, bloodyBattleDefender: bb, useMagicBow: mb)
    case .buildUpgrade(let upgrade, let track, _):
      return .buildUpgrade(upgrade, track, dieRoll: newDieRoll)
    case .chant:
      return .chant(dieRoll: newDieRoll)
    case .questAction(_, let reward):
      return .questAction(dieRoll: newDieRoll, reward: reward)
    case .heroicAttack(let hero, let slot, _):
      return .heroicAttack(hero, slot, dieRoll: newDieRoll)
    case .rally:
      return .rally(dieRoll: newDieRoll)
    case .questHeroic(_, let reward):
      return .questHeroic(dieRoll: newDieRoll, reward: reward)
    default:
      return action
    }
  }

  /// Resolve an action-phase die-roll action. Returns logs.
  mutating func resolveActionDieRoll(_ action: LoD.Action) -> [Log] {
    var logs: [Log] = []
    switch action {
    case .meleeAttack(let slot, let dieRoll, let bloodyBattleDefender, let useMagicSword):
      if checkBloodyBattle(attacking: slot), let defender = bloodyBattleDefender {
        loseDefender(defender)
        logs.append(Log(msg: "Bloody battle cost: lost \(defender)"))
      }
      var drm = totalAttackDRM(slot: slot, attackType: .melee)
      if let timing = useMagicSword {
        let bonus = self.useMagicSword(timing: timing)
        drm += bonus
        logs.append(Log(msg: "Magic Sword used (\(timing)): +\(bonus) DRM"))
      }
      let result = resolveAttack(on: slot, attackType: .melee, dieRoll: dieRoll, drm: drm)
      logs.append(Log(msg: "Melee attack on \(slot): \(result)"))

    case .rangedAttack(let slot, let dieRoll, let bloodyBattleDefender, let useMagicBow):
      if checkBloodyBattle(attacking: slot), let defender = bloodyBattleDefender {
        loseDefender(defender)
        logs.append(Log(msg: "Bloody battle cost: lost \(defender)"))
      }
      var drm = totalAttackDRM(slot: slot, attackType: .ranged)
      if let timing = useMagicBow {
        let bonus = self.useMagicBow(timing: timing)
        drm += bonus
        logs.append(Log(msg: "Magic Bow used (\(timing)): +\(bonus) DRM"))
      }
      let result = resolveAttack(on: slot, attackType: .ranged, dieRoll: dieRoll, drm: drm)
      logs.append(Log(msg: "Ranged attack on \(slot): \(result)"))

    case .buildUpgrade(let upgrade, let track, let dieRoll):
      let drm = totalBuildDRM()
      let result = build(upgrade: upgrade, on: track, dieRoll: dieRoll, drm: drm)
      logs.append(Log(msg: "Build \(upgrade) on \(track): \(result)"))

    case .chant(let dieRoll):
      let drm = totalChantDRM()
      let success = chant(dieRoll: dieRoll, drm: drm)
      logs.append(Log(msg: "Chant: \(success ? "success" : "failed")"))

    case .questAction(let dieRoll, let reward):
      let result = attemptQuest(isHeroic: false, dieRoll: dieRoll, additionalDRM: questDRM())
      logs.append(Log(msg: "Quest (action): \(result)"))
      if result == .success {
        logs += applyQuestReward(params: reward)
      }

    default:
      break
    }
    return logs
  }

  /// Resolve a heroic-phase die-roll action. Returns logs.
  mutating func resolveHeroicDieRoll(_ action: LoD.Action) -> [Log] {
    var logs: [Log] = []
    switch action {
    case .heroicAttack(let hero, let slot, let dieRoll):
      let additionalDRM = totalHeroicAttackDRM(hero: hero, slot: slot) - hero.combatDRM
      let result = resolveHeroicAttack(hero: hero, on: slot, dieRoll: dieRoll, additionalDRM: additionalDRM)
      switch result {
      case .success(let attackResult):
        logs.append(Log(msg: "Heroic attack by \(hero) on \(slot): \(attackResult.attackResult)"))
        if attackResult.heroWounded { logs.append(Log(msg: "Hero \(hero) wounded!")) }
        if attackResult.heroKilled { logs.append(Log(msg: "Hero \(hero) killed!")) }
      case .failure(let err):
        logs.append(Log(msg: "Heroic attack error: \(err)"))
      }

    case .rally(let dieRoll):
      let drm = totalRallyDRM()
      let success = rally(dieRoll: dieRoll, drm: drm)
      logs.append(Log(msg: "Rally: \(success ? "success" : "failed")"))

    case .questHeroic(let dieRoll, let reward):
      let result = attemptQuest(isHeroic: true, dieRoll: dieRoll, additionalDRM: questDRM())
      logs.append(Log(msg: "Quest (heroic): \(result)"))
      if result == .success {
        logs += applyQuestReward(params: reward)
      }

    default:
      break
    }
    return logs
  }

  /// The phase an action belongs to (for returning after Paladin re-roll).
  static func phaseForDieRollAction(_ action: LoD.Action) -> LoD.Phase {
    switch action {
    case .meleeAttack, .rangedAttack, .buildUpgrade, .chant, .questAction:
      return .action
    case .heroicAttack, .rally, .questHeroic:
      return .heroic
    default:
      return .action
    }
  }
}

extension LoD {

  // MARK: - Greenskin Scenario Setup

  /// Create the initial state for the Greenskin Horde scenario.
  /// `windsOfMagicArcane` is the arcane energy after the Winds of Magic roll
  /// and player choice (before hero bonuses). Divine = 6 - arcane.
  /// Hero bonuses (+2 arcane for Wizard, +2 divine for Cleric) are applied automatically.
  static func greenskinSetup(
    windsOfMagicArcane: Int,
    heroes: [LoD.HeroType] = [.warrior, .wizard, .cleric]
  ) -> State {
    var state = State()
    state.scenario = .greenskinHorde

    // Armies (Scenario 1 card)
    state.armyType = [
      .east: .goblin,
      .west: .goblin,
      .gate1: .orc,
      .gate2: .orc,
      .sky: .dragon,
      .terror: .troll
    ]
    state.armyPosition = [
      .east: 6,
      .west: 6,
      .gate1: 4,
      .gate2: 4,
      .sky: 6,
      // terror: Troll not placed until first twilight
    ]

    // Heroes — all start in Reserves
    for hero in heroes {
      state.heroLocation[hero] = .reserves
    }

    // Defenders at max
    state.defenders = [
      .menAtArms: LoD.DefenderType.menAtArms.maxValue,
      .archers: LoD.DefenderType.archers.maxValue,
      .priests: LoD.DefenderType.priests.maxValue
    ]

    // Morale starts Normal (rule 6.1.1)
    state.morale = .normal

    // Winds of Magic (rule 2.1)
    let baseArcane = windsOfMagicArcane
    let baseDivine = 6 - windsOfMagicArcane
    let wizardBonus = heroes.contains(.wizard) ? 2 : 0
    let clericBonus = heroes.contains(.cleric) ? 2 : 0
    state.arcaneEnergy = min(baseArcane + wizardBonus, 6)
    state.divineEnergy = min(baseDivine + clericBonus, 6)

    // Time starts at First Dawn
    state.timePosition = 0

    // All spells face-down (default)
    // No breaches, barricades, upgrades (default)
    // Bloody battle in reserves (default nil)

    state.phase = .card

    return state
  }
}
