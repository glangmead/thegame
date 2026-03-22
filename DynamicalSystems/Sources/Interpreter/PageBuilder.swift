enum PageBuilder {
  struct RulesResult {
    var pages: [RulePage<InterpretedState, ActionValue>] = []
    var priorities: [RulePage<InterpretedState, ActionValue>] = []
    var reactions: [AutoRule<InterpretedState>] = []
    var phases: [String] = []
    var phaseMap: [String: String] = [:]
    var redeterminize: [String] = []
  }
}
