import Foundation
import SwiftChessCore

/// Helper structure for presenting PGN movetext trees in UI code.
public struct MovetextOutline {

  /// A single move entry enriched with any attached variations.
  public struct MoveEntry {

    /// The primary move for this entry.
    public var move: PGN.Move

    /// Alternate lines branching from this move.
    public var variations: [MovetextOutline]

    /// Create a move entry.
    public init(move: PGN.Move, variations: [MovetextOutline]) {
      self.move = move
      self.variations = variations
    }
  }

  /// Comments that appear before the first move in the line.
  public var leadingComments: [String]

  /// Variations that occur before the first move in the line.
  public var leadingVariations: [MovetextOutline]

  /// The mainline moves in order.
  public var moves: [MoveEntry]

  /// Comments that appear after the termination marker.
  public var trailingComments: [String]

  /// Parsed result for the line, if present.
  public var result: Game.Outcome?

  /// Diagnostics emitted while parsing the backing movetext.
  public var diagnostics: [PGN.Movetext.Diagnostic]

  /// Create an outline from a movetext node.
  public init(movetext: PGN.Movetext) {
    self.leadingComments = movetext.leadingComments
    self.leadingVariations = movetext.leadingVariations.map { MovetextOutline(movetext: $0) }
    self.moves = movetext.moves.map { move in
      MoveEntry(
        move: move,
        variations: move.variations.map { MovetextOutline(movetext: $0) }
      )
    }
    self.trailingComments = movetext.trailingComments
    self.result = movetext.result
    self.diagnostics = movetext.diagnostics
  }

  /// Create an outline from a PGN instance.
  public init(pgn: PGN) {
    self.init(movetext: pgn.movetext)
  }
}

public extension Game {

  /// Build a UI-friendly outline for the game's PGN, if available.
  func movetextOutline() -> MovetextOutline? {
    guard let pgn = PGN else { return nil }
    return MovetextOutline(movetext: pgn.movetext)
  }
}
