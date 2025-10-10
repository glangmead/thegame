//
//  Pair.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/9/25.
//

struct Pair<A> {
  let fst: A
  let snd: A
}

extension Pair: Equatable where A: Equatable {
  static func == (lhs: Pair<A>, rhs: Pair<A>) -> Bool {
    return lhs.fst == rhs.fst && lhs.snd == rhs.snd
  }
}

extension Pair: Hashable where A: Hashable {}

extension Pair {
  func map<B> (_ f: (A) -> B) -> Pair<B> {
    Pair<B>(fst: f(self.fst), snd: f(self.snd))
  }
}

