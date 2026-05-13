// SettingsOverlay.swift V72
// PART 1 OF 2
// 1. バージョン管理ルールに基づき更新 (V71 -> V72)
// 2. 修正点:
//    - ZIP圧縮プロセスを完全に撤廃。フォルダ（URL）を直接ShareLinkに渡す方式に変更。
//    - 新規アイテムが漏れる問題に対し、prepareBackupData実行直前に `modelContext.save()` を強制。
//    - UIの不変性ルールに基づき、ZStack + 透明ShareLinkのデザインを1ピクセルも変えずに維持。
// 3. 全文差し替え・分割送付ルール適用

import SwiftUI
import StoreKit
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
    @ObservedObject private var langManager = LanguageManager.shared
    
    // ✅ GOD MODE Settings
    // ✅ GOD MODE Settings (Moved to Keychain)
    @State private var googleApiKey: String = ""
    @State private var googleSearchEngineId: String = ""
    @AppStorage("isGodModeEnabled") private var isGodModeEnabled: Bool = false
    
    // UI Flags
    @State private var showFileImport = false
    @State private var showItemManagement = false
    @State private var showMissingImages = false
    @State private var importMessage: String = ""
    @State private var showImportAlert: Bool = false
    @State private var showP2PSync = false
    
    // ✅ Export State (Folder URL)
    @State private var exportFolderURL: URL?
    @State private var isExportReady: Bool = false
    
    // ✅ Cloud Storage Settings
    @AppStorage("useCloudStorage") private var useCloudStorage: Bool = false
    @State private var showMigrationConfirm: Bool = false
    @State private var migrationStatus: String = ""
    
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
            
            if showP2PSync {
                P2PSyncView(isPresented: $showP2PSync)
                    .transition(.opacity)
                    .zIndex(30)
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
        .alert("クラウド移行", isPresented: $showMigrationConfirm) {
            Button("キャンセル", role: .cancel) { }
            Button("実行", role: .destructive) {
                Task {
                    let log = await DataTransferManager.shared.migrateImagesToAlbum(modelContext: modelContext)
                    importMessage = log
                    showImportAlert = true
                }
            }
        } message: {
            Text("アプリ内の画像を「PLALOG」アルバムにコピーし、ローカルファイルを削除します。よろしいですか？\n※この操作は取り消せません")
        }
        .overlay {
            if showPurchaseOverlay {
                PurchaseOverlay(isPresented: $showPurchaseOverlay)
            }
        }
        .onAppear {
            prepareBackupData()
            // Load keys from Keychain
            googleApiKey = KeychainHelper.shared.read(service: "com.hiro.pralog", account: "googleApiKey") ?? ""
            googleSearchEngineId = KeychainHelper.shared.read(service: "com.hiro.pralog", account: "googleSearchEngineId") ?? ""
        }
        .onChange(of: googleApiKey) {
            KeychainHelper.shared.save(googleApiKey, service: "com.hiro.pralog", account: "googleApiKey")
        }
        .onChange(of: googleSearchEngineId) {
            KeychainHelper.shared.save(googleSearchEngineId, service: "com.hiro.pralog", account: "googleSearchEngineId")
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
                    languageSection
                    Divider().background(Color.white.opacity(0.2))
                    themeSection
                    Divider().background(Color.white.opacity(0.2))
                    libraryManagementSection
                    Divider().background(Color.white.opacity(0.2))
                    cloudStorageSection // ✅ NEW
                    Divider().background(Color.white.opacity(0.2))
                    syncBackupSection
                    Divider().background(Color.white.opacity(0.2))
                    databaseStoreSection // ✅ NEW
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
            
            Text(langManager.t(.settings_title))
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
            sectionHeader(langManager.t(.settings_theme))
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
    
    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(langManager.t(.settings_language))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(AppLanguage.allCases) { lang in
                        Button {
                            LocalHaptics.select()
                            withAnimation {
                                langManager.currentLanguage = lang
                            }
                        } label: {
                            HStack {
                                Text(lang.flag)
                                Text(lang.displayName)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(langManager.currentLanguage == lang ? themeManager.currentTheme.mainColor : Color.white.opacity(0.1))
                            .foregroundStyle(langManager.currentLanguage == lang ? Color.black : Color.white)
                            .cornerRadius(8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(themeManager.currentTheme.mainColor, lineWidth: langManager.currentLanguage == lang ? 0 : 1))
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 10)
            }
            
            Text(langManager.t(.settings_language_note))
                .font(.caption2.monospaced())
                .foregroundStyle(.gray)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal)
    }
    
    private var libraryManagementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("LIBRARY MANAGEMENT")
            
            HStack(spacing: 8) {
                SettingsRow(
                    icon: "list.bullet.rectangle.portrait",
                    label: langManager.t(.lib_manage_title),
                    subLabel: langManager.t(.lib_manage_desc),
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
                        Text(langManager.t(.lib_reset_btn))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 50, height: 60)
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(12)
                }
            }
            
            SettingsRow(
                icon: "photo.badge.plus",
                label: langManager.t(.lib_missing_title),
                subLabel: "\(langManager.t(.lib_missing_desc_pre))\(missingBoxArtCount)\(langManager.t(.lib_missing_desc_post))\(missingPhotoCount)",
                isLocked: !storeManager.isCommander,
                action: {
                    checkCommanderAccess { showMissingImages = true }
                }
            )
            
            SettingsRow(
                icon: "wrench.and.screwdriver.fill",
                label: langManager.t(.lib_repair_title),
                subLabel: langManager.t(.lib_repair_desc),
                isLocked: false,
                action: {
                    LocalHaptics.select()
                    maintenanceMessage = "画像を検証中...\n(ライブラリのサイズにより数分かかる場合があります)"
                    showMaintenanceAlert = true
                    
                    // Fetch data on Main Actor
                    let descriptor = FetchDescriptor<Kit>()
                    let kits = (try? modelContext.fetch(descriptor)) ?? []
                    var kitData: [(image: String?, completed: String?)] = []
                    for kit in kits {
                        kitData.append((image: kit.imageURLString, completed: kit.completedImageURLString))
                        // Include Build Log Images
                        for log in (kit.buildLogs ?? []) {
                            kitData.append((image: log.imagePath, completed: nil))
                        }
                    }
                    
                    Task {
                        // Run heavy task in background
                        let result = await DataTransferManager.shared.repairBrokenImages(kitData: kitData)
                        await MainActor.run {
                            maintenanceMessage = result
                        }
                    }
                }
            )
            
            SettingsRow(
                icon: "externaldrive.badge.minus",
                label: langManager.t(.lib_storage_title),
                subLabel: langManager.t(.lib_storage_desc),
                isLocked: false,
                action: {
                    LocalHaptics.select()
                    maintenanceMessage = DataTransferManager.shared.performStorageCleanup(modelContext: modelContext)
                    showMaintenanceAlert = true
                }
            )
        }
        .padding(.horizontal)
    }
    
    private var cloudStorageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("CLOUD STORAGE (iCloud)")
            
            Toggle(isOn: $useCloudStorage) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(langManager.t(.cloud_low_data)).font(.system(size: 16, weight: .medium, design: .monospaced))
                    Text(langManager.t(.cloud_low_data_desc)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(themeManager.currentTheme.mainColor)
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            
            if useCloudStorage {
                SettingsRow(
                    icon: "arrow.up.doc.on.clipboard",
                    label: langManager.t(.cloud_migrate_title),
                    subLabel: langManager.t(.cloud_migrate_desc),
                    isLocked: false,
                    action: {
                        LocalHaptics.select()
                        showMigrationConfirm = true
                    }
                )
                
                // ✅ Manual Image Migration Trigger
                SettingsRow(
                    icon: "photo.badge.arrow.down",
                    label: "MIGRATE IMAGES",
                    subLabel: "Convert local images to CloudKit",
                    isLocked: false,
                    action: {
                        LocalHaptics.select()
                        maintenanceMessage = "Migration Started..."
                        showMaintenanceAlert = true
                        Task {
                            let result = await DataTransferManager.shared.migrateImagesToCloudKit(modelContext: modelContext)
                            await MainActor.run { 
                                maintenanceMessage = result
                                showMaintenanceAlert = true
                            }
                        }
                    }
                )
            }
        }
        .padding(.horizontal)
    }
    
    private var syncBackupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("SYNC & BACKUP")
            
            // ✅ DIRECT SYNC (NEW)
            SettingsRow(
                icon: "arrow.triangle.2.circlepath",
                label: langManager.t(.sync_direct_title),
                subLabel: langManager.t(.sync_direct_desc),
                isLocked: false,
                action: {
                    LocalHaptics.select()
                    withAnimation { showP2PSync = true }
                }
            )
            
            ZStack {
                SettingsRow(
                    icon: "square.and.arrow.up",
                    label: langManager.t(.sync_export_title),
                    subLabel: langManager.t(.sync_export_desc),
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
                label: langManager.t(.sync_import_title),
                subLabel: langManager.t(.sync_import_desc),
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
            sectionHeader(langManager.t(.settings_godmode))
            
            VStack(alignment: .leading, spacing: 4) {
                Toggle(isOn: $isGodModeEnabled) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(isGodModeEnabled ? .yellow : .gray)
                        Text(isGodModeEnabled ? langManager.t(.god_active) : langManager.t(.god_inactive))
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
                        Text(langManager.t(.god_enable_guide))
                            .font(.caption2).foregroundStyle(.gray)
                    }
                } else {
                    Text(langManager.t(.god_locked_guide))
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .fontWeight(.bold)
                }
                
                Divider().background(Color.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(langManager.t(.god_api_key))
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.leading, 4)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .foregroundStyle(googleApiKey.isEmpty ? .gray : themeManager.currentTheme.mainColor)
                            .frame(width: 20)
                        
                        SecureField("", text: $googleApiKey, prompt: Text(langManager.t(.god_enter_key)).foregroundStyle(.gray))
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
                    Text(langManager.t(.god_engine_id))
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.leading, 4)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundStyle(googleSearchEngineId.isEmpty ? .gray : themeManager.currentTheme.mainColor)
                            .frame(width: 20)
                        
                        SecureField("", text: $googleSearchEngineId, prompt: Text(langManager.t(.god_enter_id)).foregroundStyle(.gray))
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
    
    // Database Logic Helper
    private func toggleDatabase(key: String, enabled: Bool) {
        // Haptic
        if enabled { LocalHaptics.success() } else { LocalHaptics.select() }
        
        // Update UserDefaults
        UserDefaults.standard.set(enabled, forKey: key)
        
        // Reload Data
        DispatchQueue.global(qos: .userInitiated).async {
            CSVDataManager.shared.reloadAll()
        }
    }
    
    private var databaseStoreSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(langManager.t(.settings_dbstore))
            
            // TAMIYA
            DatabaseRow(
                id: "com.hiro.pralog.db.tamiya",
                title: "MILITARY (TAMIYA)",
                desc: langManager.t(.db_military_desc),
                icon: "shield.fill",
                color: Color(red: 0.8, green: 0.2, blue: 0.2) // Tamiya Red
            )
            
            // AOSHIMA
            DatabaseRow(
                id: "com.hiro.pralog.db.aoshima",
                title: "CARS (AOSHIMA)",
                desc: langManager.t(.db_car_desc),
                icon: "car.fill",
                color: .blue
            )
            
            // KOTOBUKIYA
            DatabaseRow(
                id: "com.hiro.pralog.db.kotobukiya",
                title: "CHARACTER (KOTOBUKIYA)",
                desc: "Frame Arms Girl, Megami Device",
                icon: "figure.walk",
                color: .green
            )
            
            // HASEGAWA
            DatabaseRow(
                id: "com.hiro.pralog.db.hasegawa",
                title: "AIRCRAFT (HASEGAWA)",
                desc: "Detailed aircraft kits",
                icon: "airplane",
                color: .yellow
            )
            
            // FUJIMI
            DatabaseRow(
                id: "com.hiro.pralog.db.fujimi",
                title: "MODELS (FUJIMI)",
                desc: "Ships & Cars",
                icon: "ferry.fill",
                color: .cyan
            )
            
            // FINE MOLDS
            DatabaseRow(
                id: "com.hiro.pralog.db.finemolds",
                title: "FINE MOLDS",
                desc: "Ghibli & Military",
                icon: "star.fill",
                color: .orange
            )
            
            // MAX FACTORY
            DatabaseRow(
                id: "com.hiro.pralog.db.maxfactory",
                title: "DOUGRAM (MAX FACTORY)",
                desc: "Combat Armors MAX",
                icon: "circle.grid.hex.fill",
                color: .purple
            )
            
            // VOLKS
            DatabaseRow(
                id: "com.hiro.pralog.db.volks",
                title: "MODELS (VOLKS)",
                desc: "IMS (FSS), SWS",
                icon: "v.circle.fill",
                color: .black
            )
        }
        .padding(.horizontal)
    }
    
    // Generic Database Row (Toggle)
    struct DatabaseRow: View {
        let id: String
        let title: String
        let desc: String
        let icon: String
        let color: Color
        
        @AppStorage var isEnabled: Bool
        
        init(id: String, title: String, desc: String, icon: String, color: Color) {
            self.id = id
            self.title = title
            self.desc = desc
            self.icon = icon
            self.color = color
            self._isEnabled = AppStorage(wrappedValue: false, id)
        }
        
        var body: some View {
            Toggle(isOn: $isEnabled) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(color.opacity(0.1))
                        Image(systemName: icon).foregroundStyle(color)
                    }.frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 14, weight: .bold))
                        Text(desc).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .tint(ThemeManager.shared.currentTheme.mainColor)
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .onChange(of: isEnabled) { _, newValue in
                // Trigger Reload
                if newValue { LocalHaptics.success() } else { LocalHaptics.select() }
                DispatchQueue.global(qos: .userInitiated).async {
                    CSVDataManager.shared.reloadAll()
                }
            }
        }
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
