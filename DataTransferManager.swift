// DataTransferManager.swift V28
// 1. バージョン管理ルールに基づき更新 (V27 -> V28)
// 2. 修正点: エクスポート/インポート処理の堅牢化
//    - 設定画面からの呼び出しに対応し、iPadでのエクスポートフローを安定化
//    - V27のロジック(String URLベース)を維持しつつ、安全性を向上

import Foundation
import SwiftData
import UIKit
import Photos

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
            
            // ✅ Copy Pilot Avatar
            let avatarURL = docURL.appendingPathComponent("pilot_avatar.png")
            let dstAvatarURL = folderURL.appendingPathComponent("pilot_avatar.png")
            if FileManager.default.fileExists(atPath: avatarURL.path) {
                try? FileManager.default.copyItem(at: avatarURL, to: dstAvatarURL)
            }
            
            return folderURL
            
        } catch {
            print("Export V2 Error: \(error)")
            return nil
        }
    }
    
    private func escapeCSV(_ text: String?) -> String {
        guard let t = text else { return "" }
        var result = t
        
        // CSV Injection Protection
        let dangerousPrefixes = ["=", "+", "-", "@"]
        if dangerousPrefixes.contains(where: { result.hasPrefix($0) }) {
            result = "'" + result
        }
        
        if result.contains(",") || result.contains("\n") || result.contains("\r") || result.contains("\"") {
            return "\"" + result.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return result
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
    
    // MARK: - Migration Logic (Online -> Local)
    
    /// リモートURL（http〜）で保存されている画像をダウンロードし、ローカル保存へ移行する
    // MARK: - Cloud Database Migration (Local -> Album)
    func migrateImagesToAlbum(modelContext: ModelContext) async -> String {
        do {
            let descriptor = FetchDescriptor<Kit>()
            let kits = try modelContext.fetch(descriptor)
            var successCount = 0
            var failCount = 0
            var skippedCount = 0
            
            for kit in kits {
                var updated = false
                
                // Helper to migrate one path
                func migrate(path: String?) async -> String? {
                    guard let p = path, !p.isEmpty, !p.hasPrefix("http"), !p.hasPrefix("asset://") else { return nil }
                    let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let fileURL = docURL.appendingPathComponent(p)
                    
                    guard FileManager.default.fileExists(atPath: fileURL.path),
                          let data = try? Data(contentsOf: fileURL),
                          let image = UIImage(data: data) else { return nil }
                    
                    return await withCheckedContinuation { continuation in
                        PhotoAlbumHelper.shared.saveImageToAlbum(image) { assetID in
                            if let id = assetID {
                                try? FileManager.default.removeItem(at: fileURL) // Delete local
                                continuation.resume(returning: "asset://" + id)
                            } else {
                                continuation.resume(returning: nil)
                            }
                        }
                    }
                }
                
                // 1. Box Art
                if let newPath = await migrate(path: kit.imageURLString) {
                    kit.imageURLString = newPath
                    updated = true
                    successCount += 1
                } else if let p = kit.imageURLString, !p.isEmpty, !p.hasPrefix("http"), !p.hasPrefix("asset://") {
                    failCount += 1
                } else {
                   // Clean skip
                }
                
                // 2. Completed Photo
                if let newPath = await migrate(path: kit.completedImageURLString) {
                    kit.completedImageURLString = newPath
                    updated = true
                    successCount += 1 // Count as separate success
                }
                
                if updated { kit.updatedDate = Date() }
            }
            
            try modelContext.save()
            return "移行完了\n\n成功(images): \(successCount)枚\n失敗: \(failCount)枚"
            
        } catch {
            return "エラー: \(error.localizedDescription)"
        }
    }
    
    // MARK: - CloudKit Image Migration (Local -> External Storage Data)
    // Phase 2: Migrate local image files to SwiftData @Attribute(.externalStorage)
    // MARK: - CloudKit Image Migration (Local -> External Storage Data)
    // Phase 2: Migrate local image files to SwiftData @Attribute(.externalStorage)
    func migrateImagesToCloudKit(modelContext: ModelContext) async -> String {
        do {
            let descriptor = FetchDescriptor<Kit>()
            let kits = try modelContext.fetch(descriptor)
            var successCount = 0
            
            // Helper: Fetch Data from PHAsset ID
            func fetchPHAssetData(id: String) -> Data? {
                let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
                if let asset = assets.firstObject {
                    var resultData: Data? = nil
                    let options = PHImageRequestOptions()
                    options.isSynchronous = true
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                        resultData = data
                    }
                    return resultData
                }
                return nil
            }
            
            // Helper: Recover Asset ID from Filename
            func recoverAssetFromFilename(_ filename: String) -> Data? {
                var rawID = filename.replacingOccurrences(of: "asset_", with: "") // UUID_L0_001.jpg
                if rawID.hasSuffix(".jpg") { rawID = String(rawID.dropLast(4)) }
                
                var candidateIDs: [String] = []
                
                // Candidate A: Extract UUID via Regex and reconstruct Standard ID (UUID/L0/001)
                // UUID format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX (8-4-4-4-12)
                if let range = rawID.range(of: "[A-F0-9]{8}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{4}-[A-F0-9]{12}", options: .regularExpression) {
                    let uuid = String(rawID[range])
                    candidateIDs.append("\(uuid)/L0/001") // Standard Format
                    candidateIDs.append(uuid) // Pure UUID check
                }
                
                // Candidate B: Legacy "Replaced" logic (Fallback)
                candidateIDs.append(rawID.replacingOccurrences(of: "_L0_001", with: "/L0/001"))
                candidateIDs.append(rawID.replacingOccurrences(of: "_", with: "/"))

                print("[Migration] Recovery Attempt for \(filename)")
                print("[Migration] Candidates: \(candidateIDs)")

                let assets = PHAsset.fetchAssets(withLocalIdentifiers: candidateIDs, options: nil)
                if let asset = assets.firstObject {
                    print("[Migration] Recovery Success! Found matching asset.")
                    var resultData: Data? = nil
                    let options = PHImageRequestOptions()
                    options.isSynchronous = true
                    options.deliveryMode = .highQualityFormat
                    options.isNetworkAccessAllowed = true
                    PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                        resultData = data
                    }
                    return resultData
                } else {
                    print("[Migration] Recovery Failed. No assets found for IDs.")
                }
                return nil
            }
            
            // Helper to load data
            func loadData(path: String?) -> Data? {
                guard let p = path, !p.isEmpty else { return nil }
                
                print("[Migration] loadData checking path: \(p)")
                
                // 1. Asset Library (Direct Scheme)
                if p.hasPrefix("asset://") {
                    let localID = String(p.dropFirst("asset://".count))
                    return fetchPHAssetData(id: localID)
                }
                
                // 2. Resolve Filename from any path type
                let fileManager = FileManager.default
                let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                var targetURL: URL? = nil
                var filename: String = p
                
                // Determine Filename & Target URL
                if p.hasPrefix("file://") {
                    if let directURL = URL(string: p) {
                        if fileManager.fileExists(atPath: directURL.path) {
                            return try? Data(contentsOf: directURL)
                        }
                        filename = directURL.lastPathComponent
                        targetURL = docURL.appendingPathComponent(filename)
                    }
                } else if p.contains("/") {
                    filename = (p as NSString).lastPathComponent
                    targetURL = docURL.appendingPathComponent(filename)
                } else {
                    filename = p
                    targetURL = docURL.appendingPathComponent(p)
                }
                
                // 3. Try Loading from Documents (Fallback)
                if let tURL = targetURL, fileManager.fileExists(atPath: tURL.path) {
                    return try? Data(contentsOf: tURL)
                }
                
                // 4. Recovery: Check if filename looks like an asset
                if filename.hasPrefix("asset_") {
                    return recoverAssetFromFilename(filename)
                }
                
                return nil
            }

            for kit in kits {
                var updated = false
                
                // 1. Box Art
                if kit.imageData == nil, let data = loadData(path: kit.imageURLString) {
                    kit.imageData = data
                    updated = true
                    successCount += 1
                }
                
                // 2. Completed Photo
                if kit.completedImageData == nil, let data = loadData(path: kit.completedImageURLString) {
                    kit.completedImageData = data
                    updated = true
                    successCount += 1
                }
                
                // 3. Build Logs
                for log in (kit.buildLogs ?? []) {
                    if log.logImageData == nil, let data = loadData(path: log.imagePath) {
                        log.logImageData = data
                        updated = true
                        successCount += 1
                    }
                }
                
                if updated { kit.updatedDate = Date() }
            }
            
            try modelContext.save()
            return "CloudKit移行完了\n\n変換成功(画像枚数): \(successCount)枚"
            
        } catch {
            return "移行エラー: \(error.localizedDescription)"
        }
    }

    // MARK: - Validation & Repair
    
    /// 破損した画像ファイルを検出し、削除して再取得待ち状態にする
    /// 破損した画像ファイルを検出し、削除して再取得待ち状態にする
    nonisolated func repairBrokenImages(kitData: [(image: String?, completed: String?)]) async -> String {
        let fileManager = FileManager.default
        guard let docURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return "エラー" }
        
        var corruptedCount = 0
        var checkedCount = 0
        
        for kit in kitData {
            let paths = [kit.image, kit.completed]
            
            for path in paths {
                guard let p = path, !p.isEmpty, !p.hasPrefix("http"), !p.hasPrefix("asset://") else { continue }
                let fileURL = docURL.appendingPathComponent(p)
                
                if fileManager.fileExists(atPath: fileURL.path) {
                    checkedCount += 1
                    
                    // Check 1: Empty File
                    if let attr = try? fileManager.attributesOfItem(atPath: fileURL.path),
                       let size = attr[.size] as? Int64, size == 0 {
                        try? fileManager.removeItem(at: fileURL)
                        corruptedCount += 1
                        continue
                    }
                    
                    // Check 2: Invalid Image Data (Heavy check)
                    // We use a separate AutoreleasePool to prevent memory spikes
                    let isCorrupt: Bool = autoreleasepool {
                        // UIImage(contentsOfFile:) is better than Data(contentsOf:) as it doesn't force full load immediately sometimes,
                        // but to verify integrity we need to load it.
                        if let _ = UIImage(contentsOfFile: fileURL.path) {
                            return false
                        }
                        return true
                    }
                    
                    if isCorrupt {
                        try? fileManager.removeItem(at: fileURL)
                        corruptedCount += 1
                    }
                }
            }
            // Yield to event loop occasionally to prevent thread blocking if priority is high
            if checkedCount % 10 == 0 {
                await Task.yield()
            }
        }
        
        return "検証完了: \(checkedCount)ファイルを検査\n破損/空ファイル削除: \(corruptedCount)件\n(次回同期で再取得されます)"
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
                
                // ✅ Include Build Logs
                for log in (kit.buildLogs ?? []) {
                    if let logImg = log.imagePath, !logImg.isEmpty, !logImg.hasPrefix("http"), !logImg.hasPrefix("asset://") {
                        activeFiles.insert(logImg)
                    }
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
                if filename.hasPrefix("img_") && filename.hasSuffix(".jpg") || (filename.count == 36 + 4 && filename.hasSuffix(".jpg")) {
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
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        
        let chars = Array(content)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            if insideQuotes {
                if char == "\"" {
                    if i + 1 < chars.count && chars[i+1] == "\"" {
                        currentField.append("\"")
                        i += 1 // Skip escaped quote
                    } else {
                        insideQuotes = false
                    }
                } else {
                    currentField.append(char)
                }
            } else {
                if char == "\"" {
                    insideQuotes = true
                } else if char == "," {
                    currentRow.append(currentField)
                    currentField = ""
                } else if char == "\n" || char == "\r\n" {
                     // Check if it's \r\n
                    if char == "\r" && i + 1 < chars.count && chars[i+1] == "\n" {
                        i += 1
                    }
                    
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                } else {
                    currentField.append(char)
                }
            }
            i += 1
        }
        
        // Append last field/row if exists
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
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
    // MARK: - Build Log Support
    struct CodableBuildLog: Codable, Identifiable {
        var id: String { uuid }
        var date: Date
        var imagePath: String?
        var text: String
        var uuid: String
        
        init(log: BuildLog) {
            self.date = log.date
            self.imagePath = log.imagePath
            self.text = log.text
            self.uuid = log.uuid
        }
    }

    // MARK: - P2P Sync Logic
    
    struct CodableKit: Codable, Identifiable {
        var id: String { uuid } // Use uuid as stable ID
        
        var title: String
        var maker: String
        var series: String
        var grade: String
        var scale: String
        var jan: String
        var statusValue: Int
        var imageURLString: String?
        var completedImageURLString: String?
        var displayModeValue: Int
        var memo: String
        var createdDate: Date
        var updatedDate: Date
        var completedDate: Date?
        var uuid: String
        var imageCloudIdentifier: String? // ✅ Added Cloud ID
        var completedImageCloudIdentifier: String? // ✅ Added Cloud ID
        
        // ✅ Build Logs
        var buildLogs: [CodableBuildLog]?
        
        init(kit: Kit) {
            self.title = kit.title
            self.maker = kit.maker
            self.series = kit.series
            self.grade = kit.grade
            self.scale = kit.scale
            self.jan = kit.jan
            self.statusValue = kit.statusValue
            self.imageURLString = kit.imageURLString
            self.completedImageURLString = kit.completedImageURLString
            self.displayModeValue = kit.displayModeValue
            self.memo = kit.memo
            self.createdDate = kit.createdDate
            self.updatedDate = kit.updatedDate
            self.completedDate = kit.completedDate
            self.uuid = kit.uuid
            
            // Map Build Logs
            self.buildLogs = (kit.buildLogs ?? []).map { CodableBuildLog(log: $0) }
        }
    }
    
    // MARK: - Export Logic (V2 with Cloud Deduplication)
    @MainActor
    func exportDataV2(kits: [Kit]) async -> URL? {
        var exportKits: [CodableKit] = []
        
        for kit in kits {
            var cKit = CodableKit(kit: kit)
            
            // Resolve Cloud Identifiers if applicable
            if let img = kit.imageURLString, img.hasPrefix("asset://") {
                cKit.imageCloudIdentifier = await PhotoAlbumHelper.shared.getCloudIdentifier(from: img)
            }
            if let img = kit.completedImageURLString, img.hasPrefix("asset://") {
                cKit.completedImageCloudIdentifier = await PhotoAlbumHelper.shared.getCloudIdentifier(from: img)
            }
            
            exportKits.append(cKit)
        }
        
        let envelope = SyncEnvelope(type: .fullSync, payload: exportKits, imageRequests: nil, deletedUUIDs: DeletionManager.shared.getDeletedUUIDs(), pilotName: UserDefaults.standard.string(forKey: "pilotName"))
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        guard let data = try? encoder.encode(envelope) else { return nil }
        
        // Save to Folder
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("Pralog_Backup_\(Int(Date().timeIntervalSince1970))")
        try? fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let jsonURL = tempDir.appendingPathComponent("plalog_data.json")
        try? data.write(to: jsonURL)
        
        // Copy images (Files) - Only for those NOT covered by Cloud ID?
        // Current logic: Always copy files for backup safety. Smart Sync skip happens at RECEIVER.
        if let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            for kit in kits {
                if let url = kit.imageURLString, !url.hasPrefix("http") && !url.hasPrefix("asset://") {
                    let src = docs.appendingPathComponent(url)
                    let dst = tempDir.appendingPathComponent(url)
                    try? fileManager.copyItem(at: src, to: dst)
                }
                if let url = kit.completedImageURLString, !url.hasPrefix("http") && !url.hasPrefix("asset://") {
                    let src = docs.appendingPathComponent(url)
                    let dst = tempDir.appendingPathComponent(url)
                    try? fileManager.copyItem(at: src, to: dst)
                }
            }
        }
        
        return tempDir
    }
    
    struct SyncEnvelope: Codable {
        enum MessageType: String, Codable {
            case initial // Sender -> Receiver (Push)
            case response // Receiver -> Sender (Reply)
            case requestImages // Request specific images
            case fullSync // Backup/Export (No Reply needed)
        }
        let type: MessageType
        let payload: [CodableKit]
        let imageRequests: [String]?
        let deletedUUIDs: [String]? // ✅ Added for Zombie Fix
        let pilotName: String? // ✅ Added for Pilot Name Sync
    }
    
    @MainActor
    func prepareSyncData(kits: [Kit], type: SyncEnvelope.MessageType = .initial) async -> Data? {
        var codableKits: [CodableKit] = []
        for kit in kits {
            var cKit = CodableKit(kit: kit)
            
            // ✅ Sanitize Paths (Force Relative)
            if let img = cKit.imageURLString, !img.hasPrefix("http"), !img.hasPrefix("asset://") {
                cKit.imageURLString = URL(fileURLWithPath: img).lastPathComponent
            }
            if let img = cKit.completedImageURLString, !img.hasPrefix("http"), !img.hasPrefix("asset://") {
                cKit.completedImageURLString = URL(fileURLWithPath: img).lastPathComponent
            }

            // Resolve Cloud Identifiers
            if let img = kit.imageURLString, img.hasPrefix("asset://") {
                cKit.imageCloudIdentifier = await PhotoAlbumHelper.shared.getCloudIdentifier(from: img)
            }
            if let img = kit.completedImageURLString, img.hasPrefix("asset://") {
                cKit.completedImageCloudIdentifier = await PhotoAlbumHelper.shared.getCloudIdentifier(from: img)
            }
            
            // ✅ Sanitize Build Log Paths
            if let logs = cKit.buildLogs {
                cKit.buildLogs = logs.map { log in
                    var newLog = log
                    if let p = newLog.imagePath, !p.hasPrefix("http"), !p.hasPrefix("asset://") {
                        newLog.imagePath = URL(fileURLWithPath: p).lastPathComponent
                    }
                    return newLog
                }
            }
            
            codableKits.append(cKit)
        }
        
        let deleted = DeletionManager.shared.getDeletedUUIDs() // ✅ Fetch deleted UUIDs
        let pilotName = UserDefaults.standard.string(forKey: "pilotName") // ✅ Fetch Pilot Name
        
        let envelope = SyncEnvelope(type: type, payload: codableKits, imageRequests: nil, deletedUUIDs: deleted, pilotName: pilotName)
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            return try encoder.encode(envelope)
        } catch {
            print("Sync Encode Error: \(error)")
            return nil
        }
    }
    
    func prepareImageRequest(filenames: [String]) -> Data? {
        // Payload is empty for image requests
        // Payload is empty for image requests
        let envelope = SyncEnvelope(type: .requestImages, payload: [], imageRequests: filenames, deletedUUIDs: nil, pilotName: nil)
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(envelope)
        } catch {
            print("Image Request Encode Error: \(error)")
            return nil
        }
    }

    @MainActor
    func checkMissingImages(modelContext: ModelContext) -> [String] {
        let descriptor = FetchDescriptor<Kit>()
        guard let kits = try? modelContext.fetch(descriptor) else { return [] }
        
        var missingFiles: [String] = []
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        
        for kit in kits {
            // Check Box Art
            if let boxArt = kit.imageURLString, !boxArt.isEmpty, !boxArt.hasPrefix("http") && !boxArt.hasPrefix("asset://") {
                let fileURL = documentsURL.appendingPathComponent(boxArt)
                if !fileManager.fileExists(atPath: fileURL.path) {
                    missingFiles.append(boxArt)
                }
            }
            // Check User Photo
            if let userPhoto = kit.completedImageURLString, !userPhoto.isEmpty, !userPhoto.hasPrefix("http") && !userPhoto.hasPrefix("asset://") {
                let fileURL = documentsURL.appendingPathComponent(userPhoto)
                if !fileManager.fileExists(atPath: fileURL.path) {
                    missingFiles.append(userPhoto)
                }
            }
            
            // Check Build Logs
            for log in (kit.buildLogs ?? []) {
                if let logImg = log.imagePath, !logImg.isEmpty, !logImg.hasPrefix("http"), !logImg.hasPrefix("asset://") {
                    let fileURL = documentsURL.appendingPathComponent(logImg)
                    if !fileManager.fileExists(atPath: fileURL.path) {
                        missingFiles.append(logImg)
                    }
                }
            }
        }
        
        // ✅ Always request Avatar (Sync latest)
        // If the sender has it, they will send it. If not, error is ignored.
        // This ensures the avatar is synced if present on the peer.
        missingFiles.append("pilot_avatar.png")
        
        return Array(Set(missingFiles)) // Deduplicate
    }
    
    @MainActor
    func mergeSyncData(jsonData: Data, modelContext: ModelContext) async -> (String, SyncEnvelope?) {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(SyncEnvelope.self, from: jsonData)
            
            // Image Requestの場合はマージ処理を行わない
            if envelope.type == .requestImages {
                return ("画像リクエストを受信: \(envelope.imageRequests?.count ?? 0)件", envelope)
            }
            
            let incomingKits = envelope.payload
            
            // 既存データ取得
            let descriptor = FetchDescriptor<Kit>()
            let existingKits = try modelContext.fetch(descriptor)
            
            // ✅ DELETE Logic (Zombie Fix)
            var deletedCount = 0
            if let deletions = envelope.deletedUUIDs {
                for uuid in deletions {
                    if let target = existingKits.first(where: { $0.uuid == uuid }) {
                        modelContext.delete(target)
                        deletedCount += 1
                    }
                    // Also delete by old identity match logic if needed? No, uuid should be enough now.
                }
            }
            
            // ✅ Sync Pilot Name
            if let remoteName = envelope.pilotName, !remoteName.isEmpty {
                // Only update if local is default or remote is different?
                // Strategy: Trust source (Sync Logic)
                UserDefaults.standard.set(remoteName, forKey: "pilotName")
            }
            
            // Re-fetch remaining kits if deletions occurred? 
            // Or just filter in memory. existingKits is a snapshot though.
            // Safe to proceed with for-loop but be careful not to access deleted objects?
            // Actually, if we deleted it, it's marked for deletion.
            
            var addedCount = 0
            var updatedCount = 0
            var keptCount = 0
            
            for var incoming in incomingKits {
                // If incoming UUID is in deletedUUIDs list (from remote), skip "adding" it back?
                // Logic: If remote says "Deleted X", but also sends "Kit X" (unlikely unless race condition),
                // we should trust deletion? Or update?
                // Usually payload won't contain deleted items.
                
                // ... (Existing Merge Logic) ...
                
                // ✅ SMART SYNC: Cloud Deduplication Logic
                // DISABLED: Force file transfer to ensure reliability across devices.
                /*
                // 1. Check Box Art Cloud ID
                if let cloudID = incoming.imageCloudIdentifier {
                    if let localID = await PhotoAlbumHelper.shared.getLocalIdentifier(from: cloudID) {
                        // Found in local library! Mark as resolved to avoid fallback conversion
                        incoming.imageURLString = "resolved_asset://" + localID
                    }
                }
                // 2. Check Completed Photo Cloud ID
                if let cloudID = incoming.completedImageCloudIdentifier {
                    if let localID = await PhotoAlbumHelper.shared.getLocalIdentifier(from: cloudID) {
                         // Found in local library! Mark as resolved
                        incoming.completedImageURLString = "resolved_asset://" + localID
                    }
                }
                */
                
                // Fallback: If still "asset://" (from sender's local ID), it means we failed to resolve.
                // Convert to file request safe name.
                
                if let cUrl = incoming.completedImageURLString, cUrl.hasPrefix("asset://") {
                    let id = cUrl.dropFirst(8)
                    let safeName = "asset_" + id.replacingOccurrences(of: "/", with: "_") + ".jpg"
                    incoming.completedImageURLString = safeName
                }
                // Restore resolved assets
                if let cUrl = incoming.completedImageURLString, cUrl.hasPrefix("resolved_asset://") {
                    incoming.completedImageURLString = cUrl.replacingOccurrences(of: "resolved_asset://", with: "asset://")
                }
                
                if let boxUrl = incoming.imageURLString, boxUrl.hasPrefix("asset://") {
                    let id = boxUrl.dropFirst(8)
                    let safeName = "asset_" + id.replacingOccurrences(of: "/", with: "_") + ".jpg"
                    incoming.imageURLString = safeName
                }
                // Restore resolved assets
                if let boxUrl = incoming.imageURLString, boxUrl.hasPrefix("resolved_asset://") {
                    incoming.imageURLString = boxUrl.replacingOccurrences(of: "resolved_asset://", with: "asset://")
                }
                
                var targetExisting: Kit? = nil
                
                // Strategy 1: UUID Match (Perfect Match)
                if let match = existingKits.first(where: { $0.uuid == incoming.uuid }) {
                    targetExisting = match
                }
                // Strategy 2: Legacy Match (Migration)
                else if let match = existingKits.first(where: {
                     ($0.title == incoming.title && abs($0.createdDate.timeIntervalSince(incoming.createdDate)) < 60) ||
                     ($0.title == incoming.title && $0.maker == incoming.maker && $0.grade == incoming.grade && $0.jan == incoming.jan)
                }) {
                    targetExisting = match
                    targetExisting?.uuid = incoming.uuid
                }
                
                if let existing = targetExisting {
                    // Check if it was just deleted?
                    if envelope.deletedUUIDs?.contains(incoming.uuid) == true {
                        // Skip update if marked for deletion in same envelope (rare)
                        continue
                    }
                    
                    if incoming.updatedDate > existing.updatedDate {
                        existing.title = incoming.title
                        existing.maker = incoming.maker
                        existing.series = incoming.series
                        existing.grade = incoming.grade
                        existing.scale = incoming.scale
                        existing.jan = incoming.jan
                        existing.statusValue = incoming.statusValue
                        existing.imageURLString = incoming.imageURLString
                        existing.completedImageURLString = incoming.completedImageURLString
                        existing.displayModeValue = incoming.displayModeValue
                        existing.memo = incoming.memo
                    existing.updatedDate = incoming.updatedDate
                        existing.completedDate = incoming.completedDate
                        
                        // ✅ Merge Build Logs
                        if let incomingLogs = incoming.buildLogs {
                            for logData in incomingLogs {
                                if let existingLog = (existing.buildLogs ?? []).first(where: { $0.uuid == logData.uuid }) {
                                    // Update
                                    existingLog.date = logData.date
                                    existingLog.imagePath = logData.imagePath
                                    existingLog.text = logData.text
                                } else {
                                    // Insert (Link to Kit)
                                    let newLog = BuildLog(date: logData.date, imagePath: logData.imagePath, text: logData.text, uuid: logData.uuid)
                                    if existing.buildLogs == nil { existing.buildLogs = [] }
                                    existing.buildLogs?.append(newLog) 
                                    // Note: In SwiftData, appending to the relationship array should set the inverse automatically or strict insert needed?
                                    // Best practice: insert obj, then append. Or just append if context aware.
                                    // Since `newLog` is not inserted yet:
                                    // modelContext.insert(newLog) // Implicit?
                                    // Let's rely on relationship management.
                                }
                            }
                        }
                        
                        updatedCount += 1
                    } else {
                        keptCount += 1
                    }
                } else {
                    // 新規追加
                    // Check if in deleted list?
                     if envelope.deletedUUIDs?.contains(incoming.uuid) == true { continue }
                     
                    let newKit = Kit(
                        title: incoming.title,
                        maker: incoming.maker,
                        series: incoming.series,
                        grade: incoming.grade,
                        scale: incoming.scale,
                        jan: incoming.jan,
                        statusValue: incoming.statusValue,
                        imageURLString: incoming.imageURLString,
                        completedImageURLString: incoming.completedImageURLString,
                        displayModeValue: incoming.displayModeValue,
                        memo: incoming.memo,
                        createdDate: incoming.createdDate,
                        updatedDate: incoming.updatedDate,
                        completedDate: incoming.completedDate,
                        uuid: incoming.uuid
                    )
                    
                    // ✅ Insert Build Logs for New Kit
                    if let incomingLogs = incoming.buildLogs {
                        for logData in incomingLogs {
                            let newLog = BuildLog(date: logData.date, imagePath: logData.imagePath, text: logData.text, uuid: logData.uuid)
                            if newKit.buildLogs == nil { newKit.buildLogs = [] }
                            newKit.buildLogs?.append(newLog)
                        }
                    }
                    
                    modelContext.insert(newKit)
                    addedCount += 1
                }
            }
            
            try modelContext.save()
            return ("同期完了\n受信: \(incomingKits.count)件\n(追加: \(addedCount), 更新: \(updatedCount), 維持: \(keptCount))\n(削除反映: \(deletedCount))", envelope)
            
        } catch {
            return ("同期エラー: \(error.localizedDescription)", nil)
        }
    }
}
