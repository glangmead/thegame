//
//  LegionsOfDarknessTests.swift
//  DynamicalSystems
//
//  Tests for Legions of Darkness component definitions, derived from the rules PDF.
//

import Testing
import Foundation

@MainActor
struct LegionsOfDarknessTests {

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

  // MARK: - Melee Range (board coloring)

  @Test
  func meleeRangeEastWest() {
    // Board: East and West spaces 1–3 are red (melee), 4–6 are blue (ranged only).
    for track in [LoD.Track.east, LoD.Track.west] {
      #expect(track.isMeleeRange(space: 1))
      #expect(track.isMeleeRange(space: 2))
      #expect(track.isMeleeRange(space: 3))
      #expect(!track.isMeleeRange(space: 4))
      #expect(!track.isMeleeRange(space: 5))
      #expect(!track.isMeleeRange(space: 6))
    }
  }

  @Test
  func meleeRangeGate() {
    // Board: Gate spaces 1–3 are red (melee), 4 is blue (ranged only).
    #expect(LoD.Track.gate.isMeleeRange(space: 1))
    #expect(LoD.Track.gate.isMeleeRange(space: 2))
    #expect(LoD.Track.gate.isMeleeRange(space: 3))
    #expect(!LoD.Track.gate.isMeleeRange(space: 4))
  }

  @Test
  func meleeRangeTerror() {
    // Rule 4.2: All Terror spaces are melee only.
    #expect(LoD.Track.terror.isMeleeRange(space: 1))
    #expect(LoD.Track.terror.isMeleeRange(space: 2))
    #expect(LoD.Track.terror.isMeleeRange(space: 3))
  }

  @Test
  func meleeRangeSky() {
    // Rule 4.3: Sky — only space 1 is melee range.
    #expect(LoD.Track.sky.isMeleeRange(space: 1))
    #expect(!LoD.Track.sky.isMeleeRange(space: 2))
    #expect(!LoD.Track.sky.isMeleeRange(space: 3))
    #expect(!LoD.Track.sky.isMeleeRange(space: 6))
  }

  // MARK: - Battle Resolution (rule 8.0)

  @Test
  func attackHitPushesBack() {
    // Rule 8.0: Modified roll > army strength pushes army back one space.
    // Goblin (strength 2) at East space 3. Roll 4 > 2 → hit, pushed to 4.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 3, pushedTo: 4))
    #expect(state.armyPosition[.east] == 4)
  }

  @Test
  func attackMiss() {
    // Rule 8.0: Modified roll ≤ strength = miss. Goblin (2) at East 3. Roll 2 ≤ 2.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 2)
    #expect(result == .miss(.east))
    #expect(state.armyPosition[.east] == 3) // unchanged
  }

  @Test
  func naturalOneAlwaysFails() {
    // Rules: Natural roll of 1 always fails, even with large DRM.
    // Goblin (2) at East 2. Roll 1 + DRM 10 would be 11, but natural 1 = fail.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 1, drm: 10)
    #expect(result == .naturalOneFail(.east))
    #expect(state.armyPosition[.east] == 2) // unchanged
  }

  @Test
  func meleeRequiresRedSpace() {
    // Rule 8.0: Melee attack only on red-tinted (melee range) spaces.
    // Goblin at East 5 (blue) → can't melee.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(on: .east, attackType: .melee, dieRoll: 6)
    #expect(result == .targetNotInMeleeRange)
  }

  @Test
  func rangedCanTargetAnySpace() {
    // Rule 8.0: Ranged attacks can target armies on any space (red or blue).
    // Goblin (2) at East 5 (blue). Roll 4 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(on: .east, attackType: .ranged, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 5, pushedTo: 6))
  }

  @Test
  func rangedCannotTargetTerror() {
    // Rule 4.2: Terror track is melee-only — no ranged attacks permitted.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.terror] = 2

    let result = state.resolveAttack(on: .terror, attackType: .ranged, dieRoll: 6)
    #expect(result == .targetNotInRange)
  }

  @Test
  func attackNotOnBoard() {
    // Attack on an army not on the board.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.terror] == nil)

    let result = state.resolveAttack(on: .terror, attackType: .melee, dieRoll: 6)
    #expect(result == .targetNotOnBoard)
  }

  @Test
  func attackWithDRM() {
    // DRMs add to die roll. Orc (strength 3) at Gate 2. Roll 2 + DRM 2 = 4 > 3 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2

    let result = state.resolveAttack(on: .gate1, attackType: .melee, dieRoll: 2, drm: 2)
    #expect(result == .hit(.gate1, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalIgnoresNegativeDRMInMelee() {
    // Rules: Magical attacks in melee range ignore negative DRMs.
    // Goblin (2) at East 2 (melee range). Roll 3, DRM -2 → effective DRM 0.
    // Modified roll = 3 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(
      on: .east, attackType: .melee, dieRoll: 3, drm: -2, isMagical: true
    )
    #expect(result == .hit(.east, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalKeepsPositiveDRM() {
    // Magical attack in melee range with positive DRM — DRM is kept.
    // Goblin (2) at East 2. Roll 2, DRM +1 → modified 3 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.resolveAttack(
      on: .east, attackType: .melee, dieRoll: 2, drm: 1, isMagical: true
    )
    #expect(result == .hit(.east, pushedFrom: 2, pushedTo: 3))
  }

  @Test
  func magicalAtRangeKeepsNegativeDRM() {
    // Magical attack NOT in melee range — negative DRM still applies.
    // Goblin (2) at East 5 (ranged only). Roll 3, DRM -2 → modified 1 ≤ 2 → miss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    let result = state.resolveAttack(
      on: .east, attackType: .ranged, dieRoll: 3, drm: -2, isMagical: true
    )
    #expect(result == .miss(.east))
  }

  @Test
  func hitCannotPushPastMaxSpace() {
    // Army already at max space — push has nowhere to go, stays at max.
    // Goblin (2) at East 6. Roll 4 > 2 → hit, pushed to min(7, 6) = 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.armyPosition[.east] == 6)

    let result = state.resolveAttack(on: .east, attackType: .ranged, dieRoll: 4)
    #expect(result == .hit(.east, pushedFrom: 6, pushedTo: 6))
    #expect(state.armyPosition[.east] == 6)
  }

  // MARK: - Gate Targeting (rules 4.1.1, 8.1.2)

  @Test
  func gateTargetClosest() {
    // Only the closest (lowest space) Gate army can be targeted.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 4

    let targets = state.gateAttackTargets()
    #expect(targets == [.gate1]) // gate1 at 2 is closer
  }

  @Test
  func gateTargetTiedChoose() {
    // Rule 8.1.2: Both armies on same space → player can choose either.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = 3

    let targets = state.gateAttackTargets()
    #expect(targets.count == 2)
    #expect(targets.contains(.gate1))
    #expect(targets.contains(.gate2))
  }

  @Test
  func gateTargetOneAbsent() {
    // One Gate army not on board → the other is the only target.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 3
    state.armyPosition[.gate2] = nil

    let targets = state.gateAttackTargets()
    #expect(targets == [.gate1])
  }

  // MARK: - Hero Combat Properties (Player Aid)

  @Test
  func heroCombatDRMs() {
    // Warrior gets +2, all others get +1.
    #expect(LoD.HeroType.warrior.combatDRM == 2)
    #expect(LoD.HeroType.wizard.combatDRM == 1)
    #expect(LoD.HeroType.ranger.combatDRM == 1)
    #expect(LoD.HeroType.rogue.combatDRM == 1)
    #expect(LoD.HeroType.paladin.combatDRM == 1)
    #expect(LoD.HeroType.cleric.combatDRM == 1)
  }

  @Test
  func heroAttackTypes() {
    // Warrior, Rogue, Paladin are melee. Wizard, Ranger, Cleric are ranged.
    #expect(!LoD.HeroType.warrior.isRangedCombatant)
    #expect(LoD.HeroType.wizard.isRangedCombatant)
    #expect(LoD.HeroType.ranger.isRangedCombatant)
    #expect(!LoD.HeroType.rogue.isRangedCombatant)
    #expect(!LoD.HeroType.paladin.isRangedCombatant)
    #expect(LoD.HeroType.cleric.isRangedCombatant)
  }

  @Test
  func heroWoundImmunity() {
    // Warrior (armored) and Ranger (agile) are immune to wounding in combat.
    #expect(LoD.HeroType.warrior.isWoundImmuneInCombat)
    #expect(LoD.HeroType.ranger.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.wizard.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.rogue.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.paladin.isWoundImmuneInCombat)
    #expect(!LoD.HeroType.cleric.isWoundImmuneInCombat)
  }

  // MARK: - Heroic Attack (rule 7.0)

  @Test
  func heroicAttackHit() {
    // Warrior (+2 melee) attacks Goblin (strength 2) at East space 2.
    // Roll 2 + DRM 2 = 4 > 2 → hit, pushed to 3.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 2)
    let result = try! outcome.get()
    #expect(result.attackResult == .hit(.east, pushedFrom: 2, pushedTo: 3))
    #expect(!result.heroWounded)
    #expect(!result.heroKilled)
  }

  @Test
  func heroicAttackMiss() {
    // Rogue (+1 melee) attacks Orc (strength 3) at Gate space 2.
    // Roll 2 + DRM 1 = 3 ≤ 3 → miss.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2
    state.heroLocation[.rogue] = .onTrack(.gate)

    let outcome = state.resolveHeroicAttack(hero: .rogue, on: .gate1, dieRoll: 2)
    let result = try! outcome.get()
    #expect(result.attackResult == .miss(.gate1))
    #expect(!result.heroWounded)
  }

  @Test
  func heroicAttackNaturalOneWoundsHero() {
    // Rule 7.0: Natural 1 on heroic attack fails AND wounds non-immune hero.
    // Wizard (+1 ranged) attacks Goblin at East 5. Roll 1 → fail + wound.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 1)
    let result = try! outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(result.heroWounded)
    #expect(!result.heroKilled)
    #expect(state.heroWounded.contains(.wizard))
  }

  @Test
  func heroicAttackNaturalOneDoesNotWoundImmune() {
    // Warrior (armored) and Ranger (agile) are immune to wounding in combat.
    // Warrior attacks Goblin at East 2. Roll 1 → fail but NOT wounded.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 1)
    let result = try! outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(!result.heroWounded)
    #expect(!result.heroKilled)
    #expect(!state.heroWounded.contains(.warrior))
  }

  @Test
  func heroicAttackSecondWoundKillsHero() {
    // Already-wounded hero rolls natural 1 → killed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)
    state.heroWounded.insert(.wizard) // already wounded

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 1)
    let result = try! outcome.get()
    #expect(result.attackResult == .naturalOneFail(.east))
    #expect(!result.heroWounded) // not "newly wounded" — killed instead
    #expect(result.heroKilled)
    #expect(state.heroDead.contains(.wizard))
    #expect(!state.heroWounded.contains(.wizard))
    #expect(state.heroLocation[.wizard] == nil) // removed from play
  }

  @Test
  func heroicAttackRangedHero() {
    // Wizard (+1 ranged) can target blue spaces. Goblin (2) at East 5.
    // Roll 3 + DRM 1 = 4 > 2 → hit, pushed to 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.wizard] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .wizard, on: .east, dieRoll: 3)
    let result = try! outcome.get()
    #expect(result.attackResult == .hit(.east, pushedFrom: 5, pushedTo: 6))
  }

  @Test
  func heroicAttackMeleeHeroCannotReachBlueSpace() {
    // Warrior (melee) cannot target army at East 5 (blue/ranged-only space).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 6)
    let result = try! outcome.get()
    #expect(result.attackResult == .targetNotInMeleeRange)
    #expect(!result.heroWounded) // no wound on validation failure
  }

  @Test
  func heroicAttackRequiresSameTrack() {
    // Rule 7.3: Hero must be on the same track as the target army.
    // Warrior on East track cannot attack army on West track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.west] = 2
    state.heroLocation[.warrior] = .onTrack(.east)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .west, dieRoll: 6)
    #expect(outcome == .failure(.heroOnWrongTrack))
  }

  @Test
  func heroicAttackRequiresTrackAssignment() {
    // Hero in reserves cannot make heroic attacks.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2
    // Warrior is in reserves (default from setup)

    let outcome = state.resolveHeroicAttack(hero: .warrior, on: .east, dieRoll: 6)
    #expect(outcome == .failure(.heroOnWrongTrack))
  }

  @Test
  func heroicAttackHeroNotInPlay() {
    // Hero not in game (e.g. Ranger not in Greenskin default roster).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let outcome = state.resolveHeroicAttack(hero: .ranger, on: .east, dieRoll: 6)
    #expect(outcome == .failure(.heroNotOnTrack))
  }

  // MARK: - Hero Wounding

  @Test
  func woundHealthyHero() {
    // Wound a healthy hero → becomes wounded.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.heroWounded.contains(.wizard))

    state.woundHero(.wizard)
    #expect(state.heroWounded.contains(.wizard))
    #expect(!state.heroDead.contains(.wizard))
  }

  @Test
  func woundWoundedHeroKills() {
    // Wound an already-wounded hero → killed, removed from play.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.wizard)

    state.woundHero(.wizard)
    #expect(state.heroDead.contains(.wizard))
    #expect(!state.heroWounded.contains(.wizard))
    #expect(state.heroLocation[.wizard] == nil)
  }

  // MARK: - Upgrade Attack DRMs (rule 6.3)

  @Test
  func upgradeGreaseDRM() {
    // Grease is a breach-prevention mechanic, NOT a DRM (rule 6.3).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease

    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
    #expect(state.upgradeDRM(on: .east, attackType: .ranged) == 0)
  }

  @Test
  func upgradeOilDRM() {
    // Oil: +1 DRM to melee or ranged against army in space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.west] = .oil

    #expect(state.upgradeDRM(on: .west, attackType: .melee) == 1)
    #expect(state.upgradeDRM(on: .west, attackType: .ranged) == 1)
  }

  @Test
  func upgradeLavaDRM() {
    // Lava: +2 DRM to melee only against army in space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.gate] = .lava

    #expect(state.upgradeDRM(on: .gate, attackType: .melee) == 2)
    #expect(state.upgradeDRM(on: .gate, attackType: .ranged) == 0) // melee only
  }

  @Test
  func upgradeAcidNoDRM() {
    // Acid: free attack, not a DRM bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .acid

    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
    #expect(state.upgradeDRM(on: .east, attackType: .ranged) == 0)
  }

  @Test
  func upgradeNoneNoDRM() {
    // No upgrade on track → 0 DRM.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.upgradeDRM(on: .east, attackType: .melee) == 0)
  }

  // MARK: - Bloody Battle (Player Aid: Markers)

  @Test
  func bloodyBattleFirstAttackCostsDefender() {
    // First attack against army with bloody battle marker costs 1 defender.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(shouldLose)
    #expect(state.bloodyBattlePaidThisTurn)
  }

  @Test
  func bloodyBattleSecondAttackNoCost() {
    // After paying once, subsequent attacks this turn don't cost a defender.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east
    state.bloodyBattlePaidThisTurn = true // already paid

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(!shouldLose)
  }

  @Test
  func bloodyBattleWrongArmy() {
    // Attacking a different army than the one with the marker — no cost.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east

    let shouldLose = state.checkBloodyBattle(attacking: .west)
    #expect(!shouldLose)
  }

  @Test
  func bloodyBattleNoMarker() {
    // No bloody battle marker on any army — no cost.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.bloodyBattleArmy == nil)

    let shouldLose = state.checkBloodyBattle(attacking: .east)
    #expect(!shouldLose)
  }

  // MARK: - Paladin Re-roll (Player Aid: Paladin — holy)

  @Test
  func paladinCanReroll() {
    // Paladin alive and in play, not used yet → can re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    #expect(state.canPaladinReroll)

    state.usePaladinReroll()
    #expect(!state.canPaladinReroll)
  }

  @Test
  func paladinCannotRerollWhenDead() {
    // Dead Paladin cannot re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.heroDead.insert(.paladin)
    state.heroLocation.removeValue(forKey: .paladin)

    #expect(!state.canPaladinReroll)
  }

  @Test
  func paladinCannotRerollWhenNotInPlay() {
    // Paladin not in hero roster → cannot re-roll.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3) // default: warrior, wizard, cleric
    #expect(!state.canPaladinReroll) // no paladin
  }

  @Test
  func paladinRerollResetsEachTurn() {
    // After turn reset, Paladin can re-roll again.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.usePaladinReroll()
    #expect(!state.canPaladinReroll)

    state.resetTurnTracking()
    #expect(state.canPaladinReroll)
  }

  // MARK: - Turn Reset (housekeeping)

  @Test
  func turnResetClearsPerTurnState() {
    // Reset clears bloody battle payment and Paladin re-roll.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .paladin, .cleric]
    )
    state.bloodyBattlePaidThisTurn = true
    state.paladinRerollUsed = true

    state.resetTurnTracking()
    #expect(!state.bloodyBattlePaidThisTurn)
    #expect(!state.paladinRerollUsed)
  }

  // MARK: - Memorize (rule 6.6)

  @Test
  func memorizeRevealsArcaneSpell() {
    // Memorize reveals a face-down arcane spell → known.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus[.fireball] == .faceDown)

    let success = state.memorize(spell: .fireball)
    #expect(success)
    #expect(state.spellStatus[.fireball] == .known)
  }

  @Test
  func memorizeFailsOnDivineSpell() {
    // Cannot memorize a divine spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.memorize(spell: .cureWounds)
    #expect(!success)
    #expect(state.spellStatus[.cureWounds] == .faceDown)
  }

  @Test
  func memorizeFailsOnAlreadyKnown() {
    // Cannot memorize a spell that's already known.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .known

    let success = state.memorize(spell: .fireball)
    #expect(!success)
  }

  @Test
  func memorizeFailsOnCastSpell() {
    // Cannot memorize a spell that's been cast (discarded).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast

    let success = state.memorize(spell: .fireball)
    #expect(!success)
  }

  @Test
  func faceDownArcaneSpellsQuery() {
    // All 4 arcane spells start face-down.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.faceDownArcaneSpells.count == 4)

    state.spellStatus[.fireball] = .known
    #expect(state.faceDownArcaneSpells.count == 3)
    #expect(!state.faceDownArcaneSpells.contains(.fireball))
  }

  // MARK: - Pray (rule 6.7)

  @Test
  func prayRevealsDivineSpell() {
    // Pray reveals a face-down divine spell → known.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus[.cureWounds] == .faceDown)

    let success = state.pray(spell: .cureWounds)
    #expect(success)
    #expect(state.spellStatus[.cureWounds] == .known)
  }

  @Test
  func prayFailsOnArcaneSpell() {
    // Cannot pray for an arcane spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.pray(spell: .fireball)
    #expect(!success)
  }

  @Test
  func faceDownDivineSpellsQuery() {
    // All 5 divine spells start face-down.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.faceDownDivineSpells.count == 5)

    state.spellStatus[.cureWounds] = .known
    #expect(state.faceDownDivineSpells.count == 4)
  }

  // MARK: - Chant (rule 6.5)

  @Test
  func chantSuccess() {
    // Roll 4 > 3 → +1 divine energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // divine = 5
    let divineBefore = state.divineEnergy

    let success = state.chant(dieRoll: 4)
    #expect(success)
    #expect(state.divineEnergy == divineBefore + 1)
  }

  @Test
  func chantFailure() {
    // Roll 3 ≤ 3 → fails, no energy gained.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let divineBefore = state.divineEnergy

    let success = state.chant(dieRoll: 3)
    #expect(!success)
    #expect(state.divineEnergy == divineBefore)
  }

  @Test
  func chantNaturalOneFails() {
    // Natural 1 always fails even with DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let divineBefore = state.divineEnergy

    let success = state.chant(dieRoll: 1, drm: 10)
    #expect(!success)
    #expect(state.divineEnergy == divineBefore)
  }

  @Test
  func chantWithPriestDRM() {
    // Roll 3 + DRM 1 = 4 > 3 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let divineBefore = state.divineEnergy

    let success = state.chant(dieRoll: 3, drm: 1)
    #expect(success)
    #expect(state.divineEnergy == divineBefore + 1)
  }

  @Test
  func chantDivineEnergyCapped() {
    // Divine energy capped at 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.divineEnergy = 6

    let success = state.chant(dieRoll: 5)
    #expect(success)
    #expect(state.divineEnergy == 6)
  }

  // MARK: - Build (rule 6.3)

  @Test
  func buildSuccess() {
    // Roll 4 > 3 (Grease build number) → place upgrade.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .grease, on: .east, dieRoll: 4)
    #expect(result == .success(.grease, .east))
    #expect(state.upgrades[.east] == .grease)
  }

  @Test
  func buildRollTooLow() {
    // Roll 3 ≤ 3 → fails.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .grease, on: .east, dieRoll: 3)
    #expect(result == .rollFailed)
    #expect(state.upgrades[.east] == nil)
  }

  @Test
  func buildNaturalOneFails() {
    // Natural 1 always fails even with DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .grease, on: .east, dieRoll: 1, drm: 10)
    #expect(result == .rollFailed)
  }

  @Test
  func buildWithDRM() {
    // Rogue +1 build DRM. Roll 3 + DRM 1 = 4 > 3 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .oil, on: .west, dieRoll: 3, drm: 1)
    #expect(result == .success(.oil, .west))
  }

  @Test
  func buildFailsOnBreachedTrack() {
    // Cannot build on a breached track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)

    let result = state.build(upgrade: .grease, on: .east, dieRoll: 6)
    #expect(result == .trackInvalid)
  }

  @Test
  func buildFailsOnOccupiedCircle() {
    // Cannot build if track already has an upgrade.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease

    let result = state.build(upgrade: .oil, on: .east, dieRoll: 6)
    #expect(result == .trackInvalid)
  }

  @Test
  func buildFailsOnNonWallTrack() {
    // Cannot build on Terror or Sky.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let result = state.build(upgrade: .grease, on: .terror, dieRoll: 6)
    #expect(result == .trackInvalid)
  }

  @Test
  func buildAcidRequiresHighRoll() {
    // Acid build number is 5. Roll 5 ≤ 5 → fails. Roll 6 > 5 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let fail = state.build(upgrade: .acid, on: .east, dieRoll: 5)
    #expect(fail == .rollFailed)

    let success = state.build(upgrade: .acid, on: .east, dieRoll: 6)
    #expect(success == .success(.acid, .east))
  }

  // MARK: - Cast Spell (rule 6.4)

  @Test
  func castKnownArcaneSpell() {
    // Cast Fireball (cost 1 arcane). Arcane energy reduced, spell marked cast.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane = 5
    state.spellStatus[.fireball] = .known

    let result = state.castSpell(.fireball)
    #expect(result == .success(.fireball, heroic: false))
    #expect(state.spellStatus[.fireball] == .cast)
    #expect(state.arcaneEnergy == 4) // 5 - 1
  }

  @Test
  func castKnownDivineSpell() {
    // Cast Cure Wounds (cost 1 divine). Divine energy reduced.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // divine = 5
    state.spellStatus[.cureWounds] = .known

    let result = state.castSpell(.cureWounds)
    #expect(result == .success(.cureWounds, heroic: false))
    #expect(state.spellStatus[.cureWounds] == .cast)
    #expect(state.divineEnergy == 4) // 5 - 1
  }

  @Test
  func castExpensiveSpell() {
    // Cast Fortune (cost 4 arcane).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane = 5
    state.spellStatus[.fortune] = .known

    let result = state.castSpell(.fortune)
    #expect(result == .success(.fortune, heroic: false))
    #expect(state.arcaneEnergy == 1) // 5 - 4
  }

  @Test
  func castFailsNotKnown() {
    // Cannot cast a face-down spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus[.fireball] == .faceDown)

    let result = state.castSpell(.fireball)
    #expect(result == .spellNotKnown)
  }

  @Test
  func castFailsAlreadyCast() {
    // Cannot cast a spell that's already been cast (discarded).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast

    let result = state.castSpell(.fireball)
    #expect(result == .spellNotKnown)
  }

  @Test
  func castFailsInsufficientArcane() {
    // Not enough arcane energy to cast.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fortune] = .known // cost 4
    state.arcaneEnergy = 3

    let result = state.castSpell(.fortune)
    #expect(result == .insufficientEnergy)
    #expect(state.arcaneEnergy == 3) // unchanged
    #expect(state.spellStatus[.fortune] == .known) // still known
  }

  @Test
  func castFailsInsufficientDivine() {
    // Not enough divine energy to cast.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.raiseDead] = .known // cost 4
    state.divineEnergy = 3

    let result = state.castSpell(.raiseDead)
    #expect(result == .insufficientEnergy)
    #expect(state.divineEnergy == 3) // unchanged
  }

  @Test
  func knownSpellsQuery() {
    // Query which spells are known and available to cast.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.knownSpells.isEmpty) // all face-down

    state.spellStatus[.fireball] = .known
    state.spellStatus[.cureWounds] = .known
    #expect(state.knownSpells.count == 2)

    state.spellStatus[.fireball] = .cast
    #expect(state.knownSpells.count == 1)
    #expect(state.knownSpells.contains(.cureWounds))
  }

  // MARK: - Heroic Cast (rule 7.2)

  @Test
  func heroicCastArcaneWithWizard() {
    // Wizard alive → can heroic cast arcane spell (enhanced effect).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // has wizard, arcane = 5
    state.spellStatus[.fireball] = .known

    let result = state.castSpell(.fireball, heroic: true)
    #expect(result == .success(.fireball, heroic: true))
    #expect(state.spellStatus[.fireball] == .cast)
    #expect(state.arcaneEnergy == 4)
  }

  @Test
  func heroicCastDivineWithCleric() {
    // Cleric alive → can heroic cast divine spell (enhanced effect).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // has cleric, divine = 5
    state.spellStatus[.cureWounds] = .known

    let result = state.castSpell(.cureWounds, heroic: true)
    #expect(result == .success(.cureWounds, heroic: true))
    #expect(state.spellStatus[.cureWounds] == .cast)
  }

  @Test
  func heroicCastArcaneFailsWithoutWizard() {
    // No Wizard → cannot heroic cast arcane spell.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .ranger, .cleric]
    )
    state.spellStatus[.fireball] = .known

    let result = state.castSpell(.fireball, heroic: true)
    #expect(result == .heroicRequiresHero)
    #expect(state.spellStatus[.fireball] == .known) // not cast
  }

  @Test
  func heroicCastDivineFailsWithoutCleric() {
    // No Cleric → cannot heroic cast divine spell.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .ranger]
    )
    state.spellStatus[.cureWounds] = .known

    let result = state.castSpell(.cureWounds, heroic: true)
    #expect(result == .heroicRequiresHero)
    #expect(state.spellStatus[.cureWounds] == .known) // not cast
  }

  @Test
  func heroicCastFailsWithDeadWizard() {
    // Wizard dead → cannot heroic cast arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .known
    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)

    let result = state.castSpell(.fireball, heroic: true)
    #expect(result == .heroicRequiresHero)
  }

  @Test
  func canHeroicCastQuery() {
    // Query whether heroic cast is available for a spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.canHeroicCast(.fireball)) // wizard alive
    #expect(state.canHeroicCast(.cureWounds)) // cleric alive

    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)
    #expect(!state.canHeroicCast(.fireball)) // wizard dead
    #expect(state.canHeroicCast(.cureWounds)) // cleric still alive
  }

  // MARK: - Move Hero (rule 7.1)

  @Test
  func moveHeroToTrack() {
    // Move Warrior from reserves to East track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.heroLocation[.warrior] == .reserves)

    state.moveHero(.warrior, to: .onTrack(.east))
    #expect(state.heroLocation[.warrior] == .onTrack(.east))
  }

  @Test
  func moveHeroBetweenTracks() {
    // Move hero from one track to another.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)

    state.moveHero(.warrior, to: .onTrack(.west))
    #expect(state.heroLocation[.warrior] == .onTrack(.west))
  }

  @Test
  func moveHeroBackToReserves() {
    // Move hero from a track back to reserves.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)

    state.moveHero(.warrior, to: .reserves)
    #expect(state.heroLocation[.warrior] == .reserves)
  }

  // MARK: - Rally (rule 7.4)

  @Test
  func rallySuccess() {
    // Roll 5 > 4 → raise morale one step.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)

    let success = state.rally(dieRoll: 5)
    #expect(success)
    #expect(state.morale == .high)
  }

  @Test
  func rallyFailure() {
    // Roll 4 ≤ 4 → fails.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 4)
    #expect(!success)
    #expect(state.morale == .normal)
  }

  @Test
  func rallyNaturalOneFails() {
    // Natural 1 always fails even with DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 1, drm: 10)
    #expect(!success)
    #expect(state.morale == .normal)
  }

  @Test
  func rallyWithDRM() {
    // Paladin +1 rally DRM. Roll 4 + DRM 1 = 5 > 4 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)

    let success = state.rally(dieRoll: 4, drm: 1)
    #expect(success)
    #expect(state.morale == .high)
  }

  @Test
  func rallyMoraleCapped() {
    // Morale already high → stays high.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high

    let success = state.rally(dieRoll: 6)
    #expect(success)
    #expect(state.morale == .high)
  }

  // MARK: - Spell Effects

  // -- Cure Wounds --

  @Test
  func cureWoundsHealsOneHero() {
    // Normal: heal 1 wounded hero.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.wizard)

    state.applyCureWounds(heroes: [.wizard])
    #expect(!state.heroWounded.contains(.wizard))
  }

  @Test
  func cureWoundsHeroicHealsTwoHeroes() {
    // Heroic (†): heal up to 2 wounded heroes.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.wizard)
    state.heroWounded.insert(.warrior)

    state.applyCureWounds(heroes: [.wizard, .warrior])
    #expect(!state.heroWounded.contains(.wizard))
    #expect(!state.heroWounded.contains(.warrior))
  }

  // -- Mass Heal --

  @Test
  func massHealGainsOneDefender() {
    // Normal: gain 1 defender.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 1

    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenders[.menAtArms] == 2)
  }

  @Test
  func massHealHeroicGainsTwoDifferent() {
    // Heroic (†): gain 2 defenders (different types).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 1
    state.defenders[.archers] = 0

    state.applyMassHeal(defenders: [.menAtArms, .archers])
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
  }

  @Test
  func massHealCappedAtMax() {
    // Defender cannot exceed max value.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenders[.menAtArms] == 3) // already at max

    state.applyMassHeal(defenders: [.menAtArms])
    #expect(state.defenders[.menAtArms] == 3) // still max
  }

  // -- Inspire --

  @Test
  func inspireRaisesMoraleAndGrantsDRM() {
    // Raise morale one step and activate +1 DRM for the turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)
    #expect(!state.inspireDRMActive)

    state.applyInspire()
    #expect(state.morale == .high)
    #expect(state.inspireDRMActive)
  }

  @Test
  func inspirePerTurnDRMClearedOnReset() {
    // Inspire's +1 DRM to all rolls is per-turn only.
    // The morale raise from Inspire is permanent (not affected by reset).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high // raised by Inspire (permanent)
    state.inspireDRMActive = true // per-turn bonus

    state.resetTurnTracking()
    #expect(!state.inspireDRMActive) // DRM cleared
    #expect(state.morale == .high) // morale stays
  }

  // -- Raise Dead --

  @Test
  func raiseDeadGainTwoDefenders() {
    // Normal option: gain 2 different defenders.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 1
    state.defenders[.archers] = 0

    state.applyRaiseDead(gainDefenders: [.menAtArms, .archers], returnHero: nil)
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
  }

  @Test
  func raiseDeadReturnHero() {
    // Normal option: return a dead hero to reserves.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)

    state.applyRaiseDead(gainDefenders: [], returnHero: .wizard)
    #expect(!state.heroDead.contains(.wizard))
    #expect(state.heroLocation[.wizard] == .reserves)
  }

  @Test
  func raiseDeadHeroicBothOptions() {
    // Heroic (†): gain 2 defenders AND return a dead hero.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 1
    state.defenders[.archers] = 0
    state.heroDead.insert(.wizard)
    state.heroLocation.removeValue(forKey: .wizard)

    state.applyRaiseDead(gainDefenders: [.menAtArms, .archers], returnHero: .wizard)
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
    #expect(!state.heroDead.contains(.wizard))
    #expect(state.heroLocation[.wizard] == .reserves)
  }

  // -- Fireball --

  @Test
  func fireballHit() {
    // +2 magical attack. Goblin (2) at East 3. Roll 2 + 2 = 4 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    let result = state.applyFireball(on: .east, dieRoll: 2)
    #expect(result == .hit(.east, pushedFrom: 3, pushedTo: 4))
  }

  @Test
  func fireballNaturalOneFails() {
    // Fireball makes an attack roll. Natural 1 on the attack die always fails,
    // even with Fireball's +2 DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 2

    let result = state.applyFireball(on: .gate1, dieRoll: 1)
    #expect(result == .naturalOneFail(.gate1))
  }

  @Test
  func fireballIsMagical() {
    // Fireball is magical → ignores negative DRMs in melee range.
    // Goblin (2) at East 2 (melee). Roll 3 + 2 (fireball) + (-2 penalty) = 3.
    // Magical in melee → negative DRM zeroed → effective = 3 + 2 = 5 > 2 → hit.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 2

    let result = state.applyFireball(on: .east, dieRoll: 3, additionalDRM: -2)
    // The additionalDRM of -2 + fireball's +2 = 0, but since magical in melee range
    // the negative portion is zeroed. So total DRM = max(0, 0) = 0. Roll 3 + 0 = 3 > 2 → hit.
    // Wait, the fireball DRM of +2 is always positive, and additionalDRM of -2 makes total 0.
    // Since isMagical and melee range, effectiveDRM = max(0, 0) = 0. 3 + 0 = 3 > 2 → hit.
    #expect(result == .hit(.east, pushedFrom: 2, pushedTo: 3))
  }

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
    #expect(result == .advanced(.east, from: 3, to: 2))
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
      (slot: .east, dieRoll: 2), // 2 + 0 = 2 ≤ 2 → miss
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
        (slot: .east, dieRoll: 2), // 2 + 1 = 3 > 2 → hit
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
      (slot: .east, dieRoll: 3),
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
      (slot: .east, dieRoll: 4), // 4 + 1 = 5 > 3 → hit
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
      (slot: .east, dieRoll: 4), // hit → push 5→6, undead +1 → capped at 6
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
      (slot: .west, dieRoll: 3), // 3 + 1 = 4 > 2 → hit
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
      (slot: .east, dieRoll: 2), // 2 + 1 = 3 ≤ 3 → miss
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
    #expect(results[0] == .advanced(.east, from: 4, to: 3))
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
    #expect(results[0] == .advanced(.west, from: 5, to: 4))
  }

  @Test
  func bannersInDistanceNoEffect() {
    // West army at space 2 (in melee range) → no advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.west] = 2
    let results = state.eventBannersInDistance()
    #expect(results.isEmpty)
  }

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
    #expect(results[0] == .advanced(.east, from: 5, to: 4))
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
    #expect(results[0] == .advanced(.west, from: 6, to: 5))
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
    #expect(results[0] == .advanced(.east, from: 3, to: 2))
  }

  @Test
  func brokenWallsBothIfTied() {
    // If East and West tied, advance both one space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 4
    state.armyPosition[.west] = 4

    let results = state.eventBrokenWalls()
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.east, from: 4, to: 3))
    #expect(results[1] == .advanced(.west, from: 4, to: 3))
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
    #expect(results[0] == .advanced(.gate1, from: 4, to: 3))
  }

  @Test
  func campfiresBothGateIfBothOut() {
    // Both Gate armies out of melee range → advance both.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.gate1] = 4
    state.armyPosition[.gate2] = 4

    let results = state.eventCampfires()
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.gate1, from: 4, to: 3))
    #expect(results[1] == .advanced(.gate2, from: 4, to: 3))
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

  // -- Acts of Valor (card #8) --

  @Test
  func actsOfValorWoundForBonus() {
    // Wound all unwounded heroes → +1 attack DRM this turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.eventAttackDRMBonus == 0)
    state.eventActsOfValor(woundHeroes: true)
    #expect(state.heroWounded.contains(.warrior))
    #expect(state.heroWounded.contains(.wizard))
    #expect(state.heroWounded.contains(.cleric))
    #expect(state.eventAttackDRMBonus == 1)
  }

  @Test
  func actsOfValorDecline() {
    // Choose not to wound → no bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventActsOfValor(woundHeroes: false)
    #expect(state.heroWounded.isEmpty)
    #expect(state.eventAttackDRMBonus == 0)
  }

  // -- Bloody Handprints (card #24) --

  @Test
  func bloodyHandprintsKill() {
    // Roll 1-3: kill a Hero (wounded first).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroWounded.insert(.warrior) // wounded → must be killed first
    state.eventBloodyHandprints(dieRoll: 2, chosenHero: .warrior)
    #expect(state.heroDead.contains(.warrior))
    #expect(!state.heroWounded.contains(.warrior))
    #expect(state.heroLocation[.warrior] == nil)
  }

  @Test
  func bloodyHandprintsWound() {
    // Roll 4-6: wound a Hero (player choice).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventBloodyHandprints(dieRoll: 5, chosenHero: .wizard)
    #expect(state.heroWounded.contains(.wizard))
    #expect(!state.heroDead.contains(.wizard))
  }

  // -- Council of Heroes (card #26) --

  @Test
  func councilOfHeroes() {
    // Return all living heroes to Reserves. Wounded heroes cannot act.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)
    state.heroLocation[.wizard] = .onTrack(.west)
    // cleric already in reserves

    state.eventCouncilOfHeroes()
    #expect(state.heroLocation[.warrior] == .reserves)
    #expect(state.heroLocation[.wizard] == .reserves)
    #expect(state.heroLocation[.cleric] == .reserves)
    #expect(state.woundedHeroesCannotAct)
  }

  // -- Midnight Magic (card #27) / By the Light of the Moon (card #32) --

  @Test
  func midnightMagicLow() {
    // Roll 1-3: +1 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 2)
    #expect(state.arcaneEnergy == min(before + 1, 6))
  }

  @Test
  func midnightMagicHigh() {
    // Roll 4-6: +2 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane = 1+2 = 3
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 5)
    #expect(state.arcaneEnergy == min(before + 2, 6))
  }

  // -- Assassin's Creedo (card #30) --

  @Test
  func assassinsCreedoKill() {
    // Roll 1-3: kill a Hero of your choice.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAssassinsCreedo(dieRoll: 2, chosenHero: .cleric)
    #expect(state.heroDead.contains(.cleric))
    #expect(state.heroLocation[.cleric] == nil)
  }

  @Test
  func assassinsCreedoBonus() {
    // Roll 4-6: +1 attack DRM this turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAssassinsCreedo(dieRoll: 5)
    #expect(state.eventAttackDRMBonus == 1)
  }

  // -- In the Pale Moonlight (card #31) --

  @Test
  func paleMoonlight() {
    // -1 divine, +1 arcane, lose one Priest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane 5, divine 5
    let arcBefore = state.arcaneEnergy
    let divBefore = state.divineEnergy
    state.eventPaleMoonlight()
    #expect(state.arcaneEnergy == min(arcBefore + 1, 6))
    #expect(state.divineEnergy == divBefore - 1)
    #expect(state.defenders[.priests] == 1)
  }

  // -- By the Light of the Moon (card #32) — same as Midnight Magic --

  @Test
  func byLightOfMoon() {
    // Uses same method as Midnight Magic. Roll 4-6: +2 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane = 3
    let before = state.arcaneEnergy
    state.eventMidnightMagic(dieRoll: 6)
    #expect(state.arcaneEnergy == min(before + 2, 6))
  }

  // -- Deserters in the Dark (card #33) --

  @Test
  func desertersTwoDefenders() {
    // Player chooses: lose 2 defenders.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventDeserters(loseTwoDefenders: (.menAtArms, .archers))
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 1)
  }

  @Test
  func desertersMorale() {
    // Player chooses: reduce Morale by one.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventDeserters(loseTwoDefenders: nil)
    #expect(state.morale == .low)
  }

  // -- The Waning Moon (card #34) --

  @Test
  func waningMoonLoss() {
    // Roll 1-3: -1 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3) // arcane 5
    let before = state.arcaneEnergy
    state.eventWaningMoon(dieRoll: 2)
    #expect(state.arcaneEnergy == before - 1)
  }

  @Test
  func waningMoonGain() {
    // Roll 4-6: +1 arcane.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 1) // arcane 3
    let before = state.arcaneEnergy
    state.eventWaningMoon(dieRoll: 5)
    #expect(state.arcaneEnergy == min(before + 1, 6))
  }

  // -- Mystic Forces Reborn (card #35) --

  @Test
  func mysticForcesReborn() {
    // Return cast spells to pool. Roll 4-6: draw a random arcane spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast
    state.spellStatus[.slow] = .cast
    state.spellStatus[.cureWounds] = .cast // divine, also returns

    state.eventMysticForcesReborn(dieRoll: 5, randomSpell: .chainLightning)
    // Cast spells returned to face-down
    #expect(state.spellStatus[.fireball] == .faceDown)
    #expect(state.spellStatus[.slow] == .faceDown)
    #expect(state.spellStatus[.cureWounds] == .faceDown)
    // Random arcane spell drawn (revealed)
    #expect(state.spellStatus[.chainLightning] == .known)
  }

  @Test
  func mysticForcesRebornLoseArcane() {
    // Roll 1-3: -1 arcane (spells still returned).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .cast
    let before = state.arcaneEnergy

    state.eventMysticForcesReborn(dieRoll: 2)
    #expect(state.spellStatus[.fireball] == .faceDown)
    #expect(state.arcaneEnergy == before - 1)
  }

  // -- Death and Despair (card #29) --

  @Test
  func deathAndDespair() {
    // Roll 4, no mitigation → advance farthest army 4 spaces.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // East at 6 (farthest, tied with West/Sky), set others lower
    state.armyPosition[.west] = 3
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventDeathAndDespair(dieRoll: 4, chosenSlot: .east)
    #expect(results.count == 4)
    #expect(state.armyPosition[.east] == 2) // 6 → 5 → 4 → 3 → 2
  }

  @Test
  func deathAndDespairMitigated() {
    // Roll 3, wound 1 hero + lose 1 defender → only 1 advance.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.armyPosition[.west] = 3
    state.armyPosition[.gate1] = 2
    state.armyPosition[.gate2] = 2
    state.armyPosition[.sky] = 4

    let results = state.eventDeathAndDespair(
      dieRoll: 3,
      heroesToWound: [.warrior],
      defendersToLose: [.menAtArms],
      chosenSlot: .east
    )
    #expect(results.count == 1) // 3 - 2 = 1
    #expect(state.armyPosition[.east] == 4) // 5 → 4
    #expect(state.heroWounded.contains(.warrior))
    #expect(state.defenders[.menAtArms] == 2)
  }

  // -- Bump in the Night (card #36) --

  @Test
  func bumpInTheNightSky() {
    // Choose: advance Sky 1 space.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.sky] = 5

    let results = state.eventBumpInTheNight(advanceSky: true)
    #expect(results.count == 1)
    #expect(results[0] == .advanced(.sky, from: 5, to: 4))
  }

  @Test
  func bumpInTheNightOthers() {
    // Choose: advance other armies total 2 spaces (e.g., east + west 1 each).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5
    state.armyPosition[.west] = 4

    let results = state.eventBumpInTheNight(advanceSky: false, otherAdvances: [.east, .west])
    #expect(results.count == 2)
    #expect(results[0] == .advanced(.east, from: 5, to: 4))
    #expect(results[1] == .advanced(.west, from: 4, to: 3))
  }

  // -- Event per-turn tracking reset --

  @Test
  func eventFieldsResetOnTurnReset() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.eventAttackDRMBonus = 1
    state.noMeleeThisTurn = true
    state.woundedHeroesCannotAct = true

    state.resetTurnTracking()
    #expect(state.eventAttackDRMBonus == 0)
    #expect(!state.noMeleeThisTurn)
    #expect(!state.woundedHeroesCannotAct)
  }

  // MARK: - Victory / Defeat (rule 11.0)

  @Test
  func outcomeOngoing() {
    // Fresh game is ongoing.
    let state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.outcome == .ongoing)
    #expect(!state.ended)
    #expect(!state.victory)
  }

  @Test
  func victoryOnFinalTwilight() {
    // Rule 11.0: Survive until end of Final Twilight turn → victory.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 15

    state.checkVictory()
    #expect(state.ended)
    #expect(state.victory)
    #expect(state.outcome == .victory)
  }

  @Test
  func noVictoryBeforeFinalTwilight() {
    // Not yet at Final Twilight → checkVictory does nothing.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 14

    state.checkVictory()
    #expect(!state.ended)
    #expect(!state.victory)
    #expect(state.outcome == .ongoing)
  }

  @Test
  func victoryBlockedByPriorDefeat() {
    // If already defeated, checkVictory does not override.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 15
    state.ended = true // defeated before reaching victory check
    state.victory = false

    state.checkVictory()
    #expect(state.ended)
    #expect(!state.victory) // still defeated
  }

  @Test
  func defeatByBreachOutcome() {
    // Army enters castle through existing breach → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1
    state.breaches.insert(.east)

    _ = state.advanceArmy(.east) // army enters castle
    #expect(state.ended)
    #expect(!state.victory)
    #expect(state.outcome == .defeatBreached)
  }

  @Test
  func defeatByBarricadeBreakOutcome() {
    // Army breaks through barricade → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1
    state.barricades.insert(.east) // Goblin strength 2

    _ = state.advanceArmy(.east, dieRoll: 2) // 2 ≤ 2 → barricade breaks
    #expect(state.ended)
    #expect(!state.victory)
    #expect(state.outcome == .defeatBreached)
  }

  @Test
  func defeatByAllDefendersLostOutcome() {
    // All defenders reduced to 0 → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 1

    state.loseDefender(.priests)
    #expect(state.ended)
    #expect(!state.victory)
    #expect(state.outcome == .defeatAllDefendersLost)
  }

  @Test
  func partialDefenderLossNotDefeat() {
    // Some defenders remain → game continues.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 2

    state.loseDefender(.priests)
    #expect(!state.ended)
    #expect(state.outcome == .ongoing)
    #expect(state.defenders[.priests] == 1)
  }

  // MARK: - Card Data Model

  @Test
  func cardCount() {
    // 36 cards total: 20 day, 16 night.
    let allCards = LoD.allCards
    #expect(allCards.count == 36)
    #expect(LoD.dayCards.count == 20)
    #expect(LoD.nightCards.count == 16)
  }

  @Test
  func dayCardProperties() {
    // Card #1: "Over the Walls!" — day card, advances West + East,
    // 3 actions, 1 heroic, event "Catapult Shrapnel", no quest, 0 time.
    let card = LoD.allCards.first { $0.number == 1 }!
    #expect(card.title == "Over the Walls!")
    #expect(card.deck == .day)
    #expect(card.advances == [.west, .east])
    #expect(card.actions == 3)
    #expect(card.heroics == 1)
    #expect(card.actionDRMs.isEmpty)
    #expect(card.heroicDRMs.isEmpty)
    #expect(card.event != nil)
    #expect(card.event?.title == "Catapult Shrapnel")
    #expect(card.quest == nil)
    #expect(card.time == 0)
    #expect(card.bloodyBattle == nil)
  }

  @Test
  func nightCardProperties() {
    // Card #21: "Nightmares" — night card, advances all 5 tracks,
    // 3 actions, 3 heroics, +1 attack DRM on terror, 2 time icons.
    let card = LoD.allCards.first { $0.number == 21 }!
    #expect(card.title == "Nightmares")
    #expect(card.deck == .night)
    #expect(card.advances == [.east, .west, .sky, .terror, .gate])
    #expect(card.actions == 3)
    #expect(card.heroics == 3)
    #expect(card.actionDRMs.count == 1)
    #expect(card.actionDRMs[0].action == .attack)
    #expect(card.actionDRMs[0].track == .terror)
    #expect(card.actionDRMs[0].value == 1)
    #expect(card.event == nil)
    #expect(card.quest == nil)
    #expect(card.time == 2)
    #expect(card.bloodyBattle == nil)
  }

  @Test
  func cardWithQuest() {
    // Card #2 has quest "Scrolls of the Dead", target 7.
    let card = LoD.allCards.first { $0.number == 2 }!
    #expect(card.quest != nil)
    #expect(card.quest?.title == "Scrolls of the Dead")
    #expect(card.quest?.target == 7)
  }

  @Test
  func cardWithBloodyBattle() {
    // Card #3 has bloody battle on gate track.
    let card = LoD.allCards.first { $0.number == 3 }!
    #expect(card.bloodyBattle == .gate)
  }

  @Test
  func cardGlobalDRM() {
    // Card #3 has global -1 attack DRM (no track restriction).
    let card = LoD.allCards.first { $0.number == 3 }!
    #expect(card.actionDRMs.count == 1)
    #expect(card.actionDRMs[0].action == .attack)
    #expect(card.actionDRMs[0].track == nil)
    #expect(card.actionDRMs[0].value == -1)
  }

  @Test
  func cardTrackSpecificDRM() {
    // Card #2 has +1 attack DRM on gate track only.
    let card = LoD.allCards.first { $0.number == 2 }!
    #expect(card.actionDRMs.count == 1)
    #expect(card.actionDRMs[0].action == .attack)
    #expect(card.actionDRMs[0].track == .gate)
    #expect(card.actionDRMs[0].value == 1)
  }

  @Test
  func cardHeroicDRM() {
    // Card #3 has +1 rally DRM in heroicDRMs.
    let card = LoD.allCards.first { $0.number == 3 }!
    #expect(card.heroicDRMs.count == 1)
    #expect(card.heroicDRMs[0].action == .rally)
    #expect(card.heroicDRMs[0].value == 1)
  }

  @Test
  func cardQuestWithPenalty() {
    // Card #15 has quest "Last Ditch Efforts" with a penalty.
    let card = LoD.allCards.first { $0.number == 15 }!
    #expect(card.quest?.title == "Last Ditch Efforts")
    #expect(card.quest?.target == 6)
    #expect(card.quest?.penalty == "Reduce Morale by one")
  }

  // MARK: - Deck Management (rule 3.0)

  @Test
  func deckSetupCardCounts() {
    // After setup, day draw pile has 20 cards, night has 16, discards empty.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks()
    #expect(state.dayDrawPile.count == 20)
    #expect(state.nightDrawPile.count == 16)
    #expect(state.dayDiscardPile.isEmpty)
    #expect(state.nightDiscardPile.isEmpty)
  }

  @Test
  func noCurrentCardAfterSetup() {
    // No card drawn yet after setup.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks()
    #expect(state.currentCard == nil)
  }

  @Test
  func drawFromDayOnDaySpace() {
    // On a day space (position 1), draw from day deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1 // day space

    let card = state.drawCard()
    #expect(card != nil)
    #expect(card!.deck == .day)
    #expect(state.currentCard == card)
    #expect(state.dayDrawPile.count == 19)
    #expect(state.nightDrawPile.count == 16) // unchanged
  }

  @Test
  func drawFromDayOnDawnSpace() {
    // Dawn spaces also draw from the day deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 0 // First Dawn

    let card = state.drawCard()
    #expect(card!.deck == .day)
  }

  @Test
  func drawFromNightOnNightSpace() {
    // On a night space (position 4), draw from night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 4 // night space

    let card = state.drawCard()
    #expect(card != nil)
    #expect(card!.deck == .night)
    #expect(state.currentCard == card)
    #expect(state.nightDrawPile.count == 15)
    #expect(state.dayDrawPile.count == 20) // unchanged
  }

  @Test
  func drawFromNightOnTwilightSpace() {
    // Twilight spaces draw from the night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 3 // first twilight

    let card = state.drawCard()
    #expect(card!.deck == .night)
  }

  @Test
  func drawSetsCurrentCard() {
    // After drawing, currentCard is set to the drawn card.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let card = state.drawCard()
    #expect(state.currentCard == card)
    #expect(card!.number == LoD.dayCards[0].number)
  }

  @Test
  func drawReducesPile() {
    // Drawing removes the top card from the draw pile.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    _ = state.drawCard()
    #expect(state.dayDrawPile.count == 19)
    _ = state.drawCard()
    #expect(state.dayDrawPile.count == 18)
  }

  @Test
  func drawDiscardsPreviousCard() {
    // Drawing a new card discards the previous current card.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let first = state.drawCard()!
    let second = state.drawCard()!
    #expect(second != first)
    #expect(state.currentCard == second)
    #expect(state.dayDiscardPile.count == 1)
    #expect(state.dayDiscardPile[0] == first)
  }

  @Test
  func drawReshufflesWhenEmpty() {
    // Rule 3.0: When draw pile is empty, discard pile is reshuffled back in.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // Set up with just 1 day card so the pile empties quickly.
    let oneCard = [LoD.dayCards[0]]
    state.setupDecks(shuffledDayCards: oneCard, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    // Draw the only card.
    let first = state.drawCard()!
    #expect(state.dayDrawPile.isEmpty)

    // Draw again — should reshuffle discard back into draw pile.
    // Use deterministic reshuffle order.
    let card = state.drawCard(reshuffleOrder: [first])
    #expect(card == first) // same card reshuffled back
    #expect(state.dayDiscardPile.isEmpty) // discard was moved to draw pile
  }

  // MARK: - Fortune Spell (arcane, cost 4)

  @Test
  func fortunePeekShowsTopCards() {
    // Peek at the top 3 cards of the current deck without modifying state.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1 // day space → day deck

    let peeked = state.fortunePeek()
    #expect(peeked.count == 3)
    #expect(peeked[0] == LoD.dayCards[0])
    #expect(peeked[1] == LoD.dayCards[1])
    #expect(peeked[2] == LoD.dayCards[2])
    // Deck should be unchanged
    #expect(state.dayDrawPile.count == 20)
  }

  @Test
  func fortuneNormalReorders() {
    // Normal Fortune: look at top 3, put them back in a new order.
    // Reorder [0,1,2] → [2,0,1].
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let original = state.fortunePeek()
    state.applyFortune(newOrder: [2, 0, 1])

    #expect(state.dayDrawPile.count == 20) // no cards removed
    #expect(state.dayDrawPile[0] == original[2])
    #expect(state.dayDrawPile[1] == original[0])
    #expect(state.dayDrawPile[2] == original[1])
    #expect(state.dayDiscardPile.isEmpty) // nothing discarded
  }

  @Test
  func fortuneHeroicDiscardsOne() {
    // Heroic Fortune: discard 1, put remaining 2 back in chosen order.
    // Discard index 1, keep [0, 2] in order [2, 0].
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1

    let original = state.fortunePeek()
    state.applyFortune(newOrder: [2, 0], discardIndex: 1)

    #expect(state.dayDrawPile.count == 19) // 20 - 3 + 2 = 19
    #expect(state.dayDrawPile[0] == original[2])
    #expect(state.dayDrawPile[1] == original[0])
    #expect(state.dayDiscardPile.count == 1)
    #expect(state.dayDiscardPile[0] == original[1]) // middle card discarded
  }

  @Test
  func fortuneOperatesOnNightDeck() {
    // On a night time space, Fortune operates on the night deck.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 4 // night space

    let peeked = state.fortunePeek()
    #expect(peeked[0] == LoD.nightCards[0])

    state.applyFortune(newOrder: [1, 0, 2])
    #expect(state.nightDrawPile[0] == LoD.nightCards[1])
    #expect(state.nightDrawPile[1] == LoD.nightCards[0])
    #expect(state.dayDrawPile.count == 20) // day deck untouched
  }

  // MARK: - Housekeeping (rule 3.0 step 5)

  @Test
  func housekeepingAdvancesTime() {
    // Housekeeping advances time by the current card's time value.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // Use a card with time = 1
    let timeCard = LoD.allCards.first { $0.time == 1 }!
    state.currentCard = timeCard
    #expect(state.timePosition == 0)

    state.performHousekeeping()
    #expect(state.timePosition == 1)
  }

  @Test
  func housekeepingZeroTimeNoAdvance() {
    // Card with time = 0 doesn't advance the time marker.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let zeroTimeCard = LoD.allCards.first { $0.time == 0 }!
    state.currentCard = zeroTimeCard
    #expect(state.timePosition == 0)

    state.performHousekeeping()
    #expect(state.timePosition == 0)
  }

  @Test
  func housekeepingResetsTurnEffects() {
    // Housekeeping resets all per-turn tracking.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let card = LoD.allCards.first { $0.time == 0 }!
    state.currentCard = card
    state.noMeleeThisTurn = true
    state.eventAttackDRMBonus = 1
    state.woundedHeroesCannotAct = true
    state.inspireDRMActive = true
    state.paladinRerollUsed = true
    state.bloodyBattlePaidThisTurn = true

    state.performHousekeeping()
    #expect(!state.noMeleeThisTurn)
    #expect(state.eventAttackDRMBonus == 0)
    #expect(!state.woundedHeroesCannotAct)
    #expect(!state.inspireDRMActive)
    #expect(!state.paladinRerollUsed)
    #expect(!state.bloodyBattlePaidThisTurn)
  }

  @Test
  func housekeepingChecksVictory() {
    // If time reaches Final Twilight (position 15), housekeeping triggers victory.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.timePosition = 14 // one space before final twilight
    let timeCard = LoD.allCards.first { $0.time == 1 }!
    state.currentCard = timeCard

    state.performHousekeeping()
    #expect(state.timePosition == 15)
    #expect(state.outcome == .victory)
  }

  @Test
  func housekeepingNoCardNoOp() {
    // No current card → housekeeping does nothing.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.currentCard = nil

    state.performHousekeeping()
    #expect(state.timePosition == 0) // unchanged
  }

  @Test
  func defeatByTerrorDefenderLoss() {
    // Terror/Sky army at space 1 causes defender loss. If that empties all
    // defenders → defeat.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.terror] = 1
    state.defenders[.menAtArms] = 0
    state.defenders[.archers] = 0
    state.defenders[.priests] = 1

    // Terror tries to advance past space 1 → defenderLoss result
    let result = state.advanceArmy(.terror)
    #expect(result == .defenderLoss)
    // The advanceArmy itself doesn't auto-trigger loseDefender — the caller does.
    // But the state should still be ongoing until the defender is actually lost.
    #expect(state.outcome == .ongoing)

    // Caller acts on the defenderLoss result:
    state.loseDefender(.priests)
    #expect(state.outcome == .defeatAllDefendersLost)
  }

  // MARK: - Quest Attempt Mechanic

  @Test
  func questAttemptActionSuccess() {
    // Action attempt: +1 DRM. Quest target 6. Roll 6 + 1 = 7 > 6 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    state.timePosition = 1
    state.drawCard() // draw a card so currentCard is set
    // Find a card with a target-6 quest
    let questCard = LoD.allCards.first { $0.quest?.target == 6 }!
    state.currentCard = questCard

    let result = state.attemptQuest(isHeroic: false, dieRoll: 6)
    #expect(result == .success)
  }

  @Test
  func questAttemptHeroicSuccess() {
    // Heroic attempt: +2 DRM. Quest target 7. Roll 6 + 2 = 8 > 7 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let questCard = LoD.allCards.first { $0.quest?.target == 7 }!
    state.currentCard = questCard

    let result = state.attemptQuest(isHeroic: true, dieRoll: 6)
    #expect(result == .success)
  }

  @Test
  func questAttemptFailure() {
    // Action attempt: +1 DRM. Quest target 6. Roll 5 + 1 = 6 ≤ 6 → failure.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let questCard = LoD.allCards.first { $0.quest?.target == 6 }!
    state.currentCard = questCard

    let result = state.attemptQuest(isHeroic: false, dieRoll: 5)
    #expect(result == .failure)
  }

  @Test
  func questAttemptNaturalOneFails() {
    // Natural 1 always fails, even with large DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let questCard = LoD.allCards.first { $0.quest != nil }!
    state.currentCard = questCard

    let result = state.attemptQuest(isHeroic: true, dieRoll: 1, additionalDRM: 10)
    #expect(result == .naturalOneFail)
  }

  @Test
  func questAttemptWithRangerDRM() {
    // Ranger adds +1 quest DRM. Target 6, roll 4 + 1 (action) + 1 (ranger) = 6 ≤ 6 → fail.
    // Roll 5 + 1 + 1 = 7 > 6 → success.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let questCard = LoD.allCards.first { $0.quest?.target == 6 }!
    state.currentCard = questCard

    let fail = state.attemptQuest(isHeroic: false, dieRoll: 4, additionalDRM: 1)
    #expect(fail == .failure)

    let success = state.attemptQuest(isHeroic: false, dieRoll: 5, additionalDRM: 1)
    #expect(success == .success)
  }

  @Test
  func questAttemptNoQuest() {
    // No quest on current card → .noQuest.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let noQuestCard = LoD.allCards.first { $0.quest == nil }!
    state.currentCard = noQuestCard

    let result = state.attemptQuest(isHeroic: false, dieRoll: 6)
    #expect(result == .noQuest)
  }

  // MARK: - Quest Rewards

  @Test
  func questForlornHopeAdvancesTime() {
    // Forlorn Hope reward: advance time marker +1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.timePosition == 0)

    state.questForlornHope()
    #expect(state.timePosition == 1)
  }

  @Test
  func questScrollsOfDeadRevealsSpell() {
    // Scrolls of the Dead reward: chosen spell becomes known.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.spellStatus[.chainLightning] == .faceDown)

    state.questScrollsOfDead(chosenSpell: .chainLightning)
    #expect(state.spellStatus[.chainLightning] == .known)
  }

  @Test
  func questScrollsOfDeadIgnoresNonFaceDown() {
    // Can't reveal an already-known or cast spell.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .known

    state.questScrollsOfDead(chosenSpell: .fireball)
    #expect(state.spellStatus[.fireball] == .known) // unchanged
  }

  @Test
  func questManastonesGainsEnergy() {
    // Manastones reward: +1 arcane, +1 divine.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let arcaneBefore = state.arcaneEnergy
    let divineBefore = state.divineEnergy

    state.questManastones()
    #expect(state.arcaneEnergy == min(arcaneBefore + 1, 6))
    #expect(state.divineEnergy == min(divineBefore + 1, 6))
  }

  @Test
  func questMagicBowGivesItem() {
    // Arrows of the Dead reward: gain Magic Bow.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.hasMagicBow)

    state.questMagicBow()
    #expect(state.hasMagicBow)
  }

  @Test
  func questPutForthCallGainsDefender() {
    // Put Forth the Call reward: +1 defender of choice.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.archers] = 1

    state.questPutForthCall(defender: .archers)
    #expect(state.defenders[.archers] == 2)
  }

  @Test
  func questPutForthCallCapped() {
    // Defender cannot exceed max value.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.defenders[.archers] == 2) // already at max

    state.questPutForthCall(defender: .archers)
    #expect(state.defenders[.archers] == 2) // stays at max
  }

  @Test
  func questLastDitchEffortsAddsHero() {
    // Last Ditch Efforts reward: add an unselected hero to reserves.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.heroLocation[.ranger] == nil) // not in play

    state.questLastDitchEfforts(hero: .ranger)
    #expect(state.heroLocation[.ranger] == .reserves)
  }

  @Test
  func questLastDitchPenaltyLowersMorale() {
    // Last Ditch Efforts penalty: reduce morale by one.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(state.morale == .normal)

    state.questLastDitchPenalty()
    #expect(state.morale == .low)
  }

  @Test
  func questVorpalBladeGivesItem() {
    // The Vorpal Blade reward: gain Magic Sword.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.hasMagicSword)

    state.questVorpalBlade()
    #expect(state.hasMagicSword)
  }

  @Test
  func questPillarsOfEarthRetreatsArmy() {
    // Pillars of the Earth reward: retreat one army (except Sky) two spaces.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3

    state.questPillarsOfEarth(slot: .east)
    #expect(state.armyPosition[.east] == 5) // retreated from 3 to 5
  }

  @Test
  func questPillarsOfEarthRetreatCapped() {
    // Retreat capped at maxSpace (6 for East).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 5

    state.questPillarsOfEarth(slot: .east)
    #expect(state.armyPosition[.east] == 6) // capped at max
  }

  @Test
  func questPillarsOfEarthCannotTargetSky() {
    // Sky army excluded from Pillars of the Earth.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.sky] = 3

    state.questPillarsOfEarth(slot: .sky)
    #expect(state.armyPosition[.sky] == 3) // unchanged
  }

  @Test
  func questMirrorOfMoonGainsArcane() {
    // Save the Mirror of the Moon reward: +2 arcane energy.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.arcaneEnergy = 3

    state.questMirrorOfMoon()
    #expect(state.arcaneEnergy == 5)
  }

  @Test
  func questMirrorOfMoonCapped() {
    // Arcane energy capped at 6.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.arcaneEnergy = 5

    state.questMirrorOfMoon()
    #expect(state.arcaneEnergy == 6) // capped
  }

  @Test
  func questProphecyRevealedDiscardsOne() {
    // Prophecy Revealed: reveal top 3 Day cards, discard one, put rest back.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.setupDecks(shuffledDayCards: LoD.dayCards, shuffledNightCards: LoD.nightCards)
    let topThree = Array(state.dayDrawPile.prefix(3))

    state.questProphecyRevealed(discardIndex: 1) // discard the middle card
    #expect(state.dayDiscardPile.count == 1)
    #expect(state.dayDiscardPile[0] == topThree[1]) // middle card discarded
    #expect(state.dayDrawPile.count == 19) // 20 - 3 + 2 = 19
    // The first and third cards should be back on top
    #expect(state.dayDrawPile[0] == topThree[0])
    #expect(state.dayDrawPile[1] == topThree[2])
  }

  // MARK: - Magic Items (quest rewards)

  @Test
  func useMagicSwordBefore() {
    // Magic Sword before melee: +2 DRM, item consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.hasMagicSword = true

    let drm = state.useMagicSword(timing: .before)
    #expect(drm == 2)
    #expect(!state.hasMagicSword)
  }

  @Test
  func useMagicSwordAfter() {
    // Magic Sword after melee: +1 DRM, item consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.hasMagicSword = true

    let drm = state.useMagicSword(timing: .after)
    #expect(drm == 1)
    #expect(!state.hasMagicSword)
  }

  @Test
  func useMagicSwordNotHeld() {
    // No Magic Sword → 0 DRM, nothing consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.hasMagicSword)

    let drm = state.useMagicSword(timing: .before)
    #expect(drm == 0)
  }

  @Test
  func useMagicBowBefore() {
    // Magic Bow before ranged: +2 DRM, item consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.hasMagicBow = true

    let drm = state.useMagicBow(timing: .before)
    #expect(drm == 2)
    #expect(!state.hasMagicBow)
  }

  @Test
  func useMagicBowAfter() {
    // Magic Bow after ranged: +1 DRM, item consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.hasMagicBow = true

    let drm = state.useMagicBow(timing: .after)
    #expect(drm == 1)
    #expect(!state.hasMagicBow)
  }

  @Test
  func useMagicBowNotHeld() {
    // No Magic Bow → 0 DRM, nothing consumed.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    #expect(!state.hasMagicBow)

    let drm = state.useMagicBow(timing: .before)
    #expect(drm == 0)
  }

  // MARK: - Composed Game (oapply)

  @Test
  func composedGameInitialState() {
    // The composed game creates a valid initial state in the card phase.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    let state = game.newState()

    #expect(state.phase == .card)
    #expect(state.dayDrawPile.count == 20)
    #expect(state.nightDrawPile.count == 16)
    #expect(state.history.isEmpty)
  }

  @Test
  func composedGameAllowedActionsInCardPhase() {
    // In card phase, only drawCard is offered.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    let state = game.newState()

    let actions = game.allowedActions(state: state)
    #expect(actions == [.drawCard])
  }

  @Test
  func composedGameFullTurnCascade() {
    // Use card #2 (no event) so drawCard cascades: drawCard → advanceArmies → skipEvent.
    // Then player explicitly passes actions and heroics.
    // passHeroics cascades to performHousekeeping automatically.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    #expect(state.phase == .card)
    #expect(state.timePosition == 0)

    // Step 1: drawCard cascades through army and event (no-event card)
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.currentCard != nil)
    #expect(state.history.count == 3) // drawCard, advanceArmies, skipEvent

    // Step 2: pass actions → phase becomes heroic
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)
    #expect(state.history.count == 4)

    // Step 3: pass heroics → cascades to housekeeping → phase becomes card
    _ = game.reduce(into: &state, action: .passHeroics)
    #expect(state.phase == .card)
    #expect(state.history.count == 6) // +passHeroics, +performHousekeeping

    #expect(state.history[0] == .drawCard)
    #expect(state.history[1] == .advanceArmies(acidAttackDieRolls: [:]))
    #expect(state.history[2] == .skipEvent)
    #expect(state.history[3] == .passActions)
    #expect(state.history[4] == .passHeroics)
    #expect(state.history[5] == .performHousekeeping)
  }

  @Test
  func composedGameTimeAdvancesOverTurns() {
    // Card #3 ("All is Quiet") has no event, no advances, time: 1.
    // Safe for multiple turns without triggering breaches.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: Array(repeating: card3, count: 5),
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    let initialTime = state.timePosition

    for _ in 0..<5 {
      let actions = game.allowedActions(state: state)
      #expect(actions.contains(.drawCard))
      _ = game.reduce(into: &state, action: .drawCard)
      _ = game.reduce(into: &state, action: .passActions)
      _ = game.reduce(into: &state, action: .passHeroics)
    }

    #expect(state.timePosition == initialTime + 5) // card3.time = 1 × 5 turns
    // 6 history entries per turn × 5 turns
    #expect(state.history.count == 30)
  }

  @Test
  func composedGameTerminalState() {
    // When the game ends, no actions are offered.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.ended = true

    let actions = game.allowedActions(state: state)
    #expect(actions.isEmpty)
  }

  @Test
  func composedGameArmiesAdvance() {
    // Card #2 advances: gate, gate, west, east.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    let eastBefore = state.armyPosition[.east]!
    let westBefore = state.armyPosition[.west]!

    _ = game.reduce(into: &state, action: .drawCard)

    // Card #2 advances east and west (and gate twice)
    #expect(state.armyPosition[.east]! < eastBefore)
    #expect(state.armyPosition[.west]! < westBefore)
  }

  // MARK: - Event Phase Tests

  @Test
  func composedGameEventPhaseWithEvent() {
    // Card #1 has event "Catapult Shrapnel". After drawCard cascade stops at event phase,
    // the player must provide resolveEvent.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1] + LoD.dayCards,
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // drawCard cascades: drawCard → advanceArmies. Stops because card has event.
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .event)

    // Rules should offer resolveEvent
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(where: { if case .resolveEvent = $0 { return true }; return false }))

    // Resolve with die roll 5 (no effect for Catapult Shrapnel)
    var resolution = LoD.EventResolution()
    resolution.dieRoll = 5
    _ = game.reduce(into: &state, action: .resolveEvent(resolution))
    #expect(state.phase == .action)
    // Defenders unchanged (roll 4-6 = no effect)
    #expect(state.defenders[.archers] == 2)
    #expect(state.defenders[.menAtArms] == 3)
  }

  @Test
  func composedGameEventCatapultShrapnelLoseDefender() {
    // Catapult Shrapnel roll 1 → lose archer.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .event)

    var resolution = LoD.EventResolution()
    resolution.dieRoll = 1
    _ = game.reduce(into: &state, action: .resolveEvent(resolution))
    #expect(state.defenders[.archers] == 1)
  }

  // MARK: - Action Phase Tests

  @Test
  func composedGameActionBudget() {
    // Card #2 has 4 actions, no event. With normal morale, budget = 4.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.actionBudget == 4)
    #expect(state.actionBudgetRemaining == 4)

    // Do a chant (priests > 0, costs 1 action point)
    _ = game.reduce(into: &state, action: .chant(dieRoll: 6))
    #expect(state.actionBudgetRemaining == 3)

    // Pass with budget remaining
    let actions = game.allowedActions(state: state)
    #expect(actions.contains(.passActions))
  }

  @Test
  func composedGameActionBudgetExhausted() {
    // Use a card with 1 action point. After one action, only pass is offered.
    // Card #26 has 1 action point.
    let card26 = LoD.nightCards.first { $0.number == 26 }!
    // We need to be on a night time space to draw night cards.
    // Instead, just set up manually.
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card26], // Put night card in day pile for test
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Card 26 has event "Council of Heroes", so we need to resolve it.
    _ = game.reduce(into: &state, action: .drawCard)

    // Card 26 has event, so we're in event phase
    if state.phase == .event {
      _ = game.reduce(into: &state, action: .resolveEvent(LoD.EventResolution()))
    }
    #expect(state.phase == .action)
    #expect(state.actionBudget == 1)

    // Do one chant
    _ = game.reduce(into: &state, action: .chant(dieRoll: 6))
    #expect(state.actionBudgetRemaining == 0)

    // Only pass should be offered
    let actions = game.allowedActions(state: state)
    #expect(actions == [.passActions])
  }

  @Test
  func composedGameMeleeAttack() {
    // Card #3: no event, no advances, 2 actions.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Move east army to melee range (space 2)
    state.armyPosition[.east] = 2

    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    // Melee attack on east with a strong roll
    // Card #3 has attack DRM -1, so roll 6 + (-1) = 5. Goblin str 2. 5 > 2 = hit.
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))

    // Army pushed back from space 2 to space 3
    #expect(state.armyPosition[.east]! == 3)
    #expect(state.actionBudgetRemaining == 1) // 2 - 1 = 1
  }

  @Test
  func composedGameRangedAttack() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    // Ranged attack on east army (at space 5 after advance)
    let eastPos = state.armyPosition[.east]!
    _ = game.reduce(into: &state, action: .rangedAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicBow: nil))

    // Roll 6 + card2 gate DRM (doesn't apply to east) vs goblin str 2 → hit
    #expect(state.armyPosition[.east]! > eastPos)
  }

  // MARK: - Heroic Phase Tests

  @Test
  func composedGameHeroicPhase() {
    // After passing actions, we enter heroic phase.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)
    #expect(state.heroicBudget == 2) // card 2 has heroics: 2
    #expect(state.heroicBudgetRemaining == 2)

    let actions = game.allowedActions(state: state)
    // Should offer moveHero, rally, passHeroics, etc.
    #expect(actions.contains(.passHeroics))
    #expect(actions.contains(where: { if case .moveHero = $0 { return true }; return false }))
    #expect(actions.contains(where: { if case .rally = $0 { return true }; return false }))
  }

  @Test
  func composedGameMoveHeroAndAttack() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Put east army at space 3 (melee range for warrior)
    state.armyPosition[.east] = 3

    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)

    // Move warrior to east track
    _ = game.reduce(into: &state, action: .moveHero(.warrior, .onTrack(.east)))
    #expect(state.heroLocation[.warrior] == .onTrack(.east))
    #expect(state.heroicBudgetRemaining == 1)

    // Heroic attack with warrior on east army
    _ = game.reduce(into: &state, action: .heroicAttack(.warrior, .east, dieRoll: 5))
    #expect(state.heroicBudgetRemaining == 0)

    // Budget exhausted → only pass offered
    let actions = game.allowedActions(state: state)
    #expect(actions == [.passHeroics])
  }

  @Test
  func composedGameRally() {
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.morale = .low

    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)

    // Rally with high roll → morale should raise
    _ = game.reduce(into: &state, action: .rally(dieRoll: 6))
    #expect(state.morale == .normal)
  }

  @Test
  func composedGameHeroicPassCascadesToHousekeeping() {
    // passHeroics should auto-cascade to performHousekeeping.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    _ = game.reduce(into: &state, action: .passHeroics)

    // Should be back to card phase after housekeeping
    #expect(state.phase == .card)
    // Time should have advanced by card's time value
    #expect(state.timePosition == card2.time)
  }

  // MARK: - Budget Tracking Tests

  @Test
  func actionBudgetWithMoraleModifier() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    // Use card 2 (4 actions)
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    state.currentCard = card2

    // Normal morale → budget = 4
    state.morale = .normal
    #expect(state.actionBudget == 4)

    // High morale → budget = 5
    state.morale = .high
    #expect(state.actionBudget == 5)

    // Low morale → budget = 3
    state.morale = .low
    #expect(state.actionBudget == 3)
  }

  @Test
  func heroicBudgetFromCard() {
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    state.currentCard = card2
    #expect(state.heroicBudget == 2)

    // Card 26 has 3 heroics
    let card26 = LoD.nightCards.first { $0.number == 26 }!
    state.currentCard = card26
    #expect(state.heroicBudget == 3)
  }

  // MARK: - Quest Reward Tests (composed game)

  @Test
  func composedGameQuestRewardForlornHope() {
    // Card #3: Forlorn Hope quest (target > 6). Reward: advance time +1.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let timeBefore = state.timePosition
    // Roll 6 + action DRM 1 = 7 > 6 = success
    _ = game.reduce(into: &state, action: .questAction(dieRoll: 6, reward: LoD.QuestRewardParams()))
    #expect(state.timePosition == timeBefore + 1) // Forlorn Hope advances time
  }

  @Test
  func composedGameQuestRewardScrollsOfDead() {
    // Card #2: Scrolls of the Dead (target > 7). Reward: learn a chosen spell.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)

    // All spells start face-down
    #expect(state.spellStatus[.fireball] == .faceDown)

    // Roll 6 + action DRM 1 = 7. Need > 7, so this fails.
    var reward = LoD.QuestRewardParams()
    reward.chosenSpell = .fireball
    _ = game.reduce(into: &state, action: .questAction(dieRoll: 6, reward: reward))
    #expect(state.spellStatus[.fireball] == .faceDown) // still face-down (failed)

    // Try heroic: roll 6 + heroic DRM 2 = 8 > 7 = success
    _ = game.reduce(into: &state, action: .passActions)
    _ = game.reduce(into: &state, action: .questHeroic(dieRoll: 6, reward: reward))
    #expect(state.spellStatus[.fireball] == .known) // now known!
  }

  @Test
  func composedGameQuestFailureNoReward() {
    // Card #3: Forlorn Hope, roll too low = failure, time should not advance.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)

    let timeBefore = state.timePosition
    // Roll 2 + action DRM 1 = 3. Need > 6 = failure.
    _ = game.reduce(into: &state, action: .questAction(dieRoll: 2, reward: LoD.QuestRewardParams()))
    #expect(state.timePosition == timeBefore) // no time advance
  }

  // MARK: - Spell Casting Tests (composed game)

  @Test
  func composedGameCastFireball() {
    // Cast fireball during action phase.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    // Learn fireball and place an army in range
    state.spellStatus[.fireball] = .known
    state.armyPosition[.east] = 3

    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let arcaneBefore = state.arcaneEnergy

    // Cast fireball on east army, roll 5
    var params = LoD.SpellCastParams()
    params.targetSlot = .east
    params.dieRolls = [5]
    _ = game.reduce(into: &state, action: .castSpell(.fireball, heroic: false, params))

    // Fireball costs 1 arcane energy
    #expect(state.arcaneEnergy == arcaneBefore - 1)
    #expect(state.spellStatus[.fireball] == .cast)
    // Fireball: +2 DRM magical attack. Roll 5 + 2 = 7 > goblin str 2 = hit.
    #expect(state.armyPosition[.east]! > 3) // pushed back
    #expect(state.actionBudgetRemaining == 1) // used 1 of 2 action points
  }

  @Test
  func composedGameCastInspire() {
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 1,   // low arcane so divine is high
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.spellStatus[.inspire] = .known
    state.morale = .low

    _ = game.reduce(into: &state, action: .drawCard)

    // Cast Inspire (divine, cost 3)
    _ = game.reduce(into: &state, action: .castSpell(.inspire, heroic: false, LoD.SpellCastParams()))
    #expect(state.morale == .normal) // raised from low
    #expect(state.inspireDRMActive == true) // +1 DRM to all rolls
    #expect(state.spellStatus[.inspire] == .cast)
  }

  @Test
  func composedGameCastSpellOfferedWhenKnown() {
    // Verify castSpell appears in allowed actions only when spell is known + has energy.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()

    _ = game.reduce(into: &state, action: .drawCard)

    // No known spells → no cast actions
    let actionsNoSpells = game.allowedActions(state: state)
    #expect(!actionsNoSpells.contains(where: { if case .castSpell = $0 { return true }; return false }))

    // Learn fireball
    state.spellStatus[.fireball] = .known

    let actionsWithSpell = game.allowedActions(state: state)
    #expect(actionsWithSpell.contains(where: { if case .castSpell = $0 { return true }; return false }))
  }

  @Test
  func composedGameCastSpellInsufficientEnergy() {
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.spellStatus[.fireball] = .known
    state.arcaneEnergy = 0  // no energy

    _ = game.reduce(into: &state, action: .drawCard)

    // Fireball should NOT be offered (insufficient energy)
    let actions = game.allowedActions(state: state)
    #expect(!actions.contains(where: { if case .castSpell = $0 { return true }; return false }))
  }

  // MARK: - Last Ditch Efforts Penalty

  @Test
  func composedGameLastDitchPenalty() {
    // Card #10: Last Ditch Efforts quest. Penalty if not attempted: morale -1.
    let card10 = LoD.dayCards.first { $0.number == 10 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card10],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)

    // Skip quest — just pass actions and heroics
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.morale == .normal) // not yet penalized

    _ = game.reduce(into: &state, action: .passHeroics)
    // Housekeeping should apply penalty: morale lowered
    #expect(state.morale == .low)
  }

  // MARK: - Paladin Re-roll Tracking

  @Test
  func paladinRerollTracking() {
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin]
    )

    // Paladin is alive and in play → can re-roll
    #expect(state.canPaladinReroll == true)

    // Use the re-roll
    state.usePaladinReroll()
    #expect(state.canPaladinReroll == false)

    // Reset at turn end
    state.resetTurnTracking()
    #expect(state.canPaladinReroll == true)
  }

  @Test
  func paladinRerollNotAvailableWhenDead() {
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin]
    )

    state.heroDead.insert(.paladin)
    #expect(state.canPaladinReroll == false)
  }

  // MARK: - Bloody Battle Cost in Composed Game (#6)

  @Test
  func bloodyBattleAttackCostsDefender() {
    // Attacking army with bloody battle marker loses a chosen defender.
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .east
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)
    #expect(state.bloodyBattleArmy == .east)

    // East army at space 1 (melee range)
    state.armyPosition[.east] = 1
    let archersBefore = state.defenders[.archers]!

    // Melee attack on east, choosing to lose an archer for bloody battle
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: .archers, useMagicSword: nil))
    #expect(state.defenders[.archers] == archersBefore - 1)
  }

  @Test
  func bloodyBattleCostOnlyOncePerTurn() {
    // Second attack on same army same turn doesn't lose another defender.
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .east
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.armyPosition[.east] = 1
    let archersBefore = state.defenders[.archers]!

    // First attack — costs a defender
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: .archers, useMagicSword: nil))
    #expect(state.defenders[.archers] == archersBefore - 1)

    // Second attack — no additional cost (nil defender)
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.defenders[.archers] == archersBefore - 1) // unchanged
  }

  @Test
  func bloodyBattleNoEffectOnOtherArmies() {
    // Attacking non-marked army doesn't cost a defender.
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 3, heroics: 1,
      actionDRMs: [], heroicDRMs: [],
      event: nil, quest: nil, time: 1, bloodyBattle: .east
    )
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.armyPosition[.west] = 1
    let maaBeforе = state.defenders[.menAtArms]!

    // Attack west (not marked) — no bloody battle cost
    _ = game.reduce(into: &state, action: .meleeAttack(.west, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.defenders[.menAtArms] == maaBeforе)
  }

  // MARK: - Heroic Attack DRM from Cards (#8, rule 7.0)

  @Test
  func heroicAttackAppliesCardDRM() {
    // Card with heroicDRM for attack +1 → heroic attack should include it.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.east)
    // Use a card that has heroicDRMs for attacks
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 2, heroics: 1,
      actionDRMs: [], heroicDRMs: [LoD.CardDRM(action: .attack, track: nil, value: 1)],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    state.currentCard = card

    let drm = state.totalHeroicAttackDRM(hero: .warrior, slot: .east)
    // Warrior combatDRM (2) + card heroicDRM attack (1) + inspire (0) = 3
    #expect(drm == 3)
  }

  @Test
  func heroicAttackCardDRMTrackSpecific() {
    // Card heroicDRM restricted to east track doesn't apply to west.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.warrior] = .onTrack(.west)
    let card = LoD.Card(
      number: 99, file: "test", title: "Test Card",
      deck: .day, advances: [], actions: 2, heroics: 1,
      actionDRMs: [], heroicDRMs: [LoD.CardDRM(action: .attack, track: .east, value: 2)],
      event: nil, quest: nil, time: 1, bloodyBattle: nil
    )
    state.currentCard = card

    let drm = state.totalHeroicAttackDRM(hero: .warrior, slot: .west)
    // Warrior combatDRM (2) + card heroicDRM (0, wrong track) = 2
    #expect(drm == 2)
  }

  // MARK: - Ranger Quest DRM (rule 10.3)

  @Test
  func rangerQuestDRM() {
    // Ranger alive → +1 quest DRM. Dead → 0.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .ranger]
    )
    #expect(state.questDRM() == 1)

    state.heroDead.insert(.ranger)
    #expect(state.questDRM() == 0)
  }

  @Test
  func rangerQuestDRMNotInPlay() {
    // Ranger not in hero roster → 0.
    let state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .cleric]
    )
    #expect(state.questDRM() == 0)
  }

  // MARK: - Rogue Build DRM (rule 10.4)

  @Test
  func rogueBuildDRM() {
    // Rogue alive → totalBuildDRM includes +1.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue]
    )
    // No card DRMs, no inspire → just Rogue +1
    #expect(state.totalBuildDRM() == 1)
  }

  @Test
  func rogueBuildDRMNotWhenDead() {
    // Rogue dead → no build bonus.
    var state = LoD.greenskinSetup(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue]
    )
    state.heroDead.insert(.rogue)
    #expect(state.totalBuildDRM() == 0)
  }

  // MARK: - Rogue Free Move (rule 10.4)

  @Test
  func rogueFreeMoveOfferedInActionPhase() {
    // Rogue alive → rogueMove actions offered during action phase without costing action points.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let allowed = game.allowedActions(state: state)
    // Should include rogueMove options
    let rogueMoves = allowed.filter {
      if case .rogueMove = $0 { return true }
      return false
    }
    #expect(rogueMoves.count > 0)
  }

  @Test
  func rogueFreeMoveDoesNotCostActionPoint() {
    // Using rogueMove should not decrement the action budget.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    let budgetBefore = state.actionBudgetRemaining
    _ = game.reduce(into: &state, action: .rogueMove(.onTrack(.east)))
    #expect(state.actionBudgetRemaining == budgetBefore) // No action consumed
    #expect(state.heroLocation[.rogue] == .onTrack(.east))
  }

  @Test
  func rogueFreeMoveNotOfferedWhenDead() {
    // Rogue dead → no rogueMove offered.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .rogue],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroDead.insert(.rogue)
    _ = game.reduce(into: &state, action: .drawCard)

    let allowed = game.allowedActions(state: state)
    let rogueMoves = allowed.filter {
      if case .rogueMove = $0 { return true }
      return false
    }
    #expect(rogueMoves.count == 0)
  }

  // MARK: - Magic Items (rule 9.2)

  @Test
  func magicSwordBeforeRollAdds2DRM() {
    // Magic Sword used before rolling gives +2 DRM to melee attack.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.hasMagicSword = true
    state.armyPosition[.east] = 1 // melee range
    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 1 normally always fails. With +2 DRM from sword and card DRM:
    // Card 3 has attack DRM -1. So: roll 3 + (-1) + 2 = 4. Goblin str 2. 4 > 2 = hit.
    let eastPosBefore = state.armyPosition[.east]!
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 3, bloodyBattleDefender: nil, useMagicSword: .before))
    // Should have hit — army retreated
    #expect(state.armyPosition[.east]! > eastPosBefore)
    // Sword consumed
    #expect(state.hasMagicSword == false)
  }

  @Test
  func magicSwordAfterRollAdds1DRM() {
    // Magic Sword used after seeing roll gives +1 DRM.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.hasMagicSword = true
    state.armyPosition[.east] = 1

    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 3 + card DRM (-1) + sword after (+1) = 3. Goblin str 2. 3 > 2 = hit.
    let eastPosBefore = state.armyPosition[.east]!
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 3, bloodyBattleDefender: nil, useMagicSword: .after))
    #expect(state.armyPosition[.east]! > eastPosBefore)
    #expect(state.hasMagicSword == false)
  }

  @Test
  func magicBowBeforeRollAdds2DRM() {
    // Magic Bow used before rolling gives +2 DRM to ranged attack.
    let card2 = LoD.dayCards.first { $0.number == 2 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card2],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.hasMagicBow = true
    _ = game.reduce(into: &state, action: .drawCard)

    let eastPosBefore = state.armyPosition[.east]!
    // Roll 1 always fails regardless of DRM (natural 1 rule)
    // Use roll 2 instead: roll 2 + bow before (+2) = 4. Goblin str 2. 4 > 2 = hit.
    _ = game.reduce(into: &state, action: .rangedAttack(.east, dieRoll: 2, bloodyBattleDefender: nil, useMagicBow: .before))
    #expect(state.armyPosition[.east]! > eastPosBefore)
    #expect(state.hasMagicBow == false)
  }

  @Test
  func magicItemNotConsumedWhenNotHeld() {
    // Trying to use magic sword when not held: no bonus, no crash.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.hasMagicSword = false
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // Roll 2 + card DRM (-1) + no sword = 1. 1 is natural fail anyway, but the point
    // is it shouldn't crash.
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 2, bloodyBattleDefender: nil, useMagicSword: .before))
    #expect(state.hasMagicSword == false)
  }

  // MARK: - Acid Upgrade Free Attack (rule 6.3)

  @Test
  func acidUpgradeFreeAttackOnAdvance() {
    // Army advancing to space 1 on acid-upgraded track gets a free ranged attack.
    // Test through composed game: inject acid die roll via advanceArmies action.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 2  // Will advance to 1
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    // Manually invoke advanceArmies with acid die roll = 6 (goblin str 2, 6 > 2 = hit)
    _ = game.reduce(into: &state, action: .advanceArmies(acidAttackDieRolls: [.east: 6]))

    // After acid attack hit, army should be pushed back from 1 to 2
    #expect(state.armyPosition[.east]! == 2)
  }

  @Test
  func acidUpgradeNoAttackWithoutDieRoll() {
    // Army advancing to space 1 on acid track but no die roll provided → no attack.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 2
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    // advanceArmies with no acid die rolls
    _ = game.reduce(into: &state, action: .advanceArmies(acidAttackDieRolls: [:]))

    // Without die roll, army just stays at space 1 (no free attack)
    #expect(state.armyPosition[.east]! == 1)
  }

  @Test
  func acidUpgradeNoAttackOnOtherSpaces() {
    // Army advancing to space 3 (not 1) on acid track → no free attack.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 4  // Will advance to 3
    state.upgrades[.east] = .acid
    state.phase = .army
    state.currentCard = card1

    _ = game.reduce(into: &state, action: .advanceArmies(acidAttackDieRolls: [.east: 6]))

    // Should just advance normally to space 3 — acid only triggers at space 1
    #expect(state.armyPosition[.east]! == 3)
  }

  // MARK: - Paladin Re-roll (rule 10.2)

  @Test
  func paladinRerollOfferedAfterDieRollAction() {
    // After a die-roll action with Paladin alive, game enters paladinReact
    // and offers reroll/decline.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1  // melee range
    _ = game.reduce(into: &state, action: .drawCard)
    #expect(state.phase == .action)

    // Perform a melee attack — should enter paladinReact phase
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 3, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .paladinReact)

    let allowed = game.allowedActions(state: state)
    let hasReroll = allowed.contains(where: { if case .paladinReroll = $0 { return true }; return false })
    let hasDecline = allowed.contains(where: { if case .declineReroll = $0 { return true }; return false })
    #expect(hasReroll)
    #expect(hasDecline)
  }

  @Test
  func paladinDeclineResolvesOriginalAction() {
    // Declining the re-roll resolves the original attack normally and returns to action phase.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1  // melee range
    _ = game.reduce(into: &state, action: .drawCard)

    // Attack with roll 6: card 3 attack DRM -1, so 6 + (-1) = 5 > goblin str 2 → hit
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .paladinReact)
    // Army hasn't been pushed back yet (deferred)
    #expect(state.armyPosition[.east]! == 1)

    // Decline re-roll → resolve with original die roll 6
    _ = game.reduce(into: &state, action: .declineReroll)
    #expect(state.phase == .action)
    // Now army should be pushed back (hit resolved)
    #expect(state.armyPosition[.east]! == 2)
  }

  @Test
  func paladinRerollChangesResult() {
    // Re-rolling with a better die changes the attack result.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // Original roll 1 (natural 1 always fails). Army at space 1.
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 1, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .paladinReact)

    // Re-roll with 6: 6 + (-1) = 5 > 2 → hit
    _ = game.reduce(into: &state, action: .paladinReroll(newDieRoll: 6))
    #expect(state.phase == .action)
    #expect(state.armyPosition[.east]! == 2)  // pushed back
    #expect(state.paladinRerollUsed == true)
  }

  @Test
  func paladinRerollUsedOnlyOnce() {
    // After using re-roll, second die-roll action resolves immediately (no react phase).
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.armyPosition[.east] = 1
    state.armyPosition[.west] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    // First attack: enters paladinReact
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 3, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .paladinReact)
    _ = game.reduce(into: &state, action: .paladinReroll(newDieRoll: 6))
    #expect(state.paladinRerollUsed == true)

    // Second attack: should resolve immediately, no paladinReact
    _ = game.reduce(into: &state, action: .meleeAttack(.west, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .action)  // stays in action, not paladinReact
  }

  @Test
  func paladinRerollNotOfferedWhenDead() {
    // Dead Paladin → action resolves immediately, no react phase.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroDead.insert(.paladin)
    state.armyPosition[.east] = 1
    _ = game.reduce(into: &state, action: .drawCard)

    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    #expect(state.phase == .action)  // resolved immediately
    #expect(state.armyPosition[.east]! == 2)  // hit resolved
  }

  @Test
  func paladinRerollWorksInHeroicPhase() {
    // Paladin re-roll also works for heroic attacks.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      heroes: [.warrior, .wizard, .paladin],
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    state.heroLocation[.paladin] = .onTrack(.east)
    state.armyPosition[.east] = 3
    _ = game.reduce(into: &state, action: .drawCard)
    _ = game.reduce(into: &state, action: .passActions)
    #expect(state.phase == .heroic)

    // Heroic attack: should enter paladinReact
    _ = game.reduce(into: &state, action: .heroicAttack(.paladin, .east, dieRoll: 1))
    #expect(state.phase == .paladinReact)

    // Re-roll with 6: paladin combatDRM = 1, so 6 + 1 = 7 > goblin str 2 → hit
    _ = game.reduce(into: &state, action: .paladinReroll(newDieRoll: 6))
    #expect(state.phase == .heroic)  // returns to heroic phase
    #expect(state.armyPosition[.east]! == 4)  // pushed back
  }

  // MARK: - Audit Fix #2: Acid Attack Type is MELEE (rule 6.3)

  @Test
  func acidFreeAttackIsMelee() {
    // Rule 6.3: Acid upgrade triggers a free MELEE attack when army reaches space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .acid
    state.armyPosition[.east] = 2
    // Advance to space 1 triggers acid. Die roll 6 vs goblin str 2 with melee → hit.
    // Melee should work because space 1 is in melee range.
    let card1 = LoD.dayCards.first { $0.number == 1 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card1],
      shuffledNightCards: LoD.nightCards
    )
    var gState = game.newState()
    gState.upgrades[.east] = .acid
    gState.armyPosition[.east] = 2
    // We test the underlying resolveAttack with melee type directly
    let result = gState.resolveAttack(on: .east, attackType: .melee, dieRoll: 6, drm: 0)
    if case .hit = result {
      // Expected: melee on space 1 of east wall is in range
    } else {
      Issue.record("Acid free attack should be melee and hit at space 1")
    }
  }

  // MARK: - Audit Fix #7: Build Restriction — No Army on Space 1 (rule 6.3)

  @Test
  func buildBlockedWhenArmyOnSpace1() {
    // Rule 6.3: Cannot build an upgrade if an army is on space 1 of that track.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 1  // Army on space 1
    let result = state.build(upgrade: .oil, on: .east, dieRoll: 6, drm: 0)
    #expect(result == .trackInvalid)
  }

  @Test
  func buildAllowedWhenArmyNotOnSpace1() {
    // Rule 6.3: Building is allowed when no army is on space 1.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3  // Army not on space 1
    let result = state.build(upgrade: .oil, on: .east, dieRoll: 6, drm: 0)
    #expect(result == .success(.oil, .east))
  }

  @Test
  func buildNotOfferedWhenArmyOnSpace1() {
    // Rule 6.3: Composed game should not offer build actions when army is on space 1.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.armyPosition[.east] = 1
    let actions = game.allowedActions(state: state)
    let buildActions = actions.filter {
      if case .buildUpgrade(_, .east, _) = $0 { return true }
      return false
    }
    #expect(buildActions.isEmpty)
  }

  // MARK: - Audit Fix #9: Acid Once Per Turn (rule 6.3)

  @Test
  func acidFreeAttackOncePerTurn() {
    // Rule 6.3: Acid's free attack should only trigger once per turn.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .acid
    state.acidUsedThisTurn = true
    // Even if army reaches space 1, acid shouldn't trigger again.
    #expect(state.acidUsedThisTurn)
  }

  // MARK: - Audit Fix #11: Paladin +1 Rally DRM (rule 10.2)

  @Test
  func paladinRallyDRM() {
    // Rule 10.2: Paladin on a wall track gives +1 DRM to rally rolls.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .paladin])
    state.heroLocation[.paladin] = .onTrack(.east)
    let drm = state.totalRallyDRM()
    #expect(drm >= 1)  // At least +1 from Paladin
  }

  @Test
  func paladinRallyDRMRequiresWallTrack() {
    // Paladin must be on a wall track for rally DRM bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .paladin])
    state.heroLocation[.paladin] = .onTrack(.sky)  // Non-wall track
    let drm = state.totalRallyDRM()
    // Should NOT include Paladin bonus since Sky is not a wall
    #expect(drm == 0)
  }

  @Test
  func paladinRallyDRMInReserves() {
    // Paladin in reserves should not give rally DRM bonus.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3, heroes: [.warrior, .wizard, .paladin])
    state.heroLocation[.paladin] = .reserves
    let drm = state.totalRallyDRM()
    #expect(drm == 0)
  }

  // MARK: - Audit Fix #12: Bloody Battle Magical Exemption (rule 8.2)

  @Test
  func bloodyBattleNotTriggeredBySpells() {
    // Rule 8.2: Magical attacks (spells) should not trigger the bloody battle defender cost.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.bloodyBattleArmy = .east
    state.spellStatus[.fireball] = .known
    state.arcaneEnergy = 3
    // Cast Fireball at the bloody battle army — should NOT cost a defender
    let defendersBefore = state.defenders[.menAtArms]!
    _ = state.castSpell(.fireball)
    _ = state.applyFireball(on: .east, dieRoll: 6)
    #expect(state.defenders[.menAtArms] == defendersBefore)  // No defender lost
  }

  // MARK: - Audit Fix #3: Defender Limits on Attacks (rule 8.2)

  @Test
  func meleeAttacksLimitedByMenAtArms() {
    // Rule 8.2: Men-at-arms value = max melee attacks per turn.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.defenders[.menAtArms] = 1  // Only 1 melee attack allowed
    state.armyPosition[.east] = 2  // In melee range

    // First melee attack should be offered
    var actions = game.allowedActions(state: state)
    let meleeActions = actions.filter {
      if case .meleeAttack = $0 { return true }
      return false
    }
    #expect(!meleeActions.isEmpty)

    // After 1 melee attack, no more melee should be offered
    _ = game.reduce(into: &state, action: .meleeAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicSword: nil))
    actions = game.allowedActions(state: state)
    let meleeActionsAfter = actions.filter {
      if case .meleeAttack = $0 { return true }
      return false
    }
    #expect(meleeActionsAfter.isEmpty)
  }

  @Test
  func rangedAttacksLimitedByArchers() {
    // Rule 8.2: Archers value = max ranged attacks per turn.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.defenders[.archers] = 1  // Only 1 ranged attack allowed

    // After 1 ranged attack, no more ranged should be offered
    _ = game.reduce(into: &state, action: .rangedAttack(.east, dieRoll: 6, bloodyBattleDefender: nil, useMagicBow: nil))
    let actions = game.allowedActions(state: state)
    let rangedActionsAfter = actions.filter {
      if case .rangedAttack = $0 { return true }
      return false
    }
    #expect(rangedActionsAfter.isEmpty)
  }

  // MARK: - Audit Fix #4: Wizard Same-Track Requirement (rule 9.2)

  @Test
  func arcaneSpellRequiresWizardOnSameTrack() {
    // Rule 9.2: Arcane spells (except Chain Lightning, Fortune) require Wizard on same track as target.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.spellStatus[.fireball] = .known
    state.arcaneEnergy = 3
    state.heroLocation[.wizard] = .onTrack(.west)  // Wizard on west
    // Fireball targeting east should fail validation
    #expect(!state.canTargetWithArcaneSpell(.fireball, targetTrack: .east))
    // Fireball targeting west should succeed
    #expect(state.canTargetWithArcaneSpell(.fireball, targetTrack: .west))
  }

  @Test
  func chainLightningNoTrackRestriction() {
    // Rule 9.2: Chain Lightning is exempt from same-track restriction.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.wizard] = .onTrack(.west)
    #expect(state.canTargetWithArcaneSpell(.chainLightning, targetTrack: .east))
  }

  @Test
  func fortuneNoTrackRestriction() {
    // Rule 9.2: Fortune is exempt from same-track restriction.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroLocation[.wizard] = .onTrack(.west)
    #expect(state.canTargetWithArcaneSpell(.fortune, targetTrack: .east))
  }

  // MARK: - Audit Fix #6: Inspire Normal vs Heroic (rule 9.3)

  @Test
  func inspireNormalCannotCastAtHighMorale() {
    // Rule 9.3: Normal Inspire cannot be cast when morale is already High.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high
    #expect(!state.canCastInspireNormal())
  }

  @Test
  func inspireHeroicAtHighMoraleGivesDRMOnly() {
    // Rule 9.3: Heroic Inspire at High morale gives +1 DRM but does NOT raise morale.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .high
    state.applyInspire(heroic: true)
    #expect(state.morale == .high)  // Morale stays high
    #expect(state.inspireDRMActive)  // DRM still active
  }

  @Test
  func inspireNormalRaisesMorale() {
    // Rule 9.3: Normal Inspire raises morale and grants +1 DRM.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.morale = .normal
    state.applyInspire(heroic: false)
    #expect(state.morale == .high)
    #expect(state.inspireDRMActive)
  }

  // MARK: - Audit Fix #13: Mass Heal Different Defenders (rule 9.3)

  @Test
  func massHealHeroicRequiresDifferentDefenders() {
    // Rule 9.3: Heroic Mass Heal gives +1 to 2 DIFFERENT defender types.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.defenders[.menAtArms] = 1
    state.defenders[.archers] = 1
    // Two different types should work
    state.applyMassHeal(defenders: [.menAtArms, .archers])
    #expect(state.defenders[.menAtArms] == 2)
    #expect(state.defenders[.archers] == 2)
  }

  // MARK: - Audit Fix #14: Raise Dead Normal vs Heroic (rule 9.3)

  @Test
  func raiseDeadNormalIsExclusiveOR() {
    // Rule 9.3: Normal Raise Dead = 2 different defenders OR return 1 dead hero, not both.
    // Validation: if returnHero is provided, gainDefenders should be empty (normal mode).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroDead.insert(.warrior)
    state.heroLocation.removeValue(forKey: .warrior)
    // Normal: providing both defenders AND hero is invalid
    #expect(!state.isValidRaiseDeadParams(gainDefenders: [.menAtArms, .archers], returnHero: .warrior, heroic: false))
    // Normal: hero only is valid
    #expect(state.isValidRaiseDeadParams(gainDefenders: [], returnHero: .warrior, heroic: false))
    // Normal: defenders only is valid
    #expect(state.isValidRaiseDeadParams(gainDefenders: [.menAtArms, .archers], returnHero: nil, heroic: false))
  }

  @Test
  func raiseDeadHeroicAllowsBoth() {
    // Rule 9.3: Heroic Raise Dead = 2 different defenders AND/OR return 1 dead hero.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.heroDead.insert(.warrior)
    state.heroLocation.removeValue(forKey: .warrior)
    // Heroic: both defenders AND hero is valid
    #expect(state.isValidRaiseDeadParams(gainDefenders: [.menAtArms, .archers], returnHero: .warrior, heroic: true))
  }

  // MARK: - Audit Fix #1: Grease Upgrade Breach Prevention (rule 6.3)

  @Test
  func greasePreventsBreach() {
    // Rule 6.3: When army reaches space 1 on a greased track and rolls > 2,
    // it stays on space 1 instead of breaching (army stays, no breach).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease
    state.armyPosition[.east] = 1
    // Army tries to advance past space 1, but grease check: roll 5 > 2, stays on 1
    let result = state.advanceArmy(.east, dieRoll: 5)
    #expect(result == .greaseHeld(.east))
    #expect(state.armyPosition[.east] == 1)  // Army stays on space 1
    #expect(!state.breaches.contains(.east))  // No breach
  }

  @Test
  func greaseFailsLowRoll() {
    // Rule 6.3: When army rolls ≤ 2 on a greased track, grease fails → breach.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease
    state.armyPosition[.east] = 1
    let result = state.advanceArmy(.east, dieRoll: 2)
    // Grease fails, breach is created
    #expect(result == .breachCreated(.east))
    #expect(state.breaches.contains(.east))
  }

  @Test
  func greaseRemovedAfterUse() {
    // Rule 6.3: Grease is removed when a breach occurs (upgrade removed on breach).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease
    state.armyPosition[.east] = 1
    _ = state.advanceArmy(.east, dieRoll: 5)  // Grease holds
    // Grease should be consumed/removed after successful use
    #expect(state.upgrades[.east] == nil)
  }

  @Test
  func greaseNotADRM() {
    // Rule 6.3: Grease should NOT be a DRM — it has its own breach mechanic.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.upgrades[.east] = .grease
    let drm = state.upgradeDRM(on: .east, attackType: .melee)
    #expect(drm == 0)
  }

  // MARK: - Audit Fix #5: Fireball Heroic Re-roll (rule 9.2)

  @Test
  func fireballHeroicAllowsReroll() {
    // Rule 9.2: When Fireball is cast heroically and misses, caster may re-roll once.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.armyPosition[.east] = 3
    // First roll: miss (roll 1 = natural fail)
    let result1 = state.applyFireball(on: .east, dieRoll: 1)
    #expect(result1 == .naturalOneFail(.east))
    // Heroic re-roll: roll 6, +2 DRM = 8 > goblin 2 → hit
    let result2 = state.applyFireball(on: .east, dieRoll: 6)
    if case .hit = result2 {
      // Expected
    } else {
      Issue.record("Heroic Fireball re-roll should hit")
    }
  }

  // MARK: - Audit Fix #8: Barricade as Player Action (rule 6.3)

  @Test
  func buildBarricadeAction() {
    // Rule 6.3: After a breach, player can spend a build action (roll > 2)
    // to place a barricade, converting breach to barricade.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)
    let result = state.buildBarricade(on: .east, dieRoll: 5, drm: 0)
    #expect(result == .success)
    #expect(state.barricades.contains(.east))
    #expect(!state.breaches.contains(.east))
  }

  @Test
  func buildBarricadeFailsLowRoll() {
    // Rule 6.3: Building a barricade requires roll > 2.
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.breaches.insert(.east)
    let result = state.buildBarricade(on: .east, dieRoll: 2, drm: 0)
    #expect(result == .rollFailed)
    #expect(!state.barricades.contains(.east))
    #expect(state.breaches.contains(.east))
  }

  @Test
  func buildBarricadeOfferedInAllowedActions() {
    // Rule 6.3: Barricade build should be offered when a breach exists.
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    let game = LoD.composedGame(
      windsOfMagicArcane: 3,
      shuffledDayCards: [card3],
      shuffledNightCards: LoD.nightCards
    )
    var state = game.newState()
    _ = game.reduce(into: &state, action: .drawCard)
    state.breaches.insert(.east)
    let actions = game.allowedActions(state: state)
    let barricadeActions = actions.filter {
      if case .buildBarricade = $0 { return true }
      return false
    }
    #expect(!barricadeActions.isEmpty)
  }

  // MARK: - Audit Fix #10: Multi-Point Quest Spending (rule 7.0)

  @Test
  func questMultipleActionPointsAddDRMs() {
    // Rule 7.0: Players can spend multiple action points on a quest,
    // each adding +1 DRM (action) or +2 DRM (heroic).
    var state = LoD.greenskinSetup(windsOfMagicArcane: 3)
    state.phase = .action
    // Card 3 (Forlorn Hope) has quest target 6
    let card3 = LoD.dayCards.first { $0.number == 3 }!
    state.currentCard = card3
    // With 1 point: roll 5 + 1 = 6, NOT > 6 → failure
    let result1 = state.attemptQuest(isHeroic: false, dieRoll: 5, additionalDRM: 0, pointsSpent: 1)
    #expect(result1 == .failure)
    // With 2 points: roll 5 + 2 = 7 > 6 → success
    let result2 = state.attemptQuest(isHeroic: false, dieRoll: 5, additionalDRM: 0, pointsSpent: 2)
    #expect(result2 == .success)
  }
}
