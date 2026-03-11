//
//  LoDArmyTests.swift
//  DynamicalSystems
//
//  Tests for LoD army movement: Army Advancement, Gate Track,
//  Terror and Sky, Time Track Advancement, Twilight Effects,
//  Dawn Effects, Energy capping, Multi-space traversal, Melee Range.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDArmyTests {

  // MARK: - Army Advancement (rule 4.1)

  @Test
  func basicArmyAdvance() {
    // Army at space 6 advances one space toward castle → space 5.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.east] == 6)

    let result = state.advanceArmy(.east)
    #expect(result == .advanced(.east, from: 6, destination: 5))
    #expect(state.armyPosition[.east] == 5)
  }

  @Test
  func advanceToSpace1() {
    // Army at space 2 advances to space 1. No special effect on a wall track
    // (breach only triggers at 1→0).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.advanceArmy(.east)
    #expect(result == .advanced(.east, from: 2, destination: 1))
    #expect(state.armyPosition[.east] == 1)
    #expect(state.breaches.isEmpty)
  }

  @Test
  func wallTrackBreachCreated() {
    // Rule 4.1.2: First advance from space 1 to 0 on a wall track creates a breach.
    // Army stays at space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1

    let result = state.advanceArmy(.east)
    #expect(result == .breachCreated(.east))
    #expect(state.armyPosition[.east] == 1) // army stays
    #expect(state.breaches.contains(.east))
    #expect(!state.ended)
  }

  @Test
  func breachRemovesUpgrade() {
    // Rule 4.1.2: When breach is created, remove any upgrade on that track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1
    state.upgrades[.east] = .oil

    let result = state.advanceArmy(.east)
    #expect(result == .breachCreated(.east))
    #expect(state.upgrades[.east] == nil) // upgrade removed
    #expect(state.breaches.contains(.east))
  }

  @Test
  func advanceThroughBreach() {
    // Rule 4.1.2: With existing breach, army advances to space 0 → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1
    state.breaches.insert(.east)

    let result = state.advanceArmy(.east)
    #expect(result == .armyEnteredCastle(.east))
    #expect(state.armyPosition[.east] == 0)
    #expect(state.ended)
  }

  @Test
  func barricadeHolds() {
    // Rule 4.1.3: Barricade test — die roll > army strength.
    // Barricade flips to breach, army stays at space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1
    state.barricades.insert(.east) // East has Goblin (strength 2)

    let result = state.advanceArmy(.east, dieRoll: 5) // 5 > 2
    #expect(result == .barricadeHeld(.east))
    #expect(state.armyPosition[.east] == 1) // army stays
    #expect(!state.barricades.contains(.east)) // barricade gone
    #expect(state.breaches.contains(.east)) // flipped to breach
    #expect(!state.ended)
  }

  @Test
  func barricadeFails() {
    // Rule 4.1.3: Barricade test — die roll ≤ army strength → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1
    state.barricades.insert(.east) // Goblin strength 2

    let result = state.advanceArmy(.east, dieRoll: 2) // 2 ≤ 2
    #expect(result == .armyBrokeBarricade(.east))
    #expect(state.armyPosition[.east] == 0)
    #expect(state.ended)
  }

  // MARK: - Gate Track (rule 4.1.1)

  @Test
  func gateFarthestAdvancesFirst() {
    // Rule 4.1.1: The farthest (highest space) Gate army advances first.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 4
    state.armyPosition[.gate2] = 3

    let results = state.advanceArmyOnTrack(.gate)
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.gate1, from: 4, destination: 3))
    #expect(state.armyPosition[.gate1] == 3)
    #expect(state.armyPosition[.gate2] == 3) // unchanged
  }

  @Test
  func gateTiedAdvanceTogether() {
    // Rule 4.1.1: If both Gate armies on same space, advance both together.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3

    let results = state.advanceArmyOnTrack(.gate)
    #expect(results.count == 2)
    #expect(state.armyPosition[.gate1] == 2)
    #expect(state.armyPosition[.gate2] == 2)
  }

  @Test
  func gateSecondArmyFarther() {
    // gate2 is farther than gate1 → gate2 advances.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 4

    let results = state.advanceArmyOnTrack(.gate)
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.gate2, from: 4, destination: 3))
    #expect(state.armyPosition[.gate1] == 2) // unchanged
    #expect(state.armyPosition[.gate2] == 3)
  }

  // MARK: - Terror and Sky (rule 4.4)

  @Test
  func skyArmyCannotEnterCastle() {
    // Rule 4.4: Sky army at space 1 stays at 1, causes defender loss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.sky] = 1

    let result = state.advanceArmy(.sky)
    #expect(result == .defenderLoss)
    #expect(state.armyPosition[.sky] == 1) // stays
    #expect(!state.ended)
  }

  @Test
  func terrorArmyCannotEnterCastle() {
    // Rule 4.4: Terror army at space 1 stays at 1, causes defender loss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.terror] = 1

    let result = state.advanceArmy(.terror)
    #expect(result == .defenderLoss)
    #expect(state.armyPosition[.terror] == 1) // stays
  }

  @Test
  func terrorNotOnBoard() {
    // Troll not placed yet → advance has no effect.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.terror] == nil)

    let result = state.advanceArmy(.terror)
    #expect(result == .notOnBoard)
  }

  @Test
  func defenderLossReducesCount() {
    // Rule 8.2.1: Losing a defender increments track position.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenderPosition[.menAtArms] == 0)
    #expect(state.defenderValue(for: .menAtArms) == 3)

    state.loseDefender(.menAtArms)
    #expect(state.defenderPosition[.menAtArms] == 1)
    #expect(state.defenderValue(for: .menAtArms) == 2)

    state.loseDefender(.menAtArms)
    #expect(state.defenderPosition[.menAtArms] == 2)
    #expect(state.defenderValue(for: .menAtArms) == 2)
  }

  @Test
  func defenderCannotGoBelowZero() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenderPosition[.archers] = 4 // lastPosition, value 0

    state.loseDefender(.archers)
    #expect(state.defenderPosition[.archers] == 4) // stays at lastPosition
  }

  @Test
  func allDefendersLostEndsGame() {
    // Rule 4.4: If all defenders at lastPosition, game immediately ends in a loss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenderPosition[.menAtArms] = 5 // lastPosition, value 0
    state.defenderPosition[.archers] = 4   // lastPosition, value 0
    state.defenderPosition[.priests] = 2   // value 1, one step from lastPosition

    state.loseDefender(.priests)
    #expect(state.defenderPosition[.priests] == 3) // lastPosition
    #expect(state.allDefendersAtZero)
    #expect(state.ended)
  }

  @Test
  func defenderLossTrackProgression() {
    // Rule 8.2: losing fighters goes 3->2->2->2->1->0
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenderValue(for: .menAtArms) == 3)
    state.loseDefender(.menAtArms)
    #expect(state.defenderValue(for: .menAtArms) == 2)
    state.loseDefender(.menAtArms)
    #expect(state.defenderValue(for: .menAtArms) == 2) // still 2!
    state.loseDefender(.menAtArms)
    #expect(state.defenderValue(for: .menAtArms) == 2) // still 2!
    state.loseDefender(.menAtArms)
    #expect(state.defenderValue(for: .menAtArms) == 1)
    state.loseDefender(.menAtArms)
    #expect(state.defenderValue(for: .menAtArms) == 0)
  }

  @Test
  func defenderGainTrackProgression() {
    // Gaining from worst position back to best
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenderPosition[.menAtArms] = LoD.DefenderType.menAtArms.lastPosition
    #expect(state.defenderValue(for: .menAtArms) == 0)
    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenderValue(for: .menAtArms) == 1)
    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenderValue(for: .menAtArms) == 2)
    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenderValue(for: .menAtArms) == 2) // still 2
    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenderValue(for: .menAtArms) == 2) // still 2
    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenderValue(for: .menAtArms) == 3)
    // At position 0 now — gain should clamp
    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenderValue(for: .menAtArms) == 3)
    #expect(state.defenderPosition[.menAtArms] == 0)
  }

  @Test
  func nonWallTrackAdvanceNormally() {
    // Sky army at space 3 advances to 2 — normal advance, no breach logic.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.sky] = 3

    let result = state.advanceArmy(.sky)
    #expect(result == .advanced(.sky, from: 3, destination: 2))
    #expect(state.armyPosition[.sky] == 2)
  }

}
