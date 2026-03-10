//
//  LoDEventTests.swift
//  DynamicalSystems
//
//  Tests for LoD events (rule 5.0).
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDEventTests {

  // MARK: - Events (rule 5.0)

  // -- Catapult Shrapnel (card #1) --

  @Test
  func catapultShrapnelLoseArcher() {
    // Roll 1: lose one Archer.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenders[.archers] == 2)
    state.eventCatapultShrapnel(dieRoll: 1)
    #expect(state.defenders[.archers] == 1)
  }

  @Test
  func catapultShrapnelLoseMaA() {
    // Roll 2-3: lose one Men-at-Arms.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventCatapultShrapnel(dieRoll: 2)
    #expect(state.defenders[.menAtArms] == 2)
  }

  @Test
  func catapultShrapnelNoEffect() {
    // Roll 4-6: no effect.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventCatapultShrapnel(dieRoll: 4)
    #expect(state.defenders[.archers] == 2)
    #expect(state.defenders[.menAtArms] == 3)
  }

  // -- Rocks of Ages (card #4) --

  @Test
  func rocksOfAgesLosePriest() {
    // Roll 1: lose one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventRocksOfAges(dieRoll: 1)
    #expect(state.defenders[.priests] == 1)
  }

  @Test
  func rocksOfAgesLoseMaA() {
    // Roll 2-3: lose one Men-at-Arms.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventRocksOfAges(dieRoll: 3)
    #expect(state.defenders[.menAtArms] == 2)
  }

  // -- Reign of Arrows (card #17) --

  @Test
  func reignOfArrowsLosePriest() {
    // Roll 1: lose one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventReignOfArrows(dieRoll: 1)
    #expect(state.defenders[.priests] == 1)
  }

  @Test
  func reignOfArrowsLoseArcher() {
    // Roll 2-3: lose one Archer.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventReignOfArrows(dieRoll: 2)
    #expect(state.defenders[.archers] == 1)
  }

  // -- Trapped by Flames (card #18) --

  @Test
  func trappedByFlamesLoseMaA() {
    // Roll 1-2: lose one Men-at-Arms.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventTrappedByFlames(dieRoll: 1)
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 2) // unchanged
    #expect(state.defenders[.priests] == 2) // unchanged
  }

  @Test
  func trappedByFlamesLoseArcherAndPriest() {
    // Roll 3-4: lose one Archer AND one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventTrappedByFlames(dieRoll: 3)
    #expect(state.defenders[.archers] == 1)
    #expect(state.defenders[.priests] == 1)
    #expect(state.defenders[.menAtArms] == 3) // unchanged
  }

  @Test
  func trappedByFlamesNoEffect() {
    // Roll 5-6: no effect.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventTrappedByFlames(dieRoll: 5)
    #expect(state.defenders[.menAtArms] == 3)
    #expect(state.defenders[.archers] == 2)
    #expect(state.defenders[.priests] == 2)
  }

  // -- Distracted Defenders (card #9) --

  @Test
  func distractedDefendersAdvances() {
    // East army at space 4 (out of melee range 1-3) → advance to space 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 4
    let results = state.eventDistractedDefenders()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.east, from: 4, destination: 3))
  }

  @Test
  func distractedDefendersNoEffect() {
    // East army at space 3 (in melee range) → no advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    let results = state.eventDistractedDefenders()
    #expect(results.isEmpty)
  }

  // -- Banners in the Distance (card #20) --

  @Test
  func bannersInDistanceAdvances() {
    // West army at space 5 (out of melee range) → advance to space 4.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.west] = 5
    let results = state.eventBannersInDistance()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.west, from: 5, destination: 4))
  }

  @Test
  func bannersInDistanceNoEffect() {
    // West army at space 2 (in melee range) → no advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.west] = 2
    let results = state.eventBannersInDistance()
    #expect(results.isEmpty)
  }

}
