//
//  HeartsText.swift
//  DynamicalSystems
//
//  Hearts — CLI text table rendering for gamer tool.
//

import Foundation
import TextTable

extension Hearts.State: TextTableAble {

  private struct SeatReport {
    let seat: String
    let cards: Int
    let handPenalty: Int
    let cumulative: Int
  }

  func printTable<Target>(to output: inout Target) where Target: TextOutputStream {
    let header = TextTable<Hearts.State> { state in
      [
        Column(title: "Hand", value: state.handNumber + 1),
        Column(title: "Trick", value: state.turnNumber),
        Column(title: "Pass", value: state.passDirection.description),
        Column(title: "Hearts", value: state.heartsBroken ? "broken" : "no"),
        Column(title: "Phase", value: state.phase.rawValue)
      ]
    }
    if let text = header.string(for: [self]) { Swift.print(text, to: &output) }

    let reports = Hearts.Seat.allCases.map { seat in
      SeatReport(
        seat: seat.description,
        cards: hands[seat]?.count ?? 0,
        handPenalty: handPenalties[seat] ?? 0,
        cumulative: cumulativeScores[seat] ?? 0
      )
    }
    let seats = TextTable<SeatReport> { row in
      [
        Column(title: "Seat", value: row.seat),
        Column(title: "Cards", value: row.cards),
        Column(title: "Hand", value: row.handPenalty),
        Column(title: "Total", value: row.cumulative)
      ]
    }
    if let text = seats.string(for: reports) { Swift.print(text, to: &output) }

    if !currentTrick.isEmpty {
      let trickStr = currentTrick
        .map { "\($0.seat): \($0.card)" }
        .joined(separator: " | ")
      Swift.print("Trick: \(trickStr)", to: &output)
    }
  }
}
