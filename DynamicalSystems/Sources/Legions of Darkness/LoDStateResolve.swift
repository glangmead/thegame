//
//  LoDStateResolve.swift
//  DynamicalSystems
//
//  Legions of Darkness — Die-roll action resolution, phase helpers, and scenario setup.
//

import Foundation

extension LoD.State {

  // MARK: - Shared Die-Roll Action Resolution

  /// Whether the given action is a die-roll action eligible for Paladin re-roll.
  static func isDieRollAction(_ action: LoD.Action) -> Bool {
    switch action {
    case .combat, .build, .magic(.chant), .quest:
      return true
    case .heroic(.heroicAttack), .heroic(.rally):
      return true
    default:
      return false
    }
  }

  // Replace the die roll in a die-roll action with a new value.
  // swiftlint:disable:next cyclomatic_complexity
  static func withNewDieRoll(_ action: LoD.Action, newDieRoll: Int) -> LoD.Action {
    switch action {
    case .combat(let sub):
      switch sub {
      case .meleeAttack(let slot, _, let bloodyBattleDef, let magicSword):
        return .combat(.meleeAttack(
          slot, dieRoll: newDieRoll, bloodyBattleDefender: bloodyBattleDef, useMagicSword: magicSword))
      case .rangedAttack(let slot, _, let bloodyBattleDef, let magicBow):
        return .combat(.rangedAttack(
          slot, dieRoll: newDieRoll, bloodyBattleDefender: bloodyBattleDef, useMagicBow: magicBow))
      }
    case .build(let sub):
      switch sub {
      case .buildUpgrade(let upgrade, let track, _):
        return .build(.buildUpgrade(upgrade, track, dieRoll: newDieRoll))
      case .buildBarricade(let track, _):
        return .build(.buildBarricade(track, dieRoll: newDieRoll))
      }
    case .magic(.chant):
      return .magic(.chant(dieRoll: newDieRoll))
    case .quest(.quest(let isHeroic, _, let reward)):
      return .quest(.quest(isHeroic: isHeroic, dieRoll: newDieRoll, reward: reward))
    case .heroic(let sub):
      switch sub {
      case .heroicAttack(let hero, let slot, _):
        return .heroic(.heroicAttack(hero, slot, dieRoll: newDieRoll))
      case .rally:
        return .heroic(.rally(dieRoll: newDieRoll))
      case .moveHero:
        return action
      }
    default:
      return action
    }
  }

  /// Roll a d6 if the action carries a placeholder (0), otherwise use the provided value.
  static func effectiveDie(_ dieRoll: Int) -> Int {
    dieRoll == 0 ? Int.random(in: 1...6) : dieRoll
  }

  // MARK: - Paladin Check Helper

  /// Handle a die-roll action with Paladin re-roll check.
  /// If Paladin can re-roll, defers the action and switches to paladinReact phase.
  /// Otherwise resolves immediately via the appropriate phase resolver.
  mutating func resolveDieRollWithPaladinCheck(
    _ action: LoD.Action, phase: LoD.Phase
  ) -> [Log] {
    if canPaladinReroll {
      pendingDieRollAction = action
      phaseBeforePaladinReact = phase
      self.phase = .paladinReact
      return [Log(msg: "Paladin may re-roll this die")]
    }
    if phase == .action {
      return resolveActionDieRoll(action)
    } else {
      return resolveHeroicDieRoll(action)
    }
  }

  /// Resolve an action-phase die-roll action. Returns logs.
  mutating func resolveActionDieRoll(_ action: LoD.Action) -> [Log] {
    switch action {
    case .combat(.meleeAttack(let slot, let dieRoll, let bloodyBattleDefender, let useMagicSword)):
      return resolveMeleeAttack(slot: slot, dieRoll: Self.effectiveDie(dieRoll),
                                bloodyBattleDefender: bloodyBattleDefender,
                                useMagicSword: useMagicSword)

    case .combat(.rangedAttack(let slot, let dieRoll, let bloodyBattleDefender, let useMagicBow)):
      return resolveRangedAttack(slot: slot, dieRoll: Self.effectiveDie(dieRoll),
                                bloodyBattleDefender: bloodyBattleDefender,
                                useMagicBow: useMagicBow)

    case .build(.buildUpgrade(let upgrade, let track, let dieRoll)):
      let drm = totalBuildDRM()
      let result = build(upgrade: upgrade, on: track, dieRoll: Self.effectiveDie(dieRoll), drm: drm)
      return [Log(msg: "Build \(upgrade) on \(track): \(result)")]

    case .build(.buildBarricade(let track, let dieRoll)):
      let drm = totalBuildDRM()
      let result = buildBarricade(on: track, dieRoll: Self.effectiveDie(dieRoll), drm: drm)
      return [Log(msg: "Build barricade on \(track): \(result)")]

    case .magic(.chant(let dieRoll)):
      let drm = totalChantDRM()
      let success = chant(dieRoll: Self.effectiveDie(dieRoll), drm: drm)
      return [Log(msg: "Chant: \(success ? "success" : "failed")")]

    case .quest(.quest(let isHeroic, let dieRoll, let reward)) where !isHeroic:
      return resolveQuestAction(dieRoll: Self.effectiveDie(dieRoll), reward: reward, isHeroic: false)

    default:
      return []
    }
  }

  // MARK: - Action Die-Roll Helpers

  private mutating func resolveMeleeAttack(
    slot: LoD.ArmySlot, dieRoll: Int,
    bloodyBattleDefender: LoD.DefenderType?, useMagicSword: LoD.ItemTiming?
  ) -> [Log] {
    var logs = resolveBloodyBattleCost(slot: slot, defender: bloodyBattleDefender)
    var drm = totalAttackDRM(slot: slot, attackType: .melee)
    if let timing = useMagicSword {
      let bonus = self.useMagicSword(timing: timing)
      drm += bonus
      logs.append(Log(msg: "Magic Sword used (\(timing)): +\(bonus) DRM"))
    }
    let result = resolveAttack(on: slot, attackType: .melee, dieRoll: dieRoll, drm: drm)
    logs.append(Log(msg: "Melee attack on \(slot): \(result)"))
    return logs
  }

  private mutating func resolveRangedAttack(
    slot: LoD.ArmySlot, dieRoll: Int,
    bloodyBattleDefender: LoD.DefenderType?, useMagicBow: LoD.ItemTiming?
  ) -> [Log] {
    var logs = resolveBloodyBattleCost(slot: slot, defender: bloodyBattleDefender)
    var drm = totalAttackDRM(slot: slot, attackType: .ranged)
    if let timing = useMagicBow {
      let bonus = self.useMagicBow(timing: timing)
      drm += bonus
      logs.append(Log(msg: "Magic Bow used (\(timing)): +\(bonus) DRM"))
    }
    let result = resolveAttack(on: slot, attackType: .ranged, dieRoll: dieRoll, drm: drm)
    logs.append(Log(msg: "Ranged attack on \(slot): \(result)"))
    return logs
  }

  private mutating func resolveBloodyBattleCost(
    slot: LoD.ArmySlot, defender: LoD.DefenderType?
  ) -> [Log] {
    guard checkBloodyBattle(attacking: slot), let defender else { return [] }
    loseDefender(defender)
    return [Log(msg: "Bloody battle cost: lost \(defender)")]
  }

  private mutating func resolveQuestAction(
    dieRoll: Int, reward: LoD.QuestRewardParams, isHeroic: Bool
  ) -> [Log] {
    let result = attemptQuest(isHeroic: isHeroic, dieRoll: dieRoll, additionalDRM: questDRM())
    let label = isHeroic ? "heroic" : "action"
    var logs = [Log(msg: "Quest (\(label)): \(result)")]
    if result == .success {
      logs += applyQuestReward(params: reward)
    }
    return logs
  }

  /// Resolve a heroic-phase die-roll action. Returns logs.
  mutating func resolveHeroicDieRoll(_ action: LoD.Action) -> [Log] {
    switch action {
    case .heroic(.heroicAttack(let hero, let slot, let dieRoll)):
      return resolveHeroicAttackAction(hero: hero, slot: slot, dieRoll: Self.effectiveDie(dieRoll))

    case .heroic(.rally(let dieRoll)):
      let drm = totalRallyDRM()
      let success = rally(dieRoll: Self.effectiveDie(dieRoll), drm: drm)
      return [Log(msg: "Rally: \(success ? "success" : "failed")")]

    case .quest(.quest(let isHeroic, let dieRoll, let reward)) where isHeroic:
      return resolveQuestAction(dieRoll: Self.effectiveDie(dieRoll), reward: reward, isHeroic: true)

    default:
      return []
    }
  }

  private mutating func resolveHeroicAttackAction(
    hero: LoD.HeroType, slot: LoD.ArmySlot, dieRoll: Int
  ) -> [Log] {
    let additionalDRM = totalHeroicAttackDRM(hero: hero, slot: slot) - hero.combatDRM
    let result = resolveHeroicAttack(hero: hero, on: slot, dieRoll: dieRoll, additionalDRM: additionalDRM)
    var logs: [Log] = []
    switch result {
    case .success(let attackResult):
      logs.append(Log(msg: "Heroic attack by \(hero) on \(slot): \(attackResult.attackResult)"))
      if attackResult.heroWounded { logs.append(Log(msg: "Hero \(hero) wounded!")) }
      if attackResult.heroKilled { logs.append(Log(msg: "Hero \(hero) killed!")) }
    case .failure(let err):
      logs.append(Log(msg: "Heroic attack error: \(err)"))
    }
    return logs
  }

  /// The phase an action belongs to (for returning after Paladin re-roll).
  static func phaseForDieRollAction(_ action: LoD.Action) -> LoD.Phase {
    switch action {
    case .combat, .build, .magic(.chant):
      return .action
    case .quest(.quest(let isHeroic, _, _)):
      return isHeroic ? .heroic : .action
    case .heroic(.heroicAttack), .heroic(.rally):
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
      .sky: 6
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
