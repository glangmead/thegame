//
//  LoDCombatHeroTests.swift
//  DynamicalSystems
//
//  Tests for LoD combat: Hero Wounding, Upgrade Attack DRMs, Bloody Battle, Paladin Re-roll, Turn Reset.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDCombatHeroTests {

  // MARK: - Hero Wounding

  @Test
  func woundHealthyHero() {
    // Wound a healthy hero → becomes wounded.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.heroWounded.contains(.wizard))

    state.woundHero(.wizard)
    #expect(state.heroWounded.contains(.wizard))
    #expect(!state.heroDead.contains(.wizard))
  }

  @Test
  func woundWoundedHeroKills() {
    // Wound an already-wounded hero → killed, removed from play.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.wizard)

    state.woundHero(.wizard)
    #expect(state.heroDead.contains(.wizard))
    #expect(!state.heroWounded.contains(.wizard))
    #expect(state.heroLocation[.wizard] == nil)
  }

  // MARK: - Upgrade Attack DRMs (rule 6.3)

  @Test
  func upgradeGreaseDRM() {
    // Grease is a breach-prevention mechanic, NOT a DRM (rule 6.3).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease

    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
    #expect(state.upgradeDRM(on: .east, attackType: .ranged) == 0)
  }

  @Test
  func upgradeOilDRM() {
    // Oil: +1 DRM to melee or ranged against army in space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.west] = .oil

    #expect(state.upgradeDRM(on: .west, attackType: .melee) == 1)
    #expect(state.upgradeDRM(on: .west, attackType: .ranged) == 1)
  }

  @Test
  func upgradeLavaDRM() {
    // Lava: +2 DRM to melee only against army in space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.gate] = .lava

    #expect(state.upgradeDRM(on: .gate, attackType: .melee) == 2)
    #expect(state.upgradeDRM(on: .gate, attackType: .ranged) == 0) // melee only
  }

  @Test
  func upgradeAcidNoDRM() {
    // Acid: free attack, not a DRM bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .acid

    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
    #expect(state.upgradeDRM(on: .east, attackType: .ranged) == 0)
  }

  @Test
  func upgradeNoneNoDRM() {
    // No upgrade on track → 0 DRM.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
  }

  // MARK: - Bloody Battle (Player Aid: Markers)

  @Test
  func bloodyBattleFirstAttackCostsDefender() {
    // First attack against army with bloody battle marker costs 1 defender.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(shouldLose)
    #expect(state.bloodyBattlePaidThisTurn)
  }

  @Test
  func bloodyBattleSecondAttackNoCost() {
    // After paying once, subsequent attacks this turn don't cost a defender.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east
    state.bloodyBattlePaidThisTurn = true // already paid

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(!shouldLose)
  }

  @Test
  func bloodyBattleWrongArmy() {
    // Attacking a different army than the one with the marker — no cost.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east

    let shouldLose = state.checkBloodyBattle(attacking: .west)
    #expect(!shouldLose)
  }

  @Test
  func bloodyBattleNoMarker() {
    // No bloody battle marker on any army — no cost.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.bloodyBattleArmy == nil)

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(!shouldLose)
  }

  // MARK: - Paladin Re-roll (Player Aid: Paladin — holy)

  @Test
  func paladinCanReroll() {
    // Paladin alive and in play, not used yet → can re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    #expect(state.canPaladinReroll)

    state.usePaladinReroll()
    #expect(!state.canPaladinReroll)
  }

  @Test
  func paladinCannotRerollWhenDead() {
    // Dead Paladin cannot re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.heroDead.insert(.paladin)
    state.heroLocation.removeValue(forKey: .paladin)

    #expect(!state.canPaladinReroll)
  }

  @Test
  func paladinCannotRerollWhenNotInPlay() {
    // Paladin not in hero roster → cannot re-roll.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3) // default: warrior, wizard, cleric
    #expect(!state.canPaladinReroll) // no paladin
  }

  @Test
  func paladinRerollResetsEachTurn() {
    // After turn reset, Paladin can re-roll again.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.usePaladinReroll()
    #expect(!state.canPaladinReroll)

    state.resetTurnTracking()
    #expect(state.canPaladinReroll)
  }

  // MARK: - Turn Reset (housekeeping)

  @Test
  func turnResetClearsPerTurnState() {
    // Reset clears bloody battle payment and Paladin re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.bloodyBattlePaidThisTurn = true
    state.paladinRerollUsed = true

    state.resetTurnTracking()
    #expect(!state.bloodyBattlePaidThisTurn)
    #expect(!state.paladinRerollUsed)
  }

}
