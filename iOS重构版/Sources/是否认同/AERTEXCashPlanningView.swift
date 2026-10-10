import SwiftUI

// Native read-only views of the *existing* Cash account schema.
// No local shadow account and no full-document upload that could discard fields.
struct AERTEXCashPlannedEvent: Decodable, Identifiable {
    let id: String
    let date: String
    let type: String
    let amount: Double
    let category: String
    let note: String?
    let enabled: Bool?
}

struct AERTEXCashExpectedEvent: Decodable, Identifiable {
    let id: String
    let expectedMonth: String
    let type: String
    let amount: Double
    let category: String
    let note: String?
    let enabled: Bool?
}

struct AERTEXCashRecurringExpense: Decodable, Identifiable {
    let id: String
    let name: String
    let category: String?
    let amount: Double
    let dayOfMonth: Int?
    let reserveWhenUndated: Bool?
    let enabled: Bool?
}

struct AERTEXCashBudgetRules: Decodable {
    struct Food: Decodable {
        let classDay: Double?
        let oddMonday: Double?
        let evenMonday: Double?
        let saturday: Double?
        let sunday: Double?
    }
    struct Transport: Decodable {
        let weeklyVisits: Double?
        let medianPerVisit: Double?
    }
    let foodByDayType: Food?
    let socialTransport: Transport?
}

struct AERTEXCashPlanningView: View {
    let data: AERTEXCashData
    let balance: Double

    private let money = FloatingPointFormatStyle<Double>.Currency.currency(code: "CNY")
    private var today: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    private var plans: [AERTEXCashPlannedEvent] {
        (data.plannedEvents ?? []).filter { $0.enabled != false && $0.date >= today }
            .sorted { $0.date < $1.date }
    }
    private var expected: [AERTEXCashExpectedEvent] {
        (data.expectedEvents ?? []).filter { $0.enabled != false && $0.expectedMonth >= String(today.prefix(7)) }
            .sorted { $0.expectedMonth < $1.expectedMonth }
    }
    private var recurring: [AERTEXCashRecurringExpense] {
        (data.recurringExpenses ?? []).filter { $0.enabled != false }
            .sorted { $0.name < $1.name }
    }
    // Deliberately excludes recurring, undated reserves, food/transport rules,
    // covered plan matching and the full website forecast algorithm.
    private var datedPlanNet: Double {
        plans.reduce(0) { $0 + ($1.type == "income" ? $1.amount : -$1.amount) }
    }

    var body: some View {
        List {
            Section("我的资金计划") {
                LabeledContent("截至今天的现金", value: balance.formatted(money))
                LabeledContent("已确定日期的计划净额", value: datedPlanNet.formatted(money))
                LabeledContent("计划后的参考值", value: (balance + datedPlanNet).formatted(money))
                    .fontWeight(.semibold)
                Text("这里只把未来已定日期的计划与当前现金相加，不等于最终可支配金额。尚未扣除固定支出、预算预留，也没有把可能的重复记账自动抵消。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("未来收支安排") {
                if plans.isEmpty {
                    Text("暂时没有已确定日期的收支安排").foregroundStyle(.secondary)
                }
                ForEach(plans) { plan in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text((plan.note?.isEmpty == false ? plan.note : nil) ?? plan.category)
                                .font(.headline)
                            Text(plan.date).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(plan.amount.formatted(money))
                            .foregroundStyle(plan.type == "income" ? .green : .primary)
                    }
                }
            }
            Section("预计收支（月份已知、日期未定）") {
                if expected.isEmpty {
                    Text("暂无按月份估计的收支").foregroundStyle(.secondary)
                }
                ForEach(expected) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text((item.note?.isEmpty == false ? item.note : nil) ?? item.category)
                            Text(item.expectedMonth).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text((item.type == "income" ? "+" : "−") + item.amount.formatted(money))
                    }
                }
            }
            Section("每月固定支出") {
                if recurring.isEmpty {
                    Text("暂无固定支出计划").foregroundStyle(.secondary)
                }
                ForEach(recurring) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                            Text(item.dayOfMonth.map { "每月 \($0) 日" } ?? "扣款日未设定")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.amount.formatted(money))
                    }
                }
            }
            if let rules = data.budgetRules {
                Section("当前预算") {
                    if let food = rules.foodByDayType {
                        LabeledContent("上课日餐饮", value: (food.classDay ?? 0).formatted(money))
                        LabeledContent("单周周一餐饮", value: (food.oddMonday ?? 0).formatted(money))
                        LabeledContent("双周周一餐饮", value: (food.evenMonday ?? 0).formatted(money))
                        LabeledContent("周六餐饮", value: (food.saturday ?? 0).formatted(money))
                        LabeledContent("周日餐饮", value: (food.sunday ?? 0).formatted(money))
                    }
                    if let transport = rules.socialTransport {
                        LabeledContent("每周预计出行次数", value: String(format: "%.0f", transport.weeklyVisits ?? 0))
                        LabeledContent("每次预计交通费", value: (transport.medianPerVisit ?? 0).formatted(money))
                    }
                }
            }
            Section {
                Label("计划、周期支出和预算来自你已登录的同一个 Cash 账户。此处直接在 App 中查看；为避免误覆盖云端规则，暂不提供未获服务器支持的修改操作。", systemImage: "checkmark.shield")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background { LiquidGlassBackdrop() }
        .navigationTitle("预算与计划")
        .navigationBarTitleDisplayMode(.inline)
        .aertexGlassBackButton()
    }
}
