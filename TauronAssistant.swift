import AppKit
import Combine
import Foundation
import Security
import SwiftUI

struct TauronAssistantMessage: Identifiable {
    let id = UUID()
    let role: String
    let text: String
}

@MainActor
final class TauronGeminiAssistant: ObservableObject {
    @Published var messages = [TauronAssistantMessage(role: "Tauron", text: "Hi! I can explain Tauron commands, help you write code, and review an attached text file. I only suggest commands and changes; I do not run or apply them.")]
    @Published var draft = ""
    @Published var isWorking = false
    @Published private(set) var hasAPIKey = false

    private var apiKey: String? { Self.readKey() }

    init() { hasAPIKey = apiKey != nil }

    func saveAPIKey(_ value: String) -> Bool {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "gemini-api-key",
        ]
        let data = Data(key.utf8)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        let status: OSStatus
        if update == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        } else {
            status = update
        }
        hasAPIKey = status == errSecSuccess
        return hasAPIKey
    }

    func removeAPIKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "gemini-api-key",
        ]
        SecItemDelete(query as CFDictionary)
        hasAPIKey = false
    }

    func send(directory: URL, attachedFile: String?) async {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isWorking else { return }
        guard let key = apiKey else {
            messages.append(TauronAssistantMessage(role: "Tauron", text: "Connect your Gemini API key first using the button above. The key is stored in your Mac's Keychain."))
            return
        }
        draft = ""
        messages.append(TauronAssistantMessage(role: "You", text: question))
        isWorking = true
        defer { isWorking = false }

        let systemPrompt = """
        You are Tauron's coding and terminal assistant. Help with macOS programming, beginner-friendly coding, the Tauron command language, Tauron mods (.tau), and safe file-work workflows. Tauron is a custom command interpreter with commands such as help, ls, cd, cat, mkdir, touch, cp, mv, rm, find, mod, and changelog. It does not execute arbitrary shell commands, pipes, or redirection. Explain commands clearly and label code blocks with their language. Never claim that you ran a command or changed a file. Do not ask for passwords, API keys, or other secrets. Be clear when an instruction would delete or overwrite data.

        Current Tauron folder: \(directory.path)
        \(attachedFile ?? "No file is attached.")
        """

        let recent = messages.suffix(13).map { message -> [String: Any] in
            ["role": message.role == "You" ? "user" : "model", "parts": [["text": message.text]]]
        }
        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": systemPrompt]]],
            "contents": recent,
            "generationConfig": ["temperature": 0.4, "maxOutputTokens": 4096],
        ]
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            messages.append(TauronAssistantMessage(role: "Tauron", text: "Could not prepare the Gemini request."))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = bodyData
        request.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GeminiError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["error"] as? [String: Any] }
                    .flatMap { $0["message"] as? String }
                throw GeminiError.requestFailed(http.statusCode, message ?? "Check the key, internet connection, and Gemini API access.")
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let candidates = json?["candidates"] as? [[String: Any]]
            let content = candidates?.first?["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]]
            let answer = parts?.compactMap { $0["text"] as? String }.joined()
            guard let answer, !answer.isEmpty else { throw GeminiError.emptyResponse }
            messages.append(TauronAssistantMessage(role: "Gemini", text: answer))
        } catch {
            messages.append(TauronAssistantMessage(role: "Tauron", text: "Gemini request failed: \(error.localizedDescription)"))
        }
    }

    private static let keychainService = "com.tauron.terminal.gemini"

    private static func readKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: "gemini-api-key",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private enum GeminiError: LocalizedError {
        case invalidResponse
        case emptyResponse
        case requestFailed(Int, String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "The API returned an invalid response."
            case .emptyResponse: return "Gemini returned no text. Try asking again."
            case let .requestFailed(code, message): return "HTTP \(code): \(message)"
            }
        }
    }
}

struct TauronAssistantView: View {
    @ObservedObject var assistant: TauronGeminiAssistant
    let directory: URL
    @State private var showKeySetup = false
    @State private var keyDraft = ""
    @State private var attachedFile: String?
    @State private var attachedName: String?
    @State private var keyMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                Text("GEMINI ASSISTANT").font(.system(size: 12, weight: .bold, design: .monospaced))
                Spacer()
                if assistant.hasAPIKey {
                    Text("Gemini 3.1 Flash-Lite").font(.system(size: 11)).foregroundStyle(.secondary)
                    Button("API Key") { keyMessage = nil; showKeySetup = true }
                } else {
                    Button("Connect Gemini…") { keyMessage = nil; showKeySetup = true }
                }
            }.padding(14)
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(assistant.messages) { message in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(message.role.uppercased())
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(message.role == "Gemini" ? .purple : .secondary)
                                Text(message.text)
                                    .font(.system(size: 13))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.id(message.id)
                        }
                        if assistant.isWorking {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Gemini is thinking…") }
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }.padding(18)
                }
                .onChange(of: assistant.messages.count) { _ in
                    if let last = assistant.messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }

            if let attachedName {
                HStack {
                    Label("Attached: \(attachedName)", systemImage: "doc.text")
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button { self.attachedName = nil; attachedFile = nil } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain)
                }.font(.system(size: 11)).padding(.horizontal, 12).padding(.vertical, 6)
            }
            Divider()
            HStack(alignment: .bottom, spacing: 8) {
                Button { attachFile() } label: { Image(systemName: "paperclip") }
                    .help("Attach a text or code file for Gemini to review")
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $assistant.draft)
                        .font(.system(size: 12))
                        .frame(height: 62)
                    if assistant.draft.isEmpty {
                        Text("Ask about Tauron, code, or a terminal task…")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                            .padding(.leading, 5).padding(.top, 8)
                            .allowsHitTesting(false)
                    }
                }
                Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.system(size: 22)) }
                    .disabled(assistant.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || assistant.isWorking)
                    .keyboardShortcut(.return, modifiers: [.command])
            }.padding(12)
        }
        .sheet(isPresented: $showKeySetup) { keySetupSheet }
    }

    private var keySetupSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Connect Gemini").font(.title2.bold())
            Text("Use your own Google AI Studio API key. Tauron stores it in macOS Keychain and sends it directly to Google when you ask a question.")
                .fixedSize(horizontal: false, vertical: true)
            Link("Get a Gemini API key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
            SecureField("Paste API key", text: $keyDraft)
                .textFieldStyle(.roundedBorder)
            if let keyMessage { Text(keyMessage).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                if assistant.hasAPIKey {
                    Button("Remove Key") { assistant.removeAPIKey(); keyDraft = ""; showKeySetup = false }
                }
                Spacer()
                Button("Cancel") { showKeySetup = false }
                Button("Save in Keychain") {
                    if assistant.saveAPIKey(keyDraft) { keyDraft = ""; showKeySetup = false }
                    else { keyMessage = "Could not save the key in Keychain. Try again." }
                }.keyboardShortcut(.defaultAction)
                    .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(22).frame(width: 440)
    }

    private func attachFile() {
        let panel = NSOpenPanel()
        panel.title = "Attach a code or text file"
        panel.prompt = "Attach"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = directory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data.prefix(40_000), encoding: .utf8) else {
                keyMessage = "That file is not readable as UTF-8 text."
                return
            }
            attachedName = url.lastPathComponent
            attachedFile = "Attached file: \(url.lastPathComponent)\n```\n\(text)\n```"
        } catch {
            keyMessage = "Could not read that file: \(error.localizedDescription)"
        }
    }

    private func send() {
        Task { await assistant.send(directory: directory, attachedFile: attachedFile) }
    }
}
