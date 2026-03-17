//
//  PlayerConfig.swift
//  DynamicalSystems
//
//  Player mode configuration and reusable config sheet.
//

import SwiftUI

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
