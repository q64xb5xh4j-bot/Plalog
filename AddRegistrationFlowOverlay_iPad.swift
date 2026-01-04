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
    @State private var results: [Candidate] = []
    @State private var isSearching: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    
    @State private var showErrorAlert: Bool = false
    @State private var errorMessage: String = ""
    
    @FocusState private var isSearchFocused: Bool
    
    @State private var formTitle: String = ""; @State private var formMaker: String = ""; @State private var formScale: String = ""
    @State private var formSeries: String = ""; @State private var formGrade: String = ""; @State private var formJAN: String = ""; @State private var formMemo: String = ""
    
    private var current: Step { stack.last ?? .status }
    private let orbSize: CGFloat = 70
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // 背景色変更
                Color(UIColor.systemBackground).ignoresSafeArea()
                    .onTapGesture { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "plus.square.fill.on.square.fill").font(.system(size: 20)).foregroundStyle(themeManager.currentTheme.mainColor)
                        Text("アイテム登録").font(.system(size: 20, weight: .bold)).foregroundStyle(.primary)
                        Spacer()
                    }.padding().background(Color.primary.opacity(0.05))
                    
                    content.frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if !isSearching {
                        if case .scan = current {} else { bottomBar }
                    }
                }
                
                BlueOrbView(isAnimating: true, size: orbSize)
                    .position(
                        x: geo.size.width - 80,
                        y: keyboardHeight > 0 ? geo.size.height - keyboardHeight - 50 : geo.size.height - 100
                    )
                    .onTapGesture { LocalHaptics.tap(); goBack() }
                    .zIndex(100)
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
        .alert("検索エラー", isPresented: $showErrorAlert) { Button("OK", role: .cancel) { } } message: { Text(errorMessage) }
    }
    
    @ViewBuilder
    private var content: some View {
        switch current {
        case .status:
            VStack(spacing: 0) {
                Spacer(); VStack(spacing: 16) { Image("add").resizable().renderingMode(.template).scaledToFit().frame(width: 80, height: 80).foregroundStyle(themeManager.currentTheme.mainColor); Text("状態を選択").font(.system(size: 20, weight: .bold)).foregroundStyle(.secondary) }.padding(.bottom, 40)
                HStack(spacing: 24) { ForEach(StatusKey.allCases) { s in statusIconBtn(s, size: 100) } }; Spacer()
            }
        case .method(let s):
            VStack {
                Spacer(); VStack(spacing: 16) { Image("add").resizable().renderingMode(.template).scaledToFit().frame(width: 80, height: 80).foregroundStyle(themeManager.currentTheme.mainColor); Text("登録方法を選択").font(.system(size: 20, weight: .bold)).foregroundStyle(.secondary) }.padding(.bottom, 40)
                HStack(spacing: 40) {
                    methodIconBtn(.barcode, status: s, size: 120)
                    methodIconBtn(.scan, status: s, size: 120)
                    methodIconBtn(.text, status: s, size: 120)
                }; Spacer()
            }
        case .barcode(let s):
            VStack(spacing: 0) {
                VStack(spacing: 16) { Image("icon_barcode").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor); Text("バーコードをスキャン").font(.system(size: 16, weight: .bold)).foregroundStyle(.secondary) }.padding(.top, 40).padding(.bottom, 40)
                ZStack {
                    BarcodeScannerView { code in handleScan(code: code, status: s) }.clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous)).overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1))
                    RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(themeManager.currentTheme.mainColor, lineWidth: 2).frame(width: 300, height: 150)
                    if isSearching { Color.black.opacity(0.4); ProgressView("情報を縫合中...").tint(.white) }
                }.padding(.horizontal, 40).frame(maxHeight: 500)
                Spacer()
            }
        case .scan(let s):
            ZStack {
                CleanScannerView { detectedText in
                    LocalHaptics.select()
                    query = detectedText
                    push(.search(s))
                    runWebSearch()
                }
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(40)
                
                VStack {
                    Spacer().frame(height: 80)
                    Text("CLEAN SCAN (iPad)").font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(themeManager.currentTheme.mainColor).padding(12).background(Color.black.opacity(0.7)).cornerRadius(8)
                    Text("箱の文字をタップして検索").font(.body).foregroundStyle(.white).padding(.top, 4).shadow(radius: 4)
                    Spacer()
                    RoundedRectangle(cornerRadius: 20).stroke(themeManager.currentTheme.mainColor, lineWidth: 3).frame(width: 400, height: 200).background(Color.white.opacity(0.05))
                    Spacer()
                }
            }
        case .search(let s):
            let isGodMode = (isGodModeEnabled && !googleApiKey.isEmpty)
            
            VStack(spacing: 0) {
                VStack(spacing: 16) {
                    Image("icon_text_search").resizable().renderingMode(.template).scaledToFit().frame(width: 50, height: 50).foregroundStyle(themeManager.currentTheme.mainColor)
                    Text(isGodMode ? "ULTRA LENS SEARCH" : "キーワード検索").font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundStyle(isGodMode ? themeManager.currentTheme.mainColor : .secondary)
                }.padding(.top, 40).padding(.bottom, 20)
                
                HStack(spacing: 12) {
                    TextField("", text: $query, prompt: Text("キーワードを入力...").foregroundStyle(.gray))
                        .focused($isSearchFocused).onSubmit { runWebSearch() }
                        .padding(14).background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.1))).foregroundStyle(.primary)
                    Button { runWebSearch() } label: { Image(systemName: "magnifyingglass").font(.title2).foregroundStyle(.white).padding(12).background(themeManager.currentTheme.mainColor).clipShape(Circle()) }
                }.padding(.horizontal, 60).padding(.bottom, 30)
                
                if isSearching {
                    Spacer(); ProgressView().tint(themeManager.currentTheme.mainColor); Spacer()
                } else if !results.isEmpty {
                    ScrollView { LazyVStack(spacing: 12) { ForEach(results) { r in resultRow(r, status: s) } }.padding(.horizontal, 60).padding(.bottom, 100) }
                } else {
                    Spacer(); Text("No results").foregroundStyle(.tertiary); Spacer()
                }
            }
            .onAppear { if query.isEmpty { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isSearchFocused = true } } }
        case .register(let s, let c):
            HStack(spacing: 0) {
                ZStack { Color(UIColor.secondarySystemBackground).opacity(0.3); candidateImageDisplay(candidate: c) }.frame(width: UIScreen.main.bounds.width * 0.5)
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20); VStack(spacing: 16) { Image("edit").resizable().renderingMode(.template).scaledToFit().frame(width: 50, height: 50).foregroundStyle(themeManager.currentTheme.mainColor); Text("内容確認").font(.system(size: 16, weight: .bold)).foregroundStyle(.secondary) }
                            formFields(text: $formTitle, maker: $formMaker, scale: $formScale, series: $formSeries, grade: $formGrade, jan: $formJAN, memo: $formMemo).padding(.horizontal, 40).padding(.bottom, 50)
                        }.frame(maxWidth: .infinity)
                    }
                    // ✅ 修正: 決定ボタンを左寄せ (HStack + Spacer)
                    VStack {
                        Divider()
                        HStack {
                            Button(action: { LocalHaptics.select(); goNext() }) {
                                HStack {
                                    Image("icon_select_confirm").resizable().renderingMode(.template).scaledToFit().frame(width: 44, height: 44)
                                    Text("登録を確定する").font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                                .padding(.vertical, 12).padding(.horizontal, 24)
                                .background(Color.primary.opacity(0.05)).cornerRadius(12)
                            }.buttonStyle(.plain)
                            Spacer() // 左に寄せるため、右にスペース
                        }.padding(20)
                    }.background(Color(UIColor.systemBackground))
                }.frame(width: UIScreen.main.bounds.width * 0.5)
            }
        case .detail(let s, let c):
            HStack(spacing: 0) {
                ZStack { Color(UIColor.secondarySystemBackground).opacity(0.3); candidateImageDisplay(candidate: c) }.frame(width: UIScreen.main.bounds.width * 0.5)
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 20); Text(formTitle.isEmpty ? c.title : formTitle).font(.largeTitle).bold().padding(20).foregroundStyle(.primary);
                            detailInfoList(candidate: c).padding(40)
                        }.frame(maxWidth: .infinity)
                    }
                    // ✅ 修正: 完了ボタンを左寄せ
                    VStack {
                        Divider()
                        HStack {
                            Button(action: { LocalHaptics.select(); goNext() }) {
                                HStack {
                                    Image("icon_select_confirm").resizable().renderingMode(.template).scaledToFit().frame(width: 44, height: 44)
                                    Text("完了").font(.system(size: 16, weight: .bold))
                                }
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                                .padding(.vertical, 12).padding(.horizontal, 24)
                                .background(Color.primary.opacity(0.05)).cornerRadius(12)
                            }.buttonStyle(.plain)
                            Spacer() // 左に寄せる
                        }.padding(20)
                    }.background(Color(UIColor.systemBackground))
                }.frame(width: UIScreen.main.bounds.width * 0.5)
            }
        }
    }
    
    private var bottomBar: some View {
        VStack(spacing: 0) {
            // ✅ 修正: Portrait時も決定ボタンを左側に配置して、右下のオーブと離す
            HStack(spacing: 14) {
                if case .register = current {
                    Button(action: { LocalHaptics.select(); goNext() }) { Image("icon_select_confirm").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor) }
                }
                else if case .detail = current {
                    Button(action: { LocalHaptics.select(); goNext() }) { Image("icon_select_confirm").resizable().renderingMode(.template).scaledToFit().frame(width: 60, height: 60).foregroundStyle(themeManager.currentTheme.mainColor) }
                }
                
                Spacer()
                
                // 右下はオーブの領域 (透明)
                Color.clear.frame(width: orbSize, height: orbSize)
            }.padding(20)
        }.background(Color(UIColor.systemBackground))
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
                        if let url = r.imageURL { AsyncImage(url: url) { phase in if let img = phase.image { img.resizable().scaledToFill() } else { Color.gray.opacity(0.3) } }.frame(width: 80, height: 80).cornerRadius(8) } else { Color.gray.opacity(0.3).frame(width: 80, height: 80).cornerRadius(8) }
                        VStack(alignment: .leading) { Text(r.title).font(.title3).bold().foregroundStyle(.primary); Text("\(r.maker) \(r.grade) \(r.scale)").foregroundStyle(.secondary) }
                        Spacer(); Image(systemName: "chevron.right").foregroundStyle(.gray)
                    }.padding().background(Color.primary.opacity(0.05)).cornerRadius(12)
                }.buttonStyle(.plain)
            }
            @ViewBuilder
            private func candidateImageDisplay(candidate: Candidate) -> some View {
                if let url = candidate.imageURL {
                    AsyncImage(url: url) { phase in if let img = phase.image { img.resizable().scaledToFit() } else { ProgressView() } }
                } else { Image(systemName: "cube.box").font(.system(size: 80)).foregroundStyle(.gray) }
            }
            private func formFields(text: Binding<String>, maker: Binding<String>, scale: Binding<String>, series: Binding<String>, grade: Binding<String>, jan: Binding<String>, memo: Binding<String>) -> some View {
                VStack(spacing: 20) { formField("Product", text); formField("Maker", maker); formField("Scale", scale, isReadOnly: true); formField("Series", series); formField("Grade", grade); formField("JAN", jan); formField("Memo", memo, isMultiline: true) }
            }
            private func formField(_ label: String, _ text: Binding<String>, isMultiline: Bool = false, isReadOnly: Bool = false) -> some View {
                VStack(alignment: .leading) { Text(label).bold().foregroundStyle(themeManager.currentTheme.mainColor); if isMultiline { TextEditor(text: text).frame(height: 100).padding(10).background(Color.primary.opacity(0.1)).cornerRadius(8).foregroundStyle(.primary).disabled(isReadOnly) } else { TextField("", text: text).padding().background(Color.primary.opacity(0.1)).cornerRadius(8).foregroundStyle(.primary).disabled(isReadOnly) } }
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
                    var finalCandidate: Candidate?
                    if let hit = await MainActor.run(body: { CSVDataManager.shared.findByJAN(code) }) {
                        finalCandidate = Candidate(title: hit.title, maker: hit.maker, scale: hit.scale, series: hit.series, grade: hit.grade, jan: hit.jan, imageURL: nil)
                    } else {
                        do { if let y = try await YahooShoppingClient.shared.searchByJAN(code) {
                            let fullText = "\(y.name) \(y.maker?.name ?? "") \(y.brand?.name ?? "")"
                            let p = TitleParser.parse(title: fullText, originalMaker: y.maker?.name ?? "", originalSeries: y.brand?.name ?? "")
                            finalCandidate = Candidate(title: p.cleanTitle, maker: p.maker, scale: p.scale, series: p.series, grade: p.grade, jan: y.janCode ?? code, imageURL: y.imageURL, price: y.priceLabel)
                        } } catch { print(error) }
                    }
                    
                    if var candidate = finalCandidate {
                        if isGodModeEnabled && !googleApiKey.isEmpty && !candidate.title.isEmpty {
                            do {
                                let googleItems = try await GoogleSearchClient.shared.search(query: "\(candidate.title) 型式番号 Model Number")
                                if let firstResult = googleItems.first {
                                    let mergedText = "\(firstResult.title) \(firstResult.snippet) \(candidate.title)"
                                    let p = TitleParser.parse(title: mergedText, originalMaker: candidate.maker, originalSeries: candidate.series)
                                    candidate.title = p.cleanTitle
                                    if candidate.scale.isEmpty { candidate.scale = p.scale }
                                    if candidate.grade.isEmpty { candidate.grade = p.grade }
                                    if candidate.series.isEmpty { candidate.series = p.series }
                                }
                            } catch { print("iPad model search failed: \(error)") }
                        }
                        await MainActor.run { prepareForm(from: candidate); isSearching = false; push(.register(status, candidate)) }
                    } else {
                        await MainActor.run { let c = Candidate(title: "", maker: "", scale: "", series: "", grade: "", jan: code, imageURL: nil); prepareForm(from: c); isSearching = false; push(.register(status, c)) }
                    }
                }
            }
            private func runWebSearch() {
                let base = query.trimmingCharacters(in: .whitespacesAndNewlines); guard !base.isEmpty else { results = []; return }; isSearching = true
                Task {
                    do {
                        if isGodModeEnabled && !googleApiKey.isEmpty {
                            let googleItems = try await GoogleSearchClient.shared.search(query: "\(base) プラモデル")
                            let candidates = googleItems.map { item -> Candidate in
                                let p = TitleParser.parse(title: "\(item.title) \(item.snippet)", originalMaker: "", originalSeries: "")
                                return Candidate(title: p.cleanTitle, maker: p.maker, scale: p.scale, series: p.series, grade: p.grade, jan: "", imageURL: URL(string: item.imageURL ?? ""), price: "")
                            }
                            await MainActor.run { self.results = candidates; self.isSearching = false }
                        } else {
                            let items = try await YahooShoppingClient.shared.search(query: "\(base) プラモデル")
                            let allCandidates = items.map { item -> Candidate in
                                let p = TitleParser.parse(title: "\(item.name) \(item.maker?.name ?? "")", originalMaker: item.maker?.name ?? "", originalSeries: item.brand?.name ?? "")
                                return Candidate(title: p.cleanTitle, maker: p.maker, scale: p.scale, series: p.series, grade: p.grade, jan: item.janCode ?? "", imageURL: item.imageURL, price: item.priceLabel)
                            }
                            await MainActor.run { self.results = allCandidates; self.isSearching = false }
                        }
                    } catch { await MainActor.run { self.isSearching = false; self.errorMessage = error.localizedDescription; self.showErrorAlert = true } }
                }
            }
            private func prepareForm(from c: Candidate) { let parsed = TitleParser.parse(title: c.title, originalMaker: c.maker, originalSeries: c.series); formTitle = parsed.cleanTitle; formMaker = parsed.maker; formScale = c.scale.isEmpty ? parsed.scale : c.scale; formSeries = parsed.series; formGrade = c.grade.isEmpty ? parsed.grade : c.grade; formJAN = c.jan; formMemo = "" }
            private func goNext() {
                switch current {
                case .status, .method, .barcode, .scan, .search: break
                case .register(let status, var candidate):
                    let newKit = Kit(title: formTitle.isEmpty ? candidate.title : formTitle, maker: formMaker.isEmpty ? candidate.maker : formMaker, series: formSeries.isEmpty ? candidate.series : formSeries, grade: formGrade.isEmpty ? candidate.grade : formGrade, scale: formScale.isEmpty ? candidate.scale : formScale, jan: formJAN.isEmpty ? candidate.jan : formJAN, statusValue: status.dbValue, imageURLString: candidate.imageURL?.absoluteString, memo: formMemo)
                    modelContext.insert(newKit); candidate.title = newKit.title; candidate.maker = newKit.maker; candidate.scale = newKit.scale; candidate.series = newKit.series; candidate.grade = newKit.grade; candidate.jan = newKit.jan; push(.detail(status, candidate))
                case .detail: isPresented = false
                }
            }
        }
