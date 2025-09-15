import SwiftChessCore
#if canImport(SwiftChessUI)
import SwiftChessUI
#endif

let game = try! Game(position: Game.Position(fen: "7k/6p1/8/5p1n/2r2P2/4B1P1/R7/K7 b - - 0 1")!)

game.position

game.availableMoves()
game.playerTurn
if let aiMove = game.bestMove(depth: 2) {
  print("Best move: \(aiMove)")
  try game.execute(move: aiMove)
  aiMove == Move(start: .f7, end: .g6)
} else {
  print("uh oh")
}

game.position.board
