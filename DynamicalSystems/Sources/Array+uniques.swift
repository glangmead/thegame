//
//  Array+uniques.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 10/21/25.
//

import Foundation

extension Array {
  static func uniques<T: Equatable>(_ input: Array<T>) -> Array<T> {
    var result = Array<T>()
    for val in input {
      if !result.contains(val) {
        result.append(val)
      }
    }
    return result
  }
}

extension Array where Element: Hashable {
  func intersection(_ other: Array) -> Set<Element> {
    return Set(self).intersection(Set(other))
  }
}

extension Array {
  func anySatisfy(_ predicate: (Self.Element) -> Bool) -> Bool {
    return contains(where: predicate)
  }
}

extension Array {
  var isNonEmpty: Bool {
    !isEmpty
  }
}

