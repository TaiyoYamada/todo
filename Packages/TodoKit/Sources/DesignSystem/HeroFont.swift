import SwiftUI
import UIKit

public extension Font {
    /// 画面の主役に使う、丸みのある太い文字。
    ///
    /// 大きさは利用者の文字サイズの設定に合わせて変わる。ただし、もともと大きい文字なので、
    /// 広がりすぎて画面からはみ出さないように、拡大は 1.35 倍までにする。
    static func hero(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        let scaled = UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: size)
        return .system(size: min(scaled, size * 1.35), weight: weight, design: .rounded)
    }
}
