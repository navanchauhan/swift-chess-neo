//
//  Piece.swift
//  Sage
//
//  Copyright 2016-2017 Nikolai Vazquez
//  Modified by SuperGeroy
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

/// A chess piece.
public struct Piece: Hashable, CustomStringConvertible, Sendable {

  /// A piece kind.
  public enum Kind: Int, CaseIterable, Sendable {

    /// Pawn piece kind.
    case pawn

    /// Knight piece kind.
    case knight

    /// Bishop piece kind.
    case bishop

    /// Rook piece kind.
    case rook

    /// Queen piece kind.
    case queen

    /// King piece kind.
    case king

    /// Pawn
    internal static let _pawn = Kind.pawn

    /// Knight
    internal static let _knight = Kind.knight

    /// Bishop
    internal static let _bishop = Kind.bishop

    /// Rook
    internal static let _rook = Kind.rook

    /// Queen
    internal static let _queen = Kind.queen

    /// King
    internal static let _king = Kind.king

    /// An array of all piece kinds.
    public static var all: [Kind] {
      Array(allCases)
    }

    /// The piece kind's name.
    public var name: String {
      switch self {
      case .pawn: return "Pawn"
      case .knight: return "Knight"
      case .bishop: return "Bishop"
      case .rook: return "Rook"
      case .queen: return "Queen"
      case .king: return "King"
      }
    }

    /// The piece kind's relative value. Can be used to determine how valuable a piece or combination of pieces is.
    public var relativeValue: Double {
      switch self {
      case .pawn: return 1
      case .knight: return 3
      case .bishop: return 3.25
      case .rook: return 5
      case .queen: return 9
      case .king: return 900  //.infinity
      }
    }

    /// The piece is `Pawn`.
    public var isPawn: Bool {
      return self == ._pawn
    }

    /// The piece `Knight`.
    public var isKnight: Bool {
      return self == ._knight
    }

    /// The piece is `Bishop`.
    public var isBishop: Bool {
      return self == ._bishop
    }

    /// The piece is `Rook`.
    public var isRook: Bool {
      return self == ._rook
    }

    /// The piece is `Queen`.
    public var isQueen: Bool {
      return self == ._queen
    }

    /// The piece is `King`.
    public var isKing: Bool {
      return self == ._king
    }

    /// Returns `true` if `self` can be a promotion for a pawn.
    public func canPromote() -> Bool {
      return !(isPawn || isKing)
    }

    /// Returns `true` if `self` can be a promotion for `other`.
    public func canPromote(_ other: Kind) -> Bool {
      return canPromote() ? other.isPawn : false
    }

  }

  internal static let _whiteHashes: [Int] = whitePieces.map({ $0.rawValue })

  internal static let _blackHashes: [Int] = blackPieces.map({ $0.rawValue })

  internal static func _hashes(for color: Color) -> [Int] {
    return color.isWhite ? _whiteHashes : _blackHashes
  }

  internal static let _whiteNonQueens: [Piece] = whitePieces.filter({ !$0.kind.isQueen })

  internal static let _blackNonQueens: [Piece] = blackPieces.filter({ !$0.kind.isQueen })

  internal static func _nonQueens(for color: Color) -> [Piece] {
    return color.isWhite ? _whiteNonQueens : _blackNonQueens
  }

  /// An array of all pieces.
  public static let all: [Piece] = {
    return [.white, .black].reduce([]) { pieces, color in
      return pieces + Kind.all.map({ Piece(kind: $0, color: color) })
    }
  }()

  /// An array of all white pieces.
  public static let whitePieces: [Piece] = all.filter({ $0.color.isWhite })

  /// An array of all black pieces.
  public static let blackPieces: [Piece] = all.filter({ $0.color.isBlack })

  /// Returns an array of all pieces for `color`.
  public static func pieces(for color: Color) -> [Piece] {
    return color.isWhite ? whitePieces : blackPieces
  }

  /// The piece's kind.
  public var kind: Kind

  /// The piece's color.
  public var color: Color

  /// The character for the piece. Uppercase if white or lowercase if black.
  public var character: Character {
    switch kind {
    case .pawn: return color.isWhite ? "P" : "p"
    case .knight: return color.isWhite ? "N" : "n"
    case .bishop: return color.isWhite ? "B" : "b"
    case .rook: return color.isWhite ? "R" : "r"
    case .queen: return color.isWhite ? "Q" : "q"
    case .king: return color.isWhite ? "K" : "k"
    }
  }

  /// A textual representation of `self`.
  public var description: String {
    return "\(kind.name)(\(color))"
  }

  /// The piece's raw value.
  public var rawValue: Int {
    return (kind.rawValue << 1) | color.numericValue
  }

  /// Create a piece from an integer value.
  internal init?(value: Int) {
    guard let kind = Kind(rawValue: value >> 1) else {
      return nil
    }
    self.init(kind: kind, color: value & 1 == 0 ? .white : .black)
  }

  /// Create a piece from `kind` and `color`.
  public init(kind: Kind, color: Color) {
    self.kind = kind
    self.color = color
  }

  /// Create a pawn piece with `color`.
  public init(pawn color: Color) {
    self.init(kind: ._pawn, color: color)
  }

  /// Create a knight piece with `color`.
  public init(knight color: Color) {
    self.init(kind: ._knight, color: color)
  }

  /// Create a bishop piece with `color`.
  public init(bishop color: Color) {
    self.init(kind: ._bishop, color: color)
  }

  /// Create a rook piece with `color`.
  public init(rook color: Color) {
    self.init(kind: ._rook, color: color)
  }

  /// Create a queen piece with `color`.
  public init(queen color: Color) {
    self.init(kind: ._queen, color: color)
  }

  /// Create a king piece with `color`.
  public init(king color: Color) {
    self.init(kind: ._king, color: color)
  }

  /// Create a piece from a character.
  public init?(character: Character) {
    switch character {
    case "P": self.init(pawn: .white)
    case "p": self.init(pawn: .black)
    case "N": self.init(knight: .white)
    case "n": self.init(knight: .black)
    case "B": self.init(bishop: .white)
    case "b": self.init(bishop: .black)
    case "R": self.init(rook: .white)
    case "r": self.init(rook: .black)
    case "Q": self.init(queen: .white)
    case "q": self.init(queen: .black)
    case "K": self.init(king: .white)
    case "k": self.init(king: .black)
    default:
      return nil
    }
  }

  /// Returns `true` if `self` can be a promotion for `other`.
  public func canPromote(_ other: Piece) -> Bool {
    return kind.canPromote(other.kind) && color == other.color
  }

  /// Returns `true` if `self` can be a promotion for `color`.
  public func canPromote(_ color: Color) -> Bool {
    return kind.canPromote() ? self.color == color : false
  }

  /// The special character for the piece.
  public func specialCharacter(background color: Color = .white) -> Character {
    switch kind {
    case .pawn: return color == self.color ? "♙" : "♟"
    case .knight: return color == self.color ? "♘" : "♞"
    case .bishop: return color == self.color ? "♗" : "♝"
    case .rook: return color == self.color ? "♖" : "♜"
    case .queen: return color == self.color ? "♕" : "♛"
    case .king: return color == self.color ? "♔" : "♚"
    }
  }

  public func unicodeCharacter() -> Character {
    switch kind {
    case .pawn: return "♟"
    case .knight: return "♞"
    case .bishop: return "♝"
    case .rook: return "♜"
    case .queen: return "♛"
    case .king: return "♚"
    }
  }

  public func getNaturalName() -> String {
    switch kind {
    case .pawn: return self.color.isWhite ? "White Pawn" : "Black Pawn"
    case .bishop: return self.color.isWhite ? "White Bishop" : "Black Bishop"
    case .king: return self.color.isWhite ? "White King" : "Black King"
    case .queen: return self.color.isWhite ? "White Queen" : "Black Queen"
    case .rook: return self.color.isWhite ? "White Rook" : "Black Rook"
    case .knight: return self.color.isWhite ? "White Knight" : "Black Knight"
    }
  }

}

/// Returns `true` if both pieces are the same.
public func == (lhs: Piece, rhs: Piece) -> Bool {
  return lhs.kind == rhs.kind
    && lhs.color == rhs.color
}
