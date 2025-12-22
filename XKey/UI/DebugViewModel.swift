//
//  DebugViewModel.swift
//  XKey
//
//  ViewModel for Debug Window - Optimized for high-frequency logging
//

import SwiftUI
import Combine

class DebugViewModel: ObservableObject {
    @Published var statusText = "Status: Initializing..."
    @Published var logText = ""
    @Published var isLoggingEnabled = true
    @Published var isVerboseLogging = false {
        didSet {
            verboseLoggingCallback?(isVerboseLogging)
        }
    }
    @Published var inputText = ""
    @Published var isAlwaysOnTop = true {
        didSet {
            alwaysOnTopCallback?(isAlwaysOnTop)
        }
    }
    
    // MARK: - Optimization Properties
    
    /// Background queue for log processing
    private let logQueue = DispatchQueue(label: "com.xkey.debuglog", qos: .utility)
    
    /// Buffer for pending log entries
    private var pendingLogs: [String] = []
    
    /// Lock for thread-safe access to pendingLogs
    private let logLock = NSLock()
    
    /// Timer for batched UI updates
    private var updateTimer: Timer?
    
    /// Update interval in seconds (10 updates per second max)
    private let updateInterval: TimeInterval = 0.1
    
    /// Log entries for efficient storage
    private var logEntries: [String] = []
    
    private let logFileURL: URL
    private var cancellables = Set<AnyCancellable>()
    
    // Callbacks
    var readWordCallback: (() -> Void)?
    var alwaysOnTopCallback: ((Bool) -> Void)?
    var verboseLoggingCallback: ((Bool) -> Void)?
    
    init() {
        // Create log file in user's home directory
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        logFileURL = homeDirectory.appendingPathComponent("XKey_Debug.log")

        // Initialize log file with timestamp
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let header = "=== XKey Debug Log ===\nStarted: \(timestamp)\nLog file: \(logFileURL.path)\n\n"
        try? header.write(to: logFileURL, atomically: true, encoding: .utf8)

        // Start the batched update timer
        startUpdateTimer()
        
        logMessage("Debug window initialized")
        logMessage("Log file location: \(logFileURL.path)")

        // Listen for debug logs from XKeyIM
        setupIMKitDebugListener()
    }
    
    deinit {
        updateTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    // MARK: - Optimized Logging
    
    /// Add a log event (thread-safe, non-blocking)
    func logEvent(_ event: String) {
        guard isLoggingEnabled else { return }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(event)"
        
        // Add to pending buffer (thread-safe)
        logLock.lock()
        pendingLogs.append(logLine)
        logLock.unlock()
        
        // Write to file asynchronously
        logQueue.async { [weak self] in
            self?.writeToFile(logLine + "\n")
        }
    }
    
    /// Start timer for batched UI updates
    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.flushPendingLogs()
        }
    }
    
    /// Flush pending logs to UI (called periodically)
    private func flushPendingLogs() {
        logLock.lock()
        let logsToFlush = pendingLogs
        pendingLogs.removeAll()
        logLock.unlock()
        
        guard !logsToFlush.isEmpty else { return }
        
        // Update UI on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Add new entries (no limit)
            self.logEntries.append(contentsOf: logsToFlush)
            
            // Update the text (single UI update)
            self.logText = self.logEntries.joined(separator: "\n")
        }
    }
    
    /// Write to log file asynchronously
    private func writeToFile(_ text: String) {
        guard let data = text.data(using: .utf8),
              let handle = try? FileHandle(forWritingTo: logFileURL) else { return }
        
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
    }
    
    private func logMessage(_ message: String) {
        guard isLoggingEnabled else { return }
        
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        let logLine = "[\(timestamp)] \(message)\n"
        
        logQueue.async { [weak self] in
            self?.writeToFile(logLine)
        }
    }

    // MARK: - IMKit Debug Listener
    
    private func setupIMKitDebugListener() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("XKey.debugLog"),
            object: nil,
            queue: nil // Use caller's queue, we handle threading ourselves
        ) { [weak self] notification in
            // Try to get message from object first (for InputSourceSwitcher)
            if let message = notification.object as? String {
                self?.logEvent(message)
                return
            }

            // Fallback to userInfo for XKeyIM messages with source
            guard let userInfo = notification.userInfo,
                  let message = userInfo["message"] as? String,
                  let source = userInfo["source"] as? String else {
                return
            }

            self?.logEvent("[\(source)] \(message)")
        }
    }
    
    // MARK: - Public Methods
    
    func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.statusText = "Status: \(status)"
        }
        logMessage("STATUS: \(status)")
    }
    
    func logKeyEvent(character: Character, keyCode: UInt16, result: String) {
        logEvent("KEY: '\(character)' (code: \(keyCode)) → \(result)")
    }
    
    func logEngineResult(input: String, output: String, backspaces: Int) {
        logEvent("ENGINE: '\(input)' → '\(output)' (bs: \(backspaces))")
    }
    
    func copyLogs() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(logText, forType: .string)
        
        updateStatus("Logs copied to clipboard!")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.updateStatus("Ready")
        }
    }
    
    func clearLogs() {
        logLock.lock()
        pendingLogs.removeAll()
        logLock.unlock()
        
        logEntries.removeAll()
        logText = ""
        logMessage("=== Logs Cleared ===")
    }
    
    func toggleLogging() {
        if isLoggingEnabled {
            updateStatus("Logging enabled")
            logMessage("=== Logging Enabled ===")
        } else {
            updateStatus("Logging disabled")
        }
    }
    
    func readWordBeforeCursor() {
        logEvent("=== Read Word Before Cursor ===")
        readWordCallback?()
    }
    
    func openLogFile() {
        // Reveal log file in Finder
        NSWorkspace.shared.activateFileViewerSelecting([logFileURL])
        logMessage("Opened log file in Finder")
    }
}
