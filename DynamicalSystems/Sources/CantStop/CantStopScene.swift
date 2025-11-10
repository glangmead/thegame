//
//  CantStopScene.swift
//  DynamicalSystems
//
//  Created by Greg Langmead on 11/7/25.
//

import ComposableArchitecture
import Foundation
import SpriteKit

// this will observe a CantStopState and draw stuff accordingly
class CantStopScene: SKScene {
  @SharedReader var state: CantStop.State
  
  init(state: SharedReader<CantStop.State>, size: CGSize) {
    self._state = state
    super.init(size: size)
  }

  required init?(coder aDecoder: NSCoder) {
    // this will not let us observe the model being used in the app
    self._state = SharedReader(value: CantStop.State())
    super.init(coder: aDecoder)
  }
  
  override func didMove(to view: SKView) {
    observe { [weak self] in
      print("\(self!.state.whitePositions)")
    }
  }
}

