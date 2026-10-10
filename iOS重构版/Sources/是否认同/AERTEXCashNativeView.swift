import SwiftUI

// Cash reads the actual Cash R2 account document. No mock ledger, and no
// client-side full-document PUT that could destroy unrecognised budget fields.
struct AERTEXCashTransaction: Decodable, Identifiable {
    let id: String
    let date: String
    let type: String
    let amount: Double
    let huabeiAmount: Double?
    let category: String
    let note: String?
}
struct AERTEXCashSettings: Decodable {
    let openingCash: Double?
    let periodStart: String?
    let periodEnd: String?
}
struct AERTEXCashData: Decodable {
    let version: Int
    let settings: AERTEXCashSettings?
    let transactions: [AERTEXCashTransaction]?
    let plannedEvents: [AERTEXCashPlannedEvent]?
    let expectedEvents: [AERTEXCashExpectedEvent]?
    let recurringExpenses: [AERTEXCashRecurringExpense]?
    let budgetRules: AERTEXCashBudgetRules?
}
struct AERTEXCashResponse: Decodable {
    let data: AERTEXCashData
    let updated_at: String?
    let initialized: Bool?
}
private struct AERTEXCashNewTransaction: Encodable {
    let date: String
    let type: String
    let amount: Double
    let category: String
    let note: String
}
private struct AERTEXCashMutationResponse: Decodable {
    let ok: Bool
}

struct AERTEXCashNativeView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var payload: AERTEXCashResponse?
    @State private var loading = false
    @State private var error: String?
    @State private var showingAdd = false

    private var transactions: [AERTEXCashTransaction] {
        payload?.data.transactions ?? []
    }

    // Budget projections in the website include plans/recurring expenses and
    // should not be confused with this actual-cash-only ledger balance.
    private var actualCashBalance: Double {
        let start = payload?.data.settings?.periodStart ?? "2026-10-01"
        let end = payload?.data.settings?.periodEnd ?? "9999-12-31"
        let delta = transactions.filter { $0.date >= start && $0.date <= end }.reduce(0.0) {
            $0 + ($1.type == "income"
                ? $1.amount
                : -($1.amount - min($1.amount, $1.huabeiAmount ?? 0)))
        }
        return (payload?.data.settings?.openingCash ?? 0) + delta
    }

    private var currency: FloatingPointFormatStyle<Double>.Currency {
        .currency(code: "CNY")
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 9) {
                    Text("账面现金 · 实际交易")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(actualCashBalance.formatted(currency))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(preferences.accentControlColor)
                    Text("按照期初现金与实际交易计算；不包含未来预测、未定日支出或预算模拟。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 7)
                Button {
                    showingAdd = true
                } label: {
                    Label("记录收入或支出", systemImage: "plus.circle.fill")
                }
            }
            if let accountData = payload?.data {
                Section {
                    NavigationLink {
                        AERTEXCashPlanningView(data: accountData, balance: actualCashBalance)
                    } label: {
                        Label("查看预算、固定支出与未来计划", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }
            }
            Section("收支记录（\(transactions.count) 笔）") {
                if loading && payload == nil {
                    ProgressView("正在连接 Cash…")
                } else if let error {
                    AERTEXNativeLoadMessage(message: error) {
                        Task { await reload() }
                    }
                }
                if transactions.isEmpty && !loading {
                    Text("尚无交易记录").foregroundStyle(.secondary)
                }
                ForEach(transactions.sorted(by: { $0.date > $1.date }).prefix(100)) { tx in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tx.category).font(.headline)
                            Text((tx.note?.isEmpty == false ? tx.note : nil) ?? tx.date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(tx.type == "income" ? "+" : "-")\(tx.amount.formatted(currency))")
                            .foregroundColor(tx.type == "income" ? .green : .primary)
                            .monospacedDigit()
                    }
                }
            }
            Section {
                Text("你的账本、预算及未来计划在 App 内统一查看。正式预测需要综合抵扣、周期支出与预算规则，参考金额不代表完整预测。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background { LiquidGlassBackdrop() }
        .navigationTitle("AERTEX Cash")
        .aertexGlassBackButton()
        .refreshable { await reload() }
        .task { await reload() }
        .sheet(isPresented: $showingAdd) {
            AERTEXCashEntryView {
                await reload()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await reload() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(loading)
            }
        }
    }

    private func reload() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            payload = try await auth.nativeGet(
                AERTEXCashResponse.self, product: .cash,
                path: "/api/native/cash/data"
            )
            error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct AERTEXCashEntryView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var type = "expense"
    @State private var amount = ""
    @State private var category = "food"
    @State private var note = ""
    @State private var isSaving = false
    @State private var error: String?
    let didSave: () async -> Void

    private let incomeCategories: [(String, String)] = [
        ("tutoringIncome", "家教收入"), ("familyRepayment", "家人还款"),
        ("salary", "工资/劳务"), ("otherIncome", "其他收入")
    ]
    private let expenseCategories: [(String, String)] = [
        ("food", "餐饮"), ("socialTransport", "社交交通"),
        ("tutoringTransport", "家教交通"), ("installment", "月供/Apple/iCloud"),
        ("electronics", "电子消费"), ("electricity", "电费"),
        ("water", "水费"), ("phone", "话费"), ("chatgpt", "ChatGPT"),
        ("otherExpense", "其他支出")
    ]
    private var categories: [(String, String)] {
        type == "income" ? incomeCategories : expenseCategories
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("收支类型", selection: $type) {
                    Text("支出").tag("expense")
                    Text("收入").tag("income")
                }
                .onChange(of: type) { _ in
                    category = type == "income" ? "otherIncome" : "food"
                }
                DatePicker("日期", selection: $date, in: ...Date(), displayedComponents: .date)
                TextField("金额（人民币）", text: $amount)
                    .keyboardType(.decimalPad)
                Picker("分类", selection: $category) {
                    ForEach(categories.indices, id: \.self) { index in
                        Text(categories[index].1).tag(categories[index].0)
                    }
                }
                TextField("备注（选填）", text: $note, axis: .vertical)
                    .lineLimit(1...4)
                Text("保存后会同步到账户账本。关联现有分期或未来计划的功能尚未开放，避免重复计算。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if let error {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("记一笔")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving { ProgressView() } else { Text("保存") }
                    }
                    .disabled(isSaving || amount.isEmpty)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
    }

    private func save() async {
        guard !isSaving else { return }
        let cleaned = amount.replacingOccurrences(of: ",", with: ".")
        guard let amountValue = Double(cleaned), amountValue > 0,
              amountValue <= 1_000_000_000,
              abs((amountValue * 100).rounded() - amountValue * 100) < 0.000001 else {
            error = "请输入不超过 10 亿元、最多两位小数的有效金额。"
            return
        }
        isSaving = true
        defer { isSaving = false }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        do {
            let result = try await auth.nativeWrite(
                AERTEXCashMutationResponse.self,
                product: .cash,
                path: "/api/native/cash/transactions",
                method: "POST",
                payload: AERTEXCashNewTransaction(
                    date: formatter.string(from: date),
                    type: type, amount: amountValue, category: category,
                    note: String(note.prefix(300))
                )
            )
            guard result.ok else { throw AERTEXNativeError(message: "保存未得到确认。") }
            await didSave()
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
