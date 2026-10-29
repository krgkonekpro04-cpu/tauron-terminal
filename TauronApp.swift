import AppKit
import Combine
import SwiftUI

@MainActor
final class TauronSession: ObservableObject {
    @Published var output = ""
    @Published var command = ""
    @Published var currentDirectory = FileManager.default.homeDirectoryForCurrentUser
    @Published var files: [URL] = []
    @Published var isReady = false

    private var process: Process?
    private var inputPipe: Pipe?
    private var updater: Process?
    private var started = false

    private var supportDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tauron", isDirectory: true)
    }

    func start() {
        guard !started else { return }
        started = true
        refreshFiles()

        guard let python = pythonExecutable() else {
            append("Tauron needs Python 3. Install Python 3, then reopen Tauron.\n")
            return
        }

        let updateProcess = Process()
        updater = updateProcess
        updateProcess.executableURL = python
        updateProcess.arguments = [supportDirectory.appendingPathComponent("tauron-updater.py").path]
        var updaterEnvironment = ProcessInfo.processInfo.environment
        updaterEnvironment["TAURON_MANAGED_RELAUNCH"] = "1"
        updateProcess.environment = updaterEnvironment
        updateProcess.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                if process.terminationStatus == 10 {
                    self?.relaunchUpdatedApp()
                } else {
                    self?.launchCommandEngine()
                }
            }
        }
        do {
            try updateProcess.run()
        } catch {
            launchCommandEngine()
        }
    }

    func submit() {
        let line = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty, let inputPipe else { return }
        append("\n\(promptText)\(line)\n")
        command = ""
        if line == "clear" || line == "cls" || line == "wipe" || line == "screen" {
            output = ""
        }
        let data = Data((line + "\n").utf8)
        inputPipe.fileHandleForWriting.write(data)
        refreshDirectoryFromCD(line)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Tauron working folder"
        panel.prompt = "Use Folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = currentDirectory
        guard panel.runModal() == .OK, let selected = panel.url else { return }
        changeDirectory(to: selected)
    }

    func open(_ url: URL) {
        var isDirectory: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
        if isDirectory.boolValue {
            changeDirectory(to: url)
        } else {
            sendCommand("cat \"\(escaped(url.lastPathComponent))\"")
        }
    }

    var promptText: String { "tauron:\(currentDirectory.lastPathComponent) $ " }

    private func launchCommandEngine() {
        guard let python = pythonExecutable() else {
            append("Tauron needs Python 3. Install Python 3, then reopen Tauron.\n")
            return
        }
        let engine = Process()
        process = engine
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        let commandPipe = Pipe()
        inputPipe = commandPipe
        engine.executableURL = python
        engine.arguments = [supportDirectory.appendingPathComponent("tauron.py").path]
        engine.currentDirectoryURL = currentDirectory
        var environment = ProcessInfo.processInfo.environment
        environment["TAURON_GUI"] = "1"
        environment["TAURON_APP_VERSION"] = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        engine.environment = environment
        engine.standardInput = commandPipe
        engine.standardOutput = outputPipe
        engine.standardError = errorPipe
        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = String(decoding: data, as: UTF8.self)
                .replacingOccurrences(of: "\u{001B}\\[[0-9;]*[A-Za-z]", with: "", options: .regularExpression)
            DispatchQueue.main.async { self?.append(text) }
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { handle.readabilityHandler = nil; return }
            let text = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async { self?.append(text) }
        }
        do {
            try engine.run()
            isReady = true
            append("TAURON DESKTOP  //  Ready\nChoose a Mac folder or type help to begin.\n\n")
        } catch {
            append("Could not start Tauron’s command engine. Make sure Python 3 is installed.\n\(error.localizedDescription)\n")
        }
    }

    private func pythonExecutable() -> URL? {
        let manager = FileManager.default
        var candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/Library/Frameworks/Python.framework/Versions/Current/bin/python3",
            "/opt/local/bin/python3",
            "/usr/bin/python3",
        ]
        candidates.append(contentsOf: (ProcessInfo.processInfo.environment["PATH"] ?? "")
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent("python3").path })
        if let path = candidates.first(where: { manager.isExecutableFile(atPath: $0) }) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    private func relaunchUpdatedApp() {
        let installedApp = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/Tauron.app", isDirectory: true)
        let app = FileManager.default.fileExists(atPath: installedApp.path) ? installedApp : Bundle.main.bundleURL
        let opener = Process()
        opener.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        opener.arguments = ["-n", app.path]
        do {
            try opener.run()
            NSApp.terminate(nil)
        } catch {
            append("Tauron updated. Quit and reopen the app to finish updating.\n")
            launchCommandEngine()
        }
    }

    private func changeDirectory(to url: URL) {
        currentDirectory = url.standardizedFileURL
        refreshFiles()
        if isReady {
            sendCommand("cd \"\(escaped(currentDirectory.path))\"")
        }
    }

    private func refreshFiles() {
        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: currentDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            files = urls.sorted { left, right in
                let leftDir = (try? left.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                let rightDir = (try? right.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                if leftDir != rightDir { return leftDir }
                return left.lastPathComponent.localizedCaseInsensitiveCompare(right.lastPathComponent) == .orderedAscending
            }
        } catch {
            files = []
        }
    }

    private func refreshDirectoryFromCD(_ line: String) {
        let pieces = line.split(separator: " ", maxSplits: 1).map(String.init)
        guard let name = pieces.first, ["cd", "chdir", "go", "enter", "goto", "openfolder", "changefolder", "moveinto", "switchdir"].contains(name) else {
            refreshFiles()
            return
        }
        guard pieces.count > 1 else {
            currentDirectory = FileManager.default.homeDirectoryForCurrentUser
            refreshFiles()
            return
        }
        var raw = pieces[1].trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.first == "\"", raw.last == "\"", raw.count >= 2 { raw = String(raw.dropFirst().dropLast()) }
        if raw.first == "'", raw.last == "'", raw.count >= 2 { raw = String(raw.dropFirst().dropLast()) }
        raw = (raw as NSString).expandingTildeInPath
        let target = raw.hasPrefix("/") ? URL(fileURLWithPath: raw) : currentDirectory.appendingPathComponent(raw)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory), isDirectory.boolValue {
            currentDirectory = target.standardizedFileURL
            refreshFiles()
        }
    }

    private func sendCommand(_ line: String) {
        guard let inputPipe else { return }
        inputPipe.fileHandleForWriting.write(Data((line + "\n").utf8))
    }

    private func escaped(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func append(_ text: String) { output += text }
}

struct TauronWindow: View {
    @StateObject private var session = TauronSession()
    @StateObject private var assistant = TauronAIService()
    @State private var showAssistant = false
    @State private var hasAcceptedTerms = UserDefaults.standard.string(forKey: "tauron.acceptedTermsVersion") == TauronTerms.version

    var body: some View {
        Group {
            if hasAcceptedTerms {
                mainInterface
            } else {
                TauronTermsAcceptanceView {
                    UserDefaults.standard.set(TauronTerms.version, forKey: "tauron.acceptedTermsVersion")
                    hasAcceptedTerms = true
                    session.start()
                } onReject: {
                    NSApp.terminate(nil)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 540)
        .task {
            if hasAcceptedTerms { session.start() }
        }
    }

    private var mainInterface: some View {
        ZStack {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.purple.opacity(0.13), Color.cyan.opacity(0.09)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ).ignoresSafeArea()
            Rectangle().fill(.ultraThinMaterial).opacity(0.68).ignoresSafeArea()

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.purple)
                        .frame(width: 34, height: 34)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TAURON").font(.system(size: 16, weight: .bold, design: .monospaced))
                        Text("Desktop Terminal").font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { showAssistant = false }
                    } label: { Label("Terminal", systemImage: "terminal") }
                        .buttonStyle(.borderedProminent)
                        .tint(showAssistant ? .secondary : .accentColor)
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) { showAssistant = true }
                    } label: { Label("Tauron AI", systemImage: "sparkles") }
                        .buttonStyle(.borderedProminent)
                        .tint(showAssistant ? .accentColor : .secondary)
                }
                .padding(.horizontal, 15).padding(.vertical, 11)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))

                HStack(spacing: 12) {
                    fileSidebar
                        .frame(width: 250)
                        .frame(maxHeight: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    Group {
                        if showAssistant {
                            TauronAssistantView(assistant: assistant, directory: session.currentDirectory)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                        } else {
                            terminalPanel
                                .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showAssistant)

                HStack(spacing: 7) {
                    Image(systemName: "folder").foregroundStyle(.purple)
                    Text("Commands work in the selected Mac folder.")
                    Spacer()
                    Text("Type help for commands")
                }
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.horizontal, 4).padding(.vertical, 2)
            }
            .padding(14)
        }
        .frame(minWidth: 900, minHeight: 580)
    }

    private var fileSidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MAC FILES").font(.system(size: 11, weight: .bold, design: .monospaced))
            Text(session.currentDirectory.path).font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.secondary).lineLimit(2).truncationMode(.middle)
            List(session.files, id: \.path) { url in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                Label(url.lastPathComponent, systemImage: isDirectory ? "folder" : "doc.text")
                    .lineLimit(1).contentShape(Rectangle())
                    .onTapGesture(count: 2) { session.open(url) }
            }
            .listStyle(.plain)
            .background(Color.clear)
            .animation(.easeInOut(duration: 0.18), value: session.files)
            Button(action: session.chooseFolder) { Label("Choose Folder…", systemImage: "folder.badge.plus") }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
        }
        .padding(12)
    }

    private var terminalPanel: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(session.output)
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .id("terminal-bottom")
                }
                .background(Color.clear)
                .onChange(of: session.output) { _ in proxy.scrollTo("terminal-bottom", anchor: .bottom) }
            }
            Divider()
            HStack(spacing: 8) {
                Text("tauron:$").font(.system(size: 12, weight: .bold, design: .monospaced))
                TextField("Enter a Tauron command", text: $session.command)
                    .textFieldStyle(.plain).font(.system(size: 12, design: .monospaced))
                    .onSubmit { session.submit() }
                Button("Run") { session.submit() }.keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
            .padding(12)
        }
    }
}

private enum TauronTerms {
    static let version = "1.0"

    static var text: String {
        let url = Bundle.main.url(forResource: "TERMS_OF_SERVICE", withExtension: "md")
        return (url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }) ?? "Tauron Terms of Service could not be loaded. Please reinstall Tauron before continuing."
    }
}

private struct TauronTermsAcceptanceView: View {
    let onAccept: () -> Void
    let onReject: () -> Void
    @State private var showMore = false

    private var formattedTerms: AttributedString {
        (try? AttributedString(markdown: TauronTerms.text)) ?? AttributedString(TauronTerms.text)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill").font(.system(size: 24)).foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 3) {
                    Text("TAURON").font(.system(size: 17, weight: .bold, design: .monospaced))
                    Text("Terms of Service · Version \(TauronTerms.version)").foregroundStyle(.secondary)
                }
                Spacer()
            }.padding(20)
            Divider()
            ScrollView {
                Text(formattedTerms)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                if showMore {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("In plain language").font(.headline)
                        Text("Tauron runs commands on the Mac folder you choose, so review file-changing commands and keep backups. Tauron AI suggestions need your review. Ollama keeps prompts on your Mac; Gemini sends prompts and included context to Google. The updater checks for Tauron releases. You can reject these terms and close the app, or accept to continue.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 22).padding(.bottom, 22)
                }
            }
            Divider()
            HStack {
                Button("Reject") { onReject() }
                    .keyboardShortcut(.cancelAction)
                Button(showMore ? "Hide Details" : "Learn More") { showMore.toggle() }
                Spacer()
                Button("Accept") { onAccept() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }.padding(16)
        }
        .frame(minWidth: 640, minHeight: 500)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(12)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: showMore)
    }
}

@main
struct TauronApp: App {
    var body: some Scene {
        WindowGroup("Tauron Desktop") { TauronWindow() }
    }
}
