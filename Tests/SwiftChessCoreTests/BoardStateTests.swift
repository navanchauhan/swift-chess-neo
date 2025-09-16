#if canImport(SwiftUI)
@testable import SwiftChessUI
@testable import SwiftChessCore
import XCTest

@MainActor
final class BoardStateTests: XCTestCase {

  func testInitialBoardSquares() {
    let state = BoardState()
    XCTAssertEqual(state.squares.count, 64)
    XCTAssertEqual(state.squares.filter { $0.piece != nil }.count, 32)
    XCTAssertEqual(state.squares.first?.square, Square(file: .a, rank: 8))
  }

  func testTapSelectionHighlightsMoves() {
    let state = BoardState()
    state.handleTap(on: Square(file: .e, rank: 2))
    XCTAssertEqual(state.selectedSquare, Square(file: .e, rank: 2))
    let legal = state.squares.first(where: { $0.square == Square(file: .e, rank: 4) })
    let highlight = BoardState.SquareModel.Highlights.legalMove
    XCTAssertTrue(legal?.highlights.contains(highlight) == true)
  }

  func testPromotionRequestShowsOptions() throws {
    let fen = "7k/P7/8/8/8/8/8/7K w - - 0 1"
    let position = try XCTUnwrap(Game.Position(fen: fen))
    let game = try Game(position: position)
    let state = BoardState(game: game)

    let start = Square(file: .a, rank: 7)
    let end = Square(file: .a, rank: 8)

    state.handleTap(on: start)
    state.handleTap(on: end)

    let request = try XCTUnwrap(state.promotionRequest)
    XCTAssertEqual(request.source, start)
    XCTAssertEqual(request.target, end)
    XCTAssertEqual(Set(request.options), Set([Piece.Kind.queen, .rook, .bishop, .knight]))
  }
}
#endif
