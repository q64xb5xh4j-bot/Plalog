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
    @ObservedObject private var themeManager = ThemeManager.shared
    
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
    
    @State private var tempCompletedImage: UIImage? = nil
    @State private var tempAssetID: String? = nil
    
    @State private var showImageOptions: Bool = false
    @State private var showWebSearch: Bool = false
    
    enum PickerType: Identifiable {
        case camera, library
        var id: Int { hashValue }
    }
    @State private var activePicker: PickerType? = nil
    
    // ✅ キーボードフォーカス管理用
    enum Field: Hashable {
        case title, maker, scale, grade, series, memo
    }
    @FocusState private var focusedField: Field?
    
    private let orbSize: CGFloat = 70
    
    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            ZStack {
                // 背景ガード
                Color(UIColor.systemBackground)
                    .opacity(0.98)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 背景タップでキーボードを閉じる
                        focusedField = nil
                    }
                
                if let targetKit = kit {
                    VStack(spacing: 0) {
                        if isLandscape {
                            // MARK: - Landscape Layout (V59: Focus Mode)
                            HStack(spacing: 0) {
                                // ✅ 入力中は画像を隠してスペースを確保
                                if focusedField == nil {
                                    ZStack {
                                        Color(UIColor.secondarySystemBackground).ignoresSafeArea()
                                        kitImageSection(kit: targetKit, isExpanded: true)
                                            .padding()
                                    }
                                    .frame(width: geo.size.width * 0.4)
                                    .transition(.move(edge: .leading)) // アニメーション
                                }
                                
                                // [右カラム] 情報エリア (通常60% -> 入力時100%)
                                VStack(spacing: 0) {
                                    // ScrollViewReaderで特定位置へのジャンプを可能に
                                    ScrollViewReader { proxy in
                                        ScrollView {
                                            VStack(alignment: .leading, spacing: 16) {
                                                Spacer().frame(height: 10)
                                                
                                                editableInfoSection()
                                                
                                                Divider()
                                                
                                                statusChanger(kit: targetKit)
                                                
                                                Divider()
                                                
                                                // 横画面用下部エリア
                                                HStack(alignment: .bottom, spacing: 16) {
                                                    memoSection(isLandscape: true)
                                                        .frame(maxWidth: focusedField == nil ? 200 : .infinity) // 入力時は広げる
                                                    
                                                    // 入力中はボタンを隠してスペースを稼ぐのもありだが、今回は維持
                                                    if focusedField == nil {
                                                        HStack(spacing: 12) {
                                                            updateButtonIconOnly(targetKit: targetKit)
                                                            deleteButtonIconOnly()
                                                        }
                                                    } else {
                                                        // 入力中は「閉じる」ボタンを表示してあげると親切
                                                        Button("完了") { focusedField = nil }
                                                            .buttonStyle(.borderedProminent)
                                                            .tint(themeManager.currentTheme.mainColor)
                                                    }
                                                    
                                                    // オーブ回避用スペーサー(入力中はオーブも隠れるなら不要だが念のため)
                                                    if focusedField == nil {
                                                        Spacer().frame(width: 90)
                                                    }
                                                }
                                                .padding(.bottom, 20)
                                                
                                                Spacer().frame(height: 300) // キーボード用の巨大な余白
                                            }
                                            .padding(.horizontal, 20)
                                            // ✅ フォーカス変更時に自動スクロール
                                                .onChange(of: focusedField) { _, newValue in
                                                    if let field = newValue {
                                                        LocalHaptics.tap()
                                                        withAnimation {
                                                            proxy.scrollTo(field, anchor: .center)
                                                        }
                                                    }
                                                }
                                        }
                                    }
                                }
                                .frame(width: focusedField == nil ? geo.size.width * 0.6 : geo.size.width)
                            }
                        } else {
                            // MARK: - Portrait Layout (V56維持)
                            ScrollViewReader { proxy in
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 16) {
                                        kitImageSection(kit: targetKit, isExpanded: false)
                                        
                                        editableInfoSection()
                                        
                                        Divider().padding(.horizontal, 10)
                                        
                                        memoSection(isLandscape: false)
                                            .padding(.horizontal, 10)
                                        
                                        statusChanger(kit: targetKit)
                                        
                                        Spacer().frame(height: 300) // キーボード回避用余白
                                    }
                                    .padding(.top, 10)
                                    .onChange(of: focusedField) { _, newValue in
                                        if let field = newValue {
                                            withAnimation {
                                                proxy.scrollTo(field, anchor: .center)
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 入力中はコントロールバーを隠す（画面を広く使うため）
                            if focusedField == nil {
                                portraitBottomControlBar(targetKit: targetKit)
                            }
                        }
                    }
                    
                    // Floating Orb (入力中は隠すか、邪魔にならないようにする)
                    if focusedField == nil {
                        if isLandscape {
                            BlueOrbView(isAnimating: true, size: orbSize)
                                .position(x: geo.size.width - 60, y: geo.size.height - 60)
                                .onTapGesture {
                                    LocalHaptics.tap()
                                    self.kit = nil
                                }
                        } else {
                            orbLayer(geo: geo)
                        }
                    }
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: focusedField) // レイアウト変化のアニメーション
        .onAppear { initializeStates() }
        
        // --- Alerts & Sheets ---
        .confirmationDialog(isMyPhotoMode ? "自分の写真を更新" : "箱絵を更新", isPresented: $showImageOptions) {
            if !isMyPhotoMode {
                Button("Webから箱絵を探す") { showWebSearch = true }
            } else {
                Button("カメラで撮影") { activePicker = .camera }
                Button("アルバムから選択") { activePicker = .library }
                if let k = kit, let _ = k.completedImageURLString {
                    Button("写真を削除", role: .destructive) { deleteMyPhoto() }
                }
            }
            Button("キャンセル", role: .cancel) { }
        }
        .alert("既に登録されています", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: { Text("このアイテムは既にコレクションに含まれています。") }
        .alert("手放しますか？", isPresented: $showDeleteAlert) {
            Button("キャンセル", role: .cancel) { showTrashIcon = false }
            Button("手放す (削除)", role: .destructive) { deleteKit() }
        } message: { Text("このデータは完全に削除され、元に戻せません。") }
        .sheet(isPresented: $showWebSearch) {
            if let targetKit = kit {
                let refinedQuery = "\(editedTitle) \(editedMaker) \(editedGrade) \(editedScale) プラモデル"
                DetailWebImageSearchModal(kit: targetKit, isPresented: $showWebSearch, initialSearchText: refinedQuery)
            }
        }
        .sheet(item: $activePicker) { type in
            ImagePicker(
                sourceType: (type == .camera ? .camera : .photoLibrary),
                selectedImage: $tempCompletedImage,
                selectedAssetID: $tempAssetID
            )
            .onDisappear { handleImageSelection() }
            .ignoresSafeArea()
        }
    }
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
    private func kitImageSection(kit: Kit, isExpanded: Bool) -> some View {
        VStack(spacing: 12) {
            ZStack {
                let hasUserPhoto = (kit.completedImageURLString != nil && !kit.completedImageURLString!.isEmpty)
                let isUserChoiceMyPhoto = (kit.displayModeValue == 1)
                let showPhoto = isUserChoiceMyPhoto && hasUserPhoto
                let p: String? = showPhoto ? kit.completedImageURLString : kit.imageURLString
                
                if let path = p, !path.isEmpty {
                    if path.hasPrefix("http") {
                        AsyncImage(url: URL(string: path)) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFit()
                            } else { placeholder() }
                        }
                    } else if path.hasPrefix("asset://") {
                        PhAssetImage(localIdentifier: String(path.dropFirst("asset://".count))).scaledToFit()
                    } else if let uiImage = loadLocalImage(named: path) {
                        Image(uiImage: uiImage).resizable().scaledToFit()
                    } else { placeholder() }
                } else { placeholder() }
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: showPhoto ? "camera.fill" : "magnifyingglass")
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
            .onTapGesture {
                LocalHaptics.tap()
                showImageOptions = true
            }
            
            HStack(spacing: 0) {
                modeButton(title: "Box Art", targetValue: 0)
                modeButton(title: "My Photo", targetValue: 1)
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
    private func editableInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            highlightedTextField("アイテム名", text: $editedTitle, field: .title, fontSize: 18, isBold: true)
            
            HStack(spacing: 8) {
                highlightedTextField("メーカー", text: $editedMaker, field: .maker)
                highlightedTextField("スケール", text: $editedScale, field: .scale)
                highlightedTextField("グレード", text: $editedGrade, field: .grade)
            }
            
            highlightedTextField("シリーズ名", text: $editedSeries, field: .series)
        }
        .padding(.horizontal, 10)
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
    private func statusChanger(kit: Kit) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("STATUS")
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
    private func memoSection(isLandscape: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("MEMO")
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

    private func updateButtonIconOnly(targetKit: Kit) -> some View {
        Button {
            LocalHaptics.select()
            if checkDuplication(currentKit: targetKit) { showDuplicateAlert = true }
            else { saveChanges(kit: targetKit) }
        } label: {
            Image("update")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(themeManager.currentTheme.mainColor)
                .padding(16)
                .background(Circle().fill(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2))
        }
    }
    
    private func deleteButtonIconOnly() -> some View {
        Button {
            LocalHaptics.error()
            showDeleteAlert = true
        } label: {
            Image("trash")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 30, height: 30)
                .foregroundStyle(.red)
                .padding(16)
                .background(Circle().fill(Color(UIColor.systemBackground)).shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2))
        }
    }
    
    private func portraitBottomControlBar(targetKit: Kit) -> some View {
        VStack {
            // Divider() はV58で削除済み
            HStack {
                deleteButtonIconOnly()
                Spacer()
                Color.clear.frame(width: orbSize, height: orbSize)
                Spacer()
                updateButtonIconOnly(targetKit: targetKit)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .padding(.bottom, 20)
            .background(Color(UIColor.systemBackground).opacity(0.95))
        }
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
    
    private func orbLayer(geo: GeometryProxy) -> some View {
        let x = geo.size.width / 2
        let y = geo.size.height - 65
        return BlueOrbView(isAnimating: true, size: orbSize)
            .position(x: x, y: y)
            .zIndex(3000)
            .onTapGesture {
                LocalHaptics.tap()
                self.kit = nil
            }
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
        
        let isMyPhoto = (t.displayModeValue == 1)
        let oldFilename = isMyPhoto ? t.completedImageURLString : t.imageURLString
        var newLinkString: String? = nil
        
        if let assetID = tempAssetID {
            newLinkString = "asset://" + assetID
        } else if let img = tempCompletedImage {
            guard let data = img.jpegData(compressionQuality: 0.8) else { return }
            let name = "img_\(UUID().uuidString).jpg"
            let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
            try? data.write(to: url)
            newLinkString = name
        }
        
        if let newValue = newLinkString {
            deleteLocalImageFile(named: oldFilename)
            if isMyPhoto {
                t.completedImageURLString = newValue
            } else {
                t.imageURLString = newValue
            }
        }
        
        tempAssetID = nil
        tempCompletedImage = nil
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
        modelContext.delete(t)
        self.kit = nil
    }
    
    private func deleteLocalImageFile(named name: String?) {
        ImageLinker.deleteLocalImageFile(named: name)
    }
}
