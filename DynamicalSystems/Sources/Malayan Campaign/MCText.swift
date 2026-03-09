//
//  MCText.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/9/26.
//

import Foundation
import TextTable

extension MalayanCampaign.State: TextTableAble {
  struct LocationReport {
    let location: MalayanCampaignComponents.Location
    let allies: String
    let allyStr: Int
    let japanese: String
    let japStr: Int
  }

  var reports: [LocationReport] {
    MalayanCampaignComponents.Location.allCases.map { loc in
      let allies = alliesAt(loc)
      let jap = japaneseAt(loc)
      let allyNames = allies.map { $0.shortName }.joined(separator: ",")
      let allyTotal = allies.compactMap { strength[$0]?.rawValue }.reduce(0, +)
      let japName = jap?.shortName ?? ""
      let japValue = jap.flatMap { strength[$0]?.rawValue } ?? 0
      return LocationReport(
        location: loc,
        allies: allyNames,
        allyStr: allyTotal,
        japanese: japName,
        japStr: japValue
      )
    }
  }

  func printTable<Target>(to: inout Target) where Target: TextOutputStream {
    let turnTable = TextTable<MalayanCampaign.State> { state in
      [Column(title: "Turn", value: state.turnNumber),
       Column(title: "Phase", value: state.phase.name)]
    }
    if let s = turnTable.string(for: [self]) { Swift.print(s, to: &to) }

    let mapTable = TextTable<LocationReport> { row in
      [
        Column(title: "Location", value: row.location),
        Column(title: "Allies", value: row.allies),
        Column(title: "Str", value: row.allyStr),
        Column(title: "Japanese", value: row.japanese),
        Column(title: "Str", value: row.japStr)
      ]
    }
    if let s = mapTable.string(for: reports) { Swift.print(s, to: &to) }
  }
}
