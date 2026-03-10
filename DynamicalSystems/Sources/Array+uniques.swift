//
//  Array+uniques.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import Foundation

extension Array {
  public static func uniques<T: Equatable>(_ input: [T]) -> [T] {
    var result = [T]()
    for val in input where !result.contains(val) {
      result.append(val)
    }
    return result
  }
}

extension Array where Element: Hashable {
  public func intersection(_ other: Array) -> Set<Element> {
    return Set(self).intersection(Set(other))
  }

  public func minus(_ other: Array) -> Array {
    return self.filter { !other.contains($0) }
  }

}

extension Array {
  public func anySatisfy(_ predicate: (Self.Element) -> Bool) -> Bool {
    return contains(where: predicate)
  }
}

extension Array {
  public var isNonEmpty: Bool {
    !isEmpty
  }
}
