// SharedComponents.swift V2
// 1. バージョン管理ルールに基づき更新 (V1 -> V2)
// 2. 修正点: PhAssetImage を追加し、iPadContentViewでも写真アセットを表示可能にする
// 3. 全文差し替えルール適用

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Settings Row Component
struct SettingsRow: View {
    let icon: String
    let label: String
    var subLabel: String? = nil
    var isLocked: Bool = false
    let action: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(themeManager.currentTheme.mainColor.opacity(0.1))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundStyle(.primary)
                    if let sub = subLabel {
                        Text(sub).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow)
                        .padding(.trailing, 4)
                }
                
                Image(systemName: "chevron.right").font(.system(size: 14)).foregroundStyle(.secondary.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).background(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
        }.buttonStyle(.plain)
    }
}

// MARK: - Missing Images View
struct MissingImagesView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Kit.createdDate, order: .reverse) private var kits: [Kit]
    @ObservedObject private var themeManager = ThemeManager.shared
    
    enum Tab: String, CaseIterable, Identifiable {
        case both = "BOTH"
        case box = "BOX ART"
        case photo = "COMPLETE"
        var id: String { rawValue }
    }
    @State private var selectedTab: Tab = .both
    
    @State private var targetKitForSearch: Kit? = nil
    @State private var showImagePicker = false
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var targetKitForPhoto: Kit? = nil
    @State private var pickedImage: UIImage? = nil
    @State private var showActionSheet = false
    
    var displayedKits: [Kit] {
        kits.filter { kit in
            let isBoxMissing = (kit.imageURLString == nil || kit.imageURLString!.isEmpty)
            let isPhotoMissing = (kit.statusValue == 4 && (kit.completedImageURLString == nil || kit.completedImageURLString!.isEmpty))
            let isComplete = (kit.statusValue == 4)
            
            switch selectedTab {
            case .both:
                return isBoxMissing && isPhotoMissing
            case .box:
                return isBoxMissing && !isComplete
            case .photo:
                return isPhotoMissing && !isBoxMissing
            }
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Text("MISSING LINKS")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                    .background(Color(UIColor.systemBackground))
                    
                    HStack(spacing: 0) {
                        ForEach(Tab.allCases) { tab in
                            Button {
                                LocalHaptics.tap()
                                withAnimation { selectedTab = tab }
                            } label: {
                                VStack(spacing: 8) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(selectedTab == tab ? themeManager.currentTheme.mainColor : .secondary)
                                    Rectangle()
                                        .fill(selectedTab == tab ? themeManager.currentTheme.mainColor : Color.clear)
                                        .frame(height: 2)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .background(Color(UIColor.systemBackground))
                    
                    Divider()
                    
                    if displayedKits.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "photo.badge.checkmark")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary.opacity(0.3))
                            Text("ALL IMAGES COLLECTED")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        List {
                            ForEach(displayedKits) { kit in
                                rowView(for: kit)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparatorTint(Color.white.opacity(0.1))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        handleTap(kit)
                                    }
                            }
                            Color.clear.frame(height: 100).listRowBackground(Color.clear)
                        }
                        .listStyle(.plain)
                    }
                }
                
                VStack {
                    Spacer()
                    Button {
                        LocalHaptics.tap()
                        withAnimation { isPresented = false }
                    } label: {
                        Circle()
                            .fill(themeManager.currentTheme.mainColor.opacity(0.9))
                            .frame(width: 70, height: 70)
                            .shadow(radius: 10)
                            .overlay(Image(systemName: "xmark").font(.largeTitle).foregroundColor(.white))
                    }
                    .padding(.bottom, 20)
                }
            }
            .background(Color(UIColor.systemBackground))
            .sheet(item: $targetKitForSearch) { kit in
                WebImageSearchModal(
                    kit: kit,
                    isPresented: Binding(
                        get: { true },
                        set: { if !$0 {
                            targetKitForSearch = nil
                            checkAndShowPhotoFlow(for: kit)
                        } }
                    )
                )
            }
            .confirmationDialog("画像の登録", isPresented: $showActionSheet, actions: {
                Button("カメラで撮影") {
                    pickerSource = .camera
                    showImagePicker = true
                }
                Button("アルバムから選択") {
                    pickerSource = .photoLibrary
                    showImagePicker = true
                }
                Button("キャンセル", role: .cancel) {
                    targetKitForPhoto = nil
                }
            })
            .sheet(isPresented: $showImagePicker, onDismiss: savePickedImage) {
                ImagePicker(sourceType: pickerSource, selectedImage: $pickedImage)
            }
        }
    }
    
    private func rowView(for kit: Kit) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                Image(systemName: "camera.badge.ellipsis")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(kit.title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                HStack(spacing: 6) {
                    if kit.imageURLString == nil || kit.imageURLString!.isEmpty {
                        badge(text: "BOX", color: .orange)
                    }
                    if kit.statusValue == 4 && (kit.completedImageURLString == nil || kit.completedImageURLString!.isEmpty) {
                        badge(text: "COMPLETE", color: .cyan)
                    }
                    HStack(spacing: 4) {
                        Text(kit.maker)
                        if !kit.grade.isEmpty { Text("・"); Text(kit.grade) }
                        if !kit.scale.isEmpty { Text("・"); Text(kit.scale) }
                    }.font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right.circle.fill").foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.5))
        }
    }

    private func badge(text: String, color: Color) -> some View {
        Text(text).font(.system(size: 9, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 1)
            .background(color.opacity(0.2)).foregroundStyle(color).cornerRadius(3)
    }
    
    private func handleTap(_ kit: Kit) {
        LocalHaptics.tap()
        if kit.imageURLString == nil || kit.imageURLString!.isEmpty { targetKitForSearch = kit }
        else if kit.statusValue == 4 && (kit.completedImageURLString == nil || kit.completedImageURLString!.isEmpty) {
            targetKitForPhoto = kit; showActionSheet = true
        }
    }
    
    private func checkAndShowPhotoFlow(for kit: Kit) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if kit.statusValue == 4 && (kit.completedImageURLString == nil || kit.completedImageURLString!.isEmpty) {
                self.targetKitForPhoto = kit
                self.showActionSheet = true
            }
        }
    }
    
    private func savePickedImage() {
        guard let image = pickedImage, let kit = targetKitForPhoto else { return }
        if let fileName = saveImageToDocuments(image) {
            kit.completedImageURLString = fileName
            kit.updatedDate = Date()
        }
        pickedImage = nil; targetKitForPhoto = nil
    }
    
    private func saveImageToDocuments(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        do { try data.write(to: url); return fileName } catch { return nil }
    }
}

// MARK: - Web Image Search Modal
struct WebImageSearchModal: View {
    let kit: Kit
    @Binding var isPresented: Bool
    @State private var searchText: String = ""
    @State private var items: [YahooItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @ObservedObject private var themeManager = ThemeManager.shared
    private let client = YahooShoppingClient.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SEARCH BOX ART").font(.system(size: 16, weight: .bold, design: .monospaced))
                Spacer()
                Button("CLOSE") { isPresented = false }.font(.system(size: 14, weight: .bold))
            }.padding().background(Color(UIColor.secondarySystemBackground))
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search...", text: $searchText).textFieldStyle(.plain).onSubmit { performSearch() }
                Button(action: performSearch) { Text("GO").font(.callout.bold()).foregroundStyle(themeManager.currentTheme.mainColor) }
            }.padding().background(Color(UIColor.systemBackground))
            Divider()
            if isLoading { Spacer(); ProgressView(); Spacer() }
            else if let error = errorMessage { Spacer(); Text(error).foregroundStyle(.red).padding(); Spacer() }
            else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                        ForEach(items) { item in
                            Button { selectImage(item) } label: {
                                AsyncImage(url: item.imageURL) { phase in
                                    if let img = phase.image { img.resizable().scaledToFill() }
                                    else { Color.gray.opacity(0.3) }
                                }.frame(height: 100).clipped()
                            }
                        }
                    }
                }
            }
        }.onAppear { searchText = kit.title; performSearch() }
    }
    private func performSearch() {
        guard !searchText.isEmpty else { return }
        isLoading = true; errorMessage = nil; items = []
        Task {
            do {
                let results = try await client.search(query: searchText)
                await MainActor.run { self.items = results.filter { $0.imageURL != nil }; self.isLoading = false; if self.items.isEmpty { self.errorMessage = "No images found." } }
            } catch { await MainActor.run { self.errorMessage = "Search failed."; self.isLoading = false } }
        }
    }
    private func selectImage(_ item: YahooItem) {
        guard let url = item.imageURL else { return }
        kit.imageURLString = url.absoluteString; LocalHaptics.select(); isPresented = false
    }
}

// MARK: - Item Management View
struct ItemManagementView: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Kit.createdDate, order: .reverse) private var kits: [Kit]
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var isSelectionMode: Bool = false
    @State private var selectedItems: Set<PersistentIdentifier> = []
    @State private var showBulkDeleteAlert: Bool = false
    @State private var duplicateGroups: [[Kit]] = []
    @State private var showDuplicateResolver: Bool = false
    
    @State private var showActionSheet = false
    @State private var targetKitForPhoto: Kit? = nil
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage? = nil
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showPurgeAllConfirm1 = false
    @State private var showPurgeAllConfirm2 = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text(showDuplicateResolver ? "CONFLICT RESOLUTION" : "ITEM MANAGEMENT")
                        .font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(.primary)
                    Spacer()
                }.padding(.top, 10).background(Color(UIColor.systemBackground))

                HStack {
                    if !showDuplicateResolver {
                        Button {
                            LocalHaptics.select()
                            withAnimation {
                                isSelectionMode.toggle()
                                selectedItems.removeAll()
                            }
                        } label: {
                            Text(isSelectionMode ? "CANCEL" : "MULTI SELECT")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(isSelectionMode ? .white : themeManager.currentTheme.mainColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isSelectionMode ? Color.gray.opacity(0.5) : themeManager.currentTheme.mainColor.opacity(0.15))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(isSelectionMode ? Color.gray : themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1)
                                )
                        }
                        
                        Button {
                            LocalHaptics.error()
                            showPurgeAllConfirm1 = true
                        } label: {
                            Text("ALL UNITS PURGE")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 8).padding(.vertical, 6)
                                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red.opacity(0.3), lineWidth: 1))
                        }
                        .padding(.leading, 4)
                    }
                    Spacer()
                }.padding(.horizontal).padding(.bottom, 10)
                Divider()
                
                if !duplicateGroups.isEmpty && !showDuplicateResolver {
                    Button {
                        LocalHaptics.select()
                        withAnimation { showDuplicateResolver = true }
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
                            Text("CONFLICT: \(duplicateGroups.count) SETS").font(.system(size: 14, weight: .bold, design: .monospaced))
                            Spacer()
                            Text("RESOLVE").font(.system(size: 12, weight: .bold)).padding(4).background(Color.yellow).foregroundStyle(.black).cornerRadius(4)
                        }.padding().background(Color.yellow.opacity(0.1))
                    }
                    Divider()
                }
                
                if showDuplicateResolver {
                    duplicateResolverView()
                } else {
                    List {
                        ForEach(kits) { kit in
                            rowView(for: kit)
                                .listRowBackground(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isSelectionMode {
                                        LocalHaptics.tap()
                                        toggleSelection(kit)
                                    } else {
                                        handleItemTap(kit)
                                    }
                                }
                        }
                        Color.clear.frame(height: 120).listRowBackground(Color.clear)
                    }.listStyle(.plain)
                }
            }
            
            if isSelectionMode && !showDuplicateResolver && !selectedItems.isEmpty {
                VStack {
                    Spacer()
                    Button { LocalHaptics.select(); showBulkDeleteAlert = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                            Text("EXECUTE PURGE (\(selectedItems.count))")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(Color.red)
                        .cornerRadius(10)
                        .shadow(color: .red.opacity(0.4), radius: 10, y: 5)
                    }
                    .padding(.bottom, 110)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            VStack {
                Spacer()
                Button {
                    LocalHaptics.tap()
                    if showDuplicateResolver { showDuplicateResolver = false }
                    else { isPresented = false }
                } label: {
                    Circle().fill(themeManager.currentTheme.mainColor.opacity(0.9)).frame(width: 70, height: 70).shadow(radius: 10)
                        .overlay(Image(systemName: "xmark").font(.largeTitle).foregroundColor(.white))
                }.padding(.bottom, 20)
            }
        }
        .background(Color(UIColor.systemBackground))
        .onAppear { checkForDuplicates() }
        .alert("除籍確認", isPresented: $showBulkDeleteAlert) {
            Button("キャンセル", role: .cancel) { if !isSelectionMode { selectedItems.removeAll() } }
            Button("EXECUTE", role: .destructive) {
                let targets = kits.filter { selectedItems.contains($0.persistentModelID) }
                targets.forEach { modelContext.delete($0) }
                isSelectionMode = false
                selectedItems.removeAll()
            }
        } message: { Text("\(selectedItems.count)件の機体データをシステムからパージします。よろしいですか？") }
        .alert("⚠️テスト用全削除", isPresented: $showPurgeAllConfirm1) {
            Button("キャンセル", role: .cancel) { }
            Button("次へ", role: .destructive) { showPurgeAllConfirm2 = true }
        } message: { Text("データベース内の『全てのデータ（\(kits.count)件）』を消去します。よろしいですか？") }
        .alert("⚠️最終警告", isPresented: $showPurgeAllConfirm2) {
            Button("キャンセル", role: .cancel) { }
            Button("全データを高速パージ", role: .destructive) {
                DataTransferManager.shared.clearAllData(modelContext: modelContext)
            }
        } message: { Text("本当に実行しますか？\n2万件以上のデータも数秒で削除されます。") }
        .confirmationDialog("完成写真の登録", isPresented: $showActionSheet, actions: {
            Button("カメラで撮影") { pickerSource = .camera; showImagePicker = true }
            Button("アルバムから選択") { pickerSource = .photoLibrary; showImagePicker = true }
            Button("キャンセル", role: .cancel) { targetKitForPhoto = nil }
        })
        .sheet(isPresented: $showImagePicker, onDismiss: savePickedImage) {
            ImagePicker(sourceType: pickerSource, selectedImage: $pickedImage)
        }
    }
    
    private func rowView(for kit: Kit) -> some View {
        HStack(spacing: 12) {
            if isSelectionMode {
                Image(systemName: selectedItems.contains(kit.persistentModelID) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(themeManager.currentTheme.mainColor)
            }
            VStack(alignment: .leading) {
                Text(kit.title).font(.system(size: 14, weight: .medium))
                Text("\(kit.maker) / \(kit.grade)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            
            if !isSelectionMode {
                Button {
                    LocalHaptics.select()
                    selectedItems = [kit.persistentModelID]
                    showBulkDeleteAlert = true
                } label: {
                    Text("PURGE").font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.red).padding(.horizontal, 8).padding(.vertical, 4)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.red.opacity(0.5), lineWidth: 1))
                }.buttonStyle(.plain)
            }
        }
    }
    
    private func handleItemTap(_ kit: Kit) {
        if kit.statusValue == 4 && (kit.completedImageURLString == nil || kit.completedImageURLString!.isEmpty) {
            LocalHaptics.tap()
            self.targetKitForPhoto = kit
            self.showActionSheet = true
        }
    }

    private func savePickedImage() {
        guard let image = pickedImage, let kit = targetKitForPhoto else { return }
        if let fileName = saveImageToDocuments(image) {
            kit.completedImageURLString = fileName
            kit.updatedDate = Date()
        }
        pickedImage = nil; targetKitForPhoto = nil
    }

    private func saveImageToDocuments(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        do { try data.write(to: url); return fileName } catch { return nil }
    }
    
    private func duplicateResolverView() -> some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(duplicateGroups.indices, id: \.self) { index in
                    VStack(alignment: .leading) {
                        Text("GROUP #\(index + 1)").font(.caption.bold()).foregroundStyle(.yellow)
                        ForEach(duplicateGroups[index]) { kit in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(kit.title).font(.caption).lineLimit(1)
                                    Text("\(kit.grade) \(kit.scale)").font(.system(size: 8)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("PURGE") { modelContext.delete(kit); checkForDuplicates() }.font(.caption2.bold()).foregroundStyle(.red)
                            }.padding(8).background(Color.white.opacity(0.05)).cornerRadius(4)
                        }
                    }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                }
            }.padding()
        }
    }

    private func toggleSelection(_ kit: Kit) {
        if selectedItems.contains(kit.persistentModelID) { selectedItems.remove(kit.persistentModelID) }
        else { selectedItems.insert(kit.persistentModelID) }
    }
    
    private func checkForDuplicates() {
        var groups: [[Kit]] = []
        var checkedIDs: Set<PersistentIdentifier> = []
        for kit in kits {
            if checkedIDs.contains(kit.persistentModelID) { continue }
            let duplicates = kits.filter {
                $0.persistentModelID != kit.persistentModelID &&
                $0.title == kit.title && $0.jan == kit.jan &&
                $0.grade == kit.grade && $0.scale == kit.scale
            }
            if !duplicates.isEmpty {
                var group = duplicates; group.append(kit); groups.append(group); group.forEach { checkedIDs.insert($0.persistentModelID) }
            }
        }
        self.duplicateGroups = groups
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ ui: UIActivityViewController, context: Context) {}
}

// MARK: - Haptics
enum LocalHaptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func select() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

// MARK: - PHAsset Image View (V2)
// iPadContentView, KitDetailOverlay 共通で使う画像ローダー
struct PhAssetImage: View {
    let localIdentifier: String
    @State private var image: UIImage? = nil
    
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img).resizable()
            } else {
                Color.gray.opacity(0.2) // Loading placeholder
                    .onAppear { load() }
            }
        }
    }
    
    private func load() {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = assets.firstObject else { return }
        
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        let targetSize = CGSize(width: 500, height: 500)
        
        manager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { result, _ in
            if let res = result {
                self.image = res
            }
        }
    }
}

// MARK: - Image Linker (Shared Logic)
struct ImageLinker {
    static func loadLocalImage(named name: String) -> UIImage? {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        // Crash Prevention: Check if file exists before trying to read data synchronously
        if !FileManager.default.fileExists(atPath: url.path) { return nil }
        
        do {
            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            print("Failed to load local image: \(error.localizedDescription)")
            return nil
        }
    }
    
    static func deleteLocalImageFile(named name: String?) {
        guard let name = name, !name.isEmpty else { return }
        if name.hasPrefix("http") || name.hasPrefix("asset://") { return }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Kit Status Definition
enum KitStatus: Int, CaseIterable, Identifiable {
    case wish = 0
    case reservation = 1
    case stock = 2
    case inProgress = 3
    case complete = 4
    
    var id: Int { rawValue }
    
    var iconName: String {
        switch self {
        case .wish: return "wish"
        case .reservation: return "reservation"
        case .stock: return "stock"
        case .inProgress: return "inprogress"
        case .complete: return "complete"
        }
    }
    
    var labelShort: String {
        switch self {
        case .wish: return "Wish"
        case .reservation: return "Res."
        case .stock: return "Stock"
        case .inProgress: return "Prog."
        case .complete: return "Comp."
        }
    }
    
    var labelLong: String {
        switch self {
        case .wish: return "WISH"
        case .reservation: return "RESERVED"
        case .stock: return "STOCK"
        case .inProgress: return "NOW"
        case .complete: return "COMPLETE"
        }
    }
}
