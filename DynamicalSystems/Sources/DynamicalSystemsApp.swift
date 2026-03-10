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
                    NavigationLink("Can't Stop") {
                        CantStopView()
                    }
                    NavigationLink("Battle Card: Market Garden") {
                        BCView()
                    }
                    NavigationLink("Battle Card: Malayan Campaign") {
                        MCView()
                    }
                    NavigationLink("Legions of Darkness") {
                        LoDView()
                    }
                }
                .navigationTitle("Games")
            }
        }
    }
}
