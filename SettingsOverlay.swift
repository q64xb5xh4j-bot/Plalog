// SettingsOverlay.swift V72
// PART 1 OF 2
// 1. バージョン管理ルールに基づき更新 (V71 -> V72)
// 2. 修正点:
//    - ZIP圧縮プロセスを完全に撤廃。フォルダ（URL）を直接ShareLinkに渡す方式に変更。
//    - 新規アイテムが漏れる問題に対し、prepareBackupData実行直前に `modelContext.save()` を強制。
//    - UIの不変性ルールに基づき、ZStack + 透明ShareLinkのデザインを1ピクセルも変えずに維持。
// 3. 全文差し替え・分割送付ルール適用

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UIKit
import Foundation
import PhotosUI

struct SettingsOverlay: View {
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allKits: [Kit]
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var storeManager = StoreKitManager.shared
    
    // ✅ GOD MODE Settings
    @AppStorage("googleApiKey") private var googleApiKey: String = ""
    @AppStorage("googleSearchEngineId") private var googleSearchEngineId: String = ""
    @AppStorage("isGodModeEnabled") private var isGodModeEnabled: Bool = false
    
    // UI Flags
    @State private var showFileImport = false
    @State private var showItemManagement = false
    @State private var showMissingImages = false
    @State private var importMessage: String = ""
    @State private var showImportAlert: Bool = false
    
    // ✅ Export State (Folder URL)
    @State private var exportFolderURL: URL?
    @State private var isExportReady: Bool = false
    
    // Purchase
    @State private var showPurchaseOverlay = false
    
    // Reset Confirmations
    @State private var showPurgeConfirm1 = false
    @State private var showPurgeConfirm2 = false
    
    // Maintenance
    @State private var showMaintenanceAlert = false
    @State private var maintenanceMessage = ""
    
    private let orbSize: CGFloat = 70
    
    private var missingBoxArtCount: Int {
        allKits.filter { $0.imageURLString == nil || $0.imageURLString!.isEmpty }.count
    }
    private var missingPhotoCount: Int {
        allKits.filter { $0.statusValue == 4 && ($0.completedImageURLString == nil || $0.completedImageURLString!.isEmpty) }.count
    }
    
    private var itemManagementSubLabel: String {
        return "登録データの編集・一括操作\nTOTAL UNITS: \(allKits.count)"
    }
    
    private var areKeysReady: Bool {
        !googleApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !googleSearchEngineId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
                .onTapGesture {
                    withAnimation { isPresented = false }
                }
            
            // コンテンツ本体
            settingsContent
            
            if showItemManagement {
                ItemManagementView(isPresented: $showItemManagement)
                    .transition(.move(edge: .trailing))
                    .zIndex(20)
            }
            
            if showMissingImages {
                MissingImagesView(isPresented: $showMissingImages)
                    .transition(.move(edge: .trailing))
                    .zIndex(20)
            }
        }
        // MARK: - Modifiers
        .fileImporter(
            isPresented: $showFileImport,
            allowedContentTypes: [.commaSeparatedText, .image, .folder],
            allowsMultipleSelection: true
        ) { result in
            handleImport(result: result)
        }
        .alert("メッセージ", isPresented: $showImportAlert) {
            Button("OK") { }
        } message: {
            Text(importMessage)
        }
        .alert("ストレージ整理", isPresented: $showMaintenanceAlert) {
            Button("OK") { }
        } message: { Text(maintenanceMessage) }
        
        .alert("⚠️テスト用：全データ削除", isPresented: $showPurgeConfirm1) {
            Button("キャンセル", role: .cancel) { }
            Button("次へ", role: .destructive) { showPurgeConfirm2 = true }
        } message: {
            Text("現在の全データ（\(allKits.count)件）をデータベースから完全に消去します。")
        }
        .alert("⚠️最終警告", isPresented: $showPurgeConfirm2) {
            Button("キャンセル", role: .cancel) { }
            Button("今すぐ全削除を実行", role: .destructive) {
                DataTransferManager.shared.clearAllData(modelContext: modelContext)
            }
        } message: {
            Text("ITEM MANAGEMENTが開けない場合の緊急リセットです。本当によろしいですか？")
        }
        .overlay {
            if showPurchaseOverlay {
                PurchaseOverlay(isPresented: $showPurchaseOverlay)
            }
        }
        .onAppear {
            prepareBackupData()
        }
        .onChange(of: allKits.count) { _, _ in
            prepareBackupData()
        }
    }
    
    // MARK: - Separated Content View
    private var settingsContent: some View {
        VStack(spacing: 0) {
            headerView
            
            ScrollView {
                VStack(spacing: 24) {
                    themeSection
                    Divider().background(Color.white.opacity(0.2))
                    databaseSection
                    Divider().background(Color.white.opacity(0.2))
                    godModeSection
                    Divider().background(Color.white.opacity(0.2))
                    systemInfoSection
                }
                .padding(.vertical, 20)
            }
        }
        .frame(maxWidth: 500, maxHeight: 800)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(20)
        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.3), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1)
        )
        .padding(20)
    }
}
// SettingsOverlay.swift V72
// PART 2 OF 2

// MARK: - Subviews extension
extension SettingsOverlay {
    
    private var headerView: some View {
        HStack {
            Image("setting")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(themeManager.currentTheme.mainColor)
            
            Text("SYSTEM TERMINAL")
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            Button {
                withAnimation { isPresented = false }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }
    
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("THEME COLOR")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(AppTheme.allCases) { theme in
                        colorButton(theme)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 20)
            }
        }
        .padding(.horizontal)
    }
    
    private var databaseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("DATABASE OPERATIONS")
            
            HStack(spacing: 8) {
                SettingsRow(
                    icon: "list.bullet.rectangle.portrait",
                    label: "ITEM MANAGEMENT",
                    subLabel: itemManagementSubLabel,
                    isLocked: false,
                    action: {
                        LocalHaptics.tap()
                        showItemManagement = true
                    }
                )
                
                Button {
                    LocalHaptics.error()
                    showPurgeConfirm1 = true
                } label: {
                    VStack {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white)
                        Text("RESET")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 50, height: 60)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                }
            }
            
            SettingsRow(
                icon: "externaldrive.badge.minus",
                label: "STORAGE MAINTENANCE",
                subLabel: "不要な画像ファイルを削除",
                isLocked: false,
                action: {
                    LocalHaptics.select()
                    maintenanceMessage = DataTransferManager.shared.performStorageCleanup(modelContext: modelContext)
                    showMaintenanceAlert = true
                }
            )
            
            SettingsRow(
                icon: "photo.badge.plus",
                label: "MISSING LINKS",
                subLabel: "未取得画像: BOX \(missingBoxArtCount) / COMPLETE \(missingPhotoCount)",
                isLocked: !storeManager.isCommander,
                action: {
                    checkCommanderAccess { showMissingImages = true }
                }
            )
            
            // ✅ EXPORT ROW: デザイン完全一致 + 透明ShareLinkオーバーレイ (フォルダ出力版)
            ZStack {
                SettingsRow(
                    icon: "square.and.arrow.up",
                    label: "DATA EXPORT (BACKUP)",
                    subLabel: "画像込みの完全バックアップを出力",
                    isLocked: false,
                    action: { }
                )
                
                if isExportReady, let folderURL = exportFolderURL {
                    ShareLink(item: folderURL) {
                        Color.clear
                            .contentShape(Rectangle())
                    }
                }
            }
            
            SettingsRow(
                icon: "square.and.arrow.down",
                label: "DATA IMPORT (RESTORE)",
                subLabel: "バックアップ内の全ファイルを選択",
                isLocked: !storeManager.isCommander,
                action: {
                    checkCommanderAccess { showFileImport = true }
                }
            )
        }
        .padding(.horizontal)
    }
    
    // ✅ フォルダ（非ZIP）での書き出し準備
    private func prepareBackupData() {
        Task {
            // 1. 新規アイテムを確実に含めるための強制保存
            try? modelContext.save()
            
            // 2. フォルダ形式で準備 (DataTransferManager.exportDataV2 はフォルダURLを返す想定)
            if let folderURL = await DataTransferManager.shared.exportDataV2(kits: allKits) {
                // ZIP化処理を削除し、そのままURLをセット
                self.exportFolderURL = folderURL
                self.isExportReady = true
            }
        }
    }
    
    private var godModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("GOD MODE (GOOGLE API)")
            
            VStack(alignment: .leading, spacing: 16) {
                Toggle(isOn: $isGodModeEnabled) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(isGodModeEnabled ? .yellow : .gray)
                        Text(isGodModeEnabled ? "GOD MODE: ACTIVE" : "GOD MODE: INACTIVE")
                            .fontWeight(.bold)
                            .foregroundStyle(isGodModeEnabled ? themeManager.currentTheme.mainColor : .secondary)
                    }
                }
                .tint(themeManager.currentTheme.mainColor)
                .disabled(!areKeysReady)
                
                if areKeysReady {
                    Text("SYSTEM ACTIVATED")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if !isGodModeEnabled {
                        Text("スイッチをONにして機能を有効化してください。")
                            .font(.caption2).foregroundStyle(.gray)
                    }
                } else {
                    Text("SYSTEM LOCKED: 有効化するにはAPI KEYとENGINE IDの両方を入力してください。")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .fontWeight(.bold)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("API KEY")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.leading, 4)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(googleApiKey.isEmpty ? .gray : themeManager.currentTheme.mainColor)
                            .frame(width: 20)
                        
                        SecureField("", text: $googleApiKey, prompt: Text("ENTER API KEY...").foregroundStyle(.gray))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.primary)
                        
                        Button {
                            if let content = UIPasteboard.general.string {
                                googleApiKey = content.trimmingCharacters(in: .whitespacesAndNewlines)
                                LocalHaptics.select()
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard.fill").font(.system(size: 14)).padding(10).background(themeManager.currentTheme.mainColor.opacity(0.2)).cornerRadius(6)
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.mainColor.opacity(googleApiKey.isEmpty ? 0.3 : 1.0), lineWidth: 1.5))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("SEARCH ENGINE ID (CX)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.leading, 4)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundStyle(googleSearchEngineId.isEmpty ? .gray : themeManager.currentTheme.mainColor)
                            .frame(width: 20)
                        
                        SecureField("", text: $googleSearchEngineId, prompt: Text("ENTER ENGINE ID...").foregroundStyle(.gray))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.primary)
                        
                        Button {
                            if let content = UIPasteboard.general.string {
                                var cleanID = content.trimmingCharacters(in: .whitespacesAndNewlines)
                                if cleanID.hasPrefix("cx=") { cleanID = String(cleanID.dropFirst(3)) }
                                googleSearchEngineId = cleanID
                                LocalHaptics.select()
                            }
                        } label: {
                            Image(systemName: "doc.on.clipboard.fill").font(.system(size: 14)).padding(10).background(themeManager.currentTheme.mainColor.opacity(0.2)).cornerRadius(6)
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.mainColor.opacity(googleSearchEngineId.isEmpty ? 0.3 : 1.0), lineWidth: 1.5))
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }
    
    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SYSTEM INFO")
            HStack {
                Text("Plan").foregroundStyle(.gray)
                Spacer()
                if storeManager.isCommander {
                    Text("Commander Pack").foregroundStyle(.yellow).fontWeight(.bold)
                } else if storeManager.isPremium {
                    Text("Standard Plan").foregroundStyle(.green).fontWeight(.bold)
                } else {
                    Text(allKits.count > 10 ? "Free (Limit Exceeded)" : "Free (Trial)")
                        .foregroundStyle(allKits.count > 10 ? .orange : Color(UIColor.label))
                }
            }
            .font(.system(size: 14, design: .monospaced))
            
            Text("Plalog v1.0.0")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 20)
        }
        .padding(.horizontal)
    }
    
    private func checkCommanderAccess(action: () -> Void) {
        if storeManager.isCommander {
            LocalHaptics.tap()
            action()
        } else {
            LocalHaptics.error()
            withAnimation {
                showPurchaseOverlay = true
            }
        }
    }
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.8))
    }
    
    private func colorButton(_ theme: AppTheme) -> some View {
        Button {
            LocalHaptics.select()
            themeManager.setTheme(theme)
        } label: {
            Circle()
            .fill(theme.mainColor)
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                .stroke(Color.white, lineWidth: themeManager.currentTheme == theme ? 3 : 0)
            )
            .shadow(color: theme.mainColor.opacity(0.5), radius: 6, x: 0, y: 3)
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            let (count, log) = DataTransferManager.shared.importDataBatch(urls: urls, modelContext: modelContext)
            importMessage = "インポート完了: \(count)件\n\n\(log)"
            showImportAlert = true
            
        case .failure(let error):
            importMessage = "エラー: \(error.localizedDescription)"
            showImportAlert = true
        }
    }
}
