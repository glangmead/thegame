/// A define entry: a named macro with optional parameters and a body expression.
struct DefineEntry: Sendable {
  let name: String
  let parameters: [String]
  let body: SExpr
}

/// Resolves define calls in SExpr trees by substituting parameters.
/// Cycle detection prevents infinite recursion.
struct DefineExpander: Sendable {
  private var defines: [String: DefineEntry] = [:]

  init(_ sexprList: [SExpr]) throws {
    for sexpr in sexprList {
      guard let children = sexpr.children, sexpr.tag == "define" else { continue }
      guard children.count >= 3 else {
        throw DSLError.malformed("define needs name and body")
      }
      let name = children[1].stringValue ?? children[1].atomValue ?? ""
      if children.count >= 4, let paramList = children[2].children {
        let params = paramList.compactMap(\.atomValue)
        defines[name] = DefineEntry(name: name, parameters: params, body: children[3])
      } else {
        defines[name] = DefineEntry(name: name, parameters: [], body: children[2])
      }
    }
    try detectCycles()
  }

  func expand(_ expr: SExpr) throws -> SExpr {
    try expand(expr, visited: [])
  }

  // MARK: - Private

  private func expand(_ expr: SExpr, visited: Set<String>) throws -> SExpr {
    switch expr {
    case .atom:
      return expr
    case .list(let children):
      guard let tag = children.first?.atomValue else {
        return .list(try children.map { try expand($0, visited: visited) })
      }
      if let entry = defines[tag] {
        guard !visited.contains(tag) else {
          throw DSLError.cyclicDefine(tag)
        }
        var newVisited = visited
        newVisited.insert(tag)
        if entry.parameters.isEmpty {
          return try expand(entry.body, visited: newVisited)
        } else {
          let args = Array(children.dropFirst())
          var body = entry.body
          for (idx, param) in entry.parameters.enumerated() where idx < args.count {
            let expandedArg = try expand(args[idx], visited: newVisited)
            body = substitute(body, param: param, with: expandedArg)
          }
          return try expand(body, visited: newVisited)
        }
      }
      return .list(try children.map { try expand($0, visited: visited) })
    }
  }

  private func substitute(
    _ expr: SExpr,
    param: String,
    with replacement: SExpr
  ) -> SExpr {
    switch expr {
    case .atom(let str):
      if str == "$\(param)" { return replacement }
      return expr
    case .list(let children):
      return .list(children.map { substitute($0, param: param, with: replacement) })
    }
  }

  private func detectCycles() throws {
    var callGraph: [String: Set<String>] = [:]
    for (name, entry) in defines {
      callGraph[name] = collectReferences(entry.body)
    }
    var visited = Set<String>()
    var stack = Set<String>()
    for name in defines.keys {
      // swiftlint:disable:next for_where
      if try hasCycle(name, graph: callGraph, visited: &visited, stack: &stack) {
        throw DSLError.cyclicDefine(name)
      }
    }
  }

  private func collectReferences(_ expr: SExpr) -> Set<String> {
    switch expr {
    case .atom:
      return []
    case .list(let children):
      guard let tag = children.first?.atomValue else { return [] }
      var refs = Set<String>()
      if defines[tag] != nil { refs.insert(tag) }
      for child in children { refs.formUnion(collectReferences(child)) }
      return refs
    }
  }

  private func hasCycle(
    _ node: String,
    graph: [String: Set<String>],
    visited: inout Set<String>,
    stack: inout Set<String>
  ) throws -> Bool {
    if stack.contains(node) { return true }
    if visited.contains(node) { return false }
    visited.insert(node)
    stack.insert(node)
    for neighbor in graph[node] ?? [] {
      // swiftlint:disable:next for_where
      if try hasCycle(neighbor, graph: graph, visited: &visited, stack: &stack) {
        return true
      }
    }
    stack.remove(node)
    return false
  }
}
