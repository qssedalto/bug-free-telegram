import SwiftUI

// MARK: - Existing AERTEX Intelligence server contract

struct AERTEXAIConfiguration: Decodable {
    struct Model: Decodable, Identifiable {
        let provider_id: String
        let provider_name: String?
        let model: String
        let available: Bool?
        let unavailable_code: String?

        var id: String { provider_id + "::" + model }
        var canUse: Bool { available != false }
        var label: String {
            let provider = provider_name ?? "AERTEX"
            return model + " · " + provider
        }
    }

    let enabled: Bool?
    let models: [Model]
    let default_provider_id: String?
    let default_model: String?
}

private struct AERTEXChatLine: Identifiable {
    let id: UUID
    let role: String
    var content: String

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }
}

// MARK: - Native conversation list and management

struct AERTEXIntelligenceNativeView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var conversations: [AERTEXConversation]?
    @State private var error: String?
    @State private var loading = false
    @State private var renameId: String?
    @State private var renameTitle = ""
    @State private var showingRename = false
    @State private var deleteId: String?
    @State private var showingDelete = false
    @State private var editing = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    AERTEXConversationNativeView(conversationId: nil, title: "新对话")
                } label: {
                    Label("开始新的 AI 对话", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundStyle(preferences.accentControlColor)
                }
            }
            if let conversations {
                Section("历史会话") {
                    if conversations.isEmpty {
                        Label("还没有历史会话", systemImage: "bubble.left.and.text.bubble.right")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(conversations) { conversation in
                        NavigationLink {
                            AERTEXConversationNativeView(
                                conversationId: conversation.id,
                                title: conversation.displayTitle
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(conversation.displayTitle)
                                        .font(.headline)
                                    if conversation.is_pinned == true {
                                        Image(systemName: "pin.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(conversation.model ?? "AERTEX Intelligence")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 5)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("重命名") {
                                renameId = conversation.id
                                renameTitle = conversation.displayTitle
                                showingRename = true
                            }
                            .tint(preferences.accentControlColor)
                            Button("删除", role: .destructive) {
                                deleteId = conversation.id
                                showingDelete = true
                            }
                        }
                    }
                }
            } else if loading {
                ProgressView("正在获取云端会话…")
            } else {
                Section {
                    AERTEXNativeLoadMessage(message: error ?? "未能获取会话") {
                        Task { await load() }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { LiquidGlassBackdrop() }
        .navigationTitle("Intelligence")
        .aertexGlassBackButton()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await load() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(loading)
            }
        }
        .refreshable { await load() }
        .task { if conversations == nil { await load() } }
        .onAppear {
            if conversations != nil { Task { await load() } }
        }
        .sheet(isPresented: $showingRename) {
            NavigationStack {
                Form {
                    Section("对话标题") {
                        TextField("输入新的会话标题", text: $renameTitle)
                    }
                }
                .navigationTitle("重命名会话")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") { showingRename = false }
                            .disabled(editing)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            Task { await saveRename() }
                        }
                        .disabled(editing || renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .interactiveDismissDisabled(editing)
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "确定要永久删除此云端会话吗？",
            isPresented: $showingDelete,
            titleVisibility: .visible
        ) {
            Button("删除会话", role: .destructive) {
                Task { await removeConversation() }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后无法在 AERTEX Intelligence 中恢复。")
        }
        .alert("账户操作失败", isPresented: Binding(
            get: { error != nil && conversations != nil },
            set: { if !$0 { error = nil } }
        )) {
            Button("关闭", role: .cancel) { error = nil }
        } message: {
            Text(error ?? "操作未完成")
        }
    }

    private func saveRename() async {
        guard let renameId, !editing else { return }
        editing = true
        do {
            try await auth.mutateAIConversation(
                conversationId: renameId, method: "PATCH", title: renameTitle
            )
            showingRename = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        editing = false
        if !showingRename { await load() }
    }

    private func removeConversation() async {
        guard let deleteId, !editing else { return }
        editing = true
        do {
            try await auth.mutateAIConversation(conversationId: deleteId, method: "DELETE")
            error = nil
            self.deleteId = nil
        } catch {
            self.error = error.localizedDescription
        }
        editing = false
        await load()
    }

    private func load() async {
        guard !loading else { return }
        loading = true
        defer { loading = false }
        do {
            conversations = try await auth.nativeGet(
                [AERTEXConversation].self,
                product: .intelligence,
                path: "/api/native/intelligence/conversations"
            )
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Streaming native chat

struct AERTEXConversationNativeView: View {
    @EnvironmentObject private var auth: AERTEXAuthStore
    @EnvironmentObject private var preferences: AppPreferences
    @State private var currentId: String?
    @State private var messages: [AERTEXChatLine] = []
    @State private var modelConfig: AERTEXAIConfiguration?
    @State private var selectedModelId = ""
    @State private var input = ""
    @State private var partialReply = ""
    @State private var error: String?
    @State private var isLoading = true
    @State private var isSending = false
    @State private var replyTask: Task<Void, Never>?
    @FocusState private var inputFocused: Bool

    private let initialId: String?
    private let title: String
    @State private var liveTitle: String

    init(conversationId: String?, title: String) {
        initialId = conversationId
        self.title = title
        _liveTitle = State(initialValue: title)
        _currentId = State(initialValue: conversationId)
    }

    private var chosenModel: AERTEXAIConfiguration.Model? {
        modelConfig?.models.first { $0.id == selectedModelId && $0.canUse }
    }

    private var canSend: Bool {
        !isLoading && !isSending &&
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        chosenModel != nil
    }

    private var conversationScrollId: String { "conversationBottom" }

    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                Spacer()
                ProgressView("正在连接 AERTEX Intelligence…")
                Spacer()
            } else {
                conversationBody
            }
            if let error {
                HStack(spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.caption)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        self.error = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 17)
                .padding(.vertical, 8)
            }
        }
        .background { LiquidGlassBackdrop() }
        .navigationTitle(currentId == nil ? "新对话" : liveTitle)
        .aertexGlassBackButton()
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(.ultraThinMaterial)
        }
        .task { await loadInitial() }
        .onDisappear {
            replyTask?.cancel()
            replyTask = nil
        }
    }

    private var conversationBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 19) {
                    if messages.isEmpty && !isSending {
                        VStack(spacing: 14) {
                            Image(systemName: "sparkles.rectangle.stack")
                                .font(.system(size: 43, weight: .light))
                                .foregroundStyle(preferences.accentControlColor)
                            Text("有什么可以帮你？")
                                .font(.title2.bold())
                            Text("使用 AERTEX Intelligence 的真实模型与云端会话。支持数学公式、Markdown 与代码。")
                                .multilineTextAlignment(.center)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 72)
                        .padding(.horizontal, 26)
                    }

                    ForEach(messages) { message in
                        messageBubble(role: message.role, content: message.content, streaming: false)
                    }

                    if isSending || !partialReply.isEmpty {
                        messageBubble(
                            role: "assistant",
                            content: partialReply.isEmpty ? "正在思考…" : partialReply,
                            streaming: isSending
                        )
                    }
                    Color.clear.frame(height: 1).id(conversationScrollId)
                }
                .padding(.horizontal, 15)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: messages.count) { _ in
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(conversationScrollId, anchor: .bottom)
                }
            }
            .onChange(of: partialReply.count) { _ in
                proxy.scrollTo(conversationScrollId, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func messageBubble(role: String, content: String, streaming: Bool) -> some View {
        let mine = role == "user"
        HStack(alignment: .top, spacing: 8) {
            if mine { Spacer(minLength: 35) }

            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 7) {
                    Image(systemName: mine ? "person.crop.circle.fill" : "sparkles")
                    Text(mine ? "你" : "AERTEX Intelligence")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

                if mine {
                    Text(content)
                        .textSelection(.enabled)
                        .font(.body)
                } else {
                    // The sandboxed canvas bundles the actual website renderer;
                    // text generation/UI/navigation itself remains native SwiftUI.
                    AERTEXRichMessageView(markdown: content, streaming: streaming)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: 580, alignment: .leading)
            .padding(16)
            .liquidGlassSurface(
                cornerRadius: 24,
                tint: mine
                    ? preferences.accentColor.opacity(0.24)
                    : preferences.accentColor.opacity(0.065)
            )

            if !mine { Spacer(minLength: 13) }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var composer: some View {
        VStack(spacing: 10) {
            HStack {
                if let config = modelConfig, !config.models.isEmpty {
                    Menu {
                        ForEach(config.models) { model in
                            Button {
                                selectedModelId = model.id
                            } label: {
                                if model.id == selectedModelId {
                                    Label(model.label, systemImage: "checkmark")
                                } else {
                                    Text(model.label)
                                }
                            }
                            .disabled(!model.canUse)
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cpu")
                            Text(chosenModel?.model ?? "没有可用模型")
                                .lineLimit(1)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(preferences.accentControlColor)
                    .disabled(isSending)
                }
                Spacer()
                if currentId != nil {
                    Label("云端会话", systemImage: "checkmark.shield")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(alignment: .bottom, spacing: 12) {
                TextField("向 AERTEX Intelligence 提问…", text: $input, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .font(.body)
                    .disabled(isSending || isLoading)
                    .padding(.vertical, 7)
                Button {
                    if isSending {
                        replyTask?.cancel()
                    } else {
                        send()
                    }
                } label: {
                    Image(systemName: isSending ? "stop.fill" : "arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 41, height: 41)
                        .background(preferences.accentControlColor, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(!isSending && !canSend)
                .opacity(isSending || canSend ? 1 : 0.42)
                .accessibilityLabel(isSending ? "停止生成" : "发送消息")
            }
        }
        .padding(14)
        .liquidGlassSurface(cornerRadius: 30, tint: preferences.accentColor.opacity(0.085), interactive: true)
    }

    private func loadInitial() async {
        guard isLoading else { return }
        do {
            async let config: AERTEXAIConfiguration = auth.nativeGet(
                AERTEXAIConfiguration.self,
                product: .intelligence,
                path: "/api/native/intelligence/config"
            )
            if let initialId {
                let detail: AERTEXConversationDetail = try await auth.nativeGet(
                    AERTEXConversationDetail.self,
                    product: .intelligence,
                    path: "/api/native/intelligence/conversations/" + initialId
                )
                messages = detail.messages.map {
                    AERTEXChatLine(role: $0.role, content: $0.content ?? "")
                }
            }
            let loaded = try await config
            modelConfig = loaded
            let defaults = loaded.models.first {
                $0.provider_id == loaded.default_provider_id &&
                $0.model == loaded.default_model && $0.canUse
            }
            selectedModelId = (defaults ?? loaded.models.first(where: { $0.canUse }))?.id ?? ""
            if chosenModel == nil {
                error = "此账户尚未配置可用的 AI 模型，请先在主站配置模型。"
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func send() {
        guard canSend, let model = chosenModel else { return }
        let prompt = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, prompt.count <= 30_000 else {
            error = "单条消息不能超过 30000 个字符。"
            return
        }
        error = nil
        input = ""
        inputFocused = false
        partialReply = ""
        messages.append(AERTEXChatLine(role: "user", content: prompt))
        if currentId == nil { liveTitle = String(prompt.prefix(28)) }
        isSending = true

        replyTask = Task {
            var completed = false
            do {
                try await auth.sendAIMessage(
                    prompt,
                    conversationId: currentId,
                    providerId: model.provider_id,
                    model: model.model
                ) { event in
                    switch event {
                    case .meta(let id):
                        currentId = id
                    case .delta(let piece):
                        partialReply += piece
                    case .done:
                        completed = true
                    }
                }
                guard completed else {
                    throw AERTEXNativeError(message: "服务端尚未确认完成。")
                }
                if !partialReply.isEmpty {
                    messages.append(AERTEXChatLine(role: "assistant", content: partialReply))
                }
                partialReply = ""
            } catch is CancellationError {
                error = "已停止生成。未完成的回复不计为成功。"
            } catch {
                self.error = error.localizedDescription
                if input.isEmpty { input = prompt }
            }
            isSending = false
            replyTask = nil
        }
    }
}
