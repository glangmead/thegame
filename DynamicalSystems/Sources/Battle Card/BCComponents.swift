//
//  BCComponents.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/31/25 👻
//

import Foundation

extension BattleCard: GameComponents {
  
  /// The manual should perhaps be directly translatable, i.e. easier for a person to digitize.
  /// Setup:
  /// There are four named locations in a track: E, G, N, A. Also, E-1=B (Belgium)
  /// Each location has a space for an ally, a german, a control, and 30 corps
  ///   - immobile positions AE, AG, AN, AA; GE, GG, GN, GA; CE:G, CG:G, CN:G, CA:G
  ///   - mobile pieces All101, All82, All1, All30
  /// Allies (All101, All82, All1) and german (GE, GG, GN, GA) have D6 strength
  /// Germans: GE:2, GG:2, GN:1, GA:2
  /// Allies: All101:6->E, All82:6->G, All1:5->A, 30C->B
  /// There is a D6 turn count, starting at 1
  /// Advancing to turn 7 = LOSE game
  /// There is a boolean for Clear/Fog which starts with Fog
  /// Airdrop:
  /// for each (All101, All82, All1), roll and adjust strength
  /// Battle:
  /// for each ally (which can shrink), in any order (actions commute):
  ///   - choose attack or defend
  ///   - roll
  ///   - update strengths per table
  ///   - ally strength to 0 means LOSE game. german strength clamped at 1.
  ///   - update control
  /// German reinforcements:
  /// for GE, GG, GN, GA add 1 to strength
  /// but for GN, only add if CA:G (control of Arnhem is german)
  /// Allied advance:
  /// advance a unit to the next city
  /// only advance 30C if the next city has allied control
  /// advancing 30C to A WINS game
  /// only advance an army in the same city as 30C
  /// when army1 advances into army2, add army1's strength to army2 and dissolve army1
  /// Allied reinforcements:
  /// if d6 leq turn number and if fog, increase strength of All1, set to clear
  
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
