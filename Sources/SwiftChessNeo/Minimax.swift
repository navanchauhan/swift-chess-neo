//
//  Minimax.swift
//
//
//  Created by Navan Chauhan on 4/17/24.
//

/// Extending Game to add evaluation and Minimax algorithm with alpha-beta pruning
extension Game {

  /// Evaluates the current board position, by summing relative values of all pieces (and adjusting by colour)
  func evaluate() -> Double {
    var score: Double = 0
    for square in Square.all {
      if let piece = board[square] {
        score += piece.kind.relativeValue * (piece.color == .white ? 1.0 : -1.0)
      }
    }
    return score
  }

  /// Recursive function that calculates the move value after considering future possibilities
  func minimax(depth: Int, isMaximizingPlayer: Bool, alpha: Double, beta: Double) -> Double {
    if depth == 0 || isFinished {
      return evaluate()
    }

    var alpha = alpha
    var beta = beta

    if isMaximizingPlayer {
      var maxEval: Double = -.infinity
      for move in availableMoves() {
        do {
          try execute(uncheckedMove: move)
          let eval = minimax(depth: depth - 1, isMaximizingPlayer: false, alpha: alpha, beta: beta)
          maxEval = max(maxEval, eval)
          undoMove()
          alpha = max(alpha, eval)
          if beta <= alpha {
            break
          }
        } catch {
          continue
        }
      }
      return maxEval
    } else {
      var minEval: Double = .infinity
      for move in availableMoves() {
        do {
          try execute(uncheckedMove: move)
          let eval = minimax(depth: depth - 1, isMaximizingPlayer: true, alpha: alpha, beta: beta)
          minEval = min(minEval, eval)
          undoMove()
          beta = min(beta, eval)
          if beta <= alpha {
            break
          }
        } catch {
          continue
        }
      }
      return minEval
    }
  }

  /// Public function that determines the best move for the current player
  ///
  /// - Parameter depth: Determines how deep the recursion will go into future moves. A larger depth gives a more strategicallty sound move, but increases processing time
  public func bestMove(depth: Int) -> Move? {
    var bestMove: Move?
    var bestValue: Double = (playerTurn == .white) ? -.infinity : .infinity
    let alpha: Double = -.infinity
    let beta: Double = .infinity

    for move in availableMoves() {
      do {
        try execute(uncheckedMove: move)
        let moveValue = minimax(
          depth: depth - 1, isMaximizingPlayer: playerTurn.isBlack ? false : true, alpha: alpha,
          beta: beta)
        undoMove()
        if (playerTurn == .white && moveValue > bestValue)
          || (playerTurn == .black && moveValue < bestValue)
        {
          bestValue = moveValue
          bestMove = move
        }
      } catch {
        continue
      }
    }
    return bestMove
  }
}
