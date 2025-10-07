import UIKit

var greeting = "Hello, playground"
let setOfLists: Set<[Int]> = Set(
  [ [[0, 1], [2, 3]], [[0, 2], [1, 3]], [[0, 3], [1, 2]] ].flatMap { pairings in
    return pairings
  }
)
