/// A parsed S-expression: either an atom or a list of sub-expressions.
enum SExpr: Equatable, Sendable {
  case atom(String)
  case list([SExpr])
}

// MARK: - Convenience accessors

extension SExpr {
  /// The raw atom string, or nil if this is a list.
  var atomValue: String? {
    guard case .atom(let str) = self else { return nil }
    return str
  }

  /// If this is a quoted-string atom (surrounded by `"`), returns the inner content.
  var stringValue: String? {
    guard let raw = atomValue,
          raw.hasPrefix("\""),
          raw.hasSuffix("\""),
          raw.count >= 2 else { return nil }
    return String(raw.dropFirst().dropLast())
  }

  /// Parse the atom as an integer.
  var intValue: Int? {
    guard let raw = atomValue else { return nil }
    return Int(raw)
  }

  /// The list children, or nil if this is an atom.
  var children: [SExpr]? {
    guard case .list(let items) = self else { return nil }
    return items
  }

  /// For a list, the first child's atom string — the "tag" or "head" of the form.
  var tag: String? {
    children?.first?.atomValue
  }
}

// MARK: - SExprArgs

/// Zero-copy view into an SExpr children array.  Avoids the
/// `Array(children.dropFirst())` copy that bulk-retains every String buffer.
struct SExprArgs: RandomAccessCollection {
  private let storage: [SExpr]
  private let offset: Int

  init(_ array: [SExpr], droppingFirst drop: Int = 0) {
    self.storage = array
    self.offset = drop
  }

  var startIndex: Int { 0 }
  var endIndex: Int { storage.count - offset }

  subscript(_ index: Int) -> SExpr {
    storage[offset + index]
  }

  func index(after idx: Int) -> Int { idx + 1 }

  func dropFirst(_ count: Int = 1) -> SExprArgs {
    SExprArgs(storage, droppingFirst: offset + count)
  }
}

// MARK: - Parser

enum SExprParser {

  // MARK: Public API

  /// Parse a single top-level S-expression from `input`.
  static func parse(_ input: String) throws -> SExpr {
    var tokens = tokenize(input)
    let expr = try parseExpr(&tokens)
    return expr
  }

  /// Parse zero or more top-level S-expressions from `input`.
  static func parseMultiple(_ input: String) throws -> [SExpr] {
    var tokens = tokenize(input)
    var results: [SExpr] = []
    while !tokens.isEmpty {
      results.append(try parseExpr(&tokens))
    }
    return results
  }

  // MARK: Errors

  enum ParseError: Error, Equatable {
    case unexpectedEnd
    case unexpectedToken(String)
    case unmatchedParen
  }

  // MARK: Private – tokenizer

  // swiftlint:disable:next cyclomatic_complexity
  private static func tokenize(_ input: String) -> [String] {
    var tokens: [String] = []
    var index = input.startIndex

    while index < input.endIndex {
      let cur = input[index]

      // Skip whitespace
      if cur.isWhitespace {
        index = input.index(after: index)
        continue
      }

      // Line comment
      if cur == ";" {
        while index < input.endIndex && input[index] != "\n" {
          index = input.index(after: index)
        }
        continue
      }

      // Structural delimiters
      if cur == "(" || cur == ")" || cur == "{" || cur == "}" {
        tokens.append(String(cur))
        index = input.index(after: index)
        continue
      }

      // Quoted string
      if cur == "\"" {
        var token = "\""
        index = input.index(after: index)
        while index < input.endIndex {
          let quoted = input[index]
          token.append(quoted)
          index = input.index(after: index)
          if quoted == "\"" { break }
        }
        tokens.append(token)
        continue
      }

      // Bare atom: consume until whitespace or delimiter
      var atom = ""
      while index < input.endIndex {
        let atomChar = input[index]
        if atomChar.isWhitespace || atomChar == "(" || atomChar == ")" ||
           atomChar == "{" || atomChar == "}" || atomChar == ";" {
          break
        }
        atom.append(atomChar)
        index = input.index(after: index)
      }
      if !atom.isEmpty {
        tokens.append(atom)
      }
    }

    return tokens
  }

  // MARK: Private – recursive descent

  private static func parseExpr(_ tokens: inout [String]) throws -> SExpr {
    guard !tokens.isEmpty else { throw ParseError.unexpectedEnd }

    let head = tokens.removeFirst()

    if head == "(" || head == "{" {
      let close = head == "(" ? ")" : "}"
      var children: [SExpr] = []
      while true {
        guard !tokens.isEmpty else { throw ParseError.unmatchedParen }
        if tokens.first == close {
          tokens.removeFirst()
          return .list(children)
        }
        children.append(try parseExpr(&tokens))
      }
    }

    if head == ")" || head == "}" {
      throw ParseError.unexpectedToken(head)
    }

    return .atom(head)
  }
}
