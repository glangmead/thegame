//
//  LoDComponentsExtras.swift
//  DynamicalSystems
//
//  Legions of Darkness — Card structs, scenarios, and GameComponents conformance
//  (split from LoDComponents for type_body_length).
//

import Foundation

extension LoDComponents {

  // MARK: - Spells (rules 9.2, 9.3)

  enum SpellType: String, CaseIterable, Equatable, Hashable {
    // Arcane (9.2)
    case fireball, slow, chainLightning, fortune
    // Divine (9.3)
    case cureWounds, massHeal, divineWrath, inspire, raiseDead

    var isArcane: Bool {
      switch self {
      case .fireball, .slow, .chainLightning, .fortune: return true
      default: return false
      }
    }

    var isDivine: Bool { !isArcane }

    var energyCost: Int {
      switch self {
      case .fireball: return 1
      case .slow: return 2
      case .chainLightning: return 3
      case .fortune: return 4
      case .cureWounds: return 1
      case .massHeal: return 2
      case .divineWrath: return 3
      case .inspire: return 3
      case .raiseDead: return 4
      }
    }

    static var arcaneSpells: [SpellType] {
      allCases.filter { $0.isArcane }
    }

    static var divineSpells: [SpellType] {
      allCases.filter { $0.isDivine }
    }
  }

  enum SpellStatus: Equatable, Hashable {
    case faceDown
    case known
    case cast
  }

  // MARK: - Time Track (16 spaces)

  /// Type of each space on the time track.
  /// Dawn/day -> draw from day deck. Twilight/night -> draw from night deck.
  /// Dawn: entering triggers -1 morale, +1 arcane energy, remove Terror army.
  /// Twilight: entering triggers +1 arcane energy, place Terror army at space 3.
  enum TimeSpaceType: String, Equatable, Hashable {
    case dawn
    case day
    case twilight
    case night
  }

  /// The 16-space time track:
  /// First Dawn, day, day, Twilight, night, night, Dawn, day, day,
  /// Twilight, night, night, Dawn, day, day, Final Twilight
  static let timeTrack: [TimeSpaceType] = [
    .dawn,      // 0: First Dawn
    .day,       // 1
    .day,       // 2
    .twilight,  // 3
    .night,     // 4
    .night,     // 5
    .dawn,      // 6
    .day,       // 7
    .day,       // 8
    .twilight,  // 9
    .night,     // 10
    .night,     // 11
    .dawn,      // 12
    .day,       // 13
    .day,       // 14
    .twilight   // 15: Final Twilight
  ]

  /// Whether a time space draws from the day deck.
  static func drawsFromDayDeck(at position: Int) -> Bool {
    let spaceType = timeTrack[position]
    return spaceType == .dawn || spaceType == .day
  }

  // MARK: - Turn Phases (rule 3.0)

  enum Phase: String, Equatable, Hashable {
    case setup
    case card
    case army
    case event
    case action
    case heroic
    case housekeeping
    case paladinReact
  }

  // MARK: - Cards (rule 3.0)

  enum DeckType: String, CaseIterable, Equatable, Hashable, Codable, Sendable {
    case day, night
  }

  struct CardDRM: Equatable, Hashable, Codable, Sendable {
    // swiftlint:disable:next nesting
    enum ActionType: String, Equatable, Hashable, Codable, Sendable {
      case attack    // all attacks (melee + ranged)
      case melee     // melee attacks only
      case ranged    // ranged attacks only
      case build     // build actions
      case chant     // chant actions
      case rally     // rally heroic acts
    }

    let action: ActionType
    let track: Track?
    let value: Int
  }

  struct CardEvent: Equatable, Hashable, Codable, Sendable {
    let title: String
    let text: String
  }

  struct CardQuest: Equatable, Hashable, Codable, Sendable {
    let title: String
    let text: String
    let target: Int
    let reward: String
    let penalty: String?
  }

  struct Card: Equatable, Hashable, Codable, Sendable {
    let number: Int
    let file: String
    let title: String
    let deck: DeckType
    let advances: [Track]
    let actions: Int
    let heroics: Int
    let actionDRMs: [CardDRM]
    let heroicDRMs: [CardDRM]
    let event: CardEvent?
    let quest: CardQuest?
    let time: Int
    let bloodyBattle: Track?
  }

  // MARK: - Scenarios

  enum Scenario: String, Equatable, Hashable {
    case greenskinHorde
    case undeadScourge
  }

  // MARK: - GameComponents conformance

  enum Piece: Equatable, Hashable {
    case army(ArmySlot)
    case hero(HeroType)
  }

  enum Position: Equatable, Hashable {
    case offBoard
    case onTrack(Track, Int)
    case reserves
  }

  struct PiecePosition: Equatable, Hashable {
    var piece: Piece
    var position: Position
  }
}
