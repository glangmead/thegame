import Testing
@testable import DynamicalSystems

@Suite("ActionSchema")
struct ActionSchemaTests {
  @Test func parseSimpleAction() throws {
    let input = """
    (actions
      (action drawCard)
      (action meleeAttack (slot ArmySlot)))
    """
    let sexpr = try SExprParser.parse(input)
    let schema = try ActionSchema(sexpr)
    let draw = schema.action("drawCard")
    #expect(draw != nil)
    #expect(draw?.parameters.isEmpty == true)
    let melee = schema.action("meleeAttack")
    #expect(melee?.parameters.count == 1)
    #expect(melee?.parameters[0].name == "slot")
    #expect(melee?.parameters[0].type == "ArmySlot")
  }

  @Test func parseGroups() throws {
    let input = """
    (actions
      (action meleeAttack (slot ArmySlot))
      (action rangedAttack (slot ArmySlot))
      (group "Combat" {meleeAttack rangedAttack}))
    """
    let sexpr = try SExprParser.parse(input)
    let schema = try ActionSchema(sexpr)
    #expect(schema.groups.count == 1)
    #expect(schema.groups[0].name == "Combat")
    #expect(schema.groups[0].actionNames == ["meleeAttack", "rangedAttack"])
  }
}
