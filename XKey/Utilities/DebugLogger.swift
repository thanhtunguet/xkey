//
//  DebugLogger.swift
//  XKey
//
//  Centralized logging utility that sends logs to Debug Window
//

import Foundation

/// Centralized debug logger that sends messages to Debug Window
class DebugLogger {

    /// Shared instance
    static let shared = DebugLogger()

    /// Reference to debug window controller (set by AppDelegate)
    weak var debugWindowController: DebugWindowController?

    private init() {}

    /// Log a message to both console and debug window
    /// - Parameters:
    ///   - message: The message to log
    ///   - source: The source component (e.g., "VNEngine", "MacroManager")
    ///   - level: Log level (info, warning, error)
    func log(_ message: String, source: String = "", level: LogLevel = .info) {
        let prefix = level.emoji
        let fullMessage = source.isEmpty ? "\(prefix) \(message)" : "\(prefix) [\(source)] \(message)"

        // Always print to console for debugging
        // print(fullMessage)

        // Send to debug window if available
        if let debugWindow = debugWindowController, debugWindow.isLoggingEnabled {
            debugWindow.logEvent(fullMessage)
        }
    }

    /// Log an info message
    func info(_ message: String, source: String = "") {
        log(message, source: source, level: .info)
    }

    /// Log a warning message
    func warning(_ message: String, source: String = "") {
        log(message, source: source, level: .warning)
    }

    /// Log an error message
    func error(_ message: String, source: String = "") {
        log(message, source: source, level: .error)
    }

    /// Log a success message
    func success(_ message: String, source: String = "") {
        log(message, source: source, level: .success)
    }

    /// Log a debug message (only if verbose logging is enabled)
    func debug(_ message: String, source: String = "") {
        guard let debugWindow = debugWindowController, debugWindow.isVerboseLogging else {
            return
        }
        log(message, source: source, level: .debug)
    }
}

// MARK: - Log Level

enum LogLevel {
    case info
    case warning
    case error
    case success
    case debug

    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .success: return "✅"
        case .debug: return "🔍"
        }
    }
}

// MARK: - Convenience Global Functions

/// Log an info message to debug window
func logInfo(_ message: String, source: String = "") {
    DebugLogger.shared.info(message, source: source)
}

/// Log a warning message to debug window
func logWarning(_ message: String, source: String = "") {
    DebugLogger.shared.warning(message, source: source)
}

/// Log an error message to debug window
func logError(_ message: String, source: String = "") {
    DebugLogger.shared.error(message, source: source)
}

/// Log a success message to debug window
func logSuccess(_ message: String, source: String = "") {
    DebugLogger.shared.success(message, source: source)
}

/// Log a debug message to debug window (only if verbose logging is enabled)
func logDebug(_ message: String, source: String = "") {
    DebugLogger.shared.debug(message, source: source)
}
