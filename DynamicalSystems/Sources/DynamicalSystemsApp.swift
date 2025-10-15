//
//  DynamicalSystemsApp.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 8/30/25.
//

import ComposableArchitecture
import SwiftUI

@main
struct DynamicalSystemsApp: App {
  var body: some Scene {
    WindowGroup {
      CantStopView(store: Store(initialState: CantStop.State()) {
        CantStop()
      })
    }
  }
}
