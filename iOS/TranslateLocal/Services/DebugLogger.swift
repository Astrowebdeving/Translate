//
//  DebugLogger.swift
//  TranslateLocal
//
//  Centralized logging for debugging screen translation and other features
//

import Foundation
import os.log

/// Centralized debug logger with categories
enum DebugLogger {
    
    // MARK: - Log Categories
    
    enum Category: String {
        case screenTranslation = "ScreenTranslation"
        case pip = "PiP"
        case broadcast = "Broadcast"
        case ocr = "OCR"
        case translation = "Translation"
        case model = "Model"
        case appGroup = "AppGroup"
        case general = "General"
    }
    
    // MARK: - Log Levels
    
    enum Level: String {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case success = "✅"
    }
    
    // MARK: - Configuration
    
    /// Enable/disable logging (set to false for release builds)
    static var isEnabled: Bool = true
    
    /// Store recent logs for in-app viewing
    private static var recentLogs: [LogEntry] = []
    private static let maxLogEntries = 200
    private static let logQueue = DispatchQueue(label: "com.translatelocal.logger")
    
    // MARK: - Log Entry
    
    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let category: Category
        let level: Level
        let message: String
        let file: String
        let function: String
        let line: Int
        
        var formattedTimestamp: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss.SSS"
            return formatter.string(from: timestamp)
        }
        
        var shortFile: String {
            return (file as NSString).lastPathComponent
        }
        
        var formatted: String {
            return "[\(formattedTimestamp)] \(level.rawValue) [\(category.rawValue)] \(message)"
        }
        
        var detailed: String {
            return "[\(formattedTimestamp)] \(level.rawValue) [\(category.rawValue)] \(shortFile):\(line) \(function) - \(message)"
        }
    }
    
    // MARK: - Logging Methods
    
    static func log(
        _ message: String,
        category: Category = .general,
        level: Level = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard isEnabled else { return }
        
        let entry = LogEntry(
            timestamp: Date(),
            category: category,
            level: level,
            message: message,
            file: file,
            function: function,
            line: line
        )
        
        // Print to console
        print(entry.detailed)
        
        // Store for in-app viewing
        logQueue.async {
            recentLogs.append(entry)
            if recentLogs.count > maxLogEntries {
                recentLogs.removeFirst(recentLogs.count - maxLogEntries)
            }
        }
    }
    
    // MARK: - Convenience Methods
    
    static func debug(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .debug, file: file, function: function, line: line)
    }
    
    static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .info, file: file, function: function, line: line)
    }
    
    static func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .warning, file: file, function: function, line: line)
    }
    
    static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .error, file: file, function: function, line: line)
    }
    
    static func success(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, category: category, level: .success, file: file, function: function, line: line)
    }
    
    // MARK: - Screen Translation Specific
    
    static func screenTranslation(_ message: String, level: Level = .info) {
        log(message, category: .screenTranslation, level: level)
    }
    
    static func pip(_ message: String, level: Level = .info) {
        log(message, category: .pip, level: level)
    }
    
    static func broadcast(_ message: String, level: Level = .info) {
        log(message, category: .broadcast, level: level)
    }
    
    // MARK: - Log Retrieval
    
    static func getRecentLogs(count: Int = 50) -> [LogEntry] {
        logQueue.sync {
            return Array(recentLogs.suffix(count))
        }
    }
    
    static func getRecentLogs(category: Category, count: Int = 50) -> [LogEntry] {
        logQueue.sync {
            return Array(recentLogs.filter { $0.category == category }.suffix(count))
        }
    }
    
    static func clearLogs() {
        logQueue.async {
            recentLogs.removeAll()
        }
    }
    
    static func exportLogs() -> String {
        logQueue.sync {
            return recentLogs.map { $0.detailed }.joined(separator: "\n")
        }
    }
}

// MARK: - Shorthand Functions

func debugLog(_ message: String, category: DebugLogger.Category = .general) {
    DebugLogger.debug(message, category: category)
}

func logInfo(_ message: String, category: DebugLogger.Category = .general) {
    DebugLogger.info(message, category: category)
}

func logError(_ message: String, category: DebugLogger.Category = .general) {
    DebugLogger.error(message, category: category)
}
