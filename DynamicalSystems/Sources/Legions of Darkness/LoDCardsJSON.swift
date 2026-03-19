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
          "text": "Roll. 1: lose one Archer. 2-3: lose one Swordsman."
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
        "title": "The Sky!",
        "deck": "day",
        "advances": ["sky", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "track": "sky", "value": 1}],
        "heroicDRMs": [{"action": "rally", "value": -1}],
        "event": {
          "title": "Casualties",
          "text": "Roll. On a 1, lose one Priest. On a 2-3, lose one Swordsman."
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
          "text": "You may wound all unwounded Heroes. If you wound at least one hero, add a +1 drm to all Attacks and Heroic Attacks until the end of this turn."
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
          "text": "If the Army in the East is out of melee range, advance the Army in the East one space."
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
        "title": "Up!",
        "deck": "day",
        "advances": ["sky", "sky"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Something Gives Haste",
          "text": "Advance the farthest Army one space. If two or more armies are tied, choose one to advance."
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
        "title": "Breached",
        "deck": "day",
        "advances": ["west", "sky", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Squeezed",
          "text": "Advance the closest of the East or West armies one space. If tied, advance both one space."
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
        "title": "Machines",
        "deck": "day",
        "advances": ["east", "gate", "sky"],
        "actions": 3,
        "heroics": 2,
        "actionDRMs": [{"action": "ranged", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Something Wicked",
          "text": "Roll. On a 1-3, reduce Morale by one. On a 4-6, no melee attacks this turn."
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
          "text": "Roll. On a 1, lose one Priest. On a 2-3, lose one Archer."
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
          "text": "Roll. On a 1-2, lose one Swordsman. On a 3-4, lose one Archer and one Priest."
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
        "title": "Advance Party",
        "deck": "day",
        "advances": ["west"],
        "actions": 4,
        "heroics": 2,
        "actionDRMs": [{"action": "attack", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Closing In",
          "text": "If the Army in the West is out of melee range, advance the Army in the West one space."
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
        "title": "Starlight",
        "deck": "night",
        "advances": ["terror", "east"],
        "actions": 2,
        "heroics": 1,
        "actionDRMs": [],
        "heroicDRMs": [],
        "event": {
          "title": "Castle Panic",
          "text": "If either of the Armies at the Gate are out of melee range, advance the farthest Army at the Gate one space. If both Armies at the Gate are out of melee range, advance both Armies at the Gate one space."
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
          "text": "Roll. On a 1-3, kill a Hero (wounded first). On a 4-6, wound a Hero (your choice)."
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
        "title": "The Tireless Enemy",
        "deck": "night",
        "advances": ["terror", "gate"],
        "actions": 1,
        "heroics": 3,
        "actionDRMs": [{"action": "attack", "value": 1}],
        "heroicDRMs": [],
        "event": {
          "title": "The Gathering",
          "text": "Return all living Heroes to the Reserves. Wounded Heroes cannot act this turn."
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
          "text": "Roll. On a 1-3, add +1 arcane magic. On a 4-6, add +2 arcane magic."
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
        "title": "Attack by Dark",
        "deck": "night",
        "advances": ["gate", "gate"],
        "actions": 3,
        "heroics": 1,
        "actionDRMs": [{"action": "melee", "value": -1}],
        "heroicDRMs": [],
        "event": {
          "title": "Take Him Down!",
          "text": "Roll. Advance the farthest Army that number of spaces. Reduce the result by one for each Hero you wound or defender you choose to lose."
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
          "text": "Roll. On a 1-3, kill a Hero of your choice. On a 4-6, add a +1 drm to Attack this turn."
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
          "text": "Subtract 1 divine magic and add +1 arcane magic. Lose one priest."
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
          "text": "Roll. On a 1-3, add +1 arcane magic. On a 4-6, add +2 arcane magic."
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
          "text": "Lose two defenders OR reduce Morale by one (can't choose Morale if Morale is Low)."
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
          "text": "Roll. On a 1-3, subtract 1 arcane magic. On a 4-6, add +1 arcane magic."
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
          "text": "Return all used spells to the appropriate spell draw pool. Roll: On a 1-3, subtract 1 arcane magic. On a 4-6, draw a random arcane spell."
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
