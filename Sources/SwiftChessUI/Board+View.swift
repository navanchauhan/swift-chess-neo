#if canImport(AppKit) || canImport(UIKit)
import SwiftChessCore

#if canImport(AppKit)
import AppKit
fileprivate typealias _View = NSView
fileprivate typealias _Color = NSColor
fileprivate typealias _Label = NSText
#elseif canImport(UIKit)
import UIKit
fileprivate typealias _View = UIView
fileprivate typealias _Color = UIColor
fileprivate typealias _Label = UILabel
#endif

extension Board.Space {
  // Mirrors the original playground helper while keeping the core target UI-free.
  fileprivate func _view(size: CGFloat) -> _View {
    #if canImport(AppKit)
    let rectY = CGFloat(rank.index) * size
    #else
    let rectY = CGFloat(7 - rank.index) * size
    #endif
    let frame = CGRect(
      x: CGFloat(file.index) * size,
      y: rectY,
      width: size,
      height: size)
    let textFrame = CGRect(x: 0, y: 0, width: size, height: size)
    let fontSize = size * 0.625
    let view = _View(frame: frame)
    let str = piece.map({ String($0.specialCharacter(background: color)) }) ?? ""
    let white = _Color.white
    let black = _Color.black
    let bg: _Color = color.isWhite ? white : black
    let tc: _Color = color.isWhite ? black : white
    #if canImport(AppKit)
    view.wantsLayer = true
    view.layer?.backgroundColor = bg.cgColor
    let text = _Label(frame: textFrame)
    text.alignment = .center
    text.font = .systemFont(ofSize: fontSize)
    text.isEditable = false
    text.isSelectable = false
    text.string = str
    text.drawsBackground = false
    text.textColor = tc
    view.addSubview(text)
    #else
    view.backgroundColor = bg
    let label = _Label(frame: textFrame)
    label.textAlignment = .center
    label.font = .systemFont(ofSize: fontSize)
    label.text = str
    label.textColor = tc
    view.addSubview(label)
    #endif
    return view
  }
}

extension Board: CustomPlaygroundDisplayConvertible {
  /// Returns the `playgroundDescription` for `self`.
  private var _playgroundDescription: _View {
    let spaceSize: CGFloat = 80
    let boardSize = spaceSize * 8
    let frame = CGRect(x: 0, y: 0, width: boardSize, height: boardSize)
    let view = _View(frame: frame)

    for space in self {
      view.addSubview(space._view(size: spaceSize))
    }
    return view
  }

  /// A custom playground description for this instance.
  public var playgroundDescription: Any {
    return _playgroundDescription
  }
}
#endif
