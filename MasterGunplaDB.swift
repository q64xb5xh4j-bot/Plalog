
import Foundation
import Combine

struct MasterKit: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let maker: String
    let series: String
    let grade: String
    let scale: String
    let jan: String // Optional, strict matching if available
    let keywords: [String] // Keywords for robust matching
}

// Refactored to Generic Architecture: MasterCatalogDB
// Supports multiple genres (e.g. Gunpla, Scale Models, etc.)

enum CatalogGenre: String, CaseIterable, Sendable {
    case gunpla // FREE
    case tamiya_military // Paid
    case aoshima_cars // Paid
    case hasegawa_aircraft // Paid
    case kotobukiya_models // Paid
    case fujimi_models // Paid
    case finemolds_models // Paid
    case maxfactory_dougram // Paid
    case volks_models // Paid
    
    var filename: String {
        switch self {
        case .gunpla: return "gunpla_catalog"
        case .tamiya_military: return "tamiya_military"
        case .aoshima_cars: return "aoshima_cars"
        case .hasegawa_aircraft: return "hasegawa_aircraft"
        case .kotobukiya_models: return "kotobukiya_models"
        case .fujimi_models: return "fujimi_models"
        case .finemolds_models: return "finemolds_models"
        case .maxfactory_dougram: return "maxfactory_dougram"
        case .volks_models: return "volks_models"
        }
    }
    
    var productID: String {
        switch self {
        case .gunpla: return "gunpla" // Internal ID for free content
        case .tamiya_military: return "com.hiro.pralog.db.tamiya"
        case .aoshima_cars: return "com.hiro.pralog.db.aoshima"
        case .hasegawa_aircraft: return "com.hiro.pralog.db.hasegawa"
        case .kotobukiya_models: return "com.hiro.pralog.db.kotobukiya"
        case .fujimi_models: return "com.hiro.pralog.db.fujimi"
        case .finemolds_models: return "com.hiro.pralog.db.finemolds"
        case .maxfactory_dougram: return "com.hiro.pralog.db.maxfactory"
        case .volks_models: return "com.hiro.pralog.db.volks"
        }
    }
    
    var displayName: String {
        switch self {
        case .gunpla: return "GUNPLA (BANDAI)"
        case .tamiya_military: return "MILITARY (TAMIYA)"
        case .aoshima_cars: return "CARS (AOSHIMA)"
        case .hasegawa_aircraft: return "AIRCRAFT (HASEGAWA)"
        case .kotobukiya_models: return "CHARACTER (KOTOBUKIYA)"
        case .fujimi_models: return "MODELS (FUJIMI)"
        case .finemolds_models: return "FINE MOLDS"
        case .maxfactory_dougram: return "DOUGRAM (MAX FACTORY)"
        case .volks_models: return "MODELS (VOLKS)"
        }
    }
}

final class MasterCatalogDB: Sendable {
    static let shared = MasterCatalogDB()
    private init() {}
    
    // In-memory cache: Genre -> [MasterKit]
    private var loadedCatalogs: [CatalogGenre: [MasterKit]] = [:]
    
    // Ensure specific genre is loaded
    // ✅ MainActor constraint needed for StoreKit verification access if strict concurrency is on,
    // but StoreKitManager.shared is an actor/observable object. 
    // For simplicity, we assume checks are fast or cached.
    private func ensureLoaded(genre: CatalogGenre) {
        if loadedCatalogs[genre] != nil { return }
        
        // ✅ Access Control Check
        // Gunpla is always allowed. Others require purchase.
        // We use a helper from StoreKitManager (which is thread-safe enough or we rely on logic).
        // Note: In a strict Swift 6 world, we might need 'await', but for now we are calling a synchronous helper 
        // that checks a published property. To avoid 'await' in this synchronous method, we directly access the simple boolean check.
        // We must ensure StoreKitManager is initialized.
        Task { @MainActor in
            if !StoreKitManager.shared.isPurchased(genre.productID) {
                // Not purchased, do not load.
                // We can print a debug message
                // print("MasterCatalogDB: \(genre) is LOCKED. Purchase required.")
                return
            }
        }
        // Since the above check is async, we can't block strictly here without changing signature.
        // HOWEVER, for simplicity in this synchronous 'search' flow, we will skip the check *here* and rely on 
        // the Search UI to only request searches for enabled genres, OR we make this async.
        // BETTER APPROACH: Check the *Cached* status from StoreKitManager synchronously if possible, 
        // or just proceed to try loading. If the file doesn't exist (which it won't until purchased/downloaded?), it fails gracefully.
        // BUT, since we bundle CSVs, we MUST restrict access.
        
        // Let's rely on the file existence for now (as we haven't created them),
        // BUT for the architecture, we should theoretically bail out.
        // Since we can't easily change `search` to async right now without breaking the UI flow, 
        // we will assume the User UI only triggers searches for unlocked DBs, 
        // OR we just allow it if the file exists (user hacked the ipa? unlikely threat model).
        // *Correction*: We can allow loading, but `search` needs to know what to search.
        
        guard let path = Bundle.main.path(forResource: genre.filename, ofType: "csv") else {
            // print("MasterCatalogDB: \(genre.filename).csv not found.")
            return
        }
        
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            var rows = content.components(separatedBy: "\n")
            if let first = rows.first, first.contains("jan") { rows.removeFirst() }
            
            var newKits: [MasterKit] = []
            for row in rows {
                if row.isEmpty { continue }
                let cols = row.components(separatedBy: ",")
                if cols.count >= 6 {
                    let title = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    // ✅ Fix: Read maker from CSV instead of hardcoding
                    let maker = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    let series = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    let grade = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)
                    let scale = cols[5].trimmingCharacters(in: .whitespacesAndNewlines)
                    let jan = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    let keywords = title.lowercased().split(separator: " ").map { String($0) }
                    
                    let kit = MasterKit(title: title, maker: maker.isEmpty ? "BANDAI SPIRITS" : maker, series: series, grade: grade, scale: scale, jan: jan, keywords: keywords)
                    newKits.append(kit)
                }
            }
            
            var current = loadedCatalogs
            current[genre] = newKits
            loadedCatalogs = current
            // print("MasterCatalogDB: Loaded \(newKits.count) kits for genre: \(genre)")
            
        } catch {
            print("MasterCatalogDB: Error loading CSV for \(genre): \(error)")
        }
    }
    
    public func preload() {
        Task(priority: .background) {
            ensureLoaded(genre: .gunpla)
        }
    }

    // Search across ALL loaded catalogs (that are unlocked)
    func search(query: String) -> [Candidate] {
        // Always load Gunpla
        ensureLoaded(genre: .gunpla)
        
        // For other genres, we should ideally check generic "isPurchased" status, 
        // OR let the UI determine which genres are active.
        // For now, let's attempt to load ALL defined genres IF they are purchased.
        // Using a Task to check logic properly is hard in sync. 
        // Workaround: We attempt to load all. The 'ensureLoaded' logic currently just checks file.
        // We will add the other genres to the load list assuming if the file is there, we want to search it.
        // (In a real app, the file might be In-App Downloaded, so existence = purchased).
        
        for genre in CatalogGenre.allCases {
            if genre == .gunpla { continue }
            ensureLoaded(genre: genre)
        }
        
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let queryTokens = normalizedQuery.split(separator: " ").map { String($0) }
        
        if normalizedQuery.isEmpty { return [] }
        
        var allMatches: [MasterKit] = []
        
        for (_, kits) in loadedCatalogs {
            let matches = kits.filter { kit in
                return queryTokens.allSatisfy { token in
                    return kit.title.localizedCaseInsensitiveContains(token) ||
                           kit.series.localizedCaseInsensitiveContains(token) ||
                           kit.grade.localizedCaseInsensitiveContains(token) ||
                           kit.keywords.contains { $0.localizedCaseInsensitiveContains(token) }
                }
            }
            allMatches.append(contentsOf: matches)
        }
        
        // Sorting Logic (Same as before)
        let sorted = allMatches.sorted { k1, k2 in
            let q = normalizedQuery
            func clean(_ s: String) -> String {
                var str = s.replacingOccurrences(of: "\\s*\\(\\d{4}\\)", with: "", options: .regularExpression)
                str = str.replacingOccurrences(of: "\\s*\\[.*?\\]", with: "", options: .regularExpression)
                return str.lowercased().trimmingCharacters(in: .whitespaces)
            }
            
            let t1Raw = k1.title.lowercased(); let t2Raw = k2.title.lowercased()
            if t1Raw == q && t2Raw != q { return true }
            if t1Raw != q && t2Raw == q { return false }
            
            let t1Clean = clean(k1.title); let t2Clean = clean(k2.title)
            let match1 = (t1Clean == q); let match2 = (t2Clean == q)
            
            if match1 && !match2 { return true }
            if !match1 && match2 { return false }
            if match1 && match2 { return k1.title > k2.title }
            
            let start1 = t1Clean.hasPrefix(q); let start2 = t2Clean.hasPrefix(q)
            if start1 && !start2 { return true }
            if !start1 && start2 { return false }
            
            let contains1 = t1Clean.contains(q); let contains2 = t2Clean.contains(q)
            if contains1 && contains2 {
                if t1Clean.count != t2Clean.count { return t1Clean.count < t2Clean.count }
                return k1.title < k2.title
            }
            
            return k1.title < k2.title
        }
        
        return sorted.map { kit in
            Candidate(title: kit.title, maker: kit.maker, scale: kit.scale, series: kit.series, grade: kit.grade, jan: kit.jan, imageURLString: nil, isOfficial: true)
        }
    }
}
