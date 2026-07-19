import AppKit
import Foundation
import SwiftUI

@MainActor
final class JarvisViewModel: ObservableObject {
    @Published var approvedFolder: URL?
    @Published var files: [LocalFileItem] = []
    @Published var messages: [ChatMessage] = [
        ChatMessage(
            role: .assistant,
            text: "Approve one folder, then ask what you want help with. I’ll stay scoped to that folder."
        )
    ]
    @Published var prompt = ""
    @Published var isLoading = false
    @Published var helperText: String?

    private let bookmarkStore = BookmarkStore()
    private let openAIClient = OpenAIClient()
    private let fileScanner = FileScanner()

    @Published var selectedRelativePath: String?
    @Published var renameTargetName = ""
    @Published var moveTargetFolder = ""

    var apiStatusLabel: String? {
        guard let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !key.isEmpty else {
            return nil
        }
        return "OpenAI ready"
    }

    var selectedFile: LocalFileItem? {
        guard let selectedRelativePath else { return nil }
        return files.first { $0.relativePath == selectedRelativePath }
    }

    func selectFile(_ file: LocalFileItem) {
        selectedRelativePath = file.relativePath
        renameTargetName = file.name

        let nsPath = file.relativePath as NSString
        let parentPath = nsPath.deletingLastPathComponent

        if parentPath == "." || parentPath.isEmpty {
            moveTargetFolder = ""
        } else {
            moveTargetFolder = parentPath
        }
    }

    func clearSelection() {
        selectedRelativePath = nil
        renameTargetName = ""
        moveTargetFolder = ""
    }

    func clearChatHistory() {
        messages = [
            ChatMessage(
                role: .assistant,
                text: "Approve one folder, then ask what you want help with. I’ll stay scoped to that folder."
            )
        ]
        helperText = "Chat history cleared."
    }

    func loadPersistedFolderIfNeeded() {
        guard approvedFolder == nil else { return }

        if let url = bookmarkStore.resolveBookmark() {
            approvedFolder = url
            refreshFiles()
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Approve Folder"
        panel.message = "Choose one folder for Jarvis to inspect."

        if panel.runModal() == .OK, let url = panel.url {
            bookmarkStore.saveBookmark(for: url)
            approvedFolder = url
            helperText = "Jarvis is now scoped to \(url.lastPathComponent)."
            refreshFiles()
        }
    }

    func refreshFiles() {
        guard let approvedFolder else {
            files = []
            return
        }

        files = fileScanner.scanFolder(at: approvedFolder)
    }

    func renameSelectedFile() {
        guard let approvedFolder, let selectedFile else {
            helperText = "Choose a file first."
            return
        }

        let trimmedName = renameTargetName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            helperText = "Enter a new file name."
            return
        }

        guard !trimmedName.contains("/") else {
            helperText = "File name cannot contain /"
            return
        }

        let destinationURL = selectedFile.url
            .deletingLastPathComponent()
            .appendingPathComponent(trimmedName)

        guard isInsideApprovedFolder(destinationURL, approvedFolder: approvedFolder) else {
            helperText = "Rename target must stay inside the approved folder."
            return
        }

        do {
            try FileManager.default.moveItem(at: selectedFile.url, to: destinationURL)
            helperText = "Renamed \(selectedFile.name) to \(trimmedName)."
            let newRelativePath = destinationURL.path.replacingOccurrences(of: approvedFolder.path + "/", with: "")
            refreshFiles()
            selectedRelativePath = newRelativePath
        } catch {
            helperText = "Rename failed: \(error.localizedDescription)"
        }
    }

    func moveSelectedFile() {
        guard let approvedFolder, let selectedFile else {
            helperText = "Choose a file first."
            return
        }

        let trimmedFolder = moveTargetFolder.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedFolder.hasPrefix("/") else {
            helperText = "Destination folder must be relative to the approved folder."
            return
        }

        let destinationFolderURL = trimmedFolder.isEmpty
            ? approvedFolder
            : approvedFolder.appendingPathComponent(trimmedFolder)

        let destinationURL = destinationFolderURL.appendingPathComponent(selectedFile.name)

        guard isInsideApprovedFolder(destinationFolderURL, approvedFolder: approvedFolder),
              isInsideApprovedFolder(destinationURL, approvedFolder: approvedFolder) else {
            helperText = "Move target must stay inside the approved folder."
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: destinationFolderURL,
                withIntermediateDirectories: true
            )

            try FileManager.default.moveItem(at: selectedFile.url, to: destinationURL)
            helperText = "Moved \(selectedFile.name) to \(trimmedFolder.isEmpty ? approvedFolder.lastPathComponent : trimmedFolder)."
            let newRelativePath = destinationURL.path.replacingOccurrences(of: approvedFolder.path + "/", with: "")
            refreshFiles()
            selectedRelativePath = newRelativePath
        } catch {
            helperText = "Move failed: \(error.localizedDescription)"
        }
    }

    private func isInsideApprovedFolder(_ url: URL, approvedFolder: URL) -> Bool {
        let folderPath = approvedFolder.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path

        return candidatePath == folderPath || candidatePath.hasPrefix(folderPath + "/")
    }

    func removeApprovedFolder() {
        approvedFolder?.stopAccessingSecurityScopedResource()
        approvedFolder = nil
        files = []
        bookmarkStore.clearBookmark()
        helperText = "Folder access removed."
    }

    func sendPrompt() async {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else { return }

        if approvedFolder == nil {
            messages.append(ChatMessage(role: .user, text: trimmedPrompt))
            messages.append(
                ChatMessage(
                    role: .assistant,
                    text: "Choose one folder first, then I can help with files inside that approved scope."
                )
            )
            prompt = ""
            helperText = "No folder approved yet."
            return
        }

        guard let approvedFolder else { return }

        messages.append(ChatMessage(role: .user, text: trimmedPrompt))
        prompt = ""
        isLoading = true
        helperText = nil

        do {
            let response = try await openAIClient.askAboutFolder(
                question: trimmedPrompt,
                folderURL: approvedFolder,
                files: files
            )
            messages.append(ChatMessage(role: .assistant, text: response))
        } catch {
            let fallback = fallbackReply(for: trimmedPrompt, approvedFolder: approvedFolder)
            messages.append(ChatMessage(role: .assistant, text: fallback))
            helperText = error.localizedDescription
        }

        isLoading = false
    }

    private func fallbackReply(for prompt: String, approvedFolder: URL) -> String {
        let lowercased = prompt.lowercased()

        if ["hi", "hello", "hey"].contains(lowercased) {
            return "Hi. I can see \(files.count) file\(files.count == 1 ? "" : "s") inside \(approvedFolder.lastPathComponent). Ask me what you want to find or organize."
        }

        if lowercased.contains("see") || lowercased.contains("scope") {
            return "I’m currently scoped to \(approvedFolder.lastPathComponent). I can see \(files.count) file\(files.count == 1 ? "" : "s") there."
        }

        if lowercased.contains("clean") || lowercased.contains("organize") {
            return "The fastest MVP cleanup suggestion is to start with the most recently modified files and any screenshots or markdown notes that look unlabeled."
        }

        return "I couldn’t reach OpenAI for that request, but I’m still scoped to \(approvedFolder.lastPathComponent) and can help you inspect its visible files."
    }
}

struct ChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

struct LocalFileItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let relativePath: String
    let kind: String
    let sizeLabel: String
    let modifiedLabel: String
    let preview: String?
}