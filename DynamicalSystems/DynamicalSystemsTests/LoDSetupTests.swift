//
//  LoDSetupTests.swift
//  DynamicalSystems
//
//  Tests for LoD Greenskin Scenario Setup, Winds of Magic, and State queries.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDSetupTests {

  // MARK: - Greenskin Scenario Setup (Scenario 1)

  @Test
  func greenskinArmyPlacement() {
    // Scenario 1: Goblin on East 6, Goblin on West 6, two Orcs on Gate 4,
    // Dragon on Sky 6. Troll set aside (not placed until first twilight).
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    #expect(state.armyType[.east] == .goblin)
    #expect(state.armyType[.west] == .goblin)
    #expect(state.armyType[.gate1] == .orc)
    #expect(state.armyType[.gate2] == .orc)
    #expect(state.armyType[.sky] == .dragon)
    #expect(state.armyType[.terror] == .troll)

    #expect(state.armyPosition[.east] == 6)
    #expect(state.armyPosition[.west] == 6)
    #expect(state.armyPosition[.gate1] == 4)
    #expect(state.armyPosition[.gate2] == 4)
    #expect(state.armyPosition[.sky] == 6)
    // Troll not placed yet
    #expect(state.armyPosition[.terror] == nil)
  }

  @Test
  func greenskinHeroes() {
    // First game default: Warrior, Wizard, Cleric. All in Reserves, unwounded.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    #expect(state.heroLocation.count == 3)
    #expect(state.heroLocation[.warrior] == .reserves)
    #expect(state.heroLocation[.wizard] == .reserves)
    #expect(state.heroLocation[.cleric] == .reserves)
    // Ranger, Rogue, Paladin not in play
    #expect(state.heroLocation[.ranger] == nil)
    #expect(state.heroLocation[.rogue] == nil)
    #expect(state.heroLocation[.paladin] == nil)
    // None wounded or dead
    #expect(state.heroWounded.isEmpty)
    #expect(state.heroDead.isEmpty)
  }

  @Test
  func greenskinDefenders() {
    // All defenders start at maximum (rule 2.0 step 3).
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    #expect(state.defenders[.menAtArms] == 3)
    #expect(state.defenders[.archers] == 2)
    #expect(state.defenders[.priests] == 2)
  }

  @Test
  func greenskinMorale() {
    // Morale starts Normal (rule 6.1.1).
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)
  }

  @Test
  func greenskinTimePosition() {
    // Time marker starts on First Dawn (position 0).
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.timePosition == 0)
    #expect(state.currentTimeSpace == .dawn)
  }

  @Test
  func greenskinNoBoardState() {
    // No breaches, barricades, or upgrades at start.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.breaches.isEmpty)
    #expect(state.barricades.isEmpty)
    #expect(state.upgrades.isEmpty)
  }

  @Test
  func greenskinSpellsAllFaceDown() {
    // All 9 spells start face-down (rule 2.0 step 7).
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus.count == 9)
    for (_, status) in state.spellStatus {
      #expect(status == .faceDown)
    }
  }

  @Test
  func greenskinBloodyBattle() {
    // Bloody battle marker starts in reserves (not on any army).
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.bloodyBattleArmy == nil)
  }

  @Test
  func greenskinPhase() {
    // After setup, game starts in card phase.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.phase == .card)
  }

  // MARK: - Winds of Magic (rule 2.1)

  @Test
  func windsOfMagicWithWizardAndCleric() {
    // Rule 2.1: Roll die → set arcane to result, divine to 6 - result.
    // Then +2 arcane (Wizard), +2 divine (Cleric), clamped at 6.
    // Example: roll 4 → arcane=4, divine=2 → +2 arcane=6, +2 divine=4.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 4)
    #expect(state.arcaneEnergy == 6) // min(4+2, 6)
    #expect(state.divineEnergy == 4) // min(2+2, 6)
  }

  @Test
  func windsOfMagicLowArcane() {
    // Roll 1 → arcane=1, divine=5 → +2 arcane=3, +2 divine=6 (clamped).
    let state = LoD.greenskinSetup(windsOfMagicArcane: 1)
    #expect(state.arcaneEnergy == 3) // min(1+2, 6)
    #expect(state.divineEnergy == 6) // min(5+2, 6)
  }

  @Test
  func windsOfMagicHighArcane() {
    // Roll 5 → arcane=5, divine=1 → +2 arcane=6 (clamped), +2 divine=3.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 5)
    #expect(state.arcaneEnergy == 6) // min(5+2, 6)
    #expect(state.divineEnergy == 3) // min(1+2, 6)
  }

  @Test
  func windsOfMagicWithoutWizard() {
    // No Wizard → no +2 arcane bonus.
    let state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .ranger, .cleric]
    )
    #expect(state.arcaneEnergy == 3) // no wizard bonus
    #expect(state.divineEnergy == 5) // min(3+2, 6)
  }

  @Test
  func windsOfMagicWithoutCleric() {
    // No Cleric → no +2 divine bonus.
    let state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .ranger]
    )
    #expect(state.arcaneEnergy == 5) // min(3+2, 6)
    #expect(state.divineEnergy == 3) // no cleric bonus
  }

  // MARK: - State queries

  @Test
  func allDefendersAtZero() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.allDefendersAtZero)

    // Reduce all to zero
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 0
    #expect(state.allDefendersAtZero)
  }

  @Test
  func allDefendersAtZeroPartial() {
    // If even one defender remains, not all at zero.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 1
    #expect(!state.allDefendersAtZero)
  }

  @Test
  func armyAtSpace1Query() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // No armies at space 1 initially
    #expect(!state.armyAtSpace1(on: .east))

    // Move east army to space 1
    state.armyPosition[.east] = 1
    #expect(state.armyAtSpace1(on: .east))
  }

  @Test
  func livingHeroesQuery() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.livingHeroes.count == 3)

    // Kill a hero
    state.heroDead.insert(.warrior)
    #expect(state.livingHeroes.count == 2)
    #expect(!state.livingHeroes.contains(.warrior))
  }

}
