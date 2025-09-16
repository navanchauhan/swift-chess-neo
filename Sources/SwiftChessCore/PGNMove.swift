//
//  PGNMove.swift
//  Sage
//
//  Created by Kajetan Dąbrowski on 19/10/2016.
//  Copyright © 2016 Nikolai Vazquez. All rights reserved.
//

import Foundation

/// A PGN move representation in a string.
public struct PGNMove: RawRepresentable, ExpressibleByStringLiteral {

  /// PGN Move parsing error
  ///
  /// - invalidMove: The move is invalid
  public enum ParseError: Error {
    case invalidMove(String)
  }

  private enum CastleSide {
    case king
    case queen
  }

  private struct ParsedMove {
    var piece: Piece.Kind
    var destination: Square
    var sourceFile: File?
    var sourceRank: Rank?
    var isCapture: Bool
    var promotionPiece: Piece.Kind?
    var castle: CastleSide?
    var isCheck: Bool
    var isCheckmate: Bool
    var isDrop: Bool
    var dropPiece: Piece.Kind?
  }

  private struct ParsedSuffix {
    var isCheck: Bool
    var isCheckmate: Bool
  }

  public typealias RawValue = String
  public typealias StringLiteralType = String
  public typealias ExtendedGraphemeClusterLiteralType = String
  public typealias UnicodeScalarLiteralType = String
  public let rawValue: String

  private var parsed: ParsedMove?

  public init?(rawValue: String) {
    self.rawValue = rawValue
    parse()
    if !isPossible { return nil }
  }

  public init(stringLiteral value: StringLiteralType) {
    rawValue = value
    parse()
  }

  public init(unicodeScalarLiteral value: UnicodeScalarLiteralType) {
    rawValue = value
    parse()
  }

  public init(extendedGraphemeClusterLiteral value: ExtendedGraphemeClusterLiteralType) {
    rawValue = value
    parse()
  }

  mutating private func parse() {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      parsed = nil
      return
    }
    let (core, suffix) = PGNMove.stripSuffix(from: trimmed)
    if let castle = PGNMove.parseCastle(from: core, suffix: suffix) {
      parsed = castle
      return
    }
    if let drop = PGNMove.parseDrop(from: core, suffix: suffix) {
      parsed = drop
      return
    }
    if let lan = PGNMove.parseLAN(from: core, suffix: suffix) {
      parsed = lan
      return
    }
    parsed = PGNMove.parseSAN(from: core, suffix: suffix)
  }

  /// Indicates whether the move is possible.
  public var isPossible: Bool {
    return parsed != nil
  }

  /// Indicated whether the pgn represents a capture
  public var isCapture: Bool {
    return parsed?.isCapture ?? false
  }

  /// Indicates whether the move represents a promotion
  public var isPromotion: Bool {
    return parsed?.promotionPiece != nil
  }

  /// Indicates whether the move is castle
  public var isCastle: Bool {
    return parsed?.castle != nil
  }

  /// Indicates whether the move is castle kingside
  public var isCastleKingside: Bool {
    return parsed?.castle == .king
  }

  /// Indicates whether the move is castle queenside
  public var isCastleQueenside: Bool {
    return parsed?.castle == .queen
  }

  /// Indicates whether the move represents a check
  public var isCheck: Bool {
    return parsed?.isCheck ?? false
  }

  /// Indicates whether the move represents a checkmate
  public var isCheckmate: Bool {
    return parsed?.isCheckmate ?? false
  }

  /// Indicates whether the move represents a drop
  public var isDrop: Bool {
    return parsed?.isDrop ?? false
  }

  /// The dropped piece kind when the move is a drop.
  public var dropPiece: Piece.Kind? {
    return parsed?.dropPiece
  }

  /// A piece kind that is moved by the move
  public var piece: Piece.Kind {
    guard let piece = parsed?.piece else {
      fatalError("Invalid piece")
    }
    return piece
  }

  /// The rank to move to
  public var rank: Rank {
    guard let rank = parsed?.destination.rank else {
      fatalError("Could not get rank")
    }
    return rank
  }

  /// The file to move to
  public var file: File {
    guard let file = parsed?.destination.file else {
      fatalError("Could not get file")
    }
    return file
  }

  /// The rank to move from.
  /// For example in the move 'Nf3' there is no source rank, since PGNMove is out of board context.
  /// However, if you specify the move like 'N4d2' the move will represent the knight from the fourth rank.
  public var sourceRank: Rank? {
    return parsed?.sourceRank
  }

  /// The file to move from.
  /// For example in the move 'Nf3' there is no source file, since PGNMove is out of board context.
  /// However, if you specify the move like 'Nfd2' the move will represent the knight from the d file.
  public var sourceFile: File? {
    return parsed?.sourceFile
  }

  /// Represents a piece that the move wants to promote to
  public var promotionPiece: Piece.Kind? {
    return parsed?.promotionPiece
  }

  private static func stripSuffix(from text: String) -> (core: String, suffix: ParsedSuffix) {
    var core = text
    // Trim trailing annotations like !, ? (including multiple characters)
    while let last = core.last, last == "!" || last == "?" {
      core.removeLast()
    }

    var isCheckmate = false
    if let last = core.last, last == "#" {
      isCheckmate = true
      core.removeLast()
    }

    var hasCheck = isCheckmate
    while let last = core.last, last == "+" {
      hasCheck = true
      core.removeLast()
    }

    return (
      core,
      ParsedSuffix(isCheck: hasCheck, isCheckmate: isCheckmate)
    )
  }

  private static func parseCastle(from text: String, suffix: ParsedSuffix) -> ParsedMove? {
    let normalized = text.replacingOccurrences(of: "0", with: "O")
    let castleSide: CastleSide?
    switch normalized {
    case "O-O":
      castleSide = .king
    case "O-O-O":
      castleSide = .queen
    default:
      castleSide = nil
    }
    guard let side = castleSide else { return nil }
    let destinationFile: File = side == .king ? .g : .c
    // Default to white rank; consumers should rely on the castle flags rather than destination.
    let destination = Square(file: destinationFile, rank: .one)
    return ParsedMove(
      piece: ._king,
      destination: destination,
      sourceFile: .e,
      sourceRank: .one,
      isCapture: false,
      promotionPiece: nil,
      castle: side,
      isCheck: suffix.isCheck,
      isCheckmate: suffix.isCheckmate,
      isDrop: false,
      dropPiece: nil
    )
  }

  private static func parseDrop(from text: String, suffix: ParsedSuffix) -> ParsedMove? {
    guard let atIndex = text.firstIndex(of: "@") else {
      return nil
    }
    let prefix = text[..<atIndex]
    let destinationText = text[text.index(after: atIndex)...]
    guard let destination = Square(String(destinationText)) else {
      return nil
    }
    let resolvedPiece: Piece.Kind
    if prefix.isEmpty {
      resolvedPiece = ._pawn
    } else if prefix.count == 1, let letter = prefix.first,
              let piece = pieceFor(letter: String(letter).uppercased()) {
      resolvedPiece = piece
    } else {
      return nil
    }
    return ParsedMove(
      piece: resolvedPiece,
      destination: destination,
      sourceFile: nil,
      sourceRank: nil,
      isCapture: false,
      promotionPiece: nil,
      castle: nil,
      isCheck: suffix.isCheck,
      isCheckmate: suffix.isCheckmate,
      isDrop: true,
      dropPiece: resolvedPiece
    )
  }

  private static func parseLAN(from text: String, suffix: ParsedSuffix) -> ParsedMove? {
    var work = text
    guard work.count >= 4 else { return nil }

    var pieceKind: Piece.Kind = ._pawn
    if let first = work.first, let piece = pieceFor(letter: String(first).uppercased()) {
      pieceKind = piece
      work.removeFirst()
    }

    guard work.count >= 4 else { return nil }
    let startString = String(work.prefix(2))
    guard let startSquare = Square(startString) else { return nil }
    work.removeFirst(2)

    var isCapture = false
    if let first = work.first {
      if first == "x" || first == "X" {
        isCapture = true
        work.removeFirst()
      } else if first == "-" { // optional separator
        work.removeFirst()
      }
    }

    guard work.count >= 2 else { return nil }
    let destinationString = String(work.prefix(2))
    guard let destination = Square(destinationString) else { return nil }
    work.removeFirst(2)

    var promotionPiece: Piece.Kind? = nil
    if !work.isEmpty {
      if work.first == "=" {
        work.removeFirst()
      }
      guard work.count == 1, let promo = pieceFor(letter: String(work.first!).uppercased()) else {
        return nil
      }
      promotionPiece = promo
    }

    return ParsedMove(
      piece: pieceKind,
      destination: destination,
      sourceFile: startSquare.file,
      sourceRank: startSquare.rank,
      isCapture: isCapture,
      promotionPiece: promotionPiece,
      castle: nil,
      isCheck: suffix.isCheck,
      isCheckmate: suffix.isCheckmate,
      isDrop: false,
      dropPiece: nil
    )
  }

  private static func parseSAN(from text: String, suffix: ParsedSuffix) -> ParsedMove? {
    var work = text
    guard !work.isEmpty else { return nil }

    if work.count == 2, let first = work.first, first.isUppercase {
      // Piece designations must include a destination file and rank. A two-character
      // token beginning with an uppercase piece letter is therefore invalid.
      return nil
    }

    var promotionPiece: Piece.Kind? = nil
    if let equalIndex = work.firstIndex(of: "=") {
      let promoIndex = work.index(after: equalIndex)
      guard promoIndex < work.endIndex else { return nil }
      let promoChar = work[promoIndex]
      guard let promo = pieceFor(letter: String(promoChar).uppercased()) else { return nil }
      promotionPiece = promo
      work.removeSubrange(equalIndex..<work.endIndex)
    } else if let last = work.last, let promo = pieceFor(letter: String(last).uppercased()),
              work.count >= 3 {
      // SAN sometimes omits '=' for promotions (e.g. d8Q)
      let beforeLast = work[work.index(work.endIndex, offsetBy: -2)]
      if beforeLast.isNumber || File(beforeLast) != nil {
        promotionPiece = promo
        work.removeLast()
      }
    }

    guard work.count >= 2 else { return nil }
    let destinationString = String(work.suffix(2))
    guard let destination = Square(destinationString) else { return nil }
    work.removeLast(2)

    var isCapture = false
    if let captureIndex = work.lastIndex(where: { $0 == "x" || $0 == "X" }) {
      isCapture = true
      work.remove(at: captureIndex)
    }

    var pieceKind: Piece.Kind = ._pawn
    if let first = work.first, let piece = pieceFor(letter: String(first).uppercased()) {
      pieceKind = piece
      work.removeFirst()
    }

    var sourceFile: File? = nil
    var sourceRank: Rank? = nil
    for character in work {
      if let file = File(character) {
        sourceFile = file
      } else if let value = Int(String(character)), let rank = Rank(value) {
        sourceRank = rank
      } else {
        return nil
      }
    }

    return ParsedMove(
      piece: pieceKind,
      destination: destination,
      sourceFile: sourceFile,
      sourceRank: sourceRank,
      isCapture: isCapture,
      promotionPiece: promotionPiece,
      castle: nil,
      isCheck: suffix.isCheck,
      isCheckmate: suffix.isCheckmate,
      isDrop: false,
      dropPiece: nil
    )
  }

  private static func pieceFor(letter: String) -> Piece.Kind? {
    switch letter {
    case "N":
      return ._knight
    case "B":
      return ._bishop
    case "K":
      return ._king
    case "Q":
      return ._queen
    case "R":
      return ._rook
    case "P":
      return ._pawn
    case "":
      return ._pawn
    default:
      return nil
    }
  }
}

public struct PGNParser {

  /// Parses the move in context of the game position
  ///
  /// - parameter move:     Move that needs to be parsed
  /// - parameter position: position to parse in
  ///
  /// - throws: Errors if move is invalid, or if it cannot be executed in this position, or if it's ambiguous.
  ///
  /// - returns: Parsed move that can be applied to a game (containing source and destination squares)
  public static func parse(move: PGNMove, in position: Game.Position) throws -> Move {
    if !move.isPossible { throw PGNMove.ParseError.invalidMove(move.rawValue) }
    let colorToMove = position.playerTurn
    if move.isCastleKingside { return Move(castle: colorToMove, direction: .right) }
    if move.isCastleQueenside { return Move(castle: colorToMove, direction: .left) }

    let piece = Piece(kind: move.piece, color: colorToMove)
    let destinationSquare: Square = Square(file: move.file, rank: move.rank)
    let game = try Game(position: position)
    var possibleMoves = game.availableMoves().filter { return $0.end == destinationSquare }.filter {
      move -> Bool in
      game.board.locations(for: piece).contains(where: { move.start.location == $0 })
    }

    if let sourceFile = move.sourceFile {
      possibleMoves = possibleMoves.filter { $0.start.file == sourceFile }
    }
    if let sourceRank = move.sourceRank {
      possibleMoves = possibleMoves.filter { $0.start.rank == sourceRank }
    }

    if possibleMoves.count != 1 { throw PGNMove.ParseError.invalidMove(move.rawValue) }
    return possibleMoves.first!
  }
}
