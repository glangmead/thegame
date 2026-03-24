import Testing
@testable import DynamicalSystems

@Suite("MirrorDiff")
struct MirrorDiffTests {

  // swiftlint:disable identifier_name
  struct Simple {
    var x: Int
    var y: String
  }
  // swiftlint:enable identifier_name

  @Test func identicalValuesReturnEmpty() {
    // swiftlint:disable:next identifier_name
    let a = Simple(x: 1, y: "hello")
    let diffs = mirrorDiff(a, a)
    #expect(diffs.isEmpty)
  }

  @Test func detectsChangedLeafFields() {
    // swiftlint:disable identifier_name
    let a = Simple(x: 1, y: "hello")
    let b = Simple(x: 2, y: "hello")
    // swiftlint:enable identifier_name
    let diffs = mirrorDiff(a, b)
    #expect(diffs.count == 1)
    #expect(diffs[0].contains("x"))
    #expect(diffs[0].contains("1"))
    #expect(diffs[0].contains("2"))
  }

  @Test func detectsMultipleChanges() {
    // swiftlint:disable identifier_name
    let a = Simple(x: 1, y: "hello")
    let b = Simple(x: 2, y: "world")
    // swiftlint:enable identifier_name
    let diffs = mirrorDiff(a, b)
    #expect(diffs.count == 2)
  }

  struct WithDict {
    var counts: [String: Int]
  }

  @Test func detectsDictValueChange() {
    // swiftlint:disable identifier_name
    let a = WithDict(counts: ["x": 1, "y": 2])
    let b = WithDict(counts: ["x": 1, "y": 3])
    // swiftlint:enable identifier_name
    let diffs = mirrorDiff(a, b)
    #expect(diffs.count == 1)
    #expect(diffs[0].contains("y"))
  }

  @Test func detectsDictKeyAddedRemoved() {
    // swiftlint:disable identifier_name
    let a = WithDict(counts: ["x": 1])
    let b = WithDict(counts: ["y": 2])
    // swiftlint:enable identifier_name
    let diffs = mirrorDiff(a, b)
    // x removed, y added
    #expect(diffs.count == 2)
  }

  struct WithSet {
    var tags: Set<String>
  }

  @Test func detectsSetChanges() {
    // swiftlint:disable identifier_name
    let a = WithSet(tags: ["a", "b"])
    let b = WithSet(tags: ["b", "c"])
    // swiftlint:enable identifier_name
    let diffs = mirrorDiff(a, b)
    #expect(!diffs.isEmpty)
    let joined = diffs.joined()
    #expect(joined.contains("a"))
    #expect(joined.contains("c"))
  }

  struct WithArray {
    var items: [Int]
  }

  @Test func detectsArrayChanges() {
    // swiftlint:disable identifier_name
    let a = WithArray(items: [1, 2, 3])
    let b = WithArray(items: [1, 4, 3])
    // swiftlint:enable identifier_name
    let diffs = mirrorDiff(a, b)
    #expect(diffs.count == 1)
    #expect(diffs[0].contains("[1]"))
  }

  struct WithOptional {
    var name: String?
  }

  @Test func detectsOptionalNilToValue() {
    // swiftlint:disable identifier_name
    let a = WithOptional(name: nil)
    let b = WithOptional(name: "hello")
    // swiftlint:enable identifier_name
    let diffs = mirrorDiff(a, b)
    #expect(diffs.count == 1)
    #expect(diffs[0].contains("nil"))
    #expect(diffs[0].contains("hello"))
  }

  @Test func detectsOptionalValueToNil() {
    // swiftlint:disable identifier_name
    let a = WithOptional(name: "hello")
    let b = WithOptional(name: nil)
    // swiftlint:enable identifier_name
    let diffs = mirrorDiff(a, b)
    #expect(diffs.count == 1)
  }

  @Test func identicalOptionalsReturnEmpty() {
    // swiftlint:disable:next identifier_name
    let a = WithOptional(name: "hello")
    let diffs = mirrorDiff(a, a)
    #expect(diffs.isEmpty)
  }

  @Test func dumpsSimpleStruct() {
    // swiftlint:disable:next identifier_name
    let a = Simple(x: 42, y: "hello")
    let dump = mirrorDump(a)
    #expect(dump.contains("x: 42"))
    #expect(dump.contains("y: hello"))
  }

  @Test func dumpsNestedStruct() {
    // swiftlint:disable identifier_name
    struct Outer {
      var inner: Simple
      var z: Bool
    }
    let a = Outer(inner: Simple(x: 1, y: "hi"), z: true)
    // swiftlint:enable identifier_name
    let dump = mirrorDump(a)
    #expect(dump.contains("inner.x: 1"))
    #expect(dump.contains("z: true"))
  }
}
