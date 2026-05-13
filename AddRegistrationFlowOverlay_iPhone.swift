//  AddRegistrationFlowOverlay_iPhone.swift V89
//  Modified: 2026-01-04 16:50
//  Plalog
//
//  Created by (User) on 2026/01/03.
//  1. バージョン管理ルールに基づき更新 (V74 -> V75)
//  2. 修正点: 構造体の閉じ括弧の不整合による大量のビルドエラーを修正
//     - 構造体の定義、プロパティ、body、および主要な拡張メソッドを確実に一つのブロック内に収めるよう再編。
//     - 型式番号の自動付与（TitleParser V19 連携）およびライトモード対応を維持。
//

import SwiftUI
import SwiftData
import Combine
import Foundation // Added for safety
import Photos

// Fixing Build Error: Decoupling from TitleParser to ensure access
fileprivate let knownSeriesRules = [
    "機動戦士ガンダム 逆襲のシャア", "機動戦士ガンダム 水星の魔女", "機動戦士ガンダム 鉄血のオルフェンズ", "ガンダム Gのレコンギスタ", "機動戦士ガンダムAGE", "機動戦士ガンダム00", "機動戦士ガンダムSEED DESTINY", "機動戦士ガンダムSEED FREEDOM", "機動戦士ガンダムSEED", "∀ガンダム", "機動新世紀ガンダムX", "新機動戦記ガンダムW", "機動武闘伝Gガンダム", "機動戦士Vガンダム", "機動戦士ガンダムF91", "機動戦士ガンダム0083", "機動戦士ガンダム0080", "機動戦士ガンダム 第08MS小隊", "機動戦士ガンダム サンダーボルト", "機動戦士ガンダムUC", "機動戦士Zガンダム", "機動戦士ガンダムZZ", "機動戦士ガンダム", "ガンダムビルドファイターズ", "ガンダムビルドダイバーズ", "30 MINUTES MISSIONS", "30 MINUTES SISTERS", "境界戦機", "スター・ウォーズ", "エヴァンゲリオン", "マクロス", "ボトムズ", "ダンバイン", "エルガイム", "パトレイバー", "コードギアス"
]

struct RegistrationFlow_iPhone: View {
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
    @State private var availableMakers: [String] = [] // ✅ Added for Maker Picker
    @State private var results: [Candidate] = []
    @State private var isSearching: Bool = false
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    @FocusState private var isSearchFocused: Bool
    @State private var keyboardHeight: CGFloat = 0
    
    @State private var formTitle: String = ""
    @State private var formMaker: String = ""
    @State private var formScale: String = ""
    @State private var formSeries: String = ""
    @State private var formGrade: String = ""
    @State private var formJAN: String = ""
    @State private var formMemo: String = ""
    @State private var formImageURLString: String? = nil // ✅ Changed to String
    @State private var showImagePicker: Bool = false
    
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
    
    // ✅ Dynamic Filter
    @State private var selectedFilter: String? = nil
    
    private var filterChips: [String] {
        var tags = Set<String>()
        for r in results {
            let g = r.grade.trimmingCharacters(in: .whitespacesAndNewlines)
            let s = r.scale.trimmingCharacters(in: .whitespacesAndNewlines)
            let se = r.series.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !g.isEmpty { tags.insert(g) }
            if !s.isEmpty { tags.insert(s) }
            if !se.isEmpty { tags.insert(se) }
        }
        return tags.sorted()
    }
    
    private var filteredResults: [Candidate] {
        guard let filter = selectedFilter else { return results }
        return results.filter { $0.grade == filter || $0.scale == filter || $0.series == filter }
    }
    
    private let iconSizeHome: CGFloat = 60
    private let verticalSpacing: CGFloat = 12
    
    private var current: Step { stack.last ?? .status }
    private var isSearchScreen: Bool {
        if case .search = current { return true }
        return false
    }
    
    private var isRegisterStep: Bool {
        if case .register = current { return true }
        return false
    }
    private var isDetailStep: Bool {
        if case .detail = current { return true }
        return false
    }
    
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
            // Optional: Include Series in search if needed, usually Series is for categorization but could help approximation
            if !cSeries.isEmpty { searchQuery += " \(cSeries)" }
            
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
                
                // Set editing default values (only if empty to avoid overwriting user edits during re-search loop if we were doing that, but here we run search once)
                // Actually, if we run performOCRSearch, we probably want to update the fields to match the 'best guess' or keep user input?
                // Users might call this from "Re-search" button with their own modified validation.
                // If called from OCR Camera, fields are empty.
                // If called from "Re-search", we pass the current field values.
                
                // So: update them ONLY if we found better data from Cloud (JAN hit)?
                // Or just blindly sync?
                // Let's rely on the passed arguments.
                
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
            let isLandscape = geo.size.width > geo.size.height
            let safeArea = geo.safeAreaInsets
            
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                    .onTapGesture {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                
                VStack(spacing: 0) {
                    if !isSearchFocused {
                        HStack {
                            Button {
                                LocalHaptics.tap()
                                if stack.count > 1 {
                                    stack.removeLast()
                                } else {
                                    isPresented = false
                                }
                            } label: {
                                Image(systemName: stack.count > 1 ? "chevron.backward" : "xmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(themeManager.currentTheme.mainColor)
                                    .frame(width: 44, height: 44)
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            Text("アイテム登録")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            // Placeholder to balance center text
                            Color.clear.frame(width: 44, height: 44)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, safeArea.top + 10)
                        .padding(.bottom, 10)
                        .background(Color(UIColor.systemBackground))
                    } else {
                        Spacer().frame(height: safeArea.top + 10)
                    }
                    
                    content(size: geo.size, isLandscape: isLandscape, safeArea: safeArea)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if !isSearchScreen {
                        if !(isLandscape && isRegisterStep) && !(isLandscape && isDetailStep) {
                            if case .scan = current {} else {
                                bottomBar(safeArea: safeArea)
                            }
                        }
                    }
                }
                .ignoresSafeArea(.keyboard)
                .ignoresSafeArea(edges: .top)
            }
        }
        .ignoresSafeArea(.keyboard)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut(duration: 0.22), value: stack)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                withAnimation(.easeOut(duration: 0.25)) { self.keyboardHeight = keyboardFrame.height }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.25)) { self.keyboardHeight = 0 }
        }
        .sheet(isPresented: $showImagePicker) {
            WebImageSearchModal(
                isPresented: $showImagePicker,
                initialQuery: formTitle
            ) { selectedString in
                 formImageURLString = selectedString
                 if case .register(let s, var c) = stack.last {
                     c.imageURLString = selectedString
                     stack[stack.count-1] = .register(s, c)
                 }
            }
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
                    ocrEditingSeries = "" // Default empty or parse?
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
                                    
                                    // Also update candidate if in register mode
                                    if case .register(let s, var c) = stack.last {
                                        c.imageURLString = "asset://\(id)"
                                        stack[stack.count-1] = .register(s, c)
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

        .onChange(of: pendingOCRResult) { _, newValue in
            if newValue {
                print("DEBUG: onChange triggered. ocrSuggestions count: \(ocrSuggestions.count)")
                showOCRSuggestions = true
                pendingOCRResult = false
            }
        }
        .sheet(isPresented: $showOCRSuggestions, onDismiss: { ocrSuggestions = []; showOCRCamera = false }) {
            let _ = print("DEBUG: Sheet RENDERED. ocrSuggestions count at render time: \(ocrSuggestions.count)")
            NavigationStack {
                List {
                    // ✅ Modified Header: Editable Fields & Actions
                    Section {
                        VStack(spacing: 12) {
                            // Text Fields
                            VStack(spacing: 8) {
                                // Title (Keep as standard TextField for now or wrap?)
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
                                    ).cleanedForRegistration() // ✅ Apply cleanup
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
                                    // Apply Suggestion
                                    // Keep the captured image!
                                    let capturedImage = formImageURLString
                                    var finalS = s.cleanedForRegistration() // ✅ Apply cleanup
                                    // Only overwrite image if we actually captured one (otherwise use suggested image if available?)
                                    // Actually, logic says: `formImageURLString` is the captured image URL (from OCR camera).
                                    // So we want to attach the user's photo to the data. Correct.
                                    finalS.imageURLString = capturedImage
                                    
                                    // ✅ Preserve JAN from Barcode Scan if available
                                    // If we arrived here from a barcode scan (which sets formJAN), we must preserve it
                                    // because the OCR/Search result likely comes from a DB without this specific JAN.
                                    if !formJAN.isEmpty && (finalS.jan.isEmpty || finalS.jan != formJAN) {
                                        print("DEBUG: Preserving Scanned JAN: \(formJAN) over Suggestion JAN: \(finalS.jan)")
                                        finalS.jan = formJAN
                                    }
                                    
                                    // DO NOT RESET discoveryStatus! It is already set correctly in the loop.
                                    
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
        .alert("検索エラー", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}
// AddRegistrationFlowOverlay_iPhone.swift V75
// PART 2 OF 3

extension RegistrationFlow_iPhone {

    
    @ViewBuilder
    private func content(size: CGSize, isLandscape: Bool, safeArea: EdgeInsets) -> some View {
        switch current {
        case .status: statusPicker(safeArea: safeArea, isLandscape: isLandscape)
        case .method(let s): methodPicker(status: s, safeArea: safeArea, isLandscape: isLandscape)
        case .barcode(let s): barcodeLayer(status: s, safeArea: safeArea)
        case .scan(let s): cleanScanLayer(status: s, safeArea: safeArea)
        case .search(let s): searchLayer(status: s, safeArea: safeArea)
        case .register(let s, let c): registerLayer(status: s, candidate: c, isLandscape: isLandscape, size: size, safeArea: safeArea)
        case .detail(let s, let c): detailLayer(status: s, candidate: c, isLandscape: isLandscape, size: size, safeArea: safeArea)
        }
    }
    
    @ViewBuilder
    private func statusPicker(safeArea: EdgeInsets, isLandscape: Bool) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                
                VStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 40))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                    Text("状態を選択")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 16)], spacing: 16) {
                    ForEach(StatusKey.allCases) { s in
                        Button {
                            LocalHaptics.select()
                            selectedStatus = s
                            selectedMethod = nil
                            if s.allowsBarcode { push(.method(s)) } else { push(.search(s)) }
                        } label: {
                            VStack(spacing: 12) {
                                Image(s.assetName)
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                    .foregroundStyle(themeManager.currentTheme.mainColor)
                                
                                Text(s.label)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.primary.opacity(0.05), lineWidth: 1))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
    }
    

    
    @ViewBuilder
    private func methodPicker(status: StatusKey, safeArea: EdgeInsets, isLandscape: Bool) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 20)
                
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                    Text("登録方法を選択")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                
                VStack(spacing: 16) {
                    // Method 1: Barcode (Primary)
                    methodCard(key: .barcode, status: status, icon: "barcode.viewfinder", title: "バーコード", desc: "パッケージのJANコードを読み取る", badge: "推奨")
                    
                    // Method 2: OCR Scan (New)
                    methodCard(key: .scan, status: status, icon: "camera.fill", title: "箱を撮影", desc: "写真から自動入力")
                    
                    // Method 3: Manual / Local Search
                    methodCard(key: .text, status: status, icon: "keyboard", title: "手動入力 / 検索", desc: "データベースから検索または手動登録")
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)
        }
    }
    
    private func methodCard(key: MethodKey, status: StatusKey, icon: String, title: String, desc: String, badge: String? = nil) -> some View {
        Button {
            LocalHaptics.select()
            selectedMethod = key
            switch key {
            case .barcode: push(.barcode(status))
            case .scan: push(.scan(status)) // Kept for legacy compatibility if needed
            case .text: push(.search(status))
            }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundStyle(themeManager.currentTheme.mainColor)
                    .frame(width: 50, height: 50)
                    .background(themeManager.currentTheme.mainColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if let badge = badge {
                    Text(badge)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(themeManager.currentTheme.mainColor)
                        .clipShape(Capsule())
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(badge != nil ? themeManager.currentTheme.mainColor : Color.clear, lineWidth: badge != nil ? 2 : 0)
            )
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    private func methodIconBtn(_ m: MethodKey, status: StatusKey, size: CGFloat) -> some View {
        EmptyView() // Deprecated
    }
    
    @ViewBuilder
    private func barcodeLayer(status: StatusKey, safeArea: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            if !isSearchFocused {
                VStack(spacing: 16) {
                    Image("icon_barcode").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor)
                    Text("バーコードをスキャン").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
                }.padding(.top, 20 + safeArea.top).padding(.bottom, 20)
            } else {
                Spacer().frame(height: safeArea.top + 10)
            }
            ZStack {
                // Using existing BarcodeScannerView
                BarcodeScannerView { code in handleScan(code: code, status: status) }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.3), lineWidth: 1))
                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(themeManager.currentTheme.mainColor.opacity(0.8), lineWidth: 2).frame(width: 250, height: 120)
                if isSearching { Color.black.opacity(0.4); ProgressView("照合中...").tint(.white) }
            }.padding(.horizontal, 18).padding(.bottom, 20)
            
            // Fallback Button
            Button {
                LocalHaptics.select()
                push(.scan(status))
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                    Text("読み取れない場合は箱を撮影").font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(themeManager.currentTheme.mainColor)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .background(themeManager.currentTheme.mainColor.opacity(0.1))
                .clipShape(Capsule())
            }.padding(.bottom, 20)
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private func cleanScanLayer(status: StatusKey, safeArea: EdgeInsets) -> some View {
        VStack {
            Spacer()
            ProgressView("カメラを起動中...")
            Spacer()
        }
        .onAppear {
            self.ocrTargetStatus = status
            // Only auto-open camera if we are not showing results and have no data
            if !showOCRSuggestions && ocrSuggestions.isEmpty {
                self.showOCRCamera = true
            }
        }
    }
    
    @ViewBuilder
    private func searchLayer(status: StatusKey, safeArea: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            // ✅ Header
            if !isSearchFocused {
                VStack(spacing: 16) {
                    Image("icon_text_search").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor)
                    Text("データベース検索").font(.system(size: 16, weight: .medium, design: .monospaced)).foregroundStyle(themeManager.currentTheme.mainColor)
                }.padding(.top, 20 + safeArea.top).padding(.bottom, 10)
            } else {
                Spacer().frame(height: safeArea.top + 10)
            }
            
            // ✅ Search Form (Keyword + Pulldown Filters)
            VStack(spacing: 12) {
                // Keyword Field
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("キーワード (例: ザク)", text: $query)
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
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Filters Row (Horizontal Scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
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
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            
            Divider()
            
            // ✅ Results Area
            if isSearching {
                Spacer(); ProgressView("検索中...").tint(themeManager.currentTheme.mainColor); Spacer()
            } else if results.isEmpty {
                // Empty State / Fallback
                VStack(spacing: 16) {
                    Spacer()
                    if query.isEmpty && searchSeries.isEmpty && searchGrade.isEmpty && searchScale.isEmpty {
                        // Initial State
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(.secondary)
                            Text("条件を選択して検索").foregroundStyle(.secondary)
                        }
                    } else {
                        // No Results
                        Text("条件に一致するアイテムはありません").foregroundStyle(.secondary)
                        Button("手動で登録する") {
                            let c = Candidate(title: query, maker: searchMaker.isEmpty ? "BANDAI SPIRITS" : searchMaker, scale: searchScale, series: searchSeries, grade: searchGrade, jan: "", imageURLString: nil)
                            prepareForm(from: c)
                            push(.register(status, c))
                        }
                        .font(.headline)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                    }
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(results) { r in
                            manualSearchResultRow(r, status: status)
                        }
                        Text("\(results.count)件 ヒット").font(.caption).foregroundStyle(.secondary).padding(.top, 10)
                        Spacer().frame(height: 100)
                    }
                    .padding(18)
                }
            }
        }
        .padding(.bottom, keyboardHeight)
        .onAppear {
            layoutFilters()
        }
    }
    
    // MARK: - Filter Helpers
    private func filterButtonLabel(title: String, isActive: Bool) -> some View {
        HStack(spacing: 4) {
            Text(title).lineLimit(1).truncationMode(.tail)
            Image(systemName: "chevron.down").font(.caption2)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(isActive ? .white : .primary)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isActive ? themeManager.currentTheme.mainColor : Color(UIColor.secondarySystemBackground))
        .clipShape(Capsule())
    }
    
    private func layoutFilters() {
        if availableSeries.isEmpty {
            Task {
                await CSVDataManager.shared.ensureDataLoaded() // ✅ Wait for data
                availableSeries = CSVDataManager.shared.getAllSeries()
                availableGrades = CSVDataManager.shared.getAllGrades()
                availableScales = CSVDataManager.shared.getAllScales()
                availableMakers = CSVDataManager.shared.getAllMakers() 
            }
        }
    }
    
    // Replaces runManualSearch
    private func runFilteredSearch() {
        // Prevent empty search unless filters are active (optional, but good for performance)
        if query.isEmpty && searchMaker.isEmpty && searchSeries.isEmpty && searchGrade.isEmpty && searchScale.isEmpty {
            results = []
            return
        }
        
        isSearching = true
        Task {
            // Tiny delay for UI
            try? await Task.sleep(nanoseconds: 50_000_000)
            
            await CSVDataManager.shared.ensureDataLoaded() // ✅ Wait for data
            
            // Limit results to avoid UI freeze on "All"
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
    
    // ✅ Manual Search Result Row (applies cleanup on selection)
    @ViewBuilder
    private func manualSearchResultRow(_ r: Candidate, status: StatusKey) -> some View {
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
}
// AddRegistrationFlowOverlay_iPhone.swift V89
// PART 3 OF 3

extension RegistrationFlow_iPhone {
    private func resultRow(_ r: Candidate, status: StatusKey) -> some View {
        Button {
            LocalHaptics.tap(); isSearchFocused = false; prepareForm(from: r); push(.register(status, r))
        } label: {
            HStack(spacing: 12) {
                // Image Logic (Simplified)
                placeholderIcon.frame(width: 54, height: 54)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(r.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary).lineLimit(2)
                        // if r.isOfficial { OfficialBadge() } // Removed as web search is removed
                    }
                    Text("\(r.maker) \(r.grade) \(r.scale)").font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(); Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.6))
            }.padding(12).background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
        }.buttonStyle(.plain)
    }
    
    private var placeholderIcon: some View { ZStack { Color(UIColor.tertiarySystemFill); Image(systemName: "cube.box").foregroundStyle(.secondary) } }

    @ViewBuilder
    private func registerLayer(status: StatusKey, candidate: Candidate, isLandscape: Bool, size: CGSize, safeArea: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // ✅ Discovery Badge Section
                    DiscoveryStatusBadge(
                        candidate: candidate,
                        isCorrectionMode: $isCorrectionMode,
                        onUpdate: {
                            LocalHaptics.select()
                            try? await DiscoveryManager.shared.updateDiscovery(jan: candidate.jan, title: formTitle, maker: formMaker, scale: formScale, grade: formGrade)
                            await MainActor.run { isCorrectionMode = false; LocalHaptics.success() }
                        },
                        onVote: {
                            LocalHaptics.select()
                            _ = try? await DiscoveryManager.shared.voteDiscovery(jan: candidate.jan)
                            await MainActor.run { LocalHaptics.success() }
                        }
                    )
                    
                    // Image Section
                    VStack(spacing: 12) {
                        formImageDisplay(url: formImageURLString, isExpanded: false)
                        
                        // Modern Image Switcher
                        HStack(spacing: 0) {
                            Button {
                                LocalHaptics.select()
                                formImageURLString = nil // Clear image
                            } label: {
                                Text("No Image")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background((formImageURLString ?? "").isEmpty ? themeManager.currentTheme.mainColor : Color.clear)
                                    .foregroundStyle((formImageURLString ?? "").isEmpty ? .white : .secondary)
                            }
                            
                            Divider().frame(height: 20)
                            
                            Menu {
                                Button(action: {
                                    pickerSourceType = .camera
                                    showNativeCamera = true
                                }) { Label("カメラで撮影", systemImage: "camera") }
                                
                                Button(action: {
                                    pickerSourceType = .photoLibrary
                                    showNativeCamera = true
                                }) { Label("ライブラリから選択", systemImage: "photo.on.rectangle") }
                                
                                Button(action: {
                                    showImagePicker = true // Launches Web Search
                                }) { Label("Webから検索", systemImage: "magnifyingglass") }
                                
                            } label: {
                                Text("画像を選択")
                                    .font(.system(size: 13, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background((formImageURLString ?? "").isEmpty == false ? themeManager.currentTheme.mainColor : Color.clear)
                                    .foregroundStyle((formImageURLString ?? "").isEmpty == false ? .white : .secondary)
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(Capsule())
                        .frame(width: 200)
                        
                        // OCR Trigger Button
                        Button {
                            LocalHaptics.select()
                            showOCRCamera = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "camera.viewfinder")
                                Text("箱を撮影して自動入力").font(.system(size: 14, weight: .bold))
                            }
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(themeManager.currentTheme.mainColor.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 20)
                    
                    // Form Section
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
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)

                }
            }
            
            // Fixed Bottom Action Bar
            VStack {
                Divider()
                HStack(spacing: 20) {
                    Button {
                       LocalHaptics.tap()
                       goBack()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.red)
                            .frame(width: 50, height: 50)
                            .background(Color.red.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Button {
                        LocalHaptics.success()
                        if (formImageURLString ?? "").isEmpty { // ✅ Robust check
                            pickerSourceType = .camera
                            showNativeCamera = true
                        } else {
                            goNext()
                        }
                    } label: {
                        HStack {
                           Image(systemName: (formImageURLString ?? "").isEmpty ? "camera.fill" : "checkmark.circle.fill")
                           Text((formImageURLString ?? "").isEmpty ? "箱絵を撮影" : "登録する")
                               .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(formImageURLString == nil ? themeManager.currentTheme.mainColor : themeManager.currentTheme.mainColor) // Same color or different?
                        .clipShape(Capsule())
                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.4), radius: 8, y: 4)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, safeArea.bottom + 10)
                .background(Color(UIColor.systemBackground))
            }
        }
    }

    private func prepareForm(from c: Candidate) {
        // ✅ Use the title directly - cleanedForRegistration() already cleaned it.
        // Previously, we called TitleParser.parse() which corrupted Ver.2.0 patterns.
        var finalTitle = c.title
        
        // Only extract model number if it's somehow missing (fallback)
        if let extractedModel = TitleParser.extractOnlyModelNumber(from: c.title) {
            if !finalTitle.contains(extractedModel) {
                finalTitle = "\(extractedModel) \(finalTitle)"
            }
        }
        
        formTitle = finalTitle
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
        
        // Check if this is a cloud discovery
        if case .discovered = c.discoveryStatus {
            isCloudDiscovered = true
        } else {
            isCloudDiscovered = false
        }
        isCorrectionMode = false // Reset
    }
    
    // Helper helper
    private func fetchImageDataForDiscovery(urlString: String?) async -> Data? {
        guard let urlString = urlString else { return nil }
        if urlString.hasPrefix("asset://") {
            let assetID = String(urlString.dropFirst(8))
            return await fetchAssetData(localIdentifier: assetID)
        } else if let url = URL(string: urlString), urlString.hasPrefix("file://") || urlString.count < 100 { // Assume local file
             if let resolved = ImageLinker.resolve(urlString: urlString) {
                 return try? Data(contentsOf: resolved)
             }
        }
        return nil
    }

    private func handleScan(code: String, status: StatusKey) {
        guard !isSearching else { return }; isSearching = true
        Task {
            // 1. Local CSV Check
            if let hit = await MainActor.run(body: { CSVDataManager.shared.findByJAN(code) }) {
                await MainActor.run {
                    LocalHaptics.success()
                    let c = Candidate(title: hit.title, maker: hit.maker, scale: hit.scale, series: hit.series, grade: hit.grade, jan: hit.jan, imageURLString: hit.imageURLString, discoveryStatus: .unknown) // Known items are handled as nornal
                    prepareForm(from: c)
                    push(.register(status, c))
                    isSearching = false
                }
                return
            }
            
            // 2. CloudKit Public DB Check
            let discovery = await DiscoveryManager.shared.checkDiscovery(jan: code)
            
            await MainActor.run {
                LocalHaptics.success()
                var c: Candidate
                
                if let d = discovery {
                     // Found in Cloud!
                     // Image logic for cloud record needs careful handling (CKAsset).
                     // For now, we might skip image or handle it if we implement Cloud Asset download in Manager.
                     // Assumed DiscoveryRecord doesn't return full accessible URL yet without extra work.
                     c = Candidate(
                         title: d.title,
                         maker: d.maker,
                         scale: d.scale,   // ✅ Fixed: Pass scale
                         series: d.series, // ✅ Fixed: Pass series
                         grade: d.grade,   // ✅ Fixed: Pass grade
                         jan: d.id,
                         imageURLString: nil,
                         discoveryStatus: .discovered(by: d.discovererName, date: d.discoveredDate, isLocked: d.isLocked, voteCount: d.voteCount)
                     )
                } else {
                     // New Discovery!
                     c = Candidate(title: "", maker: "", scale: "", series: "", grade: "", jan: code, imageURLString: nil, discoveryStatus: .firstDiscovery)
                }
                
                prepareForm(from: c)
                push(.register(status, c))
                isSearching = false
            }
        }
    }
    
    // ✅ Updated goNext to handle Registration + Discovery
    private func goNext() {
        switch current {
        case .status, .method, .barcode, .scan, .search: break
        case .register(let status, var candidate):
            Task {
                // Image Data Logic
                var finalImageData: Data? = nil
                if let urlString = formImageURLString {
                    if urlString.hasPrefix("asset://") {
                         let assetID = String(urlString.dropFirst(8))
                         finalImageData = await fetchAssetData(localIdentifier: assetID)
                    } else if let url = URL(string: urlString), urlString.hasPrefix("http") {
                         if let (data, _) = try? await URLSession.shared.data(from: url) { finalImageData = data }
                    } else if let resolvedURL = ImageLinker.resolve(urlString: urlString) {
                         finalImageData = try? Data(contentsOf: resolvedURL)
                    }
                }
                let targetImageData = finalImageData
                
                // ✅ Check & Register Discovery
                if case .firstDiscovery = candidate.discoveryStatus {
                    try? await DiscoveryManager.shared.registerDiscovery(jan: formJAN, title: formTitle, maker: formMaker, scale: formScale, series: formSeries, grade: formGrade, imageData: targetImageData)
                }
                
                await MainActor.run {
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
                        imageData: targetImageData
                    )
                    modelContext.insert(newKit)
                
                    candidate.title = newKit.title; candidate.maker = newKit.maker
                    candidate.scale = newKit.scale; candidate.series = newKit.series
                    candidate.grade = newKit.grade; candidate.jan = newKit.jan
                    candidate.imageURLString = formImageURLString
                    
                    push(.detail(status, candidate))
                }
            }
        case .detail: isPresented = false
        }
    }

    @ViewBuilder
    private func detailLayer(status: StatusKey, candidate: Candidate, isLandscape: Bool, size: CGSize, safeArea: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Image
                    detailImage(url: candidate.imageURLString)
                         .frame(height: 250)
                         .frame(maxWidth: .infinity)
                         .background(Color(UIColor.secondarySystemBackground))
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text(formTitle.isEmpty ? candidate.title : formTitle)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Status Badge
                        HStack {
                            Image(status.assetName)
                                .resizable()
                                .renderingMode(.template)
                                .frame(width: 20, height: 20)
                            Text(status.label)
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.currentTheme.mainColor.opacity(0.1))
                        .clipShape(Capsule())
                        
                        detailInfoList(candidate: candidate)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 100)
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Fixed Bottom Button
            VStack {
                Divider()
                Button {
                    LocalHaptics.success()
                    // Auto-Fill Blanks if applicable
                    if isCloudDiscovered {
                        Task { await DiscoveryManager.shared.fillBlanks(jan: formJAN, title: formTitle, maker: formMaker, scale: formScale, series: formSeries, grade: formGrade) }
                    }
                    goNext()
                } label: {
                     HStack {
                        Image(systemName: "checkmark")
                        Text("完了")
                            .font(.system(size: 16, weight: .bold))
                     }
                     .foregroundStyle(.white)
                     .frame(maxWidth: .infinity)
                     .frame(height: 50)
                     .background(themeManager.currentTheme.mainColor)
                     .clipShape(Capsule())
                     .shadow(color: themeManager.currentTheme.mainColor.opacity(0.4), radius: 8, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, safeArea.bottom + 10)
                .background(Color(UIColor.systemBackground))
            }
        }
    }

    private func formImageDisplay(url: String?, isExpanded: Bool = false) -> some View {
        HStack {
            Spacer()
            if let imgStr = url {
                // ✅ String Handling: Asset vs Web vs Local
                if imgStr.hasPrefix("asset://") {
                     PhAssetImage(localIdentifier: String(imgStr.dropFirst(8)))
                        .scaledToFit()
                        .cornerRadius(12)
                } else if let u = URL(string: imgStr), imgStr.hasPrefix("http") {
                    AsyncImage(url: u) { phase in
                        if let image = phase.image { image.resizable().scaledToFit().cornerRadius(12) }
                        else { Rectangle().fill(Color(UIColor.secondarySystemBackground)).cornerRadius(12) }
                    }
                } else if let localImg = ImageLinker.loadLocalImage(named: imgStr) {
                    Image(uiImage: localImg).resizable().scaledToFit().cornerRadius(12)
                } else {
                    Rectangle().fill(Color(UIColor.secondarySystemBackground)).cornerRadius(12)
                }
            } else { Rectangle().fill(Color(UIColor.secondarySystemBackground)).cornerRadius(12) }
            Spacer()
        }
        .frame(height: isExpanded ? nil : 180).frame(maxHeight: isExpanded ? .infinity : 180).padding(isExpanded ? 40 : 0)
    }

    private func detailImage(url: String?) -> some View {
        Group {
            if let imgStr = url {
                if imgStr.hasPrefix("asset://") {
                    PhAssetImage(localIdentifier: String(imgStr.dropFirst(8)))
                        .scaledToFit()
                } else if let u = URL(string: imgStr), imgStr.hasPrefix("http") {
                    AsyncImage(url: u) { phase in
                        if let img = phase.image { img.resizable().scaledToFit() }
                        else { Rectangle().fill(Color(UIColor.secondarySystemBackground)) }
                    }
                } else if let localImg = ImageLinker.loadLocalImage(named: imgStr) {
                    Image(uiImage: localImg).resizable().scaledToFit()
                } else { Rectangle().fill(Color(UIColor.secondarySystemBackground)) }
            } else { Rectangle().fill(Color(UIColor.secondarySystemBackground)) }
        }.cornerRadius(12)
    }




    private func detailInfoList(candidate: Candidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let maker = formMaker.isEmpty ? candidate.maker : formMaker
            let scale = formScale.isEmpty ? candidate.scale : formScale
            let series = formSeries.isEmpty ? candidate.series : formSeries
            let grade = formGrade.isEmpty ? candidate.grade : formGrade
            let jan = formJAN.isEmpty ? candidate.jan : formJAN
            Text("\(maker) ・ \(scale) ・ \(series)").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
            Text("Grade: \(grade)").font(.system(size: 15)).foregroundStyle(.secondary)
            Text("JAN: \(jan)").font(.system(size: 13, design: .monospaced)).foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.5))
            if !formMemo.isEmpty { Divider().padding(.vertical, 4); Text(formMemo).font(.system(size: 14)).foregroundStyle(.primary) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bottomBar(safeArea: EdgeInsets) -> some View {
        VStack(spacing: 0) {
            Divider().opacity(0.15)
            HStack(spacing: 14) {
                Spacer()
                if isRegisterStep || isDetailStep {
                    Button(action: { LocalHaptics.select(); goNext() }) {
                        HStack(spacing: 8) {
                            Text(isRegisterStep ? "確認画面へ" : "完了")
                                .font(.system(size: 16, weight: .bold))
                            Image(systemName: "arrow.right")
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 24)
                        .background(themeManager.currentTheme.mainColor)
                        .clipShape(Capsule())
                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.4), radius: 4, y: 2)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18 + safeArea.leading).padding(.trailing, safeArea.trailing).padding(.top, 12).padding(.bottom, 16 + safeArea.bottom)
        }.background(Color(UIColor.systemBackground))
    }

    private func push(_ step: Step) { stack.append(step) }
    private func goBack() { if stack.count > 1 { stack.removeLast() } else { isPresented = false } }
    

    
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

    private func runWebSearch() {
        let base = query.trimmingCharacters(in: .whitespacesAndNewlines); guard !base.isEmpty else { results = []; return }
        isSearching = true; results = []
        
        // 1. Local DB Search ONLY
        let masterResults = MasterCatalogDB.shared.search(query: base)
        self.results = masterResults
        
        // 2. God Mode Google Search
        if isGodModeEnabled && !googleApiKey.isEmpty {
            Task {
                do {
                    let googleItems = try await GoogleSearchClient.shared.search(query: "\(base) プラモデル")
                    let googleCandidates = googleItems.map { item -> Candidate in
                         // Title Cleaning
                         let fullText = "\(item.title) \(item.snippet)"
                         let p = TitleParser.parse(title: fullText, originalMaker: "", originalSeries: "")
                         return Candidate(
                             title: p.cleanTitle,
                             maker: p.maker,
                             scale: p.scale,
                             series: p.series,
                             grade: p.grade,
                             jan: "",
                             imageURLString: item.imageURL,
                             price: "",
                             isOfficial: item.link.contains("bandai-hobby.net")
                         )
                    }
                    
                    await MainActor.run {
                        withAnimation {
                            self.results.insert(contentsOf: googleCandidates, at: 0)
                            self.isSearching = false
                        }
                    }
                } catch {
                    await MainActor.run { self.isSearching = false }
                }
            }
        } else {
            // No API Search
            self.isSearching = false
        }
    }

}

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
