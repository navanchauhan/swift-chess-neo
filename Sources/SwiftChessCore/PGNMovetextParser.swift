import Foundation

struct PGNMovetextParser {

  private struct Context {
    var nextColor: Color
    var moveNumber: Int
  }

  private enum Token {
    case moveNumber(number: Int, dots: Int, position: Int)
    case san(String, position: Int)
    case result(Game.Outcome?, position: Int)
    case nag(String, position: Int)
    case comment(String, position: Int)
    case variationStart(position: Int)
    case variationEnd(position: Int)
  }

  private struct Lexer {

    enum Error: Swift.Error {
      case unclosedBrace(start: Int, partial: String)
    }

    private let scalars: [Character]
    private var index: Int = 0
    private var pendingWord: (text: String, position: Int)?
    private(set) var lastTokenStart: Int = 0

    init(source: String) {
      self.scalars = Array(source)
    }

    var currentIndex: Int {
      index
    }

    mutating func nextToken() throws -> Token? {
      if let pending = pendingWord {
        pendingWord = nil
        return try classifyWord(pending.text, position: pending.position)
      }

      skipWhitespace()
      guard index < scalars.count else {
        return nil
      }

      lastTokenStart = index
      let char = scalars[index]
      switch char {
      case "{":
        index += 1 // consume '{'
        do {
          let comment = try readBraceComment()
          return .comment(comment, position: lastTokenStart)
        } catch {
          if let lexerError = error as? Error {
            throw lexerError
          }
          throw error
        }
      case ";":
        index += 1
        let comment = readSemicolonComment()
        return .comment(comment, position: lastTokenStart)
      case "(":
        index += 1
        return .variationStart(position: lastTokenStart)
      case ")":
        index += 1
        return .variationEnd(position: lastTokenStart)
      case "$":
        index += 1
        let digits = readDigits()
        return .nag(digits, position: lastTokenStart)
      default:
        let word = readWord()
        guard !word.isEmpty else {
          return try nextToken()
        }
        return try classifyWord(word, position: lastTokenStart)
      }
    }

    private mutating func classifyWord(_ word: String, position: Int) throws -> Token {
      if let outcome = Game.Outcome(word) {
        return .result(outcome, position: position)
      }
      if word == "*" {
        return .result(nil, position: position)
      }
      if let (numberToken, remainder) = splitMoveNumber(from: word, position: position) {
        if let remainder {
          pendingWord = remainder
        }
        return numberToken
      }
      return .san(word, position: position)
    }

    private mutating func splitMoveNumber(
      from word: String,
      position: Int
    ) -> (Token, (text: String, position: Int)?)? {
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
      let consumed = word.distance(from: word.startIndex, to: dotEnd)
      let remainder: (text: String, position: Int)?
      if dotEnd < word.endIndex {
        remainder = (String(word[dotEnd..<word.endIndex]), position + consumed)
      } else {
        remainder = nil
      }
      return (.moveNumber(number: number, dots: dotCount, position: position), remainder)
    }

    private mutating func skipWhitespace() {
      while index < scalars.count && scalars[index].isWhitespace {
        index += 1
      }
    }

    private mutating func readBraceComment() throws -> String {
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
      throw Error.unclosedBrace(start: lastTokenStart, partial: comment)
    }

    private mutating func readSemicolonComment() -> String {
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

    func location(for position: Int) -> (line: Int, column: Int) {
      var line = 1
      var column = 1
      var idx = 0
      let limit = min(position, scalars.count)
      while idx < limit {
        if scalars[idx] == "\n" {
          line += 1
          column = 1
        } else {
          column += 1
        }
        idx += 1
      }
      return (line, column)
    }
  }

  private var lexer: Lexer

  init(source: String) {
    self.lexer = Lexer(source: source)
  }

  mutating func parse() throws -> PGN.Movetext {
    var context = Context(nextColor: .white, moveNumber: 1)
    return try parseMovetext(context: &context, stopAtVariationEnd: false, variationStart: nil)
  }

  private mutating func parseMovetext(
    context: inout Context,
    stopAtVariationEnd: Bool,
    variationStart: Int?
  ) throws -> PGN.Movetext {
    var moves: [PGN.Move] = []
    var leadingComments: [String] = []
    var leadingVariations: [PGN.Movetext] = []
    var trailingComments: [String] = []
    var result: Game.Outcome? = nil
    var diagnostics: [PGN.Movetext.Diagnostic] = []

    var pendingCommentsBeforeNextMove: [String] = []
    var pendingMoveNumber: Int? = nil
    var pendingColorOverride: Color? = nil
    var attachToLastMove = false

    tokenLoop: while true {
      do {
        guard let token = try lexer.nextToken() else {
          break
        }
        switch token {
        case .comment(let rawComment, _):
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
        case .nag(let glyph, _):
          if !moves.isEmpty {
            moves[moves.count - 1].nags.append(glyph)
            attachToLastMove = true
          } else {
            pendingCommentsBeforeNextMove.append("$\(glyph)")
          }
        case .moveNumber(let number, let dots, _):
          pendingMoveNumber = number
          pendingColorOverride = dots >= 3 ? .black : .white
          attachToLastMove = false
        case .san(let notation, _):
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
        case .variationStart(let position):
          var variationContext: Context
          if let anchor = moves.last, let side = anchor.side, let number = anchor.number {
            variationContext = Context(nextColor: side, moveNumber: number)
          } else {
            variationContext = context
          }
          let variation = try parseMovetext(
            context: &variationContext,
            stopAtVariationEnd: true,
            variationStart: position
          )
          if !moves.isEmpty {
            moves[moves.count - 1].variations.append(variation)
          } else {
            leadingVariations.append(variation)
          }
          diagnostics.append(contentsOf: variation.diagnostics)
          attachToLastMove = true
        case .variationEnd(let position):
          if stopAtVariationEnd {
            if !pendingCommentsBeforeNextMove.isEmpty {
              trailingComments.append(contentsOf: pendingCommentsBeforeNextMove)
            }
            return PGN.Movetext(
              leadingComments: leadingComments,
              leadingVariations: leadingVariations,
              moves: moves,
              trailingComments: trailingComments,
              result: result,
              diagnostics: diagnostics
            )
          } else {
            appendDiagnostic(
              "Unexpected ')' without matching '('",
              at: position,
              to: &diagnostics
            )
          }
        case .result(let outcome, let position):
          if result != nil {
            appendDiagnostic(
              "Multiple result markers found; keeping the first one",
              level: .warning,
              at: position,
              to: &diagnostics
            )
          } else {
            result = outcome
          }
          attachToLastMove = false
        }
      } catch let error as Lexer.Error {
        switch error {
        case .unclosedBrace(let start, let partial):
          let comment = partial.trimmingCharacters(in: .whitespacesAndNewlines)
          if !comment.isEmpty {
            if result != nil {
              trailingComments.append(comment)
            } else if attachToLastMove, !moves.isEmpty {
              moves[moves.count - 1].commentsAfter.append(comment)
            } else if moves.isEmpty {
              leadingComments.append(comment)
            } else {
              pendingCommentsBeforeNextMove.append(comment)
            }
          }
          appendDiagnostic(
            "Missing closing '}' for comment",
            at: start,
            to: &diagnostics
          )
        }
        break tokenLoop
      }
    }

    if stopAtVariationEnd {
      let anchor = variationStart ?? lexer.currentIndex
      appendDiagnostic(
        "Missing ')' to close variation",
        at: anchor,
        to: &diagnostics
      )
    }
    if !pendingCommentsBeforeNextMove.isEmpty {
      trailingComments.append(contentsOf: pendingCommentsBeforeNextMove)
    }
    return PGN.Movetext(
      leadingComments: leadingComments,
      leadingVariations: leadingVariations,
      moves: moves,
      trailingComments: trailingComments,
      result: result,
      diagnostics: diagnostics
    )
  }

  private mutating func appendDiagnostic(
    _ message: String,
    level: PGN.Movetext.Diagnostic.Level = .error,
    at position: Int,
    to diagnostics: inout [PGN.Movetext.Diagnostic]
  ) {
    let location = lexer.location(for: position)
    diagnostics.append(
      PGN.Movetext.Diagnostic(
        level: level,
        message: message,
        line: location.line,
        column: location.column
      )
    )
  }

}
