import SwiftUI

/// Starter content lives in the app. Templates do not require the website,
/// a network connection or another sign-in.
enum AERTEXWorkTemplate: String, CaseIterable, Identifiable {
    case blank, paper, mathematics, notes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: return "空白文档"
        case .paper: return "论文与报告"
        case .mathematics: return "数学笔记"
        case .notes: return "课程笔记"
        }
    }

    var symbol: String {
        switch self {
        case .blank: return "doc"
        case .paper: return "text.book.closed"
        case .mathematics: return "function"
        case .notes: return "pencil.line"
        }
    }

    var source: String {
        switch self {
        case .blank:
            return "\\documentclass{article}\n\\begin{document}\n\n\\end{document}\n"
        case .paper:
            return "\\documentclass[12pt]{article}\n\\usepackage{amsmath,amssymb}\n\\title{报告标题}\n\\author{}\n\\date{\\today}\n\\begin{document}\n\\maketitle\n\\section{摘要}\n\n\\section{引言}\n\n\\section{方法}\n\n\\section{结论}\n\n\\end{document}\n"
        case .mathematics:
            return "\\documentclass{article}\n\\usepackage{amsmath,amssymb}\n\\begin{document}\n\\section{公式推导}\n\\begin{align}\n  a^2+b^2 &= c^2\n\\end{align}\n\\end{document}\n"
        case .notes:
            return "\\documentclass{article}\n\\usepackage{amsmath}\n\\begin{document}\n\\section{今日课程}\n\\subsection{核心概念}\n\n\\subsection{例题与解答}\n\n\\end{document}\n"
        }
    }
}

/// A genuine local, native structural preview. It does not pretend to be
/// a compiled PDF; TeX compilation requires a separate authenticated API.
struct AERTEXWorkOutlineView: View {
    let title: String
    let source: String

    private struct Heading: Identifiable {
        let id: Int
        let level: Int
        let value: String
    }

    private var headings: [Heading] {
        source.components(separatedBy: .newlines).enumerated().compactMap { offset, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for (marker, level) in [("\\section{", 1), ("\\subsection{", 2), ("\\subsubsection{", 3)] {
                guard trimmed.hasPrefix(marker),
                      let end = trimmed.dropFirst(marker.count).firstIndex(of: "}") else { continue }
                let value = String(trimmed[trimmed.index(trimmed.startIndex, offsetBy: marker.count)..<end])
                return Heading(id: offset, level: level, value: value)
            }
            return nil
        }
    }

    var body: some View {
        List {
            Section {
                LabeledContent("文档", value: title.isEmpty ? "未命名文档" : title)
                LabeledContent("行数", value: "\(source.components(separatedBy: .newlines).count)")
                LabeledContent("字符数", value: "\(source.count)")
            }
            Section("文档大纲") {
                if headings.isEmpty {
                    ContentUnavailableView("暂无章节", systemImage: "text.alignleft",
                                           description: Text("添加 \\section{章节名称} 后即可在这里查看结构。"))
                } else {
                    ForEach(headings) { heading in
                        Text(heading.value)
                            .font(heading.level == 1 ? .headline : .subheadline)
                            .padding(.leading, CGFloat(heading.level - 1) * 18)
                    }
                }
            }
            Section {
                Text("大纲在 iPhone 和 iPad 上直接生成，不会上传草稿。排版后的 PDF 需要独立编译服务，本页面不代替正式编译结果。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("文档大纲")
        .navigationBarTitleDisplayMode(.inline)
    }
}
