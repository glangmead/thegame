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

