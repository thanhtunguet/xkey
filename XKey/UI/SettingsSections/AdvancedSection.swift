//
//  AdvancedSection.swift
//  XKey
//
//  Shared Advanced Settings Section
//

import SwiftUI

struct AdvancedSection: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsGroup(title: "Chính tả & Viết hoa") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Khôi phục nếu sai chính tả", isOn: $viewModel.preferences.restoreIfWrongSpelling)
                        Toggle("Tự động viết hoa chữ đầu câu", isOn: $viewModel.preferences.upperCaseFirstChar)
                        Toggle("Cho phép phụ âm Z, F, W, J", isOn: $viewModel.preferences.allowConsonantZFWJ)
                    }
                }
                
                SettingsGroup(title: "Đặt dấu") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Đặt dấu tự do (Free Mark)", isOn: $viewModel.preferences.freeMarkEnabled)
                        
                        Text("Cho phép đặt dấu ở bất kỳ vị trí nào trong từ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                SettingsGroup(title: "Tạm tắt") {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Tạm tắt chính tả bằng phím Ctrl", isOn: $viewModel.preferences.tempOffSpellingEnabled)
                            
                            Text("Giữ Ctrl khi gõ để tạm thời tắt kiểm tra chính tả")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Tạm tắt gõ tiếng Việt bằng phím Option", isOn: $viewModel.preferences.tempOffEngineEnabled)
                            
                            Text("Giữ Option (⌥) khi gõ để tạm thời tắt bộ gõ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                SettingsGroup(title: "Smart Switch") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Main Smart Switch toggle
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Nhớ ngôn ngữ theo ứng dụng", isOn: $viewModel.preferences.smartSwitchEnabled)

                            Text("Tự động chuyển ngôn ngữ khi chuyển app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        // Overlay app detection (sub-option, only shown when Smart Switch is enabled)
                        if viewModel.preferences.smartSwitchEnabled {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Hỗ trợ phát hiện Spotlight/Raycast/Alfred", isOn: $viewModel.preferences.detectOverlayApps)

                                // Info message
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Tránh ghi đè ngôn ngữ của app bên dưới khi bạn toggle trong Spotlight/Raycast")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    .padding(.top, 4)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.05))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(.leading, 20)  // Indent sub-option
                        }
                    }
                }
                
                // Window Title Rules
                SettingsGroup(title: "Hiệu chỉnh XKey Engine theo ứng dụng") {
                    if #available(macOS 13.0, *) {
                        WindowTitleRulesView()
                    } else {
                        Text("Tính năng này yêu cầu macOS 13.0 trở lên")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                SettingsGroup(title: "Debug") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Bật chế độ Debug", isOn: $viewModel.preferences.debugModeEnabled)
                        
                        Text("Hiển thị cửa sổ debug để theo dõi hoạt động của bộ gõ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // IMKit Mode (Experimental)
                SettingsGroup(title: "Input Method Kit (Thử nghiệm)") {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Bật IMKit Mode", isOn: $viewModel.preferences.imkitEnabled)

                            Text("Sử dụng Input Method Kit thay vì CGEvent injection. Giúp gõ mượt hơn trong Terminal app và IDE Terminal.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if viewModel.preferences.imkitEnabled {
                            Divider()

                            VStack(alignment: .leading, spacing: 8) {
                                Toggle("Hiển thị gạch chân khi gõ (Khuyến nghị)", isOn: $viewModel.preferences.imkitUseMarkedText)
                                    .padding(.leading, 20)

                                Text(viewModel.preferences.imkitUseMarkedText ?
                                    "✓ Chuẩn IMKit - Hiển thị gạch chân khi đang gõ. Ổn định và tương thích tốt với mọi ứng dụng." :
                                    "⚠️ Direct Mode - Không có gạch chân nhưng có thể gặp lỗi thêm dấu/double ký tự trong một số trường hợp trên các app khác nhau. Nếu gặp lỗi như vậy hãy bật tính năng này lên và thử lại.")
                                    .font(.caption)
                                    .foregroundColor(viewModel.preferences.imkitUseMarkedText ? .secondary : .orange)
                                    .padding(.leading, 20)
                            }
                            
                            Divider()
                            
                            // Install XKeyIM button
                            HStack {
                                Text("XKeyIM Input Method:")
                                    .font(.caption)
                                Spacer()
                                Button("Cài đặt XKeyIM...") {
                                    IMKitHelper.installXKeyIM()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            Text("Sau khi cài đặt, vào System Settings → Keyboard → Input Sources để thêm XKey Vietnamese")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            // Quick switch hotkey
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Phím tắt chuyển nhanh sang XKey:")
                                        .font(.caption)
                                    Spacer()
                                    // Use custom binding for optional hotkey
                                    HotkeyRecorderView(hotkey: Binding(
                                        get: { viewModel.preferences.switchToXKeyHotkey ?? Hotkey(keyCode: 0, modifiers: []) },
                                        set: { newValue in
                                            // Set to nil if empty, otherwise save the hotkey
                                            if newValue.keyCode == 0 && newValue.modifiers.isEmpty {
                                                viewModel.preferences.switchToXKeyHotkey = nil
                                            } else {
                                                viewModel.preferences.switchToXKeyHotkey = newValue
                                            }
                                        }
                                    ))
                                        .frame(width: 150)
                                }
                                
                                Text("Phím tắt này sẽ toggle giữa XKey và ABC. Nếu đang dùng XKey → chuyển sang ABC (hoặc bộ gõ tiếng Anh khác), ngược lại → XKey")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                
                                // Quick switch button
                                HStack {
                                    Button("Chuyển sang XKey ngay") {
                                        InputSourceSwitcher.shared.switchToXKey()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
