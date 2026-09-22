import Darwin
import Foundation

enum AppEnvironment {
    static func loadOpenAIKeyIfNeeded() {
        guard ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.isEmpty != false else {
            return
        }

        for fileURL in candidateEnvironmentFiles() {
            guard let contents = try? String(contentsOf: fileURL, encoding: .utf8) else {
                continue
            }

            if let key = value(named: "OPENAI_API_KEY", in: contents), !key.isEmpty {
                setenv("OPENAI_API_KEY", key, 0)
                return
            }
        }
    }

    private static func candidateEnvironmentFiles() -> [URL] {
        let workingDirectory = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        return [
            workingDirectory.appendingPathComponent(".env.local"),
            repositoryRoot.appendingPathComponent(".env.local")
        ]
    }

    private static func value(named name: String, in contents: String) -> String? {
        for rawLine in contents.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            let prefix = "\(name)="
            guard line.hasPrefix(prefix) else { continue }

            var value = String(line.dropFirst(prefix.count))
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if value.count >= 2,
               (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value.removeFirst()
                value.removeLast()
            }

            return value
        }

        return nil
    }
}
