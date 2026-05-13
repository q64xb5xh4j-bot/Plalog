// StoreKitManager.swift V7
// 1. バージョン管理ルールに基づき更新 (V6 -> V7)
// 2. 変更点: 3段階の課金プラン（Standard, Commander, Upgrade）に対応
//    - 商品ID定義の追加
//    - isPremium (基本機能) と isCommander (拡張機能) の2つの権限状態を管理
//    - 購入処理を Product を受け取る形に変更
// 3. 全文差し替えルール適用

import Foundation
import StoreKit
import Combine

// MARK: - Helper Function (Isolation Safe)
fileprivate func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
    switch result {
    case .unverified:
        throw StoreError.failedVerification
    case .verified(let safe):
        return safe
    }
}

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()
    
    // ✅ 権限ステータス (UI更新用)
    // isPremium: 登録数無制限 (Standard または Commander で true)
    // isCommander: 拡張機能 (Commander または Upgrade で true)
    @Published var isPremium: Bool = false
    @Published var isCommander: Bool = false
    
    // ✅ 商品リスト (UI表示用)
    @Published var products: [Product] = []
    
    // Base Products
    private let productID_Standard = "com.pralog.standard"
    private let productID_Commander = "com.pralog.commander"
    private let productID_Upgrade = "com.pralog.upgrade"
    
    // Database Products
    private let productID_DB_Tamiya = "com.hiro.pralog.db.tamiya"
    private let productID_DB_Aoshima = "com.hiro.pralog.db.aoshima"
    private let productID_DB_Hasegawa = "com.hiro.pralog.db.hasegawa"
    private let productID_DB_Kotobukiya = "com.hiro.pralog.db.kotobukiya"
    private let productID_DB_Fujimi = "com.hiro.pralog.db.fujimi"
    private let productID_DB_FineMolds = "com.hiro.pralog.db.finemolds"
    private let productID_DB_MaxFactory = "com.hiro.pralog.db.maxfactory"
    private let productID_DB_Volks = "com.hiro.pralog.db.volks"
    
    // 商品IDセット (DBは無料化につき削除)
    private var productIDs: Set<String> {
        [
            productID_Standard, productID_Commander, productID_Upgrade
        ]
    }
    
    // ✅ 購入済みデータベース管理 (CatalogGenreとのマッピング用)
    @Published var purchasedDatabases: Set<String> = []
    
    private var updateListenerTask: Task<Void, Never>? = nil
    
    private init() {
        updateListenerTask = listenForTransactions()
        Task {
            await requestProducts()
            await updateCustomerProductStatus()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - Fetch Products
    
    func requestProducts() async {
        do {
            let fetchedProducts = try await Product.products(for: productIDs)
            // 価格順などでソート
            self.products = fetchedProducts.sorted { $0.price < $1.price }
        } catch {
            print("Failed to fetch products: \(error)")
        }
    }
    
    // MARK: - Check Status
    
    func isPurchased(_ productID: String) -> Bool {
        // ✅ GOD MODE: All Access
        if UserDefaults.standard.bool(forKey: "isGodModeEnabled") { return true }
        
        // ✅ データベースは全無料化
        if productID.contains(".db.") { return true }
        if productID == "gunpla" { return true }
        
        return purchasedDatabases.contains(productID)
    }
    
    // MARK: - Purchase Actions
    
    // 特定の商品を購入する
    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updateCustomerProductStatus()
            await transaction.finish()
            
        case .userCancelled, .pending:
            break
            
        @unknown default:
            break
        }
    }
    
    func restore() async {
        try? await AppStore.sync()
        await updateCustomerProductStatus()
    }
    
    // MARK: - Internal Logic
    
    // 購入履歴を確認して権限フラグを更新
    func updateCustomerProductStatus() async {
        var newIsPremium = false
        var newIsCommander = false
        var newPurchasedDBs: Set<String> = []
        
        // 購入済み権利(Entitlements)を走査
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                switch transaction.productID {
                case productID_Standard:
                    newIsPremium = true
                case productID_Commander:
                    newIsPremium = true
                    newIsCommander = true
                case productID_Upgrade:
                    newIsCommander = true
                    
                case productID_DB_Tamiya, productID_DB_Aoshima, productID_DB_Hasegawa,
                     productID_DB_Kotobukiya, productID_DB_Fujimi, productID_DB_FineMolds,
                     productID_DB_MaxFactory, productID_DB_Volks:
                    newPurchasedDBs.insert(transaction.productID)
                    
                default:
                    // 旧ID互換性などを考慮
                    if transaction.productID == "jp.plalog.Plalog.premium_unlock" {
                        newIsPremium = true
                    }
                    break
                }
            }
        }
        
        // アップグレードだけ買っている場合でも、拡張機能があればPremiumもTrueとみなすのが安全
        if newIsCommander { newIsPremium = true }
        
        self.isPremium = newIsPremium
        self.isCommander = newIsCommander
        self.purchasedDatabases = newPurchasedDBs
    }
    
    private func listenForTransactions() -> Task<Void, Never> {
        return Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)
                    await MainActor.run {
                        Task { await StoreKitManager.shared.updateCustomerProductStatus() }
                    }
                    await transaction.finish()
                } catch {
                    print("Transaction verification failed.")
                }
            }
        }
    }
}

enum StoreError: Error {
    case productNotFound
    case failedVerification
}
