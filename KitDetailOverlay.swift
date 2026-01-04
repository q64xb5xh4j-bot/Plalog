// KitDetailOverlay.swift V40
// 1. バージョン管理ルールに基づき更新 (V39 -> V40)
// 2. 修正点:
//    - デバイス分岐用のラッパーとして再構築
//    - 共通のサブビュー(DetailWebImageSearchModal)をここに定義
// 3. 全文差し替え・分割送付ルール適用

import SwiftUI
import SwiftData
import Combine
import Photos

// MARK: - Main Wrapper (分岐ポイント)
struct KitDetailOverlay: View {
    @Binding var kit: Kit?
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            KitDetailOverlay_iPad(kit: $kit)
        } else {
            KitDetailOverlay_iPhone(kit: $kit)
        }
    }
}

// MARK: - Shared Helper Components (共通コンポーネント)

struct DetailWebImageSearchModal: View {
    let kit: Kit
    @Binding var isPresented: Bool
    let initialSearchText: String
    
    @State private var searchText = ""
    @State private var items: [YahooItem] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SEARCH BOX ART")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                Spacer()
                Button("CLOSE") { isPresented = false }
                    .font(.system(size: 14, weight: .bold))
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            
            TextField("検索ワードを調整...", text: $searchText)
                .padding()
                .textFieldStyle(.roundedBorder)
                .onSubmit { search() }
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                        ForEach(items) { item in
                            Button {
                                kit.imageURLString = item.imageURL?.absoluteString
                                LocalHaptics.select()
                                isPresented = false
                            } label: {
                                AsyncImage(url: item.imageURL) { p in
                                    if let i = p.image {
                                        i.resizable().interpolation(.high).scaledToFill()
                                    } else {
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(height: 100)
                                .clipped()
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear {
            searchText = initialSearchText
            search()
        }
    }
    
    private func search() {
        isLoading = true
        Task {
            do {
                let res = try await YahooShoppingClient.shared.search(query: searchText)
                await MainActor.run {
                    items = res
                    isLoading = false
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}
