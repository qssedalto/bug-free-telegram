import SwiftUI
import UIKit

struct StorySession: Identifiable {
    let id = UUID()
    let branch: StoryBranch
    let index: Int
}

struct ContentView: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var runtime: RuntimeStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var activeStory: StorySession?
    @State private var showDashboard = false
    @State private var showSettings = false
    @State private var titleTapCount = 0
    @State private var secretMessage: String?

    private var amount: AmountDisplay { DebtEngine.amount(on: Date(), preferences: preferences) }
    private var surface: Color {
        if preferences.theme == .black { return .black }
        return Color(uiColor: .systemGroupedBackground)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    questionCard
                    progressSection
                    dashboardGrid
                    quoteCard
                }
                .padding(.horizontal, sizeClass == .regular ? 30 : 16)
                .padding(.bottom, 32)
                .frame(maxWidth: 1300)
                .frame(maxWidth: .infinity)
            }
            .background(surface.ignoresSafeArea())
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showDashboard = true } label: { Label("数据面板", systemImage: "chart.xyaxis.line") }
                    Button { showSettings = true } label: { Label("设置", systemImage: "gearshape.fill") }
                }
            }
            .sheet(item: $activeStory) { session in
                StorySheet(branch: session.branch, sequence: session.index, amount: amount)
                    .environmentObject(preferences)
                    .environmentObject(runtime)
            }
            .sheet(isPresented: $showDashboard) {
                DataDashboardView()
                    .environmentObject(preferences)
                    .environmentObject(runtime)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(preferences)
            }
            .alert("隐藏档案", isPresented: Binding(
                get: { secretMessage != nil },
                set: { if !$0 { secretMessage = nil } }
            )) { Button("收好", role: .cancel) {} } message: { Text(secretMessage ?? "") }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private var header: some View {
        HStack(spacing: 14) {
            BrandIconView(size: sizeClass == .regular ? 74 : 58)
            VStack(alignment: .leading, spacing: 4) {
                Text(preferences.windowTitle)
                    .font(.system(size: 30 * preferences.fontScale, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.68)
                    .onTapGesture {
                        titleTapCount += 1
                        if titleTapCount.isMultiple(of: 5) {
                            runtime.unlock(true, "标题观察者")
                            secretMessage = "你连续敲了五次标题。档案室确认：耐心本身也是一种答案。"
                        }
                    }
                Text("今日档案 · 已运行 \(DebtEngine.days(on: Date(), preferences: preferences) + 1) 天")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("1.1.0")
                .font(.caption.monospacedDigit().weight(.bold))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(preferences.accentColor.opacity(0.14), in: Capsule())
        }
        .padding(.top, 8)
    }

    private var questionCard: some View {
        Card {
            VStack(spacing: sizeClass == .regular ? 26 : 18) {
                HStack {
                    Label("今日问题", systemImage: "questionmark.bubble.fill")
                        .font(.headline)
                        .foregroundStyle(preferences.accentColor)
                    Spacer()
                    Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Text(preferences.effectiveQuestion)
                    .font(.system(size: (sizeClass == .regular ? 39 : 29) * preferences.fontScale, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: 820)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 14) { branchButtons }
                    VStack(spacing: 12) { branchButtons }
                }
            }
            .padding(sizeClass == .regular ? 28 : 20)
        }
    }

    @ViewBuilder private var branchButtons: some View {
        ForEach(StoryBranch.allCases) { branch in
            Button {
                let result = StoryFactory.make(branch: branch, index: (runtime.branchCounts[branch] ?? 0) + 1,
                                               custom: preferences.customStory).last?.body ?? "剧情完成"
                let index = runtime.record(branch, result: result)
                withAnimation(preferences.reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.72)) {
                    activeStory = StorySession(branch: branch, index: index)
                }
            } label: {
                Label(branch.rawValue, systemImage: branch.symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .padding(.horizontal, 18)
                    .background(branch.color.gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(BounceButtonStyle(reduceMotion: preferences.reduceMotion))
            .accessibilityHint("进入\(branch.rawValue)剧情分支")
        }
    }

    private var progressSection: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { progressCards }
            VStack(spacing: 10) { progressCards }
        }
    }

    @ViewBuilder private var progressCards: some View {
        ForEach(StoryBranch.allCases) { branch in
            let count = runtime.branchCounts[branch] ?? 0
            Card {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Circle().fill(branch.color).frame(width: 10, height: 10)
                        Text("\(branch.rawValue)时间线").font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(count) / 1000").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    ProgressView(value: min(Double(count) / 1000, 1)).tint(branch.color)
                }
                .padding(15)
            }
        }
    }

    private var dashboardGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: sizeClass == .regular ? 330 : 280), spacing: 14)], spacing: 14) {
            CardButton(action: { showDashboard = true }) {
                VStack(alignment: .leading, spacing: 9) {
                    Label("当前欠款", systemImage: "banknote.fill").font(.headline).foregroundStyle(preferences.accentColor)
                    Text("￥\(amount.grouped) 元")
                        .font(.title2.monospacedDigit().weight(.black))
                        .lineLimit(2).minimumScaleFactor(0.42)
                    Text(amount.isCapped ? "已达到 99 位上限" : "点按查看对比、预测与实时换算")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CardButton(action: { showDashboard = true }) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("近七日增长", systemImage: "chart.line.uptrend.xyaxis").font(.headline).foregroundStyle(preferences.accentColor)
                    MiniTrend(amounts: (0...6).map { DebtEngine.amount(on: Date().addingDays(-6 + $0), preferences: preferences) })
                        .frame(height: 58)
                    HStack { Text("7 日前"); Spacer(); Text("今天 ↗") }.font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CardButton(action: { showDashboard = true }) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("档案概览", systemImage: "archivebox.fill").font(.headline).foregroundStyle(preferences.accentColor)
                    Text("连续签到 \(runtime.streak) 天").font(.title3.weight(.bold))
                    Text("\(runtime.choices.count) 条选择 · \(runtime.achievements.count) 项成就")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var quoteCard: some View {
        let quotes = ["每一个数字都有它的故事。", "今天的选择会成为明天的历史。", "三个按钮记得三条不同的时间线。", "历史不会评价你的答案，只负责记住。", "2023-06-21：档案编号 1111。", "圆角之内，剧情仍在继续。"]
        return Card {
            HStack(spacing: 13) {
                Image(systemName: "quote.opening").font(.title2).foregroundStyle(preferences.accentColor)
                Text(quotes[Calendar.current.component(.day, from: Date()) % quotes.count])
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("© 天国智造 · TGLab").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(15)
        }
    }
}

struct BrandIconView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let path = Bundle.module.path(forResource: "BrandIcon", ofType: "png", inDirectory: "Resources"),
               let image = UIImage(contentsOfFile: path) {
                Image(uiImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
            } else {
                Image(systemName: "a.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct Card<Content: View>: View {
    @EnvironmentObject private var preferences: AppPreferences
    @ViewBuilder let content: Content
    var body: some View {
        content
            .background(preferences.theme == .black ? Color.white.opacity(0.075) : Color(uiColor: .secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(preferences.highContrast ? preferences.accentColor.opacity(0.8) : Color.primary.opacity(0.09), lineWidth: preferences.highContrast ? 2 : 1))
    }
}

struct CardButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let content: Content
    var body: some View {
        Button(action: action) { Card { content.padding(18) } }
            .buttonStyle(.plain)
    }
}

struct BounceButtonStyle: ButtonStyle {
    let reduceMotion: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.955 : 1))
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.58), value: configuration.isPressed)
    }
}

struct MiniTrend: View {
    let amounts: [AmountDisplay]
    var body: some View {
        GeometryReader { proxy in
            let values = amounts.map(\.log10)
            let low = values.min() ?? 0
            let high = max(values.max() ?? 1, low + 0.0001)
            Path { path in
                for (index, value) in values.enumerated() {
                    let x = proxy.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = proxy.size.height * (1 - CGFloat((value - low) / (high - low)))
                    if index == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(.purple.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
        }
    }
}

