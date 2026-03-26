import Testing
@testable import DynamicalSystems

@Suite("ActionValue")
struct ActionValueTests {

  let interner = StringInterner()

  private func sym(_ name: String) -> DSLValue {
    .symbol(interner.intern(name))
  }

  // MARK: - camelCaseWords

  @Test func splitSimple() {
    #expect(ActionValue.camelCaseWords("flipHeads") == ["flip", "Heads"])
  }

  @Test func splitMultipleWords() {
    #expect(
      ActionValue.camelCaseWords("rollForAttack")
        == ["roll", "For", "Attack"]
    )
  }

  @Test func splitWithDigits() {
    #expect(
      ActionValue.camelCaseWords("advance30Corps")
        == ["advance", "30", "Corps"]
    )
  }

  @Test func splitDigitSuffix() {
    #expect(
      ActionValue.camelCaseWords("allied101st")
        == ["allied", "101st"]
    )
  }

  @Test func singleWord() {
    #expect(ActionValue.camelCaseWords("initialize") == ["initialize"])
  }

  // MARK: - displayName

  @Test func displayNameNoParams() {
    let action = ActionValue("skipAdvance")
    #expect(action.displayName() == "Skip advance")
  }

  @Test func displayNameWithLookup() {
    let action = ActionValue(
      "airdrop", ["piece": sym("allied101st")]
    )
    let lookup: (String) -> String? = { name in
      name == "allied101st" ? "101st" : nil
    }
    #expect(
      action.displayName(interner: interner, lookup: lookup) == "Airdrop 101st"
    )
  }

  @Test func displayNameFallbackSplitParam() {
    let action = ActionValue(
      "reinforceGerman",
      ["piece": sym("germanEindhoven")]
    )
    #expect(
      action.displayName(interner: interner)
        == "Reinforce german german eindhoven"
    )
  }

  @Test func displayNameDigitsInAction() {
    let action = ActionValue("advance30Corps")
    #expect(action.displayName() == "Advance 30 corps")
  }
}
