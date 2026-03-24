// swiftlint:disable cyclomatic_complexity function_body_length
/// Compare two values using Mirror reflection.
/// Returns a list of "path: oldValue -> newValue" strings for all
/// differences. Empty list means values are equal.
func mirrorDiff<T>(
  _ lhs: T, _ rhs: T, path: String = ""
) -> [String] {
  let lhsMirror = Mirror(reflecting: lhs)
  let rhsMirror = Mirror(reflecting: rhs)

  // Leaf: no children — compare String(describing:)
  if lhsMirror.children.isEmpty && rhsMirror.children.isEmpty {
    let lhsStr = String(describing: lhs)
    let rhsStr = String(describing: rhs)
    if lhsStr != rhsStr {
      return ["\(path): \(lhsStr) -> \(rhsStr)"]
    }
    return []
  }

  var diffs: [String] = []

  // Dictionary
  if lhsMirror.displayStyle == .dictionary {
    let lhsDict = dictFromMirror(lhsMirror)
    let rhsDict = dictFromMirror(rhsMirror)
    let allKeys = Set(lhsDict.keys).union(rhsDict.keys).sorted()
    for key in allKeys {
      let childPath = path.isEmpty ? "[\(key)]" : "\(path).[\(key)]"
      switch (lhsDict[key], rhsDict[key]) {
      case (.some(let lVal), .some(let rVal)):
        diffs += mirrorDiff(lVal, rVal, path: childPath)
      case (.some(let lVal), .none):
        diffs.append("\(childPath): \(String(describing: lVal)) -> (removed)")
      case (.none, .some(let rVal)):
        diffs.append("\(childPath): (added) -> \(String(describing: rVal))")
      case (.none, .none):
        break
      }
    }
    return diffs
  }

  // Set
  if lhsMirror.displayStyle == .set {
    let lhsSet = setFromMirror(lhsMirror)
    let rhsSet = setFromMirror(rhsMirror)
    if lhsSet != rhsSet {
      diffs.append(
        "\(path): {\(lhsSet.sorted().joined(separator: ", "))}"
        + " -> {\(rhsSet.sorted().joined(separator: ", "))}"
      )
    }
    return diffs
  }

  // Array/Collection
  if lhsMirror.displayStyle == .collection {
    let lhsArr = lhsMirror.children.map(\.value)
    let rhsArr = rhsMirror.children.map(\.value)
    let maxCount = max(lhsArr.count, rhsArr.count)
    for idx in 0..<maxCount {
      let childPath = "\(path)[\(idx)]"
      if idx >= lhsArr.count {
        diffs.append("\(childPath): (added) -> \(String(describing: rhsArr[idx]))")
      } else if idx >= rhsArr.count {
        diffs.append("\(childPath): \(String(describing: lhsArr[idx])) -> (removed)")
      } else {
        diffs += mirrorDiff(lhsArr[idx], rhsArr[idx], path: childPath)
      }
    }
    return diffs
  }

  // Optional
  if lhsMirror.displayStyle == .optional {
    let lhsVal = lhsMirror.children.first?.value
    let rhsVal = rhsMirror.children.first?.value
    switch (lhsVal, rhsVal) {
    case (.some(let lVal), .some(let rVal)):
      return mirrorDiff(lVal, rVal, path: path)
    case (.none, .some(let rVal)):
      return ["\(path): nil -> \(String(describing: rVal))"]
    case (.some(let lVal), .none):
      return ["\(path): \(String(describing: lVal)) -> nil"]
    case (.none, .none):
      return []
    }
  }

  // Struct/class with named children: recurse
  let lhsChildren = Array(lhsMirror.children)
  let rhsChildren = Array(rhsMirror.children)

  for (lhsChild, rhsChild) in zip(lhsChildren, rhsChildren) {
    let label = lhsChild.label ?? "?"
    let childPath = path.isEmpty ? label : "\(path).\(label)"
    diffs += mirrorDiff(lhsChild.value, rhsChild.value, path: childPath)
  }
  return diffs
}
// swiftlint:enable cyclomatic_complexity function_body_length

/// Format a value as key-value lines using Mirror reflection.
func mirrorDump<T>(_ value: T, path: String = "") -> String {
  let mirror = Mirror(reflecting: value)

  if mirror.children.isEmpty {
    let desc = String(describing: value)
    return path.isEmpty ? desc : "\(path): \(desc)"
  }

  if mirror.displayStyle == .dictionary {
    let dict = dictFromMirror(mirror)
    let entries = dict.keys.sorted().map { key in
      "\(key): \(String(describing: dict[key]!))"
    }.joined(separator: ", ")
    return "\(path): {\(entries)}"
  }

  if mirror.displayStyle == .set {
    let items = setFromMirror(mirror)
    return "\(path): {\(items.sorted().joined(separator: ", "))}"
  }

  if mirror.displayStyle == .collection {
    let count = mirror.children.count
    return "\(path): [\(count) items]"
  }

  if mirror.displayStyle == .optional {
    if let wrapped = mirror.children.first?.value {
      return mirrorDump(wrapped, path: path)
    }
    return "\(path): nil"
  }

  // Struct/class: recurse children
  var lines: [String] = []
  for child in mirror.children {
    let label = child.label ?? "?"
    let childPath = path.isEmpty ? label : "\(path).\(label)"
    lines.append(mirrorDump(child.value, path: childPath))
  }
  return lines.joined(separator: "\n")
}

private func dictFromMirror(_ mirror: Mirror) -> [String: Any] {
  var result: [String: Any] = [:]
  for child in mirror.children {
    let pair = Mirror(reflecting: child.value)
    if let key = pair.children.first?.value,
       let value = pair.children.dropFirst().first?.value {
      result[String(describing: key)] = value
    }
  }
  return result
}

private func setFromMirror(_ mirror: Mirror) -> Set<String> {
  Set(mirror.children.map { String(describing: $0.value) })
}
