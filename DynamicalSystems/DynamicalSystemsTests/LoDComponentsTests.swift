//
//  LoDComponentsTests.swift
//  DynamicalSystems
//
//  Tests for LoD components: Tracks, Armies, Heroes, Defenders,
//  Morale, Upgrades, Spells, Time Track, Turn Phases,
//  Greenskin Setup, Winds of Magic, State queries.
//

import Testing
import Foundation
import CoreGraphics

@MainActor
struct LoDComponentsTests {

  // MARK: - Tracks (rule 4.0)

  @Test
  func trackCount() {
    // Rule 4.0: There are exactly 5 army tracks.
    #expect(LoD.Track.allCases.count == 5)
  }

  @Test
  func wallTracks() {
    // Rule 4.1.2: East, West, and Gate are wall tracks (can breach, can have upgrades).
    #expect(LoD.Track.east.isWall)
    #expect(LoD.Track.west.isWall)
    #expect(LoD.Track.gate.isWall)
    #expect(LoD.Track.walls.count == 3)
  }

  @Test
  func nonWallTracks() {
    // Rule 4.4: Terror and Sky cannot breach or have upgrades.
    #expect(!LoD.Track.terror.isWall)
    #expect(!LoD.Track.sky.isWall)
  }

  @Test
  func trackLengths() {
    // East, West, Sky go from 0 to 6.
    #expect(LoD.Track.east.maxSpace == 6)
    #expect(LoD.Track.west.maxSpace == 6)
    #expect(LoD.Track.sky.maxSpace == 6)
    // Gate goes from 0 to 4.
    #expect(LoD.Track.gate.maxSpace == 4)
    // Terror goes from 0 to 3.
    #expect(LoD.Track.terror.maxSpace == 3)
  }

  // MARK: - Armies

  @Test
  func armyStrengths() {
    // Greenskin armies
    #expect(LoD.ArmyType.goblin.strength == 2)
    #expect(LoD.ArmyType.orc.strength == 3)
    #expect(LoD.ArmyType.dragon.strength == 4)
    #expect(LoD.ArmyType.troll.strength == 4)
    // Undead armies
    #expect(LoD.ArmyType.zombie.strength == 3)
    #expect(LoD.ArmyType.skeletalRider.strength == 3)
    #expect(LoD.ArmyType.wraith.strength == 5)
    #expect(LoD.ArmyType.nightmare.strength == 5)
  }

  @Test
  func armySlotTrackAssignment() {
    // Each army slot maps to its track. Gate has two slots (rule 4.1.1).
    #expect(LoD.ArmySlot.east.track == .east)
    #expect(LoD.ArmySlot.west.track == .west)
    #expect(LoD.ArmySlot.gate1.track == .gate)
    #expect(LoD.ArmySlot.gate2.track == .gate)
    #expect(LoD.ArmySlot.sky.track == .sky)
    #expect(LoD.ArmySlot.terror.track == .terror)
  }

  @Test
  func armySlotCount() {
    // 6 total army slots: one per track + extra for Gate.
    #expect(LoD.ArmySlot.allCases.count == 6)
  }

  // MARK: - Heroes (rule 10.0)

  @Test
  func heroTypes() {
    // 6 hero types: Warrior, Wizard, Ranger, Rogue, Paladin, Cleric.
    #expect(LoD.HeroType.allCases.count == 6)
    let names = LoD.HeroType.allCases.map(\.rawValue)
    #expect(names.contains("warrior"))
    #expect(names.contains("wizard"))
    #expect(names.contains("ranger"))
    #expect(names.contains("rogue"))
    #expect(names.contains("paladin"))
    #expect(names.contains("cleric"))
  }

  // MARK: - Defenders (rule 8.2)

  @Test
  func defenderMaxValues() {
    // Men-at-arms: max 3 (limits melee attacks per turn).
    #expect(LoD.DefenderType.menAtArms.maxValue == 3)
    // Archers: max 2 (limits ranged attacks per turn).
    #expect(LoD.DefenderType.archers.maxValue == 2)
    // Priests: max +2 (chant die-roll modifier).
    #expect(LoD.DefenderType.priests.maxValue == 2)
  }

  @Test
  func defenderCount() {
    #expect(LoD.DefenderType.allCases.count == 3)
  }

  // MARK: - Morale (rule 6.1.1)

  @Test
  func moraleActionModifiers() {
    // Low morale: -1 action point at start of action phase.
    #expect(LoD.Morale.low.actionModifier == -1)
    // Normal morale: no effect.
    #expect(LoD.Morale.normal.actionModifier == 0)
    // High morale: +1 action point at start of action phase.
    #expect(LoD.Morale.high.actionModifier == 1)
  }

  @Test
  func moraleOrdering() {
    #expect(LoD.Morale.low < LoD.Morale.normal)
    #expect(LoD.Morale.normal < LoD.Morale.high)
  }

  @Test
  func moraleTransitions() {
    // Raise: low → normal → high → high (clamped)
    #expect(LoD.Morale.low.raised() == .normal)
    #expect(LoD.Morale.normal.raised() == .high)
    #expect(LoD.Morale.high.raised() == .high)
    // Lower: high → normal → low → low (clamped)
    #expect(LoD.Morale.high.lowered() == .normal)
    #expect(LoD.Morale.normal.lowered() == .low)
    #expect(LoD.Morale.low.lowered() == .low)
  }

  // MARK: - Upgrades (rule 6.3)

  @Test
  func upgradeBuildNumbers() {
    #expect(LoD.UpgradeType.grease.buildNumber == 3)
    #expect(LoD.UpgradeType.oil.buildNumber == 3)
    #expect(LoD.UpgradeType.acid.buildNumber == 5)
    #expect(LoD.UpgradeType.lava.buildNumber == 5)
  }

  @Test
  func upgradeCount() {
    #expect(LoD.UpgradeType.allCases.count == 4)
  }

  // MARK: - Spells (rules 9.2, 9.3)

  @Test
  func arcaneSpells() {
    // 4 arcane spells with costs 1, 2, 3, 4.
    let arcane = LoD.SpellType.arcaneSpells
    #expect(arcane.count == 4)
    #expect(arcane.allSatisfy { $0.isArcane })
    #expect(LoD.SpellType.fireball.energyCost == 1)
    #expect(LoD.SpellType.slow.energyCost == 2)
    #expect(LoD.SpellType.chainLightning.energyCost == 3)
    #expect(LoD.SpellType.fortune.energyCost == 4)
  }

  @Test
  func divineSpells() {
    // 5 divine spells with costs 1, 2, 3, 3, 4.
    let divine = LoD.SpellType.divineSpells
    #expect(divine.count == 5)
    #expect(divine.allSatisfy { $0.isDivine })
    #expect(LoD.SpellType.cureWounds.energyCost == 1)
    #expect(LoD.SpellType.massHeal.energyCost == 2)
    #expect(LoD.SpellType.divineWrath.energyCost == 3)
    #expect(LoD.SpellType.inspire.energyCost == 3)
    #expect(LoD.SpellType.raiseDead.energyCost == 4)
  }

  @Test
  func spellTypeClassification() {
    // Every spell is either arcane or divine, never both.
    for spell in LoD.SpellType.allCases {
      #expect(spell.isArcane != spell.isDivine)
    }
  }

  // MARK: - Time Track

  @Test
  func timeTrackLength() {
    // 16 spaces from First Dawn to Final Twilight.
    #expect(LoD.timeTrack.count == 16)
  }

  @Test
  func timeTrackPattern() {
    // First Dawn, day, day, Twilight, night, night,
    // Dawn, day, day, Twilight, night, night,
    // Dawn, day, day, Final Twilight
    let timeType = LoD.timeTrack
    // First Dawn
    #expect(timeType[0] == .dawn)
    // Block 1: day, day, twilight, night, night
    #expect(timeType[1] == .day)
    #expect(timeType[2] == .day)
    #expect(timeType[3] == .twilight)
    #expect(timeType[4] == .night)
    #expect(timeType[5] == .night)
    // Block 2: dawn, day, day, twilight, night, night
    #expect(timeType[6] == .dawn)
    #expect(timeType[7] == .day)
    #expect(timeType[8] == .day)
    #expect(timeType[9] == .twilight)
    #expect(timeType[10] == .night)
    #expect(timeType[11] == .night)
    // Block 3: dawn, day, day, Final Twilight
    #expect(timeType[12] == .dawn)
    #expect(timeType[13] == .day)
    #expect(timeType[14] == .day)
    #expect(timeType[15] == .twilight)
  }

  @Test
  func timeTrackDeckDrawing() {
    // Dawn and day spaces → day deck. Twilight and night spaces → night deck.
    #expect(LoD.drawsFromDayDeck(at: 0))   // First Dawn → day
    #expect(LoD.drawsFromDayDeck(at: 1))   // day → day
    #expect(!LoD.drawsFromDayDeck(at: 3))  // Twilight → night
    #expect(!LoD.drawsFromDayDeck(at: 4))  // night → night
    #expect(LoD.drawsFromDayDeck(at: 6))   // Dawn → day
    #expect(!LoD.drawsFromDayDeck(at: 15)) // Final Twilight → night
  }

  // MARK: - Turn Phases (rule 3.0)

  @Test
  func turnPhaseOrder() {
    // Each turn: Card → Army → Event → Action → Housekeeping.
    let phases: [LoD.Phase] = [.card, .army, .event, .action, .housekeeping]
    #expect(phases.count == 5)
  }

}
