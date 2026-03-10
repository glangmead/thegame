//
//  LoDEventAdvanceTests.swift
//  DynamicalSystems
//
//  Tests for LoD army advance events and Lamentation (rule 5.0).
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDEventAdvanceTests {

  // -- The Harbingers of Doom (card #11) --

  @Test
  func harbingersAdvanceFarthest() {
    // Farthest army (highest space number) advances one space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.armyPosition[.west] = 3
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventHarbingers()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.east, from: 5, destination: 4))
  }

  @Test
  func harbingersChooseIfTied() {
    // If tied for farthest, player chooses which to advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 6
    state.armyPosition[.west] = 6
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventHarbingers(chosenSlot: .west)
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.west, from: 6, destination: 5))
  }

  // -- Broken Walls (card #14) --

  @Test
  func brokenWallsAdvanceClosest() {
    // Closest of East/West (lowest space) advances one space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    state.armyPosition[.west] = 5

    let results = state.eventBrokenWalls()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.east, from: 3, destination: 2))
  }

  @Test
  func brokenWallsBothIfTied() {
    // If East and West tied, advance both one space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 4
    state.armyPosition[.west] = 4

    let results = state.eventBrokenWalls()
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.east, from: 4, destination: 3))
    #expect(results[1] == .advanced(.west, from: 4, destination: 3))
  }

  // -- Campfires in the Distance (card #23) --

  @Test
  func campfiresAdvanceGate() {
    // One Gate army out of melee range (space 4) → advance farthest Gate army.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 4 // out of melee (melee is 1-3)
    state.armyPosition[.gate2] = 2 // in melee

    let results = state.eventCampfires()
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.gate1, from: 4, destination: 3))
  }

  @Test
  func campfiresBothGateIfBothOut() {
    // Both Gate armies out of melee range → advance both.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 4
    state.armyPosition[.gate2] = 4

    let results = state.eventCampfires()
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.gate1, from: 4, destination: 3))
    #expect(results[1] == .advanced(.gate2, from: 4, destination: 3))
  }

  @Test
  func campfiresNoEffectIfInRange() {
    // Both Gate armies in melee range → no effect.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 2

    let results = state.eventCampfires()
    #expect(results.isEmpty)
  }

  // -- Lamentation of the Women (card #16) --

  @Test
  func lamentationMoraleLoss() {
    // Roll 1-3: reduce Morale by one.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)
    state.eventLamentation(dieRoll: 2)
    #expect(state.morale == .low)
  }

  @Test
  func lamentationNoMelee() {
    // Roll 4-6: no melee attacks this turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.noMeleeThisTurn)
    state.eventLamentation(dieRoll: 5)
    #expect(state.noMeleeThisTurn)
    #expect(state.morale == .normal) // unchanged
  }

}
