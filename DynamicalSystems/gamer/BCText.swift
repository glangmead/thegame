//
//  BCText.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 1/14/26.
//

import Foundation
import TextTable

extension BattleCard.State: TextTableAble {
  struct CityReport {
    let city: BattleCardComponents.Position
    let ally: BattleCardComponents.Piece?
    let allyStr: Int
    let corps: Bool
    let german: BattleCardComponents.Piece?
    let germanStr: Int
    let control: BattleCardComponents.Control?
  }
  
  var reports: [CityReport] {
    var cities = [CityReport]()
    let track = BattleCardComponents().track
    for cityIndex in (0..<track.length).reversed() {
      let city = Position.onTrack(cityIndex)
      let ally = allyIn(pos: city)
      let german = germanIn(pos: city)
      cities.append(
        CityReport(
          city: city,
          ally: ally,
          allyStr: (ally == nil) ? 0 : strength[ally!]!.rawValue,
          corps: piecesIn(city).contains(.thirtycorps),
          german: german,
          germanStr: (german == nil) ? 0 : strength[german!]!.rawValue,
          control: control[cityIndex]
        )
      )
    }
    return cities
  }
  
  func printTable<Target>(to: inout Target) where Target : TextOutputStream {
    let turnTable = TextTable<BattleCard.State> { state in
      [Column(title: "Turn", value: state.turnNumber),
       Column(title: "Weather", value: state.weather)]
    }
    turnTable.print([self])
    
    let mapTable = TextTable<CityReport> { city in
      [
        Column(title: "City", value: city.city),
        Column(title: "Ally", value: city.ally ?? "none"),
        Column(title: "Str", value: city.allyStr),
        Column(title: "30Corps", value: city.corps ? "XXXCorps" : ""),
        Column(title: "German", value: city.german ?? "none"),
        Column(title: "Str", value: city.germanStr),
        Column(title: "Control", value: city.control ?? "none")
      ]
    }
    mapTable.print(reports)
  }
}
