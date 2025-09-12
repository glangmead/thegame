//
//  Lens.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 9/5/25.
//

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
  let up: ((B, C)) -> A      // upstream function, right to left
}

typealias StateLens<A, C, D> = Lens<A, A, C, D>
typealias OptionalStateLens<A, C, D> = Lens<A?, A, C, D>
typealias PossibleStateLens<A, C, D> = Lens<[A], A, C, D>

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

