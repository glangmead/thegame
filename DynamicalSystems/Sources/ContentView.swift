//
//  ContentView.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 8/30/25.
//

//import ComposableArchitecture
import SwiftUI

// Clock example from DJM's book

enum Hour: Int {
  case one = 1, two, three, four, five, six, seven, eight, nine, ten, eleven, twelve
  static func tick(_ h: Hour) -> Hour {
    switch h {
    case .twelve:
      return .one
    default:
      return Hour(rawValue: h.rawValue + 1)!
    }
  }
}

enum Meridiem: String {
  case am, pm
  func toggle() -> Self {
    switch self {
    case .am:
      return .pm
    case .pm:
      return .am
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
let clock = StateLens<Hour, Void, Hour>(down: { $0 }, up: {hv in Hour.tick(hv.0) })

// Meridiem lens
let meridiem = StateLens<Meridiem, Hour, Meridiem>(down: { $0 }, up: { $0 ||> Meridiem.tick})

// meridiem-clock free product
let meridiem_clock_free = meridiem ⊗ clock

// meridiem-clock coupling
// TODO: could this be generic, with the types chosen later by the ev_C functor from DJM's book (Example 1.3.3.17)?
let meridiem_clock_coupling = Lens<
  (Hour, Void),
  (Meridiem, Hour),
  Void,
  (Meridiem, Hour)
>(
  down: { $0 },
  up: { mh_v in
    (mh_v.0.1, ())
  }
)

let meridiem_clock = meridiem_clock_free <=> meridiem_clock_coupling

struct MeridiemClockView: View {
  @State private var time: (Meridiem, Hour) = (.am, .eleven)
  
  var body: some View {
    VStack {
      HStack {
        Text(time.1.rawValue.description)
        Text(time.0.rawValue.description)
      }
      Button("Tick") {
        time = time |> (meridiem_clock => ())
      }
      .buttonStyle(.borderedProminent)
    }
  }
}

#Preview("Meridiem Clock") {
  MeridiemClockView()
}
