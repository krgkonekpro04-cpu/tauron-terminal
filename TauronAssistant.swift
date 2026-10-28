import AppKit
import Combine
import Foundation
import Security
import SwiftUI

private final class TauronPromptTextView: NSTextView {
    var onSend: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 76 {
            if event.modifierFlags.contains(.shift) {
                super.keyDown(with: event)
            } else {
                onSend?()
            }
            return
        }
        super.keyDown(with: event)
    }
}

private struct TauronPromptEditor: NSViewRepresentable {
    @Binding var text: String
    let onSend: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = TauronPromptTextView()
        textView.delegate = context.coordinator
        textView.onSend = onSend
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainerInset = NSSize(width: 5, height: 7)
        textView.font = .systemFont(ofSize: 12)
        textView.textColor = .labelColor
        textView.drawsBackground = false
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? TauronPromptTextView else { return }
        textView.onSend = onSend
        if textView.string != text { textView.string = text }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String

        init(text: Binding<String>) { _text = text }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

struct TauronAssistantMessage: Identifiable {
    let id = UUID()
    let role: String
    var text: String
}

enum TauronAIProvider: String, CaseIterable, Identifiable {
    case gemini
    case ollama

    var id: String { rawValue }
    var label: String { self == .gemini ? "Gemini (optional cloud)" : "Ollama (on this Mac)" }
}

@MainActor
final class TauronAIService: ObservableObject {
    @Published var messages = [TauronAssistantMessage(role: "Tauron", text: "Hi! I can explain Tauron commands, help you write code, and review an attached text file. I only suggest commands and changes; I do not run or apply them.")]
    @Published var draft = ""
    @Published var isWorking = false
    @Published var isTyping = false
    @Published private(set) var hasAPIKey = false
    @Published var provider: TauronAIProvider {
        didSet { UserDefaults.standard.set(provider.rawValue, forKey: "tauron.ai.provider") }
    }
    @Published var localModel: String {
        didSet { UserDefaults.standard.set(localModel, forKey: "tauron.ai.ollamaModel") }
    }
    @Published var memories: [String] = []

    private var apiKey: String? { Self.readKey() }
    var latestMessageText: String { messages.last?.text ?? "" }

    init() {
        // Prefer the on-device provider so Tauron works without a Gemini account or key.
        provider = TauronAIProvider(rawValue: UserDefaults.standard.string(forKey: "tauron.ai.provider") ?? "") ?? .ollama
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
            messages.append(TauronAssistantMessage(role: "Tauron AI", text: "Connect a Gemini API key in settings, or switch to the local Ollama provider. Tauron AI defaults to Ollama so it can work without Gemini."))
            return
        }
        draft = ""
        messages.append(TauronAssistantMessage(role: "You", text: question))
        isWorking = true
        defer { isWorking = false }

        let workspaceContext = provider == .ollama ? Self.localWorkspaceContext(directory) : ""
        let systemPrompt = """
        You are Tauron AI, a careful coding and terminal assistant. Help with macOS programming, beginner-friendly coding, the Tauron command language, Tauron mods (.tau and .tauron), and safe file-work workflows. Explain your reasoning briefly, inspect the supplied project context before proposing edits, point out likely bugs, and give complete, runnable examples when useful. Ask a focused question when a missing detail changes the answer.

        Tauron commands include help, ls, cd, cat, mkdir, touch, cp, mv, rm, find, mod, and changelog. Tauron is a custom command interpreter: it does not run arbitrary shell commands, pipes, or redirection. Never claim that you ran a command or changed a file. Do not ask for passwords, API keys, or other secrets. Clearly label destructive commands and explain what they remove or overwrite.

        Current Tauron folder: \(directory.path)
        User-approved local notes to remember between chats:
        \(memories.isEmpty ? "No saved notes." : memories.map { "- \($0)" }.joined(separator: "\n"))
        \(workspaceContext)
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
            await typeOut(answer, role: "Tauron AI")
        } catch {
            let service = provider == .gemini ? "Gemini" : "Ollama"
            messages.append(TauronAssistantMessage(role: "Tauron AI", text: "\(service) request failed: \(error.localizedDescription)"))
        }
    }

    private func typeOut(_ text: String, role: String) async {
        let message = TauronAssistantMessage(role: role, text: "")
        messages.append(message)
        isTyping = true
        defer { isTyping = false }
        for character in text {
            if Task.isCancelled { break }
            guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
            var updated = messages[index]
            updated.text.append(character)
            messages[index] = updated
            try? await Task.sleep(nanoseconds: 18_000_000)
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

    /// Give an on-device model useful, bounded project context without uploading files.
    private static func localWorkspaceContext(_ directory: URL) -> String {
        let allowedExtensions: Set<String> = ["swift", "py", "js", "jsx", "ts", "tsx", "html", "css", "json", "md", "txt", "tau", "tauron", "sh", "yml", "yaml", "toml"]
        let sensitiveNameParts = ["secret", "credential", "password", "token", "apikey", "api_key", ".env"]
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let candidates = entries.filter { url in
            allowedExtensions.contains(url.pathExtension.lowercased()) &&
            !sensitiveNameParts.contains(where: { url.lastPathComponent.lowercased().contains($0) }) &&
            (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        var sections: [String] = []
        var remainingCharacters = 36_000
        for url in candidates.prefix(8) where remainingCharacters > 0 {
            guard let data = try? Data(contentsOf: url),
                  let contents = String(data: data.prefix(min(data.count, min(12_000, remainingCharacters))), encoding: .utf8),
                  !contents.isEmpty else { continue }
            let section = "File: \(url.lastPathComponent)\n```\n\(contents)\n```"
            sections.append(section)
            remainingCharacters -= section.count
        }
        guard !sections.isEmpty else {
            return "Local project context: no readable source or Tauron files found directly in the selected folder."
        }
        return "Local project context (read-only; only files in the selected folder, never uploaded by Ollama):\n" + sections.joined(separator: "\n\n")
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
                                    .foregroundStyle(message.role == "Tauron AI" ? .purple : .secondary)
                                Text(message.text)
                                    .font(.system(size: 13))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }.id(message.id)
                        }
                        if assistant.isWorking && !assistant.isTyping {
                            HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Tauron AI is thinking…") }
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                    }.padding(18)
                }
                .onChange(of: assistant.latestMessageText) { _ in
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
                    TauronPromptEditor(text: $assistant.draft, onSend: send)
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
                Text("Ollama runs an open model on this Mac. Tauron AI uses the selected folder’s readable source files as extra context, alongside attachments and saved notes. Nothing is sent to Gemini with this provider. Install Ollama and download a model once; Ollama can then answer offline.")
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
