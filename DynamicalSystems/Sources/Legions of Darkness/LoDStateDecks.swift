//
//  LoDStateDecks.swift
//  DynamicalSystems
//
//  Legions of Darkness — Deck management, quests, and items.
//

import Foundation

extension LoD.State {

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
  /// Each action point spent gives +1 DRM; each heroic point gives +2 DRM.
  /// Ranger adds +1 DRM to quests. Natural 1 always fails. Must roll > quest target.
  mutating func attemptQuest(
    isHeroic: Bool,
    dieRoll: Int,
    additionalDRM: Int = 0,
    pointsSpent: Int = 1
  ) -> QuestResult {
    guard let quest = currentCard?.quest else { return .noQuest }
    if dieRoll == 1 { return .naturalOneFail }
    let perPointDRM = isHeroic ? 2 : 1
    let baseDRM = perPointDRM * pointsSpent
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
  mutating func questScrollsOfDead(chosenSpell: LoD.SpellType) {
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
  mutating func questPutForthCall(defender: LoD.DefenderType) {
    if let current = defenders[defender] {
      defenders[defender] = min(current + 1, defender.maxValue)
    }
  }

  /// Last Ditch Efforts — add an unselected hero to reserves.
  mutating func questLastDitchEfforts(hero: LoD.HeroType) {
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
  mutating func questPillarsOfEarth(slot: LoD.ArmySlot) {
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
    for (index, card) in top.enumerated() where index != discardIndex {
      remaining.append(card)
    }
    dayDrawPile.insert(contentsOf: remaining, at: 0)
  }

  // -- Magic Items (quest rewards) --

  /// Use the Magic Sword: discard before melee attack for +2 DRM, or after for +1 DRM.
  /// Returns the DRM bonus granted, or 0 if item not held.
  mutating func useMagicSword(timing: LoD.ItemTiming) -> Int {
    guard hasMagicSword else { return 0 }
    hasMagicSword = false
    return timing == .before ? 2 : 1
  }

  /// Use the Magic Bow: discard before ranged attack for +2 DRM, or after for +1 DRM.
  /// Returns the DRM bonus granted, or 0 if item not held.
  mutating func useMagicBow(timing: LoD.ItemTiming) -> Int {
    guard hasMagicBow else { return 0 }
    hasMagicBow = false
    return timing == .before ? 2 : 1
  }
}
