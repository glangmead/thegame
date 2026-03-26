import Testing
@testable import DynamicalSystems

@Suite("DSLValue")
struct DSLValueTests {

  let interner = StringInterner()

  private func sym(_ name: String) -> DSLValue {
    .symbol(interner.intern(name))
  }

  @Test func intEquality() {
    #expect(DSLValue.int(5) == DSLValue.int(5))
    #expect(DSLValue.int(5) != DSLValue.int(6))
  }

  @Test func symbolEquality() {
    let east = sym("east")
    let east2 = sym("east")
    let west = sym("west")
    #expect(east == east2)
    #expect(east != west)
  }

  @Test func structEquality() {
    let ptA = DSLValue.structValue(type: "Point", fields: ["x": .int(1), "y": .int(2)])
    let ptB = DSLValue.structValue(type: "Point", fields: ["x": .int(1), "y": .int(2)])
    let ptC = DSLValue.structValue(type: "Point", fields: ["x": .int(1), "y": .int(9)])
    #expect(ptA == ptB)
    #expect(ptA != ptC)
  }

  @Test func intAccessor() {
    #expect(DSLValue.int(5).asInt == 5)
    #expect(DSLValue.bool(true).asInt == nil)
    #expect(DSLValue.string("hi").asInt == nil)
  }

  @Test func floatAccessor() {
    #expect(DSLValue.float(1.5).asFloat == 1.5)
    #expect(DSLValue.int(3).asFloat == 3.0)
    #expect(DSLValue.bool(false).asFloat == nil)
  }

  @Test func nilCheck() {
    #expect(DSLValue.nil.isNil == true)
    #expect(DSLValue.int(0).isNil == false)
    #expect(DSLValue.bool(false).isNil == false)
  }

  @Test func displayString() {
    #expect(DSLValue.int(42).displayString == "42")
    let symbolVal = sym("east")
    #expect(symbolVal.displayString(interner: interner) == "east")
    let lst = DSLValue.list([.int(1), .int(2)])
    #expect(lst.displayString == "[1, 2]")
    #expect(DSLValue.bool(true).displayString == "true")
    #expect(DSLValue.string("hello").displayString == "hello")
    #expect(DSLValue.nil.displayString == "nil")
  }
}
