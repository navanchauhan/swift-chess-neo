#if canImport(SwiftUI) && DEBUG
import SwiftUI
import SwiftChessCore

struct BoardView_Previews: PreviewProvider {
  static var previews: some View {
    let state = BoardState()
    return Group {
      BoardView(state: state, theme: .classic)
        .frame(width: 320, height: 320)
        .previewDisplayName("Classic")

      BoardView(state: state, theme: BoardTheme(
        lightSquare: Color(red: 0.94, green: 0.95, blue: 0.96),
        darkSquare: Color(red: 0.23, green: 0.32, blue: 0.45),
        selectionBorder: .orange,
        legalIndicator: Color.orange.opacity(0.4),
        captureIndicator: Color.red.opacity(0.5),
        lastMoveFill: Color.yellow.opacity(0.3),
        checkFill: Color.red.opacity(0.35),
        hoverFill: Color.blue.opacity(0.2),
        whitePiece: .white,
        blackPiece: .black,
        moveAnimation: .spring(response: 0.25, dampingFraction: 0.7),
        selectionBorderWidth: 3,
        captureIndicatorLineWidth: 4,
        legalIndicatorDiameterRatio: 0.22,
        pieceScale: 0.7
      ))
      .frame(width: 320, height: 320)
      .previewDisplayName("Ocean")
    }
  }
}
#endif
