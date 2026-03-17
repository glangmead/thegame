//
//  LoDStateEvents.swift
//  DynamicalSystems
//
//  Legions of Darkness — Event handlers and concrete resolution enumeration.
//
// swiftlint:disable file_length

import Foundation

extension LoD.State {

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
  mutating func eventDistractedDefenders() -> [AdvanceResult] {
    guard let pos = armyPosition[.east] else { return [] }
    if !LoD.Track.east.isMeleeRange(space: pos) {
      return [advanceArmy(.east)]
    }
    return []
  }

  // Card #20: Banners in the Distance — If West army out of melee range, advance it one space.
  mutating func eventBannersInDistance() -> [AdvanceResult] {
    guard let pos = armyPosition[.west] else { return [] }
    if !LoD.Track.west.isMeleeRange(space: pos) {
      return [advanceArmy(.west)]
    }
    return []
  }

  // Card #11: The Harbingers of Doom — Advance farthest army one space. If tied, player chooses.
  mutating func eventHarbingers(chosenSlot: LoD.ArmySlot? = nil) -> [AdvanceResult] {
    var maxSpace = 0
    var farthestSlots: [LoD.ArmySlot] = []
    for slot in LoD.ArmySlot.allCases {
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
      return [advanceArmy(farthestSlots[0])]
    }

    // Tied — use player choice
    if let chosen = chosenSlot, farthestSlots.contains(chosen) {
      return [advanceArmy(chosen)]
    }

    return [advanceArmy(farthestSlots[0])]
  }

  // Card #14: Broken Walls — Advance closest of East/West. If tied, advance both.
  mutating func eventBrokenWalls() -> [AdvanceResult] {
    let eastPos = armyPosition[.east]
    let westPos = armyPosition[.west]

    switch (eastPos, westPos) {
    case (nil, nil): return []
    case (_?, nil): return [advanceArmy(.east)]
    case (nil, _?): return [advanceArmy(.west)]
    case (let eastP?, let westP?):
      if eastP < westP {
        return [advanceArmy(.east)]
      } else if westP < eastP {
        return [advanceArmy(.west)]
      } else {
        let result1 = advanceArmy(.east)
        let result2 = advanceArmy(.west)
        return [result1, result2]
      }
    }
  }

  // Card #23: Campfires in the Distance — Gate armies out of melee range trigger advances.
  mutating func eventCampfires() -> [AdvanceResult] {
    let pos1 = armyPosition[.gate1]
    let pos2 = armyPosition[.gate2]

    let out1 = pos1.map { !LoD.Track.gate.isMeleeRange(space: $0) } ?? false
    let out2 = pos2.map { !LoD.Track.gate.isMeleeRange(space: $0) } ?? false

    if out1 && out2 {
      let result1 = advanceArmy(.gate1)
      let result2 = advanceArmy(.gate2)
      return [result1, result2]
    } else if out1 {
      return [advanceArmy(.gate1)]
    } else if out2 {
      return [advanceArmy(.gate2)]
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
    for hero in LoD.HeroType.allCases {
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
  mutating func eventBloodyHandprints(dieRoll: Int, chosenHero: LoD.HeroType) {
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
    for hero in LoD.HeroType.allCases {
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
  mutating func eventAssassinsCreedo(dieRoll: Int, chosenHero: LoD.HeroType? = nil) {
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
  mutating func eventDeserters(loseTwoDefenders: (LoD.DefenderType, LoD.DefenderType)?) {
    if let (def1, def2) = loseTwoDefenders {
      loseDefender(def1)
      loseDefender(def2)
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
  mutating func eventMysticForcesReborn(dieRoll: Int) {
    // Return all cast spells to face-down
    for spell in LoD.SpellType.allCases where spellStatus[spell] == .cast {
      spellStatus[spell] = .faceDown
    }

    switch dieRoll {
    case 1, 2, 3: arcaneEnergy = max(arcaneEnergy - 1, 0)
    case 4, 5, 6:
      let arcanePool = LoD.SpellType.arcaneSpells.filter { spellStatus[$0] == .faceDown }
      if let spell = LoD.drawRandomSpell(arcanePool) {
        spellStatus[spell] = .known
      }
    default: break
    }
  }

  // Card #29: Death and Despair — Roll die, advance farthest army that many spaces.
  // Player can wound heroes or lose defenders to reduce the advance by 1 per sacrifice.
  mutating func eventDeathAndDespair(
    dieRoll: Int,
    heroesToWound: [LoD.HeroType] = [],
    defendersToLose: [LoD.DefenderType] = [],
    chosenSlot: LoD.ArmySlot? = nil
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
    var farthestSlots: [LoD.ArmySlot] = []
    for slot in LoD.ArmySlot.allCases {
      guard let pos = armyPosition[slot] else { continue }
      if pos > maxSpace {
        maxSpace = pos
        farthestSlots = [slot]
      } else if pos == maxSpace {
        farthestSlots.append(slot)
      }
    }

    guard !farthestSlots.isEmpty else { return [] }

    let targetSlot: LoD.ArmySlot
    if farthestSlots.count == 1 {
      targetSlot = farthestSlots[0]
    } else if let chosen = chosenSlot, farthestSlots.contains(chosen) {
      targetSlot = chosen
    } else {
      targetSlot = farthestSlots[0]
    }

    var results: [AdvanceResult] = []
    for _ in 0..<advances {
      results.append(advanceArmy(targetSlot))
    }
    return results
  }

  // Card #36: Bump in the Night — Advance Sky 1 space OR advance other armies total 2 spaces.
  mutating func eventBumpInTheNight(
    advanceSky: Bool,
    otherAdvances: [LoD.ArmySlot] = []
  ) -> [AdvanceResult] {
    if advanceSky {
      return [advanceArmy(.sky)]
    } else {
      var results: [AdvanceResult] = []
      for slot in otherAdvances {
        results.append(advanceArmy(slot))
      }
      return results
    }
  }

  // MARK: - Concrete Event Resolution Enumeration

  /// Enumerate all valid concrete `EventResolution` choices for a given event card.
  /// Each resolution represents one distinct player decision path.
  func concreteEventResolutions(for card: LoD.Card) -> [LoD.EventResolution] {
    guard card.event != nil else { return [] }
    switch card.number {
    case 33: return deserterResolutions()
    case 36: return bumpInTheNightResolutions()
    case 24: return bloodyHandprintsResolutions()
    case 30: return assassinsCreedoResolutions()
    case 11: return harbingersResolutions()
    default: return [LoD.EventResolution()]
    }
  }

  // Card #33: Deserters — lose 2 defenders OR reduce morale (if not Low).
  private func deserterResolutions() -> [LoD.EventResolution] {
    var resolutions: [LoD.EventResolution] = []
    let types = LoD.DefenderType.allCases
    // One resolution per pair of defender types
    for first in 0..<types.count {
      for second in first..<types.count {
        var res = LoD.EventResolution()
        res.deserterDefenders = (types[first], types[second])
        resolutions.append(res)
      }
    }
    // Morale loss option if morale is not Low
    if morale != .low {
      resolutions.append(LoD.EventResolution())
    }
    return resolutions
  }

  // Card #36: Bump in the Night — advance Sky 1 OR distribute 2 advances among non-sky armies.
  private func bumpInTheNightResolutions() -> [LoD.EventResolution] {
    var resolutions: [LoD.EventResolution] = []
    // Sky path
    var skyRes = LoD.EventResolution()
    skyRes.advanceSky = true
    resolutions.append(skyRes)
    // Non-sky armies that are on the board
    let nonSkySlots = LoD.ArmySlot.allCases.filter {
      $0.track != .sky && armyPosition[$0] != nil
    }
    // 2-to-one: both advances on a single army
    for slot in nonSkySlots {
      var res = LoD.EventResolution()
      res.otherAdvances = [slot, slot]
      resolutions.append(res)
    }
    // 1+1: one advance each to two different armies
    for first in 0..<nonSkySlots.count {
      for second in (first + 1)..<nonSkySlots.count {
        var res = LoD.EventResolution()
        res.otherAdvances = [nonSkySlots[first], nonSkySlots[second]]
        resolutions.append(res)
      }
    }
    return resolutions
  }

  // Card #24: Bloody Handprints — one resolution per living hero.
  private func bloodyHandprintsResolutions() -> [LoD.EventResolution] {
    livingHeroes.map { hero in
      var res = LoD.EventResolution()
      res.chosenHero = hero
      return res
    }
  }

  // Card #30: Assassin's Creedo — one resolution per living hero.
  private func assassinsCreedoResolutions() -> [LoD.EventResolution] {
    livingHeroes.map { hero in
      var res = LoD.EventResolution()
      res.chosenHero = hero
      return res
    }
  }

  // Card #11: Harbingers of Doom — advance farthest army; if tied, one per tied slot.
  private func harbingersResolutions() -> [LoD.EventResolution] {
    var maxSpace = 0
    var farthestSlots: [LoD.ArmySlot] = []
    for slot in LoD.ArmySlot.allCases {
      guard let pos = armyPosition[slot] else { continue }
      if pos > maxSpace {
        maxSpace = pos
        farthestSlots = [slot]
      } else if pos == maxSpace {
        farthestSlots.append(slot)
      }
    }
    guard !farthestSlots.isEmpty else { return [LoD.EventResolution()] }
    if farthestSlots.count == 1 {
      return [LoD.EventResolution()]
    }
    return farthestSlots.map { slot in
      var res = LoD.EventResolution()
      res.chosenSlot = slot
      return res
    }
  }

}
