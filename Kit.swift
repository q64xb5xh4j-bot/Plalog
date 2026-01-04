// Kit.swift V2
// 1. ファイル冒頭のバージョン管理ルールに基づき更新 (ユーザー提示コード -> V2)
// 2. 変更点: 画像表示モードを保持する `displayModeValue` を追加
// 3. 全文差し替えルール適用: 既存ロジック・構造は完全維持

import Foundation
import SwiftData

// MARK: - Data Model (Production)
// 仕様書 に基づくデータ構造 + 完成写真対応

@Model
final class Kit {
    var title: String       // 商品名
    var maker: String       // メーカー
    var series: String      // シリーズ
    var grade: String       // グレード (HG/MG等)
    var scale: String       // スケール
    var jan: String         // JANコード
    
    // ステータス: 仕様書
    // 0: Wish, 1: Reservation, 2: Stock, 3: InProgress, 4: Complete
    var statusValue: Int
    
    var imageURLString: String?          // 箱絵・メイン画像
    var completedImageURLString: String? // ✅ 追加: 完成写真（箱絵とは別保存）
    
    // ✅ 追加: 画像表示設定 (0: BoxArt, 1: MyPhoto)
    var displayModeValue: Int = 0
    
    var memo: String            // メモ
    
    var createdDate: Date       // 作成日
    var updatedDate: Date       // 更新日
    var completedDate: Date?    // 完了日
    
    init(
        title: String,
        maker: String = "",
        series: String = "",
        grade: String = "",
        scale: String = "",
        jan: String = "",
        statusValue: Int = 0,
        imageURLString: String? = nil,
        completedImageURLString: String? = nil, // ✅ initにも追加
        displayModeValue: Int = 0,              // ✅ initにも追加 (デフォルト0)
        memo: String = "",
        createdDate: Date = Date(),
        updatedDate: Date = Date(),
        completedDate: Date? = nil
    ) {
        self.title = title
        self.maker = maker
        self.series = series
        self.grade = grade
        self.scale = scale
        self.jan = jan
        self.statusValue = statusValue
        self.imageURLString = imageURLString
        self.completedImageURLString = completedImageURLString
        self.displayModeValue = displayModeValue
        self.memo = memo
        self.createdDate = createdDate
        self.updatedDate = updatedDate
        self.completedDate = completedDate
    }
}
