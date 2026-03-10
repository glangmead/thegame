//
//  LoDCards.swift
//  DynamicalSystems
//
//  Legions of Darkness — Card data (36 cards: 20 day, 16 night).
//  Data sourced from card images and verified by user.
//

import Foundation

extension LoDComponents {

  private struct CardContainer: Codable {
    let cards: [Card]
  }

  static let allCards: [Card] = {
    let data = cardJSON.data(using: .utf8)!
    return try! JSONDecoder().decode(CardContainer.self, from: data).cards
  }()

  static var dayCards: [Card] { allCards.filter { $0.deck == .day } }
  static var nightCards: [Card] { allCards.filter { $0.deck == .night } }

  // swiftlint:disable line_length
  private static let cardJSON = """
  {
    "cards": [
      {
        "number": 1,
        "file": "Day1.jpg",
        "title": "Over the Walls!",
        "deck": "day",
        "advances": ["west", "east"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Catapult Shrapnel",
          "text": "Roll a die. On a 1, lose one Archer. On a 2-3, lose one Men-at-Arms."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 2,
        "file": "Day2.jpg",
        "title": "The Horde Marches On",
        "deck": "day",
        "advances": ["gate", "gate", "west", "east"],
        "actions": 4,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "gate", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Scrolls of the Dead",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >7 to draw a spell of your choice, then shuffle the remaining spells of that type still in the pool.",
          "target": 7,
          "reward": "Draw a spell of your choice, shuffle remaining of that type"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 3,
        "file": "Day3.jpg",
        "title": "All is Quiet",
        "deck": "day",
        "advances": [],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [{"action": "rally", "value": 1}],
        "event": null,
        "quest": {
          "title": "Forlorn Hope",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >6 to advance the Time marker +1.",
          "target": 6,
          "reward": "Advance time marker +1"
        },
        "time": 1,
        "bloodyBattle": "gate"
      },
      {
        "number": 4,
        "file": "Day4.jpg",
        "title": "Death from Above",
        "deck": "day",
        "advances": ["sky", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "sky", "value": 1}],
        "heroicDRMs": [{"action": "rally", "value": -1}],
        "event": {
          "title": "Rocks of Ages",
          "text": "Roll a die. On a 1, lose one Priest. On a 2-3, lose one Men-at-Arms."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 5,
        "file": "Day5.jpg",
        "title": "By Sword and Axe",
        "deck": "day",
        "advances": ["east", "gate"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "melee", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Search for the Manastones",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >6 to add +1 arcane energy and +1 divine energy.",
          "target": 6,
          "reward": "+1 arcane energy, +1 divine energy"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 6,
        "file": "Day6.jpg",
        "title": "Snakes and Ladders",
        "deck": "day",
        "advances": ["west", "gate"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Arrows of the Dead",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >6 to find a Magic Bow.",
          "target": 6,
          "reward": "Magic Bow: Discard before a ranged attack to add +2 drm or after the attack to add +1 drm"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 7,
        "file": "Day7.jpg",
        "title": "Day of the Ram",
        "deck": "day",
        "advances": ["gate", "gate"],
        "actions": 4,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "track": "east", "value": -1}, {"action": "attack", "track": "west", "value": -1}, {"action": "attack", "track": "gate", "value": -1}, {"action": "attack", "track": "sky", "value": -1}],
        "heroicDRMs": [],
        "event": null,
        "quest": null,
        "time": 0,
        "bloodyBattle": "east"
      },
      {
        "number": 8,
        "file": "Day8.jpg",
        "title": "Eastern Assault",
        "deck": "day",
        "advances": ["east", "east", "gate"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "west", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Acts of Valor",
          "text": "You may wound all unwounded Heroes. If you wound at least one hero, add a +1 drm to all Attacks and Heroic Attacks until the end of this turn."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 9,
        "file": "Day9.jpg",
        "title": "Western Assault",
        "deck": "day",
        "advances": ["west", "west", "gate"],
        "actions": 4,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "track": "east", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Distracted Defenders",
          "text": "If the Army in the East is out of melee range, advance the Army in the East one space."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 10,
        "file": "Day10.jpg",
        "title": "General Assault",
        "deck": "day",
        "advances": ["east", "west", "gate", "sky"],
        "actions": 3,
        "heroics": 3,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Put Forth the Call",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >6 to add +1 defender.",
          "target": 6,
          "reward": "+1 defender"
        },
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 11,
        "file": "Day11.jpg",
        "title": "Watch the Skies!",
        "deck": "day",
        "advances": ["sky", "sky"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "The Harbingers of Doom",
          "text": "Advance the farthest Army one space. If two or more armies are tied, choose one to advance."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": "west"
      },
      {
        "number": 12,
        "file": "Day12.jpg",
        "title": "The Killing Stroke",
        "deck": "day",
        "advances": ["sky", "sky", "gate"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "value": 1}],
        "heroicDRMs": [{"action": "attack", "value": 1}],
        "event": null,
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 13,
        "file": "Day13.jpg",
        "title": "Exploit the Weak",
        "deck": "day",
        "advances": ["east", "sky", "sky"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Forlorn Hope",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >7 to advance the Time marker +1.",
          "target": 7,
          "reward": "Advance time marker +1"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 14,
        "file": "Day14.jpg",
        "title": "Cracks in the Wall",
        "deck": "day",
        "advances": ["west", "sky", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Broken Walls",
          "text": "Advance the closest of the East or West armies one space. If tied, advance both one space."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 15,
        "file": "Day15.jpg",
        "title": "Barricade and Pray",
        "deck": "day",
        "advances": ["gate", "gate"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "build", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Last Ditch Efforts",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >6 to add one unselected Hero to the Reserves. If this Quest is not attempted, or if it fails, reduce Morale by one.",
          "target": 6,
          "reward": "+1 unselected Hero to Reserves",
          "penalty": "Reduce Morale by one"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 16,
        "file": "Day16.jpg",
        "title": "Engines of War",
        "deck": "day",
        "advances": ["east", "gate", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "ranged", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Lamentation of the Women",
          "text": "Roll a die. On a 1-3, reduce Morale by one. On a 4-6, no melee attacks this turn."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 17,
        "file": "Day17.jpg",
        "title": "Riders in the Sky",
        "deck": "day",
        "advances": ["west", "gate", "sky"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "ranged", "value": 1}],
        "heroicDRMs": [],
        "event": {
          "title": "Reign of Arrows",
          "text": "Roll a die. On a 1, lose one Priest. On a 2-3, lose one Archer."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 18,
        "file": "Day18.jpg",
        "title": "Scouting Attack",
        "deck": "day",
        "advances": ["gate"],
        "actions": 4,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Trapped by Flames",
          "text": "Roll a die. On a 1-2, lose one Men-at-Arms. On a 3-4, lose one Archer and one Priest."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 19,
        "file": "Day19.jpg",
        "title": "Scouting Attack",
        "deck": "day",
        "advances": ["east"],
        "actions": 4,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "The Vorpal Blade",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >6 to take the Magic Sword.",
          "target": 6,
          "reward": "Magic Sword: Discard before a melee attack to add +2 drm or after the attack to add +1 drm"
        },
        "time": 0,
        "bloodyBattle": "sky"
      },
      {
        "number": 20,
        "file": "Day20.jpg",
        "title": "Scouting Attack",
        "deck": "day",
        "advances": ["west"],
        "actions": 4,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Banners in the Distance",
          "text": "If the Army in the West is out of melee range, advance the Army in the West one space."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 21,
        "file": "Night1.jpg",
        "title": "Nightmares",
        "deck": "night",
        "advances": ["east", "west", "sky", "terror", "gate"],
        "actions": 3,
        "heroics": 3,
        "actionDRMs": [{"action": "attack", "track": "terror", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": null,
        "time": 2,
        "bloodyBattle": null
      },
      {
        "number": 22,
        "file": "Night2.jpg",
        "title": "Terror in the Dark",
        "deck": "night",
        "advances": ["terror", "gate"],
        "actions": 2,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "terror", "value": -1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Pillars of the Earth",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >7 to retreat one army (except Sky) two spaces.",
          "target": 7,
          "reward": "Retreat one army (except Sky) two spaces"
        },
        "time": 0,
        "bloodyBattle": "sky"
      },
      {
        "number": 23,
        "file": "Night3.jpg",
        "title": "By Moonlight",
        "deck": "night",
        "advances": ["terror", "east"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Campfires in the Distance",
          "text": "If either of the Armies at the Gate are out of melee range, advance the farthest Army at the Gate one space. If both Armies at the Gate are out of melee range, advance both Armies at the Gate one space."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 24,
        "file": "Night4.jpg",
        "title": "By Torchlight",
        "deck": "night",
        "advances": ["west", "terror"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Bloody Handprints",
          "text": "Roll a die. On a 1-3, kill a Hero (wounded first). On a 4-6, wound a Hero (your choice)."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 25,
        "file": "Night5.jpg",
        "title": "Darkened Wings",
        "deck": "night",
        "advances": ["sky", "terror", "sky"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Save the Mirror of the Moon",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >6 to add +2 arcane magic.",
          "target": 6,
          "reward": "+2 arcane magic"
        },
        "time": 0,
        "bloodyBattle": "west"
      },
      {
        "number": 26,
        "file": "Night6.jpg",
        "title": "No Rest for the Wicked",
        "deck": "night",
        "advances": ["terror", "gate"],
        "actions": 1,
        "heroics": 3,
        "actionDRMs": [{"action": "attack", "value": 1}],
        "heroicDRMs": [],
        "event": {
          "title": "Council of Heroes",
          "text": "Return all living Heroes to the Reserves. Wounded Heroes cannot act this turn."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 27,
        "file": "Night7.jpg",
        "title": "Pitch Black",
        "deck": "night",
        "advances": ["terror", "terror"],
        "actions": 2,
        "heroics": 2,
        "actionDRMs": [{"action": "ranged", "value": -1}],
        "heroicDRMs": [{"action": "rally", "value": -1}],
        "event": {
          "title": "Midnight Magic",
          "text": "Roll a die. On a 1-3, add +1 arcane magic. On a 4-6, add +2 arcane magic."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 28,
        "file": "Night8.jpg",
        "title": "Alone in the Dark",
        "deck": "night",
        "advances": ["terror"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [{"action": "attack", "value": -1}],
        "event": null,
        "quest": {
          "title": "Prophecy Revealed",
          "text": "Spend actions (+1 drm) or heroics (+2 drm). Roll >7 to reveal the top three cards of the Day deck and discard one.",
          "target": 7,
          "reward": "Reveal top 3 Day cards, discard one"
        },
        "time": 0,
        "bloodyBattle": "east"
      },
      {
        "number": 29,
        "file": "Night9.jpg",
        "title": "Night Assault",
        "deck": "night",
        "advances": ["gate", "gate"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "melee", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Death and Despair",
          "text": "Roll a die. Advance the farthest Army that number of spaces. Reduce the result by one for each Hero you wound or defender you choose to lose."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 30,
        "file": "Night10.jpg",
        "title": "Eastern Sunset",
        "deck": "night",
        "advances": ["east", "east"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "chant", "value": 1}],
        "heroicDRMs": [],
        "event": {
          "title": "Assassin's Creedo",
          "text": "Roll a die. On a 1-3, kill a Hero of your choice. On a 4-6, add a +1 drm to Attack this turn."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 31,
        "file": "Night11.jpg",
        "title": "Western Moonrise",
        "deck": "night",
        "advances": ["west", "west"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "chant", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "In the Pale Moonlight",
          "text": "Subtract 1 divine magic and add +1 arcane magic. Lose one priest."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": "gate"
      },
      {
        "number": 32,
        "file": "Night12.jpg",
        "title": "As the Moon Turns",
        "deck": "night",
        "advances": ["east", "gate", "terror"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "By the Light of the Moon",
          "text": "Roll a die. On a 1-3, add +1 arcane magic. On a 4-6, add +2 arcane magic."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 33,
        "file": "Night13.jpg",
        "title": "Blue Candles",
        "deck": "night",
        "advances": ["east", "west"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "build", "value": 1}],
        "heroicDRMs": [{"action": "rally", "value": -1}],
        "event": {
          "title": "Deserters in the Dark",
          "text": "Lose two defenders OR reduce Morale by one (can't choose Morale if Morale is Low)."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 34,
        "file": "Night14.jpg",
        "title": "Master of Night",
        "deck": "night",
        "advances": ["gate", "west", "terror"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "The Waning Moon",
          "text": "Roll a die. On a 1-3, subtract 1 arcane magic. On a 4-6, add +1 arcane magic."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 35,
        "file": "Night15.jpg",
        "title": "The Witching Hour",
        "deck": "night",
        "advances": ["gate", "sky", "terror"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "chant", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Mystic Forces Reborn",
          "text": "Return all used spells to the appropriate spell draw pool. Roll a die: On a 1-3, subtract 1 arcane magic. On a 4-6, draw a random arcane spell."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 36,
        "file": "Night16.jpg",
        "title": "Wings of the Bat",
        "deck": "night",
        "advances": ["east", "west", "sky"],
        "actions": 2,
        "heroics": 2,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Bump in the Night",
          "text": "Advance the Sky army one space OR any other combination of armies two spaces."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      }
    ]
  }
  """
  // swiftlint:enable line_length
}
