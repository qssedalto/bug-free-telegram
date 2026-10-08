import Foundation
import Security
import SwiftUI

struct AERTEXUser: Codable, Equatable {
    let id: String
    let email: String
    let displayName: String
    let username: String
    let avatarUrl: String
    let role: String
    let status: String
    let accentId: String?
}

private struct AERTEXTokenResponse: Decodable {
    let authenticated: Bool
    let authorized: Bool
    let token_type: String?
    let access_token: String
    let refresh_token: String
    let expires_in: Int
    let user: AERTEXUser
}

private struct AERTEXSessionResponse: Decodable {
    let authenticated: Bool
    let authorized: Bool
    let user: AERTEXUser?
    let error: String?
    let code: String?
}

private struct AERTEXLogoutResponse: Decodable {
    let success: Bool
}

private struct AERTEXErrorResponse: Decodable {
    let error: String?
    let code: String?
}

@MainActor
final class AERTEXAuthStore: ObservableObject {
    enum State: Equatable {
        case restoring
        case signedOut
        case signedIn
    }

    @Published private(set) var state: State = .restoring
    @Published private(set) var user: AERTEXUser?
    @Published var errorMessage: String?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isUpdatingProfile = false

    private let baseURL = URL(string: "https://auth.qsseda.com")!
    private let session: URLSession
    private let keychain = AERTEXKeychain()

    private var accessToken: String?

    init(session: URLSession = .shared) {
        self.session = session
    }

    var isAuthenticated: Bool { state == .signedIn && user != nil }

    func restore() async {
        guard let refreshToken = keychain.read(account: "refresh-token"), !refreshToken.isEmpty else {
            state = .signedOut
            return
        }

        do {
            let response: AERTEXTokenResponse = try await request(
                path: "/api/app/refresh",
                method: "POST",
                jsonBody: ["refresh_token": refreshToken]
            )
            accept(response)
        } catch {
            if let status = (error as? AERTEXAuthError)?.statusCode, [400, 401, 403].contains(status) {
                clearLocalSession()
                errorMessage = nil
            } else {
                // A transient outage must not erase a refresh token.
                state = .signedOut
                errorMessage = "暂时无法连接 AERTEX，设备上的会话凭据已保留。可重试恢复。"
            }
        }
    }

    func login(email: String, password: String) async -> Bool {
        errorMessage = nil
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, !password.isEmpty else {
            errorMessage = "请输入 AERTEX 邮箱和密码。"
            return false
        }

        do {
            let response: AERTEXTokenResponse = try await request(
                path: "/api/app/login",
                method: "POST",
                jsonBody: ["email": cleanEmail, "password": password]
            )
            accept(response)
            return isAuthenticated
        } catch {
            errorMessage = (error as? AERTEXAuthError)?.localizedDescription ?? "无法连接 AERTEX ID，请稍后再试。"
            return false
        }
    }

    func validateSession() async -> Bool {
        guard let accessToken else { return false }
        do {
            let response: AERTEXSessionResponse = try await request(
                path: "/api/app/session",
                method: "GET",
                bearer: accessToken
            )
            guard response.authenticated, response.authorized, let user = response.user else {
                return false
            }
            self.user = user
            self.state = .signedIn
            self.lastSyncedAt = Date()
            return true
        } catch {
            return false
        }
    }

    func refreshAccount() async -> Bool {
        guard !isRefreshing else { return false }
        isRefreshing = true
        defer { isRefreshing = false }

        if await validateSession() { return true }

        guard let refreshToken = keychain.read(account: "refresh-token"), !refreshToken.isEmpty else {
            clearLocalSession()
            return false
        }

        do {
            let response: AERTEXTokenResponse = try await request(
                path: "/api/app/refresh",
                method: "POST",
                jsonBody: ["refresh_token": refreshToken]
            )
            accept(response)
            return isAuthenticated
        } catch {
            if let status = (error as? AERTEXAuthError)?.statusCode, [400, 401, 403].contains(status) {
                clearLocalSession()
            }
            // Network and server errors do not revoke a previously valid local session.
            return false
        }
    }

    /// Update the profile in AERTEX ID through the first-party native API.
    /// The server only accepts displayName and enforces the logged-in user.
    func updateDisplayName(_ value: String) async -> Bool {
        guard !isUpdatingProfile else { return false }
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.unicodeScalars.count <= 120,
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else {
            errorMessage = "显示名称必须为 1–120 个有效字符。"
            return false
        }

        isUpdatingProfile = true
        errorMessage = nil
        defer { isUpdatingProfile = false }

        do {
            if accessToken == nil {
                guard await refreshAccount() else {
                    errorMessage = "登录状态已失效，请重新登录。"
                    return false
                }
            }

            let updated: AERTEXSessionResponse
            do {
                updated = try await request(
                    path: "/api/app/profile",
                    method: "PATCH",
                    jsonBody: ["displayName": name],
                    bearer: accessToken
                )
            } catch {
                // Access tokens expire; refresh once and retry the same validated mutation.
                guard (error as? AERTEXAuthError)?.statusCode == 401,
                      await refreshAccount() else { throw error }
                updated = try await request(
                    path: "/api/app/profile",
                    method: "PATCH",
                    jsonBody: ["displayName": name],
                    bearer: accessToken
                )
            }

            guard updated.authenticated, updated.authorized,
                  let updatedUser = updated.user, updatedUser.status == "active" else {
                errorMessage = "AERTEX 没有确认本次修改。"
                return false
            }
            user = updatedUser
            state = .signedIn
            lastSyncedAt = Date()
            return true
        } catch {
            errorMessage = (error as? AERTEXAuthError)?.localizedDescription ?? "无法保存显示名称，请检查网络或稍后重试。"
            return false
        }
    }

    func logout() async {
        let token = accessToken
        clearLocalSession()
        if let token {
            let _: AERTEXLogoutResponse? = try? await request(
                path: "/api/app/logout",
                method: "POST",
                bearer: token
            )
        }
    }

    private func accept(_ response: AERTEXTokenResponse) {
        guard response.authenticated, response.authorized, response.user.status == "active" else {
            clearLocalSession()
            errorMessage = "此 AERTEX 账户当前无法使用应用。"
            return
        }

        accessToken = response.access_token
        keychain.save(response.refresh_token, account: "refresh-token")
        user = response.user
        state = .signedIn
        lastSyncedAt = Date()
    }

    private func clearLocalSession() {
        accessToken = nil
        keychain.delete(account: "refresh-token")
        user = nil
        lastSyncedAt = nil
        state = .signedOut
    }

    /// Native JSON-only product API. Hostnames are fixed in the compiled app;
    /// no URL is provided by the user or decoded from server-controlled data.
    func nativeGet<Response: Decodable>(
        _ type: Response.Type,
        product: AERTEXNativeProduct,
        path: String
    ) async throws -> Response {
        guard isAuthenticated else {
            throw AERTEXNativeError(message: "请先登录 AERTEX ID。")
        }
        do {
            return try await nativeGetWithToken(type, product: product, path: path)
        } catch let error as AERTEXNativeError where error.statusCode == 401 {
            guard await refreshAccount() else {
                throw AERTEXNativeError(message: "登录会话已过期，请重新登录。", statusCode: 401)
            }
            return try await nativeGetWithToken(type, product: product, path: path)
        }
    }

    private func nativeGetWithToken<Response: Decodable>(
        _ type: Response.Type,
        product: AERTEXNativeProduct,
        path: String
    ) async throws -> Response {
        guard let accessToken else {
            throw AERTEXNativeError(message: "当前没有可用的访问令牌。", statusCode: 401)
        }
        guard path.hasPrefix("/api/native/"), !path.contains(".."),
              let url = URL(string: product.baseAddress + path) else {
            throw AERTEXNativeError(message: "无效的 AERTEX 服务路径。")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("AERTEX/2.2.0 (iOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AERTEXNativeError(message: "服务返回了无效响应。")
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = try? JSONDecoder().decode(AERTEXErrorResponse.self, from: data)
            throw AERTEXNativeError(
                message: detail?.error ?? "服务请求失败（HTTP \(http.statusCode)）。",
                statusCode: http.statusCode
            )
        }
        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AERTEXNativeError(message: "服务数据格式暂不兼容当前 App。")
        }
    }


    /// Uses the existing first-party Intelligence gateway. No model provider
    /// secret is ever handled by the iOS app. The server enforces quota/RLS.
    func sendAIMessage(
        _ message: String,
        conversationId: String?,
        providerId: String,
        model: String,
        onEvent: @escaping @MainActor (AERTEXAIStreamEvent) -> Void
    ) async throws {
        guard isAuthenticated else {
            throw AERTEXNativeError(message: "请先登录 AERTEX ID。")
        }
        do {
            try await streamAI(message, conversationId: conversationId,
                               providerId: providerId, model: model, onEvent: onEvent)
        } catch let error as AERTEXNativeError where error.statusCode == 401 {
            guard await refreshAccount() else {
                throw AERTEXNativeError(message: "会话已过期，请重新登录。", statusCode: 401)
            }
            try await streamAI(message, conversationId: conversationId,
                               providerId: providerId, model: model, onEvent: onEvent)
        }
    }

    private func streamAI(
        _ message: String, conversationId: String?,
        providerId: String, model: String,
        onEvent: @escaping @MainActor (AERTEXAIStreamEvent) -> Void
    ) async throws {
        guard let accessToken,
              let url = URL(string: "https://gpt.qsseda.com/api/native/intelligence/chat") else {
            throw AERTEXNativeError(message: "没有有效的访问令牌。", statusCode: 401)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("AERTEX/2.2.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "message": message,
            "conversation_id": conversationId as Any? ?? NSNull(),
            "provider_id": providerId,
            "model": model
        ])

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AERTEXNativeError(message: "AI 服务没有返回有效的 HTTP 响应。")
        }
        guard (200..<300).contains(http.statusCode) else {
            var responseBytes = Data()
            for try await byte in bytes {
                if responseBytes.count >= 32_768 { break }
                responseBytes.append(byte)
            }
            let failure = try? JSONDecoder().decode(AERTEXStreamFailure.self, from: responseBytes)
            throw AERTEXNativeError(
                message: failure?.error ?? "AI 服务异常（HTTP \(http.statusCode)）。",
                statusCode: http.statusCode
            )
        }

        guard http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("text/event-stream") == true else {
            throw AERTEXNativeError(message: "AI 服务没有返回流式事件。")
        }

        var eventName = "message"
        var dataLines: [String] = []
        var finished = false
        for try await rawLine in bytes.lines {
            try Task.checkCancellation()
            let line = rawLine.trimmingCharacters(in: .newlines)
            if line.isEmpty {
                if !dataLines.isEmpty {
                    let completed = try deliverAIEvent(
                        eventName, data: dataLines.joined(separator: "\n"), onEvent: onEvent
                    )
                    finished = finished || completed
                }
                eventName = "message"
                dataLines.removeAll(keepingCapacity: true)
                if finished { break }
                continue
            }
            if line.hasPrefix("event:") {
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("data:") {
                dataLines.append(String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces))
            }
        }
        if !finished && !dataLines.isEmpty {
            finished = try deliverAIEvent(
                eventName, data: dataLines.joined(separator: "\n"), onEvent: onEvent
            )
        }
        if !finished {
            throw AERTEXNativeError(message: "流式响应意外中断，未收到完成信号。")
        }
    }

    private func deliverAIEvent(
        _ name: String, data: String,
        onEvent: @escaping @MainActor (AERTEXAIStreamEvent) -> Void
    ) throws -> Bool {
        guard let bytes = data.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else {
            return false
        }
        switch name {
        case "meta":
            if let id = payload["conversation_id"] as? String {
                onEvent(.meta(conversationId: id))
            }
        case "delta":
            if let text = payload["delta"] as? String, !text.isEmpty {
                onEvent(.delta(text))
            }
        case "done":
            onEvent(.done)
            return true
        case "error":
            throw AERTEXNativeError(message: payload["error"] as? String ?? "AI 生成失败。")
        default:
            break
        }
        return false
    }

    private func request<Response: Decodable>(
        path: String,
        method: String,
        jsonBody: [String: String]? = nil,
        bearer: String? = nil
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AERTEX/2.2.0 (iOS)", forHTTPHeaderField: "User-Agent")
        if let bearer {
            request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
        }
        if let jsonBody {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
        }

        let (data, urlResponse) = try await session.data(for: request)
        guard let response = urlResponse as? HTTPURLResponse else {
            throw AERTEXAuthError(message: "AERTEX ID 返回了无效响应。")
        }

        guard (200..<300).contains(response.statusCode) else {
            let payload = try? JSONDecoder().decode(AERTEXErrorResponse.self, from: data)
            throw AERTEXAuthError(
                message: payload?.error ?? "AERTEX 请求失败（HTTP \(response.statusCode)）。",
                statusCode: response.statusCode
            )
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw AERTEXAuthError(message: "AERTEX ID 返回的数据格式无法识别。")
        }
    }
}

private struct AERTEXAuthError: LocalizedError {
    let message: String
    var statusCode: Int? = nil
    var errorDescription: String? { message }
}

private struct AERTEXKeychain {
    private let service = "com.tglab.shifourentong.ios.aertex"

    func save(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        delete(account: account)
        SecItemAdd([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData: data
        ] as CFDictionary, nil)
    }

    func read(account: String) -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func delete(account: String) {
        SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ] as CFDictionary)
    }
}

enum AERTEXNativeProduct {
    case studio
    case intelligence
    case watch

    var baseAddress: String {
        switch self {
        case .studio: return "https://qsseda.com"
        case .intelligence: return "https://gpt.qsseda.com"
        case .watch: return "https://aw.qsseda.com"
        }
    }
}

struct AERTEXNativeError: LocalizedError {
    let message: String
    var statusCode: Int? = nil
    var errorDescription: String? { message }
}

private struct AERTEXStreamFailure: Decodable {
    let error: String?
}

enum AERTEXAIStreamEvent {
    case meta(conversationId: String)
    case delta(String)
    case done
}
