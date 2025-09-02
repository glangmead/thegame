//
//  ContentView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 8/30/25.
//

//import ComposableArchitecture
import SwiftUI

infix operator |>: ForwardApplication
infix operator =>: LensApplyInput
infix operator ||>: ForwardPairApplication
infix operator >>>: ForwardComposition
infix operator <=>: LensForwardComposition
infix operator ⊗: LensProduct

precedencegroup ForwardApplication {
  associativity: left
  higherThan: AssignmentPrecedence
}

precedencegroup LensApplyInput {
  associativity: left
  higherThan: AssignmentPrecedence
}

precedencegroup ForwardPairApplication {
  associativity: left
  higherThan: AssignmentPrecedence
}

precedencegroup ForwardComposition {
  associativity: left
  higherThan: ForwardApplication
}

precedencegroup LensForwardComposition {
  associativity: left
  higherThan: ForwardApplication
}

precedencegroup LensProduct {
  associativity: left
  higherThan: AssignmentPrecedence
}

func |> <A, B>(a: A, f: (A) -> B) -> B {
  return f(a)
}

func ||> <A, B, C>(ab: (A, B), f: (A, B) -> C) -> C {
  return f(ab.0, ab.1)
}

// Apply a lens of the form AACD to an input value c:C to get out a function A -> D
func => <A, C, D>(lens: Lens<A, A, C, D>, c: C) -> ((A) -> D) {
  return { a in
    lens.up((a, c)) |> lens.down
  }
}

func >>> <A, B, C>(
  f: @escaping (A) -> B, g: @escaping (B) -> C) -> ((A) -> C
  ) {
  return { a in
    g(f(a))
  }
}

//struct Pair<A, B> {
//  let fst: A
//  let snd: B
//  init(_ fst: A, _ snd: B) {
//    self.fst = fst
//    self.snd = snd
//  }
//}

// Lens (A / B) <-> (C / D)
struct Lens<A, B, C, D> {
  let down: (B) -> D         // downstream function, left to right
  let up: ((B, C)) -> A  // upstream function, right to left
}

typealias StateLens<A, C, D> = Lens<A, A, C, D>

// Lens composition
func <=> <Am, Ap, Bm, Bp, Cm, Cp>(
  _ f: Lens<Am, Ap, Bm, Bp>,
  _ g: Lens<Bm, Bp, Cm, Cp>
) -> Lens<Am, Ap, Cm, Cp> {
  return Lens<Am, Ap, Cm, Cp> (
    down: f.down >>> g.down,
    up: { ap_cm in
      let ap = ap_cm.0
      let cm = ap_cm.1
      let bp_cm = (f.down(ap), cm)
      let bm = g.up(bp_cm)
      let ap_bm = (ap, bm)
      return f.up(ap_bm)
    }
  )
}

// Lens cartesian/monoidal product
func ⊗ <Am, Ap, Bm, Bp, Cm, Cp, Dm, Dp>(
  _ fab: Lens<Am, Ap, Bm, Bp>,
  _ gcd: Lens<Cm, Cp, Dm, Dp>
) -> Lens<(Am, Cm), (Ap, Cp), (Bm, Dm), (Bp, Dp)> {
  return Lens<(Am, Cm), (Ap, Cp), (Bm, Dm), (Bp, Dp)> (
    down: { ap_cp in
      return (fab.down(ap_cp.0), gcd.down(ap_cp.1))
    },
    up: { apcp_bmdm in
      return (
        fab.up((apcp_bmdm.0.0, apcp_bmdm.1.0)),
        gcd.up((apcp_bmdm.0.1, apcp_bmdm.1.1))
      )
    }
  )
}

// Tic Tac Toe
enum TTTPlayer {
  case x, o
}

enum TTTMark: Character, Identifiable {
  case none = "⬜️"
  case x = "x"
  case o = "o"
  var id: Self { self }
}

struct TTTState {
  var board: [[TTTMark]] = [[.none, .none, .none],[.none, .none, .none],[.none, .none, .none]]
  var lastMark: TTTMark = .none // the player who put the most recent mark shown on the board
  
  var winner: TTTPlayer? {
    if lastMark == .none { return nil }
    return nil // TODO: look for three in a row of lastMark
  }
}

struct TicTacToeView: View {
  @State private var state = TTTState()
  var body: some View {
    VStack {
      HStack {
        ForEach(state.board[0]) {mark in
          spaceView(mark)
        }
      }
      HStack {
        ForEach(state.board[1]) {mark in
          spaceView(mark)
        }
      }
      HStack {
        ForEach(state.board[2]) {mark in
          spaceView(mark)
        }
      }
    }
  }
  
  @ViewBuilder func spaceView(_ mark: TTTMark) -> some View {
    switch mark {
    case .none:
      Button("–") { }
      .font(.largeTitle)
    default:
      Text("\(mark.rawValue) ").font(.largeTitle)
    }
  }
  
}


// Clock example from DJM's book

enum Hour: Int {
  case one = 1, two, three, four, five, six, seven, eight, nine, ten, eleven, twelve
  static func tick(_ h: Hour) -> Hour {
    switch h {
    case .twelve:
      return .one
    default:
      return Hour(rawValue: h.rawValue + 1)!
    }
  }
}

enum Meridiem: String {
  case am, pm
  func toggle() -> Self {
    switch self {
    case .am:
      return .pm
    case .pm:
      return .am
    }
  }
  static func tick(merid: Meridiem, hour: Hour) -> Meridiem {
    switch hour {
    case .eleven:
      return merid.toggle()
    default:
      return merid
    }
  }
}

// Clock lens: clock state is just the Hour enum, no need to wrap in a Clock struct
let clock = StateLens<Hour, Void, Hour>(down: { $0 }, up: {hv in Hour.tick(hv.0) })

// Meridiem lens
let meridiem = StateLens<Meridiem, Hour, Meridiem>(down: { $0 }, up: { $0 ||> Meridiem.tick})

// meridiem-clock free product
let meridiem_clock_free = meridiem ⊗ clock

// meridiem-clock coupling
// TODO: could this be generic, with the types chosen later by the ev_C functor from DJM's book (Example 1.3.3.17)?
let meridiem_clock_coupling = Lens<
  (Hour, Void),
  (Meridiem, Hour),
  Void,
  (Meridiem, Hour)
>(
  down: { $0 },
  up: { mh_v in
    (mh_v.0.1, ())
  }
)

let meridiem_clock = meridiem_clock_free <=> meridiem_clock_coupling

struct MeridiemClockView: View {
  @State private var time: (Meridiem, Hour) = (.am, .eleven)
  
  var body: some View {
    VStack {
      HStack {
        Text(time.1.rawValue.description)
        Text(time.0.rawValue.description)
      }
      Button("Tick") {
        time = time |> (meridiem_clock => ())
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

#Preview("Meridiem Clock") {
  MeridiemClockView()
}

#Preview("Tic Tac Toe") {
  TicTacToeView()
}
