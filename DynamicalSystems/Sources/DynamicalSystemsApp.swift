//
//  DynamicalSystemsApp.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 8/30/25.
//

import SwiftUI

@main
struct DynamicalSystemsApp: App {
  var body: some Scene {
    WindowGroup {
      NavigationStack {
        List {
          NavigationLink(CantStopPages.gameName) {
            CantStopView()
          }
          NavigationLink(BCPages.gameName) {
            BCView()
          }
          NavigationLink(MCPages.gameName) {
            MCView()
          }
          NavigationLink(Hearts.gameName) {
            HeartsView()
          }
          NavigationLink(LoD.gameName) {
            LoDView()
          }
          NavigationLink("Coin Flip (DSL)") {
            InterpretedGameView(game: InterpretedGameView.sampleGame)
          }
        }
        .navigationTitle("Games")
      }
    }
  }
}
