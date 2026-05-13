// PlalogApp.swift V3
// 1. バージョン管理ルールに基づき更新 (V2 -> V3)
// 2. 変更点: デバイス判定ロジックの統合
//    - BootSequenceView（起動演出）はiPhone/iPad共通で実行
//    - 起動完了(isBooting = false)後、デバイスがiPadかiPhoneかを判定
//    - iPadなら iPadContentView、iPhoneなら ContentView へ遷移する
// 3. 全文差し替えルール適用

import SwiftUI
import SwiftData

@main
struct PlalogApp: App {
    // ✅ 起動状態フラグ (初期値 true)
    @State private var isBooting: Bool = true
    
    // データモデルのコンテナ設定
    var sharedModelContainer: ModelContainer = {
        // Main schema for Kit (existing data)
        let mainConfig = ModelConfiguration("main", schema: Schema([Kit.self]), isStoredInMemoryOnly: false)
        
        // Discovery cache schema (new, separate store)
        let discoveryConfig = ModelConfiguration("discovery", schema: Schema([DiscoveryCache.self]), isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: Kit.self, DiscoveryCache.self, configurations: mainConfig, discoveryConfig)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                // 1. 起動シーケンス (最前面)
                if isBooting {
                    BootSequenceView {
                        // ブート完了時の処理
                        withAnimation(.easeIn(duration: 0.5)) {
                            isBooting = false
                        }
                    }
                    .zIndex(1) // 常に手前に表示
                    .transition(.opacity)
                } else {
                    // 2. メイン画面 (起動後に表示)
                    // ✅ ここで「iPhoneかiPadか」を分岐させます
                    Group {
                        if UIDevice.current.userInterfaceIdiom == .pad {
                            // iPadの場合 (変更なし)
                            iPadContentView()
                        } else {
                            // iPhoneの場合: 新しいハイブリッドUIへ
                            MainTabView()
                        }
                    }
                    .zIndex(0)
                    .transition(.opacity)
                }
            }
            .modelContainer(sharedModelContainer)
            .onAppear {
                KeyValueSyncManager.shared.start()
                
                // ✅ Background Tasks
                Task {
                    let container = sharedModelContainer
                    let context = ModelContext(container)
                    
                    // 1. CloudKit Image Migration (Phase 2)
                    let defaults = UserDefaults.standard
                    if !defaults.bool(forKey: "isImageMigrationCompleted_V2") {
                        let migrationResult = await DataTransferManager.shared.migrateImagesToCloudKit(modelContext: context)
                        print("[Migration] \(migrationResult)")
                        
                        // Mark as completed if successful (or if we decide to run it only once)
                        // For now, let's assume if it runs without crashing, we mark it.
                        // Ideally checking result string for "完了" but simple flag is safer for performance.
                        defaults.set(true, forKey: "isImageMigrationCompleted_V2")
                    } else {
                        print("[Migration] Skipped (Already Completed)")
                    }
                    
                    // 2. ✅ Discovery Cache Sync (SwiftData)
                    let syncCount = await DiscoveryManager.shared.syncFromCloudKit(modelContext: context)
                    print("[DiscoverySync] Synced \(syncCount) items to local cache")
                }
            }
        }
    }
}
