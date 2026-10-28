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

enum TauronAIProvider: String, CaseIterable, Identifiable {
    case gemini
    case ollama

    var id: String { rawValue }
    var label: String { self == .gemini ? "Gemini (cloud)" : "Ollama (local)" }
}

@MainActor
final class TauronAIService: ObservableObject {
    @Published var messages = [TauronAssistantMessage(role: "Tauron", text: "Hi! I can explain Tauron commands, help you write code, and review an attached text file. I only suggest commands and changes; I do not run or apply them.")]
    @Published var draft = ""
    @Published var isWorking = false
    @Published private(set) var hasAPIKey = false
    @Published var provider: TauronAIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "tauron.ai.provider") }
    }
    @Published var localModel: String {
        didSet { UserDefaults.standard.set(localModel, forKey: "tauron.ai.ollamaModel") }
    }
    @Published var memories: [String] = []

    private var apiKey: String? { Self.readKey() }

    init() {
        provider = TauronAIProvider(rawValue: UserDefaults.standard.string(forKey: "tauron.ai.provider") ?? "") ?? .gemini
        localModel = UserDefaults.standard.string(forKey: "tauron.ai.ollamaModel") ?? "gemma4"
        hasAPIKey = apiKey != nil
        memories = Self.readMemories()
    }

    func remember(_ note: String) {
        let value = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !memories.contains(value) else { return }
        memories.append(value)
        saveMemories()
    }

    func forgetMemory(at index: Int) {
        guard memories.indices.contains(index) else { return }
        memories.remove(at: index)
        saveMemories()
    }

    func clearMemories() {
        memories.removeAll()
        saveMemories()
    }

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
        guard provider == .ollama || apiKey != nil else {
            messages.append(TauronAssistantMessage(role: "Tauron AI", text: "Connect a Gemini API key in settings, or switch to the local Ollama provider."))
            return
        }
        draft = ""
        messages.append(TauronAssistantMessage(role: "You", text: question))
        isWorking = true
        defer { isWorking = false }

        let systemPrompt = """
        You are Tauron's coding and terminal assistant. Help with macOS programming, beginner-friendly coding, the Tauron command language, Tauron mods (.tau), and safe file-work workflows. Tauron is a custom command interpreter with commands such as help, ls, cd, cat, mkdir, touch, cp, mv, rm, find, mod, and changelog. It does not execute arbitrary shell commands, pipes, or redirection. Explain commands clearly and label code blocks with their language. Never claim that you ran a command or changed a file. Do not ask for passwords, API keys, or other secrets. Be clear when an instruction would delete or overwrite data.

        Current Tauron folder: \(directory.path)
        User-approved local notes to remember between chats:
        \(memories.isEmpty ? "No saved notes." : memories.map { "- \($0)" }.joined(separator: "\n"))
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
        let requestURL: URL?
        let requestBody: [String: Any]
        if provider == .gemini {
            requestURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite:generateContent")
            requestBody = body
        } else {
            requestURL = URL(string: "http://localhost:11434/api/chat")
            let localMessages: [[String: Any]] = [["role": "system", "content": systemPrompt]] + recent.map { message in
                ["role": (message["role"] as? String) == "user" ? "user" : "assistant",
                 "content": ((message["parts"] as? [[String: Any]])?.first?["text"] as? String) ?? ""]
            }
            requestBody = ["model": localModel.trimmingCharacters(in: .whitespacesAndNewlines), "messages": localMessages, "stream": false]
        }
        guard let url = requestURL, let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            messages.append(TauronAssistantMessage(role: "Tauron AI", text: "Could not prepare the request."))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if provider == .gemini, let key = apiKey {
            request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        }
        request.httpBody = bodyData
        request.timeoutInterval = 60

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GeminiError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                    .flatMap { $0["error"] as? [String: Any] }
                    .flatMap { $0["message"] as? String }
                let fallback = provider == .gemini
                    ? "Check the key, internet connection, and Gemini API access."
                    : "Make sure Ollama is running and the selected model is installed."
                throw GeminiError.requestFailed(http.statusCode, message ?? fallback)
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let answer: String?
            if provider == .gemini {
                let candidates = json?["candidates"] as? [[String: Any]]
                let content = candidates?.first?["content"] as? [String: Any]
                let parts = content?["parts"] as? [[String: Any]]
                answer = parts?.compactMap { $0["text"] as? String }.joined()
            } else {
                let message = json?["message"] as? [String: Any]
                answer = message?["content"] as? String
            }
            guard let answer, !answer.isEmpty else { throw GeminiError.emptyResponse }
            messages.append(TauronAssistantMessage(role: provider == .gemini ? "Gemini" : "Tauron AI · Local", text: answer))
        } catch {
            let service = provider == .gemini ? "Gemini" : "Ollama"
            messages.append(TauronAssistantMessage(role: "Tauron AI", text: "\(service) request failed: \(error.localizedDescription)"))
        }
    }

    private static let keychainService = "com.tauron.terminal.gemini"
    private static var memoryURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tauron/ai-memory.json")
    }

    private static func readMemories() -> [String] {
        guard let data = try? Data(contentsOf: memoryURL),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values
    }

    private func saveMemories() {
        do {
            try FileManager.default.createDirectory(at: Self.memoryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(memories)
            try data.write(to: Self.memoryURL, options: .atomic)
        } catch {
            messages.append(TauronAssistantMessage(role: "Tauron AI", text: "Could not save local memory: \(error.localizedDescription)"))
        }
    }

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
    @ObservedObject var assistant: TauronAIService
    let directory: URL
    @State private var showKeySetup = false
    @State private var showMemorySheet = false
    @State private var keyDraft = ""
    @State private var memoryDraft = ""
    @State private var attachedFile: String?
    @State private var attachedName: String?
    @State private var keyMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "sparkles").foregroundStyle(.purple)
                Text("TAURON AI").font(.system(size: 12, weight: .bold, design: .monospaced))
                Spacer()
                Picker("AI provider", selection: $assistant.provider) {
                    ForEach(TauronAIProvider.allCases) { provider in Text(provider.label).tag(provider) }
                }.pickerStyle(.menu).frame(width: 155)
                Button { showMemorySheet = true } label: {
                    Label("Memory (\(assistant.memories.count))", systemImage: "brain")
                }
                Button { keyMessage = nil; showKeySetup = true } label: {
                    Label(assistant.provider == .gemini ? (assistant.hasAPIKey ? "Gemini Settings" : "Connect Gemini…") : "Local Model Settings", systemImage: "gearshape")
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
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Tauron AI is thinking…") }
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
                    .help("Attach a text or code file for Tauron AI to review")
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $assistant.draft)
                        .font(.system(size: 12))
                        .frame(height: 62)
                    if assistant.draft.isEmpty {
                        Text("Ask Tauron AI about code or a terminal task…")
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
        .sheet(isPresented: $showKeySetup) { providerSetupSheet }
        .sheet(isPresented: $showMemorySheet) { memorySheet }
    }

    private var providerSetupSheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tauron AI Provider").font(.title2.bold())
            Picker("Provider", selection: $assistant.provider) {
                ForEach(TauronAIProvider.allCases) { provider in Text(provider.label).tag(provider) }
            }.pickerStyle(.segmented)
            if assistant.provider == .gemini {
                Text("Use your own Google AI Studio API key. Tauron stores it in macOS Keychain. Prompts, attached files, and saved memories are sent directly to Google's Gemini API.")
                    .fixedSize(horizontal: false, vertical: true)
                Link("Get a Gemini API key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                SecureField(assistant.hasAPIKey ? "Enter a replacement API key" : "Paste API key", text: $keyDraft)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text("Ollama runs an AI model on this Mac. Prompts, attached files, and saved memories stay local with this provider.")
                    .fixedSize(horizontal: false, vertical: true)
                Link("Install Ollama", destination: URL(string: "https://ollama.com/download")!)
                TextField("Installed Ollama model name", text: $assistant.localModel)
                    .textFieldStyle(.roundedBorder)
                Text("Start Ollama and download a model first. Default: gemma4. Enter a model name that is installed on your Mac.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            if let keyMessage { Text(keyMessage).font(.system(size: 12)).foregroundStyle(.red) }
            HStack {
                if assistant.provider == .gemini && assistant.hasAPIKey {
                    Button("Remove Key") { assistant.removeAPIKey(); keyDraft = ""; showKeySetup = false }
                }
                Spacer()
                Button("Cancel") { showKeySetup = false }
                if assistant.provider == .gemini {
                    Button("Save in Keychain") {
                        if assistant.saveAPIKey(keyDraft) { keyDraft = ""; showKeySetup = false }
                        else { keyMessage = "Could not save the key in Keychain. Try again." }
                    }.keyboardShortcut(.defaultAction)
                        .disabled(keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button("Done") { showKeySetup = false }.keyboardShortcut(.defaultAction)
                }
            }
        }.padding(22).frame(width: 440)
    }

    private var memorySheet: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Tauron AI Local Memory").font(.title2.bold())
            Text("Save preferences or project notes for Tauron AI to use between chats. Notes are stored on this Mac and included with requests to whichever provider you select.")
                .fixedSize(horizontal: false, vertical: true)
            List {
                ForEach(Array(assistant.memories.enumerated()), id: \.offset) { index, note in
                    HStack(alignment: .top) {
                        Text(note).frame(maxWidth: .infinity, alignment: .leading)
                        Button { assistant.forgetMemory(at: index) } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain).help("Forget this note")
                    }.padding(.vertical, 3)
                }
            }.frame(minHeight: 160)
            HStack {
                TextField("A preference or project note to remember…", text: $memoryDraft)
                    .textFieldStyle(.roundedBorder)
                Button("Remember") {
                    assistant.remember(memoryDraft)
                    memoryDraft = ""
                }.disabled(memoryDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            HStack {
                if !assistant.memories.isEmpty { Button("Forget All") { assistant.clearMemories() } }
                Spacer()
                Button("Done") { showMemorySheet = false }.keyboardShortcut(.defaultAction)
            }
        }.padding(22).frame(width: 560, height: 420)
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
