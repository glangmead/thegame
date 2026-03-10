//
//  LoDComponentsTests.swift
//  DynamicalSystems
//
//  Tests for LoD components: Tracks, Armies, Heroes, Defenders, Morale, Upgrades, Spells, Time Track, Turn Phases, Greenskin Setup, Winds of Magic, State queries.
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
    // First Dawn, day, day, Twilight, night, night, Dawn, day, day, Twilight, night, night, Dawn, day, day, Final Twilight
    let tt = LoD.timeTrack
    // First Dawn
    #expect(tt[0] == .dawn)
    // Block 1: day, day, twilight, night, night
    #expect(tt[1] == .day)
    #expect(tt[2] == .day)
    #expect(tt[3] == .twilight)
    #expect(tt[4] == .night)
    #expect(tt[5] == .night)
    // Block 2: dawn, day, day, twilight, night, night
    #expect(tt[6] == .dawn)
    #expect(tt[7] == .day)
    #expect(tt[8] == .day)
    #expect(tt[9] == .twilight)
    #expect(tt[10] == .night)
    #expect(tt[11] == .night)
    // Block 3: dawn, day, day, Final Twilight
    #expect(tt[12] == .dawn)
    #expect(tt[13] == .day)
    #expect(tt[14] == .day)
    #expect(tt[15] == .twilight)
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
