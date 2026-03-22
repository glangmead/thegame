// MARK: - JSONStateSchema

enum JSONStateSchema {

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  static func build(_ json: JSONValue) throws -> StateSchema {
    var fields: [String: FieldDefinition] = [:]
    let dict = json.objectValue ?? [:]

    // fields → .field(type)
    if let arr = dict["fields"]?.arrayValue {
      for item in arr {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue,
              let typeName = obj["type"]?.stringValue else {
          throw DSLError.malformed("field entry missing name or type")
        }
        fields[name] = FieldDefinition(name: name, kind: .field(type: typeName))
      }
    }

    // counters → .counter(min:max:)
    if let arr = dict["counters"]?.arrayValue {
      for item in arr {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue else {
          throw DSLError.malformed("counter entry missing name")
        }
        let minVal = obj["min"]?.intValue ?? 0
        let maxVal: Int
        if let maxInt = obj["max"]?.intValue {
          maxVal = maxInt
        } else if obj["max"]?.stringValue == "inf" {
          maxVal = Int.max
        } else {
          maxVal = 0
        }
        fields[name] = FieldDefinition(name: name, kind: .counter(min: minVal, max: maxVal))
      }
    }

    // flags → .flag (array of bare strings)
    if let arr = dict["flags"]?.arrayValue {
      for item in arr {
        guard let name = item.stringValue else {
          throw DSLError.malformed("flag entry must be a string")
        }
        fields[name] = FieldDefinition(name: name, kind: .flag)
      }
    }

    // dicts → .dict(keyType:valueType:)
    if let arr = dict["dicts"]?.arrayValue {
      for item in arr {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue,
              let keyType = obj["key"]?.stringValue,
              let valueType = obj["value"]?.stringValue else {
          throw DSLError.malformed("dict entry missing name, key, or value")
        }
        fields[name] = FieldDefinition(name: name, kind: .dict(keyType: keyType, valueType: valueType))
      }
    }

    // sets → .set(elementType:)
    if let arr = dict["sets"]?.arrayValue {
      for item in arr {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue,
              let elementType = obj["element"]?.stringValue else {
          throw DSLError.malformed("set entry missing name or element")
        }
        fields[name] = FieldDefinition(name: name, kind: .set(elementType: elementType))
      }
    }

    // decks → .deck(cardType:)
    if let arr = dict["decks"]?.arrayValue {
      for item in arr {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue,
              let cardType = obj["cardType"]?.stringValue else {
          throw DSLError.malformed("deck entry missing name or cardType")
        }
        fields[name] = FieldDefinition(name: name, kind: .deck(cardType: cardType))
      }
    }

    // optionals → .optional(valueType:)
    if let arr = dict["optionals"]?.arrayValue {
      for item in arr {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue,
              let valueType = obj["type"]?.stringValue else {
          throw DSLError.malformed("optional entry missing name or type")
        }
        fields[name] = FieldDefinition(name: name, kind: .optional(valueType: valueType))
      }
    }

    // lists → .deck(cardType:) (lists map to deck internally)
    if let arr = dict["lists"]?.arrayValue {
      for item in arr {
        guard let obj = item.objectValue,
              let name = obj["name"]?.stringValue,
              let elementType = obj["element"]?.stringValue else {
          throw DSLError.malformed("list entry missing name or element")
        }
        fields[name] = FieldDefinition(name: name, kind: .deck(cardType: elementType))
      }
    }

    return StateSchema(fields: fields)
  }
}
