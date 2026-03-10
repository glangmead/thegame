//
//  TextTableAble.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 3/9/26.
//

import Foundation

protocol TextTableAble {
  func printTable<Target>(to output: inout Target) where Target: TextOutputStream
}

public struct StandardOutput: TextOutputStream {
  public mutating func write(_ string: String) {
    print(string, terminator: "")
  }
  public init() {}
}
