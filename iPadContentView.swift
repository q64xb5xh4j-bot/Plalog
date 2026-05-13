// iPadContentView.swift V52
// PART 1 OF 2
// 1. バージョン管理ルールに基づき更新 (V51 -> V52)
// 2. 修正点: デザインをiPhone版の「電脳空間」テイストに統一
//    - BootSequenceViewの導入
//    - BackgroundWallView (パララックス背景) の導入
//    - BlueOrbView (システムコア) の配置
//    - NavigationSplitViewの背景透過(Glassmorphism)化
// 3. 構造変更ルール適用: 既存のロジックは維持しつつ、UI層を大幅に変更

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CoreMotion

struct iPadContentView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    @StateObject private var motionManager = MotionManager()
    @Query(sort: \Kit.createdDate, order: .reverse) private var allKits: [Kit]
    
    // Boot Sequence State
    @State private var isBootSequenceFinished: Bool = false
    @State private var showBootSequence: Bool = true
    @State private var showPilotStatsInfo: Bool = false // ✅ Pilot ID State
    @State private var pilotAvatar: UIImage? = nil // Avatar Image
    
    @State private var selectedCategory: SidebarItem? = .all
    @State private var selectedKit: Kit? = nil
    @State private var showAddSheet: Bool = false
    @State private var searchText: String = ""

    enum SidebarItem: String, CaseIterable, Identifiable {
        case bridge // ✅ Added Bridge
        case all
        case wish
        case reservation
        case stock
        case inProgress
        case complete
        case slideshow
        // case settings // Removed: Access via Bridge
        
        var id: String { rawValue }
        
        var localizedTitle: String {
            switch self {
            case .bridge: return "ブリッジ" // Localized
            case .all: return LanguageManager.shared.t(.sidebar_all)
            case .wish: return LanguageManager.shared.t(.sidebar_wish)
            case .reservation: return LanguageManager.shared.t(.sidebar_reserved)
            case .stock: return LanguageManager.shared.t(.sidebar_stock)
            case .inProgress: return LanguageManager.shared.t(.sidebar_progress)
            case .complete: return LanguageManager.shared.t(.sidebar_complete)
            case .slideshow: return LanguageManager.shared.t(.sidebar_slideshow)
            // case .settings: return LanguageManager.shared.t(.sidebar_settings)
            }
        }
        
        var iconName: String {
            switch self {
            case .bridge: return "cpu"
            case .all: return "square.grid.2x2"
            case .slideshow: return "play.rectangle.on.rectangle"
            case .wish: return "wish"
            case .reservation: return "reservation"
            case .stock: return "stock"
            case .inProgress: return "inprogress"
            case .complete: return "complete"
            // case .settings: return "setting"
            }
        }
        
        var isSystemImage: Bool {
            switch self {
            case .all, .slideshow, .bridge: return true
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
            // MARK: - Layer 0: Cyber Space Background
            Color.black.ignoresSafeArea()
            
            if isBootSequenceFinished {
                // Parallax Wall
                BackgroundWallView(kits: allKits)
                    .opacity(0.8)
                    .offset(x: motionManager.roll * 50, y: motionManager.pitch * 50)
                    .animation(.linear(duration: 0.1), value: motionManager.roll)
                    .transition(.opacity.animation(.easeInOut(duration: 1.0)))
            }

            // MARK: - Layer 1: Main Interface (Glassmorphism)
            if isBootSequenceFinished {
                NavigationSplitView {
                    // Sidebar
                    ZStack(alignment: .topLeading) {
                        // Glass Background
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                        
                        VStack(alignment: .leading, spacing: 0) {
                            // System Header
                            HStack(spacing: 12) {
                                BlueOrbView(isAnimating: true, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PLALOG OS")
                                        .font(.system(size: 14, weight: .black, design: .monospaced))
                                        .foregroundStyle(themeManager.currentTheme.mainColor)
                                    Text("v.2.0.5 [iPad]")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                
                                // ✅ Removed Pilot ID Buttons (Moved to Bridge)
                            }
                            .padding(.top, 20)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                            
                            Divider().background(themeManager.currentTheme.mainColor.opacity(0.5))

                            List(selection: $selectedCategory) {
                                Section(langManager.t(.sidebar_modules)) {
                                    ForEach(SidebarItem.allCases, id: \.self) { item in
                                        NavigationLink(value: item) {
                                            HStack {
                                                Label {
                                                    Text(item.localizedTitle)
                                                        .font(.system(size: 14, design: .monospaced))
                                                } icon: {
                                                    if item.isSystemImage {
                                                        Image(systemName: item.iconName)
                                                            .frame(width: 20, height: 20)
                                                            .foregroundStyle((item == .slideshow || item == .all || item == .bridge) ? Color.cyan : Color.primary)
                                                    } else {
                                                        Image(item.iconName).resizable().scaledToFit().frame(width: 20, height: 20)
                                                    }
                                                }
                                                Spacer()
                                                // Only show count for list items, not slideshow/bridge
                                                if let _ = item.statusValue {
                                                     if count(for: item) > 0 {
                                                         Text(String(format: "%02d", count(for: item)))
                                                             .font(.system(size: 10, design: .monospaced))
                                                             .foregroundStyle(themeManager.currentTheme.mainColor)
                                                             .padding(.horizontal, 6)
                                                             .padding(.vertical, 2)
                                                             .overlay(RoundedRectangle(cornerRadius: 4).stroke(themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1))
                                                     }
                                                } else if item == .all {
                                                     if count(for: item) > 0 {
                                                         Text(String(format: "%02d", count(for: item)))
                                                             .font(.system(size: 10, design: .monospaced))
                                                             .foregroundStyle(themeManager.currentTheme.mainColor)
                                                             .padding(.horizontal, 6)
                                                             .padding(.vertical, 2)
                                                             .overlay(RoundedRectangle(cornerRadius: 4).stroke(themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1))
                                                     }
                                                }
                                            }
                                            .padding(.vertical, 6)
                                        }
                                        .tint(item == .slideshow || item == .all || item == .bridge ? .cyan : nil) // Force selection color
                                        .listRowBackground(Color.clear)
                                        .listRowSeparatorTint(themeManager.currentTheme.mainColor.opacity(0.2))
                                    }
                                }
                                
                                /*
                                Section(langManager.t(.sidebar_system)) {
                                    NavigationLink(value: SidebarItem.settings) {
                                        Label {
                                            Text(SidebarItem.settings.localizedTitle)
                                                .font(.system(size: 14, design: .monospaced))
                                        } icon: {
                                            if SidebarItem.settings.isSystemImage {
                                                Image(systemName: SidebarItem.settings.iconName).frame(width: 20, height: 20)
                                            } else {
                                                Image(SidebarItem.settings.iconName).resizable().scaledToFit().frame(width: 20, height: 20)
                                            }
                                        }
                                    }
                                    .listRowBackground(Color.clear)
                                }
                                */
                            }
                            .listStyle(.sidebar)
                            .scrollContentBackground(.hidden)
                            
                            // Add Button Area (Removed from Bottom - Moved to Header in Detail View)
                            VStack(alignment: .leading) {
                                Divider().background(themeManager.currentTheme.mainColor.opacity(0.5))
                                Spacer() // Placeholder or Info
                            }
                            .frame(height: 1) // Minimized
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 280, ideal: 300, max: 350)
                    
                } detail: {
                    if let category = selectedCategory {
                        // if category == .settings { iPadSettingsView() } else ... -> Removed
                        if category == .slideshow {
                            SlideshowConfigView()
                        } else if category == .wish {
                            iPadWishListView()
                        } else if category == .bridge {
                            BridgeContent(
                                showBackButton: false,
                                onSlideshowTap: { selectedCategory = .slideshow }
                            )
                        } else {
                            iPadKitGridView(category: category, allKits: allKits, selectedKit: $selectedKit, showAddSheet: $showAddSheet) // ✅ Pass showAddSheet
                        }
                    } else {
                        Text(langManager.t(.ipad_select_module))
                            .font(.largeTitle)
                            .fontWeight(.black)
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
                .navigationSplitViewStyle(.balanced)
            }
            
            // MARK: - Layer 2: Boot Sequence Overlay
            if showBootSequence {
                BootSequenceView {
                    withAnimation {
                        isBootSequenceFinished = true
                        showBootSequence = false // Hide overlay
                    }
                }
                .zIndex(999)
            }
        }
        .onAppear {
            motionManager.startUpdates()
            loadPilotAvatar()
            // ✅ Pre-warm Search Components to fix first-run lag
            Task(priority: .userInitiated) {
                _ = CSVDataManager.shared.loadedKits.count
                MasterCatalogDB.shared.preload()
                _ = TitleParser.knownSeries.count
            }
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            AddRegistrationFlowOverlay(isPresented: $showAddSheet)
        }
        .sheet(item: $selectedKit) { _ in
            KitDetailOverlay(kit: $selectedKit)
        }
        .fullScreenCover(isPresented: $showPilotStatsInfo) {
             PilotStatsOverlay(allKits: allKits, isPresented: $showPilotStatsInfo, profileImage: $pilotAvatar)
        }
    }
    
    private func count(for item: SidebarItem) -> Int {
        switch item {
        case .all: return allKits.count
        // case .settings: return 0 // Removed
        default: return allKits.filter { $0.statusValue == item.statusValue }.count
        }
    }
    
    private func loadPilotAvatar() {
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docURL.appendingPathComponent("pilot_avatar.png")
        if let data = try? Data(contentsOf: url) {
            pilotAvatar = UIImage(data: data)
        }
    }
}

// MARK: - Subviews for Content Area (New Wrapper)
// MARK: - Subviews for Content Area (New Wrapper)
struct iPadKitGridView: View {
    let category: iPadContentView.SidebarItem
    let allKits: [Kit]
    @Binding var selectedKit: Kit?
    @Binding var showAddSheet: Bool // ✅ Added Binding
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    // Share State
    @State private var showShareSheet: Bool = false
    @State private var shareImage: UIImage? = nil
    
    // ✅ Filter States
    @State private var filterSeries: String? = nil
    @State private var filterMaker: String? = nil
    @State private var filterGrade: String? = nil

    // ✅ Filter Logic
    var filteredKits: [Kit] {
        let baseKits: [Kit]
        if category == .all {
             baseKits = allKits
        } else if let status = category.statusValue {
             baseKits = allKits.filter { $0.statusValue == status }
        } else {
             baseKits = []
        }
        
        return baseKits.filter { kit in
            let seriesMatch = (filterSeries == nil) || (kit.series == filterSeries)
            let makerMatch = (filterMaker == nil) || (kit.maker == filterMaker)
            let gradeMatch = (filterGrade == nil) || (kit.grade == filterGrade)
            return seriesMatch && makerMatch && gradeMatch
        }
    }
    
    var availableSeries: [String] { Set(allKits.map { $0.series }).sorted() }
    var availableMakers: [String] { Set(allKits.map { $0.maker }).sorted() }
    var availableGrades: [String] { Set(allKits.map { $0.grade }).sorted() }
    
    var hasActiveFilters: Bool { filterSeries != nil || filterMaker != nil || filterGrade != nil }
    
    private func clearFilters() {
        filterSeries = nil
        filterMaker = nil
        filterGrade = nil
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]

    var body: some View {
        ZStack {
            // Content Background (Semi-transparent)
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ✅ Enhanced Header
                HStack {
                    // Filter Menu
                    Menu {
                        Button(action: clearFilters) {
                            Label("CLEAR ALL", systemImage: "xmark.circle")
                        }
                        
                        Menu("SERIES") {
                            ForEach(availableSeries, id: \.self) { series in
                                Button(series) { filterSeries = series }
                            }
                        }
                        Menu("MAKER") {
                            ForEach(availableMakers, id: \.self) { maker in
                                Button(maker) { filterMaker = maker }
                            }
                        }
                        Menu("GRADE") {
                            ForEach(availableGrades, id: \.self) { grade in
                                Button(grade) { filterGrade = grade }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text(langManager.t(.btn_filter))
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(hasActiveFilters ? .white : themeManager.currentTheme.mainColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background {
                            if hasActiveFilters {
                                themeManager.currentTheme.mainColor
                            } else {
                                themeManager.currentTheme.mainColor.opacity(0.1)
                            }
                        }
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeManager.currentTheme.mainColor, lineWidth: 1)
                                .opacity(0.5)
                        )
                    }
                    
                    Spacer()
                    
                    // Add Unit Button (Visible on iPad Header)
                    Button {
                         showAddSheet = true
                         let impact = UIImpactFeedbackGenerator(style: .medium)
                         impact.impactOccurred()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text(langManager.t(.btn_add_unit))
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background { themeManager.currentTheme.mainColor.opacity(0.8) }
                        .cornerRadius(8)
                    }
                    
                    // Share Button
                    if !filteredKits.isEmpty {
                        Button(action: {
                            let title: String
                            switch category {
                            case .stock: title = langManager.t(.stats_stock)
                            case .inProgress: title = langManager.t(.stats_const)
                            case .complete: title = langManager.t(.stats_done)
                            default: title = langManager.t(.sidebar_all)
                            }
                            
                            if let image = ImageRendererHelper.render(view: LootReportView(kits: filteredKits, title: title), size: CGSize(width: 1080, height: 1350)) {
                                shareImage = image
                                showShareSheet = true
                            }
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                                .padding(8)
                                .background(themeManager.currentTheme.mainColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                
                // Active Filter Tags
                if hasActiveFilters {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            if let s = filterSeries { filterTag(label: s) { filterSeries = nil } }
                            if let m = filterMaker { filterTag(label: m) { filterMaker = nil } }
                            if let g = filterGrade { filterTag(label: g) { filterGrade = nil } }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 10)
                    }
                }
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredKits) { kit in
                            Button(action: {
                                selectedKit = kit
                            }) {
                                iPadKitCard(kit: kit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    Spacer().frame(height: 100)
                }
            }
        }
        .navigationTitle(category.localizedTitle)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
    }
    
    @ViewBuilder
    private func filterTag(label: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(themeManager.currentTheme.mainColor)
        .cornerRadius(4)
    }
}

struct iPadKitCard: View {
    let kit: Kit
    var body: some View {
        VStack(spacing: 0) {
            // Image Area
                // Correct UniversalImageView Usage
                let showUserPhoto = (kit.statusValue == 4 && kit.completedImageURLString != nil && !kit.completedImageURLString!.isEmpty)
                let targetData = showUserPhoto ? kit.completedImageData : kit.imageData
                let targetPath = showUserPhoto ? kit.completedImageURLString : kit.imageURLString
                
                UniversalImageView(imageData: targetData, imagePath: targetPath)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(height: 160)
            .clipped()
            .overlay(alignment: .topTrailing) {
                if kit.statusValue == 4 {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold
                        .padding(6)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                        .overlay(Circle().stroke(Color(red: 1.0, green: 0.84, blue: 0.0), lineWidth: 1))
                        .padding(6)
                }
            }
            
            // Info Area
            VStack(alignment: .leading, spacing: 4) {
                Text(kit.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(height: 40, alignment: .topLeading)
                
                HStack {
                    Text(kit.maker).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text(kit.grade).font(.caption2).fontWeight(.bold).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 4)
    }
}


// MARK: - iPad Settings View
struct iPadSettingsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
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
    @State private var shareImage: UIImage? = nil // ✅ Added missing state
    @State private var showPurchaseOverlay = false
    @State private var showP2PSync = false
    
    // Cloud Storage
    @AppStorage("useCloudStorage") private var useCloudStorage: Bool = false
    @State private var showMigrationConfirm: Bool = false
    @State private var migrationStatus: String = ""
    
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
            // ✅ Add language section for iPad too
            languageSection
            // ✅ Database Store
            databaseStoreSection
            libraryManagementSection
            cloudStorageSection
            syncBackupSection
            godModeSection
            systemInfoSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle(langManager.t(.settings_title))
        .sheet(isPresented: $showItemManagement) { ItemManagementView(isPresented: $showItemManagement) }
 // ... (rest of modifiers)

        .sheet(isPresented: $showMissingImages) { MissingImagesView(isPresented: $showMissingImages) }
        .overlay { if showPurchaseOverlay { PurchaseOverlay(isPresented: $showPurchaseOverlay) } }
        
        .alert(langManager.t(.lib_storage_title), isPresented: $showMaintenanceAlert) {
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
        .alert(langManager.t(.cloud_migrate_title), isPresented: $showMigrationConfirm) {
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
        .sheet(isPresented: $showShareSheet) {
            // Check if we are sharing an image or a URL (Export)
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            } else if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        .sheet(isPresented: $showP2PSync) { P2PSyncView(isPresented: $showP2PSync) }
    }
    
    
    
    // MARK: - Database Store Section (Copied from SettingsOverlay)
    private var databaseStoreSection: some View {
        Section(langManager.t(.settings_dbstore)) {
            // TAMIYA
            DatabaseRow(id: "com.hiro.pralog.db.tamiya", title: "MILITARY (TAMIYA)", desc: langManager.t(.db_military_desc), icon: "shield.fill", color: Color(red: 0.8, green: 0.2, blue: 0.2))
            // AOSHIMA
            DatabaseRow(id: "com.hiro.pralog.db.aoshima", title: "CARS (AOSHIMA)", desc: langManager.t(.db_car_desc), icon: "car.fill", color: .blue)
            // KOTOBUKIYA
            DatabaseRow(id: "com.hiro.pralog.db.kotobukiya", title: "CHARACTER (KOTOBUKIYA)", desc: "Frame Arms Girl, Megami Device", icon: "figure.walk", color: .green)
            // HASEGAWA
            DatabaseRow(id: "com.hiro.pralog.db.hasegawa", title: "AIRCRAFT (HASEGAWA)", desc: "Detailed aircraft kits", icon: "airplane", color: .yellow)
            // FUJIMI
            DatabaseRow(id: "com.hiro.pralog.db.fujimi", title: "MODELS (FUJIMI)", desc: "Ships & Cars", icon: "ferry.fill", color: .cyan)
            // FINE MOLDS
            DatabaseRow(id: "com.hiro.pralog.db.finemolds", title: "FINE MOLDS", desc: "Ghibli & Military", icon: "star.fill", color: .orange)
            // MAX FACTORY
            DatabaseRow(id: "com.hiro.pralog.db.maxfactory", title: "DOUGRAM (MAX FACTORY)", desc: "Combat Armors MAX", icon: "circle.grid.hex.fill", color: .purple)
            // VOLKS
            DatabaseRow(id: "com.hiro.pralog.db.volks", title: "MODELS (VOLKS)", desc: "IMS (FSS), SWS", icon: "v.circle.fill", color: .black)
        }
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
                    }.frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.system(size: 14, weight: .bold))
                        Text(desc).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .tint(ThemeManager.shared.currentTheme.mainColor)
            .onChange(of: isEnabled) { _, newValue in
                // Trigger Reload
                if newValue { LocalHaptics.success() } else { LocalHaptics.select() }
                DispatchQueue.global(qos: .userInitiated).async {
                    CSVDataManager.shared.reloadAll()
                }
            }
        }
    }

    private var languageSection: some View {
        Section(langManager.t(.settings_language)) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AppLanguage.allCases) { lang in
                         Button {
                             LocalHaptics.select()
                             langManager.currentLanguage = lang
                         } label: {
                             HStack {
                                 Text(lang.flag)
                                 Text(lang.displayName).font(.caption).fontWeight(.bold)
                             }
                             .padding(.horizontal, 12)
                             .padding(.vertical, 8)
                             .background(langManager.currentLanguage == lang ? themeManager.currentTheme.mainColor : Color(UIColor.tertiarySystemFill))
                             .foregroundStyle(langManager.currentLanguage == lang ? .white : .primary)
                             .cornerRadius(8)
                         }
                         .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            Text(langManager.t(.settings_language_note))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var themeSection: some View {
        Section(langManager.t(.settings_theme)) {
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
    

    
    private var libraryManagementSection: some View {
        Section(langManager.t(.settings_library)) {
            HStack(spacing: 12) {
                Button { showItemManagement = true } label: {
                    VStack(alignment: .leading) {
                        Text(langManager.t(.lib_manage_title)).font(.headline)
                        Text(langManager.t(.lib_manage_desc) + "\nTOTAL UNITS: \(allKits.count)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { LocalHaptics.error(); showPurgeConfirm1 = true } label: {
                    VStack {
                        Image(systemName: "trash.fill").font(.title3).foregroundStyle(.white)
                        Text(langManager.t(.lib_reset_btn)).font(.system(size: 8, weight: .bold)).foregroundStyle(.white)
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
                            Text(langManager.t(.lib_storage_title)).font(.headline)
                            Text(langManager.t(.lib_storage_desc)).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "externaldrive.badge.minus").foregroundStyle(themeManager.currentTheme.mainColor) }
                    Spacer()
                }
            }
            
            Button { checkCommanderAccess { showMissingImages = true } } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text(langManager.t(.lib_missing_title)).font(.headline)
                            Text("\(langManager.t(.lib_missing_desc_pre))\(missingBoxArtCount)\(langManager.t(.lib_missing_desc_post))\(missingPhotoCount)").font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "photo.badge.plus").foregroundStyle(themeManager.currentTheme.mainColor) }
                    Spacer()
                    if !storeManager.isCommander { Image(systemName: "lock.fill").foregroundStyle(.yellow) }
                }
            }
        }
    }
    
    private var cloudStorageSection: some View {
        Section(langManager.t(.settings_cloud)) {
            Toggle(isOn: $useCloudStorage) {
                VStack(alignment: .leading) {
                    Text(langManager.t(.cloud_low_data))
                        .font(.headline)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                    Text(langManager.t(.cloud_low_data_desc)).font(.caption).foregroundStyle(.secondary)
                }
            }
            .tint(themeManager.currentTheme.mainColor)
            
            if useCloudStorage {
                Button {
                    LocalHaptics.select()
                    showMigrationConfirm = true
                } label: {
                    HStack {
                        Label {
                            VStack(alignment: .leading) {
                                Text(langManager.t(.cloud_migrate_title)).font(.headline)
                                Text(langManager.t(.cloud_migrate_desc)).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "arrow.up.doc.on.clipboard").foregroundStyle(themeManager.currentTheme.mainColor) }
                        Spacer()
                    }
                }
            }
        }
    }

    private var syncBackupSection: some View {
        Section(langManager.t(.settings_sync)) {
            Button {
                LocalHaptics.select()
                showP2PSync = true
            } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text(langManager.t(.sync_direct_title)).font(.headline)
                            Text(langManager.t(.sync_direct_desc)).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(themeManager.currentTheme.mainColor) }
                    Spacer()
                }
            }
            
            Button { checkCommanderAccess { runExport() } } label: {
                HStack {
                    Label {
                        VStack(alignment: .leading) {
                            Text(langManager.t(.sync_export_title)).font(.headline)
                            Text(langManager.t(.sync_export_desc)).font(.caption).foregroundStyle(.secondary)
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
                            Text(langManager.t(.sync_import_title)).font(.headline)
                            Text(langManager.t(.sync_import_desc)).font(.caption).foregroundStyle(.secondary)
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
        Section(langManager.t(.settings_godmode)) {
            VStack(alignment: .leading, spacing: 16) {
                // Toggle (鍵がないと押せない)
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
                
                // 状態表示テキスト
                if areKeysReady {
                    // ✅ 金色で SYSTEM ACTIVATED
                    Text(langManager.t(.god_system_activated))
                        .font(.caption)
                        .fontWeight(.black)
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                    
                    if !isGodModeEnabled {
                        Text(langManager.t(.god_enable_guide))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                } else {
                    Text(langManager.t(.god_locked_guide))
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .fontWeight(.bold)
                }
                
                Divider()
                
                // 1. API Key Field
                VStack(alignment: .leading, spacing: 4) {
                    Text(langManager.t(.god_api_key))
                        .font(.caption).fontWeight(.bold)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.leading, 4)
                    
                    HStack {
                        Image(systemName: "key.fill")
                            .foregroundStyle(googleApiKey.isEmpty ? .gray : themeManager.currentTheme.mainColor)
                            .frame(width: 24)
                        
                        SecureField("", text: $googleApiKey, prompt: Text(langManager.t(.god_enter_key)).foregroundStyle(.gray))
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
                    Text(langManager.t(.god_engine_id))
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

