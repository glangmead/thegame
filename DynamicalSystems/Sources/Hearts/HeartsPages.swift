//
//  HeartsPages.swift
//  DynamicalSystems
//
//  Hearts — RulePages: passing, playing, trick resolution, hand scoring, game end.
//

import Foundation

extension Hearts {

  // MARK: - Passing Page

  static var passingPage: RulePage<State, Action> {
    RulePage(
      name: "Passing",
      rules: [
        // Select cards to pass (0-2 selected so far)
        GameRule(
          condition: { state in
            state.phase == .passing
              && state.passingState != nil
              && (state.passingState?.selected.count ?? 0) < 3
          },
          actions: { state in
            guard let hand = state.hands[state.player],
                  let passing = state.passingState else { return [] }
            return hand
              .filter { !passing.selected.contains($0) }
              .map { .selectPassCard($0) }
          }
        ),
        // Confirm pass (3 selected)
        GameRule(
          condition: { state in
            state.phase == .passing
              && state.passingState?.selected.count == 3
          },
          actions: { _ in [.confirmPass(aiPasses: [:])] }
        )
      ],
      reduce: { state, action in
        switch action {
        case .selectPassCard(let card):
          guard state.passingState != nil else { return nil }
          state.passingState?.selected.append(card)
          return ([Log(msg: "Selected \(card) to pass")], [])

        case .confirmPass(let aiPasses):
          guard let passing = state.passingState else { return nil }
          let humanCards = passing.selected
          state.executePasses(humanCards: humanCards, aiPasses: aiPasses)
          return ([Log(msg: "Cards passed \(passing.direction)")], [])

        default:
          return nil
        }
      }
    )
  }

  // MARK: - Single Play Page

  static var singlePlayPage: RulePage<State, Action> {
    RulePage(
      name: "Play",
      rules: [
        GameRule(
          condition: { $0.phase == .playing && $0.currentTrick.count < 4 },
          actions: { state in
            state.legalPlays.map { .playCard($0) }
          }
        )
      ],
      reduce: { state, action in
        guard case .playCard(let card) = action else { return nil }
        guard state.hands[state.player]?.contains(card) == true else { return nil }

        state.hands[state.player]?.removeAll(where: { $0 == card })
        state.currentTrick.append(TrickPlay(seat: state.player, card: card))
        state.syncPositions()

        var logs = [Log(msg: "\(state.player) plays \(card)")]

        if state.currentTrick.count == 4 {
          // Trick complete — pause for the view to show all 4 cards
          state.phase = .trickResolution
          return (logs, [])
        } else {
          // Advance to next player clockwise
          state.player = state.player.next
          return (logs, [])
        }
      }
    )
  }

  // MARK: - Trick Resolution Page

  static var trickPage: RulePage<State, Action> {
    RulePage(
      name: "Trick",
      rules: [
        GameRule(
          condition: { $0.phase == .trickResolution },
          actions: { _ in [.resolveTrick] }
        )
      ],
      reduce: { state, action in
        guard case .resolveTrick = action else { return nil }

        let winner = state.trickWinner!
        let trickNum = state.turnNumber
        let trickStr = state.currentTrick
          .map { "\($0.card)" }
          .joined(separator: " ")
        let wasBroken = state.heartsBroken

        state.resolveTrick()

        var logs = [Log(msg: "\(winner) wins trick \(trickNum): \(trickStr)")]
        if !wasBroken && state.heartsBroken {
          logs.append(Log(msg: "Hearts broken!"))
        }

        // After trick 13, cascade to scoring
        if state.turnNumber > 13 {
          state.phase = .handEnd
          return (logs, [.scoreHand])
        }

        // Otherwise back to playing — winner leads
        state.phase = .playing
        return (logs, [])
      }
    )
  }

  // MARK: - Hand Scoring Page

  static var handPage: RulePage<State, Action> {
    RulePage(
      name: "Hand",
      rules: [
        // Offer startNewHand when hand scored but game not ended
        GameRule(
          condition: { $0.phase == .handEnd && !$0.ended },
          actions: { _ in [.startNewHand(shuffledDeck: [])] }
        )
      ],
      reduce: { state, action in
        switch action {
        case .scoreHand:
          state.scoreCurrentHand()

          var logs: [Log] = []
          for seat in Seat.allCases {
            let penalty = state.handPenalties[seat] ?? 0
            let cumulative = state.cumulativeScores[seat] ?? 0
            logs.append(Log(msg: "\(seat): \(penalty) this hand (\(cumulative) total)"))
          }

          if let shooter = Seat.allCases.first(where: { state.isShootingTheMoon(seat: $0) }) {
            logs.insert(Log(msg: "\(shooter) shot the moon!"), at: 0)
          }

          if state.ended {
            return (logs, [])
          }

          state.phase = .handEnd
          return (logs, [])

        case .startNewHand(let shuffledDeck):
          let deck = shuffledDeck.isEmpty ? Hearts.fullDeck.shuffled() : shuffledDeck
          state.startNewHand(shuffledDeck: deck)
          return ([Log(msg: "Hand \(state.handNumber + 1) dealt")], [])

        default:
          return nil
        }
      }
    )
  }

  // MARK: - Game End Page (priority)

  static var gameEndPage: RulePage<State, Action> {
    RulePage(
      name: "Game End",
      rules: [
        GameRule(
          condition: { $0.ended && !$0.gameAcknowledged },
          actions: { _ in [.declareWinner] }
        )
      ],
      reduce: { state, action in
        guard case .declareWinner = action else { return nil }
        state.gameAcknowledged = true
        let winners = state.endedInVictoryFor
          .map(\.description)
          .joined(separator: ", ")
        return ([Log(msg: "Game over! Winner(s): \(winners)")], [])
      }
    )
  }
}
