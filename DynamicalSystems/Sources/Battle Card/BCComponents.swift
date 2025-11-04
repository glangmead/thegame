//
//  BCComponents.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import Foundation

extension BattleCard: GameComponents {
  enum Player: Equatable, Hashable {
    case solo
  }
  
  enum Phase: Equatable, Hashable {
    case setup
    case airdrop
    case battle
    case reinforceGermans
    case advance
    case reinforce1st
    var name: String {
      switch self {
      case .setup:
        "Setup"
      case .airdrop:
        "Airdrop"
      case .battle:
        "Battle"
      case .reinforceGermans:
        "German reinforcements"
      case .advance:
        "Allied advance"
      case .reinforce1st:
        "1st Airb. reinforcement"
      }
    }
  }
  
  enum Piece: Equatable, Hashable, CaseIterable {
    case thirtycorps
    case germanEindhoven
    case germanGrave
    case germanNijmegen
    case germanArnhem
    case allied101st
    case allied82nd
    case allied1st
    
    static func germanFacing(_ city: Position) -> Piece? {
      switch city {
      case .belgium:
        return nil
      case .eindhoven:
        return .germanEindhoven
      case .grave:
        return .germanGrave
      case .nijmegen:
        return .germanNijmegen
      case .arnhem:
        return .germanArnhem
      }
    }

    static func cityContaining(_ germanArmy: Piece) -> Position? {
      switch germanArmy {
      case .germanEindhoven:
        return .eindhoven
      case .germanGrave:
        return .grave
      case .germanNijmegen:
        return .nijmegen
      case .germanArnhem:
        return .arnhem
      default:
        return nil
      }
    }

    var name: String {
      switch self {
      case .thirtycorps:
        "30 Corps"
      case .germanEindhoven:
        "Germans: Eindhoven"
      case .germanGrave:
        "Germans: Grave"
      case .germanNijmegen:
        "Germans: Nimjegen"
      case .germanArnhem:
        "Germans: Arnhem"
      case .allied101st:
        "Allies: 101st"
      case .allied82nd:
        "Allies: 82nd"
      case .allied1st:
        "Allies: 1st"
      }
    }
  }
  
  enum Die: Equatable, Hashable {
    case airdrop
    case attack
    case defend
    case reinforcement
  }
  
  // the board is organized by city, with a few positions per city
  enum Position: String, CaseIterable, Linear {
    case belgium = "Belgium"
    case eindhoven = "Eindhoven"
    case grave = "Grave"
    case nijmegen = "Nijmegen"
    case arnhem = "Arnhem"
    func next() -> Position {
      switch self {
      case .belgium:
        .eindhoven
      case .eindhoven:
        .grave
      case .grave:
        .nijmegen
      case .nijmegen:
        .arnhem
      case .arnhem:
        .arnhem
      }
    }
    var start: Self {
      return .belgium
    }
    var end: Self {
      return .arnhem
    }
  }
  
  enum Advantage: Equatable, Hashable {
    case allies
    case germans
    case tied
  }
    
  struct PiecePosition: Equatable, Hashable {
    var piece: Piece
    var position: Position
  }
}
