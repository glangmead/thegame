struct JSONDefineEntry: Sendable {
  let name: String
  let parameters: [String]
  let body: JSONValue
}

struct JSONDefineExpander: Sendable {
  private var defines: [String: JSONDefineEntry] = [:]

  init(_ definesArray: JSONValue) throws {
    guard case .array(let items) = definesArray else { return }
    for item in items {
      guard case .object(let dict) = item,
            let name = dict["name"]?.stringValue else { continue }
      let params = dict["params"]?.arrayValue?.compactMap(\.stringValue) ?? []
      guard let body = dict["body"] else {
        throw DSLError.malformed("define \(name) missing body")
      }
      defines[name] = JSONDefineEntry(name: name, parameters: params, body: body)
    }
    try detectCycles()
  }

  func lookup(_ name: String) -> JSONDefineEntry? {
    defines[name]
  }

  func expand(_ value: JSONValue) throws -> JSONValue {
    try expand(value, visited: [])
  }

  // MARK: - Private

  private func expand(
    _ value: JSONValue,
    visited: Set<String>
  ) throws -> JSONValue {
    switch value {
    case .object(let dict):
      // Single-key object might be a define call
      if dict.count == 1, let (key, args) = dict.first,
         let entry = defines[key] {
        guard !visited.contains(key) else {
          throw DSLError.cyclicDefine(key)
        }
        var newVisited = visited
        newVisited.insert(key)
        let argList = args.arrayValue ?? [args]
        if entry.parameters.isEmpty {
          return try expand(entry.body, visited: newVisited)
        }
        var body = entry.body
        for (idx, param) in entry.parameters.enumerated()
          where idx < argList.count {
          let expandedArg = try expand(argList[idx], visited: visited)
          body = substitute(body, param: param, with: expandedArg)
        }
        return try expand(body, visited: newVisited)
      }
      // Not a define call — recurse into all values
      var result: [String: JSONValue] = [:]
      for (key, val) in dict {
        result[key] = try expand(val, visited: visited)
      }
      return .object(result)

    case .array(let items):
      return .array(try items.map { try expand($0, visited: visited) })

    default:
      return value
    }
  }

  private func substitute(
    _ value: JSONValue,
    param: String,
    with replacement: JSONValue
  ) -> JSONValue {
    switch value {
    case .string(let str):
      if str == "$\(param)" { return replacement }
      return value
    case .object(let dict):
      var result: [String: JSONValue] = [:]
      for (key, val) in dict {
        result[key] = substitute(val, param: param, with: replacement)
      }
      return .object(result)
    case .array(let items):
      return .array(items.map { substitute($0, param: param, with: replacement) })
    default:
      return value
    }
  }

  private func detectCycles() throws {
    var callGraph: [String: Set<String>] = [:]
    for (name, entry) in defines {
      callGraph[name] = collectReferences(entry.body)
    }
    var visited = Set<String>()
    var stack = Set<String>()
    for name in defines.keys
      where hasCycle(name, graph: callGraph, visited: &visited, stack: &stack) {
      throw DSLError.cyclicDefine(name)
    }
  }

  private func collectReferences(_ value: JSONValue) -> Set<String> {
    switch value {
    case .object(let dict):
      var refs = Set<String>()
      if dict.count == 1, let key = dict.keys.first,
         defines[key] != nil {
        refs.insert(key)
      }
      for val in dict.values {
        refs.formUnion(collectReferences(val))
      }
      return refs
    case .array(let items):
      var refs = Set<String>()
      for item in items {
        refs.formUnion(collectReferences(item))
      }
      return refs
    default:
      return []
    }
  }

  private func hasCycle(
    _ node: String,
    graph: [String: Set<String>],
    visited: inout Set<String>,
    stack: inout Set<String>
  ) -> Bool {
    if stack.contains(node) { return true }
    if visited.contains(node) { return false }
    visited.insert(node)
    stack.insert(node)
    for neighbor in graph[node] ?? []
      where hasCycle(neighbor, graph: graph, visited: &visited, stack: &stack) {
      return true
    }
    stack.remove(node)
    return false
  }
}
