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
}

precedencegroup LensApplyInput {
  associativity: left
}

precedencegroup ForwardPairApplication {
  associativity: left
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
}

func |> <A, B>(a: A, f: (A) -> B) -> B {
  return f(a)
}

func ||> <A, B, C>(ab: Pair<A, B>, f: (A, B) -> C) -> C {
  return f(ab.fst, ab.snd)
}

func => <A, C, D>(lens: Lens<A, A, C, D>, c: C) -> ((A) -> D) {
  return { a in
    lens.up(Pair(a, c)) |> lens.down
  }
}

func >>> <A, B, C>(
  f: @escaping (A) -> B, g: @escaping (B) -> C) -> ((A) -> C
  ) {
  return { a in
    g(f(a))
  }
}

struct Pair<A, B> {
  let fst: A
  let snd: B
  init(_ fst: A, _ snd: B) {
    self.fst = fst
    self.snd = snd
  }
}

// Lens (A / B) <-> (C / D)
struct Lens<A, B, C, D> {
  let down: (B) -> D         // downstream function, left to right
  let up: (Pair<B, C>) -> A  // upstream function, right to left
}

// Lens composition
func <=> <Am, Ap, Bm, Bp, Cm, Cp>(
  _ f: Lens<Am, Ap, Bm, Bp>,
  _ g: Lens<Bm, Bp, Cm, Cp>
) -> Lens<Am, Ap, Cm, Cp> {
  return Lens<Am, Ap, Cm, Cp> (
    down: f.down >>> g.down,
    up: { ap_cm in
      let ap = ap_cm.fst
      let cm = ap_cm.snd
      let bp_cm = Pair<Bp, Cm>(f.down(ap), cm)
      let bm = g.up(bp_cm)
      let ap_bm = Pair<Ap, Bm>(ap, bm)
      return f.up(ap_bm)
    }
  )
}

// Lens cartesian/monoidal product
func ⊗ <Am, Ap, Bm, Bp, Cm, Cp, Dm, Dp>(
  _ fab: Lens<Am, Ap, Bm, Bp>,
  _ gcd: Lens<Cm, Cp, Dm, Dp>
) -> Lens<Pair<Am, Cm>, Pair<Ap, Cp>, Pair<Bm, Dm>, Pair<Bp, Dp>> {
  return Lens<Pair<Am, Cm>, Pair<Ap, Cp>, Pair<Bm, Dm>, Pair<Bp, Dp>> (
    down: { ap_cp in
      return Pair<Bp, Dp>(fab.down(ap_cp.fst), gcd.down(ap_cp.snd))
    },
    up: { apcp_bmdm in
      return Pair<Am, Cm>(
        fab.up(Pair<Ap, Bm>(apcp_bmdm.fst.fst, apcp_bmdm.snd.fst)),
        gcd.up(Pair<Cp, Dm>(apcp_bmdm.fst.snd, apcp_bmdm.snd.snd))
      )
    }
  )
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
let clock = Lens<Hour, Hour, Void, Hour>(down: { $0 }, up: {hv in Hour.tick(hv.fst) })

// Meridiem lens
let meridiem = Lens<Meridiem, Meridiem, Hour, Meridiem>(down: { $0 }, up: { $0 ||> Meridiem.tick})

// meridiem-clock free product
let meridiem_clock_free = meridiem ⊗ clock

// meridiem-clock coupling
let meridiem_clock_coupling = Lens<Pair<Hour, Void>, Pair<Meridiem, Hour>, Void, Pair<Meridiem, Hour>>(
  down: { $0 },
  up: { mh_v in
    Pair<Hour, Void>(mh_v.fst.snd, ())
  }
)

let meridiem_clock = meridiem_clock_free <=> meridiem_clock_coupling

struct ContentView: View {
  @State private var time = Pair<Meridiem, Hour>(.am, .twelve)
  
  var body: some View {
    VStack {
      HStack {
        Text(time.snd.rawValue.description)
        Text(time.fst.rawValue.description)
      }
      Button("Tick") {
        time = (time |> (meridiem_clock => ()))
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

#Preview {
  ContentView()
}
