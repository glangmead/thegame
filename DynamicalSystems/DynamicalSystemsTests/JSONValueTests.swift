import Testing
@testable import DynamicalSystems

@Suite("JSONValue")
struct JSONValueTests {

  // MARK: - JSONC comment stripping

  @Test func stripLineComment() {
    let input = """
    {
      // this is a comment
      "name": "test"
    }
    """
    let stripped = stripJSONCComments(input)
    #expect(stripped.contains("\"name\""))
    #expect(!stripped.contains("//"))
  }

  @Test func stripBlockComment() {
    let input = """
    { /* block */ "name": "test" }
    """
    let stripped = stripJSONCComments(input)
    #expect(!stripped.contains("/*"))
    #expect(stripped.contains("\"name\""))
  }

  @Test func preserveSlashInString() {
    let input = """
    { "url": "https://example.com" }
    """
    let stripped = stripJSONCComments(input)
    #expect(stripped.contains("https://example.com"))
  }

  // MARK: - JSON -> JSONValue conversion

  @Test func parseObject() throws {
    let json = """
    {"name": "test", "count": 3}
    """
    let value = try JSONGameParser.parse(json)
    guard case .object(let dict) = value else {
      Issue.record("Expected object")
      return
    }
    #expect(dict["name"] == .string("test"))
    #expect(dict["count"] == .int(3))
  }

  @Test func parseArray() throws {
    let json = "[1, 2, 3]"
    let value = try JSONGameParser.parse(json)
    #expect(value == .array([.int(1), .int(2), .int(3)]))
  }

  @Test func parseFloat() throws {
    let json = "[1.5]"
    let value = try JSONGameParser.parse(json)
    #expect(value == .array([.float(1.5)]))
  }

  @Test func parseBoolAndNull() throws {
    let json = "[true, false, null]"
    let value = try JSONGameParser.parse(json)
    #expect(value == .array([.bool(true), .bool(false), .null]))
  }

  @Test func parseNestedObject() throws {
    let json = """
    {"outer": {"inner": 42}}
    """
    let value = try JSONGameParser.parse(json)
    guard case .object(let dict) = value,
          case .object(let inner) = dict["outer"] else {
      Issue.record("Expected nested object")
      return
    }
    #expect(inner["inner"] == .int(42))
  }

  @Test func jsoncWithComments() throws {
    let jsonc = """
    {
      // line comment
      "name": "test", /* inline */
      "value": 42
    }
    """
    let value = try JSONGameParser.parse(jsonc)
    guard case .object(let dict) = value else {
      Issue.record("Expected object")
      return
    }
    #expect(dict["name"] == .string("test"))
    #expect(dict["value"] == .int(42))
  }

  // MARK: - Accessor tests

  @Test func asCallWithArray() {
    let value = JSONValue.object(["+": .array([.int(1), .int(2)])])
    let call = value.asCall
    #expect(call?.op == "+")
    #expect(call?.args == [.int(1), .int(2)])
  }

  @Test func asCallWithNonArrayReturnsNil() {
    let value = JSONValue.object(["name": .string("test")])
    #expect(value.asCall == nil)
  }

  @Test func asCallWithMultipleKeysReturnsNil() {
    let value = JSONValue.object(["a": .array([]), "b": .array([])])
    #expect(value.asCall == nil)
  }
}
