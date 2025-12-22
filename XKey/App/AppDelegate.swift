//
//  AppDelegate.swift
//  XKey
//
//  Application delegate managing lifecycle and coordination
//

import Cocoa
import SwiftUI
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Shared Instance
    
    /// Shared instance for access from SwiftUI views
    static var shared: AppDelegate?
    
    // MARK: - Properties

    private var statusBarManager: StatusBarManager?
    private var eventTapManager: EventTapManager?
    private var keyboardHandler: KeyboardEventHandler?
    private var debugWindowController: DebugWindowController?
    @available(macOS 13.0, *)
    private var settingsWindowController: SettingsWindowController? {
        get { _settingsWindowController as? SettingsWindowController }
        set { _settingsWindowController = newValue }
    }
    private var _settingsWindowController: NSWindowController?
    private var preferencesWindowController: PreferencesWindowController?
    private var readWordHotKeyMonitor: Any?
    private var readWordGlobalHotKeyMonitor: Any?
    private var appSwitchObserver: NSObjectProtocol?
    private var mouseClickMonitor: Any?
    private var permissionAlertShown = false
    private var permissionCheckTimer: Timer?
    private var inputSourceManager: InputSourceManager?
    private var switchXKeyHotkeyMonitor: Any?
    private var switchXKeyGlobalHotkeyMonitor: Any?
    private var updaterController: SPUStandardUpdaterController?

    // MARK: - Initialization

    override init() {
        super.init()
    }
    
    // MARK: - Public Accessors

    /// Get the keyboard handler for external access
    func getKeyboardHandler() -> KeyboardEventHandler? {
        return keyboardHandler
    }

    /// Get the macro manager for external access
    func getMacroManager() -> MacroManager? {
        if keyboardHandler == nil {
            logToDebugWindow("⚠️ AppDelegate.getMacroManager: keyboardHandler is nil!")
            return nil
        }
        return keyboardHandler?.getMacroManager()
    }

    /// Log message to debug window (for external access)
    func logToDebugWindow(_ message: String) {
        debugWindowController?.logEvent(message)
    }

    /// Get the Sparkle updater for external access
    func getSparkleUpdater() -> SPUUpdater? {
        return updaterController?.updater
    }

    // MARK: - Application Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set shared instance for access from SwiftUI views
        AppDelegate.shared = self
        
        // Create debug window first
        setupDebugWindow()
        
        debugWindowController?.logEvent("🚀 XKey starting...")

        // Load and apply preferences
        let preferences = SharedSettings.shared.loadPreferences()
        
        // Load custom Window Title Rules
        AppBehaviorDetector.shared.loadCustomRules()
        debugWindowController?.logEvent("  ✅ Loaded \(AppBehaviorDetector.shared.getCustomRules().count) custom Window Title Rules")
        
        // Initialize components
        setupKeyboardHandling()
        setupStatusBar()
        
        // Apply loaded preferences
        applyPreferences(preferences)

        // Check permissions
        checkAndRequestPermissions()

        // Setup global hotkey
        setupGlobalHotkey()
        
        // Setup read word hotkey
        setupReadWordHotkey()

        // Setup app switch observer
        setupAppSwitchObserver()
        
        // Setup mouse click monitor
        setupMouseClickMonitor()

        // Setup input source manager
        setupInputSourceManager()

        // Setup Sparkle auto-update
        setupSparkleUpdater()

        debugWindowController?.updateStatus("XKey started successfully")
        debugWindowController?.logEvent("✅ XKey started successfully")
    }

    func applicationWillTerminate(_ notification: Notification) {
        debugWindowController?.logEvent("👋 XKey terminating...")
        eventTapManager?.stop()

        // Remove read word hotkey monitors
        if let monitor = readWordHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = readWordGlobalHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Remove switch XKey hotkey monitors
        if let monitor = switchXKeyHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = switchXKeyGlobalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }

        // Remove app switch observer
        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        
        // Stop permission check timer
        permissionCheckTimer?.invalidate()
        permissionCheckTimer = nil
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    // MARK: - URL Scheme Handler
    
    /// Handle URL scheme: xkey://settings opens preferences
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "xkey" else { continue }
            
            switch url.host {
            case "settings", "preferences":
                // Open settings window
                debugWindowController?.logEvent("📲 Received URL: \(url.absoluteString) - opening settings")
                openPreferences()
            default:
                // Just activate the app
                debugWindowController?.logEvent("📲 Received URL: \(url.absoluteString)")
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // MARK: - Setup

    private func setupDebugWindow() {
        // Check if debug mode is enabled in preferences
        let preferences = SharedSettings.shared.loadPreferences()
        let shouldShowDebug = preferences.debugModeEnabled

        // Show debug window only if enabled in settings
        if shouldShowDebug {
            debugWindowController = DebugWindowController()
            debugWindowController?.showWindow(nil)
            debugWindowController?.logEvent("✅ Debug window created (enabled in settings)")

            // Connect DebugLogger to debug window
            DebugLogger.shared.debugWindowController = debugWindowController

            // Setup read word callback
            debugWindowController?.setupReadWordCallback { [weak self] in
                self?.keyboardHandler?.engine.debugReadWordBeforeCursor()
            }
            
            // Setup verbose logging callback - sync with keyboardHandler
            debugWindowController?.setupVerboseLoggingCallback { [weak self] isVerbose in
                self?.keyboardHandler?.verboseEngineLogging = isVerbose
                self?.debugWindowController?.logEvent(isVerbose ? "🔍 Verbose engine logging ENABLED (may cause lag)" : "🔍 Verbose engine logging DISABLED")
            }
        }
    }

    private func setupKeyboardHandling() {
        debugWindowController?.logEvent("🔧 Setting up keyboard handling...")

        // Create keyboard handler
        keyboardHandler = KeyboardEventHandler()
        debugWindowController?.logEvent("  ✅ Keyboard handler created")
        
        // Connect debug logging (only if logging is enabled)
        // Filter to reduce log spam
        keyboardHandler?.debugLogCallback = { [weak self] message in
            guard let self = self,
                  let debugWindow = self.debugWindowController,
                  debugWindow.isLoggingEnabled else { return }
            
            // Filter out verbose messages to reduce lag (unless verbose mode)
            if debugWindow.isVerboseLogging {
                debugWindow.logEvent(message)
            } else {
                // Always log important messages
                let shouldLog = message.contains("KEY:") ||
                               message.contains("CONSUME") ||
                               message.contains("Inject:") ||
                               message.contains("BACKSPACE") ||
                               message.contains("WORD BREAK") ||
                               message.contains("CURSOR MOVEMENT") ||
                               message.contains("===") ||
                               message.contains("DEBUG:") ||  // Read Word logs
                               message.contains("Text:") ||
                               message.contains("Word:") ||
                               message.contains("Valid:") ||
                               message.contains("Chrome") ||  // Chrome fix logs
                               message.contains("[AX]")  // Accessibility logs
                
                if shouldLog {
                    debugWindow.logEvent(message)
                }
            }
        }

        // Create event tap manager
        eventTapManager = EventTapManager()
        eventTapManager?.delegate = keyboardHandler
        debugWindowController?.logEvent("  ✅ Event tap manager created, delegate set")
        
        // Connect debug logging (only if logging is enabled)
        // EventTap logs are very verbose, skip most of them
        eventTapManager?.debugLogCallback = { [weak self] message in
            guard let self = self,
                  let debugWindow = self.debugWindowController,
                  debugWindow.isLoggingEnabled else { return }
            
            // Log important EventTap messages (setup, errors, status changes)
            let shouldLog = message.contains("No delegate") ||
                           message.contains("disabled") ||
                           message.contains("🚀") ||  // Start
                           message.contains("✅") ||  // Success
                           message.contains("❌") ||  // Error
                           message.contains("⏹️")    // Stop
            
            if shouldLog {
                debugWindow.logEvent(message)
            }
        }

        // Check permission BEFORE trying to start event tap
        // This prevents macOS system dialog from appearing
        guard let manager = eventTapManager else { return }

        // Check if current input source is XKeyIM
        // If so, don't start event tap yet (will be started when switching away)
        if let currentSource = InputSourceManager.getCurrentInputSource(),
           InputSourceManager.isXKeyInputSource(currentSource) {
            debugWindowController?.logEvent("  ⏸️ Current input source is XKeyIM - event tap will NOT start")
            debugWindowController?.logEvent("     Event tap will start automatically when switching away from XKeyIM")
            return
        }

        if manager.checkAccessibilityPermission() {
            // Permission already granted, start event tap
            do {
                try manager.start()
                debugWindowController?.updateStatus("Event tap started - Ready to type!")
                debugWindowController?.logEvent("  ✅ Event tap started successfully!")
            } catch {
                debugWindowController?.updateStatus("ERROR: Failed to start event tap")
                debugWindowController?.logEvent("  ❌ Failed to start event tap: \(error)")
            }
        } else {
            // No permission yet - don't call start() to avoid system dialog
            debugWindowController?.updateStatus("Waiting for accessibility permission...")
            debugWindowController?.logEvent("  ⚠️ Accessibility permission not granted yet")
        }
    }
    
    private func setupStatusBar() {
        statusBarManager = StatusBarManager(
            keyboardHandler: keyboardHandler,
            eventTapManager: eventTapManager
        )
        statusBarManager?.viewModel.onOpenPreferences = { [weak self] in
            self?.openPreferences()
        }
        statusBarManager?.viewModel.onOpenMacroManagement = { [weak self] in
            self?.openMacroManagement()
        }
        statusBarManager?.viewModel.onOpenConvertTool = { [weak self] in
            self?.openConvertTool()
        }
        statusBarManager?.onCheckForUpdates = { [weak self] in
            self?.checkForUpdates()
        }
        statusBarManager?.setupStatusBar()
    }
    
    // MARK: - Preferences
    
    func openPreferences() {
        if #available(macOS 13.0, *) {
            openSettings()
        } else {
            openLegacyPreferences()
        }
    }
    
    @available(macOS 13.0, *)
    func openSettings(selectedSection: SettingsSection = .general) {
        // Close existing window if section is different
        if let existingController = settingsWindowController {
            existingController.close()
            settingsWindowController = nil
        }
        
        settingsWindowController = SettingsWindowController(selectedSection: selectedSection) { [weak self] preferences in
            self?.applyPreferences(preferences)
        }
        
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openLegacyPreferences(selectedTab: Int = 0) {
        // Close existing window if tab is different
        if let existingController = preferencesWindowController {
            existingController.close()
            preferencesWindowController = nil
        }
        
        preferencesWindowController = PreferencesWindowController(selectedTab: selectedTab) { [weak self] preferences in
            self?.applyPreferences(preferences)
        }
        
        preferencesWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openMacroManagement() {
        if #available(macOS 13.0, *) {
            openSettings(selectedSection: .macro)
        } else {
            openLegacyPreferences(selectedTab: 2) // Tab 2 = Nâng cao (has Macro section)
        }
    }
    
    func openConvertTool() {
        if #available(macOS 13.0, *) {
            openSettings(selectedSection: .convertTool)
        } else {
            openLegacyPreferences(selectedTab: 2) // Tab 2 = Nâng cao
        }
    }
    
    private func applyPreferences(_ preferences: Preferences) {
        // Apply basic settings
        keyboardHandler?.inputMethod = preferences.inputMethod
        keyboardHandler?.codeTable = preferences.codeTable
        keyboardHandler?.modernStyle = preferences.modernStyle
        keyboardHandler?.spellCheckEnabled = preferences.spellCheckEnabled
        keyboardHandler?.englishDetectionEnabled = preferences.englishDetectionEnabled
        keyboardHandler?.fixAutocomplete = preferences.fixAutocomplete
        
        // Apply advanced features
        keyboardHandler?.quickTelexEnabled = preferences.quickTelexEnabled
        keyboardHandler?.quickStartConsonantEnabled = preferences.quickStartConsonantEnabled
        keyboardHandler?.quickEndConsonantEnabled = preferences.quickEndConsonantEnabled
        keyboardHandler?.upperCaseFirstChar = preferences.upperCaseFirstChar
        keyboardHandler?.restoreIfWrongSpelling = preferences.restoreIfWrongSpelling
        keyboardHandler?.allowConsonantZFWJ = preferences.allowConsonantZFWJ
        keyboardHandler?.freeMarkEnabled = preferences.freeMarkEnabled
        keyboardHandler?.tempOffSpellingEnabled = preferences.tempOffSpellingEnabled
        keyboardHandler?.tempOffEngineEnabled = preferences.tempOffEngineEnabled
        
        // Apply macro settings
        keyboardHandler?.macroEnabled = preferences.macroEnabled
        keyboardHandler?.macroInEnglishMode = preferences.macroInEnglishMode
        keyboardHandler?.autoCapsMacro = preferences.autoCapsMacro
        
        // Apply smart switch
        keyboardHandler?.smartSwitchEnabled = preferences.smartSwitchEnabled
        
        // Apply excluded apps
        keyboardHandler?.excludedApps = preferences.excludedApps
        
        // Apply debug mode (toggle debug window)
        toggleDebugWindow(enabled: preferences.debugModeEnabled)
        
        // Update status bar manager
        statusBarManager?.viewModel.currentInputMethod = preferences.inputMethod
        statusBarManager?.viewModel.currentCodeTable = preferences.codeTable
        
        // Update hotkey display in menu
        statusBarManager?.updateHotkeyDisplay(preferences.toggleHotkey)
        
        // Update menu bar icon style
        statusBarManager?.updateMenuBarIconStyle(preferences.menuBarIconStyle)
        
        // Update Dock icon visibility
        updateDockIconVisibility(show: preferences.showDockIcon)
        
        // Update hotkey
        setupGlobalHotkey(with: preferences.toggleHotkey)
        
        // Update switch XKey hotkey
        setupSwitchXKeyHotkey(with: preferences.switchToXKeyHotkey)
        
        // Update undo typing (Esc key)
        keyboardHandler?.undoTypingEnabled = preferences.undoTypingEnabled
        debugWindowController?.logEvent(preferences.undoTypingEnabled ? "  ✅ Undo typing enabled (Esc key)" : "  ⏹️ Undo typing disabled")

        debugWindowController?.logEvent("✅ Preferences applied (including advanced features)")
    }
    
    // MARK: - Debug Window Management
    
    private func toggleDebugWindow(enabled: Bool) {
        // Respect the debug mode setting
        if enabled {
            // Enable debug window
            if debugWindowController == nil {
                debugWindowController = DebugWindowController()
                debugWindowController?.setupReadWordCallback { [weak self] in
                    self?.keyboardHandler?.engine.debugReadWordBeforeCursor()
                }
                // Setup verbose logging callback - sync with keyboardHandler
                debugWindowController?.setupVerboseLoggingCallback { [weak self] isVerbose in
                    self?.keyboardHandler?.verboseEngineLogging = isVerbose
                    self?.debugWindowController?.logEvent(isVerbose ? "🔍 Verbose engine logging ENABLED (may cause lag)" : "🔍 Verbose engine logging DISABLED")
                }
                debugWindowController?.logEvent("✅ Debug window enabled via settings")
            }
            debugWindowController?.showWindow(nil)
        } else {
            // Disable debug window - also disable verbose logging
            keyboardHandler?.verboseEngineLogging = false
            if let window = debugWindowController?.window {
                window.close()
                debugWindowController = nil
            }
        }
    }
    
    // MARK: - Permissions
    
    private func checkAndRequestPermissions() {
        guard let manager = eventTapManager else { return }
        
        if !manager.checkAccessibilityPermission() {
            showPermissionAlert()
            // Start monitoring for permission changes
            startPermissionMonitoring()
        }
    }
    
    private func showPermissionAlert() {
        // Only show alert once
        guard !permissionAlertShown else { return }
        permissionAlertShown = true
        
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        XKey needs accessibility permission to function as a Vietnamese input method.
        
        Please grant permission in System Settings > Privacy & Security > Accessibility.
        
        After granting permission, XKey will automatically start working.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
            // Don't show alert again after opening settings
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func openAccessibilityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        
        debugWindowController?.logEvent("🔓 Opening System Settings for Accessibility permission")
    }
    
    private func startPermissionMonitoring() {
        // Check permission every 2 seconds
        permissionCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            guard let self = self,
                  let manager = self.eventTapManager else { return }
            
            if manager.checkAccessibilityPermission() {
                // Permission granted! Try to start event tap
                self.debugWindowController?.logEvent("✅ Accessibility permission granted!")
                
                do {
                    try manager.start()
                    self.debugWindowController?.updateStatus("Event tap started - Ready to type!")
                    self.debugWindowController?.logEvent("✅ Event tap started successfully after permission grant")
                    
                    // Stop monitoring
                    self.permissionCheckTimer?.invalidate()
                    self.permissionCheckTimer = nil
                    
                } catch {
                    self.debugWindowController?.logEvent("❌ Failed to start event tap: \(error)")
                }
            }
        }
        
        debugWindowController?.logEvent("👀 Started monitoring for permission changes")
    }

    private func setupGlobalHotkey() {
        let preferences = SharedSettings.shared.loadPreferences()
        setupGlobalHotkey(with: preferences.toggleHotkey)
    }
    
    private func setupGlobalHotkey(with hotkey: Hotkey) {
        // Configure EventTapManager to handle toggle hotkey
        // This ensures the hotkey is consumed at the lowest level
        // and doesn't reach other applications
        eventTapManager?.toggleHotkey = hotkey
        eventTapManager?.onToggleHotkey = { [weak self] in
            self?.statusBarManager?.viewModel.toggleVietnamese()
            
            self?.debugWindowController?.logEvent("🔄 Toggled Vietnamese mode via hotkey (\(hotkey.displayString))")
        }

        debugWindowController?.logEvent("  ✅ Toggle hotkey configured in EventTap: \(hotkey.displayString)")
    }
    
    private func setupReadWordHotkey() {
        // Remove existing monitors
        if let monitor = readWordHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = readWordGlobalHotKeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        // Shortcut: Cmd+Shift+R for "Read Word Before Cursor" (changed from Z to avoid Redo conflict)
        let keyCode: UInt16 = 0x0F // R key
        
        // Helper to check modifiers (only Cmd+Shift, no other modifiers)
        let checkModifiers: (NSEvent) -> Bool = { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            return flags.contains(.command) && flags.contains(.shift) && 
                   !flags.contains(.option) && !flags.contains(.control)
        }
        
        // Global monitor - catches hotkey in ALL apps
        readWordGlobalHotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && checkModifiers(event) {
                DispatchQueue.main.async {
                    self?.keyboardHandler?.engine.debugReadWordBeforeCursor()
                    
                    self?.debugWindowController?.logEvent("⌨️ Read Word triggered via hotkey (Cmd+Shift+R)")
                }
            }
        }
        
        // Local monitor - catches hotkey when XKey app is focused
        readWordHotKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && checkModifiers(event) {
                DispatchQueue.main.async {
                    self?.keyboardHandler?.engine.debugReadWordBeforeCursor()
                    
                    self?.debugWindowController?.logEvent("⌨️ Read Word triggered via hotkey (Cmd+Shift+R)")
                }
                // Return nil to consume the event
                return nil
            }
            return event
        }
        
        debugWindowController?.logEvent("  ✅ Read Word hotkey: Cmd+Shift+R")
    }
    
    private func setupSwitchXKeyHotkey(with hotkey: Hotkey?) {
        // Remove existing monitors
        if let monitor = switchXKeyHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            switchXKeyHotkeyMonitor = nil
        }
        if let monitor = switchXKeyGlobalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
            switchXKeyGlobalHotkeyMonitor = nil
        }
        
        guard let hotkey = hotkey else {
            debugWindowController?.logEvent("  ⏹️ Switch XKey hotkey disabled")
            return
        }
        
        let keyCode = hotkey.keyCode
        
        // Helper to check modifiers match exactly
        let checkModifiers: (NSEvent) -> Bool = { event in
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            var requiredFlags: NSEvent.ModifierFlags = []
            
            if hotkey.modifiers.contains(.command) { requiredFlags.insert(.command) }
            if hotkey.modifiers.contains(.control) { requiredFlags.insert(.control) }
            if hotkey.modifiers.contains(.option) { requiredFlags.insert(.option) }
            if hotkey.modifiers.contains(.shift) { requiredFlags.insert(.shift) }
            
            // Check if flags match exactly (only required modifiers, no extras)
            let significantFlags = NSEvent.ModifierFlags([.command, .control, .option, .shift])
            let actualFlags = flags.intersection(significantFlags)
            return actualFlags == requiredFlags
        }
        
        // Global monitor - catches hotkey in ALL apps
        switchXKeyGlobalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && checkModifiers(event) {
                DispatchQueue.main.async {
                    // Check state BEFORE toggle
                    let wasXKey = InputSourceSwitcher.shared.isXKeyActive
                    let action = wasXKey ? "XKey → ABC" : "ABC → XKey"

                    // Perform toggle
                    let success = InputSourceSwitcher.shared.toggleXKey()
                    self?.debugWindowController?.logEvent("🔄 Toggle input source via hotkey (\(hotkey.displayString)) [\(action)]: \(success ? "success" : "failed")")
                }
            }
        }

        // Local monitor - catches hotkey when XKey app is focused
        switchXKeyHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == keyCode && checkModifiers(event) {
                DispatchQueue.main.async {
                    // Check state BEFORE toggle
                    let wasXKey = InputSourceSwitcher.shared.isXKeyActive
                    let action = wasXKey ? "XKey → ABC" : "ABC → XKey"

                    // Perform toggle
                    let success = InputSourceSwitcher.shared.toggleXKey()
                    self?.debugWindowController?.logEvent("🔄 Toggle input source via hotkey (\(hotkey.displayString)) [\(action)]: \(success ? "success" : "failed")")
                }
                // Return nil to consume the event
                return nil
            }
            return event
        }
        
        debugWindowController?.logEvent("  ✅ Switch XKey hotkey: \(hotkey.displayString)")
    }

    private func setupAppSwitchObserver() {
        // Listen for app activation changes to reset engine buffer
        // This prevents buffer from previous app affecting typing in new app
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            // Reset keyboard handler engine when switching apps
            // Use resetForAppSwitch() which assumes typing mid-sentence to prevent
            // Forward Delete from deleting text on the right of cursor
            self.keyboardHandler?.resetForAppSwitch()

            // Handle Smart Switch - auto switch language per app
            self.handleSmartSwitch(notification: notification)

            self.debugWindowController?.logEvent("🔄 App switched - engine reset, mid-sentence mode")
        }

        debugWindowController?.logEvent("  ✅ App switch observer registered")

        // Setup overlay detector callback to restore language when overlay closes
        setupOverlayDetectorCallback()
    }

    /// Setup callback for overlay visibility changes
    private func setupOverlayDetectorCallback() {
        OverlayAppDetector.shared.onOverlayVisibilityChanged = { [weak self] isVisible in
            guard let self = self else { return }

            // When overlay closes (visible → hidden), restore language for current app
            if !isVisible {
                self.debugWindowController?.logEvent("🔄 Overlay closed - restoring language for current app")
                self.restoreLanguageForCurrentApp()
            }
        }
    }

    /// Restore language for the current frontmost app from Smart Switch
    private func restoreLanguageForCurrentApp() {
        guard let handler = keyboardHandler else { return }
        guard handler.smartSwitchEnabled else { return }

        // Check if overlay detection is enabled
        let prefs = SharedSettings.shared.loadPreferences()
        guard prefs.detectOverlayApps else { return }

        // Get current frontmost app
        guard let bundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }

        // Get current language state
        let currentLanguage = statusBarManager?.viewModel.isVietnameseEnabled == true ? 1 : 0

        // Check if should restore language using Smart Switch logic
        let result = handler.engine.checkSmartSwitchForApp(bundleId: bundleId, currentLanguage: currentLanguage)

        // If should switch, restore the saved language
        if result.shouldSwitch {
            let newEnabled = result.newLanguage == 1
            statusBarManager?.viewModel.isVietnameseEnabled = newEnabled
            handler.setVietnamese(newEnabled)

            debugWindowController?.logEvent("✅ Restored '\(bundleId)' language → \(newEnabled ? "Vietnamese" : "English")")
        } else {
            debugWindowController?.logEvent("ℹ️ No language change needed for '\(bundleId)' (current=\(currentLanguage))")
        }
    }
    
    // MARK: - Dock Icon
    
    private func updateDockIconVisibility(show: Bool) {
        if show {
            // Show Dock icon - regular app mode
            NSApp.setActivationPolicy(.regular)
            debugWindowController?.logEvent("🖥️ Dock icon: visible")
        } else {
            // Hide Dock icon - accessory/background app mode
            NSApp.setActivationPolicy(.accessory)
            debugWindowController?.logEvent("🖥️ Dock icon: hidden")
        }
    }
    
    /// Handle Smart Switch when app changes
    private func handleSmartSwitch(notification: Notification) {
        guard let handler = keyboardHandler else { return }
        
        debugWindowController?.logEvent("🔍 Smart Switch check: enabled=\(handler.smartSwitchEnabled), vUseSmartSwitchKey=\(handler.engine.vUseSmartSwitchKey)")
        
        guard handler.smartSwitchEnabled else { return }
        
        // Get the new active app
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleId = app.bundleIdentifier else { return }
        
        // Get current language from UI (StatusBar) - this is the source of truth
        let currentLanguage = statusBarManager?.viewModel.isVietnameseEnabled == true ? 1 : 0
        
        debugWindowController?.logEvent("🔍 Smart Switch: bundleId=\(bundleId), currentLanguage=\(currentLanguage)")
        
        // Check if should switch language, passing the actual current language
        let result = handler.engine.checkSmartSwitchForApp(bundleId: bundleId, currentLanguage: currentLanguage)
        
        debugWindowController?.logEvent("🔍 Smart Switch result: shouldSwitch=\(result.shouldSwitch), newLanguage=\(result.newLanguage)")
        
        if result.shouldSwitch {
            // Switch language
            let newEnabled = result.newLanguage == 1
            statusBarManager?.viewModel.isVietnameseEnabled = newEnabled
            handler.setVietnamese(newEnabled)
            
            debugWindowController?.logEvent("🔄 Smart Switch: '\(bundleId)' → \(newEnabled ? "Vietnamese" : "English")")
        } else {
            // App is new or language hasn't changed - save current language
            handler.engine.saveAppLanguage(bundleId: bundleId, language: currentLanguage)
            debugWindowController?.logEvent("📝 Smart Switch: Saved '\(bundleId)' → \(currentLanguage == 1 ? "Vietnamese" : "English")")
        }
    }
    
    private func setupMouseClickMonitor() {
        // Monitor mouse clicks to detect focus changes
        // When user clicks, they might be switching between input fields or moving cursor
        mouseClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            // Reset engine when mouse is clicked (likely focus change or cursor move)
            // Mark as cursor moved to disable autocomplete fix (avoid deleting text on right)
            self?.keyboardHandler?.resetWithCursorMoved()

            // Log detailed input detection info
            self?.logMouseClickInputDetection()
        }

        debugWindowController?.logEvent("  ✅ Mouse click monitor registered")
    }

    /// Log detailed information about the input type when mouse is clicked
    private func logMouseClickInputDetection() {
        // Get frontmost app info
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleId = app.bundleIdentifier else {
            debugWindowController?.logEvent("🖱️ Mouse click - engine reset, mid-sentence mode")
            return
        }

        let appName = app.localizedName ?? "Unknown"

        // Get focused element role from Accessibility API
        let detector = AppBehaviorDetector.shared
        let elementRole = detector.getFocusedElementRole() ?? "Unknown"
        
        // Get window title
        let windowTitle = detector.getCachedWindowTitle()

        // Get app behavior type
        let behavior = detector.detect()
        let behaviorName: String
        switch behavior {
        case .standard:
            behaviorName = "Standard"
        case .terminal:
            behaviorName = "Terminal"
        case .browserAddressBar:
            behaviorName = "Browser Address Bar"
        case .jetbrainsIDE:
            behaviorName = "JetBrains IDE"
        case .microsoftOffice:
            behaviorName = "Microsoft Office"
        case .spotlight:
            behaviorName = "Spotlight"
        case .electronApp:
            behaviorName = "Electron App"
        case .codeEditor:
            behaviorName = "Code Editor"
        }

        // Get injection method info
        let injectionInfo = detector.detectInjectionMethod()
        let injectionMethodName: String
        switch injectionInfo.method {
        case .fast: injectionMethodName = "Fast"
        case .slow: injectionMethodName = "Slow"
        case .selection: injectionMethodName = "Selection"
        case .autocomplete: injectionMethodName = "Autocomplete"
        }

        // Get current input source
        let inputSource = InputSourceManager.getCurrentInputSource()
        let inputSourceName = inputSource?.displayName ?? "Unknown"
        
        // Get matched Window Title Rule (if any)
        let matchedRule = detector.findMatchingRule()
        
        // Get IMKit behavior
        let imkitBehavior = detector.detectIMKitBehavior()

        // Log everything with nice formatting
        debugWindowController?.logEvent("🖱️ Mouse click detected")
        debugWindowController?.logEvent("   App: \(appName) (\(bundleId))")
        debugWindowController?.logEvent("   Window: \(windowTitle.isEmpty ? "(no title)" : windowTitle)")
        debugWindowController?.logEvent("   Input Type: \(elementRole)")
        debugWindowController?.logEvent("   Behavior: \(behaviorName)")
        debugWindowController?.logEvent("   Injection: \(injectionMethodName) [bs:\(injectionInfo.delays.backspace)µs, wait:\(injectionInfo.delays.wait)µs, txt:\(injectionInfo.delays.text)µs]")
        debugWindowController?.logEvent("   IMKit: markedText=\(imkitBehavior.useMarkedText), issues=\(imkitBehavior.hasMarkedTextIssues), delay=\(imkitBehavior.commitDelay)µs")
        debugWindowController?.logEvent("   Input Source: \(inputSourceName)")
        
        // Log matched rule if any
        if let rule = matchedRule {
            debugWindowController?.logEvent("   ✅ Rule: \(rule.name) (pattern: \"\(rule.titlePattern)\")")
        }
        
        debugWindowController?.logEvent("   → Engine reset, mid-sentence mode")
    }

    private func setupInputSourceManager() {
        inputSourceManager = InputSourceManager()

        // Connect debug logging
        inputSourceManager?.debugLogCallback = { [weak self] message in
            self?.debugWindowController?.logEvent(message)
        }

        // Handle input source changes
        inputSourceManager?.onInputSourceChanged = { [weak self] source, shouldEnable in
            self?.handleInputSourceChange(source: source, shouldEnable: shouldEnable)
        }

        debugWindowController?.logEvent("  ✅ Input Source Manager initialized")

        // IMPORTANT: Check current input source on startup and apply config
        if let currentSource = InputSourceManager.getCurrentInputSource() {
            let shouldEnable = inputSourceManager?.isEnabled(for: currentSource.id) ?? true
            debugWindowController?.logEvent("🌐 Initial Input Source: \(currentSource.displayName)")
            debugWindowController?.logEvent("   Should enable XKey: \(shouldEnable)")
            handleInputSourceChange(source: currentSource, shouldEnable: shouldEnable)
        }
    }

    /// Handle input source changes - apply enable/disable logic
    private func handleInputSourceChange(source: InputSourceInfo, shouldEnable: Bool) {
        // Check if this is XKeyIM input source
        let isXKeyIM = InputSourceManager.isXKeyInputSource(source)

        if isXKeyIM {
            // Switched TO XKeyIM - suspend CGEvent tap to let IMKit handle events
            debugWindowController?.logEvent("🔑 Switched to XKeyIM - suspending CGEvent tap")
            eventTapManager?.suspend()

            // Force enable Vietnamese mode for XKeyIM
            self.statusBarManager?.viewModel.isVietnameseEnabled = true
            self.keyboardHandler?.setVietnamese(true)
        } else {
            // Switched AWAY from XKeyIM
            debugWindowController?.logEvent("🔄 Switched away from XKeyIM")

            // Check if event tap is already running
            // If not (e.g., started with XKeyIM active), start it now
            guard let manager = eventTapManager else { return }

            // Try to start event tap if it's not running
            do {
                try manager.start()
                debugWindowController?.logEvent("  ✅ Event tap started (was not running)")
            } catch EventTapManager.EventTapError.alreadyRunning {
                // Already running - just resume it
                debugWindowController?.logEvent("  ▶️ Resuming event tap")
                manager.resume()
            } catch {
                debugWindowController?.logEvent("  ❌ Failed to start event tap: \(error)")
            }

            // Get current state
            let currentlyEnabled = self.statusBarManager?.viewModel.isVietnameseEnabled ?? false

            // Auto enable/disable Vietnamese mode based on configuration
            if shouldEnable {
                // Enable Vietnamese mode
                if !currentlyEnabled {
                    self.statusBarManager?.viewModel.isVietnameseEnabled = true
                    self.keyboardHandler?.setVietnamese(true)
                    self.debugWindowController?.logEvent("✅ Input Source '\(source.displayName)' → Auto-enabled")
                }
            } else {
                // Disable Vietnamese mode
                if currentlyEnabled {
                    self.statusBarManager?.viewModel.isVietnameseEnabled = false
                    self.keyboardHandler?.setVietnamese(false)
                    self.debugWindowController?.logEvent("⏹️ Input Source '\(source.displayName)' → Auto-disabled")
                }
            }
        }
    }

    // MARK: - Sparkle Auto-Update

    private func checkForUpdates() {
        debugWindowController?.logEvent("🔍 Manually checking for updates...")
        // Activate app to bring update dialog to front
        NSApp.activate(ignoringOtherApps: true)
        updaterController?.updater.checkForUpdates()
    }
    
    /// Check for updates from SwiftUI views (activates app to bring dialog to front)
    func checkForUpdatesFromUI() {
        debugWindowController?.logEvent("🔍 [UI] Manually checking for updates...")
        
        // Must be called on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Activate app to bring update dialog to front
            NSApp.activate(ignoringOtherApps: true)
            
            // Use the same method as menu bar - updater.checkForUpdates()
            if let updater = self.updaterController?.updater {
                self.debugWindowController?.logEvent("✅ [UI] Calling updater.checkForUpdates()")
                updater.checkForUpdates()
            } else {
                self.debugWindowController?.logEvent("❌ [UI] updaterController or updater is nil!")
            }
        }
    }


    private func setupSparkleUpdater() {
        do {
            // Initialize Sparkle updater controller
            // This will automatically check for updates based on Info.plist settings:
            // - SUFeedURL: appcast feed URL
            // - SUPublicEDKey: public key for signature verification
            // - SUEnableAutomaticChecks: enable automatic update checks
            // - SUScheduledCheckInterval: check interval in seconds (86400 = 24 hours)
            updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
            
            debugWindowController?.logEvent("✅ Sparkle auto-update initialized")
            debugWindowController?.logEvent("   Feed URL: \(Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? "Not configured")")
            debugWindowController?.logEvent("   Auto-check: \(Bundle.main.object(forInfoDictionaryKey: "SUEnableAutomaticChecks") as? Bool ?? false)")
            
        } catch {
            debugWindowController?.logEvent("❌ Failed to initialize Sparkle: \(error)")
        }
    }
}

