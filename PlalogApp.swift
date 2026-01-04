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
    
    // データモデルのコンテナ設定 (V2から変更なし)
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Kit.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
                            // iPadの場合: 今日作った新しい基地へ
                            iPadContentView()
                        } else {
                            // iPhoneの場合: 今までの画面へ
                            ContentView()
                        }
                    }
                    .zIndex(0)
                    .transition(.opacity)
                }
            }
            .modelContainer(sharedModelContainer)
        }
    }
}
