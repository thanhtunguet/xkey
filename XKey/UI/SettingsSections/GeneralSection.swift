//
//  GeneralSection.swift
//  XKey
//
//  Shared General Settings Section
//

import SwiftUI

struct GeneralSection: View {
    @ObservedObject var viewModel: PreferencesViewModel
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Hotkey
                SettingsGroup(title: "Phím tắt") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Bật/tắt tiếng Việt:")
                            Spacer()
                            HotkeyRecorderView(hotkey: $viewModel.preferences.toggleHotkey)
                                .frame(width: 150)
                        }
                        
                        Toggle("Phát âm thanh khi bật/tắt", isOn: $viewModel.preferences.beepOnToggle)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Hoàn tác gõ tiếng Việt bằng phím Esc", isOn: $viewModel.preferences.undoTypingEnabled)
                            
                            Text("Nhấn Esc ngay sau khi gõ để hoàn tác việc bỏ dấu (ví dụ: \"tiếng\" → \"tieesng\")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Input Method
                SettingsGroup(title: "Kiểu gõ") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(InputMethod.allCases, id: \.self) { method in
                            SettingsRadioButton(
                                title: method.displayName,
                                isSelected: viewModel.preferences.inputMethod == method
                            ) {
                                viewModel.preferences.inputMethod = method
                            }
                        }
                    }
                }
                
                // Code Table
                SettingsGroup(title: "Bảng mã") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(CodeTable.allCases, id: \.self) { table in
                            SettingsRadioButton(
                                title: table.displayName,
                                isSelected: viewModel.preferences.codeTable == table
                            ) {
                                viewModel.preferences.codeTable = table
                            }
                        }
                    }
                }
                
                // Basic Options
                SettingsGroup(title: "Tùy chọn") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Kiểu gõ hiện đại (oà/uý)", isOn: $viewModel.preferences.modernStyle)
                        Toggle("Kiểm tra chính tả", isOn: $viewModel.preferences.spellCheckEnabled)
                        Toggle("Sửa lỗi tự động hoàn thành (áp dụng cho Chrome, Terminal...)", isOn: $viewModel.preferences.fixAutocomplete)
                    }
                }
                
                // Experimental Features
                SettingsGroup(title: "Thử nghiệm") {
                    VStack(alignment: .leading, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Phát hiện từ tiếng Anh", isOn: $viewModel.preferences.englishDetectionEnabled)
                            
                            Text("Bỏ qua xử lý tiếng Việt khi phát hiện từ tiếng Anh (ví dụ: \"street\", \"check\"). Tính năng này đang trong giai đoạn thử nghiệm.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
