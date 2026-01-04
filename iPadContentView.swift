// iPadContentView.swift V51
// PART 1 OF 2
// 1. バージョン管理ルールに基づき更新 (V50 -> V51)
// 2. 修正点: ロック解除時の演出を強化
//    - キーが揃った際の表示を「SYSTEM ACTIVATED」(金色) に変更
//    - メインView構造は維持
// 3. 全文差し替え・分割送付ルール適用

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct iPadContentView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Query(sort: \Kit.createdDate, order: .reverse) private var allKits: [Kit]
    
    @State private var selectedCategory: SidebarItem? = .all
    @State private var selectedKit: Kit? = nil
    @State private var showAddSheet: Bool = false

    enum SidebarItem: String, CaseIterable, Identifiable {
        case all = "全てのキット"
        case wish = "いつか欲しい"
        case reservation = "予約済み"
        case stock = "積みプラ"
        case inProgress = "制作中"
        case complete = "完成"
        case settings = "設定"
        
        var id: String { rawValue }
        
        var iconName: String {
            switch self {
            case .all: return "square.grid.2x2"
            case .wish: return "wish"
            case .reservation: return "reservation"
            case .stock: return "stock"
            case .inProgress: return "inprogress"
            case .complete: return "complete"
            case .settings: return "setting"
            }
        }
        
        var isSystemImage: Bool {
            switch self {
            case .all: return true
            default: return false
            }
        }
        
        var statusValue: Int? {
            switch self {
            case .wish: return 0
            case .reservation: return 1
            case .stock: return 2
            case .inProgress: return 3
            case .complete: return 4
            default: return nil
            }
        }
    }

    var body: some View {
        ZStack {
            NavigationSplitView {
                // MARK: - Left Column (Sidebar)
                ZStack(alignment: .topLeading) {
                    Color(uiColor: .systemBackground).ignoresSafeArea()
                    
                    VStack(alignment: .leading, spacing: 0) {
                        List(selection: $selectedCategory) {
                            Section("Hangar") {
                                ForEach(SidebarItem.allCases.filter { $0 != .settings }, id: \.self) { item in
                                    NavigationLink(value: item) {
                                        HStack {
                                            Label {
                                                Text(item.rawValue)
                                            } icon: {
                                                if item.isSystemImage {
                                                    Image(systemName: item.iconName).frame(width: 24, height: 24)
                                                } else {
                                                    Image(item.iconName).resizable().scaledToFit().frame(width: 24, height: 24)
                                                }
                                            }
                                            Spacer()
                                            Text("\(count(for: item))")
                                                .font(.caption).foregroundStyle(.secondary)
                                                .padding(.horizontal, 8).background(Color(uiColor: .secondarySystemBackground)).clipShape(Capsule())
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                            
                            Section("System") {
                                NavigationLink(value: SidebarItem.settings) {
                                    Label {
                                        Text("設定")
                                    } icon: {
                                        if SidebarItem.settings.isSystemImage {
                                            Image(systemName: SidebarItem.settings.iconName).frame(width: 24, height: 24)
                                        } else {
                                            Image(SidebarItem.settings.iconName).resizable().scaledToFit().frame(width: 24, height: 24)
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.sidebar)
                        .padding(.top, 10)
                        
                        VStack(alignment: .leading) {
                            Divider()
                            Button(action: {
                                LocalHaptics.select()
                                showAddSheet = true
                            }) {
                                HStack {
                                    Image("add")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 44, height: 44)
                                        .foregroundStyle(themeManager.currentTheme.mainColor)
                                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                    
                                    Text("NEW ITEM")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.secondary)
                                        .padding(.leading, 8)
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color(uiColor: .secondarySystemBackground).opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .navigationSplitViewColumnWidth(min: 250, ideal: 280, max: 300)
                
            } detail: {
                if let category = selectedCategory {
                    if category == .settings {
                        iPadSettingsView()
                    } else {
                        KitGalleryView(
                            kits: filteredKits(for: category),
                            title: category.rawValue,
                            onSelect: { kit in
                                withAnimation { selectedKit = kit }
                            }
                        )
                    }
                } else {
                    Text("Select Category")
                }
            }
            .fullScreenCover(isPresented: $showAddSheet) {
                AddRegistrationFlowOverlay(isPresented: $showAddSheet)
            }
            
            if selectedKit != nil {
                KitDetailOverlay(kit: $selectedKit)
                    .zIndex(1000)
            }
        }
    }
    
    private func filteredKits(for item: SidebarItem) -> [Kit] {
        if item == .all { return allKits }
        guard let status = item.statusValue else { return [] }
        return allKits.filter { $0.statusValue == status }
    }
    
    private func count(for item: SidebarItem) -> Int {
        return filteredKits(for: item).count
    }
}
// iPadContentView.swift V51
// PART 2 OF 2
// 修正点: GOD MODEロック解除時のテキストを「SYSTEM ACTIVATED」、色を金色に変更

// MARK: - iPad Settings View
struct iPadSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var storeManager = StoreKitManager.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var allKits: [Kit]
    
    // GOD MODE: Google API Settings
    @AppStorage("googleApiKey") private var googleApiKey: String = ""
    @AppStorage("googleSearchEngineId") private var googleSearchEngineId: String = ""
    @AppStorage("isGodModeEnabled") private var isGodModeEnabled: Bool = false
    
    @State private var showItemManagement = false
    @State private var showMissingImages = false
    @State private var showCSVImport = false
    @State private var showImportAlert = false
    @State private var importMessage = ""
    @State private var exportURL: URL?
    @State private var showShareSheet = false
    @State private var showPurchaseOverlay = false
    
    @State private var showMaintenanceAlert = false
    @State private var maintenanceMessage = ""
    @State private var showPurgeConfirm1 = false
    @State private var showPurgeConfirm2 = false
    
    private let privacyURL = URL(string: "https://example.com")!
    
    private var missingBoxArtCount: Int {
        allKits.filter { $0.imageURLString == nil || $0.imageURLString!.isEmpty }.count
    }
    private var missingPhotoCount: Int {
        allKits.filter { $0.statusValue == 4 && ($0.completedImageURLString == nil || $0.completedImageURLString!.isEmpty) }.count
    }
    
    // キーが両方とも入力されているか判定
    private var areKeysReady: Bool {
        !googleApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !googleSearchEngineId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        List {
            themeSection
            operationsSection
            godModeSection
            systemInfoSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("SYSTEM TERMINAL")
        .sheet(isPresented: $showItemManagement) { ItemManagementView(isPresented: $showItemManagement) }
        .sheet(isPresented: $showMissingImages) { MissingImagesView(isPresented: $showMissingImages) }
        .overlay { if showPurchaseOverlay { PurchaseOverlay(isPresented: $showPurchaseOverlay) } }
        
        .alert("ストレージ整理", isPresented: $showMaintenanceAlert) {
            Button("OK") { }
        } message: { Text(maintenanceMessage) }
        
        .alert("⚠️テスト用：全データ削除", isPresented: $showPurgeConfirm1) {
            Button("キャンセル", role: .cancel) { }
            Button("次へ", role: .destructive) { showPurgeConfirm2 = true }
        } message: { Text("現在の全データ（\(allKits.count)件）をデータベースから完全に消去します。") }
        .alert("⚠️最終警告", isPresented: $showPurgeConfirm2) {
            Button("キャンセル", role: .cancel) { }
            Button("今すぐ全削除を実行", role: .destructive) {
                DataTransferManager.shared.clearAllData(modelContext: modelContext)
            }
        } message: { Text("ITEM MANAGEMENTが開けない場合の緊急リセットです。本当によろしいですか？") }
        
        .fileImporter(
            isPresented: $showCSVImport,
            allowedContentTypes: [.commaSeparatedText, .folder, .zip, .image],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                let (_, log) = DataTransferManager.shared.importDataBatch(urls: urls, modelContext: modelContext)
                importMessage = log
                showImportAlert = true
            case .failure(let error):
                importMessage = "エラー: \(error.localizedDescription)"
                showImportAlert = true
            }
        }
        .alert("インポート結果", isPresented: $showImportAlert) { Button("OK") { } } message: { Text(importMessage) }
        .sheet(isPresented: $showShareSheet) { if let url = exportURL { ShareSheet(activityItems: [url]) } }
    }
    
    private var themeSection: some View {
        Section("THEME COLOR") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            LocalHaptics.select()
                            themeManager.setTheme(theme)
                        } label: {
                            Circle().fill(theme.mainColor).frame(width: 44, height: 44)
                                .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: themeManager.currentTheme == theme ? 4 : 0))
                                .shadow(color: theme.mainColor.opacity(0.4), radius: 4, x: 0, y: 2)
                        }.buttonStyle(.plain)
                    }
                }.padding(.vertical, 8).padding(.horizontal, 16)
            }
        }
    }
    
    private var operationsSection: some View {
        Section("DATABASE OPERATIONS") {
            HStack(spacing: 12) {
                Button { showItemManagement = true } label: {
                    VStack(alignment: .leading) {
                        Text("ITEM MANAGEMENT").font(.headline)
                        Text("登録データの編集・一括操作\nTOTAL UNITS: \(allKits.count)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { LocalHaptics.error(); showPurgeConfirm1 = true } label: {
                    VStack {
                        Image(systemName: "trash.fill").font(.title3).foregroundStyle(.white)
                        Text("RESET").font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
                    }.frame(width: 54, height: 54).background(Color.red.opacity(0.8)).cornerRadius(12)
                }.buttonStyle(.plain)
            }
            
            Button {
                LocalHaptics.select()
                maintenanceMessage = DataTransferManager.shared.performStorageCleanup(modelContext: modelContext)
                showMaintenanceAlert = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text("STORAGE MAINTENANCE").font(.headline)
                            Text("不要な画像ファイルを検出し、削除して容量を解放").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "externaldrive.badge.minus").foregroundStyle(themeManager.currentTheme.mainColor) }
                    Spacer()
                }
            }
            
            Button { checkCommanderAccess { showMissingImages = true } } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text("MISSING LINKS").font(.headline)
                            Text("未取得画像: BOX \(missingBoxArtCount) / COMPLETE \(missingPhotoCount)").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "photo.badge.plus").foregroundStyle(themeManager.currentTheme.mainColor) }
                    Spacer()
                    if !storeManager.isCommander { Image(systemName: "lock.fill").foregroundStyle(.yellow) }
                }
            }

            Button { checkCommanderAccess { runExport() } } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text("DATA EXPORT (BACKUP)").font(.headline)
                            Text("画像込みの完全バックアップを出力").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "square.and.arrow.up").foregroundStyle(themeManager.currentTheme.mainColor) }
                    Spacer()
                    if !storeManager.isCommander { Image(systemName: "lock.fill").foregroundStyle(.yellow) }
                }
            }
            
            Button { checkCommanderAccess { showCSVImport = true } } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text("DATA IMPORT (RESTORE)").font(.headline)
                            Text("フォルダ内の全ファイル(CSV+画像)を選択").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "square.and.arrow.down").foregroundStyle(themeManager.currentTheme.mainColor) }
                    Spacer()
                    if !storeManager.isCommander { Image(systemName: "lock.fill").foregroundStyle(.yellow) }
                }
            }
        }
    }
    
    // ✅ GOD MODE SECTION: デザイン強化 & 金色ACTIVATED演出
    private var godModeSection: some View {
        Section("GOD MODE SETUP (GOOGLE API)") {
            VStack(alignment: .leading, spacing: 16) {
                // Toggle (鍵がないと押せない)
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
                
                // 状態表示テキスト
                if areKeysReady {
                    // ✅ 金色で SYSTEM ACTIVATED
                    Text("SYSTEM ACTIVATED")
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    
                    if !isGodModeEnabled {
                        Text("スイッチをONにして機能を有効化してください。")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text("SYSTEM LOCKED: 有効化するにはAPI KEYとENGINE IDの両方を入力してください。")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .fontWeight(.bold)
                }
                
                Divider()
                
                // 1. API Key Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("API KEY")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.leading, 4)
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(googleApiKey.isEmpty ? .gray : themeManager.currentTheme.mainColor)
                            .frame(width: 24)
                        
                        SecureField("", text: $googleApiKey, prompt: Text("ENTER API KEY...").foregroundStyle(.gray))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.primary)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.mainColor.opacity(googleApiKey.isEmpty ? 0.3 : 1.0), lineWidth: 1.5)
                    )
                }
                
                // 2. Search Engine ID (CX) Field
                VStack(alignment: .leading, spacing: 4) {
                    Text("SEARCH ENGINE ID (CX)")
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.leading, 4)
                    
                    HStack {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundStyle(googleSearchEngineId.isEmpty ? .gray : themeManager.currentTheme.mainColor)
                            .frame(width: 24)
                        
                        SecureField("", text: $googleSearchEngineId, prompt: Text("ENTER ENGINE ID...").foregroundStyle(.gray))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(Color.primary)
                    }
                    .padding(12)
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeManager.currentTheme.mainColor.opacity(googleSearchEngineId.isEmpty ? 0.3 : 1.0), lineWidth: 1.5)
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var systemInfoSection: some View {
        Section("SYSTEM INFO") {
            HStack {
                Text("Plan"); Spacer()
                if storeManager.isCommander { Text("Commander Pack").foregroundStyle(.yellow).fontWeight(.bold) }
                else if storeManager.isPremium { Text("Standard Plan").foregroundStyle(.green).fontWeight(.bold) }
                else { Text(allKits.count > 10 ? "Free (Limit Exceeded)" : "Free (Trial)").foregroundStyle(allKits.count > 10 ? .orange : .secondary) }
            }
            HStack { Text("Version"); Spacer(); Text("Plalog v1.0.0").foregroundStyle(.secondary) }
            Link("Privacy Policy", destination: privacyURL)
        }
    }
    
    private func checkCommanderAccess(action: () -> Void) {
        if storeManager.isCommander { action() }
        else { withAnimation { showPurchaseOverlay = true } }
    }
    
    private func runExport() {
        if let url = DataTransferManager.shared.exportDataV2(kits: allKits) {
            exportURL = url
            showShareSheet = true
        }
    }
}

// MARK: - Kit Gallery
struct KitGalleryView: View {
    let kits: [Kit]
    let title: String
    var onSelect: (Kit) -> Void
    let columns = [GridItem(.adaptive(minimum: 180, maximum: 220), spacing: 20)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(title).font(.largeTitle).fontWeight(.bold)
                    Spacer()
                    Text("\(kits.count) ITEMS").font(.headline).foregroundStyle(.secondary)
                }.padding(.horizontal).padding(.top, 20)
                
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(kits) { kit in
                        iPadKitCard(kit: kit).onTapGesture { LocalHaptics.tap(); onSelect(kit) }
                    }
                }.padding(.horizontal)
            }
        }.background(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - iPad Kit Card
struct iPadKitCard: View {
    let kit: Kit
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Color.gray.opacity(0.1)
                    
                    let isUserChoiceMyPhoto = (kit.displayModeValue == 1)
                    let hasUserPhoto = (kit.completedImageURLString != nil && !kit.completedImageURLString!.isEmpty)
                    let isComplete = (kit.statusValue == 4)
                    let showPhoto = (isComplete && hasUserPhoto) || (isUserChoiceMyPhoto && hasUserPhoto)
                    let path = showPhoto ? kit.completedImageURLString : kit.imageURLString
                    
                    if let p = path, !p.isEmpty {
                        if p.hasPrefix("http") {
                            AsyncImage(url: URL(string: p)) { phase in
                                if let image = phase.image { image.resizable().scaledToFit() }
                                else { Color.gray.opacity(0.3) }
                            }
                        } else if p.hasPrefix("asset://") {
                            let assetID = String(p.dropFirst("asset://".count))
                            PhAssetImage(localIdentifier: assetID).scaledToFit()
                        } else if let uiImage = loadLocalImage(named: p) {
                            Image(uiImage: uiImage).resizable().scaledToFit()
                        } else {
                            Image(systemName: "cube.box").font(.largeTitle).foregroundStyle(.gray.opacity(0.3))
                        }
                    } else {
                        Image(systemName: "cube.box").font(.largeTitle).foregroundStyle(.gray.opacity(0.3))
                    }
                }
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                .clipped()
                
                if kit.statusValue == 4 {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title3)
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .padding(8)
                } else if let status = statusText(for: kit.statusValue) {
                    Text(status).font(.caption2).fontWeight(.bold).padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.ultraThinMaterial).clipShape(Capsule()).padding(8)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if !kit.grade.isEmpty { Text(kit.grade).fontWeight(.bold).padding(.horizontal, 4).padding(.vertical, 2).background(Color.accentColor.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 4)) }
                    if !kit.scale.isEmpty { Text(kit.scale).padding(.horizontal, 4).padding(.vertical, 2).background(Color(uiColor: .tertiarySystemFill)).clipShape(RoundedRectangle(cornerRadius: 4)) }
                }.font(.caption2).foregroundStyle(.secondary)
                Text(kit.title).font(.headline).lineLimit(2).foregroundStyle(.primary).padding(.top, 2)
                Text(kit.maker).font(.caption).foregroundStyle(.secondary)
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color(uiColor: .secondarySystemGroupedBackground))
        }.clipShape(RoundedRectangle(cornerRadius: 12)).shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func loadLocalImage(named name: String) -> UIImage? {
        return ImageLinker.loadLocalImage(named: name)
    }
    
    private func statusText(for value: Int) -> String? {
        return KitStatus(rawValue: value)?.labelLong
    }
}
