import Testing
import Foundation

@MainActor
struct LoDVassalAssetLoaderTests {

  @Test func sitesFileDecoding() throws {
    let jsonString = """
    {
      "_notes": "test",
      "imageWidth": 2540,
      "imageHeight": 3231,
      "sites": [
        {"id": "east1", "label": "E1", "group": "East Wall",
         "x": 100, "y": 200, "width": 50, "height": 60},
        {"id": "eastBreach", "label": "E 0", "group": "East Wall",
         "x": 50, "y": 100, "width": 202, "height": 210, "siteID": 500},
        {"id": "menAtArms0", "label": "F0:3", "group": "Fighters",
         "x": 300, "y": 400, "width": 40, "height": 40, "value": 3}
      ]
    }
    """
    let json = Data(jsonString.utf8)
    let file = try JSONDecoder().decode(
      LoDVassalAssetLoader.SitesFile.self, from: json)
    #expect(file.imageWidth == 2540)
    #expect(file.imageHeight == 3231)
    #expect(file.sites.count == 3)
    #expect(file.sites[0].id == "east1")
    #expect(file.sites[0].siteID == nil)
    #expect(file.sites[1].siteID == 500)
    #expect(file.sites[2].value == 3)
  }

  @Test func pieceImageMapCoversAllPieces() {
    let pieces = LoDPieceAdapter.pieces()
    let cardID = 30
    for piece in pieces where piece.id != cardID {
      #expect(
        LoDVassalAssetLoader.pieceImageNames[piece.id] != nil,
        "Missing image mapping for piece \(piece.id) (\(piece.label ?? "?"))"
      )
    }
  }
}
