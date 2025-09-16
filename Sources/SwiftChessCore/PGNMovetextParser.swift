import Foundation

struct PGNMovetextParser {

  private struct Context {
    var nextColor: Color
    var moveNumber: Int
  }

  private enum Token {
    case moveNumber(number: Int, dots: Int)
    case san(String)
    case result(Game.Outcome?)
    case nag(String)
    case comment(String)
    case variationStart
    case variationEnd
  }

  private struct Lexer {

    private let scalars: [Character]
    private var index: Int = 0
    private var pendingWord: String?

    init(source: String) {
      self.scalars = Array(source)
    }

    mutating func nextToken() throws -> Token? {
      if let pending = pendingWord {
        pendingWord = nil
        return try classifyWord(pending)
      }
      skipWhitespace()
      guard index < scalars.count else {
        return nil
      }
      let char = scalars[index]
      switch char {
      case "{" :
        let comment = try readBraceComment()
        return .comment(comment)
      case ";" :
        let comment = readSemicolonComment()
        return .comment(comment)
      case "(":
        index += 1
        return .variationStart
      case ")":
        index += 1
        return .variationEnd
      case "$":
        index += 1
        let digits = readDigits()
        return .nag(digits)
      default:
        let word = readWord()
        guard !word.isEmpty else {
          return try nextToken()
        }
        return try classifyWord(word)
      }
    }

    private mutating func classifyWord(_ word: String) throws -> Token {
      if let outcome = Game.Outcome(word) {
        return .result(outcome)
      }
      if word == "*" {
        return .result(nil)
      }
      if let (numberToken, remainder) = splitMoveNumber(from: word) {
        if let remainder {
          pendingWord = remainder
        }
        return numberToken
      }
      return .san(word)
    }

    private mutating func splitMoveNumber(from word: String) -> (Token, String?)? {
      var digitEnd = word.startIndex
      while digitEnd < word.endIndex, word[digitEnd].isNumber {
        digitEnd = word.index(after: digitEnd)
      }
      guard digitEnd > word.startIndex else { return nil }
      let numberSubstring = word[word.startIndex..<digitEnd]
      guard let number = Int(numberSubstring) else { return nil }
      var dotEnd = digitEnd
      while dotEnd < word.endIndex, word[dotEnd] == "." {
        dotEnd = word.index(after: dotEnd)
      }
      let dotCount = word.distance(from: digitEnd, to: dotEnd)
      guard dotCount > 0 else { return nil }
      let remainder = dotEnd < word.endIndex ? String(word[dotEnd..<word.endIndex]) : nil
      return (.moveNumber(number: number, dots: dotCount), remainder)
    }

    private mutating func skipWhitespace() {
      while index < scalars.count && scalars[index].isWhitespace {
        index += 1
      }
    }

    private mutating func readBraceComment() throws -> String {
      index += 1 // consume "{"
      var comment = ""
      while index < scalars.count {
        let char = scalars[index]
        if char == "}" {
          index += 1
          return comment
        }
        comment.append(char)
        index += 1
      }
      throw PGN.ParseError.noClosingBrace(comment)
    }

    private mutating func readSemicolonComment() -> String {
      index += 1 // consume ';'
      var comment = ""
      while index < scalars.count {
        let char = scalars[index]
        if char == "\n" || char == "\r" {
          break
        }
        comment.append(char)
        index += 1
      }
      return comment
    }

    private mutating func readDigits() -> String {
      var digits = ""
      while index < scalars.count, scalars[index].isNumber {
        digits.append(scalars[index])
        index += 1
      }
      return digits
    }

    private mutating func readWord() -> String {
      var word = ""
      while index < scalars.count {
        let char = scalars[index]
        if char.isWhitespace || char == "{" || char == "}" || char == "(" || char == ")" || char == ";" {
          break
        }
        word.append(char)
        index += 1
      }
      return word
    }

  }

  private var lexer: Lexer

  init(source: String) {
    self.lexer = Lexer(source: source)
  }

  mutating func parse() throws -> PGN.Movetext {
    var context = Context(nextColor: .white, moveNumber: 1)
    return try parseMovetext(context: &context, stopAtVariationEnd: false)
  }

  private mutating func parseMovetext(context: inout Context, stopAtVariationEnd: Bool) throws -> PGN.Movetext {
    var moves: [PGN.Move] = []
    var leadingComments: [String] = []
    var leadingVariations: [PGN.Movetext] = []
    var trailingComments: [String] = []
    var result: Game.Outcome? = nil

    var pendingCommentsBeforeNextMove: [String] = []
    var pendingMoveNumber: Int? = nil
    var pendingColorOverride: Color? = nil
    var attachToLastMove = false

    while let token = try lexer.nextToken() {
      switch token {
      case .comment(let rawComment):
        let comment = rawComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !comment.isEmpty else { continue }
        if result != nil {
          trailingComments.append(comment)
        } else if attachToLastMove, !moves.isEmpty {
          moves[moves.count - 1].commentsAfter.append(comment)
        } else if moves.isEmpty {
          leadingComments.append(comment)
        } else {
          pendingCommentsBeforeNextMove.append(comment)
        }
      case .nag(let glyph):
        if !moves.isEmpty {
          moves[moves.count - 1].nags.append(glyph)
          attachToLastMove = true
        } else {
          pendingCommentsBeforeNextMove.append("$\(glyph)")
        }
      case .moveNumber(let number, let dots):
        pendingMoveNumber = number
        pendingColorOverride = dots >= 3 ? .black : .white
        attachToLastMove = false
      case .san(let notation):
        guard result == nil else {
          trailingComments.append(notation)
          continue
        }
        var color = pendingColorOverride ?? context.nextColor
        let moveNumber = pendingMoveNumber ?? context.moveNumber
        if pendingColorOverride == nil && color != context.nextColor {
          color = context.nextColor
        }
        if pendingMoveNumber != nil {
          context.moveNumber = moveNumber
        }
        if color == .white {
          context.nextColor = .black
        } else {
          context.nextColor = .white
          context.moveNumber = moveNumber + 1
        }
        let move = PGN.Move(
          number: moveNumber,
          side: color,
          notation: notation,
          nags: [],
          commentsBefore: pendingCommentsBeforeNextMove,
          commentsAfter: [],
          variations: []
        )
        pendingCommentsBeforeNextMove = []
        moves.append(move)
        attachToLastMove = true
        pendingMoveNumber = nil
        pendingColorOverride = nil
      case .variationStart:
        var variationContext: Context
        if let anchor = moves.last, let side = anchor.side, let number = anchor.number {
          variationContext = Context(nextColor: side, moveNumber: number)
        } else {
          variationContext = context
        }
        let variation = try parseMovetext(context: &variationContext, stopAtVariationEnd: true)
        if !moves.isEmpty {
          moves[moves.count - 1].variations.append(variation)
        } else {
          leadingVariations.append(variation)
        }
        attachToLastMove = true
      case .variationEnd:
        if stopAtVariationEnd {
          if !pendingCommentsBeforeNextMove.isEmpty {
            trailingComments.append(contentsOf: pendingCommentsBeforeNextMove)
          }
          return PGN.Movetext(
            leadingComments: leadingComments,
            leadingVariations: leadingVariations,
            moves: moves,
            trailingComments: trailingComments,
            result: result
          )
        } else {
          throw PGN.ParseError.parenthesisCountForRAV("")
        }
      case .result(let outcome):
        result = outcome
        attachToLastMove = false
      }
    }

    if stopAtVariationEnd {
      throw PGN.ParseError.parenthesisCountForRAV("")
    }
    if !pendingCommentsBeforeNextMove.isEmpty {
      trailingComments.append(contentsOf: pendingCommentsBeforeNextMove)
    }
    return PGN.Movetext(
      leadingComments: leadingComments,
      leadingVariations: leadingVariations,
      moves: moves,
      trailingComments: trailingComments,
      result: result
    )
  }

}
