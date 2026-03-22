import Testing
@testable import DynamicalSystems

@Suite("JSONDefineExpander")
struct JSONDefineExpanderTests {

  @Test func expandSimpleDefine() throws {
    let defines: JSONValue = .array([
      .object([
        "name": .string("double"),
        "params": .array([.string("x")]),
        "body": .object(["*": .array([.string("$x"), .int(2)])])
      ])
    ])
    let expander = try JSONDefineExpander(defines)
    // {"double": [5]} should expand to {"*": [5, 2]}
    let input = JSONValue.object(["double": .array([.int(5)])])
    let result = try expander.expand(input)
    #expect(result == .object(["*": .array([.int(5), .int(2)])]))
  }

  @Test func expandZeroParamDefine() throws {
    let defines: JSONValue = .array([
      .object([
        "name": .string("alwaysTrue"),
        "params": .array([]),
        "body": .bool(true)
      ])
    ])
    let expander = try JSONDefineExpander(defines)
    let input = JSONValue.object(["alwaysTrue": .array([])])
    let result = try expander.expand(input)
    #expect(result == .bool(true))
  }

  @Test func detectCycle() {
    let defines: JSONValue = .array([
      .object([
        "name": .string("a"),
        "params": .array([]),
        "body": .object(["b": .array([])])
      ]),
      .object([
        "name": .string("b"),
        "params": .array([]),
        "body": .object(["a": .array([])])
      ])
    ])
    do {
      _ = try JSONDefineExpander(defines)
      Issue.record("Expected DSLError.cyclicDefine but no error thrown")
    } catch {
      let desc = String(describing: error)
      #expect(desc.contains("cyclicDefine"))
    }
  }

  @Test func expandNestedDefineCall() throws {
    let defines: JSONValue = .array([
      .object([
        "name": .string("inc"),
        "params": .array([.string("x")]),
        "body": .object(["+": .array([.string("$x"), .int(1)])])
      ]),
      .object([
        "name": .string("incTwice"),
        "params": .array([.string("x")]),
        "body": .object(["inc": .array([
          .object(["inc": .array([.string("$x")])])
        ])])
      ])
    ])
    let expander = try JSONDefineExpander(defines)
    let input = JSONValue.object(["incTwice": .array([.int(5)])])
    let result = try expander.expand(input)
    // incTwice(5) -> inc(inc(5)) -> inc({"+": [5, 1]}) -> {"+": [{"+": [5, 1]}, 1]}
    #expect(result == .object(["+": .array([
      .object(["+": .array([.int(5), .int(1)])]),
      .int(1)
    ])]))
  }
}
