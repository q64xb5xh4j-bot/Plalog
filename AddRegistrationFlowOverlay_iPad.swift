//
//  AddRegistrationFlowOverlay_iPad.swift V51
//  Plalog
//
//  Created by (User) on 2026/01/03.
//  iPad専用の実装（Ultra Model Number Search & 縫合ロジック統合版）
//  修正点:
//  - バージョン管理ルールに基づき更新 (V50 -> V51)
//  - 決定ボタン(icon_select_confirm)の位置を「左寄せ」に変更し、右下のオーブと物理的に距離を確保
//
//

import SwiftUI
import SwiftData
import Combine
import Photos

struct RegistrationFlow_iPad: View {
    @Binding var isPresented: Bool
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // ✅ GOD MODE Settings
    @AppStorage("googleApiKey") private var googleApiKey: String = ""
    @AppStorage("isGodModeEnabled") private var isGodModeEnabled: Bool = false
    
    @State private var stack: [Step] = [.status]
    @State private var selectedStatus: StatusKey? = nil
    @State private var selectedMethod: MethodKey? = nil
    @State private var query: String = ""
    @State private var searchScale: String = ""
    @State private var searchGrade: String = ""
    @State private var searchSeries: String = "" // ✅ Added for Pulldown
    @State private var searchMaker: String = "" // ✅ Added State
    @State private var availableSeries: [String] = []
    @State private var availableGrades: [String] = []
    @State private var availableScales: [String] = []
    @State private var availableMakers: [String] = [] // ✅ Added
    @State private var results: [Candidate] = []
    @State private var isSearching: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    @FocusState private var isSearchFocused: Bool
    
    @State private var formTitle: String = ""; @State private var formMaker: String = ""; @State private var formScale: String = ""
    @State private var formSeries: String = ""; @State private var formGrade: String = ""; @State private var formJAN: String = ""; @State private var formMemo: String = ""
    
    // ✅ 2026-01-04 iPad Sync: Image Picker State
    @State private var formImageURLString: String? = nil // ✅ Changed to String
    @State private var showImagePicker: Bool = false
    @State private var showImageSourceDialog: Bool = false // ✅ Added for Unified UI
    
    @State private var selectedFilter: String? = nil // ✅ Filter Chip State
    
    // ✅ Discovery Debug
    @State private var showDiscoveryError: Bool = false
    @State private var discoveryErrorMessage: String = ""
    
    // ✅ OCR State
    @State private var showOCRCamera: Bool = false
    @State private var showNativeCamera: Bool = false // ✅ Added
    @State private var pickerSourceType: UIImagePickerController.SourceType = .camera // ✅ Added
    @State private var ocrTargetStatus: StatusKey = .stock
    @State private var showOCRSuggestions: Bool = false
    @State private var ocrSuggestions: [Candidate] = []
    @State private var pendingOCRResult: Bool = false // Triggers sheet via onChange
    
    // ✅ Correction & Auto-Fill State
    @State private var isCorrectionMode: Bool = false
    @State private var isCloudDiscovered: Bool = false
    
    // ✅ OCR Editing State
    @State private var ocrEditingTitle: String = ""
    @State private var ocrEditingMaker: String = ""
    @State private var ocrEditingSeries: String = "" // Added
    @State private var ocrEditingScale: String = ""
    @State private var ocrEditingGrade: String = ""
    
    // ✅ Image Editing State
    @State private var capturedImageToEdit: UIImage? = nil
    
    // Web Search
    @State private var webSearchQuery: String = ""
    
    private var current: Step { stack.last ?? .status }
    private let orbSize: CGFloat = 70
    
    // ✅ Search Logic Constants
    private let knownSeriesRules = ["ガンダム", "ザク", "ジム", "グフ", "ドム", "ゲルググ", "ズゴック", "アッガイ", "ジオング"]

    // MARK: - Reusable OCR Search Logic
    private func performOCRSearch(title: String, maker: String, jan: String?, scale: String? = nil, grade: String? = nil, series: String? = nil) {
        Task {
            // 2. Handle JAN & Discovery Check
            let queryIsJan = query.allSatisfy({ $0.isNumber }) && (query.count == 13 || query.count == 8)
            // Use provided JAN, or formJAN, or query if valid
            let finalJAN = (jan?.isEmpty == false ? jan : nil) ?? (!formJAN.isEmpty ? formJAN : (queryIsJan ? query : ""))
            
            print("DEBUG: Performing OCR Search. Title: '\(title)', JAN: '\(finalJAN)'")
            
            var status: DiscoveryStatus = .firstDiscovery
            var cTitle = title
            var cMaker = maker
            var cScale = scale ?? ""
            var cSeries = series ?? ""
            var cGrade = grade ?? ""

            if !finalJAN.isEmpty {
                // Async Cloud Check (JAN)
                print("DEBUG: Starting Cloud Check for JAN: \(finalJAN)")
                if let d = await DiscoveryManager.shared.checkDiscovery(jan: finalJAN) {
                    print("DEBUG: Cloud Check HIT! Discoverer: \(d.discovererName)")
                    status = .discovered(by: d.discovererName, date: d.discoveredDate, isLocked: d.isLocked, voteCount: d.voteCount)
                    cTitle = d.title
                    cMaker = d.maker
                    cScale = d.scale
                    cSeries = d.series
                    cGrade = d.grade
                } else {
                    print("DEBUG: Cloud Check MISS. Treating as First Discovery.")
                }
            } else {
                print("DEBUG: No JAN available for Cloud Check.")
            }
            
            // Hybrid Approximation Search (Text Based)
            // ✅ Include user-entered Scale/Grade in search query to filter results
            var searchQuery = cTitle
            if !cScale.isEmpty { searchQuery += " \(cScale)" }
            if !cGrade.isEmpty { searchQuery += " \(cGrade)" }
            // Optional: Include Series in search if needed
            if !cSeries.isEmpty { searchQuery += " \(cSeries)" }
            if !cGrade.isEmpty { searchQuery += " \(cGrade)" }
            
            let localHitTuples = CSVDataManager.shared.searchApproximate(query: searchQuery, modelContext: modelContext)
            
            // Build suggestions array first (before MainActor.run)
            var allSuggestions: [Candidate] = []
            for (item, score) in localHitTuples {
                var c = item.toCandidate()
                c.matchScore = score
                allSuggestions.append(c)
            }
            allSuggestions.sort { ($0.matchScore ?? 0) > ($1.matchScore ?? 0) }
            
            // ✅ Local SwiftData search for discovery status (fast, no CloudKit errors)
            print("DEBUG: Local Hits: \(localHitTuples.count)")
            for i in 0..<min(allSuggestions.count, 10) {
                let candidate = allSuggestions[i]
                let title = candidate.title
                let jan = candidate.jan
                print("DEBUG: Local Candidate: \(title) (JAN: \(jan)) Score: \(candidate.matchScore ?? 0)")
                
                // 1. Try JAN Search first (Most reliable)
                if !jan.isEmpty, let cached = DiscoveryManager.shared.searchLocalByJAN(jan: jan, modelContext: modelContext) {
                    allSuggestions[i].discoveryStatus = .discovered(
                        by: cached.discovererName,
                        date: cached.discoveredDate,
                        isLocked: cached.isLocked,
                        voteCount: cached.voteCount
                    )
                    print("DEBUG: ✅ Local JAN cache hit: '\(title)' discovered by \(cached.discovererName)")
                }
                // 2. Fallback to Title Search
                else if let cached = DiscoveryManager.shared.searchLocalByTitle(title: title, modelContext: modelContext) {
                    allSuggestions[i].discoveryStatus = .discovered(
                        by: cached.discovererName,
                        date: cached.discoveredDate,
                        isLocked: cached.isLocked,
                        voteCount: cached.voteCount
                    )
                    print("DEBUG: ✅ Local Title cache hit: '\(title)' discovered by \(cached.discovererName)")
                }
            }
            
            await MainActor.run {
                // 3. Create Candidate (Raw OCR or JAN Result) (Used for direct registration)
                // Note: We don't override formImageURLString here, it is set globally.
                var candidate = Candidate(title: cTitle, maker: cMaker, scale: cScale, series: cSeries, grade: cGrade, jan: finalJAN, imageURLString: formImageURLString, discoveryStatus: status)
                
                ocrSuggestions = allSuggestions
                print("DEBUG: Final ocrSuggestions count: \(ocrSuggestions.count)")
                
                // Prepare form for POTENTIAL manual registration (using the raw or cloud result)
                prepareForm(from: candidate)
                
                // Set editing default values
                ocrEditingTitle = cTitle
                ocrEditingMaker = cMaker
                ocrEditingSeries = cSeries // Added
                ocrEditingScale = cScale
                ocrEditingGrade = cGrade
                
                // Set flag - onChange will handle sheet presentation
                pendingOCRResult = true
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景色変更
                Color(UIColor.systemBackground).ignoresSafeArea()
                    .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Button {
                             LocalHaptics.tap()
                             if stack.count > 1 { stack.removeLast() } else { isPresented = false }
                        } label: {
                             Image(systemName: stack.count > 1 ? "chevron.backward" : "xmark")
                                 .font(.system(size: 20, weight: .bold))
                                 .foregroundStyle(themeManager.currentTheme.mainColor)
                                 .padding(12)
                                 .background(Color(UIColor.secondarySystemBackground))
                                 .clipShape(Circle())
                        }.buttonStyle(.plain)
                        
                        Spacer()
                        Text("アイテム登録").font(.system(size: 20, weight: .bold)).foregroundStyle(.primary)
                        Spacer()
                        
                        // Balance
                        Color.clear.frame(width: 44, height: 44)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .overlay(Divider(), alignment: .bottom)
                    
                    content(size: geo.size).frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if !isSearching {
                        if case .scan = current {} else { bottomBar }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) { self.keyboardHeight = keyboardFrame.height }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { self.keyboardHeight = 0 }
        }

        .onChange(of: pendingOCRResult) { _, newValue in
            if newValue {
                print("DEBUG: onChange triggered. ocrSuggestions count: \(ocrSuggestions.count)")
                showOCRSuggestions = true
                pendingOCRResult = false
            }
        }
        .sheet(isPresented: $showOCRSuggestions, onDismiss: { ocrSuggestions = []; showOCRCamera = false }) {
            NavigationStack {
                List {
                    // ✅ Modified Header: Editable Fields & Actions
                    Section {
                        VStack(spacing: 12) {
                            // Text Fields
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "tag.fill").foregroundStyle(.secondary)
                                    TextField("商品名", text: $ocrEditingTitle)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                }
 
                                // Series Picker (Replaces Maker in Middle)
                                EditableSelectionField(
                                    label: "シリーズ",
                                    selection: $ocrEditingSeries,
                                    options: availableSeries
                                )
                                
                                // Bottom Row: Maker, Grade, Scale
                                HStack(spacing: 8) {
                                    // Maker Picker
                                    EditableSelectionField(
                                        label: "メーカー",
                                        selection: $ocrEditingMaker,
                                        options: availableMakers
                                    )
                                    
                                    // Grade Picker
                                    EditableSelectionField(
                                        label: "グレード",
                                        selection: $ocrEditingGrade,
                                        options: availableGrades
                                    )
                                    
                                    // Scale Picker
                                    EditableSelectionField(
                                        label: "スケール",
                                        selection: $ocrEditingScale,
                                        options: availableScales
                                    )
                                }
                            }
                            .padding(.bottom, 4)
                            
                            // Action Buttons
                            HStack(spacing: 12) {
                                // Re-search Button (Primary Emphasis)
                                Button {
                                    LocalHaptics.tap()
                                    // Trigger Re-search
                                    performOCRSearch(title: ocrEditingTitle, maker: ocrEditingMaker, jan: nil, scale: ocrEditingScale, grade: ocrEditingGrade, series: ocrEditingSeries)
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("再検索")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white) // Primary text color
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(themeManager.currentTheme.mainColor) // Primary background
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(PlainButtonStyle()) // Needed in List
                                
                                // Direct Register Button (Secondary Emphasis)
                                Button {
                                    LocalHaptics.select()
                                    showOCRSuggestions = false
                                    
                                    // Use edited values
                                    let raw = Candidate(
                                        title: ocrEditingTitle,
                                        maker: ocrEditingMaker,
                                        scale: ocrEditingScale,
                                        series: ocrEditingSeries, // Use Edited Series
                                        grade: ocrEditingGrade,
                                        jan: formJAN,
                                        imageURLString: formImageURLString,
                                        discoveryStatus: .firstDiscovery
                                    ).cleanedForRegistration()
                                    prepareForm(from: raw) // Ensure form values are synced
                                    push(.register(ocrTargetStatus, raw))
                                } label: {
                                    HStack {
                                        Text("入力を確定")
                                        Image(systemName: "arrow.right")
                                    }
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(themeManager.currentTheme.mainColor) // Text only
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(themeManager.currentTheme.mainColor.opacity(0.1)) // Light background
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    } header: { Text("読み取り結果の修正") }
                    
                    Section {
                        if ocrSuggestions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("似ているキットは見つかりませんでした")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("テキストを修正して「再検索」するか、\n「入力を確定」して次へ進んでください。")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(ocrSuggestions) { s in
                                Button {
                                    LocalHaptics.select()
                                    showOCRSuggestions = false
                                    
                                    let capturedImage = formImageURLString
                                    var finalS = s.cleanedForRegistration() // ✅ Apply cleanup
                                    finalS.imageURLString = capturedImage
                                    // Preserve discovery status from original suggestion
                                    finalS.discoveryStatus = s.discoveryStatus
                                    
                                    // ✅ Preserve JAN from Barcode Scan if available
                                    if !formJAN.isEmpty && (finalS.jan.isEmpty || finalS.jan != formJAN) {
                                        print("DEBUG: Preserving Scanned JAN: \(formJAN) over Suggestion JAN: \(finalS.jan)")
                                        finalS.jan = formJAN
                                    }

                                    prepareForm(from: finalS)
                                    push(.register(ocrTargetStatus, finalS))
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text(s.title).font(.headline).foregroundStyle(.primary)
                                            Spacer()
                                            // ✅ Discovery Badge
                                            if case .discovered(_, _, _, _) = s.discoveryStatus {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundStyle(.green)
                                                    Text("発見済み")
                                                        .font(.caption2)
                                                        .foregroundStyle(.green)
                                                }
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.green.opacity(0.1))
                                                .clipShape(Capsule())
                                            }
                                        }
                                        HStack {
                                            if let score = s.matchScore {
                                                Text("\(Int(score * 100))%")
                                                    .font(.system(size: 12, weight: .bold))
                                                    .foregroundStyle(score > 0.8 ? .green : .orange)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.secondary.opacity(0.1))
                                                    .clipShape(Capsule())
                                            }
                                            Text(s.maker).font(.caption).bold()
                                            Text(s.scale).font(.caption)
                                            Text(s.series).font(.caption).foregroundStyle(.secondary)
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    } header: { Text("データベースからの提案") }
                }
                .navigationTitle("似ているアイテム")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
            .onAppear {
                layoutFilters()
            }
        }
        .alert("検索エラー", isPresented: $showErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(errorMessage) }
        // ✅ 2026-01-04 iPad Sync: Image Search Sheet
        .sheet(isPresented: $showImagePicker) {
            WebImageSearchModal(
                kit: nil,
                isPresented: $showImagePicker,
                initialQuery: formTitle.isEmpty ? candidateTitleForSearch : formTitle,
                onImageSelected: { selectedString in
                    // ✅ Stringを受け取る
                    formImageURLString = selectedString
                    
                    // 候補オブジェクトの表示も更新 (一時的)
                    if case .register(let s, var c) = current {
                       c.imageURLString = selectedString
                       // Stateを更新するためにstackを書き換える
                       stack[stack.count-1] = .register(s, c)
                    }
                }
            )
        }
        .fullScreenCover(isPresented: $showOCRCamera) {
            OCRCameraView { image, title, maker in
                // 1. Handle Image
                if let image = image {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        try? data.write(to: tempURL)
                        DispatchQueue.main.async {
                            formImageURLString = tempURL.absoluteString
                        }
                    }
                }
                
                // Reset editing state
                DispatchQueue.main.async {
                    ocrEditingTitle = title
                    ocrEditingMaker = maker ?? ""
                    ocrEditingSeries = "" // Added
                }
                
                // Run Search
                performOCRSearch(title: title, maker: maker ?? "", jan: nil)
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showNativeCamera) {
            ImagePicker(
                sourceType: pickerSourceType,
                selectedImage: .constant(nil),
                selectedAssetID: Binding(
                    get: { nil },
                    set: { id in
                        if let id = id { formImageURLString = "asset://\(id)" }
                    }
                ),
                onCameraCapture: { image in
                    // Camera -> Edit Flow
                    showNativeCamera = false
                    capturedImageToEdit = image
                }
            )
            .ignoresSafeArea()
        }
        // ✅ Image Editor Sheet
        .fullScreenCover(isPresented: Binding(get: { capturedImageToEdit != nil }, set: { if !$0 { capturedImageToEdit = nil } })) {
            if let img = capturedImageToEdit {
                ImageEditorView(
                    image: img,
                    onComplete: { edited in
                        // Save Process
                        PhotoSaver.shared.saveImageToCustomAlbum(edited) { id in
                            if let id = id {
                                DispatchQueue.main.async {
                                    formImageURLString = "asset://\(id)"
                                    // Update candidate if needed
                                    if case .register(let s, var c) = current {
                                        c.imageURLString = "asset://\(id)"
                                        // Update stack? iPad uses 'current' often but modifies via stack
                                        // Actually current is computed.
                                        // Need to update stack.
                                        let lastIndex = stack.count - 1
                                        if lastIndex >= 0 {
                                            stack[lastIndex] = .register(s, c)
                                        }
                                    }
                                }
                            }
                        }
                        capturedImageToEdit = nil
                    },
                    onCancel: {
                        capturedImageToEdit = nil
                    }
                )
            }
        }
        .confirmationDialog("画像の設定", isPresented: $showImageSourceDialog) {
            Button("箱を撮影して自動入力 (OCR)") {
                LocalHaptics.select()
                showOCRCamera = true
            }
            Button("カメラで撮影") {
                pickerSourceType = .camera
                showNativeCamera = true
            }
            Button("ライブラリから選択") {
                pickerSourceType = .photoLibrary
                showNativeCamera = true
            }
            Button("Webから検索") {
                showImagePicker = true
            }
            if formImageURLString != nil {
                Button("画像を削除", role: .destructive) {
                    formImageURLString = nil
                }
            }
            Button("キャンセル", role: .cancel) { }
        }
    }
    
    @ViewBuilder
    private func content(size: CGSize) -> some View {
        switch current {
        case .status:
            ScrollView {
                VStack(spacing: 40) {
                    Spacer().frame(height: 20)
                    VStack(spacing: 16) {
                        Image(systemName: "square.grid.2x2").font(.system(size: 60)).foregroundStyle(themeManager.currentTheme.mainColor)
                        Text("状態を選択").font(.title2.bold()).foregroundStyle(.primary)
                    }
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 20)], spacing: 20) {
                        ForEach(StatusKey.allCases) { s in
                            Button {
                                LocalHaptics.select()
                                selectedStatus = s
                                if s.allowsBarcode { push(.method(s)) } else { push(.search(s)) }
                            } label: {
                                VStack(spacing: 16) {
                                    Image(s.assetName).resizable().renderingMode(.template).scaledToFit().frame(width: 50, height: 50).foregroundStyle(themeManager.currentTheme.mainColor)
                                    Text(s.label).font(.headline).foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 30)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }.padding(.horizontal, 40)
                    Spacer()
                }
            }
        case .method(let s):
            ScrollView {
                 VStack(spacing: 40) {
                     Spacer().frame(height: 20)
                     VStack(spacing: 16) {
                         Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundStyle(themeManager.currentTheme.mainColor)
                         Text("登録方法を選択").font(.title2.bold()).foregroundStyle(.primary)
                     }
                     
                     HStack(spacing: 30) {
                         methodCardiPad(key: .barcode, status: s, icon: "barcode.viewfinder", title: "バーコード", desc: "JANコードスキャン", badge: "推奨")
                         methodCardiPad(key: .scan, status: s, icon: "camera.fill", title: "箱を撮影", desc: "写真から自動入力") // Icon and Text changed
                         methodCardiPad(key: .text, status: s, icon: "keyboard", title: "キーワード検索", desc: "手動入力・検索")
                     }.padding(.horizontal, 40)
                     Spacer()
                 }
            }
        case .barcode(let s):
            VStack(spacing: 0) {
                VStack(spacing: 16) { Image("icon_barcode").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor); Text("バーコードをスキャン").font(.system(size: 16, weight: .bold)).foregroundStyle(.secondary) }.padding(.top, 40).padding(.bottom, 40)
                ZStack {
                    BarcodeScannerView { code in handleScan(code: code, status: s) }.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1))
                    RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(themeManager.currentTheme.mainColor, lineWidth: 2).frame(width: 300, height: 150)
                    if isSearching { Color.black.opacity(0.4); ProgressView("情報を縫合中...").tint(.white) }
                }.padding(.horizontal, 40).frame(maxHeight: 500)
                
                // Fallback Button
                Button {
                    LocalHaptics.select()
                    push(.scan(s))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                        Text("読み取れない場合は箱を撮影").font(.headline)
                    }
                    .foregroundStyle(themeManager.currentTheme.mainColor)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(themeManager.currentTheme.mainColor.opacity(0.1))
                    .clipShape(Capsule())
                }.padding(.top, 30)
                
                Spacer()
            }
        case .scan(let s):
            // Placeholder: Logic handled by fullScreenCover
            // Launch Camera immediately when this view appears (or waiting for trigger)
            // But since we trigger via 'showOCRCamera', we can just show a loader here or empty.
            VStack {
                Spacer()
                ProgressView("カメラを起動中...")
                Spacer()
            }
            .onAppear {
                self.ocrTargetStatus = s
                
                // Only auto-open camera if we are not showing results and have no data
            }
        case .search(let s):
            // ✅ Enhanced Search Layer (Pulldown)
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 10) {
                    Image("icon_text_search").resizable().renderingMode(.template).scaledToFit().frame(width: 40, height: 40).foregroundStyle(themeManager.currentTheme.mainColor)
                    Text("データベース検索").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(themeManager.currentTheme.mainColor)
                }.padding(.top, 20).padding(.bottom, 10)
                
                // ✅ Search Form
                VStack(spacing: 12) {
                    // Keyword Field
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("キーワード (例: RX-78)", text: $query)
                            .focused($isSearchFocused)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .submitLabel(.search)
                            .onSubmit { runFilteredSearch() }
                        
                        if !query.isEmpty {
                            Button { query = ""; runFilteredSearch() } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    // Filters Row
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            // Maker Picker (Added)
                            Menu {
                                Button("すべて") { searchMaker = ""; runFilteredSearch() }
                                ForEach(availableMakers, id: \.self) { m in
                                    Button(m) { searchMaker = m; runFilteredSearch() }
                                }
                            } label: {
                                filterButtonLabel(title: searchMaker.isEmpty ? "メーカー" : searchMaker, isActive: !searchMaker.isEmpty)
                            }
                            
                            // Series Picker
                            Menu {
                                Button("すべて") { searchSeries = ""; runFilteredSearch() }
                                ForEach(availableSeries, id: \.self) { s in
                                    Button(s) { searchSeries = s; runFilteredSearch() }
                                }
                            } label: {
                                filterButtonLabel(title: searchSeries.isEmpty ? "シリーズ" : searchSeries, isActive: !searchSeries.isEmpty)
                            }
                            
                            // Grade Picker
                            Menu {
                                Button("すべて") { searchGrade = ""; runFilteredSearch() }
                                ForEach(availableGrades, id: \.self) { g in
                                    Button(g) { searchGrade = g; runFilteredSearch() }
                                }
                            } label: {
                                filterButtonLabel(title: searchGrade.isEmpty ? "グレード" : searchGrade, isActive: !searchGrade.isEmpty)
                            }
                            
                            // Scale Picker
                            Menu {
                                Button("すべて") { searchScale = ""; runFilteredSearch() }
                                ForEach(availableScales, id: \.self) { s in
                                    Button(s) { searchScale = s; runFilteredSearch() }
                                }
                            } label: {
                                filterButtonLabel(title: searchScale.isEmpty ? "スケール" : searchScale, isActive: !searchScale.isEmpty)
                            }
                            
                            // Clear All
                            if !searchMaker.isEmpty || !searchSeries.isEmpty || !searchGrade.isEmpty || !searchScale.isEmpty {
                                Button {
                                    LocalHaptics.tap()
                                    searchMaker = ""
                                    searchSeries = ""
                                    searchGrade = ""
                                    searchScale = ""
                                    runFilteredSearch()
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(8)
                                        .background(Color.secondary)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 12)
                
                Divider()
                
                // Results Area
                if isSearching {
                    Spacer(); ProgressView("検索中...").tint(themeManager.currentTheme.mainColor); Spacer()
                } else if results.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        if query.isEmpty && searchMaker.isEmpty && searchSeries.isEmpty && searchGrade.isEmpty && searchScale.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(.secondary)
                                Text("条件を選択して検索").foregroundStyle(.secondary)
                            }
                        } else {
                            Text("条件に一致するアイテムはありません").foregroundStyle(.secondary)
                            Button("手動で登録する") {
                                let c = Candidate(title: query, maker: searchMaker.isEmpty ? "BANDAI SPIRITS" : searchMaker, scale: searchScale, series: searchSeries, grade: searchGrade, jan: "", imageURLString: nil)
                                prepareForm(from: c)
                                push(.register(s, c))
                            }
                            .font(.headline)
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                        }
                    }
                    Spacer()
                } else {
                    ScrollView { 
                        LazyVStack(spacing: 12) { 
                            ForEach(results) { r in iPadManualSearchResultRow(r, status: s) } 
                            Text("\(results.count)件 ヒット").font(.caption).foregroundStyle(.secondary).padding(.top, 10)
                            Spacer().frame(height: 100)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100) 
                    }
                }
            }
            .onAppear { layoutFilters() }
            .task { 
                if query.isEmpty { try? await Task.sleep(nanoseconds: 600_000_000); isSearchFocused = true } 
            }
        case .register(_, let c):
            HStack(spacing: 0) {
                // Left Pane: Image Area (Unified Trigger)
                ZStack {
                    Color(UIColor.secondarySystemBackground).opacity(0.3)
                    
                    VStack(spacing: 30) {
                        candidateImageDisplay(candidate: c)
                        
                        Text("画像をタップして設定")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }.frame(width: size.width * 0.5)
                
                // Right Pane: Info Form
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 24) {
                            Spacer().frame(height: 10)
                            
                            // Discovery Badge
                            DiscoveryStatusBadge(
                                candidate: c,
                                isCorrectionMode: $isCorrectionMode,
                                onUpdate: {
                                    LocalHaptics.select()
                                    try? await DiscoveryManager.shared.updateDiscovery(jan: c.jan, title: formTitle, maker: formMaker, scale: formScale, grade: formGrade)
                                    await MainActor.run { isCorrectionMode = false; LocalHaptics.success() }
                                },
                                onVote: {
                                    LocalHaptics.select()
                                    _ = try? await DiscoveryManager.shared.voteDiscovery(jan: c.jan)
                                    await MainActor.run { LocalHaptics.success() }
                                }
                            )
                            
                            // Edit Icon
                            VStack(spacing: 16) {
                                Image("edit").resizable().renderingMode(.template).scaledToFit().frame(width: 40, height: 40).foregroundStyle(themeManager.currentTheme.mainColor)
                                Text("内容確認").font(.headline).foregroundStyle(.secondary)
                            }
                            
                            // Input Form (Refactored)
                            RegistrationFormView(
                                title: $formTitle,
                                maker: $formMaker,
                                scale: $formScale,
                                series: $formSeries,
                                grade: $formGrade,
                                jan: $formJAN,
                                memo: $formMemo,
                                availableMakers: availableMakers,
                                availableScales: availableScales,
                                availableSeries: availableSeries,
                                availableGrades: availableGrades,
                                isCorrectionMode: isCorrectionMode,
                                isCloudDiscovered: isCloudDiscovered
                            )
                            .onChange(of: formJAN) { _, newToken in
                                // Auto-Check Cloud when JAN is entered
                                let token = newToken.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard token.count == 13 || token.count == 8, token.allSatisfy({ $0.isNumber }) else { return }
                                
                                Task {
                                    if let d = await DiscoveryManager.shared.checkDiscovery(jan: token) {
                                        await MainActor.run {
                                            // Found in Cloud! Update form and status.
                                            if !d.title.isEmpty { formTitle = d.title }
                                            if !d.maker.isEmpty { formMaker = d.maker }
                                            if !d.scale.isEmpty { formScale = d.scale }
                                            if !d.series.isEmpty { formSeries = d.series }
                                            if !d.grade.isEmpty { formGrade = d.grade }
                                            
                                            // Update Badge Status
                                            if !stack.isEmpty, case .register(let s, var c) = stack.last {
                                                c.discoveryStatus = .discovered(by: d.discovererName, date: d.discoveredDate, isLocked: d.isLocked, voteCount: d.voteCount)
                                                // Sync Candidate Data
                                                c.title = formTitle
                                                c.maker = formMaker
                                                c.scale = formScale
                                                c.series = formSeries
                                                c.grade = formGrade
                                                c.jan = token
                                                
                                                stack[stack.count-1] = .register(s, c)
                                                
                                                // Feedback
                                                let gen = UINotificationFeedbackGenerator()
                                                gen.notificationOccurred(.success)
                                            }
                                        }
                                    }
                                }
                            }
                                .padding(.horizontal, 40).padding(.bottom, 50)
                            
                        }.frame(maxWidth: .infinity) // Close VStack (Content)
                    } // Close ScrollView
                    
                    // Bottom Bar
                    VStack {
                        Divider()
                        HStack {
                            Button(action: {
                                LocalHaptics.select()
                                if (formImageURLString ?? "").isEmpty {
                                    pickerSourceType = .camera
                                    showNativeCamera = true
                                } else {
                                    // Auto-Fill Blanks for discovered items
                                    if case .discovered = c.discoveryStatus {
                                        Task { await DiscoveryManager.shared.fillBlanks(jan: formJAN, title: formTitle, maker: formMaker, scale: formScale, series: formSeries, grade: formGrade) }
                                    }
                                    goNext()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: (formImageURLString ?? "").isEmpty ? "camera.fill" : "checkmark.circle.fill")
                                    Text((formImageURLString ?? "").isEmpty ? "箱絵を撮影" : "登録を確定する")
                                        .font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 14).padding(.horizontal, 24)
                                .background(themeManager.currentTheme.mainColor).clipShape(Capsule())
                                .shadow(color: themeManager.currentTheme.mainColor.opacity(0.4), radius: 8, y: 4)
                            }.buttonStyle(ScaleButtonStyle())
                            Spacer()
                        }.padding(20)
                    }.background(Color(UIColor.systemBackground))
                    
                }.frame(width: size.width * 0.5) // Close Right Pane VStack
            } // Close HStack

            
        case .detail(_, let c):
            HStack(spacing: 0) {
                ZStack { Color(UIColor.secondarySystemBackground).opacity(0.3); candidateImageDisplay(candidate: c) }.frame(width: size.width * 0.5)
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20); Text(formTitle.isEmpty ? c.title : formTitle).font(.largeTitle).bold().padding(20).foregroundStyle(.primary);
                            detailInfoList(candidate: c).padding(40)
                        }.frame(maxWidth: .infinity)
                    }
                    VStack {
                        Divider()
                        HStack {
                            Button(action: { LocalHaptics.select(); goNext() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark")
                                    Text("完了").font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(.white)
                                .padding(.vertical, 14).padding(.horizontal, 24)
                                .background(themeManager.currentTheme.mainColor).clipShape(Capsule())
                                .shadow(color: themeManager.currentTheme.mainColor.opacity(0.4), radius: 8, y: 4)
                            }.buttonStyle(ScaleButtonStyle())
                            Spacer()
                        }.padding(20)
                    }.background(Color(UIColor.systemBackground))
                }.frame(width: size.width * 0.5)
            }
        }
    }
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            HStack(spacing: 14) {
               Spacer()
            // Buttons are now in the content views (Register/Detail)
            // But we keep this bar for consistency or if we want global actions.
            // Actually, the previous implementation had specific buttons here.
            // Let's remove the Orb spacer.
            }
            .padding(20)
            .frame(height: 0) // Collapse if empty
        }.background(Color(UIColor.systemBackground))
    }
    
    // Helper for iPad Method Card
    private func methodCardiPad(key: MethodKey, status: StatusKey, icon: String, title: String, desc: String, badge: String? = nil) -> some View {
        Button {
            LocalHaptics.select()
            selectedMethod = key
            switch key {
            case .barcode: push(.barcode(status))
                    case .scan: 
                        self.ocrTargetStatus = status
                        self.showOCRCamera = true
            case .text: push(.search(status))
            }
        } label: {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundStyle(themeManager.currentTheme.mainColor)
                    .frame(width: 80, height: 80)
                    .background(themeManager.currentTheme.mainColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(spacing: 4) {
                    Text(title).font(.title3.bold()).foregroundStyle(.primary)
                    Text(desc).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                ZStack(alignment: .top) {
                    if let badge = badge {
                        Text(badge)
                             .font(.headline.bold())
                             .foregroundStyle(.white)
                             .padding(.vertical, 6)
                             .padding(.horizontal, 16)
                             .background(themeManager.currentTheme.mainColor)
                             .clipShape(Capsule())
                             .offset(y: 16)
                    }
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(badge != nil ? themeManager.currentTheme.mainColor : Color.clear, lineWidth: badge != nil ? 3 : 0)
                }
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
            
    // API-Free Search Logic
    private func runWebSearch() {
        let base = query.trimmingCharacters(in: .whitespacesAndNewlines); guard !base.isEmpty else { results = []; return }
        isSearching = true; results = []
        
        // 1. Local DB Search ONLY
        let masterResults = MasterCatalogDB.shared.search(query: base)
        
        // 2. Fallback to Legacy CSV if needed (optional)
        // let legacyResults = CSVDataManager.shared.search(query: base)
        
        // Combine
        self.results = masterResults
        
        // God Mode Google Search
        if isGodModeEnabled && !googleApiKey.isEmpty {
             Task {
                 do {
                     let googleItems = try await GoogleSearchClient.shared.search(query: "\(base) プラモデル")
                     let googleCandidates = googleItems.map { item -> Candidate in
                         let fullText = "\(item.title) \(item.snippet)"
                         let p = TitleParser.parse(title: fullText, originalMaker: "", originalSeries: "")
                         return Candidate(title: p.cleanTitle, maker: p.maker, scale: p.scale, series: p.series, grade: p.grade, jan: "", imageURLString: item.imageURL, isOfficial: false)
                     }
                     await MainActor.run { self.results.insert(contentsOf: googleCandidates, at: 0); self.isSearching = false }
                 } catch { await MainActor.run { self.isSearching = false } }
             }
        } else {
            self.isSearching = false
        }
    }
    
    // ✅ Manual Search Function (includes Scale/Grade in query)
    private func runManualSearch() {
        guard !query.isEmpty else { return }
        isSearching = true
        results = []
        
        Task {
            // Build search query with Scale and Grade
            var searchQuery = query
            if !searchScale.isEmpty { searchQuery += " \(searchScale)" }
            if !searchGrade.isEmpty { searchQuery += " \(searchGrade)" }
            
            let hits = CSVDataManager.shared.searchApproximate(query: searchQuery, modelContext: modelContext, limit: 20)
            
            await MainActor.run {
                results = hits.map { $0.item.toCandidate() }
                isSearching = false
            }
        }
    }
    
    // ✅ iPad Manual Search Result Row (applies cleanup on selection)
    @ViewBuilder
    private func iPadManualSearchResultRow(_ r: Candidate, status: StatusKey) -> some View {
        Button {
            LocalHaptics.select()
            let cleaned = r.cleanedForRegistration()
            prepareForm(from: cleaned)
            push(.register(status, cleaned))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(r.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                HStack(spacing: 8) {
                    if !r.scale.isEmpty {
                        Text(r.scale).font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue.opacity(0.2)).clipShape(Capsule())
                    }
                    if !r.grade.isEmpty {
                        Text(r.grade).font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(Color.green.opacity(0.2)).clipShape(Capsule())
                    }
                    if !r.maker.isEmpty {
                        Text(r.maker).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func filterChip(_ label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { LocalHaptics.tap(); action() }) {
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? themeManager.currentTheme.mainColor : Color.primary.opacity(0.1))
                .clipShape(Capsule())
        }.buttonStyle(.plain)
    }
            private func statusIconBtn(_ s: StatusKey, size: CGFloat) -> some View {
                Button { LocalHaptics.select(); selectedStatus = s; if s.allowsBarcode { push(.method(s)) } else { push(.search(s)) } } label: {
                    VStack(spacing: 10) {
                        ZStack { RoundedRectangle(cornerRadius: size*0.28).fill(Color.primary.opacity(0.05)).frame(width: size, height: size).overlay(RoundedRectangle(cornerRadius: size*0.28).stroke(Color.primary.opacity(0.1), lineWidth: 1)); Image(s.assetName).resizable().renderingMode(.template).scaledToFit().frame(width: size*0.5).foregroundStyle(themeManager.currentTheme.mainColor) }
                        Text(s.label).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary.opacity(0.9))
                    }
                }.buttonStyle(.plain)
            }
            private func methodIconBtn(_ m: MethodKey, status: StatusKey, size: CGFloat) -> some View {
                Button { LocalHaptics.select(); selectedMethod = m; switch m { case .barcode: push(.barcode(status)); case .scan: push(.scan(status)); case .text: push(.search(status)) } } label: {
                    VStack(spacing: 10) {
                        ZStack { RoundedRectangle(cornerRadius: size*0.28).fill(Color.primary.opacity(0.05)).frame(width: size, height: size).overlay(RoundedRectangle(cornerRadius: size*0.28).stroke(Color.primary.opacity(0.1), lineWidth: 1)); Image(m.assetName).resizable().renderingMode(.template).scaledToFit().frame(width: size*0.5).foregroundStyle(themeManager.currentTheme.mainColor) }
                        Text(m.label).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary.opacity(0.9))
                    }
                }.buttonStyle(.plain)
            }
            private func resultRow(_ r: Candidate, status: StatusKey) -> some View {
                Button { LocalHaptics.tap(); prepareForm(from: r); push(.register(status, r)) } label: {
                    HStack(spacing: 20) {
                        if let url = r.imageURLString {
                            if url.hasPrefix("asset://") {
                                PhAssetImage(localIdentifier: String(url.dropFirst(8))).scaledToFill().frame(width: 80, height: 80).cornerRadius(8)
                            } else if let u = URL(string: url), url.hasPrefix("http") {
                                AsyncImage(url: u) { phase in if let img = phase.image { img.resizable().scaledToFill() } else { Color.gray.opacity(0.3) } }.frame(width: 80, height: 80).cornerRadius(8)
                            } else {
                                Color.gray.opacity(0.3).frame(width: 80, height: 80).cornerRadius(8)
                            }
                        } else { Color.gray.opacity(0.3).frame(width: 80, height: 80).cornerRadius(8) }
                        VStack(alignment: .leading, spacing: 4) { 
                            HStack {
                                Text(r.title).font(.title3).bold().foregroundStyle(.primary)
                                if r.isOfficial { OfficialBadge() }
                            }
                            Text("\(r.maker) \(r.grade) \(r.scale)").foregroundStyle(.secondary) 
                        }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.gray)
                    }.padding().background(Color.primary.opacity(0.05)).cornerRadius(12)
                }.buttonStyle(.plain)
            }
            @ViewBuilder
            private func candidateImageDisplay(candidate: Candidate) -> some View {
                Button {
                    LocalHaptics.select()
                    showImageSourceDialog = true
                } label: {
                    ZStack {
                        if let imgStr = formImageURLString {
                            // ✅ String Handling: Asset vs Web vs Local
                            if imgStr.hasPrefix("asset://") {
                                 PhAssetImage(localIdentifier: String(imgStr.dropFirst(8)))
                                    .scaledToFill()
                                    .frame(width: 320, height: 320) // Larger for iPad
                                    .clipped()
                                    .cornerRadius(16)
                            } else if let url = URL(string: imgStr), imgStr.hasPrefix("http") {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        ProgressView()
                                    }
                                }
                                .frame(width: 320, height: 320).clipped().cornerRadius(16)
                            } else {
                                if let localImg = ImageLinker.loadLocalImage(named: imgStr) {
                                     Image(uiImage: localImg).resizable().scaledToFill()
                                         .frame(width: 320, height: 320).clipped().cornerRadius(16)
                                } else {
                                     Image(systemName: "photo").font(.largeTitle).frame(width: 320, height: 320).background(Color.gray.opacity(0.1)).cornerRadius(16)
                                }
                            }
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "camera.fill").font(.system(size: 60))
                                Text("画像を設定").font(.headline)
                            }
                            .frame(width: 320, height: 320)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(20)
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                        }
                    }
                    .shadow(radius: 10)
                }
                .buttonStyle(.plain)
            }

            private func detailInfoList(candidate: Candidate) -> some View {
                VStack(alignment: .leading, spacing: 12) {
                    let maker = formMaker.isEmpty ? candidate.maker : formMaker
                    let grade = formGrade.isEmpty ? candidate.grade : formGrade
                    let scale = formScale.isEmpty ? candidate.scale : formScale
                    let series = formSeries.isEmpty ? candidate.series : formSeries
                    Text("\(maker) ・ \(scale)").font(.title3).foregroundStyle(.primary); Text(series).font(.headline).foregroundStyle(.secondary); Text("Grade: \(grade)").foregroundStyle(.secondary); if !formMemo.isEmpty { Divider(); Text(formMemo).foregroundStyle(.primary) }
                }
            }
            
            private func push(_ step: Step) { stack.append(step) }
            private func goBack() { if stack.count > 1 { stack.removeLast() } else { isPresented = false } }
            
            private func handleScan(code: String, status: StatusKey) {
                guard !isSearching else { return }; isSearching = true
                Task {
                    // 1. Local Check
                    if let hit = await MainActor.run(body: { CSVDataManager.shared.findByJAN(code) }) {
                         await MainActor.run {
                             LocalHaptics.success()
                             let c = Candidate(title: hit.title, maker: hit.maker, scale: hit.scale, series: hit.series, grade: hit.grade, jan: hit.jan, imageURLString: hit.imageURLString, discoveryStatus: .unknown)
                             prepareForm(from: c); isSearching = false; push(.register(status, c))
                         }
                         return
                    }
                    
                    // 2. CloudKit Public Check
                    let discovery = await DiscoveryManager.shared.checkDiscovery(jan: code)
                    
                    await MainActor.run {
                        LocalHaptics.success()
                        var c: Candidate
                        
                        if let d = discovery {
                             c = Candidate(
                                 title: d.title,
                                 maker: d.maker,
                                 scale: d.scale,   // ✅ Fixed
                                 series: d.series, // ✅ Fixed
                                 grade: d.grade,   // ✅ Fixed
                                 jan: d.id,
                                 imageURLString: nil,
                                 discoveryStatus: .discovered(by: d.discovererName, date: d.discoveredDate, isLocked: d.isLocked, voteCount: d.voteCount)
                             )
                        } else {
                             c = Candidate(title: "", maker: "", scale: "", series: "", grade: "", jan: code, imageURLString: nil, discoveryStatus: .firstDiscovery)
                        }
                        
                        prepareForm(from: c); isSearching = false; push(.register(status, c))
                    }
                }
            }

            private func prepareForm(from c: Candidate) {
                // ✅ Use the title directly - cleanedForRegistration() already cleaned it.
                // Previously, we called TitleParser.parse() which corrupted Ver.2.0 patterns.
                formTitle = c.title
                // Get maker from TitleParser only if not already set
                if c.maker.isEmpty || c.maker == "Unknown" {
                    let parsed = TitleParser.parse(title: c.title, originalMaker: c.maker, originalSeries: c.series)
                    formMaker = parsed.maker
                } else {
                    formMaker = c.maker
                }
                formScale = c.scale
                formSeries = c.series
                formGrade = c.grade
                formJAN = c.jan
                formMemo = ""
                formImageURLString = c.imageURLString
            }
            
            // Helper for initial search query
            private var candidateTitleForSearch: String {
                if case .register(_, let c) = current { return c.title }
                return ""
            }
            private func goNext() {
                switch current {
                case .status, .method, .barcode, .scan, .search: break
                case .register(let status, var candidate):
                    Task {
                        // CloudKit Logic: Resolve Image Data
                        var finalImageData: Data? = nil
                        
                        if let urlString = formImageURLString {
                            if urlString.hasPrefix("asset://") {
                                 // Fetch from Photo Library
                                 let assetID = String(urlString.dropFirst(8))
                                 finalImageData = await fetchAssetData(localIdentifier: assetID)
                            } else if let url = URL(string: urlString), urlString.hasPrefix("http") {
                                 // Fetch from Web
                                 if let (data, _) = try? await URLSession.shared.data(from: url) {
                                     finalImageData = data
                                 }
                            } else {
                                 // Local File?
                                 if let resolvedURL = ImageLinker.resolve(urlString: urlString) {
                                     finalImageData = try? Data(contentsOf: resolvedURL)
                                 }
                            }
                        }
                        
                        let targetImageData = finalImageData
                        
                        // ✅ Check & Register Discovery
                        if case .firstDiscovery = candidate.discoveryStatus {
                            do {
                                try await DiscoveryManager.shared.registerDiscovery(
                                    jan: formJAN,
                                    title: formTitle,
                                    maker: formMaker,
                                    scale: formScale,
                                    series: formSeries,
                                    grade: formGrade,
                                    imageData: targetImageData
                                )
                            } catch {
                                print("❌ [RegistrationFlow] Failed to register discovery: \(error)")
                                await MainActor.run {
                                    self.discoveryErrorMessage = "発見者情報の登録に失敗しました: \(error.localizedDescription)"
                                    self.showDiscoveryError = true
                                }
                            }
                        }
                        
                        let newKit = Kit(
                            title: formTitle,
                            maker: formMaker,
                            series: formSeries,
                            grade: formGrade,
                            scale: formScale,
                            jan: formJAN,
                            statusValue: status.dbValue,
                            imageURLString: formImageURLString, 
                            memo: formMemo,
                            imageData: targetImageData // ✅ Save Data for Sync
                        )
                        modelContext.insert(newKit)
                        
                        candidate.title = newKit.title
                        candidate.maker = newKit.maker
                        candidate.scale = newKit.scale
                        candidate.series = newKit.series
                        candidate.grade = newKit.grade
                        candidate.jan = newKit.jan
                        candidate.imageURLString = newKit.imageURLString
                        
                        push(.detail(status, candidate))
                    }
                case .detail: isPresented = false
            }
        }
        
    // Helper for Asset Data
    private func fetchAssetData(localIdentifier: String) async -> Data? {
        return await withCheckedContinuation { continuation in
             let options = PHImageRequestOptions()
             options.isSynchronous = false
             options.deliveryMode = .highQualityFormat
             options.isNetworkAccessAllowed = true
             
             let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
             if let asset = assets.firstObject {
                 PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                     continuation.resume(returning: data)
                 }
             } else {
                 continuation.resume(returning: nil)
             }
        }
    }


    // Levenshtein Helper
    private func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1.utf16)
        let b = Array(s2.utf16)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        
        var d = [Int](0...b.count)
        for i in 1...a.count {
            var last = i
            for j in 1...b.count {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                let val = min(d[j-1] + cost, d[j] + 1, last + 1)
                d[j-1] = last
                last = val
            }
            d[b.count] = last
        }
        return d[b.count]
    }
}

extension RegistrationFlow_iPad {
    // MARK: - Filter Helpers (Pulldown Search)
    private func filterButtonLabel(title: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title).lineLimit(1).truncationMode(.tail)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(isActive ? .white : .primary)
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(isActive ? themeManager.currentTheme.mainColor : Color(UIColor.secondarySystemBackground))
        .clipShape(Capsule())
    }
    
    private func layoutFilters() {
        if availableSeries.isEmpty {
            Task {
                availableSeries = CSVDataManager.shared.getAllSeries()
                availableGrades = CSVDataManager.shared.getAllGrades()
                availableScales = CSVDataManager.shared.getAllScales()
                availableMakers = CSVDataManager.shared.getAllMakers() // ✅ Load Makers
            }
        }
    }
    
    private func runFilteredSearch() {
        if query.isEmpty && searchMaker.isEmpty && searchSeries.isEmpty && searchGrade.isEmpty && searchScale.isEmpty {
            results = []
            return
        }
        
        isSearching = true
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            let hits = CSVDataManager.shared.filterSearch(
                series: searchSeries.isEmpty ? nil : searchSeries,
                grade: searchGrade.isEmpty ? nil : searchGrade,
                scale: searchScale.isEmpty ? nil : searchScale,
                maker: searchMaker.isEmpty ? nil : searchMaker, // ✅ Pass Maker
                keyword: query.isEmpty ? nil : query
            ).prefix(200)
            
            await MainActor.run {
                results = hits.map { $0.toCandidate() }
                isSearching = false
            }
        }
    }
}
