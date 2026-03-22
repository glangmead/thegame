import Foundation
import Testing
@testable import DynamicalSystems

@Suite("JSONGameParser")
// swiftlint:disable:next type_body_length
struct JSONGameParserTests {

  @Test func parseEnumComponent() throws {
    let json = """
    {
      "enums": [
        {"name": "Phase", "values": ["setup", "play"]},
        {"name": "Piece", "values": ["knight"],
         "player": 0, "displayNames": ["Knight"]}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    #expect(registry.enumCases("Phase") == ["setup", "play"])
    #expect(registry.displayName(forCase: "knight") == "Knight")
    #expect(registry.playerIndex["Piece"] == 0)
  }

  @Test func parseCRT() throws {
    let json = """
    {
      "enums": [],
      "crts": [
        {"name": "penalty",
         "col": [1, 6],
         "entries": [
           {"dice": [1, 2], "values": [2]},
           {"dice": [3, 4], "values": [1]},
           {"dice": [5, 6], "values": [0]}
         ]}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    let crt = try #require(registry.crt("penalty"))
    #expect(crt.lookup(row: nil, dieRoll: 1) == [.int(2)])
    #expect(crt.lookup(row: nil, dieRoll: 4) == [.int(1)])
    #expect(crt.lookup(row: nil, dieRoll: 6) == [.int(0)])
  }

  @Test func parseSingleDiceCRT() throws {
    let json = """
    {
      "enums": [],
      "crts": [
        {"name": "hit",
         "row": "Type",
         "col": [1, 6],
         "results": ["damage"],
         "entries": {
           "light": [
             {"dice": [1], "values": [3]},
             {"dice": [2, 3, 4], "values": [1]},
             {"dice": [5, 6], "values": [0]}
           ]
         }}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    let crt = try #require(registry.crt("hit"))
    #expect(crt.lookup(row: "light", dieRoll: 1) == [.int(3)])
    #expect(crt.lookup(row: "light", dieRoll: 3) == [.int(1)])
    #expect(crt.lookup(row: "light", dieRoll: 5) == [.int(0)])
  }

  @Test func parseStateSchema() throws {
    let json = """
    {
      "fields": [{"name": "phase", "type": "Phase"}],
      "counters": [{"name": "hp", "min": 0, "max": 10}],
      "flags": ["ended", "victory"]
    }
    """
    let value = try JSONGameParser.parse(json)
    let schema = try JSONStateSchema.build(value)
    #expect(schema.field("phase") != nil)
    #expect(schema.field("hp")?.kind == .counter(min: 0, max: 10))
    #expect(schema.field("ended")?.kind == .flag)
  }

  @Test func parseActionSchema() throws {
    let json = """
    {
      "actions": [
        {"name": "move"},
        {"name": "attack", "params": [{"name": "target", "type": "Piece"}]}
      ],
      "groups": [
        {"name": "Combat", "actions": ["attack"]}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let schema = try JSONActionSchema.build(value)
    #expect(schema.action("move") != nil)
    #expect(schema.action("attack")?.parameters.count == 1)
    #expect(schema.groups.count == 1)
  }

  @Test func parseGraph() throws {
    let json = """
    {
      "tracks": [
        {"name": "road", "length": 3, "tags": ["main"]},
        {"name": "side", "length": 2}
      ],
      "connections": [
        {"type": "crossConnect", "from": "road", "to": "side", "offset": 1}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let graph = try JSONGraphBuilder.build(value)
    #expect(graph.tracks.count == 2)
  }

  // swiftlint:disable:next function_body_length
  @Test func trivialJSONGamePlaythrough() throws {
    let jsonc = """
    {
      "game": "Coin Flip",
      "players": 1,
      "components": {
        "enums": [
          {"name": "Phase", "values": ["play", "done"]}
        ]
      },
      "state": {
        "fields": [{"name": "phase", "type": "Phase"}],
        "counters": [{"name": "score", "min": 0, "max": 10}],
        "flags": ["ended", "victory", "gameAcknowledged"]
      },
      "graph": {"tracks": [], "connections": []},
      "actions": {
        "actions": [
          {"name": "flipHeads"},
          {"name": "flipTails"},
          {"name": "acknowledge"}
        ]
      },
      "rules": {
        "terminal": "gameAcknowledged",
        "pages": [
          {
            "page": "Play",
            "rules": [
              {"when": {"==": ["phase", ".play"]},
               "offer": ["flipHeads", "flipTails"]}
            ],
            "reduce": {
              "flipHeads": {"seq": [
                {"increment": ["score", 1]},
                {"if": [{">=": ["score", 3]},
                  {"seq": [{"endGame": ["victory"]},
                           {"setPhase": [".done"]}]},
                  {"log": ["no win yet"]}]}
              ]},
              "flipTails": {"log": ["tails, no points"]}
            }
          }
        ],
        "priorities": [
          {
            "priority": "Victory",
            "rules": [
              {"when": {"and": ["victory", {"not": ["gameAcknowledged"]}]},
               "offer": ["acknowledge"]}
            ],
            "reduce": {
              "acknowledge": {"set": ["gameAcknowledged", true]}
            }
          }
        ]
      },
      "defines": [],
      "metadata": {}
    }
    """
    let game = try GameBuilder.build(fromJSONC: jsonc)
    var state = game.newState()
    #expect(!game.isTerminal(state: state))
    for _ in 0..<3 {
      let actions = game.allowedActions(state: state)
      let heads = actions.first { $0.name == "flipHeads" }!
      _ = game.reduce(into: &state, action: heads)
    }
    let actions = game.allowedActions(state: state)
    #expect(actions.count == 1)
    #expect(actions[0].name == "acknowledge")
    _ = game.reduce(into: &state, action: actions[0])
    #expect(game.isTerminal(state: state))
  }

  // swiftlint:disable:next function_body_length
  @Test func forEachPageJSON() throws {
    let jsonc = """
    {
      "game": "ForEach Test",
      "players": 1,
      "components": {
        "enums": [
          {"name": "Phase", "values": ["roll", "done"]},
          {"name": "Unit", "values": ["a", "b"]}
        ]
      },
      "state": {
        "fields": [{"name": "phase", "type": "Phase"}],
        "counters": [{"name": "total", "min": 0, "max": 100}],
        "flags": ["ended", "victory", "gameAcknowledged"]
      },
      "graph": {"tracks": [], "connections": []},
      "actions": {
        "actions": [
          {"name": "rollUnit", "params": [{"name": "piece", "type": "Unit"}]},
          {"name": "enterDone"}
        ]
      },
      "rules": {
        "terminal": "gameAcknowledged",
        "pages": [
          {
            "forEachPage": "Roll Units",
            "when": {"==": ["phase", ".roll"]},
            "items": {"list": [".a", ".b"]},
            "transition": "enterDone",
            "reduce": {
              "rollUnit": {"increment": ["total", 1]}
            }
          },
          {
            "page": "Done",
            "rules": [
              {"when": {"==": ["phase", ".done"]},
               "offer": ["enterDone"]}
            ],
            "reduce": {
              "enterDone": {"seq": [
                {"set": ["gameAcknowledged", true]},
                {"setPhase": [".done"]}
              ]}
            }
          }
        ],
        "priorities": []
      },
      "defines": [],
      "metadata": {}
    }
    """
    let game = try GameBuilder.build(fromJSONC: jsonc)
    var state = game.newState()
    // Should offer rollUnit for first item
    let actions1 = game.allowedActions(state: state)
    #expect(actions1.contains { $0.name == "rollUnit" })
    _ = game.reduce(
      into: &state,
      action: actions1.first { $0.name == "rollUnit" }!
    )
    // Should offer rollUnit for second item
    let actions2 = game.allowedActions(state: state)
    #expect(actions2.contains { $0.name == "rollUnit" })
    _ = game.reduce(
      into: &state,
      action: actions2.first { $0.name == "rollUnit" }!
    )
    // After both, total should be 2
    #expect(state.getCounter("total") == 2)
  }

  // MARK: - Component tests

  @Test func parseEnumWithPlayerIndex() throws {
    let json = """
    {
      "enums": [
        {"name": "Ally", "values": ["infantry", "armor"], "player": 0},
        {"name": "Enemy", "values": ["militia"], "player": 1}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    #expect(registry.playerIndex["Ally"] == 0)
    #expect(registry.playerIndex["Enemy"] == 1)
    #expect(registry.playerIndex["Phase"] == nil)
  }

  @Test func displayNameLookup() throws {
    let json = """
    {
      "enums": [
        {"name": "Unit", "values": ["inf", "cav", "art"],
         "displayNames": ["Infantry", "Cavalry", "Artillery"]}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    #expect(registry.displayName(forCase: "inf") == "Infantry")
    #expect(registry.displayName(forCase: "cav") == "Cavalry")
    #expect(registry.displayName(forCase: "art") == "Artillery")
    #expect(registry.displayName(forCase: "nonexistent") == nil)
  }

  @Test func isEnumCaseLookup() throws {
    let json = """
    {
      "enums": [
        {"name": "Phase", "values": ["setup", "play"]},
        {"name": "Piece", "values": ["knight", "rook"]}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    #expect(registry.isEnumCase("knight") == "Piece")
    #expect(registry.isEnumCase("setup") == "Phase")
    #expect(registry.isEnumCase("missing") == nil)
  }

  @Test func parseFnComponent() throws {
    let json = """
    {
      "enums": [
        {"name": "Unit", "values": ["inf", "cav"]}
      ],
      "functions": [
        {"name": "strength", "domain": "Unit",
         "mapping": {"inf": 3, "cav": 5}}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    #expect(registry.lookupFn("strength", argument: "inf") == .int(3))
    #expect(registry.lookupFn("strength", argument: "cav") == .int(5))
    #expect(registry.lookupFn("strength", argument: "art") == nil)
    #expect(registry.lookupFn("missing", argument: "inf") == nil)
  }

  @Test func parseStructComponent() throws {
    let json = """
    {
      "enums": [],
      "structs": [
        {"name": "Position",
         "fields": [
           {"name": "x", "type": "Int"},
           {"name": "y", "type": "Int"}
         ]}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    let posDef = registry.structs["Position"]
    #expect(posDef != nil)
    #expect(posDef?.fields.count == 2)
    #expect(posDef?.fields[0].name == "x")
    #expect(posDef?.fields[1].type == "Int")
  }

  @Test func parseCardsComponent() throws {
    let json = """
    {
      "enums": [],
      "cards": [
        {"title": "Fireball", "cost": 3},
        {"title": "Heal", "cost": 1}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let registry = try JSONComponentRegistry.build(value)
    #expect(registry.cards.count == 2)
    // Cards are stored as .structValue with type "Card"
    if case .structValue(let type, let fields) = registry.cards[0] {
      #expect(type == "Card")
      #expect(fields["title"] == .string("Fireball"))
      #expect(fields["cost"] == .int(3))
    } else {
      Issue.record("Expected structValue for card")
    }
  }

  // MARK: - Schema tests

  @Test func parseAllFieldKinds() throws {
    let json = """
    {
      "fields": [{"name": "phase", "type": "Phase"}],
      "counters": [{"name": "hp", "min": 0, "max": 20}],
      "flags": ["ended"],
      "dicts": [{"name": "strength", "key": "Unit", "value": "Int"}],
      "sets": [{"name": "active", "element": "Unit"}],
      "decks": [{"name": "drawPile", "cardType": "Card"}],
      "optionals": [{"name": "target", "type": "Unit"}],
      "lists": [{"name": "log", "element": "String"}]
    }
    """
    let value = try JSONGameParser.parse(json)
    let schema = try JSONStateSchema.build(value)
    #expect(schema.field("phase")?.kind == .field(type: "Phase"))
    #expect(schema.field("hp")?.kind == .counter(min: 0, max: 20))
    #expect(schema.field("ended")?.kind == .flag)
    #expect(schema.field("strength")?.kind == .dict(keyType: "Unit", valueType: "Int"))
    #expect(schema.field("active")?.kind == .set(elementType: "Unit"))
    #expect(schema.field("drawPile")?.kind == .deck(cardType: "Card"))
    #expect(schema.field("target")?.kind == .optional(valueType: "Unit"))
    // lists map to .deck internally
    #expect(schema.field("log")?.kind == .deck(cardType: "String"))
  }

  @Test func counterWithInfMax() throws {
    let json = """
    {
      "counters": [
        {"name": "score", "min": 0, "max": "inf"}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let schema = try JSONStateSchema.build(value)
    #expect(schema.field("score")?.kind == .counter(min: 0, max: Int.max))
  }

  @Test func schemaFieldQuery() throws {
    let json = """
    {
      "counters": [{"name": "hp", "min": 0, "max": 10}],
      "flags": ["ended"]
    }
    """
    let value = try JSONGameParser.parse(json)
    let schema = try JSONStateSchema.build(value)
    #expect(schema.field("hp")?.kind == .counter(min: 0, max: 10))
    #expect(schema.field("ended")?.kind == .flag)
    #expect(schema.field("nonexistent") == nil)
  }

  @Test func schemaAllFieldNames() throws {
    let json = """
    {
      "fields": [{"name": "phase", "type": "Phase"}],
      "counters": [{"name": "hp", "min": 0, "max": 10}],
      "flags": ["ended", "victory"]
    }
    """
    let value = try JSONGameParser.parse(json)
    let schema = try JSONStateSchema.build(value)
    let names = Set(schema.allFieldNames)
    #expect(names == Set(["phase", "hp", "ended", "victory"]))
  }

  // MARK: - Graph tests

  @Test func graphCrossConnect() throws {
    let json = """
    {
      "tracks": [
        {"name": "road", "length": 3},
        {"name": "side", "length": 3}
      ],
      "connections": [
        {"from": "road", "to": "side", "offset": 0}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    let graph = try JSONGraphBuilder.build(value)
    // Verify both tracks exist
    let roadSites = try #require(graph.tracks["road"])
    let sideSites = try #require(graph.tracks["side"])
    #expect(roadSites.count == 3)
    #expect(sideSites.count == 3)
    // Cross-connection: road[0] should reach side[0] via .custom("side")
    let roadSite0 = graph.sites[roadSites[0]]
    #expect(roadSite0?.adjacency[.custom("side")] == sideSites[0])
    // Reverse: side[0] should reach road[0] via .custom("road")
    let sideSite0 = graph.sites[sideSites[0]]
    #expect(sideSite0?.adjacency[.custom("road")] == roadSites[0])
  }

  @Test func graphNamedSites() throws {
    let json = """
    {
      "tracks": [
        {"name": "path", "length": 3,
         "displayNames": ["Start", "Middle", "End"]}
      ],
      "connections": []
    }
    """
    let value = try JSONGameParser.parse(json)
    let graph = try JSONGraphBuilder.build(value)
    let pathSites = try #require(graph.tracks["path"])
    #expect(graph.sites[pathSites[0]]?.displayName == "Start")
    #expect(graph.sites[pathSites[1]]?.displayName == "Middle")
    #expect(graph.sites[pathSites[2]]?.displayName == "End")
  }

  @Test func graphTrackTags() throws {
    let json = """
    {
      "tracks": [
        {"name": "main", "length": 2, "tags": ["highway", "paved"]},
        {"name": "dirt", "length": 2, "tags": ["unpaved"]}
      ],
      "connections": []
    }
    """
    let value = try JSONGameParser.parse(json)
    let graph = try JSONGraphBuilder.build(value)
    #expect(graph.trackTags["main"]?.contains("highway") == true)
    #expect(graph.trackTags["main"]?.contains("paved") == true)
    #expect(graph.trackTags["dirt"]?.contains("unpaved") == true)
    // Sites also inherit track tags
    let mainSites = try #require(graph.tracks["main"])
    let site0Tags = graph.sites[mainSites[0]]?.tags ?? []
    #expect(site0Tags.contains("highway"))
    #expect(site0Tags.contains("paved"))
    #expect(site0Tags.contains("track:main"))
  }

  // MARK: - Page / rule tests

  // swiftlint:disable:next function_body_length
  @Test func parseSimplePage() throws {
    let jsonc = """
    {
      "game": "Page Test",
      "players": 1,
      "components": {
        "enums": [
          {"name": "Phase", "values": ["play", "done"]}
        ]
      },
      "state": {
        "fields": [{"name": "phase", "type": "Phase"}],
        "counters": [{"name": "points", "min": 0, "max": 10}],
        "flags": ["ended", "victory", "gameAcknowledged"]
      },
      "graph": {"tracks": [], "connections": []},
      "actions": {
        "actions": [{"name": "score"}, {"name": "ack"}]
      },
      "rules": {
        "terminal": "gameAcknowledged",
        "pages": [
          {
            "page": "Main",
            "rules": [
              {"when": {"==": ["phase", ".play"]},
               "offer": ["score"]}
            ],
            "reduce": {
              "score": {"seq": [
                {"increment": ["points", 1]},
                {"endGame": ["victory"]},
                {"set": ["gameAcknowledged", true]}
              ]}
            }
          }
        ],
        "priorities": []
      },
      "defines": [],
      "metadata": {}
    }
    """
    let game = try GameBuilder.build(fromJSONC: jsonc)
    var state = game.newState()
    let actions = game.allowedActions(state: state)
    #expect(actions.contains { $0.name == "score" })
    _ = game.reduce(
      into: &state,
      action: actions.first { $0.name == "score" }!
    )
    #expect(state.getCounter("points") == 1)
    #expect(game.isTerminal(state: state))
  }

  // swiftlint:disable:next function_body_length
  @Test func parsePriorityPage() throws {
    let jsonc = """
    {
      "game": "Priority Test",
      "players": 1,
      "components": {
        "enums": [
          {"name": "Phase", "values": ["play", "done"]}
        ]
      },
      "state": {
        "fields": [{"name": "phase", "type": "Phase"}],
        "counters": [{"name": "hp", "min": 0, "max": 10}],
        "flags": ["ended", "victory", "gameAcknowledged"]
      },
      "graph": {"tracks": [], "connections": []},
      "actions": {
        "actions": [
          {"name": "damage"},
          {"name": "claimVictory"}
        ]
      },
      "rules": {
        "terminal": "gameAcknowledged",
        "pages": [
          {
            "page": "Combat",
            "rules": [
              {"when": {"==": ["phase", ".play"]},
               "offer": ["damage"]}
            ],
            "reduce": {
              "damage": {"seq": [
                {"increment": ["hp", 1]},
                {"if": [{">=": ["hp", 3]},
                  {"endGame": ["victory"]},
                  {"log": ["not yet"]}]}
              ]}
            }
          }
        ],
        "priorities": [
          {
            "priority": "Win",
            "rules": [
              {"when": {"and": ["victory", {"not": ["gameAcknowledged"]}]},
               "offer": ["claimVictory"]}
            ],
            "reduce": {
              "claimVictory": {"set": ["gameAcknowledged", true]}
            }
          }
        ]
      },
      "defines": [],
      "metadata": {}
    }
    """
    let game = try GameBuilder.build(fromJSONC: jsonc)
    var state = game.newState()
    // Play until victory triggers
    for _ in 0..<3 {
      let actions = game.allowedActions(state: state)
      let dmg = try #require(actions.first { $0.name == "damage" })
      _ = game.reduce(into: &state, action: dmg)
    }
    // Priority should now offer claimVictory
    let actions = game.allowedActions(state: state)
    #expect(actions.count == 1)
    #expect(actions[0].name == "claimVictory")
    _ = game.reduce(into: &state, action: actions[0])
    #expect(game.isTerminal(state: state))
  }

  // swiftlint:disable:next function_body_length
  @Test func parseReactionRule() throws {
    let jsonc = """
    {
      "game": "Reaction Test",
      "players": 1,
      "components": {
        "enums": [
          {"name": "Phase", "values": ["play", "done"]}
        ]
      },
      "state": {
        "fields": [{"name": "phase", "type": "Phase"}],
        "counters": [{"name": "score", "min": 0, "max": 100}],
        "flags": ["ended", "victory", "gameAcknowledged", "bonusApplied"]
      },
      "graph": {"tracks": [], "connections": []},
      "actions": {
        "actions": [{"name": "score3"}, {"name": "ack"}]
      },
      "rules": {
        "terminal": "gameAcknowledged",
        "pages": [
          {
            "page": "Play",
            "rules": [
              {"when": {"==": ["phase", ".play"]},
               "offer": ["score3"]}
            ],
            "reduce": {
              "score3": {"increment": ["score", 3]}
            }
          }
        ],
        "priorities": [
          {
            "priority": "EndGame",
            "rules": [
              {"when": {"and": [{">=": ["score", 5]},
                                {"not": ["gameAcknowledged"]}]},
               "offer": ["ack"]}
            ],
            "reduce": {
              "ack": {"seq": [
                {"endGame": ["victory"]},
                {"set": ["gameAcknowledged", true]}
              ]}
            }
          }
        ],
        "reactions": [
          {
            "name": "bonus",
            "when": {"and": [{">=": ["score", 3]},
                             {"not": ["bonusApplied"]}]},
            "apply": {"seq": [
              {"increment": ["score", 10]},
              {"set": ["bonusApplied", true]}
            ]}
          }
        ]
      },
      "defines": [],
      "metadata": {}
    }
    """
    let game = try GameBuilder.build(fromJSONC: jsonc)
    var state = game.newState()
    let actions = game.allowedActions(state: state)
    let score3 = try #require(actions.first { $0.name == "score3" })
    _ = game.reduce(into: &state, action: score3)
    // After scoring 3, the reaction should fire and add 10 more
    #expect(state.getCounter("score") == 13)
    #expect(state.getFlag("bonusApplied"))
  }

  // MARK: - Validation / error tests

  @Test func malformedEnumThrows() throws {
    let json = """
    {
      "enums": [
        {"values": ["a", "b"]}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    #expect(throws: DSLError.self) {
      _ = try JSONComponentRegistry.build(value)
    }
  }

  @Test func malformedCounterThrows() throws {
    let json = """
    {
      "counters": [
        {"min": 0, "max": 10}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    #expect(throws: DSLError.self) {
      _ = try JSONStateSchema.build(value)
    }
  }

  @Test func malformedFlagThrows() throws {
    let json = """
    {
      "flags": [42]
    }
    """
    let value = try JSONGameParser.parse(json)
    #expect(throws: DSLError.self) {
      _ = try JSONStateSchema.build(value)
    }
  }

  @Test func malformedActionThrows() throws {
    let json = """
    {
      "actions": [
        {"params": []}
      ]
    }
    """
    let value = try JSONGameParser.parse(json)
    #expect(throws: DSLError.self) {
      _ = try JSONActionSchema.build(value)
    }
  }

  @Test func malformedTrackThrows() throws {
    let json = """
    {
      "tracks": [
        {"length": 5}
      ],
      "connections": []
    }
    """
    let value = try JSONGameParser.parse(json)
    #expect(throws: DSLError.self) {
      _ = try JSONGraphBuilder.build(value)
    }
  }

  @Test func cyclicDefineThrows() throws {
    let json = """
    [
      {"name": "a", "params": [], "body": {"b": []}},
      {"name": "b", "params": [], "body": {"a": []}}
    ]
    """
    let value = try JSONGameParser.parse(json)
    #expect(throws: DSLError.self) {
      _ = try JSONDefineExpander(value)
    }
  }

  @Test func invalidJSONThrows() throws {
    let json = "this is not json {{"
    #expect(throws: (any Error).self) {
      _ = try JSONGameParser.parse(json)
    }
  }

  @Test func battleCardJSONCPlaythrough() throws {
    guard let url = Bundle.main.url(
      forResource: "BattleCard.game", withExtension: "jsonc"
    ) else {
      Issue.record("BattleCard.game.jsonc not found in bundle")
      return
    }
    let source = try String(contentsOf: url, encoding: .utf8)
    let game = try GameBuilder.build(fromJSONC: source)
    var state = game.newState()
    #expect(!game.isTerminal(state: state))
    #expect(state.phase == "setup")
    let actions = game.allowedActions(state: state)
    #expect(actions.count == 1)
    #expect(actions[0].name == "initialize")
    // Execute initialize and verify resulting state
    _ = game.reduce(into: &state, action: actions[0])
    #expect(state.phase == "airdrop")
    #expect(state.getCounter("turnNumber") == 1)
    // Verify pieces placed and strengths set
    #expect(state.getDict("allyStrength")["allied101st"] == .int(6))
    #expect(state.getDict("allyStrength")["allied82nd"] == .int(6))
    #expect(state.getDict("allyStrength")["allied1st"] == .int(5))
    #expect(state.getDict("germanStrength")["germanEindhoven"] == .int(2))
    // Random playthrough to exercise all reducers
    var turns = 0
    while !game.isTerminal(state: state) {
      let moves = game.allowedActions(state: state)
      guard !moves.isEmpty else { break }
      let move = moves[Int.random(in: 0..<moves.count)]
      _ = game.reduce(into: &state, action: move)
      turns += 1
      if turns > 500 { break }
    }
    #expect(game.isTerminal(state: state))
  }
}
