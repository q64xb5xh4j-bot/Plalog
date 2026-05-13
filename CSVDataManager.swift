import Foundation
import SwiftData
import Combine

struct CSVKitData: Identifiable {
    let id = UUID()
    let title: String
    let maker: String
    let scale: String
    let series: String
    let jan: String // JANコード
    let grade: String
    var imageURLString: String? = nil // ✅ Added for compatibility
}

// Helper to convert CSV data to Candidate
extension CSVKitData {
    func toCandidate() -> Candidate {
        return Candidate(
            title: self.title,
            maker: self.maker,
            scale: self.scale,
            series: self.series,
            grade: self.grade,
            jan: self.jan,
            imageURLString: self.imageURLString
        )
    }
}

class CSVDataManager: ObservableObject {
    static let shared = CSVDataManager()
    @Published var loadedKits: [CSVKitData] = []
    @Published var isLoading: Bool = false
    
    // List of ALL supported manufacturer catalogs
    private let availableCatalogs = [
        "gunpla_catalog",      // Bandai / Gunpla (Main)
        "tamiya_military",     // Tamiya
        "aoshima_cars",        // Aoshima
        "hasegawa_aircraft",   // Hasegawa
        "kotobukiya_models",   // Kotobukiya
        "fujimi_models",       // Fujimi
        "finemolds_models",    // FineMolds
        "maxfactory_dougram",  // MaxFactory
        "volks_models"         // Volks
    ]
    
    init() {
        // Initial load in background
        Task {
            await reloadAll()
        }
    }
    
    func reloadAll() {
        if isLoading { return }
        Task {
            await performLoad()
        }
    }
    
    private func performLoad() async {
        if !loadedKits.isEmpty { return } // Double safety
        
        await MainActor.run { isLoading = true }
        
        // Run file I/O on background thread
        let newKits = await Task.detached(priority: .userInitiated) { [availableCatalogs] in
            var kits: [CSVKitData] = []
            // Load ALL catalogs unconditionally
            for filename in availableCatalogs {
                if let loaded = CSVDataManager.loadCatalog(filename: filename) {
                    kits.append(contentsOf: loaded)
                }
            }
            return kits
        }.value
        
        await MainActor.run {
            self.loadedKits = newKits
            self.isLoading = false
            print("CSVDataManager: Total loaded items: \(self.loadedKits.count)")
        }
    }
    
    // ✅ Ensure data is loaded (Async)
    func ensureDataLoaded() async {
        if !loadedKits.isEmpty { return }
        if isLoading {
            // Wait for existing load to finish
            // Simple polling/spin-wait since we don't have a Task reference to await
            while isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            }
            return
        }
        await performLoad()
    }
    
    // カタログデータの読み込み (Simple 6-column format)
    // Modified to be static/helper and return array instead of modifying state directly
    private static func loadCatalog(filename: String) -> [CSVKitData]? {
        guard let path = Bundle.main.path(forResource: filename, ofType: "csv") else { return nil }
        return parseCSV(path: path, format: .catalog)
    }
    
    private enum CSVFormat {
        case master
        case catalog
    }
    
    private static func parseCSV(path: String, format: CSVFormat) -> [CSVKitData] {
        var results: [CSVKitData] = []
        do {
            let content = try String(contentsOfFile: path, encoding: .utf8)
            let rows = content.components(separatedBy: "\n")
            
            // Header check - simplified for robustness (skip logic handled below if needed)
            var startIndex = 0
            if let first = rows.first, (first.contains("uuid") || first.contains("jan,title")) {
                startIndex = 1
            }
            
            // Regex for CSV parsing (handles quoted fields)
            // Pattern matches: Quoted field ("...") OR Non-comma field ([^,]*), followed by comma or end of string
            let csvPattern = "(\"[^\"]*\"|[^,]*)(,|$)"
            let regex = try NSRegularExpression(pattern: csvPattern)
            
            for i in startIndex..<rows.count {
                let row = rows[i]
                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                
                // Parse columns using Regex
                let nsString = row as NSString
                let matches = regex.matches(in: row, range: NSRange(location: 0, length: nsString.length))
                
                var columns: [String] = []
                for result in matches {
                    // Extract the field (group 1)
                    if let range = Range(result.range(at: 1), in: row) {
                        var field = String(row[range])
                        // Remove surrounding quotes if present
                        if field.hasPrefix("\"") && field.hasSuffix("\"") && field.count >= 2 {
                            field.removeFirst()
                            field.removeLast()
                            // Handle escaped quotes ("" -> ")
                            field = field.replacingOccurrences(of: "\"\"", with: "\"")
                        }
                        columns.append(field)
                    }
                }
                
                // Remove the last empty match that regex usually picks up if line ends with delimiter logic
                // But specifically for this regex, it might match the end $ as an empty field.
                // Let's refine: actually, standard split usually produces N+1 items for N commas if trailing.
                // Our parsing logic matches (Field)(Sep).
                // If a line is `A,B,C`, matches are `A,`, `B,`, `C$`. 3 matches. Correct.
                
                guard !columns.isEmpty else { continue }
                
                var data: CSVKitData?
                
                switch format {
                case .master:
                    // Schema: uuid, jan, name, maker, series, grade, scale, status...
                    if columns.count >= 7 {
                        let jan = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let title = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                        let maker = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
                        let series = columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
                        let grade = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)
                        let scale = columns[6].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        if !title.isEmpty {
                            data = CSVKitData(title: title, maker: maker, scale: scale, series: series, jan: jan, grade: grade)
                        }
                    }
                    
                case .catalog:
                    // Schema: jan, title, maker, series, grade, scale
                    if columns.count >= 6 {
                        let jan = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let title = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
                        let maker = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
                        let series = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
                        let grade = columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
                        let scale = columns[5].trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // ✅ Filter out Header values if any crept in
                        if jan == "jan" || title == "title" { continue }
                        
                        if !title.isEmpty {
                            data = CSVKitData(title: title, maker: maker, scale: scale, series: series, jan: jan, grade: grade)
                        }
                    }
                }
                
                if let validData = data {
                    results.append(validData)
                }
            }
        } catch {
            print("Error parsing CSV at \(path): \(error)")
        }
        return results
    }
    
    // 検索メソッド (キーワード)
    func search(query: String) -> [CSVKitData] {
        // if loadedKits.isEmpty { reloadAll() } // Removed blocking call
        
        let lowerQuery = query.lowercased()
        let keywords = lowerQuery.split(separator: " ")
        
        return loadedKits.filter { kit in
            keywords.allSatisfy { keyword in
                kit.title.localizedCaseInsensitiveContains(keyword) ||
                kit.series.localizedCaseInsensitiveContains(keyword) ||
                kit.maker.localizedCaseInsensitiveContains(keyword) ||
                kit.jan.contains(keyword)
            }
        }
    }
    
    // JANコード完全一致検索
    func findByJAN(_ code: String) -> CSVKitData? {
        if loadedKits.isEmpty { reloadAll() }
        return loadedKits.first { $0.jan == code }
    }
    
    // 近似検索 (Fuzzy Token Matching)
    // modelContext: Optional. If provided, also searches local DiscoveryCache (Gold Data)
    func searchApproximate(query: String, modelContext: ModelContext? = nil, limit: Int = 10) -> [(item: CSVKitData, score: Double)] {
        if loadedKits.isEmpty { reloadAll() }
        
        // 1. Prepare Search Candidates
        // Start with Silver Data (CSV)
        var searchPool: [(item: CSVKitData, isGold: Bool)] = loadedKits.map { ($0, false) }
        
        // Add Gold Data (Discovery Cache)
        if let context = modelContext {
             let cachedItems = DiscoveryManager.shared.fetchAllCache(modelContext: context)
             let goldItems = cachedItems.map { cache -> (CSVKitData, Bool) in
                 let gItem = CSVKitData(title: cache.title, maker: cache.maker, scale: cache.scale, series: cache.series, jan: cache.janCode, grade: cache.grade, imageURLString: nil)
                 return (gItem, true)
             }
             searchPool.insert(contentsOf: goldItems, at: 0)
        }
        
        // Custom Tokenizer: Preserve hyphens, slashes (1/144), and version numbers (Ver.2.0)
        func tokenize(_ text: String) -> Set<String> {
            var tokens = Set<String>()
            var proc = text.lowercased()
            
            // ✅ Step 1: Extract and preserve special patterns BEFORE splitting
            // Version patterns: Ver.2.0, v2.0, 2.0, etc.
            let versionRegex = try? NSRegularExpression(pattern: "(?:ver\\.?)?\\d+\\.\\d+", options: .caseInsensitive)
            if let regex = versionRegex {
                let matches = regex.matches(in: proc, range: NSRange(proc.startIndex..., in: proc))
                for match in matches {
                    if let range = Range(match.range, in: proc) {
                        tokens.insert(String(proc[range]))
                    }
                }
            }
            
            // ✅ Step 2: Replace delimiters with space (but NOT period or hyphen)
            // Period is used in version numbers, hyphen in model numbers like RX-78-2
            let delimiters = ["「", "」", "『", "』", "(", ")", "[", "]", "{", "}", "・", "，", ",", "！", "!", "?", "？", "_", "•", "●", "■", "★", "$"]
            for d in delimiters {
                proc = proc.replacingOccurrences(of: d, with: " ")
            }
            
            // ✅ Step 3: Split by whitespace and add remaining tokens
            let words = proc.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.count >= 2 } // Keep words with 2+ chars
            tokens.formUnion(words)
            
            return tokens
        }
        
        // Remove Noise Filter (Allow Scale/Grade to contribute to score)
        let noise = Set(["plastic", "model", "kit", "no", "non", "vol"]) 
        
        var queryTokens = tokenize(query)
        queryTokens = queryTokens.filter { !noise.contains($0) }
        
        if queryTokens.isEmpty { return [] }
        
        // === SEMANTIC TOKEN CLASSIFICATION ===
        // Attribute tokens: Scale and Grade (common, not distinctive alone)
        let attributePatterns = Set(["1/144", "1/100", "1/60", "1/35", "1/48", "1/72", "1/12", "1/32", 
                                     "hg", "mg", "pg", "rg", "eg", "hguc", "sd", "re", "fm"])

        // Classify query tokens
        let queryAttributeTokens = queryTokens.filter { attributePatterns.contains($0) }
        let queryIdentityTokens = queryTokens.filter { !attributePatterns.contains($0) }
        
        // Removed excessive logging
        
        // If NO identity tokens in query, fall back to old behavior (rare case)
        let requireIdentityMatch = !queryIdentityTokens.isEmpty
        
        // Calculate Score (Semantic Matching)
        // Calculate Score (Semantic Matching)
        let scored = searchPool.compactMap { (kit, isGold) -> (item: CSVKitData, score: Double)? in
            // Include Scale/Grade in search target text
            let fullText = "\(kit.title) \(kit.series) \(kit.maker) \(kit.scale) \(kit.grade)" 
            let itemTokens = tokenize(fullText)
            
            // Helper function to check if token matches
            func checkMatch(_ qToken: String) -> Bool {
                return itemTokens.contains { iToken in
                    // 1. Exact Match (Best)
                    if iToken == qToken { return true }
                    // 2. Short Token Safety
                    if qToken.count <= 2 { return false }
                    // 3. Substring Match
                    if iToken.contains(qToken) { return true }
                    // 4. Fuzzy Match (by Levenshtein)
                    let threshold = qToken.count > 5 ? 2 : 1
                    let dist = levenshtein(qToken, iToken)
                    return dist <= threshold && abs(qToken.count - iToken.count) <= 2
                }
            }
            
            // Check matches
            var identityMatches = 0
            for qToken in queryIdentityTokens {
                if checkMatch(qToken) { identityMatches += 1 }
            }
            
            // Valid match requirement
            if requireIdentityMatch && identityMatches == 0 { return nil }
            
            var attributeMatches = 0
            for qToken in queryAttributeTokens {
                if checkMatch(qToken) { attributeMatches += 1 }
            }
            
            // Base Score
            let totalMatches = identityMatches + attributeMatches
            var score = Double(totalMatches) / Double(queryTokens.count)
            
            // Filter weak matches (Silver only)
            if !isGold && score < 0.3 { return nil }
            
            // Critical: Apply Gold Boost to ensure it tops the list
            if isGold { score += 100.0 }
            
            return (kit, score)
        }
        
        // Final Sort & Deduplicate
        // Sort by score DESC (Gold items with >100 will be first)
        let sortedHits = scored.sorted { $0.score > $1.score }
        
        // Deduplicate: Keep first occurrence of each title (which will be the highest score/Gold one)
        var uniqueResults: [(item: CSVKitData, score: Double)] = []
        var seenTitles = Set<String>()
        
        for hit in sortedHits {
            let simpleTitle = hit.item.title.replacingOccurrences(of: " ", with: "").lowercased()
            if !seenTitles.contains(simpleTitle) {
                seenTitles.insert(simpleTitle)
                uniqueResults.append(hit)
            }
        }
        
        return uniqueResults.prefix(limit).map { $0 }
    }
    
    private func levenshtein(_ s1: String, _ s2: String) -> Int {
        let a = Array(s1.utf16)
        let b = Array(s2.utf16)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        
        var d = [Int](0...b.count)
        for i in 1...a.count {
            var last = i
            for j in 1...b.count {
                let cost = a[i-1] == b[j-1] ? 0 : 1
                let val = min(d[j-1] + cost, d[j] + 1, last + 1)
                d[j-1] = last
                last = val
            }
            d[b.count] = last
        }
        return d[b.count]
    }
    
    // === PUL-DOWN / FILTERING SUPPORT ===
    
    // Get unique list of makers (sorted, with BANDAI SPIRITS first)
    func getAllMakers() -> [String] {
        if loadedKits.isEmpty { reloadAll() }
        let makers = Set(loadedKits.compactMap { $0.maker.isEmpty ? nil : $0.maker })
        var sorted = makers.sorted()
        
        // Ensure BANDAI SPIRITS is at the top if present
        if let index = sorted.firstIndex(of: "BANDAI SPIRITS") {
            sorted.remove(at: index)
            sorted.insert("BANDAI SPIRITS", at: 0)
        }
        return sorted
    }
    
    // Get unique list of series (sorted alphabetically)
    func getAllSeries() -> [String] {
        if loadedKits.isEmpty { reloadAll() }
        let series = Set(loadedKits.compactMap { item -> String? in
            if item.series.isEmpty { return nil }
            if item.series.lowercased() == "series" { return nil } // Filter header
            return item.series
        })
        return series.sorted()
    }
    
    // Get unique list of grades
    func getAllGrades() -> [String] {
        if loadedKits.isEmpty { reloadAll() }
        let grades = Set(loadedKits.compactMap { item -> String? in
            if item.grade.isEmpty { return nil }
            if item.grade.lowercased() == "grade" { return nil } // Filter header
            // Filter out known misaligned data if any remains
            if item.grade == "BANDAI SPIRITS" { return nil }
            return item.grade
        })
        return grades.sorted()
    }
    
    // Get unique list of scales
    func getAllScales() -> [String] {
        if loadedKits.isEmpty { reloadAll() }
        let scales = Set(loadedKits.compactMap { item -> String? in
            if item.scale.isEmpty { return nil }
            if item.scale.lowercased() == "scale" { return nil } // Filter header
            return item.scale
        })
        return scales.sorted()
    }
    
    // Filtered Search Method
    func filterSearch(series: String?, grade: String?, scale: String?, maker: String? = nil, keyword: String?) -> [CSVKitData] {
        if loadedKits.isEmpty { reloadAll() }
        
        let lowerKeyword = keyword?.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return loadedKits.filter { kit in
            // Filter by Maker
            if let targetMaker = maker, !targetMaker.isEmpty {
                if kit.maker != targetMaker { return false }
            }
            
            // Filter by Series
            if let targetSeries = series, !targetSeries.isEmpty {
                if kit.series != targetSeries { return false }
            }
            
            // Filter by Grade
            if let targetGrade = grade, !targetGrade.isEmpty {
                if kit.grade != targetGrade { return false }
            }
            
            // Filter by Scale
            if let targetScale = scale, !targetScale.isEmpty {
                if kit.scale != targetScale { return false }
            }
            
            if let query = lowerKeyword, !query.isEmpty {
                // If keyword provided, check title/jan/maker
                let match = kit.title.localizedCaseInsensitiveContains(query) ||
                            kit.jan.contains(query) ||
                            kit.maker.localizedCaseInsensitiveContains(query)
                if !match { return false }
            }
            
            return true
        }
    }
    
    // ✅ Health Check / Bulk Update
    // Returns a list of (Kit, NewData) for items that have a JAN match but differing data
    func checkForUpdates(for kits: [Kit]) -> [(Kit, CSVKitData)] {
        if loadedKits.isEmpty { reloadAll() }
        
        var updates: [(Kit, CSVKitData)] = []
        
        for kit in kits {
            guard !kit.jan.isEmpty else { continue }
            
            if let match = findByJAN(kit.jan) {
                // Check for significant differences to avoid unnecessary updates
                // We mainly care if the Title or Maker was "Provisional" or empty/different
                // Or if it's a "Stock" item that was registered provisionally
                
                // Simple logic: If Title differs significantly
                if kit.title != match.title || kit.maker != match.maker {
                    updates.append((kit, match))
                }
            }
        }
        
        return updates
    }
}
