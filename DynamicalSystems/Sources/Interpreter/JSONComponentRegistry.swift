// MARK: - JSONComponentRegistry

enum JSONComponentRegistry {

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  static func build(_ json: JSONValue) throws -> ComponentRegistry {
    var enums: [String: EnumDefinition] = [:]
    var structs: [String: StructDefinition] = [:]
    var functions: [String: EnumFunction] = [:]
    var cards: [DSLValue] = []
    var crts: [String: CRTDefinition] = [:]
    var playerIndex: [String: Int] = [:]
    let dict = json.objectValue ?? [:]

    // Parse enums
    if let enumsArray = dict["enums"]?.arrayValue {
      for item in enumsArray {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue else {
          throw DSLError.malformed("enum entry missing name")
        }
        let values = obj["values"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let rawDisplayNames = obj["displayNames"]?.arrayValue?.compactMap(\.stringValue) ?? []
        var displayNames: [String: String] = [:]
        for (idx, caseName) in values.enumerated() where idx < rawDisplayNames.count {
          displayNames[caseName] = rawDisplayNames[idx]
        }
        enums[name] = EnumDefinition(
          name: name,
          cases: values,
          associatedTypes: [:],
          displayNames: displayNames
        )
        if let playerIdx = obj["player"]?.intValue {
          playerIndex[name] = playerIdx
        }
      }
    }

    // Parse structs
    if let structsArray = dict["structs"]?.arrayValue {
      for item in structsArray {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue else {
          throw DSLError.malformed("struct entry missing name")
        }
        let fields: [(name: String, type: String)] = obj["fields"]?.arrayValue?.compactMap { fieldItem in
          guard let fObj = fieldItem.objectValue,
                let fName = fObj["name"]?.stringValue,
                let fType = fObj["type"]?.stringValue else { return nil }
          return (name: fName, type: fType)
        } ?? []
        structs[name] = StructDefinition(name: name, fields: fields)
      }
    }

    // Parse functions
    if let functionsArray = dict["functions"]?.arrayValue {
      for item in functionsArray {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue,
              let domain = obj["domain"]?.stringValue,
              let mappingObj = obj["mapping"]?.objectValue else {
          throw DSLError.malformed("function entry missing required fields")
        }
        var mapping: [String: DSLValue] = [:]
        for (key, val) in mappingObj {
          mapping[key] = jsonValueToDSLValue(val)
        }
        functions[name] = EnumFunction(
          name: name, domain: domain, mapping: mapping, fidMapping: [:]
        )
      }
    }

    // Parse cards
    if let cardsArray = dict["cards"]?.arrayValue {
      for item in cardsArray {
        guard let obj = item.objectValue else { continue }
        var fields: [String: DSLValue] = [:]
        for (key, val) in obj {
          fields[key] = jsonValueToDSLValue(val)
        }
        cards.append(.structValue(type: "Card", fields: fields))
      }
    }

    // Parse CRTs
    if let crtsArray = dict["crts"]?.arrayValue {
      for item in crtsArray {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue else {
          throw DSLError.malformed("crt entry missing name")
        }
        let rowEnumName = obj["row"]?.stringValue
        let resultFields = obj["results"]?.arrayValue?.compactMap(\.stringValue) ?? []
        let entriesValue = obj["entries"]

        var rows: [String: [CRTEntry]] = [:]

        if rowEnumName != nil, let entriesObj = entriesValue?.objectValue {
          // Keyed by row name
          for (rowName, rowData) in entriesObj {
            guard let rowEntries = rowData.arrayValue else { continue }
            rows[rowName] = try parseCRTEntries(rowEntries)
          }
        } else if let entriesArr = entriesValue?.arrayValue {
          // Row-less CRT
          rows[""] = try parseCRTEntries(entriesArr)
        }

        crts[name] = CRTDefinition(
          name: name,
          rowEnumName: rowEnumName,
          resultFields: resultFields,
          rows: rows
        )
      }
    }

    return ComponentRegistry(
      enums: enums,
      structs: structs,
      functions: functions,
      cards: cards,
      crts: crts,
      playerIndex: playerIndex
    )
  }

  // MARK: - Private helpers

  private static func parseCRTEntries(
    _ entries: [JSONValue]
  ) throws -> [CRTEntry] {
    var result: [CRTEntry] = []
    for entry in entries {
      guard let obj = entry.objectValue,
            let diceArr = obj["dice"]?.arrayValue,
            !diceArr.isEmpty,
            let valuesArr = obj["values"]?.arrayValue else {
        throw DSLError.malformed("crt entry missing dice or values")
      }
      let diceInts = diceArr.compactMap(\.intValue)
      guard let low = diceInts.min(),
            let high = diceInts.max() else {
        throw DSLError.malformed("crt dice must be integers")
      }
      let values = valuesArr.map { jsonValueToDSLValue($0) }
      result.append(CRTEntry(low: low, high: high, values: values))
    }
    return result
  }

  private static func jsonValueToDSLValue(_ value: JSONValue) -> DSLValue {
    switch value {
    case .int(let num): return .int(num)
    case .float(let flt): return .float(flt)
    case .bool(let bln): return .bool(bln)
    case .string(let str): return .string(str)
    case .null: return .nil
    case .array(let items): return .list(items.map { jsonValueToDSLValue($0) })
    case .object: return .nil
    }
  }
}
