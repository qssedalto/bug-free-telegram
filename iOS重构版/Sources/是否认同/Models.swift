import Foundation
import SwiftUI
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case system = "跟随系统"
    case light = "浅色"
    case dark = "深色"
    case black = "纯黑"
    var id: String { rawValue }
}

@MainActor
final class AppPreferences: ObservableObject {
    @Published var startDate: Date { didSet { save() } }
    @Published var initialAmount: String { didSet { save() } }
    @Published var windowTitle: String { didSet { save() } }
    @Published var question: String { didSet { save() } }
    @Published var customStory: String { didSet { save() } }
    @Published var theme: AppTheme { didSet { save() } }
    @Published private(set) var aertexAccentId: String { didSet { save() } }
    @Published var fontScale: Double { didSet { save() } }
    @Published var highContrast: Bool { didSet { save() } }
    @Published var reduceMotion: Bool { didSet { save() } }
    @Published var soundEnabled: Bool { didSet { save() } }
    @Published var english: Bool { didSet { save() } }
    @Published var neutralMode: Bool { didSet { save() } }

    private var isLoading = true
    private let defaults = UserDefaults.standard

    init() {
        let calendar = Calendar(identifier: .gregorian)
        let anchor = calendar.date(from: DateComponents(year: 2023, month: 6, day: 19)) ?? Date()
        startDate = defaults.object(forKey: "startDate") == nil
            ? anchor : Date(timeIntervalSince1970: defaults.double(forKey: "startDate"))
        initialAmount = defaults.string(forKey: "initialAmount") ?? "1008"
        windowTitle = defaults.string(forKey: "windowTitle") ?? "对于甲，有一些问题"
        question = defaults.string(forKey: "question") ?? "是否认为甲是大傻福？"
        customStory = defaults.string(forKey: "customStory") ?? ""
        theme = AppTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        aertexAccentId = defaults.string(forKey: "aertexAccentId") ?? AERTEXAccent.defaultID
        fontScale = defaults.object(forKey: "fontScale") == nil ? 1 : defaults.double(forKey: "fontScale")
        highContrast = defaults.bool(forKey: "highContrast")
        reduceMotion = defaults.bool(forKey: "reduceMotion")
        soundEnabled = defaults.object(forKey: "soundEnabled") == nil ? true : defaults.bool(forKey: "soundEnabled")
        english = defaults.bool(forKey: "english")
        neutralMode = defaults.bool(forKey: "neutralMode")
        isLoading = false
        migrateLegacyText()
    }

    var currentAERTEXAccent: AERTEXAccent { AERTEXAccent.resolve(aertexAccentId) }
    var accentColor: Color { currentAERTEXAccent.color }
    var accentInkColor: Color { currentAERTEXAccent.inkColor }
    var accentName: String { currentAERTEXAccent.displayName(english: english) }
    var colorScheme: ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark, .black: return .dark
        }
    }

    var effectiveQuestion: String {
        if neutralMode {
            return english ? "Do you agree this is an interesting hypothesis?" : "是否认同这是一个有趣的假设？"
        }
        return question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "是否认为甲是大傻福？" : question
    }

    func applyAERTEXAccent(_ id: String?) {
        guard let id, AERTEXAccent.byID[id] != nil, id != aertexAccentId else { return }
        aertexAccentId = id
    }

    func restoreDefaults() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        startDate = calendar.date(from: DateComponents(year: 2023, month: 6, day: 19)) ?? Date()
        initialAmount = "1008"
        windowTitle = "对于甲，有一些问题"
        question = "是否认为甲是大傻福？"
        customStory = ""
        theme = .system
        fontScale = 1
        highContrast = false
        reduceMotion = false
        soundEnabled = true
        english = false
        neutralMode = false
    }

    private func migrateLegacyText() {
        let legacy = "\u{50bb}\u{903c}"
        if question.contains(legacy) { question = question.replacingOccurrences(of: legacy, with: "傻福") }
        if question.contains("焦晨阳") { question = question.replacingOccurrences(of: "焦晨阳", with: "甲") }
    }

    private func save() {
        guard !isLoading else { return }
        defaults.set(startDate.timeIntervalSince1970, forKey: "startDate")
        defaults.set(initialAmount, forKey: "initialAmount")
        defaults.set(windowTitle, forKey: "windowTitle")
        defaults.set(question, forKey: "question")
        defaults.set(customStory, forKey: "customStory")
        defaults.set(theme.rawValue, forKey: "theme")
        defaults.set(aertexAccentId, forKey: "aertexAccentId")
        defaults.set(min(max(fontScale, 0.75), 1.75), forKey: "fontScale")
        defaults.set(highContrast, forKey: "highContrast")
        defaults.set(reduceMotion, forKey: "reduceMotion")
        defaults.set(soundEnabled, forKey: "soundEnabled")
        defaults.set(english, forKey: "english")
        defaults.set(neutralMode, forKey: "neutralMode")
    }
}

private struct BigUnsigned {
    private static let base: UInt64 = 1_000_000_000
    private var words: [UInt32]

    init(decimal: String) {
        var result: [UInt32] = []
        var end = decimal.endIndex
        while end > decimal.startIndex {
            let start = decimal.index(end, offsetBy: -min(9, decimal.distance(from: decimal.startIndex, to: end)))
            result.append(UInt32(decimal[start..<end]) ?? 0)
            end = start
        }
        words = result.isEmpty ? [0] : result
        normalize()
    }

    mutating func multiply(by value: UInt32) {
        var carry: UInt64 = 0
        for index in words.indices {
            let product = UInt64(words[index]) * UInt64(value) + carry
            words[index] = UInt32(product % Self.base)
            carry = product / Self.base
        }
        while carry > 0 {
            words.append(UInt32(carry % Self.base))
            carry /= Self.base
        }
    }

    @discardableResult
    mutating func divide(by value: UInt32) -> UInt32 {
        var remainder: UInt64 = 0
        for index in words.indices.reversed() {
            let current = remainder * Self.base + UInt64(words[index])
            words[index] = UInt32(current / UInt64(value))
            remainder = current % UInt64(value)
        }
        normalize()
        return UInt32(remainder)
    }

    var decimalString: String {
        guard let last = words.last else { return "0" }
        var result = String(last)
        for word in words.dropLast().reversed() {
            result += String(format: "%09u", word)
        }
        return result
    }

    private mutating func normalize() {
        while words.count > 1 && words.last == 0 { words.removeLast() }
    }
}

struct AmountDisplay: Equatable {
    static let maximumDigits = String(repeating: "9", count: 99)
    static let maximum = AmountDisplay(digits: maximumDigits, chinese: ChineseMoney.text(maximumDigits), isCapped: true)
    let digits: String
    let chinese: String
    let isCapped: Bool

    var grouped: String {
        var result = ""
        for (index, character) in digits.enumerated() {
            if index > 0 && (digits.count - index).isMultiple(of: 3) { result.append(",") }
            result.append(character)
        }
        return result
    }

    var log10: Double {
        let prefix = String(digits.prefix(15))
        return log(Double(prefix) ?? 1) / log(10.0) + Double(digits.count - prefix.count)
    }
}

enum DebtEngine {
    static let maximumTrackedDays = 100_000
    private static let precision = 110

    @MainActor static func days(on date: Date, preferences: AppPreferences) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let start = calendar.startOfDay(for: preferences.startDate)
        let target = calendar.startOfDay(for: date)
        return min(max(calendar.dateComponents([.day], from: start, to: target).day ?? 0, 0), maximumTrackedDays)
    }

    @MainActor static func amount(on date: Date, preferences: AppPreferences) -> AmountDisplay {
        let elapsed = days(on: date, preferences: preferences)
        guard elapsed < 5_000 else { return .maximum }
        let cleaned = preferences.initialAmount.trimmingCharacters(in: .whitespacesAndNewlines)
        let pieces = cleaned.split(separator: ".", omittingEmptySubsequences: false)
        guard pieces.count <= 2,
              !pieces[0].isEmpty,
              pieces.allSatisfy({ $0.allSatisfy(\.isNumber) }) else {
            return amount(initialDigits: "1008", fractionCount: 0, elapsed: elapsed)
        }
        let fraction = pieces.count == 2 ? String(pieces[1].prefix(8)) : ""
        let raw = (String(pieces[0]) + fraction).drop(while: { $0 == "0" })
        guard !raw.isEmpty else { return amount(initialDigits: "1008", fractionCount: 0, elapsed: elapsed) }
        return amount(initialDigits: String(raw), fractionCount: fraction.count, elapsed: elapsed)
    }

    private static func amount(initialDigits: String, fractionCount: Int, elapsed: Int) -> AmountDisplay {
        let zeroCount = max(0, precision - fractionCount)
        var fixed = BigUnsigned(decimal: initialDigits + String(repeating: "0", count: zeroCount))
        for _ in 0..<elapsed {
            fixed.multiply(by: 21)
            fixed.divide(by: 20)
        }
        let raw = fixed.decimalString
        let padded = raw.count <= precision ? String(repeating: "0", count: precision + 1 - raw.count) + raw : raw
        let split = padded.index(padded.endIndex, offsetBy: -precision)
        var integer = String(padded[..<split]).drop(while: { $0 == "0" }).description
        if integer.isEmpty { integer = "0" }
        let fraction = padded[split...]
        if fraction.first ?? "0" >= "5" { integer = increment(integer) }
        guard integer.count <= 99 else { return .maximum }
        return AmountDisplay(digits: integer, chinese: ChineseMoney.text(integer), isCapped: false)
    }

    private static func increment(_ digits: String) -> String {
        var values = digits.compactMap(\.wholeNumberValue)
        var carry = 1
        for index in values.indices.reversed() where carry == 1 {
            let next = values[index] + carry
            values[index] = next % 10
            carry = next / 10
        }
        if carry == 1 { values.insert(1, at: 0) }
        return values.map(String.init).joined()
    }
}

enum ChineseMoney {
    private static let numerals = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
    private static let innerUnits = ["", "十", "百", "千"]
    private static let groupUnits = [
        "", "万", "亿", "兆", "京", "垓", "秭", "穰", "沟", "涧", "正", "载", "极",
        "恒河沙", "阿僧祇", "那由他", "不可思议", "无量大数", "万无量大数", "亿无量大数",
        "兆无量大数", "京无量大数", "垓无量大数", "秭无量大数", "穰无量大数"
    ]

    static func text(_ source: String) -> String {
        let digits = source.drop(while: { $0 == "0" }).description
        guard !digits.isEmpty else { return "零元" }
        var groups: [Int] = []
        var end = digits.endIndex
        while end > digits.startIndex {
            let start = digits.index(end, offsetBy: -min(4, digits.distance(from: digits.startIndex, to: end)))
            groups.append(Int(digits[start..<end]) ?? 0)
            end = start
        }
        var result = ""
        var pendingZero = false
        for index in groups.indices.reversed() {
            let value = groups[index]
            if value == 0 {
                if !result.isEmpty { pendingZero = true }
                continue
            }
            if !result.isEmpty && (pendingZero || value < 1000) { result += "零" }
            result += groupText(value) + groupUnits[index]
            pendingZero = false
        }
        return result + "元"
    }

    private static func groupText(_ value: Int) -> String {
        var result = ""
        var pendingZero = false
        let divisors = [1, 10, 100, 1000]
        for position in stride(from: 3, through: 0, by: -1) {
            let digit = value / divisors[position] % 10
            if digit == 0 {
                if !result.isEmpty { pendingZero = true }
            } else {
                if pendingZero { result += "零" }
                result += numerals[digit] + innerUnits[position]
                pendingZero = false
            }
        }
        return result
    }
}

enum StoryBranch: String, CaseIterable, Identifiable, Codable {
    case agree = "认同"
    case strongAgree = "非常认同"
    case disagree = "不认同"
    var id: String { rawValue }
    var color: Color {
        switch self { case .agree: return .blue; case .strongAgree: return .green; case .disagree: return .red }
    }
    var symbol: String {
        switch self { case .agree: return "checkmark.circle.fill"; case .strongAgree: return "hand.thumbsup.fill"; case .disagree: return "exclamationmark.triangle.fill" }
    }
}

struct ChoiceRecord: Codable, Identifiable {
    var id = UUID()
    let time: Date
    let choice: String
    let result: String
}

struct DailySnapshot: Codable, Identifiable {
    var id: String { day }
    let day: String
    let digits: String
}

@MainActor
final class RuntimeStore: ObservableObject {
    @Published private(set) var choices: [ChoiceRecord] = []
    @Published private(set) var achievements: [String] = []
    @Published private(set) var snapshots: [DailySnapshot] = []
    @Published private(set) var streak = 1
    @Published private(set) var branchCounts: [StoryBranch: Int] = [.agree: 0, .strongAgree: 0, .disagree: 0]

    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        if let data = defaults.data(forKey: "runtime.choices"), let value = try? decoder.decode([ChoiceRecord].self, from: data) { choices = value }
        if let value = defaults.stringArray(forKey: "runtime.achievements") { achievements = value }
        if let data = defaults.data(forKey: "runtime.snapshots"), let value = try? decoder.decode([DailySnapshot].self, from: data) { snapshots = value }
        streak = max(1, defaults.integer(forKey: "runtime.streak"))
        for branch in StoryBranch.allCases { branchCounts[branch] = defaults.integer(forKey: "runtime.branch.\(branch.rawValue)") }
    }

    func checkIn(amount: AmountDisplay) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let today = formatter.string(from: Date())
        let last = defaults.string(forKey: "runtime.lastCheckIn")
        if let last, last != today,
           let previous = formatter.date(from: last),
           Calendar.current.dateComponents([.day], from: previous, to: Date()).day == 1 { streak += 1 }
        else if last != nil && last != today { streak = 1 }
        defaults.set(today, forKey: "runtime.lastCheckIn")
        snapshots.removeAll { $0.day == today }
        snapshots.append(DailySnapshot(day: today, digits: amount.digits))
        snapshots = Array(snapshots.suffix(3660))
        unlock(streak >= 7, "连续七日")
        unlock(amount.digits.count >= 10, "十位数里程碑")
        unlock(amount.digits.count >= 20, "二十位数里程碑")
        save()
    }

    func record(_ branch: StoryBranch, result: String) -> Int {
        let next = (branchCounts[branch] ?? 0) + 1
        branchCounts[branch] = next
        choices.append(ChoiceRecord(time: Date(), choice: branch.rawValue, result: result))
        choices = Array(choices.suffix(1000))
        unlock(choices.count >= 10, "十次选择")
        unlock(next >= 12, "时间线观察者")
        if StoryBranch.allCases.allSatisfy({ (branchCounts[$0] ?? 0) > 0 }) { unlock(true, "三线同行") }
        save()
        return next
    }

    func resetStory() {
        choices = []
        achievements = []
        streak = 1
        branchCounts = [.agree: 0, .strongAgree: 0, .disagree: 0]
        save()
    }

    func unlock(_ condition: Bool, _ name: String) {
        if condition && !achievements.contains(name) { achievements.append(name) }
    }

    private func save() {
        defaults.set(try? encoder.encode(choices), forKey: "runtime.choices")
        defaults.set(achievements, forKey: "runtime.achievements")
        defaults.set(try? encoder.encode(snapshots), forKey: "runtime.snapshots")
        defaults.set(streak, forKey: "runtime.streak")
        for branch in StoryBranch.allCases { defaults.set(branchCounts[branch] ?? 0, forKey: "runtime.branch.\(branch.rawValue)") }
    }
}

struct StoryPage: Identifiable {
    let id = UUID()
    let title: String
    let body: String
    let button: String
}

enum StoryFactory {
    private static let places = ["档案室", "旧车站", "金额观测站", "第七码头", "午夜账簿", "数据回廊", "合同仓库", "时间塔", "审计室", "隐藏终端"]
    private static let events = ["灯忽然亮了", "时间线重新对齐", "打印机吐出一页记录", "紫色指示灯开始呼吸", "遗失的索引被找回", "今日快照完成归档", "一封迟到的回信抵达", "数字开始缓慢滚动", "三条路线同时出现", "一扇圆角门被推开"]
    private static let clues = ["日期与公式完全吻合", "账本仍有几页没有读完", "每个按钮都记得你的选择", "金额没有忘记经过的日子", "右下角藏着新的批注", "历史只记录而不评价", "下一次答案可能不同", "一枚紫色印章落在纸上", "系统留下了编号 1111", "墙上的折线继续向上"]
    private static let buttons = ["继续查看", "翻到下一页", "保存证据", "进入档案", "确认记录", "追踪线索", "打开回信", "对齐时间", "记住这一页", "走近一点"]

    static func make(branch: StoryBranch, index: Int, custom: String) -> [StoryPage] {
        let n = abs(index) % 1000
        let a = n % 10
        let b = n / 10 % 10
        let c = n / 100 % 10
        let opening: String
        let middle: String
        let ending: String
        switch branch {
        case .agree:
            opening = "你点头之后，\(places[a])的\(events[b])。"
            middle = "系统恢复了一份温和路线的记录：\(clues[c])。"
            ending = "这一页已归档。认同并不是句号，而是一把打开下一页的钥匙。"
        case .strongAgree:
            opening = "绿色确认信号穿过\(places[a])，\(events[b])。"
            middle = "赞同能量达到新峰值，终端提示：\(clues[c])。"
            ending = "记录完成。下一次非常认同，也许会唤醒另一条隐藏时间线。"
        case .disagree:
            opening = "红色警报覆盖\(places[a])，随后\(events[b])。"
            middle = "追踪程序逼近，但你发现出口旁写着：\(clues[c])。"
            ending = ["你关掉了灯，追踪者从门口经过却没有回头。", "随机结局编号 404：追踪者未找到。", "你从备用时间线离开，警报在身后归零。", "电梯停在不存在的楼层，你成功脱离。", "屏幕闪烁三次，系统宣布本次逃离有效。"][index % 5]
        }
        var pages = [StoryPage(title: "\(places[a])的记录", body: opening, button: buttons[b])]
        if !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            pages.append(StoryPage(title: "自定义档案", body: String(custom.prefix(1000)), button: "继续"))
        }
        pages.append(StoryPage(title: branch == .disagree ? "警告时间线" : "账本的新一页", body: middle, button: buttons[c]))
        pages.append(StoryPage(title: "本次结局", body: ending, button: branch == .disagree ? "安全离开" : "完成归档"))
        return pages
    }
}

struct MarketQuote: Equatable {
    var btc = "—"
    var usd = "—"
    var eur = "—"
    var jpy = "—"
    var hkd = "—"
    var goldTons = "—"
    var source = "正在获取实时行情…"
    var updatedAt: Date? = nil
}

enum MarketService {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 8
        configuration.httpAdditionalHeaders = ["User-Agent": "TGLab-ShiFouRenTong-iOS/1.1"]
        return URLSession(configuration: configuration)
    }()

    static func fetch(for amount: AmountDisplay) async -> MarketQuote {
        do {
            async let inChina = detectChina()
            async let btcPrice = bitcoinCNY()
            let china = await inChina
            let fiatGold = try await china ? chinaMarket() : internationalMarket()
            let btc = try await btcPrice
            return quote(amount: amount, rates: fiatGold.rates, goldPerGram: fiatGold.gold, btcPrice: btc,
                         source: fiatGold.source + (china ? "（中国线路）" : "（国际线路）"))
        } catch {
            do {
                let fallback = try await internationalMarket()
                let btc = try await bitcoinCNY()
                return quote(amount: amount, rates: fallback.rates, goldPerGram: fallback.gold, btcPrice: btc,
                             source: fallback.source + "（备用线路）")
            } catch {
                return MarketQuote(source: "实时行情暂不可用，请检查网络后重试")
            }
        }
    }

    private static func quote(amount: AmountDisplay, rates: [String: Decimal], goldPerGram: Decimal,
                              btcPrice: Decimal, source: String) -> MarketQuote {
        guard let value = Decimal(string: amount.digits) else { return MarketQuote(source: source) }
        return MarketQuote(
            btc: fixed(value / btcPrice, digits: 5),
            usd: money(value * (rates["USD"] ?? 0), digits: 2),
            eur: money(value * (rates["EUR"] ?? 0), digits: 2),
            jpy: money(value * (rates["JPY"] ?? 0), digits: 2),
            hkd: money(value * (rates["HKD"] ?? 0), digits: 2),
            goldTons: fixed(value / goldPerGram / Decimal(1_000_000), digits: 6),
            source: source,
            updatedAt: Date()
        )
    }

    private static func detectChina() async -> Bool {
        for textURL in ["https://myip.ipip.net", "https://ipapi.co/country/"] {
            guard let url = URL(string: textURL), let data = try? await session.data(from: url).0,
                  let text = String(data: data, encoding: .utf8)?.uppercased() else { continue }
            if text.contains("中国") || text.trimmingCharacters(in: .whitespacesAndNewlines) == "CN" { return true }
            if text.count < 8 { return false }
        }
        return Locale.current.region?.identifier == "CN"
    }

    private static func bitcoinCNY() async throws -> Decimal {
        if let json = try? await json("https://api.coinbase.com/v2/prices/BTC-CNY/spot"),
           let data = json["data"] as? [String: Any], let value = data["amount"] as? String,
           let price = Decimal(string: value), price > 0 { return price }
        let json = try await json("https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=cny")
        guard let bitcoin = json["bitcoin"] as? [String: Any], let number = bitcoin["cny"] as? NSNumber else { throw URLError(.badServerResponse) }
        return number.decimalValue
    }

    private static func internationalMarket() async throws -> (rates: [String: Decimal], gold: Decimal, source: String) {
        async let fiatJSON = json("https://api.coinbase.com/v2/exchange-rates?currency=CNY")
        async let goldJSON = json("https://api.coingecko.com/api/v3/simple/price?ids=pax-gold&vs_currencies=cny")
        let fiat = try await fiatJSON
        let gold = try await goldJSON
        guard let data = fiat["data"] as? [String: Any], let raw = data["rates"] as? [String: Any] else { throw URLError(.cannotParseResponse) }
        var rates: [String: Decimal] = [:]
        for code in ["USD", "EUR", "JPY", "HKD"] {
            guard let text = raw[code] as? String, let value = Decimal(string: text) else { throw URLError(.cannotParseResponse) }
            rates[code] = value
        }
        guard let pax = gold["pax-gold"] as? [String: Any], let ounce = pax["cny"] as? NSNumber else { throw URLError(.cannotParseResponse) }
        return (rates, ounce.decimalValue / Decimal(string: "31.1034768")!, "Coinbase；CoinGecko PAX Gold")
    }

    private static func chinaMarket() async throws -> (rates: [String: Decimal], gold: Decimal, source: String) {
        async let bankData = data("https://www.boc.cn/sourcedb/whpj/")
        async let goldJSON = json("https://www.sge.com.cn/graph/quotations")
        let htmlData = try await bankData
        let gold = try await goldJSON
        guard let html = String(data: htmlData, encoding: .utf8) else { throw URLError(.cannotDecodeContentData) }
        let names = ["美元": "USD", "欧元": "EUR", "日元": "JPY", "港币": "HKD"]
        var rates: [String: Decimal] = [:]
        for (name, code) in names {
            guard let row = html.range(of: "<td>\(name)</td>") else { continue }
            let tail = String(html[row.lowerBound...].prefix(1500))
            let cells = matches("<td[^>]*>(.*?)</td>", in: tail).map { stripHTML($0) }
            if cells.count >= 6, let cnyPerHundred = Decimal(string: cells[5]), cnyPerHundred > 0 {
                rates[code] = Decimal(100) / cnyPerHundred
            }
        }
        guard rates.count == 4 else { throw URLError(.cannotParseResponse) }
        guard let values = gold["data"] as? [Any] else { throw URLError(.cannotParseResponse) }
        let latest = values.reversed().compactMap { item -> Decimal? in
            if let number = item as? NSNumber { return number.decimalValue }
            if let text = item as? String { return Decimal(string: text) }
            return nil
        }.first { $0 > 0 }
        guard let latest else { throw URLError(.cannotParseResponse) }
        return (rates, latest, "中国银行；上海黄金交易所 Au99.99")
    }

    private static func data(_ address: String) async throws -> Data {
        guard let url = URL(string: address) else { throw URLError(.badURL) }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200, data.count <= 524_288 else { throw URLError(.badServerResponse) }
        return data
    }

    private static func json(_ address: String) async throws -> [String: Any] {
        let object = try JSONSerialization.jsonObject(with: try await data(address))
        guard let result = object as? [String: Any] else { throw URLError(.cannotParseResponse) }
        return result
    }

    private static func matches(_ pattern: String, in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length)).compactMap {
            $0.numberOfRanges > 1 ? ns.substring(with: $0.range(at: 1)) : nil
        }
    }

    private static func stripHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func money(_ value: Decimal, digits: Int) -> String { fixed(value, digits: digits) }
    private static func fixed(_ value: Decimal, digits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.usesGroupingSeparator = true
        formatter.minimumFractionDigits = digits
        formatter.maximumFractionDigits = digits
        return formatter.string(from: value as NSDecimalNumber) ?? "—"
    }
}

extension Date {
    func addingDays(_ value: Int) -> Date { Calendar.current.date(byAdding: .day, value: value, to: self) ?? self }
}

