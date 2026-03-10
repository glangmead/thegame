//
//  LoDArmyTests.swift
//  DynamicalSystems
//
//  Tests for LoD army movement: Army Advancement, Gate Track, Terror and Sky, Time Track Advancement, Twilight Effects, Dawn Effects, Energy capping, Multi-space traversal, Melee Range.
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
    #expect(result == .advanced(.east, from: 6, to: 5))
    #expect(state.armyPosition[.east] == 5)
  }

  @Test
  func advanceToSpace1() {
    // Army at space 2 advances to space 1. No special effect on a wall track
    // (breach only triggers at 1→0).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.advanceArmy(.east)
    #expect(result == .advanced(.east, from: 2, to: 1))
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
    #expect(results[0] == .advanced(.gate1, from: 4, to: 3))
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
    #expect(results[0] == .advanced(.gate2, from: 4, to: 3))
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
    // Rule 8.2.1: Losing a defender moves marker one space left.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenders[.menAtArms] == 3)

    state.loseDefender(.menAtArms)
    #expect(state.defenders[.menAtArms] == 2)

    state.loseDefender(.menAtArms)
    #expect(state.defenders[.menAtArms] == 1)
  }

  @Test
  func defenderCannotGoBelowZero() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.archers] = 0

    state.loseDefender(.archers)
    #expect(state.defenders[.archers] == 0)
  }

  @Test
  func allDefendersLostEndsGame() {
    // Rule 4.4: If all defenders reduced to 0, game immediately ends in a loss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 1

    state.loseDefender(.priests)
    #expect(state.defenders[.priests] == 0)
    #expect(state.allDefendersAtZero)
    #expect(state.ended)
  }

  @Test
  func nonWallTrackAdvanceNormally() {
    // Sky army at space 3 advances to 2 — normal advance, no breach logic.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.sky] = 3

    let result = state.advanceArmy(.sky)
    #expect(result == .advanced(.sky, from: 3, to: 2))
    #expect(state.armyPosition[.sky] == 2)
  }

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
