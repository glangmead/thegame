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

func |> <A, B>(value: A, transform: (A) -> B) -> B {
  return transform(value)
}

func ||> <A, B, C>(pair: (A, B), transform: (A, B) -> C) -> C {
  return transform(pair.0, pair.1)
}

// Apply a lens of the form AACD to an input value c:C to get out a function A -> D
func => <A, C, D>(lens: Lens<A, A, C, D>, input: C) -> ((A) -> D) {
  return { state in
    lens.update((state, input)) |> lens.down
  }
}

func >>> <A, B, C>(
  lhs: @escaping (A) -> B, rhs: @escaping (B) -> C) -> ((A) -> C
  ) {
  return { value in
    rhs(lhs(value))
  }
}

// struct Pair<A, B> {
//  let fst: A
//  let snd: B
//  init(_ fst: A, _ snd: B) {
//    self.fst = fst
//    self.snd = snd
//  }
// }

// Lens (A / B) <-> (C / D)
struct Lens<A, B, C, D> {
  let down: (B) -> D         // downstream function, left to right
  let update: ((B, C)) -> A  // upstream function, right to left
}

typealias StateLens<A, C, D> = Lens<A, A, C, D>
typealias OptionalStateLens<A, C, D> = Lens<A?, A, C, D>
typealias PossibleStateLens<A, C, D> = Lens<[A], A, C, D>

// Lens composition
func <=> <Am, Ap, Bm, Bp, Cm, Cp>(
  _ lhs: Lens<Am, Ap, Bm, Bp>,
  _ rhs: Lens<Bm, Bp, Cm, Cp>
) -> Lens<Am, Ap, Cm, Cp> {
  return Lens<Am, Ap, Cm, Cp>(
    down: lhs.down >>> rhs.down,
    update: { aPartCMap in
      let apVal = aPartCMap.0
      let cmVal = aPartCMap.1
      let bPartCMap = (lhs.down(apVal), cmVal)
      let bmVal = rhs.update(bPartCMap)
      let aPartBMap = (apVal, bmVal)
      return lhs.update(aPartBMap)
    }
  )
}

// Lens cartesian/monoidal product
// swiftlint:disable:next identifier_name
func ⊗ <Am, Ap, Bm, Bp, Cm, Cp, Dm, Dp>(
  _ fab: Lens<Am, Ap, Bm, Bp>,
  _ gcd: Lens<Cm, Cp, Dm, Dp>
) -> Lens<(Am, Cm), (Ap, Cp), (Bm, Dm), (Bp, Dp)> {
  return Lens<(Am, Cm), (Ap, Cp), (Bm, Dm), (Bp, Dp)>(
    down: { aPartCPart in
      return (fab.down(aPartCPart.0), gcd.down(aPartCPart.1))
    },
    update: { acPartBDMap in
      return (
        fab.update((acPartBDMap.0.0, acPartBDMap.1.0)),
        gcd.update((acPartBDMap.0.1, acPartBDMap.1.1))
      )
    }
  )
}
