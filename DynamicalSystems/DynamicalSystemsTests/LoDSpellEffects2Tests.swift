//
//  LoDSpellEffects2Tests.swift
//  DynamicalSystems
//
//  Tests for LoD spell effects: Slow, Chain Lightning, Divine Wrath, isUndead.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDSpellEffects2Tests {

  // -- Slow --

  @Test
  func slowPlacesMarker() {
    // Normal: place Slow marker on army. Army doesn't move.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    state.applySlow(on: .east)
    #expect(state.slowedArmy == .east)
  }

  @Test
  func slowHeroicRetreatsFirst() {
    // Heroic (∞): retreat army one space, then place marker.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    state.applySlow(on: .east, heroic: true)
    #expect(state.armyPosition[.east] == 4) // retreated from 3 to 4
    #expect(state.slowedArmy == .east)
  }

  @Test
  func slowHeroicRetreatCapped() {
    // Heroic retreat capped at maxSpace.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.east] == 6) // already at max

    state.applySlow(on: .east, heroic: true)
    #expect(state.armyPosition[.east] == 6) // stays at max
    #expect(state.slowedArmy == .east)
  }

  @Test
  func slowedArmySkipsAdvance() {
    // When a slowed army would advance, remove the marker instead.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    state.slowedArmy = .east

    let result = state.advanceArmy(.east)
    #expect(result == .slowMarkerRemoved(.east))
    #expect(state.armyPosition[.east] == 3) // didn't move
    #expect(state.slowedArmy == nil) // marker removed
  }

  @Test
  func slowedArmyThenNormalAdvance() {
    // After slow marker removed, next advance is normal.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    state.slowedArmy = .east

    _ = state.advanceArmy(.east) // removes marker
    let result = state.advanceArmy(.east) // normal advance
    #expect(result == .advanced(.east, from: 3, destination: 2))
  }

  // -- Chain Lightning --

  @Test
  func chainLightningThreeAttacks() {
    // Normal: 3 attacks with +2, +1, +0 DRMs.
    // All targeting Goblin (2) at East 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let results = state.applyChainLightning(targets: [
      (slot: .east, dieRoll: 2), // 2 + 2 = 4 > 2 → hit
      (slot: .east, dieRoll: 2), // 2 + 1 = 3 > 2 → hit
      (slot: .east, dieRoll: 2) // 2 + 0 = 2 ≤ 2 → miss
    ])
    #expect(results.count == 3)
    // First hit pushes from 3→4, second from 4→5, third misses
    #expect(results[2] == .miss(.east))
  }

  @Test
  func chainLightningHeroicBetterDRMs() {
    // Heroic (∞): 3 attacks with +3, +2, +1 DRMs.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let results = state.applyChainLightning(
      targets: [
        (slot: .east, dieRoll: 2), // 2 + 3 = 5 > 2 → hit
        (slot: .east, dieRoll: 2), // 2 + 2 = 4 > 2 → hit
        (slot: .east, dieRoll: 2) // 2 + 1 = 3 > 2 → hit
      ],
      heroic: true
    )
    #expect(results.count == 3)
    // All three should hit
    for result in results {
      switch result {
      case .hit: break // expected
      default: #expect(Bool(false), "Expected hit")
      }
    }
  }

  // -- Divine Wrath --

  @Test
  func divineWrathOneAttack() {
    // Normal: 1 magical attack with +1 DRM. Goblin (2) at East 3.
    // Roll 3 + 1 = 4 > 2 → hit, pushed to 4.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 3)
    ])
    #expect(results.count == 1)
    #expect(results[0] == .hit(.east, pushedFrom: 3, pushedTo: 4))
    // Goblin is not undead → no extra retreat
    #expect(state.armyPosition[.east] == 4)
  }

  @Test
  func divineWrathUndeadExtraRetreat() {
    // Undead army gets pushed back an extra space.
    // Set up an undead scenario: zombie (strength 3) on east.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyType[.east] = .zombie
    state.armyPosition[.east] = 3

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 4) // 4 + 1 = 5 > 3 → hit
    ])
    #expect(results.count == 1)
    // Normal push: 3→4. Undead bonus: 4→5. So army ends at 5.
    #expect(state.armyPosition[.east] == 5)
  }

  @Test
  func divineWrathUndeadRetreatCapped() {
    // Undead extra retreat capped at maxSpace.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyType[.east] = .zombie
    state.armyPosition[.east] = 5

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 4) // hit → push 5→6, undead +1 → capped at 6
    ])
    #expect(results.count == 1)
    #expect(state.armyPosition[.east] == 6)
  }

  @Test
  func divineWrathHeroicTwoAttacks() {
    // Heroic (†): 2 attacks on different targets.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3 // Goblin (2)
    state.armyPosition[.west] = 3 // Goblin (2)

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 3), // 3 + 1 = 4 > 2 → hit
      (slot: .west, dieRoll: 3) // 3 + 1 = 4 > 2 → hit
    ])
    #expect(results.count == 2)
    #expect(state.armyPosition[.east] == 4)
    #expect(state.armyPosition[.west] == 4)
  }

  @Test
  func divineWrathMissNoRetreat() {
    // Miss → no push, no undead bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyType[.east] = .zombie
    state.armyPosition[.east] = 3

    let results = state.applyDivineWrath(targets: [
      (slot: .east, dieRoll: 2) // 2 + 1 = 3 ≤ 3 → miss
    ])
    #expect(results[0] == .miss(.east))
    #expect(state.armyPosition[.east] == 3) // unchanged
  }

  // -- Army type: isUndead --

  @Test
  func armyTypeUndead() {
    #expect(!LoD.ArmyType.goblin.isUndead)
    #expect(!LoD.ArmyType.orc.isUndead)
    #expect(!LoD.ArmyType.dragon.isUndead)
    #expect(!LoD.ArmyType.troll.isUndead)
    #expect(LoD.ArmyType.zombie.isUndead)
    #expect(LoD.ArmyType.skeletalRider.isUndead)
    #expect(LoD.ArmyType.wraith.isUndead)
    #expect(LoD.ArmyType.nightmare.isUndead)
  }

}
