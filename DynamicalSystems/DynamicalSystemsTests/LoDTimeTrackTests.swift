//
//  LoDTimeTrackTests.swift
//  DynamicalSystems
//
//  Tests for LoD Time Track Advancement, Twilight Effects, Dawn Effects, Energy capping, Multi-space traversal.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDTimeTrackTests {

  // MARK: - Time Track Advancement (rule 3.1)

  @Test
  func timeAdvanceBasic() {
    // Advance time by 1 from First Dawn (pos 0) → pos 1 (day).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.timePosition == 0)

    state.advanceTime(by: 1)
    #expect(state.timePosition == 1)
    #expect(state.currentTimeSpace == .day)
  }

  @Test
  func timeAdvanceByTwo() {
    // Advance time by 2 from pos 0 → pos 2 (day).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.advanceTime(by: 2)
    #expect(state.timePosition == 2)
  }

  @Test
  func timeAdvanceByZero() {
    // Advance by 0 → no movement.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.advanceTime(by: 0)
    #expect(state.timePosition == 0)
  }

  @Test
  func timeClampedAtFinalTwilight() {
    // Rule 3.1: Time marker can never advance past the Final Twilight (pos 15).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 14

    state.advanceTime(by: 3) // would be 17, clamped to 15
    #expect(state.timePosition == 15)
    #expect(state.isOnFinalTwilight)
  }

  // MARK: - Twilight Effects (rule 3.1.1)

  @Test
  func twilightGrantsArcaneEnergy() {
    // Rule 3.1.1: Entering a twilight space adds +1 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 2) // arcane=4 after wizard bonus
    state.timePosition = 2 // day space, one step before twilight at 3
    let arcaneBefore = state.arcaneEnergy

    state.advanceTime(by: 1) // → pos 3 (twilight)
    #expect(state.timePosition == 3)
    #expect(state.arcaneEnergy == arcaneBefore + 1)
  }

  @Test
  func twilightPlacesTerror() {
    // Rule 3.1.1: Entering a twilight space places Terror army at space 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 2
    #expect(state.armyPosition[.terror] == nil) // Troll not placed yet

    state.advanceTime(by: 1) // → pos 3 (twilight)
    #expect(state.armyPosition[.terror] == 3)
  }

  @Test
  func twilightResetsTerrorPosition() {
    // Terror army already on board at space 2 → twilight resets to space 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 2
    state.armyPosition[.terror] = 2

    state.advanceTime(by: 1) // → twilight
    #expect(state.armyPosition[.terror] == 3)
  }

  // MARK: - Dawn Effects (rule 3.1.2)

  @Test
  func dawnReducesMorale() {
    // Rule 3.1.2: Entering a dawn space reduces morale by one step.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 5 // night space, one step before dawn at 6
    state.morale = .high

    state.advanceTime(by: 1) // → pos 6 (dawn)
    #expect(state.morale == .normal)
  }

  @Test
  func dawnGrantsArcaneEnergy() {
    // Rule 3.1.2: Entering a dawn space adds +1 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 2) // arcane=4
    state.timePosition = 5
    let arcaneBefore = state.arcaneEnergy

    state.advanceTime(by: 1) // → pos 6 (dawn)
    #expect(state.arcaneEnergy == arcaneBefore + 1)
  }

  @Test
  func dawnRemovesTerror() {
    // Rule 3.1.2: Entering a dawn space removes the Terror army.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 5
    state.armyPosition[.terror] = 2 // Terror on board

    state.advanceTime(by: 1) // → pos 6 (dawn)
    #expect(state.armyPosition[.terror] == nil) // removed
  }

  @Test
  func dawnRemovesTerrorSafeWhenNotOnBoard() {
    // Dawn when Terror not on board → no crash.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 5
    #expect(state.armyPosition[.terror] == nil)

    state.advanceTime(by: 1) // → dawn, Terror not on board
    #expect(state.armyPosition[.terror] == nil) // still nil, no crash
  }

  // MARK: - Energy capping

  @Test
  func arcaneEnergyCappedAtSix() {
    // Arcane energy cannot exceed 6 even with twilight/dawn bonuses.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 2
    state.arcaneEnergy = 6

    state.advanceTime(by: 1) // → twilight, +1 arcane
    #expect(state.arcaneEnergy == 6) // capped
  }

  // MARK: - Passing through multiple special spaces

  @Test
  func advanceThroughTwilightAndBeyond() {
    // Advance by 2 from pos 2 → passes through twilight (3), lands on night (4).
    // Twilight effect should trigger at pos 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 2) // arcane=4
    state.timePosition = 2
    let arcaneBefore = state.arcaneEnergy

    state.advanceTime(by: 2) // 2→3 (twilight) → 4 (night)
    #expect(state.timePosition == 4)
    #expect(state.arcaneEnergy == arcaneBefore + 1) // twilight bonus
    #expect(state.armyPosition[.terror] == 3) // Terror placed
  }

  @Test
  func advanceThroughDawnAndBeyond() {
    // Advance by 2 from pos 5 → passes through dawn (6), lands on day (7).
    // Dawn effects should trigger.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 2)
    state.timePosition = 5
    state.morale = .high
    state.armyPosition[.terror] = 2
    let arcaneBefore = state.arcaneEnergy

    state.advanceTime(by: 2) // 5→6 (dawn) →7 (day)
    #expect(state.timePosition == 7)
    #expect(state.morale == .normal) // dawn: -1
    #expect(state.arcaneEnergy == arcaneBefore + 1) // dawn: +1
    #expect(state.armyPosition[.terror] == nil) // dawn: removed
  }

  @Test
  func finalTwilightQuery() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.isOnFinalTwilight)

    state.timePosition = 15
    #expect(state.isOnFinalTwilight)
  }

}
