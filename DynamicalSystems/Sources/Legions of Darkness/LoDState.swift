//
//  LoDState.swift
//  DynamicalSystems
//
//  Legions of Darkness — Game state.
//

import Foundation

extension LoD {

  struct State: Equatable, Sendable, HistoryTracking {

    // MARK: - Turn structure

    var phase: Phase = .setup
    var scenario: Scenario = .greenskinHorde

    // MARK: - History (HistoryTracking conformance)

    var history: [LoD.Action] = []

    // MARK: - Armies

    /// What type of army occupies each slot (set during setup, fixed for the game).
    var armyType: [ArmySlot: ArmyType] = [:]

    /// Current space number for each army. Absent = not yet placed / removed.
    var armyPosition: [ArmySlot: Int] = [:]

    // MARK: - Heroes

    /// Location of each hero in play. Heroes not in play are absent from this dict.
    var heroLocation: [HeroType: HeroLocation] = [:]

    /// Which heroes are wounded.
    var heroWounded: Set<HeroType> = []

    /// Which heroes are dead.
    var heroDead: Set<HeroType> = []

    // MARK: - Defenders

    var defenders: [DefenderType: Int] = [
      .menAtArms: DefenderType.menAtArms.maxValue,
      .archers: DefenderType.archers.maxValue,
      .priests: DefenderType.priests.maxValue,
    ]

    // MARK: - Morale

    var morale: Morale = .normal

    // MARK: - Magic energy

    var arcaneEnergy: Int = 0
    var divineEnergy: Int = 0

    // MARK: - Spells

    var spellStatus: [SpellType: SpellStatus] = {
      var d: [SpellType: SpellStatus] = [:]
      for spell in SpellType.allCases {
        d[spell] = .faceDown
      }
      return d
    }()

    // MARK: - Upgrades (placed on wall track castle circles)

    var upgrades: [Track: UpgradeType] = [:]

    // MARK: - Breaches and barricades (wall tracks only)

    var breaches: Set<Track> = []
    var barricades: Set<Track> = []

    // MARK: - Time

    var timePosition: Int = 0

    // MARK: - Bloody battle

    /// Which army slot has the bloody battle marker, if any.
    var bloodyBattleArmy: ArmySlot? = nil

    /// Whether the bloody battle defender cost has already been paid this turn.
    var bloodyBattlePaidThisTurn: Bool = false

    // MARK: - Slow marker

    /// Which army slot has the Slow marker, if any.
    var slowedArmy: ArmySlot? = nil

    // MARK: - Card decks (rule 3.0)

    var dayDrawPile: [LoD.Card] = []
    var nightDrawPile: [LoD.Card] = []
    var dayDiscardPile: [LoD.Card] = []
    var nightDiscardPile: [LoD.Card] = []
    var currentCard: LoD.Card? = nil

    // MARK: - Per-turn tracking

    /// Whether the Paladin has used their re-roll this turn.
    var paladinRerollUsed: Bool = false

    /// Whether Inspire's +1 DRM to all rolls is active this turn.
    var inspireDRMActive: Bool = false

    /// Per-turn +1 attack DRM from events (Acts of Valor, Assassin's Creedo).
    var eventAttackDRMBonus: Int = 0

    /// Whether melee attacks are forbidden this turn (Lamentation of the Women).
    var noMeleeThisTurn: Bool = false

    /// Whether wounded heroes cannot act this turn (Council of Heroes).
    var woundedHeroesCannotAct: Bool = false

    // MARK: - Items (quest rewards)

    /// Whether the player holds the Magic Sword (from The Vorpal Blade quest).
    var hasMagicSword: Bool = false

    /// Whether the player holds the Magic Bow (from Arrows of the Dead quest).
    var hasMagicBow: Bool = false

    // MARK: - Victory / defeat (rule 11.0)

    var ended: Bool = false
    var victory: Bool = false

    enum GameOutcome: Equatable {
      case ongoing
      case victory
      case defeatBreached
      case defeatAllDefendersLost
    }

    /// Current game outcome.
    var outcome: GameOutcome {
      if !ended { return .ongoing }
      if victory { return .victory }
      if allDefendersAtZero { return .defeatAllDefendersLost }
      return .defeatBreached
    }

    /// Check for victory at the end of the Final Twilight turn (rule 11.0).
    /// Call this during housekeeping of the last turn.
    mutating func checkVictory() {
      guard !ended else { return }
      if isOnFinalTwilight {
        ended = true
        victory = true
      }
    }

    // MARK: - Queries

    /// Whether all defenders are at zero (defeat condition per rule 4.4 / 11.1).
    var allDefendersAtZero: Bool {
      defenders.values.allSatisfy { $0 == 0 }
    }

    /// Current time space type.
    var currentTimeSpace: TimeSpaceType {
      LoDComponents.timeTrack[timePosition]
    }

    /// Whether the current time space draws from the day deck.
    var drawsFromDayDeck: Bool {
      LoDComponents.drawsFromDayDeck(at: timePosition)
    }

    /// Heroes currently alive and in play.
    var livingHeroes: [HeroType] {
      heroLocation.keys.filter { !heroDead.contains($0) }.sorted { $0.rawValue < $1.rawValue }
    }

    /// Whether a given track has an army at space 1 (relevant for breach/build rules).
    func armyAtSpace1(on track: Track) -> Bool {
      for slot in ArmySlot.allCases where slot.track == track {
        if armyPosition[slot] == 1 { return true }
      }
      return false
    }

    // MARK: - Budget Tracking (action/heroic phases)

    /// How many action points this turn's card grants (card.actions + morale modifier).
    var actionBudget: Int {
      guard let card = currentCard else { return 0 }
      return max(card.actions + morale.actionModifier, 0)
    }

    /// How many heroic points this turn's card grants.
    var heroicBudget: Int {
      currentCard?.heroics ?? 0
    }

    /// Count action-phase actions taken this turn (since last .advanceArmies or .resolveEvent or .skipEvent).
    var actionPointsSpent: Int {
      var count = 0
      for action in history.reversed() {
        switch action {
        case .skipEvent, .resolveEvent:
          return count
        case .meleeAttack, .rangedAttack, .buildUpgrade, .chant, .memorize, .pray, .questAction:
          count += 1
        default:
          break
        }
      }
      return count
    }

    /// Count heroic-phase actions taken this turn (since last .passActions).
    var heroicPointsSpent: Int {
      var count = 0
      for action in history.reversed() {
        switch action {
        case .passActions:
          return count
        case .moveHero, .heroicAttack, .rally, .questHeroic:
          count += 1
        default:
          break
        }
      }
      return count
    }

    /// Remaining action points this turn.
    var actionBudgetRemaining: Int {
      max(actionBudget - actionPointsSpent, 0)
    }

    /// Remaining heroic points this turn.
    var heroicBudgetRemaining: Int {
      max(heroicBudget - heroicPointsSpent, 0)
    }

    // MARK: - Army Advancement (rule 4.1)

    /// Result of attempting to advance an army one space toward the castle.
    enum AdvanceResult: Equatable {
      case advanced(ArmySlot, from: Int, to: Int)
      case breachCreated(Track)
      case armyEnteredCastle(Track)
      case barricadeHeld(Track)
      case armyBrokeBarricade(Track)
      case defenderLoss
      case notOnBoard
      case slowMarkerRemoved(ArmySlot)
    }

    /// Advance a single army slot one space toward the castle (space number decreases).
    /// For barricade tests, provide `dieRoll`.
    mutating func advanceArmy(_ slot: ArmySlot, dieRoll: Int? = nil) -> AdvanceResult {
      guard let currentSpace = armyPosition[slot] else {
        return .notOnBoard
      }

      // Slow spell: remove marker instead of advancing
      if slowedArmy == slot {
        slowedArmy = nil
        return .slowMarkerRemoved(slot)
      }

      let track = slot.track
      let newSpace = currentSpace - 1

      // Terror and Sky special rule (4.4): cannot enter castle
      if !track.isWall && newSpace < 1 {
        return .defenderLoss
      }

      // Wall track advancing to space 0 (4.1.2, 4.1.3)
      if track.isWall && newSpace == 0 {
        if barricades.contains(track) {
          // Barricade test (4.1.3)
          let roll = dieRoll!
          let strength = armyType[slot]!.strength
          if roll <= strength {
            barricades.remove(track)
            armyPosition[slot] = 0
            ended = true
            return .armyBrokeBarricade(track)
          } else {
            barricades.remove(track)
            breaches.insert(track)
            return .barricadeHeld(track)
          }
        } else if !breaches.contains(track) {
          // First time: create breach, remove any upgrade (4.1.2)
          upgrades.removeValue(forKey: track)
          breaches.insert(track)
          return .breachCreated(track)
        } else {
          // Breach exists: army enters → defeat
          armyPosition[slot] = 0
          ended = true
          return .armyEnteredCastle(track)
        }
      }

      // Normal advance
      armyPosition[slot] = newSpace
      return .advanced(slot, from: currentSpace, to: newSpace)
    }

    /// Process one advance icon for a given track.
    /// For the Gate track, applies rule 4.1.1 (farthest advances first; tied = both).
    mutating func advanceArmyOnTrack(_ track: Track, dieRoll: Int? = nil) -> [AdvanceResult] {
      if track == .gate {
        return advanceGateArmies(dieRoll: dieRoll)
      }
      guard let slot = ArmySlot.allCases.first(where: { $0.track == track }) else {
        return []
      }
      return [advanceArmy(slot, dieRoll: dieRoll)]
    }

    /// Gate track advancement per rule 4.1.1.
    private mutating func advanceGateArmies(dieRoll: Int? = nil) -> [AdvanceResult] {
      let pos1 = armyPosition[.gate1]
      let pos2 = armyPosition[.gate2]

      switch (pos1, pos2) {
      case (nil, nil):
        return [.notOnBoard]
      case (_?, nil):
        return [advanceArmy(.gate1, dieRoll: dieRoll)]
      case (nil, _?):
        return [advanceArmy(.gate2, dieRoll: dieRoll)]
      case (let p1?, let p2?):
        if p1 > p2 {
          return [advanceArmy(.gate1, dieRoll: dieRoll)]
        } else if p2 > p1 {
          return [advanceArmy(.gate2, dieRoll: dieRoll)]
        } else {
          let r1 = advanceArmy(.gate1, dieRoll: dieRoll)
          let r2 = advanceArmy(.gate2, dieRoll: dieRoll)
          return [r1, r2]
        }
      }
    }

    /// Lose one defender of the specified type (rule 8.2.1).
    mutating func loseDefender(_ type: DefenderType) {
      if let current = defenders[type], current > 0 {
        defenders[type] = current - 1
      }
      if allDefendersAtZero {
        ended = true
      }
    }

    // MARK: - Time Track Advancement (rule 3.1)

    /// Advance the time marker by the given number of spaces.
    /// Triggers twilight (3.1.1) and dawn (3.1.2) effects for each such space
    /// entered or passed through. Clamped at position 15 (Final Twilight).
    mutating func advanceTime(by spaces: Int) {
      guard spaces > 0 else { return }

      let finalPosition = 15
      for _ in 0..<spaces {
        guard timePosition < finalPosition else { return }
        timePosition += 1
        let spaceType = LoDComponents.timeTrack[timePosition]

        switch spaceType {
        case .twilight:
          // Rule 3.1.1: +1 arcane energy, place Terror army at space 3
          arcaneEnergy = min(arcaneEnergy + 1, 6)
          armyPosition[.terror] = 3
        case .dawn:
          // Rule 3.1.2: -1 morale, +1 arcane energy, remove Terror army
          morale = morale.lowered()
          arcaneEnergy = min(arcaneEnergy + 1, 6)
          armyPosition.removeValue(forKey: .terror)
        case .day, .night:
          break
        }
      }
    }

    /// Whether the time marker is on the Final Twilight (victory check).
    var isOnFinalTwilight: Bool {
      timePosition == 15
    }

    // MARK: - Battle Resolution (rule 8.0)

    enum AttackType: Equatable {
      case melee
      case ranged
    }

    enum AttackResult: Equatable {
      case hit(ArmySlot, pushedFrom: Int, pushedTo: Int)
      case miss(ArmySlot)
      case naturalOneFail(ArmySlot)
      case targetNotOnBoard
      case targetNotInMeleeRange
      case targetNotInRange
    }

    /// Resolve an attack action against an army.
    ///
    /// - Parameters:
    ///   - slot: Which army to attack.
    ///   - attackType: `.melee` or `.ranged`.
    ///   - dieRoll: The natural d6 roll (1–6) before any modifiers.
    ///   - drm: Total die-roll modifier (hero bonuses, upgrade bonuses, etc.).
    ///   - isMagical: Whether this is a magical attack (ignores negative DRMs in melee range).
    /// - Returns: The result of the attack.
    mutating func resolveAttack(
      on slot: ArmySlot,
      attackType: AttackType,
      dieRoll: Int,
      drm: Int = 0,
      isMagical: Bool = false
    ) -> AttackResult {
      guard let space = armyPosition[slot] else {
        return .targetNotOnBoard
      }

      let track = slot.track

      // Natural 1 always fails (rules_notes: die rolls)
      if dieRoll == 1 {
        return .naturalOneFail(slot)
      }

      // Range validation
      switch attackType {
      case .melee:
        if !track.isMeleeRange(space: space) {
          return .targetNotInMeleeRange
        }
      case .ranged:
        // Ranged can target any space — but Terror is melee-only (rule 4.2)
        if track == .terror {
          return .targetNotInRange
        }
      }

      // Apply DRMs
      var effectiveDRM = drm
      // Magical attacks in melee range ignore negative DRMs
      if isMagical && track.isMeleeRange(space: space) {
        effectiveDRM = max(effectiveDRM, 0)
      }

      let modifiedRoll = dieRoll + effectiveDRM
      let strength = armyType[slot]!.strength

      if modifiedRoll > strength {
        // Hit — push army back one space (away from castle)
        let newSpace = min(space + 1, track.maxSpace)
        armyPosition[slot] = newSpace
        return .hit(slot, pushedFrom: space, pushedTo: newSpace)
      } else {
        return .miss(slot)
      }
    }

    // MARK: - Heroic Attack (rule 7.0)

    struct HeroicAttackResult: Equatable {
      let attackResult: AttackResult
      let heroWounded: Bool
      let heroKilled: Bool
    }

    enum HeroicAttackError: Error, Equatable {
      case heroNotOnTrack
      case heroOnWrongTrack
    }

    /// Resolve a heroic attack by a hero against an army (rule 7.3).
    /// The hero must be assigned to the same track as the target army.
    /// The hero's combat DRM and attack type are used automatically.
    /// On natural 1: attack fails AND hero is wounded (unless immune).
    mutating func resolveHeroicAttack(
      hero: HeroType,
      on slot: ArmySlot,
      dieRoll: Int,
      additionalDRM: Int = 0
    ) -> Result<HeroicAttackResult, HeroicAttackError> {
      // Rule 7.3: hero must be on the same track as the target army
      guard let location = heroLocation[hero] else {
        return .failure(.heroNotOnTrack)
      }
      guard case .onTrack(let heroTrack) = location, heroTrack == slot.track else {
        return .failure(.heroOnWrongTrack)
      }

      let attackType: AttackType = hero.isRangedCombatant ? .ranged : .melee
      let totalDRM = hero.combatDRM + additionalDRM

      let result = resolveAttack(
        on: slot,
        attackType: attackType,
        dieRoll: dieRoll,
        drm: totalDRM
      )

      // Natural 1: wound hero (unless immune)
      var wounded = false
      var killed = false
      if dieRoll == 1 && !hero.isWoundImmuneInCombat {
        if heroWounded.contains(hero) {
          // Already wounded → killed
          heroDead.insert(hero)
          heroWounded.remove(hero)
          heroLocation.removeValue(forKey: hero)
          killed = true
        } else {
          heroWounded.insert(hero)
          wounded = true
        }
      }

      return .success(HeroicAttackResult(
        attackResult: result,
        heroWounded: wounded,
        heroKilled: killed
      ))
    }

    // MARK: - Hero Wounding

    /// Wound a hero. If already wounded, the hero dies.
    mutating func woundHero(_ hero: HeroType) {
      if heroWounded.contains(hero) {
        heroDead.insert(hero)
        heroWounded.remove(hero)
        heroLocation.removeValue(forKey: hero)
      } else {
        heroWounded.insert(hero)
      }
    }

    // MARK: - Upgrade DRM (rule 6.3)

    /// DRM bonus from an upgrade on a track, for an army at a given space.
    /// Only applies to armies at space 1.
    func upgradeDRM(on track: Track, attackType: AttackType) -> Int {
      guard let upgrade = upgrades[track] else { return 0 }
      // Upgrades only affect armies at space 1 (per Player Aid)
      switch upgrade {
      case .grease, .oil:
        // +1 DRM to melee or ranged in space 1
        return 1
      case .lava:
        // +2 DRM to melee against army in space 1
        return attackType == .melee ? 2 : 0
      case .acid:
        // Acid gives a free attack, not a DRM bonus
        return 0
      }
    }

    // MARK: - Gate Targeting (rules 4.1.1, 8.1.2)

    /// Which army slot on the Gate track is eligible to be attacked.
    /// Rule: only the closest (lowest space number). If tied, either can be targeted (player choice, rule 8.1.2).
    func gateAttackTargets() -> [ArmySlot] {
      let pos1 = armyPosition[.gate1]
      let pos2 = armyPosition[.gate2]

      switch (pos1, pos2) {
      case (nil, nil): return []
      case (_?, nil): return [.gate1]
      case (nil, _?): return [.gate2]
      case (let p1?, let p2?):
        if p1 < p2 { return [.gate1] }
        else if p2 < p1 { return [.gate2] }
        else { return [.gate1, .gate2] } // tied — player chooses
      }
    }

    // MARK: - Bloody Battle (Player Aid: Markers)

    /// Check whether an attack against `slot` triggers the bloody battle
    /// defender cost. Returns true if a defender must be lost.
    /// Automatically marks the cost as paid for this turn.
    mutating func checkBloodyBattle(attacking slot: ArmySlot) -> Bool {
      guard bloodyBattleArmy == slot, !bloodyBattlePaidThisTurn else {
        return false
      }
      bloodyBattlePaidThisTurn = true
      return true
    }

    // MARK: - Paladin Re-roll (Player Aid: Paladin — holy)

    /// Whether the Paladin can use their once-per-turn re-roll.
    var canPaladinReroll: Bool {
      !paladinRerollUsed
        && heroLocation[.paladin] != nil
        && !heroDead.contains(.paladin)
    }

    /// Mark the Paladin re-roll as used for this turn.
    mutating func usePaladinReroll() {
      paladinRerollUsed = true
    }

    // MARK: - Actions (rule 6.0)

    // -- Memorize (rule 6.6) --

    /// Face-down arcane spells available to memorize.
    var faceDownArcaneSpells: [SpellType] {
      SpellType.arcaneSpells.filter { spellStatus[$0] == .faceDown }
    }

    /// Memorize action: reveal a face-down arcane spell (mark as known).
    /// `spell` is the randomly-selected spell (injected for deterministic testing).
    mutating func memorize(spell: SpellType) -> Bool {
      guard spell.isArcane, spellStatus[spell] == .faceDown else {
        return false
      }
      spellStatus[spell] = .known
      return true
    }

    // -- Pray (rule 6.7) --

    /// Face-down divine spells available to pray for.
    var faceDownDivineSpells: [SpellType] {
      SpellType.divineSpells.filter { spellStatus[$0] == .faceDown }
    }

    /// Pray action: reveal a face-down divine spell (mark as known).
    /// `spell` is the randomly-selected spell (injected for deterministic testing).
    mutating func pray(spell: SpellType) -> Bool {
      guard spell.isDivine, spellStatus[spell] == .faceDown else {
        return false
      }
      spellStatus[spell] = .known
      return true
    }

    // -- Chant (rule 6.5) --

    /// Chant action: roll > 3 (with priest DRM) to gain +1 divine energy.
    /// Natural 1 always fails.
    mutating func chant(dieRoll: Int, drm: Int = 0) -> Bool {
      if dieRoll == 1 { return false }
      let modified = dieRoll + drm
      if modified > 3 {
        divineEnergy = min(divineEnergy + 1, 6)
        return true
      }
      return false
    }

    // -- Build (rule 6.3) --

    enum BuildResult: Equatable {
      case success(UpgradeType, Track)
      case rollFailed
      case trackInvalid
    }

    /// Build action: roll > build number to place upgrade on a valid wall track.
    /// Track must be a wall, unbreached, and have no existing upgrade.
    /// Natural 1 always fails.
    mutating func build(
      upgrade: UpgradeType,
      on track: Track,
      dieRoll: Int,
      drm: Int = 0
    ) -> BuildResult {
      guard track.isWall, !breaches.contains(track), upgrades[track] == nil else {
        return .trackInvalid
      }
      if dieRoll == 1 { return .rollFailed }
      let modified = dieRoll + drm
      if modified > upgrade.buildNumber {
        upgrades[track] = upgrade
        return .success(upgrade, track)
      }
      return .rollFailed
    }

    // -- Cast Spell (rule 6.4) --

    enum CastSpellResult: Equatable {
      case success(SpellType, heroic: Bool)
      case spellNotKnown
      case insufficientEnergy
      case heroicRequiresHero
    }

    /// Known spells available to cast.
    var knownSpells: [SpellType] {
      SpellType.allCases.filter { spellStatus[$0] == .known }
    }

    /// Whether a spell can be heroically cast.
    /// Arcane heroic cast requires Wizard alive; divine requires Cleric alive.
    func canHeroicCast(_ spell: SpellType) -> Bool {
      if spell.isArcane {
        return heroLocation[.wizard] != nil && !heroDead.contains(.wizard)
      } else {
        return heroLocation[.cleric] != nil && !heroDead.contains(.cleric)
      }
    }

    /// Cast a spell: deduct energy, mark as cast.
    /// If `heroic` is true, the enhanced effect applies (requires Wizard for arcane,
    /// Cleric for divine). The spell effect itself is handled separately.
    mutating func castSpell(_ spell: SpellType, heroic: Bool = false) -> CastSpellResult {
      guard spellStatus[spell] == .known else {
        return .spellNotKnown
      }
      if heroic && !canHeroicCast(spell) {
        return .heroicRequiresHero
      }
      let cost = spell.energyCost
      if spell.isArcane {
        guard arcaneEnergy >= cost else { return .insufficientEnergy }
        arcaneEnergy -= cost
      } else {
        guard divineEnergy >= cost else { return .insufficientEnergy }
        divineEnergy -= cost
      }
      spellStatus[spell] = .cast
      return .success(spell, heroic: heroic)
    }

    // MARK: - Spell Effects (rules 9.2, 9.3)

    // -- Cure Wounds (divine, cost 1) --

    /// Heal wounded heroes. Normal: 1 hero. Heroic (†): up to 2 heroes.
    mutating func applyCureWounds(heroes: [HeroType]) {
      for hero in heroes {
        heroWounded.remove(hero)
      }
    }

    // -- Mass Heal (divine, cost 2) --

    /// Gain defenders. Normal: 1 defender. Heroic (†): 2 different defenders.
    mutating func applyMassHeal(defenders gainTypes: [DefenderType]) {
      for type in gainTypes {
        if let current = defenders[type] {
          defenders[type] = min(current + 1, type.maxValue)
        }
      }
    }

    // -- Inspire (divine, cost 3) --

    /// Raise morale one step and grant +1 DRM to all rolls until end of turn.
    /// Normal and heroic (†) have the same effect.
    mutating func applyInspire() {
      morale = morale.raised()
      inspireDRMActive = true
    }

    // -- Raise Dead (divine, cost 4) --

    /// Normal: gain 2 different defenders OR return 1 dead hero.
    /// Heroic (†): gain 2 different defenders AND/OR return 1 dead hero.
    mutating func applyRaiseDead(gainDefenders: [DefenderType], returnHero: HeroType?) {
      for type in gainDefenders {
        if let current = defenders[type] {
          defenders[type] = min(current + 1, type.maxValue)
        }
      }
      if let hero = returnHero {
        heroDead.remove(hero)
        heroLocation[hero] = .reserves
      }
    }

    // -- Fireball (arcane, cost 1) --

    /// Make a +2 magical attack. Heroic (∞): may re-roll.
    /// Returns the attack result. Caller handles re-roll decision.
    mutating func applyFireball(
      on slot: ArmySlot,
      dieRoll: Int,
      additionalDRM: Int = 0
    ) -> AttackResult {
      return resolveAttack(
        on: slot,
        attackType: .ranged,
        dieRoll: dieRoll,
        drm: 2 + additionalDRM,
        isMagical: true
      )
    }

    // -- Slow (arcane, cost 2) --

    /// Normal: place Slow marker on one army.
    /// Heroic (∞): retreat army one space first, then place marker.
    mutating func applySlow(on slot: ArmySlot, heroic: Bool = false) {
      if heroic {
        // Retreat army one space (push back away from castle)
        if let space = armyPosition[slot] {
          let track = slot.track
          armyPosition[slot] = min(space + 1, track.maxSpace)
        }
      }
      slowedArmy = slot
    }

    // -- Chain Lightning (arcane, cost 3) --

    /// Make 3 magical attacks. Normal: +2, +1, +0 DRMs. Heroic (∞): +3, +2, +1.
    /// Targets and die rolls provided as parallel arrays.
    mutating func applyChainLightning(
      targets: [(slot: ArmySlot, dieRoll: Int)],
      heroic: Bool = false,
      additionalDRM: Int = 0
    ) -> [AttackResult] {
      let baseDRMs = heroic ? [3, 2, 1] : [2, 1, 0]
      var results: [AttackResult] = []
      for (i, target) in targets.prefix(3).enumerated() {
        let result = resolveAttack(
          on: target.slot,
          attackType: .ranged,
          dieRoll: target.dieRoll,
          drm: baseDRMs[i] + additionalDRM,
          isMagical: true
        )
        results.append(result)
      }
      return results
    }

    // -- Divine Wrath (divine, cost 3) --

    /// Normal: 1 magical attack with +1 DRM; undead retreat +1.
    /// Heroic (†): 2 magical attacks (different targets) with +1 DRM; undead retreat +1.
    mutating func applyDivineWrath(
      targets: [(slot: ArmySlot, dieRoll: Int)],
      additionalDRM: Int = 0
    ) -> [AttackResult] {
      var results: [AttackResult] = []
      for target in targets {
        let result = resolveAttack(
          on: target.slot,
          attackType: .ranged,
          dieRoll: target.dieRoll,
          drm: 1 + additionalDRM,
          isMagical: true
        )
        // Undead retreat +1 on hit
        if case .hit(let slot, _, let pushedTo) = result {
          if let type = armyType[slot], type.isUndead {
            let track = slot.track
            armyPosition[slot] = min(pushedTo + 1, track.maxSpace)
          }
        }
        results.append(result)
      }
      return results
    }

    // -- Fortune (arcane, cost 4) --

    /// Peek at the top cards of the current deck (day or night based on time).
    func fortunePeek() -> [LoD.Card] {
      let pile = drawsFromDayDeck ? dayDrawPile : nightDrawPile
      return Array(pile.prefix(3))
    }

    /// Fortune spell effect. Operates on the current deck.
    /// Normal: look at top 3, reorder. `newOrder` = indices into the top-3 in desired order.
    /// Heroic (∞): look at top 3, discard 1. `discardIndex` specifies which to discard.
    ///   `newOrder` = indices of the 2 remaining cards in desired order.
    mutating func applyFortune(newOrder: [Int], discardIndex: Int? = nil) {
      let isDayDeck = drawsFromDayDeck
      let count = isDayDeck
        ? min(3, dayDrawPile.count)
        : min(3, nightDrawPile.count)
      guard count > 0 else { return }

      let top: [LoD.Card]
      if isDayDeck {
        top = Array(dayDrawPile.prefix(count))
        dayDrawPile.removeFirst(count)
      } else {
        top = Array(nightDrawPile.prefix(count))
        nightDrawPile.removeFirst(count)
      }

      if let discardIdx = discardIndex {
        if isDayDeck {
          dayDiscardPile.append(top[discardIdx])
        } else {
          nightDiscardPile.append(top[discardIdx])
        }
      }

      var reordered: [LoD.Card] = []
      for idx in newOrder {
        reordered.append(top[idx])
      }

      if isDayDeck {
        dayDrawPile.insert(contentsOf: reordered, at: 0)
      } else {
        nightDrawPile.insert(contentsOf: reordered, at: 0)
      }
    }

    // MARK: - Heroic Acts (rule 7.0)

    // -- Move Hero (rule 7.1) --

    /// Move a hero to a track or back to reserves.
    mutating func moveHero(_ hero: HeroType, to location: HeroLocation) {
      heroLocation[hero] = location
    }

    // -- Rally (rule 7.4) --

    /// Rally heroic act: roll > 4 to raise morale one step.
    /// Natural 1 always fails.
    mutating func rally(dieRoll: Int, drm: Int = 0) -> Bool {
      if dieRoll == 1 { return false }
      let modified = dieRoll + drm
      if modified > 4 {
        morale = morale.raised()
        return true
      }
      return false
    }

    // MARK: - Events (rule 5.0)

    // Card #1: Catapult Shrapnel — Roll die. 1: lose Archer. 2-3: lose MaA. 4-6: no effect.
    mutating func eventCatapultShrapnel(dieRoll: Int) {
      switch dieRoll {
      case 1: loseDefender(.archers)
      case 2, 3: loseDefender(.menAtArms)
      default: break
      }
    }

    // Card #4: Rocks of Ages — Roll die. 1: lose Priest. 2-3: lose MaA. 4-6: no effect.
    mutating func eventRocksOfAges(dieRoll: Int) {
      switch dieRoll {
      case 1: loseDefender(.priests)
      case 2, 3: loseDefender(.menAtArms)
      default: break
      }
    }

    // Card #17: Reign of Arrows — Roll die. 1: lose Priest. 2-3: lose Archer. 4-6: no effect.
    mutating func eventReignOfArrows(dieRoll: Int) {
      switch dieRoll {
      case 1: loseDefender(.priests)
      case 2, 3: loseDefender(.archers)
      default: break
      }
    }

    // Card #18: Trapped by Flames — Roll die. 1-2: lose MaA. 3-4: lose Archer + Priest. 5-6: no effect.
    mutating func eventTrappedByFlames(dieRoll: Int) {
      switch dieRoll {
      case 1, 2: loseDefender(.menAtArms)
      case 3, 4:
        loseDefender(.archers)
        loseDefender(.priests)
      default: break
      }
    }

    // Card #9: Distracted Defenders — If East army out of melee range, advance it one space.
    mutating func eventDistractedDefenders(dieRoll: Int? = nil) -> [AdvanceResult] {
      guard let pos = armyPosition[.east] else { return [] }
      if !LoD.Track.east.isMeleeRange(space: pos) {
        return [advanceArmy(.east, dieRoll: dieRoll)]
      }
      return []
    }

    // Card #20: Banners in the Distance — If West army out of melee range, advance it one space.
    mutating func eventBannersInDistance(dieRoll: Int? = nil) -> [AdvanceResult] {
      guard let pos = armyPosition[.west] else { return [] }
      if !LoD.Track.west.isMeleeRange(space: pos) {
        return [advanceArmy(.west, dieRoll: dieRoll)]
      }
      return []
    }

    // Card #11: The Harbingers of Doom — Advance farthest army one space. If tied, player chooses.
    mutating func eventHarbingers(chosenSlot: ArmySlot? = nil, dieRoll: Int? = nil) -> [AdvanceResult] {
      var maxSpace = 0
      var farthestSlots: [ArmySlot] = []
      for slot in ArmySlot.allCases {
        guard let pos = armyPosition[slot] else { continue }
        if pos > maxSpace {
          maxSpace = pos
          farthestSlots = [slot]
        } else if pos == maxSpace {
          farthestSlots.append(slot)
        }
      }

      guard !farthestSlots.isEmpty else { return [] }

      if farthestSlots.count == 1 {
        return [advanceArmy(farthestSlots[0], dieRoll: dieRoll)]
      }

      // Tied — use player choice
      if let chosen = chosenSlot, farthestSlots.contains(chosen) {
        return [advanceArmy(chosen, dieRoll: dieRoll)]
      }

      return [advanceArmy(farthestSlots[0], dieRoll: dieRoll)]
    }

    // Card #14: Broken Walls — Advance closest of East/West. If tied, advance both.
    mutating func eventBrokenWalls(dieRoll: Int? = nil) -> [AdvanceResult] {
      let eastPos = armyPosition[.east]
      let westPos = armyPosition[.west]

      switch (eastPos, westPos) {
      case (nil, nil): return []
      case (_?, nil): return [advanceArmy(.east, dieRoll: dieRoll)]
      case (nil, _?): return [advanceArmy(.west, dieRoll: dieRoll)]
      case (let e?, let w?):
        if e < w {
          return [advanceArmy(.east, dieRoll: dieRoll)]
        } else if w < e {
          return [advanceArmy(.west, dieRoll: dieRoll)]
        } else {
          let r1 = advanceArmy(.east, dieRoll: dieRoll)
          let r2 = advanceArmy(.west, dieRoll: dieRoll)
          return [r1, r2]
        }
      }
    }

    // Card #23: Campfires in the Distance — Gate armies out of melee range trigger advances.
    mutating func eventCampfires(dieRoll: Int? = nil) -> [AdvanceResult] {
      let pos1 = armyPosition[.gate1]
      let pos2 = armyPosition[.gate2]

      let out1 = pos1.map { !LoD.Track.gate.isMeleeRange(space: $0) } ?? false
      let out2 = pos2.map { !LoD.Track.gate.isMeleeRange(space: $0) } ?? false

      if out1 && out2 {
        let r1 = advanceArmy(.gate1, dieRoll: dieRoll)
        let r2 = advanceArmy(.gate2, dieRoll: dieRoll)
        return [r1, r2]
      } else if out1 {
        return [advanceArmy(.gate1, dieRoll: dieRoll)]
      } else if out2 {
        return [advanceArmy(.gate2, dieRoll: dieRoll)]
      }

      return []
    }

    // Card #16: Lamentation of the Women — Roll 1-3: morale -1. Roll 4-6: no melee this turn.
    mutating func eventLamentation(dieRoll: Int) {
      switch dieRoll {
      case 1, 2, 3: morale = morale.lowered()
      case 4, 5, 6: noMeleeThisTurn = true
      default: break
      }
    }

    // Card #8: Acts of Valor — Wound all unwounded heroes. If ≥1 wounded, +1 attack DRM this turn.
    mutating func eventActsOfValor(woundHeroes: Bool) {
      guard woundHeroes else { return }
      var woundedAny = false
      for hero in HeroType.allCases {
        if heroLocation[hero] != nil && !heroDead.contains(hero) && !heroWounded.contains(hero) {
          heroWounded.insert(hero)
          woundedAny = true
        }
      }
      if woundedAny {
        eventAttackDRMBonus += 1
      }
    }

    // Card #24: Bloody Handprints — Roll 1-3: kill a Hero (wounded first). Roll 4-6: wound a Hero.
    mutating func eventBloodyHandprints(dieRoll: Int, chosenHero: HeroType) {
      switch dieRoll {
      case 1, 2, 3:
        // Kill hero — wounded heroes must be chosen first (enforced by caller)
        heroDead.insert(chosenHero)
        heroWounded.remove(chosenHero)
        heroLocation.removeValue(forKey: chosenHero)
      case 4, 5, 6:
        woundHero(chosenHero)
      default: break
      }
    }

    // Card #26: Council of Heroes — Return all living heroes to Reserves.
    // Wounded heroes cannot act this turn.
    mutating func eventCouncilOfHeroes() {
      for hero in HeroType.allCases {
        if heroLocation[hero] != nil && !heroDead.contains(hero) {
          heroLocation[hero] = .reserves
        }
      }
      woundedHeroesCannotAct = true
    }

    // Cards #27, #32: Midnight Magic / By the Light of the Moon
    // Roll 1-3: +1 arcane. Roll 4-6: +2 arcane.
    mutating func eventMidnightMagic(dieRoll: Int) {
      switch dieRoll {
      case 1, 2, 3: arcaneEnergy = min(arcaneEnergy + 1, 6)
      case 4, 5, 6: arcaneEnergy = min(arcaneEnergy + 2, 6)
      default: break
      }
    }

    // Card #30: Assassin's Creedo — Roll 1-3: kill a Hero. Roll 4-6: +1 attack DRM this turn.
    mutating func eventAssassinsCreedo(dieRoll: Int, chosenHero: HeroType? = nil) {
      switch dieRoll {
      case 1, 2, 3:
        if let hero = chosenHero {
          heroDead.insert(hero)
          heroWounded.remove(hero)
          heroLocation.removeValue(forKey: hero)
        }
      case 4, 5, 6:
        eventAttackDRMBonus += 1
      default: break
      }
    }

    // Card #31: In the Pale Moonlight — -1 divine, +1 arcane, lose one Priest.
    mutating func eventPaleMoonlight() {
      divineEnergy = max(divineEnergy - 1, 0)
      arcaneEnergy = min(arcaneEnergy + 1, 6)
      loseDefender(.priests)
    }

    // Card #33: Deserters in the Dark — Lose 2 defenders OR reduce Morale by one (not if Low).
    mutating func eventDeserters(loseTwoDefenders: (DefenderType, DefenderType)?) {
      if let (d1, d2) = loseTwoDefenders {
        loseDefender(d1)
        loseDefender(d2)
      } else {
        morale = morale.lowered()
      }
    }

    // Card #34: The Waning Moon — Roll 1-3: -1 arcane. Roll 4-6: +1 arcane.
    mutating func eventWaningMoon(dieRoll: Int) {
      switch dieRoll {
      case 1, 2, 3: arcaneEnergy = max(arcaneEnergy - 1, 0)
      case 4, 5, 6: arcaneEnergy = min(arcaneEnergy + 1, 6)
      default: break
      }
    }

    // Card #35: Mystic Forces Reborn — Return all cast spells to pool.
    // Roll 1-3: -1 arcane. Roll 4-6: draw a random arcane spell.
    mutating func eventMysticForcesReborn(dieRoll: Int, randomSpell: SpellType? = nil) {
      // Return all cast spells to face-down
      for spell in SpellType.allCases {
        if spellStatus[spell] == .cast {
          spellStatus[spell] = .faceDown
        }
      }

      switch dieRoll {
      case 1, 2, 3: arcaneEnergy = max(arcaneEnergy - 1, 0)
      case 4, 5, 6:
        if let spell = randomSpell, spell.isArcane, spellStatus[spell] == .faceDown {
          spellStatus[spell] = .known
        }
      default: break
      }
    }

    // Card #29: Death and Despair — Roll die, advance farthest army that many spaces.
    // Player can wound heroes or lose defenders to reduce the advance by 1 per sacrifice.
    mutating func eventDeathAndDespair(
      dieRoll: Int,
      heroesToWound: [HeroType] = [],
      defendersToLose: [DefenderType] = [],
      chosenSlot: ArmySlot? = nil,
      dieRollForBarricade: Int? = nil
    ) -> [AdvanceResult] {
      for hero in heroesToWound {
        woundHero(hero)
      }
      for defender in defendersToLose {
        loseDefender(defender)
      }

      let reductions = heroesToWound.count + defendersToLose.count
      let advances = max(dieRoll - reductions, 0)

      // Find farthest army
      var maxSpace = 0
      var farthestSlots: [ArmySlot] = []
      for slot in ArmySlot.allCases {
        guard let pos = armyPosition[slot] else { continue }
        if pos > maxSpace {
          maxSpace = pos
          farthestSlots = [slot]
        } else if pos == maxSpace {
          farthestSlots.append(slot)
        }
      }

      guard !farthestSlots.isEmpty else { return [] }

      let targetSlot: ArmySlot
      if farthestSlots.count == 1 {
        targetSlot = farthestSlots[0]
      } else if let chosen = chosenSlot, farthestSlots.contains(chosen) {
        targetSlot = chosen
      } else {
        targetSlot = farthestSlots[0]
      }

      var results: [AdvanceResult] = []
      for _ in 0..<advances {
        results.append(advanceArmy(targetSlot, dieRoll: dieRollForBarricade))
      }
      return results
    }

    // Card #36: Bump in the Night — Advance Sky 1 space OR advance other armies total 2 spaces.
    mutating func eventBumpInTheNight(
      advanceSky: Bool,
      otherAdvances: [ArmySlot] = [],
      dieRoll: Int? = nil
    ) -> [AdvanceResult] {
      if advanceSky {
        return [advanceArmy(.sky)]
      } else {
        var results: [AdvanceResult] = []
        for slot in otherAdvances {
          results.append(advanceArmy(slot, dieRoll: dieRoll))
        }
        return results
      }
    }

    // MARK: - Deck Management (rule 3.0)

    /// Set up the draw piles for a new game.
    /// Pass `shuffledDayCards` and `shuffledNightCards` for deterministic testing,
    /// or nil to use the default card lists (caller shuffles).
    mutating func setupDecks(
      shuffledDayCards: [LoD.Card]? = nil,
      shuffledNightCards: [LoD.Card]? = nil
    ) {
      dayDrawPile = shuffledDayCards ?? LoD.dayCards
      nightDrawPile = shuffledNightCards ?? LoD.nightCards
      dayDiscardPile = []
      nightDiscardPile = []
      currentCard = nil
    }

    /// Draw a card from the appropriate deck (day/dawn → day deck, night/twilight → night deck).
    /// Discards the previous current card. If the draw pile is empty, shuffles the
    /// discard pile back in (rule 3.0). Returns the drawn card, or nil if both
    /// draw pile and discard pile are empty.
    @discardableResult
    mutating func drawCard() -> LoD.Card? {
      // Discard previous current card
      if let current = currentCard {
        if current.deck == .day {
          dayDiscardPile.append(current)
        } else {
          nightDiscardPile.append(current)
        }
        currentCard = nil
      }

      if drawsFromDayDeck {
        // Reshuffle discard into draw pile if empty
        if dayDrawPile.isEmpty && !dayDiscardPile.isEmpty {
          dayDrawPile = dayDiscardPile.shuffled()
          dayDiscardPile = []
        }
        guard !dayDrawPile.isEmpty else { return nil }
        currentCard = dayDrawPile.removeFirst()
      } else {
        // Reshuffle discard into draw pile if empty
        if nightDrawPile.isEmpty && !nightDiscardPile.isEmpty {
          nightDrawPile = nightDiscardPile.shuffled()
          nightDiscardPile = []
        }
        guard !nightDrawPile.isEmpty else { return nil }
        currentCard = nightDrawPile.removeFirst()
      }

      return currentCard
    }

    /// Draw a card with an injectable shuffle for deterministic testing.
    /// When the draw pile is empty and discard needs reshuffling, `reshuffleOrder`
    /// provides the new order instead of random shuffle.
    @discardableResult
    mutating func drawCard(reshuffleOrder: [LoD.Card]?) -> LoD.Card? {
      // Discard previous current card
      if let current = currentCard {
        if current.deck == .day {
          dayDiscardPile.append(current)
        } else {
          nightDiscardPile.append(current)
        }
        currentCard = nil
      }

      if drawsFromDayDeck {
        if dayDrawPile.isEmpty && !dayDiscardPile.isEmpty {
          dayDrawPile = reshuffleOrder ?? dayDiscardPile.shuffled()
          dayDiscardPile = []
        }
        guard !dayDrawPile.isEmpty else { return nil }
        currentCard = dayDrawPile.removeFirst()
      } else {
        if nightDrawPile.isEmpty && !nightDiscardPile.isEmpty {
          nightDrawPile = reshuffleOrder ?? nightDiscardPile.shuffled()
          nightDiscardPile = []
        }
        guard !nightDrawPile.isEmpty else { return nil }
        currentCard = nightDrawPile.removeFirst()
      }

      return currentCard
    }

    // MARK: - Quest Resolution (card quests)

    enum QuestResult: Equatable {
      case success
      case failure
      case naturalOneFail
      case noQuest
    }

    /// Attempt the quest on the current card.
    /// Actions grant +1 DRM, heroics grant +2 DRM. Ranger adds +1 DRM to quests.
    /// Natural 1 always fails. Must roll > quest target.
    mutating func attemptQuest(
      isHeroic: Bool,
      dieRoll: Int,
      additionalDRM: Int = 0
    ) -> QuestResult {
      guard let quest = currentCard?.quest else { return .noQuest }
      if dieRoll == 1 { return .naturalOneFail }
      let baseDRM = isHeroic ? 2 : 1
      let modified = dieRoll + baseDRM + additionalDRM
      if modified > quest.target {
        return .success
      }
      return .failure
    }

    // -- Quest Rewards --

    /// Forlorn Hope — advance time marker +1.
    mutating func questForlornHope() {
      advanceTime(by: 1)
    }

    /// Scrolls of the Dead — draw a spell of your choice (mark it known).
    mutating func questScrollsOfDead(chosenSpell: SpellType) {
      if spellStatus[chosenSpell] == .faceDown {
        spellStatus[chosenSpell] = .known
      }
    }

    /// Search for the Manastones — +1 arcane energy, +1 divine energy.
    mutating func questManastones() {
      arcaneEnergy = min(arcaneEnergy + 1, 6)
      divineEnergy = min(divineEnergy + 1, 6)
    }

    /// Arrows of the Dead — gain the Magic Bow item.
    mutating func questMagicBow() {
      hasMagicBow = true
    }

    /// Put Forth the Call — gain +1 defender of player's choice.
    mutating func questPutForthCall(defender: DefenderType) {
      if let current = defenders[defender] {
        defenders[defender] = min(current + 1, defender.maxValue)
      }
    }

    /// Last Ditch Efforts — add an unselected hero to reserves.
    mutating func questLastDitchEfforts(hero: HeroType) {
      heroLocation[hero] = .reserves
    }

    /// Last Ditch Efforts penalty — reduce morale by one (if quest not attempted or failed).
    mutating func questLastDitchPenalty() {
      morale = morale.lowered()
    }

    /// The Vorpal Blade — gain the Magic Sword item.
    mutating func questVorpalBlade() {
      hasMagicSword = true
    }

    /// Pillars of the Earth — retreat one army (except Sky) two spaces.
    mutating func questPillarsOfEarth(slot: ArmySlot) {
      guard slot.track != .sky else { return }
      if let pos = armyPosition[slot] {
        let track = slot.track
        armyPosition[slot] = min(pos + 2, track.maxSpace)
      }
    }

    /// Save the Mirror of the Moon — +2 arcane energy.
    mutating func questMirrorOfMoon() {
      arcaneEnergy = min(arcaneEnergy + 2, 6)
    }

    /// Prophecy Revealed — reveal top 3 Day deck cards, discard one, put rest back on top.
    mutating func questProphecyRevealed(discardIndex: Int) {
      let count = min(3, dayDrawPile.count)
      guard count > 0 else { return }
      let top = Array(dayDrawPile.prefix(count))
      dayDrawPile.removeFirst(count)
      dayDiscardPile.append(top[discardIndex])
      var remaining: [LoD.Card] = []
      for (i, card) in top.enumerated() where i != discardIndex {
        remaining.append(card)
      }
      dayDrawPile.insert(contentsOf: remaining, at: 0)
    }

    // -- Magic Items (quest rewards) --

    enum ItemTiming: Equatable {
      case before  // +2 DRM
      case after   // +1 DRM
    }

    /// Use the Magic Sword: discard before melee attack for +2 DRM, or after for +1 DRM.
    /// Returns the DRM bonus granted, or 0 if item not held.
    mutating func useMagicSword(timing: ItemTiming) -> Int {
      guard hasMagicSword else { return 0 }
      hasMagicSword = false
      return timing == .before ? 2 : 1
    }

    /// Use the Magic Bow: discard before ranged attack for +2 DRM, or after for +1 DRM.
    /// Returns the DRM bonus granted, or 0 if item not held.
    mutating func useMagicBow(timing: ItemTiming) -> Int {
      guard hasMagicBow else { return 0 }
      hasMagicBow = false
      return timing == .before ? 2 : 1
    }

    // MARK: - Housekeeping (rule 3.0 step 5)

    /// Perform housekeeping at the end of a turn.
    /// Advances time by the current card's time value, resets per-turn tracking,
    /// and checks for victory.
    mutating func performHousekeeping() {
      guard let card = currentCard else { return }

      // Advance time by the card's time value
      advanceTime(by: card.time)

      // Reset per-turn tracking
      resetTurnTracking()

      // Check victory (only matters on Final Twilight)
      checkVictory()
    }

    /// Reset per-turn tracking at the start of a new turn.
    mutating func resetTurnTracking() {
      bloodyBattlePaidThisTurn = false
      paladinRerollUsed = false
      inspireDRMActive = false
      eventAttackDRMBonus = 0
      noMeleeThisTurn = false
      woundedHeroesCannotAct = false
    }

    // MARK: - DRM Helpers (for RulePages)

    /// Total DRM for an attack action, combining card DRMs, upgrades, event bonuses, and Inspire.
    func totalAttackDRM(slot: ArmySlot, attackType: AttackType) -> Int {
      var drm = 0
      if let card = currentCard {
        for cardDRM in card.actionDRMs {
          switch cardDRM.action {
          case .attack:
            if cardDRM.track == nil || cardDRM.track == slot.track {
              drm += cardDRM.value
            }
          case .melee:
            if attackType == .melee && (cardDRM.track == nil || cardDRM.track == slot.track) {
              drm += cardDRM.value
            }
          case .ranged:
            if attackType == .ranged && (cardDRM.track == nil || cardDRM.track == slot.track) {
              drm += cardDRM.value
            }
          default: break
          }
        }
      }
      // Upgrade DRM (only for space 1)
      if armyPosition[slot] == 1 {
        drm += upgradeDRM(on: slot.track, attackType: attackType)
      }
      // Event attack bonus
      drm += eventAttackDRMBonus
      // Inspire bonus
      if inspireDRMActive { drm += 1 }
      return drm
    }

    /// Total DRM for a build action from card DRMs and Inspire.
    func totalBuildDRM() -> Int {
      var drm = 0
      if let card = currentCard {
        for cardDRM in card.actionDRMs where cardDRM.action == .build {
          drm += cardDRM.value
        }
      }
      if inspireDRMActive { drm += 1 }
      return drm
    }

    /// Total DRM for a chant action from card DRMs and Inspire.
    func totalChantDRM() -> Int {
      var drm = 0
      // Priests provide +1 DRM per priest
      drm += defenders[.priests] ?? 0
      if let card = currentCard {
        for cardDRM in card.actionDRMs where cardDRM.action == .chant {
          drm += cardDRM.value
        }
      }
      if inspireDRMActive { drm += 1 }
      return drm
    }

    /// Total DRM for a rally heroic action from card DRMs and Inspire.
    func totalRallyDRM() -> Int {
      var drm = 0
      if let card = currentCard {
        for cardDRM in card.heroicDRMs where cardDRM.action == .rally {
          drm += cardDRM.value
        }
      }
      if inspireDRMActive { drm += 1 }
      return drm
    }
  }

  // MARK: - Greenskin Scenario Setup

  /// Create the initial state for the Greenskin Horde scenario.
  /// `windsOfMagicArcane` is the arcane energy after the Winds of Magic roll
  /// and player choice (before hero bonuses). Divine = 6 - arcane.
  /// Hero bonuses (+2 arcane for Wizard, +2 divine for Cleric) are applied automatically.
  static func greenskinSetup(
    windsOfMagicArcane: Int,
    heroes: [HeroType] = [.warrior, .wizard, .cleric]
  ) -> State {
    var state = State()
    state.scenario = .greenskinHorde

    // Armies (Scenario 1 card)
    state.armyType = [
      .east: .goblin,
      .west: .goblin,
      .gate1: .orc,
      .gate2: .orc,
      .sky: .dragon,
      .terror: .troll,
    ]
    state.armyPosition = [
      .east: 6,
      .west: 6,
      .gate1: 4,
      .gate2: 4,
      .sky: 6,
      // terror: Troll not placed until first twilight
    ]

    // Heroes — all start in Reserves
    for hero in heroes {
      state.heroLocation[hero] = .reserves
    }

    // Defenders at max
    state.defenders = [
      .menAtArms: DefenderType.menAtArms.maxValue,
      .archers: DefenderType.archers.maxValue,
      .priests: DefenderType.priests.maxValue,
    ]

    // Morale starts Normal (rule 6.1.1)
    state.morale = .normal

    // Winds of Magic (rule 2.1)
    let baseArcane = windsOfMagicArcane
    let baseDivine = 6 - windsOfMagicArcane
    let wizardBonus = heroes.contains(.wizard) ? 2 : 0
    let clericBonus = heroes.contains(.cleric) ? 2 : 0
    state.arcaneEnergy = min(baseArcane + wizardBonus, 6)
    state.divineEnergy = min(baseDivine + clericBonus, 6)

    // Time starts at First Dawn
    state.timePosition = 0

    // All spells face-down (default)
    // No breaches, barricades, upgrades (default)
    // Bloody battle in reserves (default nil)

    state.phase = .card

    return state
  }
}
