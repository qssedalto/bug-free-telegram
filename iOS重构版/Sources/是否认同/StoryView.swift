import SwiftUI
import UIKit

struct StorySheet: View {
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var runtime: RuntimeStore
    @Environment(\.dismiss) private var dismiss
    let branch: StoryBranch
    let sequence: Int
    let amount: AmountDisplay

    @State private var pageIndex = 0
    @State private var quote = MarketQuote()
    @State private var isLoadingMarket = false
    @State private var copiedMessage: String?
    @State private var countdown = 8
    @State private var selectedDetent: PresentationDetent = .medium

    private var pages: [StoryPage] { StoryFactory.make(branch: branch, index: sequence, custom: preferences.customStory) }
    private var page: StoryPage { pages[min(pageIndex, pages.count - 1)] }
    private var isFinal: Bool { pageIndex == pages.count - 1 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    branchHeader
                    storyCard
                    if isFinal && branch != .disagree { amountCard }
                    if isFinal && branch == .disagree { escapeCard }
                    actionButton
                }
                .padding(24)
                .frame(maxWidth: 900)
                .frame(maxWidth: .infinity)
            }
            .background {
                LiquidGlassBackdrop(
                    accent: branch == .disagree ? .red : preferences.accentColor,
                    intense: branch == .disagree
                )
            }
            .navigationTitle(page.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
        }
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .task {
            selectedDetent = page.body.count > 100 ? .large : .medium
            if branch != .disagree {
                isLoadingMarket = true
                quote = await MarketService.fetch(for: amount)
                isLoadingMarket = false
            } else {
                for remaining in stride(from: 8, through: 0, by: -1) {
                    countdown = remaining
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
        .alert("已复制", isPresented: Binding(get: { copiedMessage != nil }, set: { if !$0 { copiedMessage = nil } })) {
            Button("好", role: .cancel) {}
        } message: { Text(copiedMessage ?? "") }
    }

    private var branchHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: branch.symbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(branch.color)
            VStack(alignment: .leading, spacing: 3) {
                Text("\(branch.rawValue)时间线").font(.headline)
                Text("组合编号 \(String(format: "%03d", sequence % 1000)) · 第 \(pageIndex + 1)/\(pages.count) 页")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var storyCard: some View {
        VStack(spacing: 16) {
            Text(page.title)
                .font(.system(size: 30 * preferences.fontScale, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text(page.body)
                .font(.system(size: 18 * preferences.fontScale, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .padding(24)
        .liquidGlassSurface(
            cornerRadius: 26,
            tint: branch.color.opacity(0.07)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }

    private var amountCard: some View {
        VStack(spacing: 14) {
            Text("当前合同欠款").font(.headline).foregroundStyle(.secondary)
            Text("￥\(amount.grouped) 元")
                .font(.system(size: 27 * preferences.fontScale, weight: .black, design: .monospaced))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.38)
            Text("人民币：\(amount.chinese)\(amount.isCapped ? "（已达到 99 位上限）" : "")")
                .font(.subheadline.weight(.bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            if isLoadingMarket {
                ProgressView("正在获取比特币实时价格…")
            } else {
                Text("相当于 \(quote.btc) BTC")
                    .font(.title3.monospacedDigit().weight(.black))
                Text(quote.source).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            ViewThatFits(in: .horizontal) {
                HStack { copyButtons }
                VStack { copyButtons }
            }
        }
        .padding(22)
        .liquidGlassSurface(
            cornerRadius: 24,
            tint: preferences.accentColor.opacity(0.11)
        )
    }

    @ViewBuilder private var copyButtons: some View {
        Button { copy("￥\(amount.grouped) 元", label: "人民币金额") } label: { Label("复制人民币", systemImage: "doc.on.doc") }
            .liquidGlassButtonStyle(prominent: true, tint: preferences.accentColor)
        Button { copy("\(quote.btc) BTC", label: "BTC 数值") } label: { Label("复制 BTC", systemImage: "bitcoinsign.circle") }
            .liquidGlassButtonStyle(tint: preferences.accentColor)
            .disabled(quote.btc == "—")
    }

    private var escapeCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: 8)
                Circle().trim(from: 0, to: CGFloat(countdown) / 8)
                    .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(countdown)").font(.title2.monospacedDigit().bold())
            }
            .frame(width: 74, height: 74)
            VStack(alignment: .leading, spacing: 5) {
                Text(countdown > 0 ? "警告页面倒计时" : "出口已经出现")
                    .font(.headline)
                Text("随机逃离结果已经写入历史记录。关闭页面不会删除这条时间线。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .liquidGlassSurface(
            cornerRadius: 24,
            tint: Color.red.opacity(0.10)
        )
    }

    private var actionButton: some View {
        Button {
            if isFinal {
                dismiss()
            } else {
                withAnimation(preferences.reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.78)) {
                    pageIndex += 1
                    selectedDetent = pages[pageIndex].body.count > 100 || pageIndex == pages.count - 1 ? .large : .medium
                }
            }
        } label: {
            Text(isFinal ? (branch == .disagree ? "安全离开" : "完成归档") : page.button)
                .font(.headline.weight(.black))
                .frame(maxWidth: 360, minHeight: 54)
                .padding(.horizontal, 14)
        }
        .liquidGlassButtonStyle(
            prominent: true,
            tint: branch == .disagree ? .purple : preferences.accentColor
        )
    }

    private func copy(_ text: String, label: String) {
        UIPasteboard.general.string = text
        copiedMessage = "\(label)已写入剪贴板。"
    }
}

