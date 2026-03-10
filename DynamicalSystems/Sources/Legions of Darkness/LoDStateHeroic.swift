//
//  LoDStateHeroic.swift
//  DynamicalSystems
//
//  Legions of Darkness — Heroic acts, rally, hero movement
//  (split from LoDStateCombat for file_length).
//

import Foundation

extension LoD.State {

  // MARK: - Heroic Attack (rule 7.0)

  struct HeroicAttackResult: Equatable {
    let attackResult: AttackResult
    let heroWounded: Bool
    let heroKilled: Bool
  }

  enum HeroicAttackError: Error, Equatable {
    case heroNotOnTrack
    case heroOnWrongTrack
  }

  /// Resolve a heroic attack by a hero against an army (rule 7.3).
  /// The hero must be assigned to the same track as the target army.
  /// The hero's combat DRM and attack type are used automatically.
  /// On natural 1: attack fails AND hero is wounded (unless immune).
  mutating func resolveHeroicAttack(
    hero: LoD.HeroType,
    on slot: LoD.ArmySlot,
    dieRoll: Int,
    additionalDRM: Int = 0
  ) -> Result<HeroicAttackResult, HeroicAttackError> {
    // Rule 7.3: hero must be on the same track as the target army
    guard let location = heroLocation[hero] else {
      return .failure(.heroNotOnTrack)
    }
    guard case .onTrack(let heroTrack) = location, heroTrack == slot.track else {
      return .failure(.heroOnWrongTrack)
    }

    let attackType: AttackType = hero.isRangedCombatant ? .ranged : .melee
    let totalDRM = hero.combatDRM + additionalDRM

    let result = resolveAttack(
      on: slot,
      attackType: attackType,
      dieRoll: dieRoll,
      drm: totalDRM
    )

    // Natural 1: wound hero (unless immune)
    var wounded = false
    var killed = false
    if dieRoll == 1 && !hero.isWoundImmuneInCombat {
      if heroWounded.contains(hero) {
        // Already wounded -> killed
        heroDead.insert(hero)
        heroWounded.remove(hero)
        heroLocation.removeValue(forKey: hero)
        killed = true
      } else {
        heroWounded.insert(hero)
        wounded = true
      }
    }

    return .success(HeroicAttackResult(
      attackResult: result,
      heroWounded: wounded,
      heroKilled: killed
    ))
  }

  // MARK: - Hero Wounding

  /// Wound a hero. If already wounded, the hero dies.
  mutating func woundHero(_ hero: LoD.HeroType) {
    if heroWounded.contains(hero) {
      heroDead.insert(hero)
      heroWounded.remove(hero)
      heroLocation.removeValue(forKey: hero)
    } else {
      heroWounded.insert(hero)
    }
  }

  // MARK: - Heroic Acts (rule 7.0)

  // -- Move Hero (rule 7.1) --

  /// Move a hero to a track or back to reserves.
  mutating func moveHero(_ hero: LoD.HeroType, to location: LoD.HeroLocation) {
    heroLocation[hero] = location
  }

  // -- Rally (rule 7.4) --

  /// Rally heroic act: roll > 4 to raise morale one step.
  /// Natural 1 always fails.
  mutating func rally(dieRoll: Int, drm: Int = 0) -> Bool {
    if dieRoll == 1 { return false }
    let modified = dieRoll + drm
    if modified > 4 {
      morale = morale.raised()
      return true
    }
    return false
  }
}
