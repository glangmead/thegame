//
//  LoDRandomSetupTests.swift
//  DynamicalSystems
//
//  Tests for Greenskin Random Set Up table (Scenario 1 card variant).
//

import Testing

@testable import DynamicalSystems

struct LoDRandomSetupTests {

  @Test func greenskinRandomSetupRoll1() {
    // Roll 1: East=Goblin, West=Goblin, Gate=Orc+Orc, Terror=Troll, Sky=Dragon
    let state = LoD.greenskinRandomSetup(
      dieRoll: 1, windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.armyType[.east] == .goblin)
    #expect(state.armyType[.west] == .goblin)
    #expect(state.armyType[.gate1] == .orc)
    #expect(state.armyType[.gate2] == .orc)
    #expect(state.armyType[.terror] == .troll)
    #expect(state.armyType[.sky] == .dragon)
    // Positions unchanged from standard
    #expect(state.armyPosition[.east] == 6)
    #expect(state.armyPosition[.west] == 6)
    #expect(state.armyPosition[.gate1] == 4)
    #expect(state.armyPosition[.gate2] == 4)
    #expect(state.armyPosition[.sky] == 6)
    #expect(state.armyPosition[.terror] == nil) // troll placed at first twilight
  }

  @Test func greenskinRandomSetupRoll2() {
    // Roll 2: East=Orc, West=Goblin, Gate=Orc+Goblin, Terror=Troll, Sky=Dragon
    let state = LoD.greenskinRandomSetup(
      dieRoll: 2, windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.armyType[.east] == .orc)
    #expect(state.armyType[.west] == .goblin)
    #expect(state.armyType[.gate1] == .orc)
    #expect(state.armyType[.gate2] == .goblin)
    #expect(state.armyType[.terror] == .troll)
    #expect(state.armyType[.sky] == .dragon)
  }

  @Test func greenskinRandomSetupRoll3() {
    // Roll 3: East=Goblin, West=Orc, Gate=Orc+Goblin, Terror=Troll, Sky=Dragon
    let state = LoD.greenskinRandomSetup(
      dieRoll: 3, windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.armyType[.east] == .goblin)
    #expect(state.armyType[.west] == .orc)
    #expect(state.armyType[.gate1] == .orc)
    #expect(state.armyType[.gate2] == .goblin)
    #expect(state.armyType[.terror] == .troll)
    #expect(state.armyType[.sky] == .dragon)
  }

  @Test func greenskinRandomSetupRoll4() {
    // Roll 4: East=Orc, West=Orc, Gate=Goblin+Goblin, Terror=Troll, Sky=Dragon
    let state = LoD.greenskinRandomSetup(
      dieRoll: 4, windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.armyType[.east] == .orc)
    #expect(state.armyType[.west] == .orc)
    #expect(state.armyType[.gate1] == .goblin)
    #expect(state.armyType[.gate2] == .goblin)
    #expect(state.armyType[.terror] == .troll)
    #expect(state.armyType[.sky] == .dragon)
  }

  @Test func greenskinRandomSetupRoll5() {
    // Roll 5: East=Goblin, West=Orc, Gate=Orc+Troll, Terror=Orc, Sky=Dragon
    let state = LoD.greenskinRandomSetup(
      dieRoll: 5, windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.armyType[.east] == .goblin)
    #expect(state.armyType[.west] == .orc)
    #expect(state.armyType[.gate1] == .orc)
    #expect(state.armyType[.gate2] == .troll)
    #expect(state.armyType[.terror] == .orc)
    #expect(state.armyType[.sky] == .dragon)
  }

  @Test func greenskinRandomSetupRoll6() {
    // Roll 6: East=Orc, West=Goblin, Gate=Goblin+Troll, Terror=Goblin, Sky=Dragon
    let state = LoD.greenskinRandomSetup(
      dieRoll: 6, windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.armyType[.east] == .orc)
    #expect(state.armyType[.west] == .goblin)
    #expect(state.armyType[.gate1] == .goblin)
    #expect(state.armyType[.gate2] == .troll)
    #expect(state.armyType[.terror] == .goblin)
    #expect(state.armyType[.sky] == .dragon)
  }

  @Test func greenskinRandomSetupPreservesOtherState() {
    // Random setup should have same heroes, energy, morale etc as standard
    let standard = LoD.greenskinSetup(
      windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .cleric]
    )
    let random = LoD.greenskinRandomSetup(
      dieRoll: 1, windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .cleric]
    )
    #expect(random.morale == standard.morale)
    #expect(random.arcaneEnergy == standard.arcaneEnergy)
    #expect(random.divineEnergy == standard.divineEnergy)
    #expect(random.heroLocation == standard.heroLocation)
    #expect(random.defenderPosition == standard.defenderPosition)
  }
}
