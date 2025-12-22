//
//  BackupRestoreSection.swift
//  XKey
//
//  Shared Backup & Restore Settings Section
//

import SwiftUI

struct BackupRestoreSection: View {
    @State private var showSuccessAlert = false
    @State private var showCountdownSheet = false
    @State private var countdownSeconds = 3
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var countdownTimer: Timer?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Export Section
                SettingsGroup(title: "Sao lưu thiết lập") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Export toàn bộ cấu hình ra file .plist")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: exportSettings) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        Text("Lưu toàn bộ cài đặt, macro, quy tắc. Phù hợp để backup hoặc chuyển sang máy khác.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Import Section
                SettingsGroup(title: "Khôi phục thiết lập") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Import cấu hình từ file đã lưu")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Button(action: importSettings) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("Import sẽ ghi đè toàn bộ thiết lập hiện tại và tự động khởi động lại XKey.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .alert(alertTitle, isPresented: $showSuccessAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showCountdownSheet) {
            RestartCountdownView(
                seconds: $countdownSeconds,
                onCancel: {
                    stopCountdown()
                    showCountdownSheet = false
                },
                onRestart: {
                    stopCountdown()
                    showCountdownSheet = false
                    // Delay a bit to let sheet close, then restart
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        Self.performRestart()
                    }
                }
            )
            .onAppear {
                startCountdown()
            }
            .onDisappear {
                stopCountdown()
            }
        }
    }
    
    // MARK: - Export/Import Actions
    
    private func exportSettings() {
        guard let data = SharedSettings.shared.exportSettings() else {
            showAlert(title: "Lỗi", message: "Không thể export thiết lập")
            return
        }
        
        let panel = NSSavePanel()
        panel.title = "Export Settings"
        panel.message = "Lưu file thiết lập XKey"
        panel.nameFieldStringValue = SharedSettings.shared.getExportFileName()
        panel.allowedContentTypes = [.propertyList]
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                showAlert(title: "Thành công", message: "Đã export thiết lập thành công")
            } catch {
                showAlert(title: "Lỗi", message: "Không thể lưu file: \(error.localizedDescription)")
            }
        }
    }
    
    private func importSettings() {
        let panel = NSOpenPanel()
        panel.title = "Import Settings"
        panel.message = "Chọn file thiết lập XKey để import"
        panel.allowedContentTypes = [.propertyList]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                if SharedSettings.shared.importSettings(from: data) {
                    // Show countdown sheet for auto-restart
                    countdownSeconds = 3
                    showCountdownSheet = true
                } else {
                    showAlert(title: "Lỗi", message: "File không hợp lệ hoặc không đúng định dạng")
                }
            } catch {
                showAlert(title: "Lỗi", message: "Không thể đọc file: \(error.localizedDescription)")
            }
        }
    }
    
    private func startCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [self] _ in
            DispatchQueue.main.async {
                if self.countdownSeconds > 1 {
                    self.countdownSeconds -= 1
                } else {
                    self.stopCountdown()
                    self.showCountdownSheet = false
                    // Delay a bit to let sheet close, then restart
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        Self.performRestart()
                    }
                }
            }
        }
    }
    
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    /// Restart the app using a shell script
    private static func performRestart() {
        let bundlePath = Bundle.main.bundleURL.path
        let pid = ProcessInfo.processInfo.processIdentifier
        
        // Create a shell script that will:
        // 1. Wait for this process to exit
        // 2. Relaunch the app
        let script = """
        while kill -0 \(pid) 2>/dev/null; do
            sleep 0.1
        done
        open "\(bundlePath)"
        """
        
        let task = Process()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", script]
        
        do {
            try task.run()
        } catch {
            NSLog("Failed to start restart script: \(error)")
        }
        
        // Force quit the app - use exit() instead of terminate() to avoid UI blocking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            exit(0)
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showSuccessAlert = true
    }
}

// MARK: - Restart Countdown View

struct RestartCountdownView: View {
    @Binding var seconds: Int
    let onCancel: () -> Void
    let onRestart: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.green)
            
            Text("Import thành công!")
                .font(.headline)
            
            Text("XKey sẽ tự động khởi động lại sau")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Countdown display - compact
            HStack(spacing: 4) {
                Text("\(seconds)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.accentColor)
                    .frame(width: 30)
                Text("giây")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            
            HStack(spacing: 12) {
                Button("Huỷ") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Button("Khởi động lại ngay") {
                    onRestart()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(24)
        .frame(width: 280)
    }
}
