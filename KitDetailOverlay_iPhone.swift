//
//  KitDetailOverlay_iPhone.swift V59
//  Plalog
//
//  Created by (User) on 2024/06/xx.
//  iPhone専用の実装
//  Layout Fixed Version (V59)
//  修正点:
//  - 【横画面入力対策】入力中は画像エリアを非表示にし、フォームを全画面化してキーボード被りを回避
//  - 【自動スクロール】入力項目をタップした際、その項目が見える位置へ自動スクロール
//

import SwiftUI
import SwiftData
import Combine
import Photos

struct KitDetailOverlay_iPhone: View {
    @Binding var kit: Kit?
    
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var themeManager = ThemeManager.shared
    
    // MARK: - Local State
    @State private var editedTitle: String = ""
    @State private var editedMaker: String = ""
    @State private var editedSeries: String = ""
    @State private var editedGrade: String = ""
    @State private var editedScale: String = ""
    @State private var editedStatus: Int = 0
    @State private var editedMemo: String = ""
    
    private var isMyPhotoMode: Bool { return kit?.displayModeValue == 1 }
    
    @State private var showDuplicateAlert: Bool = false
    @State private var showDeleteAlert: Bool = false
    @State private var showTrashIcon: Bool = false
    @State private var showSettings: Bool = false
    
    // ✅ Discovery State
    
    // ✅ Discovery State
    // ✅ Discovery State
    @State var discoveryRecord: DiscoveryRecord? = nil
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @AppStorage("pilotName") var myPilotName: String = "COMMANDER"
    
    enum PickerType: Identifiable {
        case camera, library
        var id: Int { hashValue }
    }
    // ✅ View Model for Persistent State
    class ViewModel: ObservableObject {
        @Published var activePicker: PickerType? = nil
        @Published var showArrivalScanner: Bool = false
        @Published var showArrivalBoxArtAlert: Bool = false
        @Published var showImageOptions: Bool = false
        @Published var showDuplicateAlert: Bool = false
        @Published var showDeleteAlert: Bool = false
        @Published var showWebSearch: Bool = false
        @Published var showBuildLog: Bool = false
        @Published var showDatabaseMatch: Bool = false
        @Published var capturedImageToEdit: ImageEditWrapper? = nil
        @Published var tempCompletedImage: UIImage? = nil
        @Published var tempAssetID: String? = nil
    }
    
    @StateObject private var vm = ViewModel()

    // ✅ キーボードフォーカス管理用
    enum Field: Hashable {
        case title, maker, scale, grade, series, memo
    }
    @FocusState var focusedField: Field?
    
    private let orbSize: CGFloat = 70
    
    @Environment(\.dismiss) var dismiss // If used as sheet, but this is Overlay.

    var body: some View {
        GeometryReader { geo in
            mainContent(geo: geo)
        }
        .task {
             if let t = kit, !t.jan.isEmpty {
                 self.discoveryRecord = await DiscoveryManager.shared.checkDiscovery(jan: t.jan)
             }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: focusedField)
        .onAppear { initializeStates() }
        .modifier(KitDetailOverlayAlerts(
            kit: $kit,
            vm: vm, // Pass VM instead of individual bindings
            isMyPhotoMode: isMyPhotoMode,
            editedTitle: editedTitle,
            editedMaker: editedMaker,
            editedGrade: editedGrade,
            editedScale: editedScale,
            // Actions
            handleArrivalCheck: handleArrivalCheck,
            deleteMyPhoto: deleteMyPhoto,
            deleteKit: deleteKit,
            handleImageSelection: handleImageSelection,
            loadAssetImageForEditing: loadAssetImageForEditing,
            // Binding updates (hacky but needed for modifier to write back)
            updateEditedFields: { item in
                editedTitle = item.title
                editedMaker = item.maker
                editedSeries = item.series
                editedGrade = item.grade
                editedScale = item.scale
                kit?.jan = item.jan
            }
        ))
    }

    private func mainContent(geo: GeometryProxy) -> some View {
        let isLandscape = geo.size.width > geo.size.height
        return ZStack {
            // 背景ガード
            Color(UIColor.systemBackground)
                .opacity(0.98)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { focusedField = nil }
            
            if let targetKit = kit {
                VStack(spacing: 0) {
                    headerView(geo: geo)

                    if isLandscape {
                        landscapeLayout(geo: geo, targetKit: targetKit)
                    } else {
                        portraitLayout(geo: geo, targetKit: targetKit, proxy: nil)
                    }
                }
            }
        }
    }
    
    private func headerView(geo: GeometryProxy) -> some View {
        HStack {
            Button {
                LocalHaptics.tap()
                self.kit = nil
            } label: {
                ZStack {
                    Color.clear.frame(width: 60, height: 60)
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .frame(width: 44, height: 44)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Circle())
                }
                .contentShape(Rectangle())
            }
            Spacer()
            Text("アイテム詳細").font(.system(size: 16, weight: .bold)).foregroundStyle(.primary)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, geo.safeAreaInsets.top + 10)
        .padding(.bottom, 10)
        .background(Color(UIColor.systemBackground))
    }


}

// Wrapper for Identifiable Image
struct ImageEditWrapper: Identifiable {
    let id = UUID()
    let image: UIImage
}

// MARK: - Subviews & Logic (iPhone)
extension KitDetailOverlay_iPhone {
    
    private func initializeStates() {
        if let t = kit {
            editedTitle = t.title
            editedMaker = t.maker
            editedSeries = t.series
            editedGrade = t.grade
            editedScale = t.scale
            editedStatus = t.statusValue
            editedMemo = t.memo
        }
    }

    @ViewBuilder
    func kitImageSection(kit: Kit, isExpanded: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack {
                let isUserChoiceMyPhoto = (kit.displayModeValue == 1)
                
                let targetData = isUserChoiceMyPhoto ? kit.completedImageData : kit.imageData
                let targetPath = isUserChoiceMyPhoto ? kit.completedImageURLString : kit.imageURLString
                
                if (targetData != nil) || (targetPath?.isEmpty == false) {
                    UniversalImageView(imageData: targetData, imagePath: targetPath)
                        .scaledToFit()
                } else { placeholder() }
                
                VStack {
                    Spacer()
                    HStack {
                        // Edit Button (New)
                        if (targetData != nil) || (targetPath?.isEmpty == false) {
                            Button {
                                LocalHaptics.select()
                                // Load image for editing
                                if let d = targetData, let img = UIImage(data: d) {
                                    vm.capturedImageToEdit = ImageEditWrapper(image: img)
                                } else if let p = targetPath {
                                    // Async load
                                    if p.hasPrefix("asset://") {
                                        let id = String(p.dropFirst(8))
                                        loadAssetImageForEditing(id)
                                    } else {
                                        if let img = loadLocalImage(named: p) {
                                            vm.capturedImageToEdit = ImageEditWrapper(image: img)
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "crop.rotate")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(8)
                                    .background(.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(8)
                        }
                        
                        Spacer()
                        
                        // Existing Indicator
                        Image(systemName: isUserChoiceMyPhoto ? "camera.fill" : "magnifyingglass")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
            }
            .frame(height: isExpanded ? nil : 200)
            .frame(maxHeight: isExpanded ? 250 : nil)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
           if !kit.jan.isEmpty {
            Button("データベース照合") {
                vm.showDatabaseMatch = true
            }
        }    
            HStack(spacing: 0) {
                modeButton(title: "箱絵", targetValue: 0)
                modeButton(title: "マイフォト", targetValue: 1)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(Capsule())
            .frame(maxWidth: 240)
        }
    }
    
    private func modeButton(title: String, targetValue: Int) -> some View {
        let isSelected = (kit?.displayModeValue == targetValue)
        return Button {
            LocalHaptics.select()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { kit?.displayModeValue = targetValue }
        } label: {
            Text(title).font(.system(size: 12, weight: .bold)).foregroundStyle(isSelected ? .white : .secondary)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(isSelected ? themeManager.currentTheme.mainColor : Color.clear)
                .clipShape(Capsule())
        }
    }

    private func placeholder() -> some View {
        ZStack {
            Color(UIColor.secondarySystemBackground)
            Image(systemName: (kit?.displayModeValue == 0) ? "cube.box" : "photo")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.3))
        }
    }

    @ViewBuilder
    func editableInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            highlightedTextField("アイテム名", text: $editedTitle, field: .title, fontSize: 18, isBold: true)
            
            HStack(spacing: 8) {
                highlightedTextField("メーカー", text: $editedMaker, field: .maker)
                highlightedTextField("スケール", text: $editedScale, field: .scale)
                highlightedTextField("グレード", text: $editedGrade, field: .grade)
            }
            
            highlightedTextField("シリーズ名", text: $editedSeries, field: .series)
            
            // Add match button here
            databaseMatchButton()
        }
        .padding(.horizontal, 10)
    }

    // ✅ データベース照合ボタン
    func databaseMatchButton() -> some View {
        Button {
            LocalHaptics.tap()
            vm.showDatabaseMatch = true
        } label: {
            HStack {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption)
                Text("データベースと照合して補完")
                    .font(.caption)
                    .bold()
            }
            .foregroundColor(themeManager.currentTheme.mainColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeManager.currentTheme.mainColor.opacity(0.1))
            .cornerRadius(8)
        }
        .padding(.leading, 4)
    }
    
    // ✅ フォーカス対応版 TextField
    private func highlightedTextField(_ placeholder: String, text: Binding<String>, field: Field, fontSize: CGFloat = 14, isBold: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(placeholder)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            TextField(placeholder, text: text)
                .focused($focusedField, equals: field) // フォーカス接続
                .id(field) // スクロールジャンプ用ID
                .font(.system(size: fontSize, weight: isBold ? .bold : .regular))
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == field ? themeManager.currentTheme.mainColor : Color.primary.opacity(0.1), lineWidth: focusedField == field ? 2 : 1)
                )
        }
    }

    @ViewBuilder
    func statusChanger(kit: Kit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ステータス")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
                
            HStack(spacing: 0) {
                Spacer()
                ForEach(KitStatus.allCases) { status in
                    let i = status.rawValue
                    let isSelected = (editedStatus == i)
                    Button {
                        LocalHaptics.select()
                        withAnimation { editedStatus = i; if i == 4 { kit.displayModeValue = 1 } }
                    } label: {
                        VStack(spacing: 4) {
                            Image(status.iconName)
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 30, height: 30)
                                .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : .secondary.opacity(0.3))
                            
                            Text(status.labelShort)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : .secondary)
                        }
                        .padding(.vertical, 8)
                        .frame(width: 55)
                        .background(isSelected ? themeManager.currentTheme.mainColor.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    if i < 4 { Spacer() }
                }
                Spacer()
            }
        }
    }
    
    // ✅ フォーカス対応版 メモ欄
    func memoSection(isLandscape: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("メモ")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            TextField("メモを入力", text: $editedMemo)
                .focused($focusedField, equals: .memo)
                .id(Field.memo)
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focusedField == .memo ? themeManager.currentTheme.mainColor : Color.primary.opacity(0.1), lineWidth: focusedField == .memo ? 2 : 1)
                )
        }
    }

    func updateButtonIconOnly(targetKit: Kit) -> some View {
        Button {
            LocalHaptics.select()
            if checkDuplication(currentKit: targetKit) { vm.showDuplicateAlert = true }
            else { saveChanges(kit: targetKit) }
        } label: {
            VStack(spacing: 4) {
                Image("update")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(themeManager.currentTheme.mainColor)
                Text("更新")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(themeManager.currentTheme.mainColor)
            }
            .frame(width: 60, height: 60)
            .background(Circle().fill(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2))
            .overlay(Circle().stroke(themeManager.currentTheme.mainColor.opacity(0.3), lineWidth: 1))
        }
    }
    
    func deleteButtonIconOnly() -> some View {
        Button {
            LocalHaptics.error()
            vm.showDeleteAlert = true
        } label: {
            VStack(spacing: 4) {
                Image("trash")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(.red)
                Text("リムーブ")
                    .font(.caption2)
                    .bold()
                    .foregroundStyle(.red)
            }
            .frame(width: 60, height: 60)
            .background(Circle().fill(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2))
        }
    }
    
    @ViewBuilder
    func buildLogButtonIconOnly() -> some View {
        if let k = kit, k.statusValue >= 3 {
            Button {
                LocalHaptics.select()
                vm.showBuildLog = true
            } label: {
                Image(systemName: "doc.text.image")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 30, height: 30)
                    .foregroundStyle(themeManager.currentTheme.mainColor)
                    .padding(16)
                    .background(Circle().fill(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2))
            }
        }
    }
    
    func portraitBottomControlBar(targetKit: Kit) -> some View {
        let showLog = targetKit.statusValue >= 3
        let isReserved = targetKit.statusValue == 1
        
        return VStack(spacing: 8) {
            // Row 0: Arrival Button (Prominent)
                if isReserved {
                    Button {
                        LocalHaptics.select()
                        vm.showArrivalScanner = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "box.truck.badge.clock.fill")
                                .font(.system(size: 18))
                            Text("着弾報告 (バーコードスキャン)")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(themeManager.currentTheme.mainColor)
                    .cornerRadius(8)
                    .shadow(color: themeManager.currentTheme.mainColor.opacity(0.3), radius: 4, x: 0, y: 2)
                }
                .padding(.horizontal, 40)
            }
            
            // Row 1: Build Log Button (Above Update Button)
            if showLog {
                HStack {
                    Spacer()
                    buildLogButtonIconOnly()
                }
                .padding(.horizontal, 40)
            }
            
            // Row 2: Standard Controls
            HStack(spacing: 40) {
                deleteButtonIconOnly()
                updateButtonIconOnly(targetKit: targetKit)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 10)
        .padding(.bottom, 20)
        .background(Color(UIColor.systemBackground).opacity(0.95))
    }
    
    private func checkDuplication(currentKit: Kit) -> Bool {
        let title = editedTitle.trimmingCharacters(in: .whitespaces)
        let grade = editedGrade.trimmingCharacters(in: .whitespaces)
        let scale = editedScale.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<Kit>(predicate: #Predicate { kit in
            kit.title == title && kit.grade == grade && kit.scale == scale
        })
        do { return try modelContext.fetch(descriptor).contains { $0.persistentModelID != currentKit.persistentModelID } }
        catch { return false }
    }
    


    private func saveChanges(kit: Kit) {
        kit.title = editedTitle; kit.maker = editedMaker; kit.series = editedSeries
        kit.grade = editedGrade; kit.scale = editedScale; kit.statusValue = editedStatus
        kit.memo = editedMemo; kit.updatedDate = Date()
        
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        self.kit = nil
    }

    private func loadLocalImage(named name: String) -> UIImage? {
        return ImageLinker.loadLocalImage(named: name)
    }

    private func handleImageSelection() {
        guard let t = kit else { return }
        guard let image = vm.tempCompletedImage else { return } // Only handle new images here
        
        let isMyPhoto = (t.displayModeValue == 1)
        
        // Use PhotoSaver to save to Album and get Asset ID
        PhotoSaver.shared.saveImageToCustomAlbum(image) { assetID in
            DispatchQueue.main.async {
                if let id = assetID {
                    // Success: Link Asset
                    withAnimation {
                        if isMyPhoto {
                            t.completedImageURLString = "asset://\(id)"
                             // Clear data if we have asset
                            t.completedImageData = nil
                        } else {
                            t.imageURLString = "asset://\(id)" // Box Art
                            t.imageData = nil
                        }
                        
                        // Force update display mode if Box Art
                        if !isMyPhoto {
                             t.displayModeValue = 0
                        }
                        
                        t.updatedDate = Date()
                    }
                    LocalHaptics.success()
                } else {
                    // Fallback: Save Data directly if PhotoSaver fails
                    print("PhotoSaver failed, falling back to Core Data storage")
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        if isMyPhoto {
                            t.completedImageData = data
                            t.completedImageURLString = nil
                        } else {
                            t.imageData = data
                            t.imageURLString = nil
                        }
                        t.updatedDate = Date()
                        LocalHaptics.warning()
                    }
                }
                
                // Cleanup
                self.vm.tempAssetID = nil
                self.vm.tempCompletedImage = nil
            }
        }
    }
    
    private func deleteMyPhoto() {
        if let t = kit {
            deleteLocalImageFile(named: t.completedImageURLString)
            t.completedImageURLString = nil
            t.displayModeValue = 0
        }
    }

    private func deleteKit() {
        guard let t = kit else { return }
        deleteLocalImageFile(named: t.imageURLString)
        deleteLocalImageFile(named: t.completedImageURLString)
        
        // Record Deletion for Sync
        DeletionManager.shared.recordDeletion(uuid: t.uuid)
        
        modelContext.delete(t)
        self.kit = nil
    }
    
    private func deleteLocalImageFile(named name: String?) {
        ImageLinker.deleteLocalImageFile(named: name)
    }
    
    private func loadAssetImageForEditing(_ id: String) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        if let asset = assets.firstObject {
            PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 2000, height: 2000), contentMode: .aspectFit, options: options) { result, _ in
                if let image = result {
                    DispatchQueue.main.async {
                        self.vm.capturedImageToEdit = ImageEditWrapper(image: image)
                    }
                }
            }
        }
    }
    
    // ✅ Arrival Check Logic
    private func handleArrivalCheck(jan: String) {
        guard let t = kit else { return }
        
        print("Arrival Check: \(jan)")
        
        Task {
            // Ensure DB is loaded (Fix for "No Match" bug on cold start)
            await CSVDataManager.shared.ensureDataLoaded()
            
            await MainActor.run {
                // 1. Search DB
                if let match = CSVDataManager.shared.findByJAN(jan) {
                    // Match Found - Overwrite Core Data
                    withAnimation {
                        t.title = match.title
                        t.maker = match.maker
                        t.series = match.series
                        t.grade = match.grade
                        t.scale = match.scale
                        t.jan = match.jan
                        t.statusValue = 2 // Update to Stock
                        
                        // Keep Memo & Images & UUID
                        t.updatedDate = Date()
                        
                        // Update Local State for UI
                        editedTitle = t.title
                        editedMaker = t.maker
                        editedSeries = t.series
                        editedGrade = t.grade
                        editedScale = t.scale
                        editedStatus = 2
                    }
                    LocalHaptics.success()
                } else {
                    // No Match - Provisional Update
                    withAnimation {
                        t.jan = jan
                        t.statusValue = 2 // Update to Stock
                        t.updatedDate = Date()
                        
                        editedStatus = 2
                    }
                    LocalHaptics.warning()
                }
                
                // After processing, prompt for Box Art if no image exists
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.vm.showArrivalBoxArtAlert = true
                }
            }
        }
    }
}

// MARK: - Alert Modifier
struct KitDetailOverlayAlerts: ViewModifier {
    @Binding var kit: Kit?
    @ObservedObject var vm: KitDetailOverlay_iPhone.ViewModel
    
    
    let isMyPhotoMode: Bool
    let editedTitle: String
    let editedMaker: String
    let editedGrade: String
    let editedScale: String
    
    // Actions
    let handleArrivalCheck: (String) -> Void
    let deleteMyPhoto: () -> Void
    let deleteKit: () -> Void
    let handleImageSelection: () -> Void
    let loadAssetImageForEditing: (String) -> Void
    let updateEditedFields: (CSVKitData) -> Void
    
    @State private var showTrashIcon: Bool = false // Helper for inner state if needed, or pass from parent?
    // Note: showTrashIcon was in parent state. We might need to bind it if alerts depend on it, 
    // but looking at usage, it's used to TRIGGER alert.
    
    func body(content: Content) -> some View {
        content
            .confirmationDialog("着弾確認", isPresented: $vm.showArrivalBoxArtAlert) {
                Button("箱絵を撮影する") {
                    kit?.displayModeValue = 0
                    vm.activePicker = .camera
                }
                Button("アルバムから選択") {
                    kit?.displayModeValue = 0
                    vm.activePicker = .library
                }
                Button("あとで", role: .cancel) { }
            } message: { Text("着弾おめでとうございます！\n続けてパッケージ写真を登録しますか？") }
            .confirmationDialog(isMyPhotoMode ? "自分の写真を更新" : "箱絵を更新", isPresented: $vm.showImageOptions) {
                Button("カメラで撮影") { vm.activePicker = .camera }
                Button("アルバムから選択") { vm.activePicker = .library }
                if !isMyPhotoMode {
                    Button("Webから箱絵を探す") { vm.showWebSearch = true }
                } 
                
                if let k = kit, let _ = k.completedImageURLString, isMyPhotoMode {
                    Button("写真を削除", role: .destructive) { deleteMyPhoto() }
                }
                
                Button("キャンセル", role: .cancel) { }
            }
            .alert("既に登録されています", isPresented: $vm.showDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: { Text("このアイテムは既にコレクションに含まれています。") }
            .alert("手放しますか？", isPresented: $vm.showDeleteAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("手放す (削除)", role: .destructive) { deleteKit() }
            } message: { Text("このデータは完全に削除され、元に戻せません。") }
            .sheet(isPresented: $vm.showWebSearch) {
                if let targetKit = kit {
                    let refinedQuery = "\(editedTitle) \(editedMaker) \(editedGrade) \(editedScale) プラモデル"
                    DetailWebImageSearchModal(kit: targetKit, isPresented: $vm.showWebSearch, initialSearchText: refinedQuery)
                }
            }
            .sheet(isPresented: $vm.showBuildLog) {
                if let k = kit {
                    BuildLogView(kit: k, isPresented: $vm.showBuildLog)
                }
            }
            .sheet(isPresented: $vm.showDatabaseMatch) {
                DatabaseMatchModal(isPresented: $vm.showDatabaseMatch, currentTitle: editedTitle) { selectedItem in
                    updateEditedFields(selectedItem)
                    LocalHaptics.success()
                }
            }
            .background(
                EmptyView()
                    .sheet(isPresented: $vm.showArrivalScanner) {
                         BarcodeScannerView(onFound: { code in
                             handleArrivalCheck(code)
                             vm.showArrivalScanner = false
                         })
                         .edgesIgnoringSafeArea(.all)
                    }
            )
            .background(
                EmptyView()
                    .sheet(item: $vm.activePicker) { type in
                        ImagePicker(
                            sourceType: (type == .camera ? .camera : .photoLibrary),
                            selectedImage: .constant(nil),
                            selectedAssetID: Binding(
                                get: { nil },
                                set: { id in
                                     if let id = id {
                                         vm.activePicker = nil // Explicitly dismiss picker first
                                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                             loadAssetImageForEditing(id)
                                         }
                                     }
                                }
                            ),
                            onCameraCapture: { image in
                                 vm.activePicker = nil
                                 // Delay to allow sheet to dismiss before presenting fullScreenCover
                                 DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                     vm.capturedImageToEdit = ImageEditWrapper(image: image)
                                 }
                            }
                        )
                        .ignoresSafeArea()
                    }
            )
            .fullScreenCover(item: $vm.capturedImageToEdit) { wrapper in
                PerspectiveEditorView(
                    image: wrapper.image,
                    onComplete: { edited in
                        vm.tempCompletedImage = edited
                        handleImageSelection()
                        vm.capturedImageToEdit = nil
                    },
                    onCancel: { vm.capturedImageToEdit = nil }
                )
            }

    }
}
