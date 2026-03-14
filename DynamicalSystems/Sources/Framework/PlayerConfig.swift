//
//  PlayerConfig.swift
//  DynamicalSystems
//
//  Player mode configuration and reusable config sheet.
//

import SwiftUI

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

struct PlayerSlot<Player: Hashable>: Identifiable {
  let player: Player
  let label: String
  let allowedModes: [PlayerMode]
  var id: String { label }
}

struct PlayerConfigSheet<Player: Hashable>: View {
  let slots: [PlayerSlot<Player>]
  @Binding var modes: [Player: PlayerMode]
  let onStart: () -> Void

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        ForEach(slots) { slot in
          Picker(slot.label, selection: binding(for: slot.player)) {
            ForEach(slot.allowedModes) { mode in
              Text(mode.rawValue).tag(mode)
            }
          }
        }
      }
      .navigationTitle("Configure Players")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Start") { onStart() }
        }
      }
    }
  }

  private func binding(for player: Player) -> Binding<PlayerMode> {
    Binding(
      get: { modes[player, default: .interactive] },
      set: { modes[player] = $0 }
    )
  }
}
