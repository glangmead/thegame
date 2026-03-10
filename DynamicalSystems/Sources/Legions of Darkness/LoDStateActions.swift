//
//  LoDStateActions.swift
//  DynamicalSystems
//
//  Legions of Darkness — Actions, spell effects, and casting.
//

import Foundation

extension LoD.State {

  // MARK: - Actions (rule 6.0)

  // -- Memorize (rule 6.6) --

  /// Face-down arcane spells available to memorize.
  var faceDownArcaneSpells: [LoD.SpellType] {
    LoD.SpellType.arcaneSpells.filter { spellStatus[$0] == .faceDown }
  }

  /// Memorize action: reveal a face-down arcane spell (mark as known).
  /// `spell` is the randomly-selected spell (injected for deterministic testing).
  mutating func memorize(spell: LoD.SpellType) -> Bool {
    guard spell.isArcane, spellStatus[spell] == .faceDown else {
      return false
    }
    spellStatus[spell] = .known
    return true
  }

  // -- Pray (rule 6.7) --

  /// Face-down divine spells available to pray for.
  var faceDownDivineSpells: [LoD.SpellType] {
    LoD.SpellType.divineSpells.filter { spellStatus[$0] == .faceDown }
  }

  /// Pray action: reveal a face-down divine spell (mark as known).
  /// `spell` is the randomly-selected spell (injected for deterministic testing).
  mutating func pray(spell: LoD.SpellType) -> Bool {
    guard spell.isDivine, spellStatus[spell] == .faceDown else {
      return false
    }
    spellStatus[spell] = .known
    return true
  }

  // -- Chant (rule 6.5) --

  /// Chant action: roll > 3 (with priest DRM) to gain +1 divine energy.
  /// Natural 1 always fails.
  mutating func chant(dieRoll: Int, drm: Int = 0) -> Bool {
    if dieRoll == 1 { return false }
    let modified = dieRoll + drm
    if modified > 3 {
      divineEnergy = min(divineEnergy + 1, 6)
      return true
    }
    return false
  }

  // -- Build (rule 6.3) --

  enum BuildResult: Equatable {
    case success(LoD.UpgradeType, LoD.Track)
    case rollFailed
    case trackInvalid
  }

  /// Build action: roll > build number to place upgrade on a valid wall track.
  /// LoD.Track must be a wall, unbreached, and have no existing upgrade.
  /// Natural 1 always fails.
  mutating func build(
    upgrade: LoD.UpgradeType,
    on track: LoD.Track,
    dieRoll: Int,
    drm: Int = 0
  ) -> BuildResult {
    guard track.isWall, !breaches.contains(track), upgrades[track] == nil,
          !armyAtSpace1(on: track) else {
      return .trackInvalid
    }
    if dieRoll == 1 { return .rollFailed }
    let modified = dieRoll + drm
    if modified > upgrade.buildNumber {
      upgrades[track] = upgrade
      return .success(upgrade, track)
    }
    return .rollFailed
  }

  // -- Build Barricade (rule 6.3) --

  enum BarricadeBuildResult: Equatable {
    case success
    case rollFailed
    case trackInvalid
  }

  /// Build barricade action: roll > 2 to convert a breach into a barricade.
  /// Track must be a wall with a breach.
  /// Natural 1 always fails.
  mutating func buildBarricade(
    on track: LoD.Track,
    dieRoll: Int,
    drm: Int = 0
  ) -> BarricadeBuildResult {
    guard track.isWall, breaches.contains(track) else {
      return .trackInvalid
    }
    if dieRoll == 1 { return .rollFailed }
    let modified = dieRoll + drm
    if modified > 2 {
      breaches.remove(track)
      barricades.insert(track)
      return .success
    }
    return .rollFailed
  }

  // -- Cast Spell (rule 6.4) --

  enum CastSpellResult: Equatable {
    case success(LoD.SpellType, heroic: Bool)
    case spellNotKnown
    case insufficientEnergy
    case heroicRequiresHero
  }

  /// Known spells available to cast.
  var knownSpells: [LoD.SpellType] {
    LoD.SpellType.allCases.filter { spellStatus[$0] == .known }
  }

  /// Whether a spell can be heroically cast.
  /// Arcane heroic cast requires Wizard alive; divine requires Cleric alive.
  func canHeroicCast(_ spell: LoD.SpellType) -> Bool {
    if spell.isArcane {
      return heroLocation[.wizard] != nil && !heroDead.contains(.wizard)
    } else {
      return heroLocation[.cleric] != nil && !heroDead.contains(.cleric)
    }
  }

  /// Cast a spell: deduct energy, mark as cast.
  /// If `heroic` is true, the enhanced effect applies (requires Wizard for arcane,
  /// Cleric for divine). The spell effect itself is handled separately.
  mutating func castSpell(_ spell: LoD.SpellType, heroic: Bool = false) -> CastSpellResult {
    guard spellStatus[spell] == .known else {
      return .spellNotKnown
    }
    if heroic && !canHeroicCast(spell) {
      return .heroicRequiresHero
    }
    let cost = spell.energyCost
    if spell.isArcane {
      guard arcaneEnergy >= cost else { return .insufficientEnergy }
      arcaneEnergy -= cost
    } else {
      guard divineEnergy >= cost else { return .insufficientEnergy }
      divineEnergy -= cost
    }
    spellStatus[spell] = .cast
    return .success(spell, heroic: heroic)
  }

  // MARK: - Spell Targeting (rule 9.2)

  /// Whether an arcane spell can target a given track.
  /// Most arcane spells require the Wizard to be on the same track as the target.
  /// Chain Lightning and Fortune are exempt (they affect multiple targets or the deck).
  func canTargetWithArcaneSpell(_ spell: LoD.SpellType, targetTrack: LoD.Track) -> Bool {
    // Chain Lightning and Fortune have no track restriction
    if spell == .chainLightning || spell == .fortune { return true }
    guard spell.isArcane else { return true }  // Divine spells have no track restriction
    // Wizard must be on the target track
    if let wizardLoc = heroLocation[.wizard], !heroDead.contains(.wizard) {
      if case .onTrack(let track) = wizardLoc {
        return track == targetTrack
      }
    }
    // No wizard or wizard in reserves — can still cast (wizard not required), but
    // if the spell needs same-track, it can target any track when wizard is absent
    // Actually per rule 9.2, wizard is needed for same-track. If no wizard, cannot target.
    // But rule says "wizard not required to cast". The same-track is a targeting restriction.
    // If wizard is absent/dead/in reserves, targeted arcane spells can't pick a track.
    return false
  }

  /// Whether normal Inspire can be cast (not at High morale).
  func canCastInspireNormal() -> Bool {
    morale != .high
  }

  /// Validate Raise Dead parameters based on normal vs heroic mode.
  /// Normal: 2 different defenders OR 1 hero, not both.
  /// Heroic: 2 different defenders AND/OR 1 hero.
  func isValidRaiseDeadParams(
    gainDefenders: [LoD.DefenderType],
    returnHero: LoD.HeroType?,
    heroic: Bool
  ) -> Bool {
    if heroic {
      // Heroic: can do defenders, hero, or both
      return true
    } else {
      // Normal: exclusive OR — defenders or hero, not both
      let hasDefenders = !gainDefenders.isEmpty
      let hasHero = returnHero != nil
      if hasDefenders && hasHero { return false }
      return true
    }
  }

  // MARK: - Spell Effects (rules 9.2, 9.3)

  // -- Cure Wounds (divine, cost 1) --

  /// Heal wounded heroes. Normal: 1 hero. Heroic (†): up to 2 heroes.
  mutating func applyCureWounds(heroes: [LoD.HeroType]) {
    for hero in heroes {
      heroWounded.remove(hero)
    }
  }

  // -- Mass Heal (divine, cost 2) --

  /// Gain defenders. Normal: 1 defender. Heroic (†): 2 different defenders.
  mutating func applyMassHeal(defenders gainTypes: [LoD.DefenderType]) {
    for type in gainTypes {
      if let current = defenders[type] {
        defenders[type] = min(current + 1, type.maxValue)
      }
    }
  }

  // -- Inspire (divine, cost 3) --

  /// Raise morale one step and grant +1 DRM to all rolls until end of turn.
  /// Normal: cannot cast at High morale. Raises morale + DRM.
  /// Heroic (†): at High morale, only grants +1 DRM (no morale raise).
  mutating func applyInspire(heroic: Bool = false) {
    if morale == .high {
      // At high morale, only heroic Inspire works, and only for DRM
      inspireDRMActive = true
    } else {
      morale = morale.raised()
      inspireDRMActive = true
    }
  }

  // -- Raise Dead (divine, cost 4) --

  /// Normal: gain 2 different defenders OR return 1 dead hero.
  /// Heroic (†): gain 2 different defenders AND/OR return 1 dead hero.
  mutating func applyRaiseDead(gainDefenders: [LoD.DefenderType], returnHero: LoD.HeroType?) {
    for type in gainDefenders {
      if let current = defenders[type] {
        defenders[type] = min(current + 1, type.maxValue)
      }
    }
    if let hero = returnHero {
      heroDead.remove(hero)
      heroLocation[hero] = .reserves
    }
  }

  // -- Fireball (arcane, cost 1) --

  /// Make a +2 magical attack. Heroic (∞): may re-roll.
  /// Returns the attack result. Caller handles re-roll decision.
  mutating func applyFireball(
    on slot: LoD.ArmySlot,
    dieRoll: Int,
    additionalDRM: Int = 0
  ) -> AttackResult {
    return resolveAttack(
      on: slot,
      attackType: .ranged,
      dieRoll: dieRoll,
      drm: 2 + additionalDRM,
      isMagical: true
    )
  }

  // -- Slow (arcane, cost 2) --

  /// Normal: place Slow marker on one army.
  /// Heroic (∞): retreat army one space first, then place marker.
  mutating func applySlow(on slot: LoD.ArmySlot, heroic: Bool = false) {
    if heroic {
      // Retreat army one space (push back away from castle)
      if let space = armyPosition[slot] {
        let track = slot.track
        armyPosition[slot] = min(space + 1, track.maxSpace)
      }
    }
    slowedArmy = slot
  }

  // -- Chain Lightning (arcane, cost 3) --

  /// Make 3 magical attacks. Normal: +2, +1, +0 DRMs. Heroic (∞): +3, +2, +1.
  /// Targets and die rolls provided as parallel arrays.
  mutating func applyChainLightning(
    targets: [(slot: LoD.ArmySlot, dieRoll: Int)],
    heroic: Bool = false,
    additionalDRM: Int = 0
  ) -> [AttackResult] {
    let baseDRMs = heroic ? [3, 2, 1] : [2, 1, 0]
    var results: [AttackResult] = []
    for (index, target) in targets.prefix(3).enumerated() {
      let result = resolveAttack(
        on: target.slot,
        attackType: .ranged,
        dieRoll: target.dieRoll,
        drm: baseDRMs[index] + additionalDRM,
        isMagical: true
      )
      results.append(result)
    }
    return results
  }

  // -- Divine Wrath (divine, cost 3) --

  /// Normal: 1 magical attack with +1 DRM; undead retreat +1.
  /// Heroic (†): 2 magical attacks (different targets) with +1 DRM; undead retreat +1.
  mutating func applyDivineWrath(
    targets: [(slot: LoD.ArmySlot, dieRoll: Int)],
    additionalDRM: Int = 0
  ) -> [AttackResult] {
    var results: [AttackResult] = []
    for target in targets {
      let result = resolveAttack(
        on: target.slot,
        attackType: .ranged,
        dieRoll: target.dieRoll,
        drm: 1 + additionalDRM,
        isMagical: true
      )
      // Undead retreat +1 on hit
      if case .hit(let slot, _, let pushedTo) = result {
        if let type = armyType[slot], type.isUndead {
          let track = slot.track
          armyPosition[slot] = min(pushedTo + 1, track.maxSpace)
        }
      }
      results.append(result)
    }
    return results
  }

  // -- Fortune (arcane, cost 4) --

  /// Peek at the top cards of the current deck (day or night based on time).
  func fortunePeek() -> [LoD.Card] {
    let pile = drawsFromDayDeck ? dayDrawPile : nightDrawPile
    return Array(pile.prefix(3))
  }

  /// Fortune spell effect. Operates on the current deck.
  /// Normal: look at top 3, reorder. `newOrder` = indices into the top-3 in desired order.
  /// Heroic (∞): look at top 3, discard 1. `discardIndex` specifies which to discard.
  ///   `newOrder` = indices of the 2 remaining cards in desired order.
  mutating func applyFortune(newOrder: [Int], discardIndex: Int? = nil) {
    let isDayDeck = drawsFromDayDeck
    let count = isDayDeck
      ? min(3, dayDrawPile.count)
      : min(3, nightDrawPile.count)
    guard count > 0 else { return }

    let top: [LoD.Card]
    if isDayDeck {
      top = Array(dayDrawPile.prefix(count))
      dayDrawPile.removeFirst(count)
    } else {
      top = Array(nightDrawPile.prefix(count))
      nightDrawPile.removeFirst(count)
    }

    if let discardIdx = discardIndex {
      if isDayDeck {
        dayDiscardPile.append(top[discardIdx])
      } else {
        nightDiscardPile.append(top[discardIdx])
      }
    }

    var reordered: [LoD.Card] = []
    for idx in newOrder {
      reordered.append(top[idx])
    }

    if isDayDeck {
      dayDrawPile.insert(contentsOf: reordered, at: 0)
    } else {
      nightDrawPile.insert(contentsOf: reordered, at: 0)
    }
  }
}
