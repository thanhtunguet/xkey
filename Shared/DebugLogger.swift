//
//  DebugLogger.swift
//  XKey / XKeyIM
//
//  Centralized logging utility that works in both XKey and XKeyIM
//  Optimized for high-frequency logging without blocking the caller
//

import Foundation

// Forward declaration for DebugWindowController (only available in XKey)
// This protocol allows us to reference the debug window without importing AppKit
protocol DebugWindowControllerProtocol: AnyObject {
    var isLoggingEnabled: Bool { get }
    var isVerboseLogging: Bool { get }
    func logEvent(_ message: String)
}

/// Centralized debug logger that works in both XKey and XKeyIM
/// Optimized for high-frequency logging without blocking
class DebugLogger {

    /// Shared instance
    static let shared = DebugLogger()

    /// Reference to debug window controller (set by AppDelegate in XKey)
    /// Using protocol to avoid dependency on AppKit/UI code
    weak var debugWindowController: DebugWindowControllerProtocol? {
        didSet {
            // When debug window is connected, use it for logging settings
            if let controller = debugWindowController {
                isLoggingEnabled = controller.isLoggingEnabled
                isVerboseLogging = controller.isVerboseLogging
            }
        }
    }
    
    /// Whether verbose logging is enabled
    var isVerboseLogging: Bool = false
    
    /// Whether logging is enabled
    var isLoggingEnabled: Bool = true
    
    /// Background queue for async logging (XKeyIM only)
    private let logQueue = DispatchQueue(label: "com.xkey.logger", qos: .utility)

    private init() {}

    /// Log a message (non-blocking)
    /// - Parameters:
    ///   - message: The message to log
    ///   - source: The source component (e.g., "VNEngine", "MacroManager")
    ///   - level: Log level (info, warning, error)
    func log(_ message: String, source: String = "", level: LogLevel = .info) {
        let prefix = level.emoji
        let fullMessage = source.isEmpty ? "\(prefix) \(message)" : "\(prefix) [\(source)] \(message)"

        // Send to debug window if available (XKey)
        // DebugViewModel handles its own threading/batching
        if let debugWindow = debugWindowController, debugWindow.isLoggingEnabled {
            debugWindow.logEvent(fullMessage)
            return
        }
        
        // For XKeyIM or when no debug window: use NSLog asynchronously
        guard isLoggingEnabled else { return }
        
        // Check level before async dispatch to avoid unnecessary work
        switch level {
        case .error, .warning:
            logQueue.async {
                NSLog("%@", fullMessage)
            }
        case .info, .success:
            #if DEBUG
            logQueue.async {
                NSLog("%@", fullMessage)
            }
            #endif
        case .debug:
            #if DEBUG
            if isVerboseLogging {
                logQueue.async {
                    NSLog("%@", fullMessage)
                }
            }
            #endif
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
        let verbose = debugWindowController?.isVerboseLogging ?? isVerboseLogging
        guard verbose else { return }
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
@inline(__always)
func logInfo(_ message: String, source: String = "") {
    DebugLogger.shared.info(message, source: source)
}

/// Log a warning message to debug window
@inline(__always)
func logWarning(_ message: String, source: String = "") {
    DebugLogger.shared.warning(message, source: source)
}

/// Log an error message to debug window
@inline(__always)
func logError(_ message: String, source: String = "") {
    DebugLogger.shared.error(message, source: source)
}

/// Log a success message to debug window
@inline(__always)
func logSuccess(_ message: String, source: String = "") {
    DebugLogger.shared.success(message, source: source)
}

/// Log a debug message to debug window (only if verbose logging is enabled)
@inline(__always)
func logDebug(_ message: String, source: String = "") {
    DebugLogger.shared.debug(message, source: source)
}

// MARK: - Aliases for SharedSettings compatibility

/// Alias for logInfo (used by SharedSettings)
@inline(__always)
func sharedLogInfo(_ message: String, source: String = "") {
    logInfo(message, source: source)
}

/// Alias for logWarning (used by SharedSettings)
@inline(__always)
func sharedLogWarning(_ message: String, source: String = "") {
    logWarning(message, source: source)
}

/// Alias for logError (used by SharedSettings)
@inline(__always)
func sharedLogError(_ message: String, source: String = "") {
    logError(message, source: source)
}

/// Alias for logSuccess (used by SharedSettings)
@inline(__always)
func sharedLogSuccess(_ message: String, source: String = "") {
    logSuccess(message, source: source)
}

/// Alias for logDebug (used by SharedSettings)
@inline(__always)
func sharedLogDebug(_ message: String, source: String = "") {
    logDebug(message, source: source)
}
