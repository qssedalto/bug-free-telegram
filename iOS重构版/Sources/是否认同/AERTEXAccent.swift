import SwiftUI

struct AERTEXAccent: Identifiable, Equatable, Hashable {
    let id: String
    let hex: String
    let inkHex: String
    let nameZh: String
    let nameEn: String
    let models: [String]

    var color: Color { Color(aertexHex: hex) }
    var inkColor: Color { Color(aertexHex: inkHex) }

    func displayName(english: Bool) -> String {
        english ? nameEn : nameZh
    }

    var modelSummary: String {
        models.joined(separator: " · ")
    }

    static let defaultID = "iphone-9aadf6"

    static let all: [AERTEXAccent] = [
        .init(
            id: "iphone-222930",
            hex: "#222930",
            inkHex: "#FFFFFF",
            nameZh: "午夜色",
            nameEn: "Midnight",
            models: ["iPhone 14", "iPhone 14 Plus"]
        ),
        .init(
            id: "iphone-faf6f2",
            hex: "#FAF6F2",
            inkHex: "#111111",
            nameZh: "星光色",
            nameEn: "Starlight",
            models: ["iPhone 14", "iPhone 14 Plus"]
        ),
        .init(
            id: "iphone-fc0324",
            hex: "#FC0324",
            inkHex: "#111111",
            nameZh: "红色",
            nameEn: "(PRODUCT)RED",
            models: ["iPhone 14", "iPhone 14 Plus"]
        ),
        .init(
            id: "iphone-a0b4c7",
            hex: "#A0B4C7",
            inkHex: "#111111",
            nameZh: "蓝色",
            nameEn: "Blue",
            models: ["iPhone 14", "iPhone 14 Plus"]
        ),
        .init(
            id: "iphone-e6ddeb",
            hex: "#E6DDEB",
            inkHex: "#111111",
            nameZh: "紫色",
            nameEn: "Purple",
            models: ["iPhone 14", "iPhone 14 Plus"]
        ),
        .init(
            id: "iphone-f9e479",
            hex: "#F9E479",
            inkHex: "#111111",
            nameZh: "黄色",
            nameEn: "Yellow",
            models: ["iPhone 14", "iPhone 14 Plus"]
        ),
        .init(
            id: "iphone-403e3d",
            hex: "#403E3D",
            inkHex: "#FFFFFF",
            nameZh: "深空黑色",
            nameEn: "Space Black",
            models: ["iPhone 14 Pro", "iPhone 14 Pro Max"]
        ),
        .init(
            id: "iphone-f0f2f2",
            hex: "#F0F2F2",
            inkHex: "#111111",
            nameZh: "银色",
            nameEn: "Silver",
            models: ["iPhone 14 Pro", "iPhone 14 Pro Max"]
        ),
        .init(
            id: "iphone-f4e8ce",
            hex: "#F4E8CE",
            inkHex: "#111111",
            nameZh: "金色",
            nameEn: "Gold",
            models: ["iPhone 14 Pro", "iPhone 14 Pro Max"]
        ),
        .init(
            id: "iphone-594f63",
            hex: "#594F63",
            inkHex: "#FFFFFF",
            nameZh: "暗紫色",
            nameEn: "Deep Purple",
            models: ["iPhone 14 Pro", "iPhone 14 Pro Max"]
        ),
        .init(
            id: "iphone-35393b",
            hex: "#35393B",
            inkHex: "#FFFFFF",
            nameZh: "黑色",
            nameEn: "Black",
            models: ["iPhone 15", "iPhone 15 Plus"]
        ),
        .init(
            id: "iphone-ced5d9",
            hex: "#CED5D9",
            inkHex: "#111111",
            nameZh: "雾蓝色",
            nameEn: "Blue 2",
            models: ["iPhone 15", "iPhone 15 Plus"]
        ),
        .init(
            id: "iphone-cad4c5",
            hex: "#CAD4C5",
            inkHex: "#111111",
            nameZh: "绿色",
            nameEn: "Green",
            models: ["iPhone 15", "iPhone 15 Plus"]
        ),
        .init(
            id: "iphone-e5e0c1",
            hex: "#E5E0C1",
            inkHex: "#111111",
            nameZh: "柔黄色",
            nameEn: "Yellow 2",
            models: ["iPhone 15", "iPhone 15 Plus"]
        ),
        .init(
            id: "iphone-e3c8ca",
            hex: "#E3C8CA",
            inkHex: "#111111",
            nameZh: "粉色",
            nameEn: "Pink",
            models: ["iPhone 15", "iPhone 15 Plus"]
        ),
        .init(
            id: "iphone-1b1b1b",
            hex: "#1B1B1B",
            inkHex: "#FFFFFF",
            nameZh: "玄黑色",
            nameEn: "Black",
            models: ["iPhone 15 Pro", "iPhone 15 Pro Max"]
        ),
        .init(
            id: "iphone-dddddd",
            hex: "#DDDDDD",
            inkHex: "#111111",
            nameZh: "雾白色",
            nameEn: "White",
            models: ["iPhone 15 Pro", "iPhone 15 Pro Max"]
        ),
        .init(
            id: "iphone-2f4452",
            hex: "#2F4452",
            inkHex: "#FFFFFF",
            nameZh: "深海蓝色",
            nameEn: "Blue",
            models: ["iPhone 15 Pro", "iPhone 15 Pro Max"]
        ),
        .init(
            id: "iphone-837f7d",
            hex: "#837F7D",
            inkHex: "#111111",
            nameZh: "钛原色",
            nameEn: "Natural",
            models: ["iPhone 15 Pro", "iPhone 15 Pro Max"]
        ),
        .init(
            id: "iphone-3c4042",
            hex: "#3C4042",
            inkHex: "#FFFFFF",
            nameZh: "夜空色",
            nameEn: "Black 2 / Night Sky",
            models: ["iPhone 16", "iPhone 16 Plus", "iPhone Duo"]
        ),
        .init(
            id: "iphone-fafafa",
            hex: "#FAFAFA",
            inkHex: "#111111",
            nameZh: "星光白色",
            nameEn: "White / Star White",
            models: ["iPhone 16", "iPhone 16 Plus", "iPhone Duo"]
        ),
        .init(
            id: "iphone-f2adda",
            hex: "#F2ADDA",
            inkHex: "#111111",
            nameZh: "柔粉色",
            nameEn: "Pink 2",
            models: ["iPhone 16", "iPhone 16 Plus"]
        ),
        .init(
            id: "iphone-b0d4d2",
            hex: "#B0D4D2",
            inkHex: "#111111",
            nameZh: "深青色",
            nameEn: "Teal",
            models: ["iPhone 16", "iPhone 16 Plus"]
        ),
        .init(
            id: "iphone-9aadf6",
            hex: "#9AADF6",
            inkHex: "#111111",
            nameZh: "群青色",
            nameEn: "Ultramarine",
            models: ["iPhone 16", "iPhone 16 Plus"]
        ),
        .init(
            id: "iphone-3c3c3d",
            hex: "#3C3C3D",
            inkHex: "#FFFFFF",
            nameZh: "石墨黑色",
            nameEn: "Black 2",
            models: ["iPhone 16 Pro", "iPhone 16 Pro Max"]
        ),
        .init(
            id: "iphone-f2f1ed",
            hex: "#F2F1ED",
            inkHex: "#111111",
            nameZh: "暖白色",
            nameEn: "White 2",
            models: ["iPhone 16 Pro", "iPhone 16 Pro Max"]
        ),
        .init(
            id: "iphone-c2bcb2",
            hex: "#C2BCB2",
            inkHex: "#111111",
            nameZh: "自然原色",
            nameEn: "Natural 2",
            models: ["iPhone 16 Pro", "iPhone 16 Pro Max"]
        ),
        .init(
            id: "iphone-bfa48f",
            hex: "#BFA48F",
            inkHex: "#111111",
            nameZh: "沙漠色",
            nameEn: "Desert",
            models: ["iPhone 16 Pro", "iPhone 16 Pro Max"]
        ),
        .init(
            id: "iphone-353839",
            hex: "#353839",
            inkHex: "#FFFFFF",
            nameZh: "墨黑色",
            nameEn: "Black 3",
            models: ["iPhone 17"]
        ),
        .init(
            id: "iphone-f5f5f5",
            hex: "#F5F5F5",
            inkHex: "#111111",
            nameZh: "银白色",
            nameEn: "White 2 / Silver 2",
            models: ["iPhone 17", "iPhone 17 Pro", "iPhone 17 Pro Max"]
        ),
        .init(
            id: "iphone-96aed1",
            hex: "#96AED1",
            inkHex: "#111111",
            nameZh: "青雾蓝色",
            nameEn: "Mist Blue",
            models: ["iPhone 17"]
        ),
        .init(
            id: "iphone-a9b689",
            hex: "#A9B689",
            inkHex: "#111111",
            nameZh: "鼠尾草绿色",
            nameEn: "Sage",
            models: ["iPhone 17"]
        ),
        .init(
            id: "iphone-dfceea",
            hex: "#DFCEEA",
            inkHex: "#111111",
            nameZh: "薰衣草紫色",
            nameEn: "Lavender",
            models: ["iPhone 17"]
        ),
        .init(
            id: "iphone-f77e2d",
            hex: "#F77E2D",
            inkHex: "#111111",
            nameZh: "星宇橙色",
            nameEn: "Cosmic Orange",
            models: ["iPhone 17 Pro", "iPhone 17 Pro Max"]
        ),
        .init(
            id: "iphone-32374a",
            hex: "#32374A",
            inkHex: "#FFFFFF",
            nameZh: "深蓝色",
            nameEn: "Deep Blue",
            models: ["iPhone 17 Pro", "iPhone 17 Pro Max"]
        ),
        .init(
            id: "iphone-000000",
            hex: "#000000",
            inkHex: "#FFFFFF",
            nameZh: "纯黑色",
            nameEn: "Space Black 2",
            models: ["iPhone Air"]
        ),
        .init(
            id: "iphone-fcfcfc",
            hex: "#FCFCFC",
            inkHex: "#111111",
            nameZh: "云白色",
            nameEn: "Cloud White",
            models: ["iPhone Air"]
        ),
        .init(
            id: "iphone-fffcf5",
            hex: "#FFFCF5",
            inkHex: "#111111",
            nameZh: "浅金色",
            nameEn: "Light Gold",
            models: ["iPhone Air"]
        ),
        .init(
            id: "iphone-f0f9ff",
            hex: "#F0F9FF",
            inkHex: "#111111",
            nameZh: "天蓝色",
            nameEn: "Sky Blue",
            models: ["iPhone Air"]
        ),
        .init(
            id: "iphone-3c3c3c",
            hex: "#3C3C3C",
            inkHex: "#FFFFFF",
            nameZh: "炭黑色",
            nameEn: "Black 4",
            models: ["iPhone 18 Pro", "iPhone 18 Pro Max"]
        ),
        .init(
            id: "iphone-f7f7f7",
            hex: "#F7F7F7",
            inkHex: "#111111",
            nameZh: "亮银色",
            nameEn: "Silver 3",
            models: ["iPhone 18 Pro", "iPhone 18 Pro Max"]
        ),
        .init(
            id: "iphone-e8f2ff",
            hex: "#E8F2FF",
            inkHex: "#111111",
            nameZh: "冰川蓝色",
            nameEn: "Glacier",
            models: ["iPhone 18 Pro", "iPhone 18 Pro Max"]
        ),
        .init(
            id: "iphone-4d1821",
            hex: "#4D1821",
            inkHex: "#FFFFFF",
            nameZh: "勃艮第酒红色",
            nameEn: "Burgundy",
            models: ["iPhone 18 Pro", "iPhone 18 Pro Max"]
        )
    ]

    static let byID: [String: AERTEXAccent] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static var defaultAccent: AERTEXAccent {
        byID[defaultID] ?? all[0]
    }

    static func resolve(_ id: String?) -> AERTEXAccent {
        guard let id, let accent = byID[id] else { return defaultAccent }
        return accent
    }
}

extension Color {
    init(aertexHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let value = UInt64(cleaned, radix: 16) ?? 0

        let red: Double
        let green: Double
        let blue: Double

        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        } else {
            red = 0.60
            green = 0.68
            blue = 0.96
        }

        self.init(red: red, green: green, blue: blue)
    }
}
