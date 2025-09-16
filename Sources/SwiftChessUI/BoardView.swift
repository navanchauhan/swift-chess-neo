#if canImport(SwiftUI)
import SwiftUI
import SwiftChessCore

public struct BoardTheme {
  public var lightSquare: SwiftUI.Color
  public var darkSquare: SwiftUI.Color
  public var selectionBorder: SwiftUI.Color
  public var legalIndicator: SwiftUI.Color
  public var captureIndicator: SwiftUI.Color
  public var lastMoveFill: SwiftUI.Color
  public var checkFill: SwiftUI.Color
  public var hoverFill: SwiftUI.Color
  public var whitePiece: SwiftUI.Color
  public var blackPiece: SwiftUI.Color
  public var moveAnimation: Animation
  public var selectionBorderWidth: CGFloat
  public var captureIndicatorLineWidth: CGFloat
  public var legalIndicatorDiameterRatio: CGFloat
  public var pieceScale: CGFloat

  public init(
    lightSquare: SwiftUI.Color = SwiftUI.Color(red: 0.92, green: 0.85, blue: 0.70),
    darkSquare: SwiftUI.Color = SwiftUI.Color(red: 0.54, green: 0.40, blue: 0.24),
    selectionBorder: SwiftUI.Color = .blue,
    legalIndicator: SwiftUI.Color = SwiftUI.Color.blue.opacity(0.35),
    captureIndicator: SwiftUI.Color = SwiftUI.Color.red.opacity(0.55),
    lastMoveFill: SwiftUI.Color = SwiftUI.Color.yellow.opacity(0.35),
    checkFill: SwiftUI.Color = SwiftUI.Color.red.opacity(0.35),
    hoverFill: SwiftUI.Color = SwiftUI.Color.gray.opacity(0.25),
    whitePiece: SwiftUI.Color = .white,
    blackPiece: SwiftUI.Color = .black,
    moveAnimation: Animation = .easeInOut(duration: 0.18),
    selectionBorderWidth: CGFloat = 4,
    captureIndicatorLineWidth: CGFloat = 5,
    legalIndicatorDiameterRatio: CGFloat = 0.28,
    pieceScale: CGFloat = 0.72
  ) {
    self.lightSquare = lightSquare
    self.darkSquare = darkSquare
    self.selectionBorder = selectionBorder
    self.legalIndicator = legalIndicator
    self.captureIndicator = captureIndicator
    self.lastMoveFill = lastMoveFill
    self.checkFill = checkFill
    self.hoverFill = hoverFill
    self.whitePiece = whitePiece
    self.blackPiece = blackPiece
    self.moveAnimation = moveAnimation
    self.selectionBorderWidth = selectionBorderWidth
    self.captureIndicatorLineWidth = captureIndicatorLineWidth
    self.legalIndicatorDiameterRatio = legalIndicatorDiameterRatio
    self.pieceScale = pieceScale
  }

  public static let classic = BoardTheme()

  public func symbol(for piece: Piece) -> String {
    String(piece.specialCharacter())
  }

  public func pieceColor(for piece: Piece) -> SwiftUI.Color {
    piece.color.isWhite ? whitePiece : blackPiece
  }

  public func pieceFont(squareSize: CGFloat) -> Font {
    .system(size: squareSize * pieceScale)
  }
}

public struct BoardView: View {
  @ObservedObject private var state: BoardState
  private let theme: BoardTheme
  private let showsCoordinates: Bool

  public init(state: BoardState, theme: BoardTheme = .classic, showsCoordinates: Bool = true) {
    self.state = state
    self.theme = theme
    self.showsCoordinates = showsCoordinates
  }

  public var body: some View {
    GeometryReader { proxy in
      let side = min(proxy.size.width, proxy.size.height)
      let squareSize = side / 8
      let origin = CGPoint(
        x: (proxy.size.width - side) / 2,
        y: (proxy.size.height - side) / 2
      )

      ZStack(alignment: .topLeading) {
        ForEach(state.squares) { model in
          SquareCell(model: model, theme: theme, squareSize: squareSize)
            .frame(width: squareSize, height: squareSize)
            .offset(
              x: origin.x + CGFloat(model.column) * squareSize,
              y: origin.y + CGFloat(model.row) * squareSize
            )
            .contentShape(Rectangle())
            .onTapGesture {
              state.handleTap(on: model.square)
            }
        }

        if showsCoordinates {
          coordinateOverlay(squareSize: squareSize, origin: origin, side: side)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
      .animation(theme.moveAnimation, value: state.squares)
      .gesture(boardDragGesture(squareSize: squareSize, origin: origin))
      .sheet(item: $state.promotionRequest) { request in
        PromotionPicker(
          request: request,
          theme: theme,
          onSelect: { state.promote(with: $0) },
          onCancel: { state.cancelPromotion() }
        )
      }
    }
  }

  private func boardDragGesture(squareSize: CGFloat, origin: CGPoint) -> some Gesture {
    DragGesture(minimumDistance: 1, coordinateSpace: .local)
      .onChanged { value in
        let start = square(at: value.startLocation, squareSize: squareSize, origin: origin)
        let current = square(at: value.location, squareSize: squareSize, origin: origin)
        state.handleDrag(start: start, current: current)
      }
      .onEnded { value in
        let start = square(at: value.startLocation, squareSize: squareSize, origin: origin)
        let end = square(at: value.location, squareSize: squareSize, origin: origin)
        state.completeDrag(start: start, end: end)
      }
  }

  private func square(at location: CGPoint, squareSize: CGFloat, origin: CGPoint) -> Square? {
    let x = location.x - origin.x
    let y = location.y - origin.y
    guard x >= 0, y >= 0 else { return nil }
    let side = squareSize * 8
    guard x < side, y < side else { return nil }
    let column = Int(x / squareSize)
    let row = Int(y / squareSize)
    return state.squareForDisplay(row: row, column: column)
  }

  private func coordinateOverlay(squareSize: CGFloat, origin: CGPoint, side: CGFloat) -> some View {
    let rankLabels = state.orientation.isWhite
      ? Rank.all.reversed().map { String($0.rawValue) }
      : Rank.all.map { String($0.rawValue) }
    let fileLabels = state.orientation.isWhite
      ? File.all.map { String($0.character) }
      : File.all.reversed().map { String($0.character) }

    return ZStack {
      ForEach(0..<8, id: \.self) { index in
        Text(rankLabels[index])
          .font(.caption2)
          .foregroundStyle(.secondary)
          .position(
            x: origin.x - squareSize * 0.25,
            y: origin.y + CGFloat(index) * squareSize + squareSize * 0.5
          )
      }

      ForEach(0..<8, id: \.self) { index in
        Text(fileLabels[index])
          .font(.caption2)
          .foregroundStyle(.secondary)
          .position(
            x: origin.x + CGFloat(index) * squareSize + squareSize * 0.5,
            y: origin.y + side + squareSize * 0.25
          )
      }
    }
  }
}

private struct SquareCell: View {
  let model: BoardState.SquareModel
  let theme: BoardTheme
  let squareSize: CGFloat

  var body: some View {
    let baseColor = model.isDark ? theme.darkSquare : theme.lightSquare
    ZStack {
      Rectangle()
        .fill(baseColor)

      if model.highlights.contains(.lastMoveOrigin) || model.highlights.contains(.lastMoveDestination) {
        Rectangle()
          .fill(theme.lastMoveFill)
      }

      if model.highlights.contains(.check) {
        Rectangle()
          .fill(theme.checkFill)
      }

      if model.highlights.contains(.hover) {
        Rectangle()
          .fill(theme.hoverFill)
      }

      if model.highlights.contains(.legalMove) {
        if model.highlights.contains(.capture) {
          Circle()
            .stroke(theme.captureIndicator, lineWidth: theme.captureIndicatorLineWidth)
            .frame(width: squareSize * 0.65, height: squareSize * 0.65)
        } else {
          Circle()
            .fill(theme.legalIndicator)
            .frame(
              width: squareSize * theme.legalIndicatorDiameterRatio,
              height: squareSize * theme.legalIndicatorDiameterRatio
            )
        }
      }

      if let piece = model.piece {
        Text(theme.symbol(for: piece))
          .font(theme.pieceFont(squareSize: squareSize))
          .foregroundColor(theme.pieceColor(for: piece))
      }

      if model.highlights.contains(.selected) {
        RoundedRectangle(cornerRadius: squareSize * 0.1)
          .stroke(theme.selectionBorder, lineWidth: theme.selectionBorderWidth)
      }
    }
    .drawingGroup()
  }
}

private struct PromotionPicker: View {
  let request: BoardState.PromotionRequest
  let theme: BoardTheme
  let onSelect: (Piece.Kind) -> Void
  let onCancel: () -> Void

  var body: some View {
    NavigationStack {
      List {
        Section("Promote to") {
          ForEach(request.options, id: \.self) { option in
            Button {
              onSelect(option)
            } label: {
              HStack {
                Text(pieceName(for: option, color: request.color))
                Spacer()
                Text(theme.symbol(for: Piece(kind: option, color: request.color)))
              }
            }
          }
        }
      }
      .navigationTitle("Promotion")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel", action: onCancel)
        }
      }
    }
  }

  private func pieceName(for kind: Piece.Kind, color: SwiftChessCore.Color) -> String {
    Piece(kind: kind, color: color).getNaturalName()
  }
}
#endif
