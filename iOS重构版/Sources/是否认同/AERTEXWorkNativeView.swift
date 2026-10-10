import SwiftUI

// Work's real owner-prefixed TeX documents. The native API returns the same
// IDs, source and engine as work.qsseda.com; no local mock documents.
struct AERTEXWorkDocument: Decodable, Identifiable {
    let id: String
    let title: String
    let engine: String
    let preview: String?
    let source: String?
    let updated_at: String?
}
private struct AERTEXWorkDocumentList: Decodable {
    let documents: [AERTEXWorkDocument]
}
private struct AERTEXWorkDocumentResponse: Decodable {
    let document: AERTEXWorkDocument
    let etag: String
}
private struct AERTEXWorkDraft: Encodable {
    let title: String
    let source: String
    let engine: String
}

struct AERTEXWorkNativeView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @State private var documents: [AERTEXWorkDocument] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AERTEXWorkEditorView(documentId: nil)
                } label: {
                    Label("新建 TeX 文档", systemImage: "doc.badge.plus")
                }
            }
            Section("我的 TeX 文档") {
                if loading {
                    ProgressView("正在同步 Work…")
                } else if let error {
                    AERTEXNativeLoadMessage(message: error) {
                        Task { await reload() }
                    }
                } else if documents.isEmpty {
                    Label("尚无云端文档", systemImage: "doc.text")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(documents) { doc in
                        NavigationLink {
                            AERTEXWorkEditorView(documentId: doc.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(doc.title).font(.headline)
                                Text(doc.preview ?? "")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(doc.engine)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Section {
                Link(destination: URL(string: "https://work.qsseda.com")!) {
                    Label("高级 TeX 编译、PDF 预览与实时协作", systemImage: "arrow.up.right.square")
                }
            } footer: {
                Text("原生版支持个人文档查看、新建和手动保存。共享文档权限、PDF 编译及实时协作仍使用 Work 网页工作台。")
            }
        }
        .scrollContentBackground(.hidden)
        .background { LiquidGlassBackdrop() }
        .navigationTitle("AERTEX Work")
        .aertexGlassBackButton()
        .refreshable { await reload() }
        .task { await reload() }
        .onAppear { if !loading { Task { await reload() } } }
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
        guard !loading || documents.isEmpty else { return }
        loading = true
        defer { loading = false }
        do {
            let response = try await auth.nativeGet(
                AERTEXWorkDocumentList.self, product: .work,
                path: "/api/native/work/documents"
            )
            documents = response.documents
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AERTEXWorkEditorView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @State private var documentId: String?
    @State private var title = ""
    @State private var source = ""
    @State private var engine = "xelatex"
    @State private var etag: String?
    @State private var loading = false
    @State private var saving = false
    @State private var error: String?
    @State private var notice: String?
    private let initialId: String?

    init(documentId: String?) {
        self.initialId = documentId
        _documentId = State(initialValue: documentId)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField("TeX 文档标题", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .disabled(loading || saving)
                Picker("引擎", selection: $engine) {
                    Text("XeLaTeX").tag("xelatex")
                    Text("LuaLaTeX").tag("lualatex")
                    Text("pdfLaTeX").tag("pdflatex")
                }
                .labelsHidden()
                .disabled(loading || saving)
            }
            .padding(.horizontal, 14)
            if loading {
                Spacer()
                ProgressView("正在读取 Work 文档…")
                Spacer()
            } else {
                TextEditor(text: $source)
                    .font(.system(.body, design: .monospaced))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 14)
                    .disabled(saving)
            }
            if let error {
                Text(error).font(.footnote).foregroundStyle(.red).textSelection(.enabled)
            }
            if let notice {
                Label(notice, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background { LiquidGlassBackdrop() }
        .navigationTitle(documentId == nil ? "新建 Work 文档" : "编辑 Work 文档")
        .navigationBarTitleDisplayMode(.inline)
        .aertexGlassBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() } else { Text("保存到云端") }
                }
                .disabled(saving || loading || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || source.count > 180000)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let initialId else { return }
        loading = true
        defer { loading = false }
        do {
            let response = try await auth.nativeGet(
                AERTEXWorkDocumentResponse.self, product: .work,
                path: "/api/native/work/documents?id=" + initialId
            )
            title = response.document.title
            source = response.document.source ?? ""
            engine = response.document.engine
            etag = response.etag
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        do {
            let editing = documentId != nil
            guard !editing || etag != nil else {
                error = "请先重新加载云端版本再保存。"
                return
            }
            let path = "/api/native/work/documents" +
                (documentId.map { "?id=" + $0 } ?? "")
            let result = try await auth.nativeWrite(
                AERTEXWorkDocumentResponse.self,
                product: .work,
                path: path,
                method: editing ? "PUT" : "POST",
                payload: AERTEXWorkDraft(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    source: source, engine: engine
                ),
                etag: editing ? etag : nil
            )
            documentId = result.document.id
            etag = result.etag
            error = nil
            notice = "已同步到 Work 云端"
        } catch {
            notice = nil
            error = error.localizedDescription
        }
    }
}
