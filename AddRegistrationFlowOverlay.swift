//
//  AddRegistrationFlowOverlay.swift V2
//  Plalog
//
//  Created by (User) on 2026/01/02.
//  1. バージョン管理ルールに基づき更新 (V1 -> V2)
//  2. 修正点:
//     - 独立した TitleParser.swift との衝突を防ぐため、このファイル内の古い TitleParser 定義を削除
//     - 全デバイス共通の Step / MethodKey に .scan を追加し、レンズ検索に対応
//

import SwiftUI
import SwiftData

// MARK: - Wrapper View (分岐ポイント)
struct AddRegistrationFlowOverlay: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            RegistrationFlow_iPad(isPresented: $isPresented)
        } else {
            RegistrationFlow_iPhone(isPresented: $isPresented)
        }
    }
}

// MARK: - Shared Definitions (共通定義)

enum StatusKey: String, CaseIterable, Identifiable, Equatable {
    case wish, reservation, stock, inprogress, complete
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .wish: return "欲しい"
        case .reservation: return "予約済"
        case .stock: return "積み"
        case .inprogress: return "制作中"
        case .complete: return "完成"
        }
    }
    
    var assetName: String { rawValue }
    
    var dbValue: Int {
        switch self {
        case .wish: return 0; case .reservation: return 1; case .stock: return 2; case .inprogress: return 3; case .complete: return 4
        }
    }
    
    var allowsBarcode: Bool {
        switch self {
        case .wish, .reservation: return false; default: return true
        }
    }
}

enum MethodKey: String, CaseIterable, Identifiable, Equatable {
    case barcode, scan, text // ✅ scanを追加
    var id: String { rawValue }
    var assetName: String {
        switch self {
        case .barcode: return "camera"
        case .scan: return "icon_clean_scan"
        case .text: return "icon_text_search"
        }
    }
    var label: String {
        switch self {
        case .barcode: return "スキャン"; case .scan: return "レンズ"; case .text: return "検索"
        }
    }
}

struct Candidate: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var maker: String
    var scale: String
    var series: String
    var grade: String
    var jan: String
    var imageURLString: String? // Changed to String to support assets/filenames
    var price: String = ""
    var isOfficial: Bool = false
    var discoveryStatus: DiscoveryStatus = .unknown // ✅ Gamification
    var matchScore: Double? = nil // ✅ Added for OCR alignment ranking
    
    // MARK: - Title Cleanup for Registration
    /// Cleans the title by extracting Scale/Grade and removing year, returning a new Candidate.
    /// - Display: `ENTRY GRADE 1/144 RX-78-2 ガンダム (2024)`
    /// - Cleaned: Title=`RX-78-2 ガンダム`, Scale=`1/144`, Grade=`ENTRY GRADE`
    func cleanedForRegistration() -> Candidate {
        var cleanedTitle = self.title
        var extractedScale = self.scale
        var extractedGrade = self.grade
        
        print("🧹 [Cleanup] START: '\(cleanedTitle)'")
        
        // ✅ Grade Patterns (Order matters: longer patterns first)
        // Note: Short patterns like "RG", "HG" need word boundary matching
        let gradePatterns: [(pattern: String, normalized: String)] = [
            ("PERFECT GRADE", "PG"),
            ("MASTER GRADE", "MG"),
            ("REAL GRADE", "RG"),
            ("HIGH GRADE", "HG"),
            ("ENTRY GRADE", "EG"),
            ("SUPER DEFORMED", "SD"),
            ("FULL MECHANICS", "FM"),
            ("RE/100", "RE/100"),
            ("HGUC", "HGUC"),
            ("HGCE", "HGCE"),
            ("HGAC", "HGAC"),
            ("HGAW", "HGAW"),
            ("HGFC", "HGFC"),
            ("HGBF", "HGBF"),
            ("HGBD", "HGBD"),
            ("MGEX", "MGEX"),
            ("PG", "PG"),
            ("MG", "MG"),
            ("RG", "RG"),
            ("HG", "HG"),
            ("EG", "EG"),
            ("SD", "SD"),
            ("FM", "FM"),
            // Note: "RE" removed - too short and matches inside "Ver", "Here", etc.
            // RE/100 is already covered above
        ]
        
        // ✅ Scale Patterns
        let scalePatterns = ["1/144", "1/100", "1/60", "1/48", "1/72", "1/35", "1/12", "1/32", "1/24", "1/200", "1/400", "1/550", "1/1700", "1/2400"]
        
        // ✅ Helper to match with word boundaries (prevents "RE" matching inside "Ver")
        func removeWithWordBoundary(_ pattern: String, from text: inout String) -> Bool {
            // Escape special regex characters in pattern (for patterns like "RE/100")
            let escaped = NSRegularExpression.escapedPattern(for: pattern)
            // Use word boundary \b to ensure whole-word match
            let regexPattern = "\\b\(escaped)\\b"
            if let regex = try? NSRegularExpression(pattern: regexPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range, in: text) {
                text.removeSubrange(range)
                return true
            }
            return false
        }
        
        // Extract and remove Grade (with word boundary)
        for (pattern, normalized) in gradePatterns {
            if removeWithWordBoundary(pattern, from: &cleanedTitle) {
                print("🧹 [Cleanup] Removed Grade '\(pattern)' → '\(cleanedTitle)'")
                if extractedGrade.isEmpty {
                    extractedGrade = normalized
                }
            }
        }
        
        // Extract and remove Scale (with word boundary)
        for pattern in scalePatterns {
            if removeWithWordBoundary(pattern, from: &cleanedTitle) {
                print("🧹 [Cleanup] Removed Scale '\(pattern)' → '\(cleanedTitle)'")
                if extractedScale.isEmpty {
                    extractedScale = pattern
                }
            }
        }
        
        // ✅ Remove Year patterns: (2024), [2024] ONLY - parenthesized/bracketed years
        // Removed standalone year pattern - it was too aggressive
        let yearPatterns = [
            "\\(19[89]\\d\\)", "\\(20[0-9]{2}\\)",  // (1980-2099)
            "\\[19[89]\\d\\]", "\\[20[0-9]{2}\\]",  // [1980-2099]
        ]
        for pattern in yearPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let before = cleanedTitle
                cleanedTitle = regex.stringByReplacingMatches(
                    in: cleanedTitle,
                    options: [],
                    range: NSRange(cleanedTitle.startIndex..., in: cleanedTitle),
                    withTemplate: ""
                )
                if before != cleanedTitle {
                    print("🧹 [Cleanup] Removed Year pattern '\(pattern)' → '\(cleanedTitle)'")
                }
            }
        }
        
        // ✅ Remove bracket tags like [j 35], [j 14], etc. (internal codes)
        if let regex = try? NSRegularExpression(pattern: "\\[j\\s*\\d+\\]", options: .caseInsensitive) {
            let before = cleanedTitle
            cleanedTitle = regex.stringByReplacingMatches(
                in: cleanedTitle,
                options: [],
                range: NSRange(cleanedTitle.startIndex..., in: cleanedTitle),
                withTemplate: ""
            )
            if before != cleanedTitle {
                print("🧹 [Cleanup] Removed [j XX] tag → '\(cleanedTitle)'")
            }
        }
        
        // ✅ Final cleanup: trim, collapse multiple spaces
        cleanedTitle = cleanedTitle
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("🧹 [Cleanup] FINAL: '\(cleanedTitle)' | Scale: '\(extractedScale)' | Grade: '\(extractedGrade)'")
        
        return Candidate(
            title: cleanedTitle,
            maker: self.maker,
            scale: extractedScale,
            series: self.series,
            grade: extractedGrade,
            jan: self.jan,
            imageURLString: self.imageURLString,
            price: self.price,
            isOfficial: self.isOfficial,
            discoveryStatus: self.discoveryStatus,
            matchScore: self.matchScore
        )
    }
}

enum DiscoveryStatus: Equatable {
    case unknown
    case firstDiscovery
    case discovered(by: String, date: Date, isLocked: Bool, voteCount: Int)
    
    // Equatable logic for assoc values
    static func == (lhs: DiscoveryStatus, rhs: DiscoveryStatus) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown), (.firstDiscovery, .firstDiscovery): return true
        case let (.discovered(n1, d1, l1, v1), .discovered(n2, d2, l2, v2)): 
            return n1 == n2 && d1 == d2 && l1 == l2 && v1 == v2
        default: return false
        }
    }
}

enum Step: Equatable {
    case status
    case method(StatusKey)
    case barcode(StatusKey)
    case scan(StatusKey)   // ✅ 追加
    case search(StatusKey)
    case register(StatusKey, Candidate)
    case detail(StatusKey, Candidate)
}
