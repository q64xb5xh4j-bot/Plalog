//
//  RegistrationFlowComponents.swift
//  Plalog
//
//  Created by (User) on 2026/01/18.
//  Common UI Components for Registration Flow
//

import SwiftUI

struct DiscoveryStatusBadge: View {
    let candidate: Candidate
    @Binding var isCorrectionMode: Bool
    @ObservedObject var themeManager: ThemeManager = ThemeManager.shared
    
    // Actions
    var onUpdate: () async -> Void
    var onVote: () async -> Void
    
    var body: some View {
        Group {
            if case .firstDiscovery = candidate.discoveryStatus {
                VStack(spacing: 4) {
                    Text("UNREGISTERED").font(.system(size: 24, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("詳細を入力して最初の発見者になろう！").font(.caption).foregroundStyle(.primary)
                }
                .padding().frame(maxWidth: .infinity).background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12).overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                .padding(.horizontal, 40)
                
            } else if case let .discovered(name, date, isLocked, voteCount) = candidate.discoveryStatus {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "person.2.fill").foregroundStyle(.blue)
                        VStack(alignment: .leading) {
                            Text("DISCOVERED BY: \(name)").font(.headline.monospaced())
                            Text(date.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        if isLocked {
                            // Verified Badge
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("VERIFIED")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .clipShape(Capsule())
                        } else {
                            // Correction Mode Toggle
                            if isCorrectionMode {
                                Button {
                                    Task { await onUpdate() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "paperplane.fill")
                                        Text("修正を送信")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(themeManager.currentTheme.mainColor)
                                    .clipShape(Capsule())
                                }
                            } else {
                                Button {
                                    LocalHaptics.select()
                                    isCorrectionMode = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "pencil")
                                        Text("修正")
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(isLocked ? .secondary : themeManager.currentTheme.mainColor) // Note: isLocked is checked above, but safe to keep
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 12)
                                    .background(Color.gray.opacity(0.1)) // Assuming default background for toggle
                                    // Or use Theme? Original used themeManager.currentTheme.mainColor.opacity(0.1)
                                    // I'll stick to original logic roughly or improve it.
                                    .background(themeManager.currentTheme.mainColor.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    // Voting
                    if !isLocked {
                        Divider()
                        HStack {
                            Text("情報は正確ですか？").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button {
                                Task { await onVote() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "hand.thumbsup.fill")
                                    Text("正確です (\(voteCount))")
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding().frame(maxWidth: .infinity).background(Color.blue.opacity(0.1))
                .cornerRadius(12).padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Registration Input Form
struct RegistrationFormView: View {
    // Bindings for Input
    @Binding var title: String
    @Binding var maker: String
    @Binding var scale: String
    @Binding var series: String
    @Binding var grade: String
    @Binding var jan: String
    @Binding var memo: String
    
    // Data Sources for Dropdowns
    var availableMakers: [String] = []
    var availableScales: [String] = []
    var availableSeries: [String] = []
    var availableGrades: [String] = []
    
    // State Controls
    var isCorrectionMode: Bool
    var isCloudDiscovered: Bool
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Internal Helper for Read-Only Logic
    private func checkReadOnly(_ binding: Binding<String>) -> Bool {
        // Read-Only if: Cloud Item AND Not Correction Mode AND Field has value (not empty)
        return !isCorrectionMode && isCloudDiscovered && !binding.wrappedValue.isEmpty
    }

    var body: some View {
        VStack(spacing: 24) {
             // Group 0: Title (Item Name)
             formField(label: "アイテム名", text: $title, isReadOnly: checkReadOnly($title))
            
             // Group 1: Compact Info
             Grid(horizontalSpacing: 20, verticalSpacing: 16) {
                 GridRow {
                     // Maker Picker
                     EditableSelectionField(label: "メーカー", selection: $maker, options: availableMakers, isReadOnly: checkReadOnly($maker))
                     
                     // Scale Picker
                     EditableSelectionField(label: "スケール", selection: $scale, options: availableScales, isReadOnly: checkReadOnly($scale))
                 }
                 GridRow {
                     // Grade Picker
                     EditableSelectionField(label: "グレード", selection: $grade, options: availableGrades, isReadOnly: checkReadOnly($grade))
                     
                     // JAN (Text)
                     formField(label: "JAN", text: $jan, isReadOnly: checkReadOnly($jan), isNumeric: true)
                 }
             }
             
             // Group 2: Full Width
             // Series Picker
             EditableSelectionField(label: "シリーズ名", selection: $series, options: availableSeries, isReadOnly: checkReadOnly($series))
             
             // Group 3: Memo
             formField(label: "メモ", text: $memo, isMultiline: true)
        }
    }
    
    // Internal Form Field Builder (Text)
    private func formField(label: String, text: Binding<String>, isMultiline: Bool = false, isReadOnly: Bool = false, isNumeric: Bool = false) -> some View {
        let showPrompt = !isReadOnly && text.wrappedValue.isEmpty
        
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            if isMultiline {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: text)
                        .scrollContentBackground(.hidden)
                        .frame(height: 100)
                        .padding(12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                        )
                        .disabled(isReadOnly)
                        .foregroundStyle(Color.primary)
                    
                    if showPrompt {
                        Text("未入力").foregroundStyle(.red.opacity(0.5)).padding(.top, 20).padding(.leading, 16).allowsHitTesting(false)
                    }
                }
            } else {
                TextField("", text: text, prompt: Text(showPrompt ? "未入力" : "").foregroundColor(.red.opacity(0.5)))
                    .keyboardType(isNumeric ? .numberPad : .default)
                    .padding(14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    )
                    .disabled(isReadOnly)
                    .foregroundStyle(isReadOnly ? .secondary : .primary)
            }
        }
    }
    
}

// MARK: - Reusable Selection Field (Combo Box)
struct EditableSelectionField: View {
    let label: String
    @Binding var selection: String
    let options: [String]
    var isReadOnly: Bool = false
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            HStack(spacing: 0) {
                // 1. Text Field (Editable)
                TextField("直接入力または選択", text: $selection)
                    .disabled(isReadOnly)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                
                // 2. Divider
                if !options.isEmpty && !isReadOnly {
                    Divider().padding(.vertical, 8)
                }
                
                // 3. Menu Button
                if !options.isEmpty && !isReadOnly {
                    Menu {
                        // Header
                        Text("リストから選択").font(.caption).foregroundStyle(.secondary)
                        
                        ForEach(options, id: \.self) { option in
                            Button {
                                selection = option
                            } label: {
                                HStack {
                                    Text(option)
                                    if selection == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        ZStack {
                            Color(UIColor.secondarySystemBackground) // Fill background to make it look like a button
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                        }
                        .frame(width: 50, height: 50) // Explicit larger size
                        .contentShape(Rectangle())
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.05), lineWidth: 1)
            )
        }
    }
}

