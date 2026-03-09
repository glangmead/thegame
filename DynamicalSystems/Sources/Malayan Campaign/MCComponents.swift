//
//  MCComponents.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

struct MalayanCampaignComponents: GameComponents {

  enum Player: Equatable, Hashable {
    case solo
  }

  enum Phase: Equatable, Hashable {
    case setup
    case alliedWithdrawal
    case japaneseAdvance
    case battle
    case airSupport
    case advanceTurn
    var name: String {
      switch self {
      case .setup: "Setup"
      case .alliedWithdrawal: "Allied Withdrawal"
      case .japaneseAdvance: "Japanese Advance"
      case .battle: "Battle"
      case .airSupport: "Allied Air Support"
      case .advanceTurn: "Advance Turn"
      }
    }
  }

  enum Road: String, Equatable, Hashable, CustomStringConvertible {
    case trunk = "Trunk"
    case eastern = "Eastern"
    var description: String { rawValue }
  }

  // Pieces: 7 allied (anonymous, one per non-Singapore location), 2 japanese
  enum Piece: Int, Equatable, Hashable, CaseIterable, CustomStringConvertible {
    case japTrunk = 0
    case japEastern
    case ally1  // starts at Jitra
    case ally2  // starts at Kota Bharu
    case ally3  // starts at Kampar
    case ally4  // starts at Kuantan
    case ally5  // starts at Kuala Lumpur
    case ally6  // starts at Endau
    case ally7  // starts at Kluang

    static func allies() -> [Piece] {
      [.ally1, .ally2, .ally3, .ally4, .ally5, .ally6, .ally7]
    }

    static func japanese() -> [Piece] {
      [.japTrunk, .japEastern]
    }

    var description: String {
      switch self {
      case .japTrunk: "Japanese (Trunk)"
      case .japEastern: "Japanese (Eastern)"
      case .ally1: "Allied 1"
      case .ally2: "Allied 2"
      case .ally3: "Allied 3"
      case .ally4: "Allied 4"
      case .ally5: "Allied 5"
      case .ally6: "Allied 6"
      case .ally7: "Allied 7"
      }
    }

    var shortName: String {
      switch self {
      case .japTrunk: "JpT"
      case .japEastern: "JpE"
      case .ally1: "A1"
      case .ally2: "A2"
      case .ally3: "A3"
      case .ally4: "A4"
      case .ally5: "A5"
      case .ally6: "A6"
      case .ally7: "A7"
      }
    }
  }

  // 7 locations + Singapore
  enum Location: Int, Equatable, Hashable, CaseIterable, CustomStringConvertible {
    case jitra = 0
    case kotaBharu
    case kampar
    case kuantan
    case kualaLumpur
    case endau
    case kluang
    case singapore

    var description: String {
      switch self {
      case .jitra: "Jitra"
      case .kotaBharu: "Kota Bharu"
      case .kampar: "Kampar"
      case .kuantan: "Kuantan"
      case .kualaLumpur: "Kuala Lumpur"
      case .endau: "Endau"
      case .kluang: "Kluang"
      case .singapore: "Singapore"
      }
    }

    static var reinforcements: [Location: Int] {
      [.kampar: 2, .kuantan: 1, .endau: 1, .kluang: 1]
    }
  }

  // Trunk road: Jitra -> Kampar -> KL -> Kluang -> Singapore
  static let trunkRoad: [Location] = [.jitra, .kampar, .kualaLumpur, .kluang, .singapore]
  // Eastern road: Kota Bharu -> Kuantan -> Endau -> Kluang -> Singapore
  static let easternRoad: [Location] = [.kotaBharu, .kuantan, .endau, .kluang, .singapore]

  enum Position: Equatable, Hashable, CustomStringConvertible {
    case offBoard
    case at(Location)

    var description: String {
      switch self {
      case .offBoard: "(Off board)"
      case .at(let loc): loc.description
      }
    }
  }

  struct PiecePosition: Equatable, Hashable {
    var piece: Piece
    var position: Position
  }

  let track = Track(
    length: 8,
    names: ["Jitra", "Kota Bharu", "Kampar", "Kuantan", "Kuala Lumpur", "Endau", "Kluang", "Singapore"]
  )
}
