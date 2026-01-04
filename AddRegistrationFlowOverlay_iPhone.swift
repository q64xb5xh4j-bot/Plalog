//
//  AddRegistrationFlowOverlay_iPhone.swift V75
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
    
    private let iconSizeHome: CGFloat = 60
    private let orbSize: CGFloat = 70
    private let verticalSpacing: CGFloat = 12
    private let menuBottomOffsetPortrait: CGFloat = -58
    
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
    
    private var shouldMoveOrbToHeader: Bool {
        if keyboardHeight > 0 { return true }
        if case .search = current { return true }
        if case .register = current { return true }
        if case .detail = current { return true }
        if case .scan = current { return true }
        return false
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
                            Image(systemName: "plus.square.fill.on.square.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                            Text("アイテム登録")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.primary)
                            Spacer()
                            if shouldMoveOrbToHeader {
                                Color.clear.frame(width: orbSize, height: orbSize)
                            }
                        }
                        .padding()
                        .padding(.top, safeArea.top)
                        .background(Color.primary.opacity(0.05))
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
                
                BlueOrbView(isAnimating: true, size: orbSize)
                    .position(orbPosition(size: geo.size, safeArea: safeArea, isLandscape: isLandscape))
                    .onTapGesture {
                        LocalHaptics.tap()
                        goBack()
                    }
                    .zIndex(100)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: shouldMoveOrbToHeader)
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
    private func orbPosition(size: CGSize, safeArea: EdgeInsets, isLandscape: Bool) -> CGPoint {
        if shouldMoveOrbToHeader {
            let x = size.width - 20 - (orbSize / 2)
            let y = safeArea.top + (orbSize / 2) + 10
            return CGPoint(x: x, y: y)
        } else {
            if isLandscape {
                return CGPoint(x: size.width - 100, y: size.height - 60)
            } else {
                let bottomOffset = menuBottomOffsetPortrait + iconSizeHome + verticalSpacing + orbSize / 2
                let y = size.height - bottomOffset - 35 - (safeArea.bottom > 0 ? 0 : 20)
                return CGPoint(x: size.width / 2, y: y)
            }
        }
    }
    
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
        GeometryReader { geo in
            let sidePadding: CGFloat = 20
            let spacing: CGFloat = 16
            
            if isLandscape {
                ScrollView {
                    VStack {
                        Spacer(minLength: 20)
                        VStack(spacing: 16) {
                            Image("add").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor)
                            Text("どの状態で追加しますか？").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
                        }.padding(.bottom, 20)
                        let contentWidth = geo.size.width - (sidePadding * 2) - safeArea.trailing
                        let btnSize = min(contentWidth / 5, 80)
                        HStack(spacing: spacing) { ForEach(StatusKey.allCases) { s in statusIconBtn(s, size: btnSize) } }.padding(.horizontal, sidePadding)
                        Spacer(minLength: 20)
                    }
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image("add").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor)
                        Text("どの状態で追加しますか？").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
                    }.padding(.bottom, 40)
                    let availableWidth = geo.size.width - (sidePadding * 2) - (spacing * 4)
                    let btnSize = min(availableWidth / 5, 80)
                    HStack(spacing: spacing) { ForEach(StatusKey.allCases) { s in statusIconBtn(s, size: btnSize) } }.frame(maxWidth: .infinity).padding(.horizontal, sidePadding)
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
    
    private func statusIconBtn(_ s: StatusKey, size: CGFloat) -> some View {
        Button {
            LocalHaptics.select(); selectedStatus = s; selectedMethod = nil
            if s.allowsBarcode { push(.method(s)) } else { push(.search(s)) }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Color(UIColor.secondarySystemBackground)).frame(width: size, height: size)
                    .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                Image(s.assetName).resizable().renderingMode(.template).scaledToFit().frame(width: size * 0.5, height: size * 0.5).foregroundStyle(Color(red: 0.0, green: 0.65, blue: 0.90))
            }
        }.buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func methodPicker(status: StatusKey, safeArea: EdgeInsets, isLandscape: Bool) -> some View {
        GeometryReader { geo in
            let sidePadding: CGFloat = 20
            let spacing: CGFloat = 16
            
            if isLandscape {
                ScrollView {
                    VStack {
                        Spacer(minLength: 20)
                        VStack(spacing: 16) {
                            Image("add").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor)
                            Text("登録方法を選択").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
                        }.padding(.bottom, 20)
                        let contentWidth = geo.size.width - (sidePadding * 2) - (spacing * 2) - safeArea.trailing
                        let btnSize = min(contentWidth / 3, 100)
                        HStack(spacing: spacing) {
                            methodIconBtn(.barcode, status: status, size: btnSize)
                            methodIconBtn(.scan, status: status, size: btnSize)
                            methodIconBtn(.text, status: status, size: btnSize)
                        }.padding(.horizontal, sidePadding)
                        Spacer(minLength: 20)
                    }
                    .frame(minHeight: geo.size.height)
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack {
                    Spacer()
                    VStack(spacing: 16) {
                        Image("add").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor)
                        Text("登録方法を選択").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary)
                    }.padding(.bottom, 40)
                    let availableWidth = geo.size.width - (sidePadding * 2) - (spacing * 2)
                    let btnSize = min(availableWidth / 3, 100)
                    HStack(spacing: spacing) {
                        methodIconBtn(.barcode, status: status, size: btnSize)
                        methodIconBtn(.scan, status: status, size: btnSize)
                        methodIconBtn(.text, status: status, size: btnSize)
                    }.frame(maxWidth: .infinity).padding(.horizontal, sidePadding)
                    Spacer()
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
    }
    
    private func methodIconBtn(_ m: MethodKey, status: StatusKey, size: CGFloat) -> some View {
        Button {
            LocalHaptics.select(); selectedMethod = m
            switch m {
            case .barcode: push(.barcode(status))
            case .scan: push(.scan(status))
            case .text: push(.search(status))
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).fill(Color(UIColor.secondarySystemBackground)).frame(width: size, height: size)
                    .overlay(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous).stroke(Color.primary.opacity(0.1), lineWidth: 1))
                Image(m.assetName).resizable().renderingMode(.template).scaledToFit().frame(width: size * 0.5, height: size * 0.5).foregroundStyle(Color(red: 0.0, green: 0.65, blue: 0.90))
            }
        }.buttonStyle(.plain)
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
                BarcodeScannerView { code in handleScan(code: code, status: status) }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.primary.opacity(0.3), lineWidth: 1))
                RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(themeManager.currentTheme.mainColor.opacity(0.8), lineWidth: 2).frame(width: 250, height: 120)
                if isSearching { Color.black.opacity(0.4); ProgressView("情報を縫合中...").tint(.white) }
            }.padding(.horizontal, 18).padding(.bottom, 20)
            Spacer()
        }
    }
    
    @ViewBuilder
    private func cleanScanLayer(status: StatusKey, safeArea: EdgeInsets) -> some View {
        ZStack {
            CleanScannerView { detectedText in
                LocalHaptics.success()
                query = detectedText
                push(.search(status))
                runWebSearch()
            }
            .ignoresSafeArea()
            
            VStack {
                Spacer().frame(height: safeArea.top + 80)
                Text("CLEAN SCAN").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(themeManager.currentTheme.mainColor).padding(8).background(Color.black.opacity(0.6)).cornerRadius(4)
                Text("商品名や型番を枠内に写してタップ").font(.caption).foregroundStyle(.white).padding(.top, 4)
                Spacer()
                RoundedRectangle(cornerRadius: 20).stroke(themeManager.currentTheme.mainColor, lineWidth: 2).frame(width: 280, height: 150).background(Color.white.opacity(0.05))
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private func searchLayer(status: StatusKey, safeArea: EdgeInsets) -> some View {
        let isGodMode = (isGodModeEnabled && !googleApiKey.isEmpty)
        
        VStack(spacing: 0) {
            if !isSearchFocused {
                VStack(spacing: 16) {
                    Image("icon_text_search").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor)
                    Text(isGodMode ? "ULTRA LENS SEARCH" : "Webから探す").font(.system(size: 16, weight: .medium, design: .monospaced)).foregroundStyle(isGodMode ? themeManager.currentTheme.mainColor : .secondary)
                }.padding(.top, 20 + safeArea.top).padding(.bottom, 10)
            } else {
                Spacer().frame(height: safeArea.top + 10)
            }
            
            if isSearching {
                Spacer()
                ProgressView(isGodMode ? "ULTRA MODE ACTIVATED..." : "Searching...").tint(themeManager.currentTheme.mainColor)
                Spacer()
            } else if results.isEmpty {
                Spacer()
                Text(query.isEmpty ? "キーワードを入力" : "No results").foregroundStyle(.tertiary)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(results) { r in resultRow(r, status: status) }
                    }
                    .padding(.horizontal, 18).padding(.bottom, 10)
                }
            }
            
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 12) {
                    TextField("Gundam etc...", text: $query)
                        .focused($isSearchFocused).textInputAutocapitalization(.never).autocorrectionDisabled(true).submitLabel(.search)
                        .onSubmit { LocalHaptics.tap(); isSearchFocused = false; runWebSearch() }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(UIColor.secondarySystemBackground)))
                        .foregroundStyle(Color(UIColor.label))
                    Button(action: { LocalHaptics.select(); isSearchFocused = false; runWebSearch() }) {
                        Image(systemName: "magnifyingglass").font(.system(size: 20, weight: .bold)).foregroundStyle(.white).padding(12).background(themeManager.currentTheme.mainColor).clipShape(Circle())
                    }
                }.padding(.horizontal, 18 + safeArea.leading).padding(.top, 12).padding(.bottom, 16).background(Color(UIColor.systemBackground))
            }.padding(.bottom, keyboardHeight)
        }
        .onAppear { if query.isEmpty { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isSearchFocused = true } } }
    }
}
// AddRegistrationFlowOverlay_iPhone.swift V75
// PART 3 OF 3

extension RegistrationFlow_iPhone {
    private func resultRow(_ r: Candidate, status: StatusKey) -> some View {
        Button {
            LocalHaptics.tap(); isSearchFocused = false; prepareForm(from: r); push(.register(status, r))
        } label: {
            HStack(spacing: 12) {
                if let url = r.imageURL {
                    AsyncImage(url: url) { phase in if let img = phase.image { img.resizable().scaledToFill() } else { placeholderIcon } }
                        .frame(width: 54, height: 54).clipShape(RoundedRectangle(cornerRadius: 10))
                } else { placeholderIcon.frame(width: 54, height: 54) }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(r.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary).lineLimit(2)
                    Text("\(r.maker) \(r.grade) \(r.scale)").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(); Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.6))
            }.padding(12).background(RoundedRectangle(cornerRadius: 16).fill(Color(UIColor.secondarySystemBackground)))
        }.buttonStyle(.plain)
    }
    
    private var placeholderIcon: some View { ZStack { Color(UIColor.tertiarySystemFill); Image(systemName: "cube.box").foregroundStyle(.secondary) } }

    @ViewBuilder
    private func registerLayer(status: StatusKey, candidate: Candidate, isLandscape: Bool, size: CGSize, safeArea: EdgeInsets) -> some View {
        if isLandscape {
            HStack(spacing: 0) {
                ZStack { Color(UIColor.secondarySystemBackground).opacity(0.3).ignoresSafeArea(); candidateImageDisplay(candidate: candidate, isExpanded: true) }.frame(width: size.width * 0.5)
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20)
                            VStack(spacing: 16) { Image("edit").resizable().renderingMode(.template).scaledToFit().frame(width: 50, height: 50).foregroundStyle(themeManager.currentTheme.mainColor); Text("内容確認").font(.system(size: 16, weight: .bold)).foregroundStyle(.secondary) }
                            formFields(text: $formTitle, maker: $formMaker, scale: $formScale, series: $formSeries, grade: $formGrade, jan: $formJAN, memo: $formMemo).padding(.horizontal, 30).padding(.bottom, 50)
                        }.frame(maxWidth: .infinity)
                    }
                    VStack { Divider().background(Color.primary.opacity(0.1)); Button(action: { LocalHaptics.select(); goNext() }) { HStack { Text("登録を確定する").font(.system(size: 16, weight: .bold)); Image("icon_select_confirm").resizable().renderingMode(.template).scaledToFit().frame(width: 30, height: 30) }.foregroundStyle(themeManager.currentTheme.mainColor).padding(.vertical, 16).frame(maxWidth: .infinity).background(Color.primary.opacity(0.05)) }.buttonStyle(.plain) }.padding(.bottom, safeArea.bottom).background(Color(UIColor.systemBackground))
                }.frame(width: size.width * 0.5)
            }
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    candidateImageDisplay(candidate: candidate, isExpanded: false)
                    VStack(spacing: 16) { Image("edit").resizable().renderingMode(.template).scaledToFit().frame(width: 50, height: 50).foregroundStyle(themeManager.currentTheme.mainColor); Text("内容を整えて保存").font(.system(size: 16, weight: .medium)).foregroundStyle(.secondary) }
                    formFields(text: $formTitle, maker: $formMaker, scale: $formScale, series: $formSeries, grade: $formGrade, jan: $formJAN, memo: $formMemo).padding(.horizontal, 18).padding(.bottom, 100)
                }.padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private func detailLayer(status: StatusKey, candidate: Candidate, isLandscape: Bool, size: CGSize, safeArea: EdgeInsets) -> some View {
        if isLandscape {
            HStack(spacing: 0) {
                ZStack { Color(UIColor.secondarySystemBackground).opacity(0.3).ignoresSafeArea(); detailImage(url: candidate.imageURL).padding(40) }.frame(width: size.width * 0.5)
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20); Text(formTitle.isEmpty ? candidate.title : formTitle).font(.system(size: 24, weight: .bold)).multilineTextAlignment(.center).padding(.horizontal, 20).foregroundStyle(.primary); detailInfoList(candidate: candidate).padding(.horizontal, 30)
                        }.frame(maxWidth: .infinity)
                    }
                    VStack { Divider().background(Color.primary.opacity(0.1)); Button(action: { LocalHaptics.select(); goNext() }) { HStack { Text("完了").font(.system(size: 16, weight: .bold)); Image("icon_select_confirm").resizable().renderingMode(.template).scaledToFit().frame(width: 30, height: 30) }.foregroundStyle(themeManager.currentTheme.mainColor).padding(.vertical, 16).frame(maxWidth: .infinity).background(Color.primary.opacity(0.05)) }.buttonStyle(.plain) }.padding(.bottom, safeArea.bottom).background(Color(UIColor.systemBackground))
                }.frame(width: size.width * 0.5)
            }
        } else {
            VStack(spacing: 0) {
                Text(formTitle.isEmpty ? candidate.title : formTitle).font(.system(size: 24, weight: .bold)).multilineTextAlignment(.center).padding(.top, 20).padding(.horizontal, 20).foregroundStyle(.primary)
                Spacer()
                VStack(spacing: 24) {
                    detailImage(url: candidate.imageURL).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 22)).padding(.horizontal, 20)
                    detailInfoList(candidate: candidate).padding(.horizontal, 24)
                }
                Spacer()
            }
        }
    }

    private func candidateImageDisplay(candidate: Candidate, isExpanded: Bool = false) -> some View {
        HStack {
            Spacer()
            if let url = candidate.imageURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFit().cornerRadius(12) }
                    else { Rectangle().fill(Color(UIColor.secondarySystemBackground)).cornerRadius(12) }
                }
            } else { Rectangle().fill(Color(UIColor.secondarySystemBackground)).cornerRadius(12) }
            Spacer()
        }
        .frame(height: isExpanded ? nil : 180).frame(maxHeight: isExpanded ? .infinity : 180).padding(isExpanded ? 40 : 0)
    }

    private func detailImage(url: URL?) -> some View {
        Group {
            if let url = url {
                AsyncImage(url: url) { phase in
                    if let img = phase.image { img.resizable().scaledToFit() }
                    else { Rectangle().fill(Color(UIColor.secondarySystemBackground)) }
                }
            } else { Rectangle().fill(Color(UIColor.secondarySystemBackground)) }
        }.cornerRadius(12)
    }

    private func formFields(text: Binding<String>, maker: Binding<String>, scale: Binding<String>, series: Binding<String>, grade: Binding<String>, jan: Binding<String>, memo: Binding<String>) -> some View {
        VStack(spacing: 14) {
            formField(label: "Product", text: text)
            formField(label: "Maker", text: maker)
            formField(label: "Scale", text: scale, isReadOnly: true)
            formField(label: "Series", text: series)
            formField(label: "Grade", text: grade)
            formField(label: "JAN", text: jan)
            formField(label: "Memo", text: memo, isMultiline: true)
        }
    }

    private func formField(label: String, text: Binding<String>, isMultiline: Bool = false, isReadOnly: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 14, weight: .medium)).foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.7))
            if isMultiline {
                TextEditor(text: text).scrollContentBackground(.hidden).frame(height: 88).padding(10).background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
                    .disabled(isReadOnly)
                    .foregroundStyle(Color(UIColor.label))
            } else {
                TextField("", text: text).padding(.horizontal, 12).padding(.vertical, 12).background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemBackground)))
                    .disabled(isReadOnly)
                    .foregroundStyle(Color(UIColor.label))
            }
        }
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
                Color.clear.frame(width: orbSize, height: orbSize)
                Spacer()
                if isRegisterStep || isDetailStep {
                    Button(action: { LocalHaptics.select(); goNext() }) {
                        Image("icon_select_confirm").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor)
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18 + safeArea.leading).padding(.trailing, safeArea.trailing).padding(.top, 12).padding(.bottom, 16 + safeArea.bottom)
        }.background(Color(UIColor.systemBackground))
    }

    private func push(_ step: Step) { stack.append(step) }
    private func goBack() { if stack.count > 1 { stack.removeLast() } else { isPresented = false } }
    
    private func goNext() {
        switch current {
        case .status, .method, .barcode, .scan, .search: break
        case .register(let status, var candidate):
            let newKit = Kit(
                title: formTitle,
                maker: formMaker,
                series: formSeries,
                grade: formGrade,
                scale: formScale,
                jan: formJAN,
                statusValue: status.dbValue,
                imageURLString: candidate.imageURL?.absoluteString,
                memo: formMemo
            )
            modelContext.insert(newKit)
            candidate.title = newKit.title; candidate.maker = newKit.maker; candidate.scale = newKit.scale; candidate.series = newKit.series; candidate.grade = newKit.grade; candidate.jan = newKit.jan
            push(.detail(status, candidate))
        case .detail: isPresented = false
        }
    }

    private func runWebSearch() {
        let base = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { results = []; return }
        isSearching = true
        
        Task {
            do {
                if isGodModeEnabled && !googleApiKey.isEmpty {
                    let googleItems = try await GoogleSearchClient.shared.search(query: "\(base) プラモデル")
                    let candidates = googleItems.map { item -> Candidate in
                        let fullText = "\(item.title) \(item.snippet)"
                        let parsed = TitleParser.parse(title: fullText, originalMaker: "", originalSeries: "")
                        return Candidate(
                            title: parsed.cleanTitle, maker: parsed.maker, scale: parsed.scale,
                            series: parsed.series, grade: parsed.grade, jan: "",
                            imageURL: URL(string: item.imageURL ?? ""), price: ""
                        )
                    }
                    await MainActor.run { self.results = candidates; self.isSearching = false }
                } else {
                    let items = try await YahooShoppingClient.shared.search(query: "\(base) プラモデル")
                    let allCandidates = items.map { item -> Candidate in
                        let fullText = "\(item.name) \(item.maker?.name ?? "") \(item.brand?.name ?? "")"
                        let parsed = TitleParser.parse(title: fullText, originalMaker: item.maker?.name ?? "", originalSeries: item.brand?.name ?? "")
                        return Candidate(
                            title: parsed.cleanTitle, maker: parsed.maker, scale: parsed.scale, series: parsed.series, grade: parsed.grade, jan: item.janCode ?? "", imageURL: item.imageURL, price: item.priceLabel
                        )
                    }
                    let keywords = base.split(separator: " ").map { String($0) }
                    let filtered = allCandidates.filter { c in keywords.allSatisfy { c.title.localizedCaseInsensitiveContains($0) } }
                    await MainActor.run { self.results = filtered; self.isSearching = false }
                }
            } catch {
                await MainActor.run { LocalHaptics.error(); self.isSearching = false; self.errorMessage = error.localizedDescription; self.showErrorAlert = true }
            }
        }
    }

    private func prepareForm(from c: Candidate) {
        let parsed = TitleParser.parse(title: c.title, originalMaker: c.maker, originalSeries: c.series)
        var finalTitle = parsed.cleanTitle
        
        if let extractedModel = TitleParser.extractOnlyModelNumber(from: c.title) {
            if !finalTitle.contains(extractedModel) {
                finalTitle = "\(extractedModel) \(finalTitle)"
            }
        }
        
        formTitle = finalTitle
        formMaker = parsed.maker
        formScale = c.scale.isEmpty ? parsed.scale : c.scale
        formSeries = parsed.series
        formGrade = c.grade.isEmpty ? parsed.grade : c.grade
        formJAN = c.jan
        formMemo = ""
    }

    private func handleScan(code: String, status: StatusKey) {
        guard !isSearching else { return }; isSearching = true
        Task {
            var finalCandidate: Candidate?
            var originalCleanName = ""
            
            if let hit = await MainActor.run(body: { CSVDataManager.shared.findByJAN(code) }) {
                originalCleanName = hit.title
                finalCandidate = Candidate(title: hit.title, maker: hit.maker, scale: hit.scale, series: hit.series, grade: hit.grade, jan: hit.jan, imageURL: nil)
            } else {
                do {
                    if let y = try await YahooShoppingClient.shared.searchByJAN(code) {
                        let p = TitleParser.parse(title: y.name, originalMaker: y.maker?.name ?? "", originalSeries: y.brand?.name ?? "")
                        originalCleanName = p.cleanTitle
                        finalCandidate = Candidate(title: p.cleanTitle, maker: p.maker, scale: p.scale, series: p.series, grade: p.grade, jan: y.janCode ?? code, imageURL: y.imageURL, price: y.priceLabel)
                    }
                } catch { print(error) }
            }
            
            if var candidate = finalCandidate {
                if isGodModeEnabled && !googleApiKey.isEmpty && !originalCleanName.isEmpty {
                    do {
                        let googleItems = try await GoogleSearchClient.shared.search(query: "\(originalCleanName) 型式番号 Wikipedia")
                        if let firstResult = googleItems.first {
                            if let extractedModel = TitleParser.extractOnlyModelNumber(from: "\(firstResult.title) \(firstResult.snippet)") {
                                if !candidate.title.contains(extractedModel) {
                                    candidate.title = "\(extractedModel) \(candidate.title)"
                                }
                            }
                        }
                    } catch { print("Model-only extraction failed: \(error)") }
                }
                
                await MainActor.run {
                    LocalHaptics.success()
                    prepareForm(from: candidate)
                    isSearching = false
                    push(.register(status, candidate))
                }
            } else {
                await MainActor.run {
                    LocalHaptics.select()
                    let c = Candidate(title: "", maker: "", scale: "", series: "", grade: "", jan: code, imageURL: nil)
                    prepareForm(from: c)
                    isSearching = false
                    push(.register(status, c))
                }
            }
        }
    }
}
