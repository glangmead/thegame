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

func pairs<T>(of list: Array<T>) -> [Pair<T>] {
  var pairs = [Pair<T>]()
  let len = list.count
  for left in 0..<len {
    for right in left+1..<len {
      pairs.append(Pair<T>(fst: list[left], snd: list[right]))
    }
  }
  return pairs
}

