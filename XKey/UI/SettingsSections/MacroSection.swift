//
//  MacroSection.swift
//  XKey
//
//  Shared Macro Settings Section
//

import SwiftUI

struct MacroSection: View {
    @StateObject private var viewModel = MacroManagementViewModel()
    @ObservedObject var prefsViewModel: PreferencesViewModel
    @State private var newMacroText: String = ""
    @State private var newMacroContent: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Settings Group
                SettingsGroup(title: "Cài đặt Macro") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Bật Macro", isOn: $prefsViewModel.preferences.macroEnabled)
                        
                        if prefsViewModel.preferences.macroEnabled {
                            Toggle("Dùng macro trong chế độ tiếng Anh", isOn: $prefsViewModel.preferences.macroInEnglishMode)
                                .padding(.leading, 20)
                            Toggle("Tự động viết hoa macro", isOn: $prefsViewModel.preferences.autoCapsMacro)
                                .padding(.leading, 20)
                        }
                    }
                }
                
                // Add new macro
                SettingsGroup(title: "Thêm macro mới") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .bottom, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Từ viết tắt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("vd: btw", text: $newMacroText)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 120)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nội dung thay thế")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("vd: by the way", text: $newMacroContent)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            Button("Thêm") {
                                addMacro()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newMacroText.isEmpty || newMacroContent.isEmpty)
                        }
                        
                        if showError {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                // Macro list
                SettingsGroup(title: "Danh sách macro (\(viewModel.macros.count))") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Action buttons
                        HStack(spacing: 12) {
                            Button(action: viewModel.importMacros) {
                                Label("Import", systemImage: "square.and.arrow.down")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: viewModel.exportMacros) {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            
                            Spacer()
                            
                            if !viewModel.macros.isEmpty {
                                Button(role: .destructive) {
                                    viewModel.clearAll()
                                } label: {
                                    Label("Xóa tất cả", systemImage: "trash")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        Divider()
                        
                        // Macro list
                        if viewModel.macros.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "text.badge.plus")
                                    .font(.system(size: 32))
                                    .foregroundColor(.secondary)
                                Text("Chưa có macro nào")
                                    .foregroundColor(.secondary)
                                Text("Thêm macro để tự động thay thế từ viết tắt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.macros) { macro in
                                    MacroRowView(macro: macro) {
                                        viewModel.deleteMacro(macro)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .onAppear {
            viewModel.loadMacros()
        }
    }
    
    private func addMacro() {
        let trimmedText = newMacroText.trimmingCharacters(in: .whitespaces)
        let trimmedContent = newMacroContent.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedText.isEmpty && !trimmedContent.isEmpty else {
            showErrorMessage("Vui lòng nhập đầy đủ thông tin")
            return
        }
        
        guard trimmedText.count >= 2 else {
            showErrorMessage("Từ viết tắt phải có ít nhất 2 ký tự")
            return
        }
        
        if viewModel.addMacro(text: trimmedText, content: trimmedContent) {
            newMacroText = ""
            newMacroContent = ""
            showError = false
        } else {
            showErrorMessage("Macro '\(trimmedText)' đã tồn tại")
        }
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showError = false
        }
    }
}

// MARK: - Macro Row View

struct MacroRowView: View {
    let macro: MacroItem
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Shortcut text
            Text(macro.text)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(4)
                .frame(minWidth: 80, alignment: .center)
            
            // Arrow
            Image(systemName: "arrow.right")
                .foregroundColor(.secondary)
                .font(.system(size: 12, weight: .medium))
            
            // Content
            Text(macro.content)
                .foregroundColor(.primary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundColor(isHovered ? .red : .secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0.5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHovered ? Color.gray.opacity(0.1) : Color.gray.opacity(0.03))
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
