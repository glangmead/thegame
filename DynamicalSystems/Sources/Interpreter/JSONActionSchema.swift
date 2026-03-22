// MARK: - JSONActionSchema

enum JSONActionSchema {

  static func build(_ json: JSONValue) throws -> ActionSchema {
    var actions: [String: ActionDefinition] = [:]
    var groups: [DSLActionGroup] = []
    let dict = json.objectValue ?? [:]

    // Parse actions
    if let actionsArray = dict["actions"]?.arrayValue {
      for item in actionsArray {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue else {
          throw DSLError.malformed("action entry missing name")
        }
        var params: [ActionParameter] = []
        if let paramsArray = obj["params"]?.arrayValue {
          for paramItem in paramsArray {
            guard let pObj = paramItem.objectValue,
                  let pName = pObj["name"]?.stringValue,
                  let pType = pObj["type"]?.stringValue else {
              throw DSLError.malformed("action param missing name or type")
            }
            let isOptional = pObj["optional"]?.boolValue ?? false
            params.append(ActionParameter(name: pName, type: pType, isOptional: isOptional))
          }
        }
        actions[name] = ActionDefinition(name: name, parameters: params)
      }
    }

    // Parse groups
    if let groupsArray = dict["groups"]?.arrayValue {
      for item in groupsArray {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue else {
          throw DSLError.malformed("group entry missing name")
        }
        let actionNames = obj["actions"]?.arrayValue?.compactMap(\.stringValue) ?? []
        groups.append(DSLActionGroup(name: name, actionNames: actionNames))
      }
    }

    return ActionSchema(actions: actions, groups: groups)
  }
}
