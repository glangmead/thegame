//
//  MCEngine.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/8/26.
//

import Foundation

struct MalayanCampaign {
  typealias Player = MalayanCampaignComponents.Player
  typealias Position = MalayanCampaignComponents.Position
  typealias Piece = MalayanCampaignComponents.Piece
  typealias Phase = MalayanCampaignComponents.Phase
  typealias Location = MalayanCampaignComponents.Location

  enum Action: Hashable, Equatable, Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    case initialize
    case setPhase(Phase)
    case withdraw(Piece)
    case skipWithdrawal
    case japaneseAdvance(Piece)
    case counterattack(Piece)
    case defend(Piece)
    case airSupport
    case skipAirSupport
    case advanceTurn
    case claimVictory
    case declareLoss

    var name: String { description }
    var debugDescription: String { description }

    var description: String {
      switch self {
      case .initialize: "Perform setup"
      case .setPhase(let phase): "Go to \(phase.name) phase"
      case .withdraw(let piece): "Withdraw \(piece)"
      case .skipWithdrawal: "Skip withdrawal"
      case .japaneseAdvance(let piece): "Advance \(piece)"
      case .counterattack(let piece): "Counterattack with \(piece)"
      case .defend(let piece): "Defend with \(piece)"
      case .airSupport: "Allied air support at Kuantan"
      case .skipAirSupport: "Skip air support"
      case .advanceTurn: "Advance turn"
      case .claimVictory: "Declare victory!"
      case .declareLoss: "Declare loss."
      }
    }
  }

  // Counterattack CRT from the PDF
  // Columns: 1, 2-3-4, 5-6
  // Rows: Jpn+ (decisive, 3:1 ratio), Jpn (advantage), All/No (allied or no advantage)
  // Values: (alliedHit, japaneseHit)
  let counterattackCRT = TwoParamCRT<MalayanCampaign.Advantage, DSix, (DSix, DSix)>(
    result: { advantage, roll in
      switch roll {
      case .one, .none:
        switch advantage {
        case .japaneseDecisive: (DSix.three, DSix.none)
        case .japanese:         (DSix.three, DSix.one)
        case .alliedOrNone:     (DSix.one, DSix.one)
        }
      case .two, .three, .four:
        switch advantage {
        case .japaneseDecisive: (DSix.three, DSix.one)
        case .japanese:         (DSix.two, DSix.one)
        case .alliedOrNone:     (DSix.one, DSix.two)
        }
      case .five, .six:
        switch advantage {
        case .japaneseDecisive: (DSix.three, DSix.two)
        case .japanese:         (DSix.one, DSix.one)
        case .alliedOrNone:     (DSix.one, DSix.two)
        }
      }
    }
  )

  // Defend CRT from the PDF
  // Columns: 1, 2-3-4, 5-6
  // Rows: Jpn+ (decisive), Jpn (advantage), All/No
  // All damage is on the allies (white boxes); Japanese take 0.
  let defendCRT = TwoParamCRT<MalayanCampaign.Advantage, DSix, (DSix, DSix)>(
    result: { advantage, roll in
      switch roll {
      case .one, .none:
        switch advantage {
        case .japaneseDecisive: (DSix.three, DSix.none)
        case .japanese:         (DSix.two, DSix.none)
        case .alliedOrNone:     (DSix.one, DSix.none)
        }
      case .two, .three, .four:
        switch advantage {
        case .japaneseDecisive: (DSix.two, DSix.none)
        case .japanese:         (DSix.one, DSix.none)
        case .alliedOrNone:     (DSix.none, DSix.none)
        }
      case .five, .six:
        switch advantage {
        case .japaneseDecisive: (DSix.two, DSix.none)
        case .japanese:         (DSix.one, DSix.none)
        case .alliedOrNone:     (DSix.none, DSix.none)
        }
      }
    }
  )

  enum Advantage {
    case japaneseDecisive  // 3:1 or higher ratio
    case japanese          // Japanese strength > Allied
    case alliedOrNone      // Allied advantage or equal
  }

  static func advantage(alliedStrength: DSix, japaneseStrength: DSix) -> Advantage {
    let alliedValue = alliedStrength.rawValue
    let japaneseValue = japaneseStrength.rawValue
    if japaneseValue >= alliedValue * 3 {
      return .japaneseDecisive
    } else if japaneseValue > alliedValue {
      return .japanese
    } else {
      return .alliedOrNone
    }
  }

  func newState() -> State {
    State()
  }
}
