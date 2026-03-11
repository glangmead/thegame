//
//  LoDText.swift
//  DynamicalSystems
//
//  Legions of Darkness — CLI text table rendering.
//

import Foundation
import TextTable

extension LoD.State: TextTableAble {

  private struct ArmyReport {
    let track: String
    let army: String
    let space: String
    let status: String
  }

  private struct HeroReport {
    let name: String
    let location: String
    let condition: String
  }

  private var armyReports: [ArmyReport] {
    LoD.ArmySlot.allCases.compactMap { slot in
      guard let armyType = armyType[slot] else { return nil }
      let space = armyPosition[slot].map { "\($0)" } ?? "off"
      var flags: [String] = []
      if slowedArmy == slot { flags.append("slow") }
      if bloodyBattleArmy == slot { flags.append("bloody") }
      return ArmyReport(
        track: slot.track.rawValue,
        army: armyType.rawValue,
        space: space,
        status: flags.joined(separator: ",")
      )
    }
  }

  private var heroReports: [HeroReport] {
    LoD.HeroType.allCases.compactMap { hero in
      guard let loc = heroLocation[hero] else { return nil }
      let location: String
      switch loc {
      case .reserves: location = "reserves"
      case .onTrack(let track): location = track.rawValue
      }
      let condition: String
      if heroDead.contains(hero) {
        condition = "dead"
      } else if heroWounded.contains(hero) {
        condition = "wounded"
      } else {
        condition = "healthy"
      }
      return HeroReport(name: hero.rawValue, location: location, condition: condition)
    }
  }

  private var wallSummary: String {
    var info: [String] = []
    for track in LoD.Track.walls {
      if breaches.contains(track) { info.append("\(track.rawValue): breached") }
      if barricades.contains(track) { info.append("\(track.rawValue): barricade") }
      if let upgrade = upgrades[track] { info.append("\(track.rawValue): \(upgrade.rawValue)") }
    }
    return info.joined(separator: ", ")
  }

  func printTable<Target>(to output: inout Target) where Target: TextOutputStream {
    let header = TextTable<LoD.State> { state in
      [
        Column(title: "Phase", value: state.phase.rawValue),
        Column(title: "Time", value: "\(state.timePosition)/15"),
        Column(title: "Morale", value: state.morale.rawValue),
        Column(title: "Card", value: state.currentCard?.title ?? "-")
      ]
    }
    if let text = header.string(for: [self]) { Swift.print(text, to: &output) }

    let resources = TextTable<LoD.State> { state in
      [
        Column(title: "MaA", value: state.defenderValue(for: .menAtArms)),
        Column(title: "Arch", value: state.defenderValue(for: .archers)),
        Column(title: "Priest", value: state.defenderValue(for: .priests)),
        Column(title: "Arcane", value: state.arcaneEnergy),
        Column(title: "Divine", value: state.divineEnergy)
      ]
    }
    if let text = resources.string(for: [self]) { Swift.print(text, to: &output) }

    let armies = TextTable<ArmyReport> { row in
      [
        Column(title: "Track", value: row.track),
        Column(title: "Army", value: row.army),
        Column(title: "Space", value: row.space),
        Column(title: "Status", value: row.status)
      ]
    }
    if let text = armies.string(for: armyReports) { Swift.print(text, to: &output) }

    let heroes = TextTable<HeroReport> { row in
      [
        Column(title: "Hero", value: row.name),
        Column(title: "Location", value: row.location),
        Column(title: "Condition", value: row.condition)
      ]
    }
    if let text = heroes.string(for: heroReports) { Swift.print(text, to: &output) }

    let walls = wallSummary
    if !walls.isEmpty { Swift.print("Walls: \(walls)", to: &output) }

    let known = LoD.SpellType.allCases.filter { spellStatus[$0] == .known }
    let cast = LoD.SpellType.allCases.filter { spellStatus[$0] == .cast }
    if !known.isEmpty {
      Swift.print("Spells known: \(known.map(\.rawValue).joined(separator: ", "))", to: &output)
    }
    if !cast.isEmpty {
      Swift.print("Spells cast: \(cast.map(\.rawValue).joined(separator: ", "))", to: &output)
    }
  }
}
