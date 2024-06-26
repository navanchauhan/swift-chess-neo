//
//  Move.swift
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

/// A chess move from a start `Square` to an end `Square`.
public struct Move: Hashable, CustomStringConvertible {

    /// The move's start square.
    public var start: Square

    /// The move's end square.
    public var end: Square

    /// The move's change in file.
    public var fileChange: Int {
        return end.file.rawValue - start.file.rawValue
    }

    /// The move's change in rank.
    public var rankChange: Int {
        return end.rank.rawValue - start.rank.rawValue
    }

    /// The move is a real change in location.
    public var isChange: Bool {
        return start != end
    }

    /// The move is diagonal.
    public var isDiagonal: Bool {
        let fileChange = self.fileChange
        return fileChange != 0 && abs(fileChange) == abs(rankChange)
    }

    /// The move is horizontal.
    public var isHorizontal: Bool {
        return start.file != end.file && start.rank == end.rank
    }

    /// The move is vertical.
    public var isVertical: Bool {
        return start.file == end.file && start.rank != end.rank
    }

    /// The move is horizontal or vertical.
    public var isAxial: Bool {
        return isHorizontal || isVertical
    }

    /// The move is leftward.
    public var isLeftward: Bool {
        return end.file < start.file
    }

    /// The move is rightward.
    public var isRightward: Bool {
        return end.file > start.file
    }

    /// The move is downward.
    public var isDownward: Bool {
        return end.rank < start.rank
    }

    /// The move is upward.
    public var isUpward: Bool {
        return end.rank > start.rank
    }

    /// The move is a knight jump two spaces horizontally and one space vertically, or two spaces vertically and one
    /// space horizontally.
    public var isKnightJump: Bool {
        let fileChange = abs(self.fileChange)
        let rankChange = abs(self.rankChange)
        return (fileChange == 2 && rankChange == 1)
            || (rankChange == 2 && fileChange == 1)
    }

    /// The move's direction in file, if any.
    public var fileDirection: File.Direction? {
        if self.isLeftward {
            return .left
        } else if self.isRightward {
            return .right
        } else {
            return .none
        }
    }

    /// The move's direction in rank, if any.
    public var rankDirection: Rank.Direction? {
        if self.isUpward {
            return .up
        } else if self.isDownward {
            return .down
        } else {
            return .none
        }
    }

    /// A textual representation of `self`.
    public var description: String {
        return "\(start) >>> \(end)"
    }

    /// The hash value.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(end)
    }

    /// Create a move with start and end squares.
    public init(start: Square, end: Square) {
        self.start = start
        self.end = end
    }

    /// Create a move with start and end locations.
    public init(start: Location, end: Location) {
        self.start = Square(location: start)
        self.end = Square(location: end)
    }

    /// A castle move for `color` in `direction`.
    public init(castle color: Color, direction: File.Direction) {
        let rank: Rank = color.isWhite ? 1 : 8
        self = Move(start: Square(file: .e, rank: rank), end: Square(file: direction == .left ? .c : .g, rank: rank))
    }

    /// Returns the castle squares for a rook.
    internal func _castleSquares() -> (old: Square, new: Square) {
        let rank = start.rank
        let movedLeft = self.isLeftward
        let old = Square(file: movedLeft ? .a : .h, rank: rank)
        let new = Square(file: movedLeft ? .d : .f, rank: rank)
        return (old, new)
    }

    /// Returns a move with the end and start of `self` reversed.
    public func reversed() -> Move {
        return Move(start: end, end: start)
    }

    /// Returns the result of rotating `self` 180 degrees.
    public func rotated() -> Move {
        let start = Square(file: self.start.file.opposite(),
                           rank: self.start.rank.opposite())
        let end = Square(file: self.end.file.opposite(),
                         rank: self.end.rank.opposite())
        return start >>> end
    }

    /// Returns `true` if `self` is castle move for `color`.
    ///
    /// - parameter color: The color to check the rank against. If `nil`, the rank can be either 1 or 8. The default
    ///                    value is `nil`.
    public func isCastle(for color: Color? = nil) -> Bool {
        let startRank = start.rank
        if let color = color {
            guard startRank == Rank(startFor: color) else { return false }
        } else {
            guard startRank == 1 || startRank == 8 else { return false }
        }
        let endFile = end.file
        return startRank == end.rank
            && start.file == ._e
            && (endFile == ._c || endFile == ._g)
    }

}

infix operator >>>

/// Returns `true` if both moves are the same.
public func == (lhs: Move, rhs: Move) -> Bool {
    return lhs.start == rhs.start && lhs.end == rhs.end
}

/// Returns a `Move` from the two squares.
public func >>> (start: Square, end: Square) -> Move {
    return Move(start: start, end: end)
}

/// Returns a `Move` from the two locations.
public func >>> (start: Location, rhs: Location) -> Move {
    return Square(location: start) >>> Square(location: rhs)
}
