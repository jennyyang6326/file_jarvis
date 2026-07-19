import Foundation

final class BookmarkStore {
    private let key = "file_jarvis.approvedFolderBookmark"

    func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func resolveBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }

        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            return nil
        }

        _ = url.startAccessingSecurityScopedResource()
        return url
    }

    func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

struct FileScanner {
    private let allowedPreviewExtensions = Set(["txt", "md", "markdown", "json", "csv", "swift"])

    func scanFolder(at folderURL: URL) -> [LocalFileItem] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .localizedTypeDescriptionKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }

        var results: [LocalFileItem] = []

        for case let fileURL as URL in enumerator {
            guard results.count < 40 else { break }

            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }

            let modified = values?.contentModificationDate ?? .distantPast
            let size = values?.fileSize ?? 0
            let type = values?.localizedTypeDescription ?? fileURL.pathExtension.uppercased()
            let preview = previewText(for: fileURL, byteLimit: 260)

            let relativePath = fileURL.path.replacingOccurrences(
                of: folderURL.path + "/",
                with: ""
            )

            results.append(
                LocalFileItem(
                    url: fileURL,
                    name: fileURL.lastPathComponent,
                    relativePath: relativePath,
                    kind: type.isEmpty ? "File" : type,
                    sizeLabel: ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file),
                    modifiedLabel: modified.formatted(date: .abbreviated, time: .shortened),
                    preview: preview
                )
            )
        }

        return results.sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
    }

    private func previewText(for url: URL, byteLimit: Int) -> String? {
        guard allowedPreviewExtensions.contains(url.pathExtension.lowercased()) else {
            return nil
        }

        guard
            let data = try? Data(contentsOf: url),
            data.count <= 16_000,
            let text = String(data: data.prefix(byteLimit), encoding: .utf8)?
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        else {
            return nil
        }

        return text
    }
}