//
//  LoDEventEnergyTests.swift
//  DynamicalSystems
//
//  Tests for LoD energy/defender/spell events and event reset (rule 5.0).
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDEventEnergyTests {

  // -- Deserters in the Dark (card #33) --

  @Test
  func desertersTwoDefenders() {
    // Player chooses: lose 2 defenders.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventDeserters(loseTwoDefenders: (.menAtArms, .archers))
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
  }

  @Test
  func desertersMorale() {
    // Player chooses: reduce Morale by one.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventDeserters(loseTwoDefenders: nil)
    #expect(state.morale == .low)
  }

  // -- The Waning Moon (card #34) --

  @Test
  func waningMoonLoss() {
    // Roll 1-3: -1 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane 5
    let before = state.arcaneEnergy
    state.eventWaningMoon(dieRoll: 2)
    #expect(state.arcaneEnergy == before - 1)
  }

  @Test
  func waningMoonGain() {
    // Roll 4-6: +1 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane 3
    let before = state.arcaneEnergy
    state.eventWaningMoon(dieRoll: 5)
    #expect(state.arcaneEnergy == min(before + 1, 6))
  }

  // -- Mystic Forces Reborn (card #35) --

  @Test
  func mysticForcesReborn() {
    // Return cast spells to pool. Roll 4-6: draw a random arcane spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast
    state.spellStatus[.slow] = .cast
    state.spellStatus[.cureWounds] = .cast // divine, also returns

    state.eventMysticForcesReborn(dieRoll: 5, randomSpell: .chainLightning)
    // Cast spells returned to face-down
    #expect(state.spellStatus[.fireball] == .faceDown)
    #expect(state.spellStatus[.slow] == .faceDown)
    #expect(state.spellStatus[.cureWounds] == .faceDown)
    // Random arcane spell drawn (revealed)
    #expect(state.spellStatus[.chainLightning] == .known)
  }

  @Test
  func mysticForcesRebornLoseArcane() {
    // Roll 1-3: -1 arcane (spells still returned).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast
    let before = state.arcaneEnergy

    state.eventMysticForcesReborn(dieRoll: 2)
    #expect(state.spellStatus[.fireball] == .faceDown)
    #expect(state.arcaneEnergy == before - 1)
  }

  // -- Death and Despair (card #29) --

  @Test
  func deathAndDespair() {
    // Roll 4, no mitigation → advance farthest army 4 spaces.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // East at 6 (farthest, tied with West/Sky), set others lower
    state.armyPosition[.west] = 3
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventDeathAndDespair(dieRoll: 4, chosenSlot: .east)
    #expect(results.count == 4)
    #expect(state.armyPosition[.east] == 2) // 6 → 5 → 4 → 3 → 2
  }

  @Test
  func deathAndDespairMitigated() {
    // Roll 3, wound 1 hero + lose 1 defender → only 1 advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.armyPosition[.west] = 3
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventDeathAndDespair(
      dieRoll: 3,
      heroesToWound: [.warrior],
      defendersToLose: [.menAtArms],
      chosenSlot: .east
    )
    #expect(results.count == 1) // 3 - 2 = 1
    #expect(state.armyPosition[.east] == 4) // 5 → 4
    #expect(state.heroWounded.contains(.warrior))
    #expect(state.defenders[.menAtArms] == 2)
  }

  // -- Bump in the Night (card #36) --

  @Test
  func bumpInTheNightSky() {
    // Choose: advance Sky 1 space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.sky] = 5

    let results = state.eventBumpInTheNight(advanceSky: true)
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.sky, from: 5, destination: 4))
  }

  @Test
  func bumpInTheNightOthers() {
    // Choose: advance other armies total 2 spaces (e.g., east + west 1 each).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.armyPosition[.west] = 4

    let results = state.eventBumpInTheNight(advanceSky: false, otherAdvances: [.east, .west])
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.east, from: 5, destination: 4))
    #expect(results[1] == .advanced(.west, from: 4, destination: 3))
  }

  // -- Event per-turn tracking reset --

  @Test
  func eventFieldsResetOnTurnReset() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAttackDRMBonus = 1
    state.noMeleeThisTurn = true
    state.woundedHeroesCannotAct = true

    state.resetTurnTracking()
    #expect(state.eventAttackDRMBonus == 0)
    #expect(!state.noMeleeThisTurn)
    #expect(!state.woundedHeroesCannotAct)
  }

}
