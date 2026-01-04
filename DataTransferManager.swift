// DataTransferManager.swift V28
// 1. バージョン管理ルールに基づき更新 (V27 -> V28)
// 2. 修正点: エクスポート/インポート処理の堅牢化
//    - 設定画面からの呼び出しに対応し、iPadでのエクスポートフローを安定化
//    - V27のロジック(String URLベース)を維持しつつ、安全性を向上

import Foundation
import SwiftData
import UIKit

@MainActor
class DataTransferManager {
    static let shared = DataTransferManager()
    
    private let csvHeader = "uuid,jan,name,maker,series,grade,scale,status,memo,updatedAt,sheet_updated_at"
    private let csvHeaderV2 = "uuid,jan,name,maker,series,grade,scale,status,memo,image_url,completed_image_url,updatedAt"
    
    private let exportDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
    
    private init() {}
    
    // MARK: - Export Logic (Flat Folder Strategy)
    
    func exportDataV2(kits: [Kit]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let folderName = "Plalog_Backup_Flat_\(Int(Date().timeIntervalSince1970))"
        let folderURL = tempDir.appendingPathComponent(folderName)
        
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
            
            // 1. Create CSV
            var csvString = csvHeaderV2 + "\n"
            for kit in kits {
                let row = [
                    kit.persistentModelID.id.hashValue.description, // ID placeholder
                    escapeCSV(kit.jan),
                    escapeCSV(kit.title),
                    escapeCSV(kit.maker),
                    escapeCSV(kit.series),
                    escapeCSV(kit.grade),
                    escapeCSV(kit.scale),
                    String(kit.statusValue),
                    escapeCSV(kit.memo),
                    escapeCSV(kit.imageURLString),
                    escapeCSV(kit.completedImageURLString),
                    exportDateFormatter.string(from: kit.updatedDate)
                ].joined(separator: ",")
                csvString += row + "\n"
            }
            
            let csvURL = folderURL.appendingPathComponent("plalog_data_v2.csv")
            try csvString.write(to: csvURL, atomically: true, encoding: .utf8)
            
            // 2. Copy Images (Same Directory)
            let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            for kit in kits {
                if let path = kit.imageURLString, !path.isEmpty, !path.hasPrefix("http"), !path.hasPrefix("asset://") {
                    let src = docURL.appendingPathComponent(path)
                    let dst = folderURL.appendingPathComponent(path)
                    if FileManager.default.fileExists(atPath: src.path) {
                        try? FileManager.default.copyItem(at: src, to: dst)
                    }
                }
                if let path = kit.completedImageURLString, !path.isEmpty, !path.hasPrefix("http"), !path.hasPrefix("asset://") {
                    let src = docURL.appendingPathComponent(path)
                    let dst = folderURL.appendingPathComponent(path)
                    if FileManager.default.fileExists(atPath: src.path) {
                        try? FileManager.default.copyItem(at: src, to: dst)
                    }
                }
            }
            
            return folderURL
            
        } catch {
            print("Export V2 Error: \(error)")
            return nil
        }
    }
    
    private func escapeCSV(_ text: String?) -> String {
        guard let t = text else { return "" }
        if t.contains(",") || t.contains("\n") || t.contains("\r") || t.contains("\"") {
            return "\"" + t.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return t
    }
    
    // MARK: - Import Logic (Batch)
    
    /// SettingsOverlayから呼ばれる統合インポートメソッド (V2)
    /// - URLがフォルダなら展開し、ファイルならそのまま処理リストへ追加してバッチ処理へ
    func importDataV2(url: URL, modelContext: ModelContext) -> (Int, String) {
        var targetUrls: [URL] = []
        
        // フォルダかどうか判定
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
            // フォルダの場合: 直下のファイルを取得
            do {
                // 隠しファイル以外を取得
                let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
                targetUrls = files
            } catch {
                return (0, "フォルダ読み込みエラー: \(error.localizedDescription)")
            }
        } else {
            // ファイルの場合: 単一ファイルとして処理
            targetUrls = [url]
        }
        
        // 既存のバッチロジックへ委譲
        return importDataBatch(urls: targetUrls, modelContext: modelContext)
    }
    
    func importDataBatch(urls: [URL], modelContext: ModelContext) -> (Int, String) {
        var importedCount = 0
        var log = ""
        
        // 1. Identify CSV and Images
        let csvFiles = urls.filter { $0.pathExtension.lowercased() == "csv" }
        let imageFiles = urls.filter { ["jpg", "jpeg", "png"].contains($0.pathExtension.lowercased()) }
        
        // 2. Copy Images to App Document Directory
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var copiedImagesCount = 0
        
        for imgURL in imageFiles {
            // Security Scoped Access
            let startAccess = imgURL.startAccessingSecurityScopedResource()
            defer { if startAccess { imgURL.stopAccessingSecurityScopedResource() } }
            
            let destURL = docURL.appendingPathComponent(imgURL.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: imgURL, to: destURL)
                copiedImagesCount += 1
            } catch {
                print("Image Copy Error: \(error)")
            }
        }
        log += "画像取り込み: \(copiedImagesCount)件\n"
        
        // 3. Process CSV
        for csvURL in csvFiles {
            let startAccess = csvURL.startAccessingSecurityScopedResource()
            defer { if startAccess { csvURL.stopAccessingSecurityScopedResource() } }
            
            do {
                let content = try String(contentsOf: csvURL, encoding: .utf8)
                let rows = parseCSV(content)
                // ヘッダー行をスキップ (簡易判定)
                let dataRows = rows.filter { $0.count > 3 && $0[0] != "uuid" }
                
                for row in dataRows {
                    let title = safeGet(row, 2)
                    let maker = safeGet(row, 3)
                    let series = safeGet(row, 4)
                    let grade = safeGet(row, 5)
                    let scale = safeGet(row, 6)
                    let status = convertStatusToInt(safeGet(row, 7))
                    let memo = safeGet(row, 8)
                    
                    // V2なら画像情報がある
                    var img: String? = nil
                    var compImg: String? = nil
                    if row.count >= 12 {
                        img = safeGet(row, 9)
                        compImg = safeGet(row, 10)
                    }
                    
                    // 新規登録
                    let newKit = Kit(title: title, maker: maker, series: series, grade: grade, scale: scale, jan: safeGet(row, 1), statusValue: status, imageURLString: img, completedImageURLString: compImg, memo: memo)
                    modelContext.insert(newKit)
                    importedCount += 1
                }
            } catch {
                log += "CSVエラー: \(csvURL.lastPathComponent)\n"
            }
        }
        
        log += "データ登録: \(importedCount)件"
        return (importedCount, log)
    }
    
    // MARK: - Storage Cleanup Logic (V26 New Feature)
    
    /// 使われていない画像ファイルを検出し、削除する
    func performStorageCleanup(modelContext: ModelContext) -> String {
        do {
            // 1. 全キットを取得し、使用中のファイル名リストを作成
            let descriptor = FetchDescriptor<Kit>()
            let kits = try modelContext.fetch(descriptor)
            
            var activeFiles = Set<String>()
            for kit in kits {
                if let url = kit.imageURLString, !url.isEmpty, !url.hasPrefix("http"), !url.hasPrefix("asset://") {
                    activeFiles.insert(url)
                }
                if let cUrl = kit.completedImageURLString, !cUrl.isEmpty, !cUrl.hasPrefix("http"), !cUrl.hasPrefix("asset://") {
                    activeFiles.insert(cUrl)
                }
            }
            
            // 2. ドキュメントフォルダ内の全ファイルをスキャン
            let fileManager = FileManager.default
            let docUrl = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let allFiles = try fileManager.contentsOfDirectory(at: docUrl, includingPropertiesForKeys: [.fileSizeKey])
            
            var deletedCount = 0
            var recoveredSize: Int64 = 0
            
            // 3. 使われていないファイルを削除
            for fileUrl in allFiles {
                let filename = fileUrl.lastPathComponent
                
                // アプリが生成した画像ファイル("img_xxx.jpg")のみを対象にする (安全性のため)
                if filename.hasPrefix("img_") && filename.hasSuffix(".jpg") {
                    if !activeFiles.contains(filename) {
                        // 使用されていない -> 削除対象
                        if let resources = try? fileUrl.resourceValues(forKeys: [.fileSizeKey]),
                           let fileSize = resources.fileSize {
                            recoveredSize += Int64(fileSize)
                        }
                        
                        try fileManager.removeItem(at: fileUrl)
                        deletedCount += 1
                    }
                }
            }
            
            let mb = Double(recoveredSize) / 1024.0 / 1024.0
            return String(format: "メンテナンス完了\n\n削除されたゴミファイル: %d個\n解放された容量: %.2f MB", deletedCount, mb)
            
        } catch {
            return "エラーが発生しました: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helpers
    
    // Emergency Reset
    func clearAllData(modelContext: ModelContext) {
        try? modelContext.delete(model: Kit.self)
        
        // 画像も全消去
        let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let files = try? FileManager.default.contentsOfDirectory(at: docURL, includingPropertiesForKeys: nil) {
            for file in files {
                if file.lastPathComponent.hasPrefix("img_") {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }
    
    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            if line.isEmpty { continue }
            // 簡易CSVパース (カンマ区切り、ダブルクォート対応)
            var currentRow: [String] = []
            var currentField = ""
            var insideQuotes = false
            
            var i = 0
            let chars = Array(line)
            while i < chars.count {
                let char = chars[i]
                if char == "\"" {
                    if i + 1 < chars.count && chars[i+1] == "\"" {
                        currentField.append("\""); i += 1
                    } else { insideQuotes.toggle() }
                } else if char == "," && !insideQuotes {
                    currentRow.append(currentField); currentField = ""
                } else { currentField.append(char) }
                i += 1
            }
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) { rows.append(currentRow) }
        }
        return rows
    }
    
    private func safeGet(_ array: [String], _ index: Int) -> String {
        guard index < array.count else { return "" }
        return array[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func convertStatusToInt(_ status: String) -> Int {
        let clean = status.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.contains("完成") || clean.contains("complete") || clean == "4" { return 4 }
        if clean.contains("制作") || clean.contains("inprogress") || clean == "3" { return 3 }
        if clean.contains("積み") || clean.contains("stock") || clean == "2" { return 2 }
        if clean.contains("予約") || clean.contains("reservation") || clean == "1" { return 1 }
        return Int(clean) ?? 0
    }
}
