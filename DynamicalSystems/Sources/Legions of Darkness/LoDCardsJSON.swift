// swiftlint:disable file_length
//
//  LoDCardsJSON.swift
//  DynamicalSystems
//
//  Legions of Darkness — Card JSON data (split from LoDCards for file_length).
//

import Foundation

extension LoDComponents {

  // swiftlint:disable line_length
  static let cardJSON = """
  {
    "cards": [
      {
        "number": 1,
        "file": "Day1.jpg",
        "title": "Heads up!",
        "deck": "day",
        "advances": ["west", "east"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Catapult",
          "text": "Roll. 1: lose 1 Archer. 2-3: lose 1 Swordsman."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 2,
        "file": "Day2.jpg",
        "title": "Still coming",
        "deck": "day",
        "advances": ["gate", "gate", "west", "east"],
        "actions": 4,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "gate", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Ancient Parchment",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >7. Choose a face-down spell and learn it.",
          "target": 7,
          "reward": "Choose a face-down spell and learn it"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 3,
        "file": "Day3.jpg",
        "title": "A pause",
        "deck": "day",
        "advances": [],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [{"action": "rally", "value": 1}],
        "event": null,
        "quest": {
          "title": "Estel",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >6. Time marker +1.",
          "target": 6,
          "reward": "Time marker +1"
        },
        "time": 1,
        "bloodyBattle": "gate"
      },
      {
        "number": 4,
        "file": "Day4.jpg",
        "title": "The Sky!",
        "deck": "day",
        "advances": ["sky", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "sky", "value": 1}],
        "heroicDRMs": [{"action": "rally", "value": -1}],
        "event": {
          "title": "Casualties",
          "text": "Roll. 1: lose 1 Priest. 2-3: lose 1 Swordsman."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 5,
        "file": "Day5.jpg",
        "title": "Muscle",
        "deck": "day",
        "advances": ["east", "gate"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "melee", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Mystic Consultation",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >6. +1 arcane, +1 divine.",
          "target": 6,
          "reward": "+1 arcane, +1 divine"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 6,
        "file": "Day6.jpg",
        "title": "Over here!",
        "deck": "day",
        "advances": ["west", "gate"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "A Storied Weapon",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >6. Gain Magic Bow.",
          "target": 6,
          "reward": "Gain Magic Bow: +2 DRM before ranged attack, +1 DRM after"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 7,
        "file": "Day7.jpg",
        "title": "Double time",
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
        "title": "Look to the East",
        "deck": "day",
        "advances": ["east", "east", "gate"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "west", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Sacrifice",
          "text": "You may wound all unwounded Heroes. If at least one wounded: +1 Attack DRM this turn."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 9,
        "file": "Day9.jpg",
        "title": "Look to the West",
        "deck": "day",
        "advances": ["west", "west", "gate"],
        "actions": 4,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "track": "east", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Sneak Advance",
          "text": "If East army out of melee range, advance East 1."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 10,
        "file": "Day10.jpg",
        "title": "Surrounded",
        "deck": "day",
        "advances": ["east", "west", "gate", "sky"],
        "actions": 3,
        "heroics": 3,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "To Me!",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >6. +1 defender (your choice).",
          "target": 6,
          "reward": "+1 defender (your choice)"
        },
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 11,
        "file": "Day11.jpg",
        "title": "Up!",
        "deck": "day",
        "advances": ["sky", "sky"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Something Gives Haste",
          "text": "Advance farthest army 1. If tied, choose one."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": "west"
      },
      {
        "number": 12,
        "file": "Day12.jpg",
        "title": "Smite",
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
        "title": "Wan hope",
        "deck": "day",
        "advances": ["east", "sky", "sky"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Amdir",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >7. Time marker +1.",
          "target": 7,
          "reward": "Time marker +1"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 14,
        "file": "Day14.jpg",
        "title": "Breached",
        "deck": "day",
        "advances": ["west", "sky", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Squeezed",
          "text": "Advance closest of East/West 1. If tied, advance both 1."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 15,
        "file": "Day15.jpg",
        "title": "Prayer",
        "deck": "day",
        "advances": ["gate", "gate"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "build", "value": 1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Now or Never",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >6. Add 1 unselected Hero to Reserves. If not attempted or failed: Morale -1.",
          "target": 6,
          "reward": "Add 1 unselected Hero to Reserves",
          "penalty": "Morale -1"
        },
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 16,
        "file": "Day16.jpg",
        "title": "Machines",
        "deck": "day",
        "advances": ["east", "gate", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "ranged", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Something Wicked",
          "text": "Roll. 1-3: Morale -1. 4-6: no melee this turn."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 17,
        "file": "Day17.jpg",
        "title": "Winged Riders",
        "deck": "day",
        "advances": ["west", "gate", "sky"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "ranged", "value": 1}],
        "heroicDRMs": [],
        "event": {
          "title": "He Fell",
          "text": "Roll. 1: lose 1 Priest. 2-3: lose 1 Archer."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 18,
        "file": "Day18.jpg",
        "title": "Advance Party",
        "deck": "day",
        "advances": ["gate"],
        "actions": 4,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "He has Fallen",
          "text": "Roll. 1-2: lose 1 Swordsman. 3-4: lose 1 Archer and 1 Priest."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 19,
        "file": "Day19.jpg",
        "title": "Advance Party",
        "deck": "day",
        "advances": ["east"],
        "actions": 4,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "The Blade that was Broken",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >6. Gain Magic Sword.",
          "target": 6,
          "reward": "Gain Magic Sword: +2 DRM before melee attack, +1 DRM after"
        },
        "time": 0,
        "bloodyBattle": "sky"
      },
      {
        "number": 20,
        "file": "Day20.jpg",
        "title": "Advance Party",
        "deck": "day",
        "advances": ["west"],
        "actions": 4,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Closing In",
          "text": "If West army out of melee range, advance West 1."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 21,
        "file": "Night1.jpg",
        "title": "Bad dreams",
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
        "title": "Fear",
        "deck": "night",
        "advances": ["terror", "gate"],
        "actions": 2,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "terror", "value": -1}],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "Hurrah!",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >7. Retreat 1 army (not Sky) 2 spaces.",
          "target": 7,
          "reward": "Retreat 1 army (not Sky) 2 spaces"
        },
        "time": 0,
        "bloodyBattle": "sky"
      },
      {
        "number": 23,
        "file": "Night3.jpg",
        "title": "Starlight",
        "deck": "night",
        "advances": ["terror", "east"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Castle Panic",
          "text": "If both Gate armies out of melee range, advance both 1. Otherwise advance whichever Gate army is out of melee range 1."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 24,
        "file": "Night4.jpg",
        "title": "Lamplight",
        "deck": "night",
        "advances": ["west", "terror"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Hail the Victorious Dead",
          "text": "Roll. 1-3: kill a Hero (wounded first). 4-6: wound a Hero (your choice)."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 25,
        "file": "Night5.jpg",
        "title": "Black webbing",
        "deck": "night",
        "advances": ["sky", "terror", "sky"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": null,
        "quest": {
          "title": "The Red Flicker",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >6. +2 arcane.",
          "target": 6,
          "reward": "+2 arcane"
        },
        "time": 0,
        "bloodyBattle": "west"
      },
      {
        "number": 26,
        "file": "Night6.jpg",
        "title": "The Tireless Enemy",
        "deck": "night",
        "advances": ["terror", "gate"],
        "actions": 1,
        "heroics": 3,
        "actionDRMs": [{"action": "attack", "value": 1}],
        "heroicDRMs": [],
        "event": {
          "title": "The Gathering",
          "text": "Return all living Heroes to Reserves. Wounded Heroes cannot act this turn."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 27,
        "file": "Night7.jpg",
        "title": "Utter Dark",
        "deck": "night",
        "advances": ["terror", "terror"],
        "actions": 2,
        "heroics": 2,
        "actionDRMs": [{"action": "ranged", "value": -1}],
        "heroicDRMs": [{"action": "rally", "value": -1}],
        "event": {
          "title": "The Blue Flicker",
          "text": "Roll. 1-3: +1 arcane. 4-6: +2 arcane."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 28,
        "file": "Night8.jpg",
        "title": "Cut off",
        "deck": "night",
        "advances": ["terror"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [{"action": "attack", "value": -1}],
        "event": null,
        "quest": {
          "title": "The Seeing Stone",
          "text": "Spend actions (+1 DRM) or heroics (+2 DRM). Roll >7. Reveal top 3 Day cards, discard 1.",
          "target": 7,
          "reward": "Reveal top 3 Day cards, discard 1"
        },
        "time": 0,
        "bloodyBattle": "east"
      },
      {
        "number": 29,
        "file": "Night9.jpg",
        "title": "Attack by Dark",
        "deck": "night",
        "advances": ["gate", "gate"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "melee", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Take Him Down!",
          "text": "Roll N. Advance farthest army N spaces. If tied, choose army. Wound Heroes or lose defenders to reduce N by 1 each."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 30,
        "file": "Night10.jpg",
        "title": "Turned Around",
        "deck": "night",
        "advances": ["east", "east"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "chant", "value": 1}],
        "heroicDRMs": [],
        "event": {
          "title": "Black and White",
          "text": "Roll. 1-3: kill a Hero (your choice). 4-6: +1 Attack DRM this turn."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 31,
        "file": "Night11.jpg",
        "title": "Lunar Apparation",
        "deck": "night",
        "advances": ["west", "west"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "chant", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Unholy Bargain",
          "text": "-1 divine, +1 arcane. Lose 1 Priest."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": "gate"
      },
      {
        "number": 32,
        "file": "Night12.jpg",
        "title": "Lunar Shapeshifting",
        "deck": "night",
        "advances": ["east", "gate", "terror"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Light of the Stars",
          "text": "Roll. 1-3: +1 arcane. 4-6: +2 arcane."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 33,
        "file": "Night13.jpg",
        "title": "Colored Lights",
        "deck": "night",
        "advances": ["east", "west"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [{"action": "build", "value": 1}],
        "heroicDRMs": [{"action": "rally", "value": -1}],
        "event": {
          "title": "It Broke Them",
          "text": "Lose 2 defenders OR Morale -1 (cannot choose Morale if Low)."
        },
        "quest": null,
        "time": 1,
        "bloodyBattle": null
      },
      {
        "number": 34,
        "file": "Night14.jpg",
        "title": "The Music of the Night",
        "deck": "night",
        "advances": ["gate", "west", "terror"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Handwriting",
          "text": "Roll. 1-3: -1 arcane. 4-6: +1 arcane."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 35,
        "file": "Night15.jpg",
        "title": "Vampires!",
        "deck": "night",
        "advances": ["gate", "sky", "terror"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "chant", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Turn Back the Page",
          "text": "Return all cast spells to pool. Roll. 1-3: -1 arcane. 4-6: draw 1 random arcane spell."
        },
        "quest": null,
        "time": 0,
        "bloodyBattle": null
      },
      {
        "number": 36,
        "file": "Night16.jpg",
        "title": "Fanged Flyers",
        "deck": "night",
        "advances": ["east", "west", "sky"],
        "actions": 2,
        "heroics": 2,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Even Closer",
          "text": "Advance Sky 1 OR advance other armies total 2 spaces."
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
