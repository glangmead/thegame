//
//  ContentView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 8/30/25.
//

import SwiftUI

// Clock example from DJM's book

enum Hour: Int {
  case one = 1, two, three, four, five, six, seven, eight, nine, ten, eleven, twelve
  static func tick(_ hour: Hour) -> Hour {
    switch hour {
    case .twelve:
      return .one
    default:
      return Hour(rawValue: hour.rawValue + 1)!
    }
  }
}

enum Meridiem: String {
  case anteMeridiem = "am"
  case postMeridiem = "pm"
  func toggle() -> Self {
    switch self {
    case .anteMeridiem:
      return .postMeridiem
    case .postMeridiem:
      return .anteMeridiem
    }
  }
  static func tick(merid: Meridiem, hour: Hour) -> Meridiem {
    switch hour {
    case .eleven:
      return merid.toggle()
    default:
      return merid
    }
  }
}

// Clock lens: clock state is just the Hour enum, no need to wrap in a Clock struct
let clock = StateLens<Hour, Void, Hour>(down: { $0 }, update: { hourVoid in Hour.tick(hourVoid.0) })

// Meridiem lens
let meridiem = StateLens<Meridiem, Hour, Meridiem>(down: { $0 }, update: { $0 ||> Meridiem.tick})

// meridiem-clock free product
let meridiemClockFree = meridiem ⊗ clock

// meridiem-clock coupling
// TODO: could this be generic, with the types chosen later by the ev_C functor from DJM's book (Example 1.3.3.17)?
let meridiemClockCoupling = Lens<
  (Hour, Void),
  (Meridiem, Hour),
  Void,
  (Meridiem, Hour)
>(
  down: { $0 },
  update: { meridiemHourValue in
    (meridiemHourValue.0.1, ())
  }
)

let meridiemClock = meridiemClockFree <=> meridiemClockCoupling

struct MeridiemClockView: View {
  @State private var time: (Meridiem, Hour) = (.anteMeridiem, .eleven)

  var body: some View {
    VStack {
      HStack {
        Text(time.1.rawValue.description)
        Text(time.0.rawValue.description)
      }
      Button("Tick") {
        time = time |> (meridiemClock => ())
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

#Preview("Meridiem Clock") {
  MeridiemClockView()
}
