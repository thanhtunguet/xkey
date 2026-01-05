//
//  DebugView.swift
//  XKey
//
//  Professional Debug Console with modern UI design
//

import SwiftUI

// MARK: - Main Debug View

struct DebugView: View {
    @ObservedObject var viewModel: DebugViewModel
    @State private var searchText = ""
    @State private var filterLevel: LogLevel = .all
    
    enum LogLevel: String, CaseIterable {
        case all = "All"
        case error = "Error"
        case warning = "Warning"
        case success = "Success"
        case debug = "Debug"
        
        var icon: String {
            switch self {
            case .all: return "line.3.horizontal.decrease.circle"
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .success: return "checkmark.circle.fill"
            case .debug: return "magnifyingglass.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .primary
            case .error: return .red
            case .warning: return .orange
            case .success: return .green
            case .debug: return .purple
            }
        }
    }
    
    var filteredLines: [String] {
        var lines = viewModel.logLines
        
        // Filter by search text
        if !searchText.isEmpty {
            lines = lines.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
        
        // Filter by log level
        switch filterLevel {
        case .all: break
        case .error: lines = lines.filter { $0.contains("[ERROR]") || $0.contains("ERROR") }
        case .warning: lines = lines.filter { $0.contains("[WARN]") || $0.contains("WARNING") }
        case .success: lines = lines.filter { $0.contains("[OK]") || $0.contains("SUCCESS") }
        case .debug: lines = lines.filter { $0.contains("[DEBUG]") || $0.contains("DEBUG") }
        }
        
        return lines
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            DebugHeaderView(viewModel: viewModel)
            
            // Toolbar
            DebugToolbar(
                viewModel: viewModel,
                searchText: $searchText,
                filterLevel: $filterLevel
            )
            
            // Log Viewer
            LogListView(
                lines: filteredLines,
                totalCount: viewModel.logLines.count
            )
        }
        .frame(width: 900, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            viewModel.windowDidBecomeVisible()
            viewModel.refreshPinnedConfig()
        }
        .onDisappear {
            viewModel.windowDidBecomeHidden()
        }
    }
}

// MARK: - Header View

struct DebugHeaderView: View {
    @ObservedObject var viewModel: DebugViewModel
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 16) {
            // App Icon & Title
            HStack(spacing: 10) {
                Image(systemName: "ant.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("XKey Debug")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("v\(AppVersion.current) (\(AppVersion.build))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(viewModel.isLoggingEnabled ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                
                Text(viewModel.isLoggingEnabled ? "Recording" : "Paused")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(viewModel.isLoggingEnabled ? .green : .orange)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .stroke(viewModel.isLoggingEnabled ? Color.green.opacity(0.4) : Color.orange.opacity(0.4), lineWidth: 1)
            )
            
            // Stats
            HStack(spacing: 4) {
                Image(systemName: "doc.text")
                    .font(.system(size: 10))
                    .foregroundColor(.blue)
                Text("\(viewModel.logLines.count)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                Text("lines")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.blue.opacity(0.08))
            )
            
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text(timeString)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.green.opacity(0.08))
            )
            .onReceive(timer) { time in
                currentTime = time
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.15)),
            alignment: .bottom
        )
    }
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: currentTime)
    }
}

// MARK: - Toolbar

struct DebugToolbar: View {
    @ObservedObject var viewModel: DebugViewModel
    @Binding var searchText: String
    @Binding var filterLevel: DebugView.LogLevel
    
    var body: some View {
        HStack(spacing: 10) {
            // Search Field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                
                TextField("Search...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            .frame(width: 180)
            
            // Filter Picker
            Picker("", selection: $filterLevel) {
                ForEach(DebugView.LogLevel.allCases, id: \.self) { level in
                    Label(level.rawValue, systemImage: level.icon)
                        .tag(level)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 90)
            
            Divider().frame(height: 18)
            
            // Action Buttons
            Group {
                ToolbarIconButton(icon: "gearshape", tooltip: "Log Config") {
                    viewModel.logCurrentConfig()
                }
                
                ToolbarIconButton(icon: "doc.on.doc", tooltip: "Copy All") {
                    viewModel.copyLogs()
                }
                
                ToolbarIconButton(icon: "folder", tooltip: "Open File") {
                    viewModel.openLogFile()
                }
                
                ToolbarIconButton(icon: "trash", tooltip: "Clear", color: .red) {
                    viewModel.clearLogs()
                }
            }
            
            Spacer()
            
            // Toggle Buttons
            Toggle(isOn: $viewModel.isVerboseLogging) {
                Text("Verbose")
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
            
            Toggle(isOn: $viewModel.isLoggingEnabled) {
                Text("Recording")
                    .font(.system(size: 11))
            }
            .toggleStyle(.checkbox)
            .onChange(of: viewModel.isLoggingEnabled) { _ in
                viewModel.toggleLogging()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
    }
}

// MARK: - Toolbar Icon Button

struct ToolbarIconButton: View {
    let icon: String
    let tooltip: String
    var color: Color = .primary
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(isHovered ? color : .secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isHovered ? color.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Log List View

struct LogListView: View {
    let lines: [String]
    let totalCount: Int
    
    @State private var autoScroll = true
    @State private var lastLineCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Info Bar
            HStack {
                if lines.count != totalCount {
                    Text("Showing \(lines.count) of \(totalCount) entries")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(totalCount) entries")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle(isOn: $autoScroll) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.to.line")
                            .font(.system(size: 9))
                        Text("Auto-scroll")
                            .font(.system(size: 10))
                    }
                }
                .toggleStyle(.checkbox)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            
            // Log Content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            LogLineView(line: line, lineNumber: index + 1)
                                .id(index)
                        }
                    }
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: lines.count) { newCount in
                    if autoScroll && newCount > lastLineCount {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newCount - 1, anchor: .bottom)
                        }
                    }
                    lastLineCount = newCount
                }
            }
        }
    }
}

// MARK: - Log Line View

struct LogLineView: View {
    let line: String
    let lineNumber: Int
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Line number
            Text("\(lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.4))
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 8)
            
            // Log text
            Text(line)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(
            Rectangle()
                .fill(backgroundColor)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    private var textColor: Color {
        return .primary
    }
    
    private var backgroundColor: Color {
        if isHovered {
            return Color.blue.opacity(0.06)
        }
        return lineNumber % 2 == 0 ? Color.clear : Color.gray.opacity(0.025)
    }
}

// MARK: - Preview

#Preview {
    DebugView(viewModel: DebugViewModel())
}
