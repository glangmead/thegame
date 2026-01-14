import Foundation

protocol TextTableAble {
  func printTable<Target>(to: inout Target) where Target: TextOutputStream
}

final class LogDestination: TextOutputStream {
  private let path: String
  init(path: String) {
    self.path = path
  }
  
  func write(_ string: String) {
    if let data = string.data(using: .utf8), let fileHandle = FileHandle(forWritingAtPath: path) {
      defer {
        fileHandle.closeFile()
      }
      fileHandle.seekToEndOfFile()
      fileHandle.write(data)
    }
  }
}

public struct StandardOutput: TextOutputStream {
  public mutating func write(_ string: String) {
    print(string, terminator: "")
  }
  public init() {}
}
