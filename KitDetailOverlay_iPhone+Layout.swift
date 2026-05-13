import SwiftUI

extension KitDetailOverlay_iPhone {
    @ViewBuilder
    func landscapeLayout(geo: GeometryProxy, targetKit: Kit) -> some View {
        HStack(spacing: 0) {
            // ✅ 入力中は画像を隠してスペースを確保
            if focusedField == nil {
                ZStack {
                    Color(UIColor.secondarySystemBackground).ignoresSafeArea()
                    kitImageSection(kit: targetKit, isExpanded: true)
                        .padding()
                }
                .frame(width: geo.size.width * 0.4)
                .transition(.move(edge: .leading))
            }
            
            // [右カラム] 情報エリア
            VStack(spacing: 0) {
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
                                    .frame(maxWidth: focusedField == nil ? 200 : .infinity)
                                
                                if focusedField == nil {
                                    HStack(spacing: 12) {
                                        buildLogButtonIconOnly()
                                        updateButtonIconOnly(targetKit: targetKit)
                                        deleteButtonIconOnly()
                                    }
                                } else {
                                    Button("完了") { focusedField = nil }
                                        .buttonStyle(.borderedProminent)
                                        .tint(themeManager.currentTheme.mainColor)
                                }
                                
                                if focusedField == nil { Spacer().frame(width: 90) }
                            }
                            .padding(.bottom, 20)
                            Spacer().frame(height: 300)
                        }
                        .padding(.horizontal, 20)
                        .onChange(of: focusedField) { oldValue, newValue in
                             if let field = newValue {
                                 LocalHaptics.tap()
                                 withAnimation { proxy.scrollTo(field, anchor: .center) }
                             }
                        }
                    }
                }
            }
            .frame(width: focusedField == nil ? geo.size.width * 0.6 : geo.size.width)
        }
    }

    @ViewBuilder
    func portraitLayout(geo: GeometryProxy, targetKit: Kit, proxy: ScrollViewProxy?) -> some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 🔹 DISCOVERY BADGE (Fixed)
                    if let d = discoveryRecord {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles").font(.title2).foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                if d.discovererName == myPilotName {
                                    Text("YOU DISCOVERED THIS!").font(.caption).bold().foregroundStyle(.yellow)
                                } else {
                                    Text("DISCOVERED BY").font(.caption).bold().foregroundStyle(.secondary)
                                }
                                HStack(alignment: .lastTextBaseline) {
                                    Text(d.discovererName).font(.headline.monospaced()).bold().foregroundStyle(.primary)
                                    Text(d.discoveredDate.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(d.discovererName == myPilotName ? Color.yellow.opacity(0.1) : Color.primary.opacity(0.03))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(d.discovererName == myPilotName ? Color.yellow.opacity(0.5) : Color.primary.opacity(0.1), lineWidth: 1))
                    }

                    kitImageSection(kit: targetKit, isExpanded: false)
                    editableInfoSection()
                    Divider().padding(.horizontal, 10)
                    memoSection(isLandscape: false).padding(.horizontal, 10)
                    statusChanger(kit: targetKit)
                    Spacer().frame(height: 300)
                }
                .padding(.top, 10)
                .onChange(of: focusedField) { oldValue, newValue in
                     if let field = newValue {
                         withAnimation { proxy.scrollTo(field, anchor: .center) }
                     }
                }
            }
        }
        
        if focusedField == nil {
            portraitBottomControlBar(targetKit: targetKit)
        }
    }
}
