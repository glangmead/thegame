//
//  BoardSummaryView.swift
//  DynamicalSystems
//
//  Generic text-based board summary for VoiceOver and screen reader users.
//  Derives all content from SiteGraph + GameSection — works for any game.
//

import SwiftUI

/// Sections describing board state as text. Use inside a List context.
/// For standalone use, wrap in `List { BoardSummarySections(...) }`.
struct BoardSummarySections: View {
  let graph: SiteGraph
  let pieces: [GamePiece]
  let section: GameSection

  var body: some View {
    ForEach(trackSummaries, id: \.name) { track in
      Section(track.name) {
        if track.entries.isEmpty {
          Text("Empty")
            .foregroundStyle(.secondary)
        } else {
          ForEach(track.entries) { entry in
            Text(entry.description)
          }
        }
      }
    }
    if !untrackedEntries.isEmpty {
      Section("Other") {
        ForEach(untrackedEntries) { entry in
          Text(entry.description)
        }
      }
    }
  }

  // MARK: - Data

  private struct TrackSummary {
    let name: String
    let entries: [PieceEntry]
  }

  private struct PieceEntry: Identifiable {
    let id: Int
    let description: String
  }

  private var trackSummaries: [TrackSummary] {
    graph.tracks.keys.sorted().map { trackName in
      let siteIDs = graph.tracks[trackName] ?? []
      var entries: [PieceEntry] = []
      for (index, siteID) in siteIDs.enumerated() {
        let piecesHere = section.piecesAt(siteID)
        guard !piecesHere.isEmpty else { continue }
        let siteName = graph.sites[siteID]?.label ?? "Space \(index + 1)"
        for piece in piecesHere.sorted(by: { $0.id < $1.id }) {
          let pieceName = pieceDescription(piece)
          entries.append(PieceEntry(
            id: piece.id,
            description: "\(pieceName) at \(siteName)"))
        }
      }
      return TrackSummary(name: trackName, entries: entries)
    }
  }

  private var untrackedEntries: [PieceEntry] {
    let trackedSites = Set(graph.tracks.values.flatMap { $0 })
    var entries: [PieceEntry] = []
    for (piece, value) in section.sorted(by: { $0.key.id < $1.key.id }) {
      guard let site = value.site, !trackedSites.contains(site) else { continue }
      let siteName = graph.sites[site]?.label ?? site.description
      let pieceName = pieceDescription(piece)
      entries.append(PieceEntry(
        id: piece.id,
        description: "\(pieceName) at \(siteName)"))
    }
    return entries
  }

  private func pieceDescription(_ piece: GamePiece) -> String {
    var parts: [String] = []
    if let label = piece.label {
      parts.append(label)
    }
    switch piece.kind {
    case .token:
      break
    case .die(let sides):
      if case .dieShowing(let face, _) = section[piece] {
        parts.append("showing \(face)")
      } else {
        parts.append("d\(sides)")
      }
    case .card:
      if case .cardState(let name, let faceUp, _, _, _) = section[piece] {
        parts.append(faceUp ? name : "face down")
      }
    }
    return parts.isEmpty ? "Piece \(piece.id)" : parts.joined(separator: " ")
  }
}
