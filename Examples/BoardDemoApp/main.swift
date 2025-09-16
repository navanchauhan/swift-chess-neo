#if canImport(SwiftUI)
import SwiftUI
import SwiftChessCore
import SwiftChessUI

@main
struct BoardDemoApp: App {
  @StateObject private var boardState = BoardState()

  var body: some Scene {
    WindowGroup {
      VStack(spacing: 24) {
        BoardView(state: boardState, theme: .classic)
          .aspectRatio(1, contentMode: .fit)
          .padding()

        HStack {
          Button("Rotate") { boardState.rotateBoard() }
          Button("Reset") { boardState.reset() }
        }
        .buttonStyle(.borderedProminent)
      }
      .padding()
      .frame(minWidth: 480, minHeight: 600)
    }
  }
}
#else
import Foundation

@main
struct BoardDemoFallback {
  static func main() {
    print("BoardDemoApp requires SwiftUI and an Apple platform.")
  }
}
#endif
