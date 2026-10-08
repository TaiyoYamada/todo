#if DEBUG
    import DesignSystem
    import Domain
    import SwiftUI
    import WidgetKit

    /// ウィジェットの見た目を、アプリの中で確かめるための画面(開発用)。
    ///
    /// ホーム画面にウィジェットを置かなくても、各状態と各サイズの配置をまとめて見られる。
    /// 本物のウィジェットと同じ View を、同じくらいの大きさの枠に入れて並べている。
    /// 枠の背景は OS が描くものを真似ているだけなので、細部は実物と違う。
    public struct WidgetGallery: View {
        private let worlds: [(name: String, world: World)]
        private let now: Date

        /// - Parameter worlds: 見せたい状態の名前と、その保存データ。
        public init(worlds: [(name: String, world: World)], now: Date = .now) {
            self.worlds = worlds
            self.now = now
        }

        public var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(worlds, id: \.name) { item in
                        let entry = SlackEntry(
                            date: now,
                            status: LockEngine(calendar: .current).status(world: item.world, now: now)
                        )
                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            HStack(alignment: .top, spacing: 12) {
                                frame(entry, family: .systemSmall, size: CGSize(width: 158, height: 158))
                                VStack(alignment: .leading, spacing: 12) {
                                    lockScreen(entry, family: .accessoryRectangular)
                                        .frame(width: 160, height: 66, alignment: .leading)
                                    lockScreen(entry, family: .accessoryInline)
                                        .frame(width: 160, alignment: .leading)
                                }
                            }
                            frame(entry, family: .systemMedium, size: CGSize(width: 338, height: 158))
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.black)
        }

        /// ホーム画面のウィジェット。背景のグラデーションを、実物と同じ色で敷く。
        private func frame(_ entry: SlackEntry, family: WidgetFamily, size: CGSize) -> some View {
            let mood = SlackContent(entry: entry).mood
            return SlackWidgetBody(entry: entry, family: family)
                .padding(16)
                .frame(width: size.width, height: size.height)
                .background(
                    LinearGradient(
                        colors: [mood.backdrop[1], mood.backdrop[2], mood.backdrop[3]],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(.rect(cornerRadius: 24))
        }

        /// ロック画面のウィジェット。白い文字で出る。
        private func lockScreen(_ entry: SlackEntry, family: WidgetFamily) -> some View {
            SlackWidgetBody(entry: entry, family: family)
                .foregroundStyle(.white)
        }
    }
#endif
