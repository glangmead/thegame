//
//  PlayerMode.swift
//  DynamicalSystems
//
//  Player mode enum — no SwiftUI dependency so CLI targets can use it.
//

import Foundation

enum PlayerMode: String, CaseIterable, Identifiable, Sendable {
  case interactive = "Interactive"
  case fastAI = "Fast AI"
  case slowAI = "Slow AI"
  case excluded = "None"

  var id: String { rawValue }

  var mctsIterations: Int? {
    switch self {
    case .interactive: nil
    case .fastAI: 50
    case .slowAI: 1500
    case .excluded: nil
    }
  }
}
