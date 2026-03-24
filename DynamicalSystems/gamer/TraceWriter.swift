import Foundation

/// Contextual metadata for a single game step passed to `writeStep`.
struct StepInfo {
  let step: Int
  let phase: String
  let ended: Bool
  let victory: Bool
  let gameAcknowledged: Bool
  let offeredActions: [String]
  let chosenAction: String
  let isAuto: Bool
  let logs: [String]
}

final class TraceWriter {
  private let fileHandle: FileHandle
  private let gameName: String
  private let mctsIters: Int

  /// Property names to skip in diff/dump output.
  private let skipProperties: Set<String> = [
    "history", "pieceTypes", "schema"
  ]

  private var stepCount = 0

  init(
    directory: String, gameName: String,
    trialIndex: Int, mctsIters: Int
  ) throws {
    let fileManager = FileManager.default
    try fileManager.createDirectory(
      atPath: directory, withIntermediateDirectories: true
    )
    let timestamp = ISO8601DateFormatter().string(from: Date())
      .replacingOccurrences(of: ":", with: "-")
    let filename = "trace_\(gameName)_\(timestamp)_\(trialIndex).txt"
    let filePath = (directory as NSString)
      .appendingPathComponent(filename)
    fileManager.createFile(atPath: filePath, contents: nil)
    guard let handle = FileHandle(forWritingAtPath: filePath) else {
      throw CocoaError(.fileNoSuchFile)
    }
    fileHandle = handle
    self.gameName = gameName
    self.mctsIters = mctsIters
  }

  func writeHeader() {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    writeLine(
      "=== Game: \(gameName) | MCTS: \(mctsIters) iters"
      + " | \(timestamp) ==="
    )
    writeLine("")
  }

  func writeStep0(_ state: InterpretedState) {
    let dump = mirrorDump(state)
    let filtered = filterLines(dump)
    writeLine(
      "[Step 0] phase=\(state.phase)"
      + " ended=\(state.ended)"
      + " victory=\(state.victory)"
      + " gameAcknowledged=\(state.gameAcknowledged)"
    )
    writeLine("  STATE:")
    for line in filtered.split(separator: "\n") {
      writeLine("    \(line)")
    }
    writeLine("")
  }

  func writeStep<T>(info: StepInfo, before: T, after: T) {
    stepCount = info.step
    var header = "[Step \(info.step)] phase=\(info.phase)"
    if info.ended { header += " ended=true" }
    if info.victory { header += " victory=true" }
    if info.gameAcknowledged { header += " gameAcknowledged=true" }
    writeLine(header)
    writeLine(
      "  OFFERED: \(info.offeredActions.joined(separator: ", "))"
    )
    let autoTag = info.isAuto ? " [auto]" : ""
    writeLine("  CHOSEN: \(info.chosenAction)\(autoTag)")

    let diffs = mirrorDiff(before, after)
    let filteredDiffs = diffs.filter { line in
      !skipProperties.contains(where: { line.hasPrefix($0) })
    }
    if !filteredDiffs.isEmpty {
      writeLine("  CHANGED:")
      for diff in filteredDiffs {
        writeLine("    \(diff)")
      }
    }

    if !info.logs.isEmpty {
      writeLine("  LOGS:")
      for log in info.logs {
        writeLine("    \"\(log)\"")
      }
    }
    writeLine("")
    flush()
  }

  func writeResult(_ result: String) {
    writeLine("=== Result: \(result) at step \(stepCount) ===")
    flush()
  }

  func close() {
    fileHandle.closeFile()
  }

  private func writeLine(_ text: String) {
    fileHandle.write(Data("\(text)\n".utf8))
  }

  private func flush() {
    fileHandle.synchronizeFile()
  }

  private func filterLines(_ dump: String) -> String {
    dump.split(separator: "\n")
      .filter { line in
        !skipProperties.contains(where: {
          line.hasPrefix($0) || line.hasPrefix("  \($0)")
        })
      }
      .joined(separator: "\n")
  }
}
