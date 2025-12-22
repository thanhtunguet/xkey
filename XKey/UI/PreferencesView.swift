//
//  PreferencesView.swift
//  XKey
//
//  SwiftUI Preferences View with Tab Layout
//  Uses shared components from SettingsSections/
//

import SwiftUI

struct PreferencesView: View {
    @StateObject private var viewModel = PreferencesViewModel()
    @State private var selectedTab: Int

    var onSave: ((Preferences) -> Void)?
    var onClose: (() -> Void)?

    init(selectedTab: Int = 0, onSave: ((Preferences) -> Void)? = nil, onClose: (() -> Void)? = nil) {
        self._selectedTab = State(initialValue: selectedTab)
        self.onSave = onSave
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            Text("Cài đặt XKey")
                .font(.title2)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            // Tab View - Using shared components
            TabView(selection: $selectedTab) {
                // Tab 0: Giới thiệu
                AboutSection()
                    .tabItem {
                        Label("Giới thiệu", systemImage: "info.circle")
                    }
                    .tag(0)
                
                // Tab 1: Cơ bản
                GeneralSection(viewModel: viewModel)
                    .tabItem {
                        Label("Cơ bản", systemImage: "gearshape")
                    }
                    .tag(1)
                
                // Tab 2: Gõ nhanh
                QuickTypingSection(viewModel: viewModel)
                    .tabItem {
                        Label("Gõ nhanh", systemImage: "keyboard")
                    }
                    .tag(2)
                
                // Tab 3: Nâng cao
                AdvancedSection(viewModel: viewModel)
                    .tabItem {
                        Label("Nâng cao", systemImage: "slider.horizontal.3")
                    }
                    .tag(3)
                
                // Tab 4: Input Sources
                InputSourcesSection()
                    .tabItem {
                        Label("Input Sources", systemImage: "globe")
                    }
                    .tag(4)
                
                // Tab 5: Loại trừ
                ExcludedAppsSection(viewModel: viewModel)
                    .tabItem {
                        Label("Loại trừ", systemImage: "app.badge.fill")
                    }
                    .tag(5)
                
                // Tab 6: Macro
                MacroSection(prefsViewModel: viewModel)
                    .tabItem {
                        Label("Macro", systemImage: "text.badge.plus")
                    }
                    .tag(6)
                
                // Tab 7: Chuyển đổi
                ConvertToolSection()
                    .tabItem {
                        Label("Chuyển đổi", systemImage: "arrow.left.arrow.right")
                    }
                    .tag(7)
                
                // Tab 8: Giao diện
                AppearanceSection(viewModel: viewModel)
                    .tabItem {
                        Label("Giao diện", systemImage: "paintbrush")
                    }
                    .tag(8)
                
                // Tab 9: Sao lưu
                BackupRestoreSection()
                    .tabItem {
                        Label("Sao lưu", systemImage: "arrow.up.arrow.down.circle")
                    }
                    .tag(9)
            }
            .padding(.horizontal, 8)
            
            // Buttons
            HStack {
                Spacer()
                
                Button("Hủy") {
                    onClose?()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Lưu") {
                    viewModel.save()
                    onSave?(viewModel.preferences)
                    onClose?()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 650, height: 550)
    }
}

// MARK: - Preview

#Preview {
    PreferencesView()
}
