// PurchaseOverlay.swift V6
// 1. バージョン管理ルールに基づき更新 (V5 -> V6)
// 2. 変更点: SF的表現の強化 & 警告表示ロジック追加 (ユーザー指定)
//    - @Queryを追加し、所有キット数を参照
//    - 10件以上かつ未課金の場合、ヘッダーに "WARNING: CAPACITY FULL" を赤字で表示
//    - タイトル文言を "SYSTEM UPGRADE" などSF調に調整
// 3. 全文差し替えルール適用

import SwiftUI
import StoreKit
import SwiftData

struct PurchaseOverlay: View {
    @Binding var isPresented: Bool
    @ObservedObject private var storeManager = StoreKitManager.shared
    @Environment(\.colorScheme) private var colorScheme
    
    // ✅ 追加: 所有キット数をチェックして警告を出すため
    @Query private var allKits: [Kit]
    
    // アニメーション用
    @State private var isAnimating = false
    @State private var showSpinner = false
    
    // 警告を表示するか判定
    private var isCapacityLimitReached: Bool {
        return !storeManager.isPremium && allKits.count >= 10
    }
    
    var body: some View {
        ZStack {
            // 背景（半透明ダーク）
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    LocalHaptics.tap()
                    close()
                }
            
            // メインコンテンツ
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // 1. ヘッダー: HANGAR EXPANSION / WARNING
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.3x3.topleft.filled")
                            .font(.system(size: 48))
                            .foregroundStyle(isCapacityLimitReached ? LinearGradient(colors: [.red, .orange], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [.blue, .cyan], startPoint: .top, endPoint: .bottom))
                            .shadow(color: isCapacityLimitReached ? .red : .blue, radius: 10)
                            .padding(.bottom, 8)
                        
                        // ✅ 警告表示 (ユーザー指定)
                        if isCapacityLimitReached {
                            Text("WARNING: CAPACITY FULL")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundStyle(.red)
                                .tracking(1)
                                .padding(.bottom, 4)
                        } else {
                            Text("HANGAR EXPANSION")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .tracking(2)
                        }
                        
                        Text(isCapacityLimitReached ? "積載限界到達" : "格納庫拡張プロトコル")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 40)
                    
                    // 2. 機能説明エリア (Commander Privileges)
                    VStack(alignment: .leading, spacing: 16) {
                        Text("COMMANDER PRIVILEGES")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 4)
                        
                        featureRow(
                            icon: "square.stack.3d.up.fill",
                            title: "LIMIT BREAK",
                            desc: "登録上限(10機)を解除。無制限に格納可能。",
                            color: .green
                        )
                        
                        featureRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "DATA LINK (CSV)",
                            desc: "大量のデータを一括インポート・バックアップ。",
                            color: .cyan
                        )
                        
                        featureRow(
                            icon: "photo.badge.plus.fill",
                            title: "MISSING LIST",
                            desc: "箱絵・完成写真の未取得リストを自動生成。",
                            color: .orange
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    Divider().background(Color.white.opacity(0.2))
                    
                    // 3. プラン選択エリア
                    if storeManager.products.isEmpty {
                        ProgressView("Loading Plans...")
                            .foregroundStyle(.white)
                            .padding()
                    } else {
                        if storeManager.isPremium && !storeManager.isCommander {
                            // ケースA: スタンダード購入済み -> アップグレードのみ表示
                            upgradeView
                        } else if !storeManager.isPremium {
                            // ケースB: 未購入 -> 2つのプランを表示
                            planSelectionView
                        } else {
                            // ケースC: 全て購入済み (Thank You)
                            thankYouView
                        }
                    }
                    
                    // 4. フッター (復元・閉じる)
                    VStack(spacing: 20) {
                        Button("購入を復元する (RESTORE)") {
                            LocalHaptics.select()
                            handleRestore()
                        }
                        .font(.caption)
                        .foregroundStyle(.gray)
                        .underline()
                        
                        Button {
                            LocalHaptics.tap()
                            close()
                        } label: {
                            Text("CLOSE")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.6))
                                .padding(10)
                        }
                    }
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 16)
            }
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.clear)
            )
            .scaleEffect(isAnimating ? 1.0 : 0.95)
            .opacity(isAnimating ? 1.0 : 0.0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Component Views
    
    private func featureRow(icon: String, title: String, desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
        }
    }
    
    // 2つのプラン選択 (未購入者向け)
    private var planSelectionView: some View {
        VStack(spacing: 16) {
            // 1. COMMANDER PACK (推奨)
            if let commander = storeManager.products.first(where: { $0.id == "com.pralog.commander" }) {
                Button {
                    LocalHaptics.select()
                    handlePurchase(commander)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("COMMANDER")
                                    .font(.headline)
                                    .fontWeight(.heavy)
                                Text("RECOMMENDED")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.yellow)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                            
                            Text("登録数無制限 + 全拡張機能")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Text("バラ売り(¥600)より ¥100 お得")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.yellow)
                                .padding(.top, 2)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text(commander.displayPrice)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.yellow)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.yellow.opacity(0.5), lineWidth: 2)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
            
            // 2. STANDARD PLAN
            if let standard = storeManager.products.first(where: { $0.id == "com.pralog.standard" }) {
                Button {
                    LocalHaptics.select()
                    handlePurchase(standard)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("STANDARD")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                            Text("登録数無制限のみ")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.6))
                            
                            Text("※後から拡張機能を追加すると +¥300 (計¥600) かかります")
                                .font(.caption2)
                                .foregroundStyle(Color(UIColor.systemOrange))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 2)
                        }
                        Spacer()
                        Text(standard.displayPrice)
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // アップグレード画面 (Standard購入済み向け)
    private var upgradeView: some View {
        VStack(spacing: 16) {
            Text("スタンダードプランをご利用中")
                .font(.caption)
                .foregroundStyle(.green)
            
            if let upgrade = storeManager.products.first(where: { $0.id == "com.pralog.upgrade" }) {
                Button {
                    LocalHaptics.select()
                    handlePurchase(upgrade)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("UPGRADE ADD-ON")
                                .font(.headline)
                                .fontWeight(.bold)
                            Text("拡張機能を追加 (CSV/画像管理)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        Spacer()
                        Text(upgrade.displayPrice)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.yellow)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient(colors: [.indigo.opacity(0.6), .purple.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // 購入完了画面
    private var thankYouView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
                .padding()
            
            Text("Full Access Unlocked")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("全ての機能をご利用いただけます。\nありがとうございます。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Logic
    private func handlePurchase(_ product: Product) {
        showSpinner = true
        Task {
            try? await storeManager.purchase(product)
            await MainActor.run {
                showSpinner = false
                if storeManager.isCommander {
                   // 必要なら閉じる処理
                }
            }
        }
    }
    
    private func handleRestore() {
        showSpinner = true
        Task {
            await storeManager.restore()
            await MainActor.run {
                showSpinner = false
            }
        }
    }
    
    private func close() {
        withAnimation {
            isPresented = false
        }
    }
}
