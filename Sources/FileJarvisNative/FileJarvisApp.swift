import AppKit
import SwiftUI

private let launcherIconPath = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Assets/jarvis_launcher.png")
    .path

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let viewModel: JarvisViewModel
    let windowCoordinator: WindowCoordinator

    private init() {
        AppEnvironment.loadOpenAIKeyIfNeeded()
        self.viewModel = JarvisViewModel()
        self.windowCoordinator = WindowCoordinator()
    }
}

@main
struct FileJarvisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(viewModel: AppState.shared.viewModel)
                .frame(width: 420, height: 250)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let appState = AppState.shared
        appState.viewModel.loadPersistedFolderIfNeeded()
        appState.windowCoordinator.configure(viewModel: appState.viewModel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@MainActor
final class WindowCoordinator: NSObject, NSWindowDelegate {
    private var launcherWindow: NSWindow?
    private var mainWindow: NSWindow?
    private var hasConfigured = false

    func configure(viewModel: JarvisViewModel) {
        guard !hasConfigured else { return }
        hasConfigured = true

        createLauncherWindow()
        createMainWindow(viewModel: viewModel)

        launcherWindow?.orderFrontRegardless()
        showMainWindow()
    }

    func toggleMainWindow() {
        guard let mainWindow else { return }

        if mainWindow.isVisible {
            hideMainWindow()
        } else {
            showMainWindow()
        }
    }

    func showMainWindow() {
        guard let mainWindow else { return }
        mainWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideMainWindow() {
        mainWindow?.orderOut(nil)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let mainWindow, sender === mainWindow {
            hideMainWindow()
            return false
        }
        return true
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === mainWindow else {
            return
        }

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window, !window.isKeyWindow else { return }

            // Keep the assistant visible while a folder picker or another modal panel is open.
            guard NSApp.modalWindow == nil, window.attachedSheet == nil else { return }
            self.hideMainWindow()
        }
    }

    private func createLauncherWindow() {
        let size = NSSize(width: 92, height: 92)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = NSPoint(
            x: screenFrame.maxX - size.width - 26,
            y: screenFrame.midY - (size.height / 2)
        )

        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false

        window.contentView = NSHostingView(
            rootView: FloatingLauncherView {
                self.toggleMainWindow()
            }
        )

        launcherWindow = window
    }

    private func createMainWindow(viewModel: JarvisViewModel) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 920),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 640, height: 820)
        window.delegate = self

        window.contentView = NSHostingView(
            rootView: ContentView(
                viewModel: viewModel,
                onHide: { [weak self] in
                    self?.hideMainWindow()
                }
            )
        )

        mainWindow = window
    }
}

struct FloatingLauncherView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.clear)

                if let image = NSImage(contentsOfFile: launcherIconPath) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 92)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.92))

                    Image(systemName: "sparkles")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .frame(width: 92, height: 92)
            .overlay(
                Circle()
                    .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.cyan.opacity(0.18), radius: 10, x: 0, y: 4)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

struct ContentView: View {
    @ObservedObject var viewModel: JarvisViewModel
    let onHide: () -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    accessCard
                    assistantCard
                    filesCard
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 640, minHeight: 820)
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("file_jarvis")
                    .font(.system(size: 26, weight: .semibold))

                Text("Your files, quietly within reach.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onHide) {
                Label("Hide", systemImage: "xmark")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.bordered)
        }
    }

    private var accessCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Access")
                    .sectionEyebrow()

                HStack(alignment: .center, spacing: 10) {
                    AccessBadge(
                        title: viewModel.approvedFolder?.lastPathComponent ?? "No folder approved",
                        subtitle: viewModel.approvedFolder == nil ? "Choose one folder to get started" : "Current approved scope",
                        systemImage: "folder.badge.gearshape"
                    )

                    Spacer()

                    Button("Choose Folder") {
                        viewModel.chooseFolder()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Refresh") {
                        viewModel.refreshFiles()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.approvedFolder == nil)

                    Button("Remove Folder") {
                        viewModel.removeApprovedFolder()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.approvedFolder == nil)
                }

                if let apiStatusLabel = viewModel.apiStatusLabel {
                    StatusChip(text: apiStatusLabel, tint: Color.green)
                }

                if let helper = viewModel.helperText, !helper.isEmpty {
                    Text(helper)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var assistantCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Ask Jarvis")
                    .sectionEyebrow()

                TextField("Ask Jarvis about this folder...", text: $viewModel.prompt, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .lineLimit(3...7)
                    .padding(12)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
                    )

                HStack(spacing: 8) {
                    Button("What can you see?") {
                        viewModel.prompt = "What can you see right now?"
                    }
                    .buttonStyle(.bordered)

                    Button("Suggest cleanup") {
                        viewModel.prompt = "Suggest the best cleanup starting point."
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Clear Chat") {
                        viewModel.clearChatHistory()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button {
                        Task {
                            await viewModel.sendPrompt()
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Ask")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        viewModel.isLoading ||
                        viewModel.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }

                Divider()

                Text("Conversation")
                    .sectionEyebrow()

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                            }

                            if viewModel.isLoading {
                                ThinkingBubble()
                                    .transition(.opacity)
                            }

                            Color.clear
                                .frame(height: 1)
                                .id("conversation-bottom")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .onChange(of: viewModel.messages.count) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("conversation-bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.isLoading) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("conversation-bottom", anchor: .bottom)
                        }
                    }
                }
                .frame(minHeight: 240, idealHeight: 300, maxHeight: 340)
            }
        }
    }

    private var filesCard: some View {
        SurfaceCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Visible Files")
                    .sectionEyebrow()

                if let folder = viewModel.approvedFolder {
                    let tree = buildFolderTree(from: viewModel.files)

                    Text("Folder Tree")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "externaldrive.fill")
                                    .foregroundColor(.accentColor)

                                Text(folder.lastPathComponent)
                                    .font(.system(size: 13, weight: .semibold))
                            }

                            FolderTreeView(node: tree, depth: 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 180)

                    Divider()
                }

                if let selectedFile = viewModel.selectedFile {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Manage Selected File")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text(selectedFile.relativePath)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rename")
                                .font(.system(size: 12, weight: .semibold))

                            HStack(spacing: 8) {
                                TextField("New file name", text: $viewModel.renameTargetName)
                                    .textFieldStyle(.roundedBorder)

                                Button("Rename") {
                                    viewModel.renameSelectedFile()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Move")
                                .font(.system(size: 12, weight: .semibold))

                            HStack(spacing: 8) {
                                TextField("Folder path inside approved scope", text: $viewModel.moveTargetFolder)
                                    .textFieldStyle(.roundedBorder)

                                Button("Move") {
                                    viewModel.moveSelectedFile()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }

                        Button("Clear Selection") {
                            viewModel.clearSelection()
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.files) { file in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(alignment: .top) {
                                    Text(file.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Text(file.kind)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }

                                Text(file.relativePath)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)

                                HStack(spacing: 8) {
                                    Text(file.sizeLabel)
                                    Text(file.modifiedLabel)
                                }
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)

                                if let preview = file.preview, !preview.isEmpty {
                                    Text(preview)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                HStack {
                                    Spacer()

                                    Button("Manage") {
                                        viewModel.selectFile(file)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 220, idealHeight: 280, maxHeight: 320)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct SettingsView: View {
    @ObservedObject var viewModel: JarvisViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 22, weight: .semibold))

            Text("file_jarvis stays scoped to the folder you approve. The floating J.A.R.V.I.S. icon stays on screen, and clicking it shows or hides the assistant.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            if let folder = viewModel.approvedFolder {
                Text("Approved folder: \(folder.path)")
                    .font(.system(size: 12))
                    .textSelection(.enabled)
            } else {
                Text("No folder approved yet.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
    }
}

struct SurfaceCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.8)
            )
    }
}

struct AccessBadge: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatusChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint.opacity(0.12))
            .clipShape(Capsule())
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 50)
            }

            Text(message.text)
                .font(.system(size: 13))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    message.role == .user
                    ? Color.accentColor.opacity(0.16)
                    : Color(nsColor: .controlBackgroundColor)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 0.6)
                )

            if message.role == .assistant {
                Spacer(minLength: 50)
            }
        }
    }
}

struct ThinkingBubble: View {
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)

                Text("Jarvis is thinking...")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 0.6)
            )

            Spacer(minLength: 50)
        }
    }
}

struct FolderNode: Identifiable {
    let id = UUID()
    let name: String
    var folders: [FolderNode] = []
    var files: [String] = []
}

func buildFolderTree(from files: [LocalFileItem]) -> FolderNode {
    var root = FolderNode(name: "root")

    for file in files {
        let parts = file.relativePath.split(separator: "/").map(String.init)
        guard !parts.isEmpty else { continue }
        insert(parts, into: &root)
    }

    sortNode(&root)
    return root
}

func insert(_ parts: [String], into node: inout FolderNode) {
    guard let first = parts.first else { return }

    if parts.count == 1 {
        node.files.append(first)
        return
    }

    if let index = node.folders.firstIndex(where: { $0.name == first }) {
        insert(Array(parts.dropFirst()), into: &node.folders[index])
    } else {
        var newFolder = FolderNode(name: first)
        insert(Array(parts.dropFirst()), into: &newFolder)
        node.folders.append(newFolder)
    }
}

func sortNode(_ node: inout FolderNode) {
    node.folders.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    node.files.sort { $0.localizedStandardCompare($1) == .orderedAscending }

    for index in node.folders.indices {
        sortNode(&node.folders[index])
    }
}

struct FolderTreeView: View {
    let node: FolderNode
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(node.folders) { folder in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.accentColor)
                        Text(folder.name)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .padding(.leading, CGFloat(depth) * 16)

                    FolderTreeView(node: folder, depth: depth + 1)
                }
            }

            ForEach(node.files, id: \.self) { file in
                HStack(spacing: 8) {
                    Image(systemName: "doc")
                        .foregroundColor(.secondary)
                    Text(file)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, CGFloat(depth) * 16)
            }
        }
    }
}

extension Text {
    func sectionEyebrow() -> some View {
        self
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
    }
}
