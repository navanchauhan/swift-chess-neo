#if canImport(SwiftUI)
import SwiftUI
import SwiftChessCore

@MainActor
public final class BoardState: ObservableObject {

  public struct SquareModel: Identifiable, Equatable {
    public struct Highlights: OptionSet {
      public let rawValue: Int
      public init(rawValue: Int) { self.rawValue = rawValue }
      public static let selected = Highlights(rawValue: 1 << 0)
      public static let legalMove = Highlights(rawValue: 1 << 1)
      public static let capture = Highlights(rawValue: 1 << 2)
      public static let lastMoveOrigin = Highlights(rawValue: 1 << 3)
      public static let lastMoveDestination = Highlights(rawValue: 1 << 4)
      public static let check = Highlights(rawValue: 1 << 5)
      public static let hover = Highlights(rawValue: 1 << 6)
    }

    public let square: Square
    public let piece: Piece?
    public let row: Int
    public let column: Int
    public let isDark: Bool
    public let highlights: Highlights

    public var id: Square { square }
  }

  public struct PromotionRequest: Identifiable, Equatable {
    public let id = UUID()
    public let move: Move
    public let options: [Piece.Kind]
    public let source: Square
    public let target: Square
    public let color: SwiftChessCore.Color
  }

  public enum InteractionFeedback {
    case invalidMove
  }

  public var feedbackHandler: ((InteractionFeedback) -> Void)?

  @Published public private(set) var squares: [SquareModel] = []
  @Published public var orientation: SwiftChessCore.Color
  @Published public private(set) var selectedSquare: Square?
  @Published public var promotionRequest: PromotionRequest?
  @Published public private(set) var hoverSquare: Square?

  public private(set) var lastMove: Move?

  private let game: Game
  private var movesByDestination: [Square: Move] = [:]
  private var captureSquares: Set<Square> = []

  public init(game: Game = Game(), orientation: SwiftChessCore.Color = .white) {
    self.game = game
    self.orientation = orientation
    refreshSquares()
  }

  public func reset(game newGame: Game = Game(), orientation newOrientation: SwiftChessCore.Color? = nil) {
    selectedSquare = nil
    promotionRequest = nil
    hoverSquare = nil
    lastMove = nil
    movesByDestination = [:]
    captureSquares = []
    if let orientation = newOrientation {
      self.orientation = orientation
    }
    game.setGame(newGame)
    refreshSquares()
  }

  public func handleTap(on square: Square) {
    guard promotionRequest == nil else { return }
    if let selected = selectedSquare {
      if square == selected {
        clearSelection()
        return
      }
      if let move = movesByDestination[square] {
        perform(move: move)
        return
      }
    }
    guard let piece = game.board[square], piece.color == game.playerTurn else {
      notify(.invalidMove)
      return
    }
    select(square: square)
  }

  public func handleDrag(start: Square?, current: Square?) {
    guard promotionRequest == nil else { return }
    guard let start else {
      hoverSquare = nil
      refreshSquares()
      return
    }
    if selectedSquare != start {
      guard let piece = game.board[start], piece.color == game.playerTurn else {
        hoverSquare = nil
        refreshSquares()
        return
      }
      select(square: start)
    }
    hoverSquare = current
    refreshSquares()
  }

  public func completeDrag(start: Square?, end: Square?) {
    defer {
      hoverSquare = nil
      refreshSquares()
    }
    guard promotionRequest == nil else { return }
    guard let start, let end else { return }
    if selectedSquare != start {
      guard let piece = game.board[start], piece.color == game.playerTurn else {
        return
      }
      select(square: start)
    }
    if let move = movesByDestination[end] {
      perform(move: move)
    }
  }

  public func cancelPromotion() {
    promotionRequest = nil
    clearSelection()
  }

  public func promote(with piece: Piece.Kind) {
    guard let request = promotionRequest else { return }
    promotionRequest = nil
    do {
      try game.execute(move: request.move, promotion: piece)
      lastMove = request.move
      clearSelection()
      refreshSquares()
    } catch {
      notify(.invalidMove)
    }
  }

  public func rotateBoard() {
    orientation = orientation.inverse()
    refreshSquares()
  }

  public func highlight(square: Square?) {
    hoverSquare = square
    refreshSquares()
  }

  private func select(square: Square) {
    selectedSquare = square
    let moves = game.movesForPiece(at: square)
    movesByDestination = Dictionary(uniqueKeysWithValues: moves.map { ($0.end, $0) })
    captureSquares = Set(moves.filter { move in
      if game.board[move.end] != nil { return true }
      if move.start.file != move.end.file, game.board[move.end] == nil {
        return true
      }
      return false
    }.map { $0.end })
    refreshSquares()
  }

  private func clearSelection() {
    selectedSquare = nil
    movesByDestination = [:]
    captureSquares = []
    refreshSquares()
  }

  private func perform(move: Move) {
    guard let piece = game.board[move.start] else { return }
    if requiresPromotion(move: move, piece: piece) {
      promotionRequest = PromotionRequest(
        move: move,
        options: [.queen, .rook, .bishop, .knight],
        source: move.start,
        target: move.end,
        color: piece.color
      )
      refreshSquares()
      return
    }
    do {
      try game.execute(move: move)
      lastMove = move
      clearSelection()
      refreshSquares()
    } catch {
      notify(.invalidMove)
    }
  }

  private func requiresPromotion(move: Move, piece: Piece) -> Bool {
    guard piece.kind.isPawn else { return false }
    return move.end.rank == Rank(endFor: piece.color)
  }

  private func refreshSquares() {
    var models: [SquareModel] = []
    models.reserveCapacity(64)
    let turnColor = game.playerTurn
    let checkSquare = game.board.kingIsChecked(for: turnColor) ? game.board.squareForKing(for: turnColor) : nil
    for row in 0..<8 {
      for column in 0..<8 {
        let square = squareFor(row: row, column: column)
        let piece = game.board[square]
        var highlights: SquareModel.Highlights = []
        if square == selectedSquare {
          highlights.insert(.selected)
        }
        if let hover = hoverSquare, hover == square {
          highlights.insert(.hover)
        }
        if let move = lastMove {
          if move.start == square {
            highlights.insert(.lastMoveOrigin)
          }
          if move.end == square {
            highlights.insert(.lastMoveDestination)
          }
        }
        if let checkSquare, checkSquare == square {
          highlights.insert(.check)
        }
        if movesByDestination.keys.contains(square) {
          highlights.insert(.legalMove)
          if captureSquares.contains(square) {
            highlights.insert(.capture)
          }
        }
        let isDark = (row + column) % 2 == 1
        models.append(SquareModel(
          square: square,
          piece: piece,
          row: row,
          column: column,
          isDark: isDark,
          highlights: highlights
        ))
      }
    }
    squares = models
  }

  private func squareFor(row: Int, column: Int) -> Square {
    let fileIndex = orientation.isWhite ? column : (7 - column)
    let rankIndex = orientation.isWhite ? (7 - row) : row
    let file = File(index: fileIndex)!
    let rank = Rank(index: rankIndex)!
    return Square(file: file, rank: rank)
  }

  public func squareForDisplay(row: Int, column: Int) -> Square {
    squareFor(row: row, column: column)
  }

  private func notify(_ feedback: InteractionFeedback) {
    feedbackHandler?(feedback)
#if canImport(UIKit)
    if feedback == .invalidMove {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
#endif
  }
}
#endif
