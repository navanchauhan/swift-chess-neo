//
//  Board.swift
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

/// A chess board used to map `Square`s to `Piece`s.
///
/// Pieces map to separate instances of `Bitboard` which can be retrieved with `bitboard(for:)`.
public struct Board: Hashable, CustomStringConvertible {

  /// A chess board space.
  public struct Space: Hashable, CustomStringConvertible {

    /// The occupying chess piece.
    public var piece: Piece?

    /// The space's file.
    public var file: File

    /// The space's rank.
    public var rank: Rank

    /// The space's location on a chess board.
    public var location: Location {
      get {
        return (file, rank)
      }
      set {
        (file, rank) = newValue
      }
    }

    /// The space's square on a chess board.
    public var square: Square {
      get {
        return Square(file: file, rank: rank)
      }
      set {
        location = newValue.location
      }
    }

    /// The space's color.
    public var color: Color {
      return (file.index & 1 != rank.index & 1) ? .white : .black
    }

    /// The space's name.
    public var name: String {
      return "\(file.character)\(rank.rawValue)"
    }

    /// A textual representation of `self`.
    public var description: String {
      return "Space(\(name), \(piece._altDescription))"
    }

    /// The hash value.
    //        public var hashValue: Int {
    //            let pieceHash = piece?.hashValue ?? (6 << 1)
    //            let fileHash = file.hashValue << 4
    //            let rankHash = rank.hashValue << 7
    //            return pieceHash + fileHash + rankHash
    //        }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(piece)
      hasher.combine(file)
      hasher.combine(rank)
    }

    /// Create a chess board space with a piece, file, and rank.
    public init(piece: Piece? = nil, file: File, rank: Rank) {
      self.init(piece: piece, location: (file, rank))
    }

    /// Create a chess board space with a piece and location.
    public init(piece: Piece? = nil, location: Location) {
      self.piece = piece
      (file, rank) = location
    }

    /// Create a chess board space with a piece and square.
    public init(piece: Piece? = nil, square: Square) {
      self.piece = piece
      (file, rank) = square.location
    }

    /// Clears the piece from the space and returns it.
    public mutating func clear() -> Piece? {
      let piece = self.piece
      self.piece = nil
      return piece
    }

  }

  /// An iterator for the spaces of a chess board.
  public struct Iterator: IteratorProtocol {

    let _board: Board

    var _index: Int

    fileprivate init(_ board: Board) {
      self._board = board
      self._index = 0
    }

    /// Advances to the next space on the board and returns it.
    public mutating func next() -> Board.Space? {
      guard let square = Square(rawValue: _index) else {
        return nil
      }
      defer { _index += 1 }
      return _board.space(at: square)
    }

  }

  /// A board side.
  public enum Side {

    /// Right side of the board.
    case kingside

    /// Right side of the board.
    case queenside

    /// `self` is kingside.
    public var isKingside: Bool {
      return self == .kingside
    }

    /// `self` is queenside.
    public var isQueenside: Bool {
      return self == .queenside
    }

  }

  /// The bitboards of `self`.
  internal var _bitboards: [Bitboard]

  /// The board's pieces.
  public var pieces: [Piece] {
    return self.compactMap({ $0.piece })
  }

  /// The board's white pieces.
  public var whitePieces: [Piece] {
    return pieces.filter({ $0.color.isWhite })
  }

  /// The board's black pieces.
  public var blackPieces: [Piece] {
    return pieces.filter({ $0.color.isBlack })
  }

  /// A bitboard for the occupied spaces of `self`.
  public var occupiedSpaces: Bitboard {
    return _bitboards.reduce(0, |)
  }

  /// A bitboard for the empty spaces of `self`.
  public var emptySpaces: Bitboard {
    return ~occupiedSpaces
  }

  /// A textual representation of `self`.
  public var description: String {
    return "Board(\(fen()))"
  }

  /// The hash value.
  public func hash(into hasher: inout Hasher) {
    _bitboards.forEach { hasher.combine($0) }
  }

  /// An ASCII art representation of `self`.
  ///
  /// The ASCII representation for the starting board:
  ///
  /// ```
  ///   +-----------------+
  /// 8 | r n b q k b n r |
  /// 7 | p p p p p p p p |
  /// 6 | . . . . . . . . |
  /// 5 | . . . . . . . . |
  /// 4 | . . . . . . . . |
  /// 3 | . . . . . . . . |
  /// 2 | P P P P P P P P |
  /// 1 | R N B Q K B N R |
  ///   +-----------------+
  ///     a b c d e f g h
  /// ```
  public var ascii: String {
    let edge = "  +-----------------+\n"
    var result = edge
    let reversed = Rank.all.reversed()
    for rank in reversed {
      let strings = File.all.map({ file in "\(self[(file, rank)]?.character ?? ".")" })
      let str = strings.joined(separator: " ")
      result += "\(rank) | \(str) |\n"
    }
    result += "\(edge)    a b c d e f g h  "
    return result
  }

  /// Create a chess board.
  ///
  /// - parameter variant: The variant to populate the board for. Won't populate if `nil`. Default is `Standard`.
  public init(variant: Variant? = .standard) {
    _bitboards = Array(repeating: 0, count: 12)
    if let variant = variant {
      for piece in Piece.all {
        _bitboards[piece.rawValue] = Bitboard(startFor: piece)
      }
      if variant.isUpsideDown {
        for index in _bitboards.indices {
          _bitboards[index].flipVertically()
        }
      }
    }
  }

  /// Create a chess board from a valid FEN string.
  ///
  /// - Warning: Only to be used with the board part of a full FEN string.
  ///
  /// - see also: [FEN (Wikipedia)](https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation),
  ///            [FEN (Chess Programming Wiki)](https://chessprogramming.org/Forsyth-Edwards+Notation)
  public init?(fen: String) {
    func pieces(for string: String) -> [Piece?]? {
      var pieces: [Piece?] = []
      for char in string {
        guard pieces.count < 8 else {
          return nil
        }
        if let piece = Piece(character: char) {
          pieces.append(piece)
        } else if let num = Int(String(char)) {
          guard 1...8 ~= num else { return nil }
          pieces += Array(repeating: nil, count: num)
        } else {
          return nil
        }
      }
      return pieces
    }
    guard !fen.contains(" ") else {
      return nil
    }
    let parts = fen.split(separator: "/").map(String.init)
    let ranks = Rank.all.reversed()
    guard parts.count == 8 else {
      return nil
    }
    var board = Board(variant: nil)
    for (rank, part) in zip(ranks, parts) {
      guard let pieces = pieces(for: part) else {
        return nil
      }
      for (file, piece) in zip(File.all, pieces) {
        board[(file, rank)] = piece
      }
    }
    self = board
  }

  /// Create a chess board from arrays of piece characters.
  ///
  /// Returns `nil` if a piece can't be initialized from a character. Characters beyond the 8x8 area are ignored.
  /// Empty spaces are denoted with a whitespace or period.
  ///
  /// ```swift
  /// Board(pieces: [["r", "n", "b", "q", "k", "b", "n", "r"],
  ///                ["p", "p", "p", "p", "p", "p", "p", "p"],
  ///                [" ", " ", " ", " ", " ", " ", " ", " "],
  ///                [" ", " ", " ", " ", " ", " ", " ", " "],
  ///                [" ", " ", " ", " ", " ", " ", " ", " "],
  ///                [" ", " ", " ", " ", " ", " ", " ", " "],
  ///                ["P", "P", "P", "P", "P", "P", "P", "P"],
  ///                ["R", "N", "B", "Q", "K", "B", "N", "R"]])
  /// ```
  public init?(pieces: [[Character]]) {
    self.init(variant: nil)
    for rankIndex in pieces.indices {
      guard let rank = Rank(index: rankIndex)?.opposite() else { break }
      for fileIndex in pieces[rankIndex].indices {
        guard let file = File(index: fileIndex) else { break }
        let pieceChar = pieces[rankIndex][fileIndex]
        if pieceChar != " " && pieceChar != "." {
          guard let piece = Piece(character: pieceChar) else { return nil }
          self[(file, rank)] = piece
        }
      }
    }
  }

  /// Gets and sets a piece at `location`.
  public subscript(location: Location) -> Piece? {
    get {
      return self[Square(location: location)]
    }
    set {
      self[Square(location: location)] = newValue
    }
  }

  /// Gets and sets a piece at `square`.
  public subscript(square: Square) -> Piece? {
    get {
      for index in _bitboards.indices {
        if _bitboards[index][square] {
          return Piece(value: index)
        }
      }
      return nil
    }
    set {
      for index in _bitboards.indices {
        _bitboards[index][square] = false
      }
      if let piece = newValue {
        self[piece][square] = true
      }
    }
  }

  /// Gets and sets the bitboard for `piece`.
  internal subscript(piece: Piece) -> Bitboard {
    get {
      return _bitboards[piece.rawValue]
    }
    set {
      _bitboards[piece.rawValue] = newValue
    }
  }

  /// Returns `self` flipped horizontally.
  public func flippedHorizontally() -> Board {
    var board = self
    for index in _bitboards.indices {
      board._bitboards[index].flipHorizontally()
    }
    return board
  }

  /// Returns `self` flipped vertically.
  public func flippedVertically() -> Board {
    var board = self
    for index in _bitboards.indices {
      board._bitboards[index].flipVertically()
    }
    return board
  }

  /// Clears all the pieces from `self`.
  public mutating func clear() {
    self = Board(variant: nil)
  }

  /// Populates `self` with all of the pieces at their proper locations for the given chess variant.
  public mutating func populate(for variant: Variant = .standard) {
    self = Board(variant: variant)
  }

  /// Flips `self` horizontally.
  public mutating func flipHorizontally() {
    self = flippedHorizontally()
  }

  /// Flips `self` vertically.
  public mutating func flipVertically() {
    self = flippedVertically()
  }

  /// Returns the number of pieces for `color`, or all if `nil`.
  public func pieceCount(for color: Color? = nil) -> Int {
    if let color = color {
      return bitboard(for: color).count
    } else {
      return _bitboards.reduce(0) { $0 + $1.count }
    }
  }

  /// Returns the number of `piece` in `self`.
  public func count(of piece: Piece) -> Int {
    return bitboard(for: piece).count
  }

  /// Returns the bitboard for `piece`.
  public func bitboard(for piece: Piece) -> Bitboard {
    return self[piece]
  }

  /// Returns the bitboard for `color`.
  public func bitboard(for color: Color) -> Bitboard {
    return Piece._hashes(for: color).reduce(0) { $0 | _bitboards[$1] }
  }

  /// The squares with pinned pieces for `color`.
  public func pinned(for color: Color) -> Bitboard {
    guard let kingSquare = squareForKing(for: color) else {
      return 0
    }
    let occupied = occupiedSpaces
    var pinned = Bitboard()
    let pieces = bitboard(for: color)
    let king = bitboard(for: Piece(king: color))
    let opRQ =
      bitboard(for: Piece(rook: color.inverse())) | bitboard(for: Piece(queen: color.inverse()))
    let opBQ =
      bitboard(for: Piece(bishop: color.inverse())) | bitboard(for: Piece(queen: color.inverse()))
    for square in king._xrayRookAttacks(occupied: occupied, stoppers: pieces) & opRQ {
      pinned |= square.between(kingSquare) & pieces
    }
    for square in king._xrayBishopAttacks(occupied: occupied, stoppers: pieces) & opBQ {
      pinned |= square.between(kingSquare) & pieces
    }
    return pinned
  }

  /// Returns the attackers to `square` corresponding to `color`.
  ///
  /// - parameter square: The `Square` being attacked.
  /// - parameter color: The `Color` of the attackers.
  public func attackers(to square: Square, color: Color) -> Bitboard {
    let all = occupiedSpaces
    let attackPieces = Piece._nonQueens(for: color)
    let playerPieces = Piece._nonQueens(for: color.inverse())
    let attacks = playerPieces.map({ piece in
      square.attacks(for: piece, stoppers: all)
    })
    let queens = (attacks[2] | attacks[3]) & self[Piece(queen: color)]
    return zip(attackPieces, attacks).reduce(queens) { $0 | (self[$1.0] & $1.1) }
  }

  /// Returns the attackers to the king for `color`.
  ///
  /// - parameter color: The `Color` of the potentially attacked king.
  ///
  /// - returns: A bitboard of all attackers, or 0 if the king does not exist or if there are no pieces attacking the
  ///            king.
  public func attackersToKing(for color: Color) -> Bitboard {
    guard let square = squareForKing(for: color) else {
      return 0
    }
    return attackers(to: square, color: color.inverse())
  }

  /// Returns `true` if the king for `color` is in check.
  public func kingIsChecked(for color: Color) -> Bool {
    return attackersToKing(for: color) != 0
  }

  /// Returns the spaces at `file`.
  public func spaces(at file: File) -> [Space] {
    return Rank.all.map { space(at: (file, $0)) }
  }

  /// Returns the spaces at `rank`.
  public func spaces(at rank: Rank) -> [Space] {
    return File.all.map { space(at: ($0, rank)) }
  }

  /// Returns the space at `location`.
  public func space(at location: Location) -> Space {
    return Space(piece: self[location], location: location)
  }

  /// Returns the square at `location`.
  public func space(at square: Square) -> Space {
    return Space(piece: self[square], square: square)
  }

  /// Removes a piece at `square`, and returns it.
  @discardableResult
  public mutating func removePiece(at square: Square) -> Piece? {
    if let piece = self[square] {
      self[piece][square] = false
      return piece
    } else {
      return nil
    }
  }

  /// Removes a piece at `location`, and returns it.
  @discardableResult
  public mutating func removePiece(at location: Location) -> Piece? {
    return removePiece(at: Square(location: location))
  }

  /// Swaps the pieces between the two locations.
  public mutating func swap(_ first: Location, _ second: Location) {
    swap(Square(location: first), Square(location: second))
  }

  /// Swaps the pieces between the two squares.
  public mutating func swap(_ first: Square, _ second: Square) {
    switch (self[first], self[second]) {
    case let (firstPiece?, secondPiece?):
      self[firstPiece].swap(first, second)
      self[secondPiece].swap(first, second)
    case let (firstPiece?, nil):
      self[firstPiece].swap(first, second)
    case let (nil, secondPiece?):
      self[secondPiece].swap(first, second)
    default:
      break
    }
  }

  /// Returns the locations where `piece` exists.
  public func locations(for piece: Piece) -> [Location] {
    return bitboard(for: piece).map({ $0.location })
  }

  /// Returns the squares where `piece` exists.
  public func squares(for piece: Piece) -> [Square] {
    return Array(bitboard(for: piece))
  }

  /// Returns the squares where pieces for `color` exist.
  public func squares(for color: Color) -> [Square] {
    return Array(bitboard(for: color))
  }

  /// Returns the square of the king for `color`, if any.
  public func squareForKing(for color: Color) -> Square? {
    return bitboard(for: Piece(king: color)).lsbSquare
  }

  /// Returns `true` if `self` contains `piece`.
  public func contains(_ piece: Piece) -> Bool {
    return !self[piece].isEmpty
  }

  /// Returns the FEN string for the board.
  ///
  /// - see also: [FEN (Wikipedia)](https://en.wikipedia.org/wiki/Forsyth%E2%80%93Edwards_Notation),
  ///            [FEN (Chess Programming Wiki)](https://www.chessprogramming.org/Forsyth-Edwards_Notation)
  public func fen() -> String {
    func fen(forRank rank: Rank) -> String {
      var fen = ""
      var accumulator = 0
      for space in spaces(at: rank) {
        if let piece = space.piece {
          if accumulator > 0 {
            fen += String(accumulator)
            accumulator = 0
          }
          fen += String(piece.character)
        } else {
          accumulator += 1
          if space.file == ._h {
            fen += String(accumulator)
          }
        }
      }
      return fen
    }
    return Rank.all.reversed().map(fen).joined(separator: "/")
  }

  public func toArray() -> [Board.Space] {
    var array = [Board.Space]()
    for space in self {
      array.append(space)
    }

    return array.reversed()
  }

}

extension Board: Sequence {

  /// A value less than or equal to the number of elements in
  /// the sequence, calculated nondestructively.
  ///
  /// - Complexity: O(1).
  public var underestimatedCount: Int {
    return 64
  }

  /// Returns an iterator over the spaces of the board.
  public func makeIterator() -> Iterator {
    return Iterator(self)
  }

}

/// Returns `true` if both boards are the same.
public func == (lhs: Board, rhs: Board) -> Bool {
  return lhs._bitboards == rhs._bitboards
}

/// Returns `true` if both spaces are the same.
public func == (lhs: Board.Space, rhs: Board.Space) -> Bool {
  return lhs.piece == rhs.piece
    && lhs.file == rhs.file
    && lhs.rank == rhs.rank
}
