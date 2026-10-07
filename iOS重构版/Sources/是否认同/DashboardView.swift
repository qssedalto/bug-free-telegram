import SwiftUI

private enum DashboardTab: String, CaseIterable, Identifiable {
    case overview = "概览"
    case trend = "增长折线图"
    case history = "历史与成就"
    var id: String { rawValue }
}

struct DataDashboardView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var runtime: RuntimeStore
    @Environment(\.dismiss) private var dismiss
    @State private var tab: DashboardTab = .overview
    @State private var market = MarketQuote()
    @State private var loadingMarket = false
    @State private var confirmReset = false

    private var current: AmountDisplay { DebtEngine.amount(on: Date(), preferences: preferences) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("数据页面", selection: $tab) {
                    ForEach(DashboardTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(10)
                .liquidGlassSurface(
                    cornerRadius: 20,
                    tint: preferences.accentColor.opacity(0.06),
                    interactive: true
                )
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)

                Group {
                    switch tab {
                    case .overview: overview
                    case .trend: trend
                    case .history: history
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background { LiquidGlassBackdrop() }
            .navigationTitle("数据面板")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.large])
        .task { await refreshMarket() }
        .alert("重新开始剧情？", isPresented: $confirmReset) {
            Button("取消", role: .cancel) {}
            Button("清空并重置", role: .destructive) { runtime.resetStory() }
        } message: { Text("选择记录、剧情进度和成就会归零；金额设置与每日快照不受影响。") }
    }

    private var overview: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 14)], spacing: 14) {
                amountSummary
                comparisonCard
                predictionCard
                marketCard
                formulaCard
            }
            .padding([.horizontal, .bottom])
            .frame(maxWidth: 1200)
            .frame(maxWidth: .infinity)
        }
    }

    private var amountSummary: some View {
        dashboardCard(title: "当前金额", icon: "banknote.fill") {
            Text("￥\(current.grouped) 元")
                .font(.title2.monospacedDigit().weight(.black))
                .lineLimit(3).minimumScaleFactor(0.38)
            Text("人民币：\(current.chinese)").font(.caption.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            if current.isCapped { Label("已达到 99 位上限", systemImage: "exclamationmark.shield.fill").foregroundStyle(.orange) }
        }
    }

    private var comparisonCard: some View {
        dashboardCard(title: "过去金额对比", icon: "clock.arrow.circlepath") {
            amountLine("昨日", date: Date().addingDays(-1))
            amountLine("七日前", date: Date().addingDays(-7))
            amountLine("三十日前", date: Date().addingDays(-30))
        }
    }

    private var predictionCard: some View {
        dashboardCard(title: "未来金额预测", icon: "calendar.badge.clock") {
            amountLine("明日", date: Date().addingDays(1))
            amountLine("一周后", date: Date().addingDays(7))
            amountLine("一年后", date: Date().addingDays(365))
        }
    }

    private var marketCard: some View {
        dashboardCard(title: "多市场实时估值", icon: "network") {
            if loadingMarket {
                ProgressView("正在选择可用行情源…")
            } else {
                marketLine("比特币", value: "\(market.btc) BTC")
                marketLine("美元", value: "$\(market.usd)")
                marketLine("欧元", value: "€\(market.eur)")
                marketLine("日元", value: "¥\(market.jpy)")
                marketLine("港币", value: "HK$\(market.hkd)")
                marketLine("黄金重量", value: "\(market.goldTons) 吨")
                Divider()
                Text(market.source).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("重新获取") { Task { await refreshMarket() } }
                    .liquidGlassButtonStyle(tint: preferences.accentColor)
            }
        }
    }

    private var formulaCard: some View {
        dashboardCard(title: "运行参数", icon: "function") {
            Label("当前运行：\(DebtEngine.days(on: Date(), preferences: preferences) + 1) 天", systemImage: "calendar")
            Text("锚点日期：\(preferences.startDate.formatted(date: .numeric, time: .omitted))")
            Text("初始金额：￥\(preferences.initialAmount)")
            Text("公式：初始金额 × 1.05 ^ 经过天数，按元四舍五入")
            Text("安全策略：十进制大整数计算；结果最多显示 99 位")
                .foregroundStyle(.secondary)
        }
    }

    private var trend: some View {
        ScrollView {
            VStack(spacing: 16) {
                dashboardCard(title: "近三十日欠款增长", icon: "chart.line.uptrend.xyaxis") {
                    TrendChartView(points: (0...30).map { offset in
                        let date = Date().addingDays(-30 + offset)
                        return TrendPoint(date: date, amount: DebtEngine.amount(on: date, preferences: preferences))
                    })
                    .frame(height: 360)
                    Text("纵轴采用对数刻度，使大金额变化仍能完整显示。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                dashboardCard(title: "每日金额快照", icon: "camera.fill") {
                    Text("已保存 \(runtime.snapshots.count) 个本地快照，最多保留 3,660 天。")
                    ForEach(runtime.snapshots.suffix(7).reversed()) { snapshot in
                        HStack {
                            Text(snapshot.day).font(.caption.monospacedDigit())
                            Spacer()
                            Text("￥\(group(snapshot.digits))").font(.caption.monospacedDigit()).lineLimit(1)
                        }
                    }
                }
            }
            .padding([.horizontal, .bottom])
            .frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }
    }

    private var history: some View {
        ScrollView {
            VStack(spacing: 16) {
                dashboardCard(title: "连续签到与成就", icon: "trophy.fill") {
                    Text("连续签到：\(runtime.streak) 天").font(.title3.weight(.black))
                    if runtime.achievements.isEmpty {
                        Text("暂无成就，继续探索三个剧情分支。")
                    } else {
                        FlowLayout(spacing: 8) {
                            ForEach(runtime.achievements, id: \.self) { achievement in
                                Label(achievement, systemImage: "star.fill")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10).padding(.vertical, 7)
                                    .background(preferences.accentColor.opacity(0.14), in: Capsule())
                            }
                        }
                    }
                }
                dashboardCard(title: "选择记录", icon: "list.bullet.rectangle.portrait") {
                    if runtime.choices.isEmpty { Text("还没有选择记录。") }
                    ForEach(runtime.choices.suffix(100).reversed()) { record in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(record.choice).font(.subheadline.weight(.bold))
                                Spacer()
                                Text(record.time.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            Text(record.result).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Divider()
                    }
                }
                Button(role: .destructive) { confirmReset = true } label: {
                    Label("重新开始剧情", systemImage: "arrow.counterclockwise.circle.fill")
                        .font(.headline).frame(maxWidth: 360, minHeight: 50)
                }
                .liquidGlassButtonStyle(prominent: true, tint: .red)
            }
            .padding([.horizontal, .bottom])
            .frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func dashboardCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: icon).font(.headline).foregroundStyle(preferences.accentColor)
                Divider()
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(19)
        }
    }

    private func amountLine(_ name: String, date: Date) -> some View {
        let value = DebtEngine.amount(on: date, preferences: preferences)
        return HStack(alignment: .firstTextBaseline) {
            Text(name).foregroundStyle(.secondary)
            Spacer()
            Text("￥\(value.grouped)").font(.subheadline.monospacedDigit().weight(.bold)).lineLimit(2).minimumScaleFactor(0.45)
        }
    }

    private func marketLine(_ name: String, value: String) -> some View {
        HStack { Text(name).foregroundStyle(.secondary); Spacer(); Text(value).font(.subheadline.monospacedDigit().weight(.bold)) }
    }

    private func refreshMarket() async {
        loadingMarket = true
        market = await MarketService.fetch(for: current)
        loadingMarket = false
    }

    private func group(_ digits: String) -> String {
        AmountDisplay(digits: digits, chinese: "", isCapped: false).grouped
    }
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let amount: AmountDisplay
}

struct TrendChartView: View {
    let points: [TrendPoint]
    var body: some View {
        GeometryReader { proxy in
            let labelsHeight: CGFloat = 30
            let chartHeight = max(1, proxy.size.height - labelsHeight)
            let values = points.map { $0.amount.log10 }
            let minimum = values.min() ?? 0
            let maximum = max(values.max() ?? 1, minimum + 0.0001)
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 16).fill(.primary.opacity(0.035))
                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = proxy.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                        let y = chartHeight * (1 - CGFloat((value - minimum) / (maximum - minimum)))
                        index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.purple.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                HStack {
                    Text(points.first?.date.formatted(.dateTime.month().day()) ?? "")
                    Spacer()
                    Text("今天 ↗")
                }
                .font(.caption.weight(.semibold)).padding(.horizontal, 8).frame(height: labelsHeight)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? 0, subviews: subviews).size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(width: bounds.width, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }
    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        var points: [CGPoint] = []
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > width { x = 0; y += rowHeight + spacing; rowHeight = 0 }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: width, height: y + rowHeight), points)
    }
}
