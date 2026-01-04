// CSVDataManager.swift V5
// 1. バージョン管理ルールに基づき更新 (V4 -> V5)
// 2. 修正点: AddRegistrationFlowOverlayが必要とする findByJAN などの機能を復活・統合
//    - findByJAN メソッドを追加
//    - CSVKitData に jan プロパティを追加 (productCodeのエイリアス)
//    - 読み込みファイル名は "plalog_master" を維持
// 3. 全文差し替えルール適用

import Foundation
import SwiftData

struct CSVKitData: Identifiable {
    let id = UUID()
    let title: String
    let maker: String
    let scale: String
    let series: String
    let productCode: String // JANコードとして扱う
    let grade: String // グレード情報も保持するように拡張（CSVにない場合は推論）

    // ✅ 追加: AddRegistrationFlowOverlayとの互換性用エイリアス
    var jan: String { productCode }
}

class CSVDataManager {
    static let shared = CSVDataManager()
    private var loadedKits: [CSVKitData] = []
    
    // マスターデータの読み込み
    func loadMasterData() {
        guard loadedKits.isEmpty else { return }
        
        // ✅ ファイル名は plalog_master (スペル修正版) を使用
        guard let path = Bundle.main.path(forResource: "plalog_master", ofType: "csv") else {
            print("CSV file not found.")
            return
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let rows = content.components(separatedBy: "\n")
            
            for row in rows {
                let columns = row.components(separatedBy: ",")
                // 想定カラム: title, maker, scale, series, productCode
                if columns.count >= 5 {
                    let title = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let maker = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let scale = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    let series = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    let code = columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Gradeの簡易推定（タイトルから）
                    var grade = ""
                    let upperTitle = title.uppercased()
                    if upperTitle.contains("HG") { grade = "HG" }
                    else if upperTitle.contains("MG") { grade = "MG" }
                    else if upperTitle.contains("RG") { grade = "RG" }
                    else if upperTitle.contains("PG") { grade = "PG" }
                    else if upperTitle.contains("EG") { grade = "EG" }
                    
                    if !title.isEmpty {
                        let data = CSVKitData(title: title, maker: maker, scale: scale, series: series, productCode: code, grade: grade)
                        loadedKits.append(data)
                    }
                }
            }
            print("Loaded \(loadedKits.count) items from CSV.")
            
        } catch {
            print("Error parsing CSV: \(error)")
        }
    }
    
    // 検索メソッド (キーワード)
    func search(query: String) -> [CSVKitData] {
        if loadedKits.isEmpty { loadMasterData() }
        
        let lowerQuery = query.lowercased()
        return loadedKits.filter { kit in
            kit.title.lowercased().contains(lowerQuery) ||
            kit.productCode.lowercased().contains(lowerQuery) ||
            kit.series.lowercased().contains(lowerQuery)
        }
    }
    
    // ✅ 追加: JANコード完全一致検索 (AddRegistrationFlowOverlay用)
    func findByJAN(_ code: String) -> CSVKitData? {
        if loadedKits.isEmpty { loadMasterData() }
        return loadedKits.first { $0.productCode == code }
    }
}
