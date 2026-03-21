import CoreGraphics

struct InterpretedPieceAdapter {
  let pieces: [GamePiece]
  let section: GameSection

  init(
    state: InterpretedState,
    schema: StateSchema,
    graph: SiteGraph,
    playerIndex: [String: Int]
  ) {
    var pieces: [GamePiece] = []
    var section: GameSection = [:]

    for (pieceName, siteValue) in state.positions {
      guard let siteID = graph.resolve(siteValue) else { continue }

      let enumType = state.pieceTypes[pieceName] ?? ""
      let owner = playerIndex[enumType].map { PlayerID($0) }
      let pieceID = pieceName.hashValue & 0x7FFFFFFF // stable positive hash

      // Transpose display values from column-major dicts
      var displayValues: [String: Int] = [:]
      for (dictName, fieldDef) in schema.fields {
        guard case .dict(let keyType, _) = fieldDef.kind,
              keyType == enumType else { continue }
        if let val = state.getDict(dictName)[pieceName]?.asInt {
          displayValues[dictName] = val
        }
      }

      let piece = GamePiece(
        id: pieceID,
        kind: .token,
        owner: owner,
        label: pieceName,
        displayValues: displayValues
      )
      pieces.append(piece)
      section[piece] = .at(siteID)
    }

    self.pieces = pieces
    self.section = section
  }
}
