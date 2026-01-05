//
//  OverlayAppDetector.swift
//  XKey
//
//  Detects overlay apps (Spotlight, Raycast, Alfred) that don't trigger
//  standard workspace notifications and appear over the current app.
//
//  This helps Smart Switch avoid overwriting the underlying app's language
//  preference when user toggles language while an overlay is active.
//

import Cocoa
import ApplicationServices
import ObjectiveC

/// Detects overlay/panel apps that appear over the current application
class OverlayAppDetector {

    // MARK: - Singleton

    static let shared = OverlayAppDetector()

    // MARK: - State Tracking

    /// Callback when overlay visibility changes
    var onOverlayVisibilityChanged: ((Bool) -> Void)?

    /// Previous overlay visibility state (for change detection)
    private var wasOverlayVisible = false

    /// Timer for monitoring overlay state changes
    private var monitorTimer: Timer?

    private init() {
        // Start monitoring overlay state changes
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Known Overlay Apps

    /// List of known overlay apps that should be detected
    /// These apps typically appear over the current window without becoming
    /// the frontmost application in NSWorkspace
    private static let overlayAppOwnerNames: Set<String> = [
        "Spotlight",      // macOS Spotlight search (Cmd+Space)
        "Raycast",        // Raycast launcher
        "Alfred",         // Alfred launcher
        // Note: Add more overlay apps here if needed
    ]

    // MARK: - Detection Methods

    /// Check if any overlay app is currently visible on screen
    /// - Returns: True if an overlay app window is detected
    func isOverlayAppVisible() -> Bool {
        // Get all on-screen windows
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            logDebug("Failed to get window list")
            return false
        }

        logDebug("Checking \(windows.count) windows for overlay apps")

        // Collect all unique owner names for debugging
        let allOwners = Set(windows.compactMap { $0[kCGWindowOwnerName as String] as? String })
        logDebug("Window owners: \(allOwners.sorted().prefix(10).joined(separator: ", "))")

        // Check if any window belongs to a known overlay app
        for window in windows {
            if let owner = window[kCGWindowOwnerName as String] as? String {
                // Check against known overlay apps
                if Self.overlayAppOwnerNames.contains(owner) {
                    // Verify it's a visible window (has non-zero bounds)
                    if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                       let width = bounds["Width"],
                       let height = bounds["Height"],
                       width > 0 && height > 0 {
                        logDebug("FOUND overlay app: '\(owner)' (size: \(Int(width))×\(Int(height)))")
                        return true
                    }
                }
            }
        }

        logDebug("No overlay app detected")
        return false
    }

    /// Log debug message
    private func logDebug(_ message: String) {
        // Log to Debug Window
        DebugLogger.shared.info(message, source: "OverlayDetector")
    }

    /// Get the name of the currently visible overlay app, if any
    /// - Returns: Owner name of the overlay app (e.g., "Spotlight"), or nil if none visible
    func getVisibleOverlayAppName() -> String? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windows {
            if let owner = window[kCGWindowOwnerName as String] as? String,
               Self.overlayAppOwnerNames.contains(owner) {
                if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                   let width = bounds["Width"],
                   let height = bounds["Height"],
                   width > 0 && height > 0 {
                    return owner
                }
            }
        }

        return nil
    }

    // MARK: - Monitoring

    /// Start monitoring overlay state changes
    private func startMonitoring() {
        // Check every 0.5 seconds for overlay state changes
        monitorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkOverlayStateChange()
        }
    }

    /// Stop monitoring overlay state changes
    private func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    /// Check if overlay state has changed and notify callback
    private func checkOverlayStateChange() {
        let isCurrentlyVisible = isOverlayVisibleQuiet()

        // Detect state change
        if isCurrentlyVisible != wasOverlayVisible {
            logDebug("Overlay visibility changed: \(wasOverlayVisible ? "visible" : "hidden") → \(isCurrentlyVisible ? "visible" : "hidden")")
            wasOverlayVisible = isCurrentlyVisible

            // Notify callback
            onOverlayVisibilityChanged?(isCurrentlyVisible)
        }
    }

    /// Check overlay visibility without logging (for polling)
    private func isOverlayVisibleQuiet() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for window in windows {
            if let owner = window[kCGWindowOwnerName as String] as? String {
                if Self.overlayAppOwnerNames.contains(owner) {
                    if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                       let width = bounds["Width"],
                       let height = bounds["Height"],
                       width > 0 && height > 0 {
                        return true
                    }
                }
            }
        }

        return false
    }

    // MARK: - Notes on Permissions

    // ℹ️ Screen Recording permission is NOT required for this feature!
    //
    // We only read kCGWindowOwnerName (application name like "Spotlight", "Raycast")
    // which is available WITHOUT Screen Recording permission on all macOS versions.
    //
    // Screen Recording permission is only needed for:
    // - kCGWindowName (window title)
    // - kCGWindowSharingState
    //
    // References:
    // - https://developer.apple.com/forums/thread/126860
    // - https://www.ryanthomson.net/articles/screen-recording-permissions-catalina-mess/
}
