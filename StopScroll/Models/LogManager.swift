import Foundation
import os

/// Centralized logging system that writes to both console and local file.
/// Access logs via ConsoleView or by reading the log file from Documents.
class LogManager: ObservableObject {
    static let shared = LogManager()

    @Published var logs: [LogEntry] = []
    
    private let maxLogs = 500  // Keep last 500 entries
    private let fileManager = FileManager.default
    private let logFileName = "stopscroll_debug.log"
    
    private var logsFileURL: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent(logFileName)
    }

    private init() {
        loadLogsFromFile()
    }

    func log(
        _ message: String,
        category: String = "General",
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let entry = LogEntry(
            timestamp: timestamp,
            level: level,
            category: category,
            message: message,
            source: "\(fileName):\(function):\(line)"
        )

        DispatchQueue.main.async {
            self.logs.append(entry)
            if self.logs.count > self.maxLogs {
                self.logs.removeFirst()
            }
        }

        writeToFile(entry)
        
        // Also print to console for Xcode
        let levelEmoji = level.emoji
        print("[\(timestamp)] [\(levelEmoji) \(level.rawValue)] [\(category)] \(message) (\(fileName):\(function):\(line))")
    }

    private func writeToFile(_ entry: LogEntry) {
        let line = "[\(entry.timestamp)] [\(entry.level.rawValue)] [\(entry.category)] \(entry.message) (\(entry.source))\n"
        
        if let data = line.data(using: .utf8) {
            if fileManager.fileExists(atPath: logsFileURL.path) {
                if let fileHandle = FileHandle(forWritingAtPath: logsFileURL.path) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logsFileURL)
            }
        }
    }

    private func loadLogsFromFile() {
        guard fileManager.fileExists(atPath: logsFileURL.path),
              let content = try? String(contentsOf: logsFileURL, encoding: .utf8) else {
            return
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        logs = lines.compactMap { LogEntry(from: String($0)) }
    }

    func clearLogs() {
        logs.removeAll()
        try? fileManager.removeItem(at: logsFileURL)
    }

    func exportLogs() -> String {
        logs.map { $0.description }.joined(separator: "\n")
    }
}

struct LogEntry {
    let timestamp: String
    let level: LogLevel
    let category: String
    let message: String
    let source: String

    var description: String {
        "[\(timestamp)] [\(level.rawValue)] [\(category)] \(message) (\(source))"
    }

    init(timestamp: String, level: LogLevel, category: String, message: String, source: String) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.source = source
    }

    init?(from line: String) {
        // Parse: [2026-04-19T...] [INFO] [Category] Message (file:func:line)
        let pattern = #"\[([^\]]+)\]\s+\[([^\]]+)\]\s+\[([^\]]+)\]\s+([^\(]+)\s+\(([^\)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsLine = line as NSString
        guard let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsLine.length)) else {
            return nil
        }

        guard match.numberOfRanges == 6 else { return nil }

        timestamp = nsLine.substring(with: match.range(at: 1))
        let levelStr = nsLine.substring(with: match.range(at: 2))
        category = nsLine.substring(with: match.range(at: 3))
        message = nsLine.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespaces)
        source = nsLine.substring(with: match.range(at: 5))

        guard let parsedLevel = LogLevel(rawValue: levelStr) else { return nil }
        level = parsedLevel
    }
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔴"
        }
    }
}
