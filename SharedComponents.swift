// SharedComponents.swift V2
// 1. バージョン管理ルールに基づき更新 (V1 -> V2)
// 2. 修正点: PhAssetImage を追加し、iPadContentViewでも写真アセットを表示可能にする
// 3. 全文差し替えルール適用

import SwiftUI
import SwiftData
import PhotosUI
import PhotosUI
import UniformTypeIdentifiers
import Photos // ✅ Helper for Album

// MARK: - Common Styles (Shared)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Common Visual Elements
struct OfficialBadge: View {
    var body: some View {
        Text("OFFICIAL")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.blue)
            .cornerRadius(4)
    }
}

// MARK: - Photo Album Helper (Shared)
class PhotoAlbumHelper {
    static let shared = PhotoAlbumHelper()
    private let albumName = "PLALOG"
    
    func saveImageToAlbum(_ image: UIImage, completion: @escaping (String?) -> Void) {
        // 1. Check/Create Album
        if let album = fetchAssetCollection(for: albumName) {
            saveImage(image, to: album, completion: completion)
        } else {
            createAlbum(name: albumName) { [weak self] success in
                if success, let self = self, let album = self.fetchAssetCollection(for: self.albumName) {
                    self.saveImage(image, to: album, completion: completion)
                } else {
                    // Fallback: Camera Roll
                    self?.saveImageToLibraryFallback(image, completion: completion)
                }
            }
        }
    }
    
    private func fetchAssetCollection(for title: String) -> PHAssetCollection? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", title)
        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        return collection.firstObject
    }
    
    private func createAlbum(name: String, completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
        }, completionHandler: { success, error in
            completion(success)
        })
    }
    
    private func saveImage(_ image: UIImage, to album: PHAssetCollection, completion: @escaping (String?) -> Void) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = createAssetRequest.placeholderForCreatedAsset
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                  let assetPlaceholder = placeholder else { return }
            let fastEnumeration = NSArray(object: assetPlaceholder)
            albumChangeRequest.addAssets(fastEnumeration)
        }, completionHandler: { success, error in
            if success, let id = placeholder?.localIdentifier {
                completion(id)
            } else {
                completion(nil)
            }
        })
    }
    
    private func saveImageToLibraryFallback(_ image: UIImage, completion: @escaping (String?) -> Void) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
        } completionHandler: { success, _ in
            completion(success ? placeholder?.localIdentifier : nil)
        }
    }
    func getCloudIdentifier(from localIdentifier: String) async -> String? {
        let library = PHPhotoLibrary.shared()
        let localID = localIdentifier.components(separatedBy: "/").last ?? localIdentifier 
        let cleanID = localID.replacingOccurrences(of: "asset://", with: "")
        
        return await withCheckedContinuation { continuation in
            let identifiers = [cleanID]
            let cloudIdentifiers = library.cloudIdentifierMappings(forLocalIdentifiers: identifiers)
            
            if let result = cloudIdentifiers[cleanID], let cloudID = try? result.get() {
                continuation.resume(returning: cloudID.stringValue)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
    
    func getLocalIdentifier(from cloudIdentifierString: String) async -> String? {
        let library = PHPhotoLibrary.shared()
        guard let cloudIdentifier = try? PHCloudIdentifier(stringValue: cloudIdentifierString) else { return nil }
        
        return await withCheckedContinuation { continuation in
            let mappings = library.localIdentifierMappings(for: [cloudIdentifier])
            if let result = mappings[cloudIdentifier], let localID = try? result.get() {
                continuation.resume(returning: localID)
            } else {
                continuation.resume(returning: nil)
            }
        }
    }
}

// MARK: - Image Render Logic (Shared)
@MainActor
class ImageRendererHelper {
    static func render<Content: View>(view: Content, size: CGSize) -> UIImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0 // High Resolution
        renderer.proposedSize = ProposedViewSize(size)
        return renderer.uiImage
    }
}

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
    @State private var pickedAssetID: String? = nil // ✅ New: Store Asset ID
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
                ImagePicker(sourceType: pickerSource, selectedImage: $pickedImage, selectedAssetID: $pickedAssetID)
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
        guard let kit = targetKitForPhoto else { return }
        
        // 1. Asset IDがある場合 (Library参照)
        if let assetID = pickedAssetID {
             kit.completedImageURLString = "asset://" + assetID
             kit.updatedDate = Date()
        } 
        // 2. 画像データがある場合 (カメラ撮影など)
        else if let image = pickedImage {
            if let fileName = saveImageToDocuments(image) {
                kit.completedImageURLString = fileName
                kit.updatedDate = Date()
            }
        }
        
        pickedImage = nil; pickedAssetID = nil; targetKitForPhoto = nil
    }
    
    private func saveImageToDocuments(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        do { try data.write(to: url); return fileName } catch { return nil }
    }
}

// MARK: - Web Image Search Modal
// MARK: - Web Image Search Modal (Browser Redirect)
struct WebImageSearchModal: View {
    var kit: Kit? = nil
    @Binding var isPresented: Bool
    var initialQuery: String? = nil
    var onImageSelected: ((String) -> Void)? = nil
    
    @State private var searchText = ""
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage? = nil
    @State private var pickedAssetID: String? = nil
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("IMAGE HUNT").font(.system(size: 16, weight: .bold, design: .monospaced))
                Spacer()
                Button("閉じる") { isPresented = false }.font(.system(size: 14, weight: .bold))
            }.padding().background(Color(UIColor.secondarySystemBackground))
            
            ScrollView {
                VStack(spacing: 24) {
                    // Step 1: Search
                    VStack(alignment: .leading, spacing: 12) {
                        stepLabel(number: 1, text: "Webで画像を検索・保存")
                        
                        TextField("検索キーワード", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        Button {
                            openGoogleImageSearch()
                        } label: {
                            HStack {
                                Image(systemName: "safari")
                                Text("Google画像検索を開く")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(themeManager.currentTheme.mainColor)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                        
                        Text("※ Safariが開きます。画像を長押しして「写真に保存」してください。")
                            .font(.caption).foregroundStyle(.secondary).padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // Step 2: Import
                    VStack(alignment: .leading, spacing: 12) {
                        stepLabel(number: 2, text: "保存した画像をインポート")
                        
                        Button {
                            showImagePicker = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("ライブラリから選択")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(UIColor.secondarySystemBackground))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                    
                    if let img = pickedImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(12)
                            .padding()
                    }
                }
                .padding(.vertical, 24)
            }
        }
        .onAppear {
            if let q = initialQuery { searchText = q }
            else if let k = kit { searchText = k.title }
        }
        .sheet(isPresented: $showImagePicker, onDismiss: handleImagePicked) {
            ImagePicker(sourceType: .photoLibrary, selectedImage: $pickedImage, selectedAssetID: $pickedAssetID)
        }
    }
    
    private func stepLabel(number: Int, text: String) -> some View {
        HStack {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(themeManager.currentTheme.mainColor))
            Text(text)
                .font(.system(size: 14, weight: .bold))
            Spacer()
        }.padding(.horizontal)
    }
    
    private func openGoogleImageSearch() {
        guard let encodedQuery = searchText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.google.com/search?tbm=isch&q=\(encodedQuery)") else { return }
        UIApplication.shared.open(url)
    }
    
    private func handleImagePicked() {
        if let assetID = pickedAssetID {
            onImageSelected?("asset://" + assetID)
            isPresented = false
        } else if let image = pickedImage {
            // Save to Documents as fallback
             if let data = image.jpegData(compressionQuality: 0.8) {
                 let fileName = UUID().uuidString + ".jpg"
                 let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
                 try? data.write(to: url)
                 onImageSelected?(fileName)
                 isPresented = false
             }
        }
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
    @State private var pickedAssetID: String? = nil // ✅ New
    @State private var pickerSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var showPurgeAllConfirm1 = false
    @State private var showPurgeAllConfirm2 = false
    
    // Share State
    @State private var showShareSheet: Bool = false
    @State private var shareImage: UIImage? = nil
    
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
                VStack(spacing: 20) {
                    Spacer()
                    
                    // Share Button
                    Button {
                        LocalHaptics.select()
                        let targets = kits.filter { selectedItems.contains($0.persistentModelID) }
                        if let image = ImageRendererHelper.render(view: LootReportView(kits: targets, title: "ACQUISITION LOG"), size: CGSize(width: 1080, height: 1350)) {
                            shareImage = image
                            showShareSheet = true
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "square.and.arrow.up")
                            Text("SHARE SELECTION (\(selectedItems.count))")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 24)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(themeManager.currentTheme.mainColor, lineWidth: 2)
                        )
                    }

                    // Delete Button
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
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                targets.forEach { kit in 
                    DeletionManager.shared.recordDeletion(uuid: kit.uuid)
                    modelContext.delete(kit) 
                }
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
            ImagePicker(sourceType: pickerSource, selectedImage: $pickedImage, selectedAssetID: $pickedAssetID)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
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
        guard let kit = targetKitForPhoto else { return }
        
        if let assetID = pickedAssetID {
            kit.completedImageURLString = "asset://" + assetID
            kit.updatedDate = Date()
        } else if let image = pickedImage {
             if let fileName = saveImageToDocuments(image) {
                 kit.completedImageURLString = fileName
                 kit.updatedDate = Date()
             }
        }
        pickedImage = nil; pickedAssetID = nil; targetKitForPhoto = nil
    }

    private func saveImageToDocuments(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
        do { try data.write(to: url); return fileName } catch { return nil }
    }
    
    private func duplicateResolverView() -> some View {
        VStack {
            // Auto Resolve Button
            Button {
                autoResolveDuplicates()
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("AI AUTO MERGE (KEEP BEST)")
                }
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(themeManager.currentTheme.mainColor)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.top)
            
            Text("画像がある方、または作成日が古い方(オリジナル)を優先して残します。")
                .font(.caption2).foregroundStyle(.secondary).padding(.bottom, 10)
            
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
                                        if hasImage(kit) {
                                            Text("HAS IMAGE").font(.system(size: 8, weight: .bold)).foregroundStyle(.green)
                                        }
                                        Text(kit.createdDate.formatted(date: .numeric, time: .omitted)).font(.system(size: 8)).foregroundStyle(.gray)
                                    }
                                    Spacer()
                                    Button("PURGE") { 
                                        DeletionManager.shared.recordDeletion(uuid: kit.uuid)
                                        modelContext.delete(kit)
                                        checkForDuplicates() 
                                    }.font(.caption2.bold()).foregroundStyle(.red)
                                }.padding(8).background(Color.white.opacity(0.05)).cornerRadius(4)
                            }
                        }.padding().background(Color.white.opacity(0.05)).cornerRadius(8)
                    }
                }.padding()
            }
        }
    }

    private func hasImage(_ kit: Kit) -> Bool {
        return (kit.imageData != nil) || (kit.imageURLString != nil && !kit.imageURLString!.isEmpty)
    }

    private func autoResolveDuplicates() {
        var solvedCount = 0
        
        for group in duplicateGroups {
            // Strategy:
            // 1. Keep the one with Image Data (CloudKit) or Image URL
            // 2. If both have images (or neither), keep the OLDER one (Original)
            
            let sorted = group.sorted { k1, k2 in
                let k1HasImg = hasImage(k1)
                let k2HasImg = hasImage(k2)
                
                if k1HasImg && !k2HasImg { return true }
                if !k1HasImg && k2HasImg { return false }
                
                return k1.createdDate < k2.createdDate
            }
            
            guard let keeper = sorted.first else { continue }
            let losers = sorted.dropFirst()
            
            for loser in losers {
                DeletionManager.shared.recordDeletion(uuid: loser.uuid)
                modelContext.delete(loser)
            }
            solvedCount += 1
        }
        
        LocalHaptics.success()
        checkForDuplicates() // Refresh
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
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        // iPad crash fix
        controller.popoverPresentationController?.sourceRect = CGRect(x: UIScreen.main.bounds.width/2, y: UIScreen.main.bounds.height/2, width: 0, height: 0)
        controller.popoverPresentationController?.sourceView = UIView()
        controller.popoverPresentationController?.permittedArrowDirections = []
        return controller
    }
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

// MARK: - Universal Image View (CloudKit + Local Support)
struct UniversalImageView: View {
    let imageData: Data?
    let imagePath: String?
    
    var body: some View {
        Group {
            if let data = imageData, let uiImage = UIImage(data: data) {
                // 1. Prioritize CloudKit Data
                Image(uiImage: uiImage)
                    .resizable()
            } else if let path = imagePath, !path.isEmpty {
                // 2. Fallback to Local Path / Asset
                if path.hasPrefix("asset://") {
                    PhAssetImage(localIdentifier: String(path.dropFirst(8)))
                } else if let url = ImageLinker.resolve(urlString: path) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image {
                            img.resizable()
                        } else {
                            Color.gray.opacity(0.1)
                        }
                    }
                } else {
                    Color.gray.opacity(0.1)
                }
            } else {
                // 3. No Image
                Color.clear
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
    
    // ✅ URL文字列を、ローカルファイルURLまたはリモートURLに解決する
    static func resolve(urlString: String?) -> URL? {
        guard let s = urlString, !s.isEmpty else { return nil }
        // 1. HTTP/HTTPS -> Remote
        if s.lowercased().hasPrefix("http") { return URL(string: s) }
        
        // 2. Local Documents Base
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 3. Try Exact Match (if simple filename) or Absolute Path
        if s.hasPrefix("file://") {
             if let url = URL(string: s), FileManager.default.fileExists(atPath: url.path) { return url }
             // Fallback: Extract filename from file:// URL
             if let url = URL(string: s) {
                 let filename = url.lastPathComponent
                 let fallbackURL = docURL.appendingPathComponent(filename)
                 if FileManager.default.fileExists(atPath: fallbackURL.path) { return fallbackURL }
             }
        } else if s.contains("/") {
            // Absolute path string or relative path with slashes
            // Choice A: Try as is (e.g. legacy absolute path)
            // Choice B: Extract filename and look in Documents (Handling App UUID change)
            let filename = (s as NSString).lastPathComponent
            let fallbackURL = docURL.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: fallbackURL.path) { return fallbackURL }
        }
        
        // 4. Fallback: Treat as simple filename in Documents
        let simpleName = (s as NSString).lastPathComponent // Ensure we only use filename part
        let simpleURL = docURL.appendingPathComponent(simpleName)
        return simpleURL // Return even if not exists, to let AsyncImage handle/fail
    }
    
    // ✅ リモート画像をダウンロードして保存し、ファイル名を返す
    static func downloadAndSave(from url: URL) async -> String? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            // JPEG圧縮して保存
            guard let jpgData = image.jpegData(compressionQuality: 0.8) else { return nil }
            
            let fileName = UUID().uuidString + ".jpg"
            let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = docURL.appendingPathComponent(fileName)
            
            try jpgData.write(to: fileURL)
            return fileName
        } catch {
            print("Download failed: \(error)")
            return nil
        }
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
        case .wish: return "欲しい"
        case .reservation: return "予約済"
        case .stock: return "積み"
        case .inProgress: return "製作中"
        case .complete: return "完成"
        }
    }
    
    var labelLong: String {
        switch self {
        case .wish: return "ウィッシュリスト"
        case .reservation: return "予約済み"
        case .stock: return "積みプラ"
        case .inProgress: return "製作中"
        case .complete: return "完成済み"
        }
    }
}

// MARK: - Official Badge


// MARK: - Deletion Logic (Zombie Fix)
// MARK: - Deletion Logic (Zombie Fix + Optimization)
class DeletionManager {
    static let shared = DeletionManager()
    private let legacyKey = "deleted_kit_uuids" // Old format
    private let limitKey = "deleted_kit_history_v2" // New format: [String: TimeInterval]
    private let retentionPeriod: TimeInterval = 90 * 24 * 60 * 60 // 90 Days
    
    private init() {
        migrateLegacyData()
        pruneOldRecords()
    }
    
    /// Records a deletion with current timestamp
    func recordDeletion(uuid: String) {
        var history = getHistory()
        history[uuid] = Date().timeIntervalSince1970
        saveHistory(history)
        print("[DeletionManager] Recorded deletion for UUID: \(uuid)")
    }
    
    /// Returns list of deleted UUIDs for SyncEnvelope
    func getDeletedUUIDs() -> [String] {
        return Array(getHistory().keys)
    }
    
    // MARK: - Internal Logic
    
    private func getHistory() -> [String: TimeInterval] {
        return UserDefaults.standard.dictionary(forKey: limitKey) as? [String: TimeInterval] ?? [:]
    }
    
    private func saveHistory(_ history: [String: TimeInterval]) {
        UserDefaults.standard.set(history, forKey: limitKey)
    }
    
    /// Migrate from [String] to [String: TimeInterval]
    private func migrateLegacyData() {
        if let oldList = UserDefaults.standard.stringArray(forKey: legacyKey) {
            print("[DeletionManager] Migrating \(oldList.count) legacy records...")
            var history = getHistory()
            let now = Date().timeIntervalSince1970
            
            for uuid in oldList {
                // If not already in new history, add it with current time (reset clock)
                if history[uuid] == nil {
                    history[uuid] = now
                }
            }
            
            saveHistory(history)
            UserDefaults.standard.removeObject(forKey: legacyKey)
            print("[DeletionManager] Migration complete.")
        }
    }
    
    /// Remove records older than retentionPeriod
    private func pruneOldRecords() {
        var history = getHistory()
        let threshold = Date().timeIntervalSince1970 - retentionPeriod
        let initialCount = history.count
        
        // Filter in place
        history = history.filter { $0.value > threshold }
        
        if history.count < initialCount {
            saveHistory(history)
            print("[DeletionManager] Pruned \(initialCount - history.count) old records (Retention: 90 days)")
        }
    }
}

// MARK: - Shape Utilities (Shared)
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
