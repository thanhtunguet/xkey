//
//  PreferencesViewModel.swift
//  XKey
//
//  ViewModel for Preferences
//

import SwiftUI
import Combine

import ServiceManagement

class PreferencesViewModel: ObservableObject {
    @Published var preferences: Preferences

    init() {
        // Load from SharedSettings (plist file)
        self.preferences = SharedSettings.shared.loadPreferences()
    }

    func save() {
        // Save to SharedSettings (plist file)
        SharedSettings.shared.savePreferences(preferences)

        // Apply launch at login setting
        setLaunchAtLogin(preferences.startAtLogin)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                
            }
        } else {
            SMLoginItemSetEnabled("group.com.codetay.inputmethod.XKey.debug" as CFString, enabled)
        }
    }
}
