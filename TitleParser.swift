//
//  TitleParser.swift V20
//  Plalog
//
//  Created by (User) on 2026/01/03.
//  1. バージョン管理ルールに基づき更新 (V19 -> V20)
//  2. 修正点:
//     - 「限定」キーワード（ガンダムベース限定など）を文末に移動させるロジックを追加。
//     - セット商品などの正式名称の並び順を「主役名 ＋ 限定情報」に最適化。
//     - 全張りルールに基づき全文出力。
//

import Foundation

struct TitleParser {
    struct Result {
        let cleanTitle: String
        let maker: String
        let scale: String
        let series: String
        let grade: String
    }
    
    static let knownSeries = [
        "機動戦士ガンダム 逆襲のシャア", "機動戦士ガンダム 水星の魔女", "機動戦士ガンダム 鉄血のオルフェンズ", "ガンダム Gのレコンギスタ", "機動戦士ガンダムAGE", "機動戦士ガンダム00", "機動戦士ガンダムSEED DESTINY", "機動戦士ガンダムSEED FREEDOM", "機動戦士ガンダムSEED", "∀ガンダム", "機動新世紀ガンダムX", "新機動戦記ガンダムW", "機動武闘伝Gガンダム", "機動戦士Vガンダム", "機動戦士ガンダムF91", "機動戦士ガンダム0083", "機動戦士ガンダム0080", "機動戦士ガンダム 第08MS小隊", "機動戦士ガンダム サンダーボルト", "機動戦士ガンダムUC", "機動戦士Zガンダム", "機動戦士ガンダムZZ", "機動戦士ガンダム", "ガンダムビルドファイターズ", "ガンダムビルドダイバーズ", "30 MINUTES MISSIONS", "30 MINUTES SISTERS", "境界戦機", "スター・ウォーズ", "エヴァンゲリオン", "マクロス", "ボトムズ", "ダンバイン", "エルガイム", "パトレイバー", "コードギアス"
    ]
    
    static func parse(title: String, originalMaker: String, originalSeries: String) -> Result {
        var workTitle = title
        
        workTitle = decodeHTMLEntities(workTitle)
        workTitle = smartNormalize(workTitle)
        
        // ✅ 修正: 限定キーワードの退避
        let limitedKeywords = ["ガンダムベース限定", "プレミアムバンダイ限定", "イベント限定", "限定"]
        var foundLimitedWord: String? = nil
        for kw in limitedKeywords {
            if workTitle.contains(kw) {
                foundLimitedWord = kw
                workTitle = workTitle.replacingOccurrences(of: kw, with: " ")
                break
            }
        }
        
        var grade = ""
        var scale = ""
        
        func extract(pattern: String, target: inout String) -> String? {
            if let range = target.range(of: pattern, options: [.regularExpression, .caseInsensitive]) {
                let matched = String(target[range])
                target.replaceSubrange(range, with: " ")
                return matched.trimmingCharacters(in: .whitespaces)
            }
            return nil
        }
        
        if let m = extract(pattern: "\\bHG[A-Z]*\\b", target: &workTitle) { grade = m }
        else if let m = extract(pattern: "\\bMG[A-Z]*\\b", target: &workTitle) { grade = m }
        else if let m = extract(pattern: "\\bRG\\b", target: &workTitle) { grade = m }
        else if let m = extract(pattern: "\\bPG\\b", target: &workTitle) { grade = m }
        else if let m = extract(pattern: "\\bEG\\b", target: &workTitle) { grade = m }
        else if let m = extract(pattern: "\\bFM\\b", target: &workTitle) { grade = m }
        else if let m = extract(pattern: "\\bSD\\b", target: &workTitle) { grade = m }
        
        if let s = extract(pattern: "1/[0-9]+", target: &workTitle) { scale = s }
        
        var modelNumber = ""
        if let r = workTitle.range(of: "[A-Z]{2,}-[0-9]+[A-Z0-9-]*", options: .regularExpression) {
            modelNumber = String(workTitle[r])
        }
        
        var suffixInfo = ""
        if let r = workTitle.range(of: "Ver\\.[a-zA-Z0-9]+", options: .regularExpression) {
            suffixInfo = " " + String(workTitle[r])
            workTitle.replaceSubrange(r, with: "")
        }
        
        workTitle = workTitle.replacingOccurrences(of: "&", with: " & ")
        workTitle = workTitle.replacingOccurrences(of: "/", with: " / ")
        
        workTitle = workTitle.replacingOccurrences(of: "【.*?】", with: " ", options: .regularExpression)
        workTitle = workTitle.replacingOccurrences(of: "\\[.*?\\]", with: " ", options: .regularExpression)
        
        let sellingKeywords = ["中古", "即納", "即日", "発送", "新品", "未開封", "未組立", "塗装済み", "完成品", "送料無料", "送料込", "在庫", "あす楽", "国内", "正規品", "訳あり", "箱傷み", "同梱", "代引き", "セット"]
        for word in sellingKeywords {
            workTitle = workTitle.replacingOccurrences(of: word, with: " ")
        }
        
        var maker = originalMaker
        var series = originalSeries
        
        let makerPatterns = ["BANDAI SPIRITS", "BANDAI", "バンダイ", "コトブキヤ", "KOTOBUKIYA", "タミヤ", "TAMIYA", "ハセガワ", "HASEGAWA", "アオシマ", "AOSHIMA", "グッドスマイルカンパニー", "Good Smile Company"]
        for m in makerPatterns {
            if workTitle.localizedCaseInsensitiveContains(m) {
                if maker.isEmpty { maker = m }
                workTitle = workTitle.replacingOccurrences(of: m, with: " ", options: .caseInsensitive)
            }
        }
        
        let sortedSeries = knownSeries.sorted { $0.count > $1.count }
        for s in sortedSeries {
            if workTitle.localizedCaseInsensitiveContains(s) {
                if series.isEmpty { series = s }
                workTitle = workTitle.replacingOccurrences(of: s, with: " ", options: .caseInsensitive)
            }
        }
        
        let symbols = ["「", "」", "『", "』", "(", ")", "{", "}", ":", "：", " - ", "｜", "|", "■", "★", "●", "◆", "－"]
        for s in symbols { workTitle = workTitle.replacingOccurrences(of: s, with: " ") }
        
        if let range = workTitle.range(of: "\\s+[0-9]{3,}$", options: .regularExpression) {
            workTitle.removeSubrange(range)
        }
        
        let tokens = workTitle.components(separatedBy: .whitespaces).filter { $0.count >= 1 }
        var seenTokens = Set<String>()
        var uniqueTokens: [String] = []
        
        for t in tokens {
            let lowerToken = t.lowercased()
            if !seenTokens.contains(lowerToken) {
                uniqueTokens.append(t)
                seenTokens.insert(lowerToken)
            }
        }
        workTitle = uniqueTokens.joined(separator: " ")
        
        // 7. 最終整形
        var cleanTitle = workTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // ✅ 修正: 限定キーワードを文末に付与
        if let limited = foundLimitedWord {
            cleanTitle = "\(cleanTitle) \(limited)"
        }
        
        if cleanTitle.isEmpty && !modelNumber.isEmpty { cleanTitle = modelNumber }
        
        if !suffixInfo.isEmpty {
            let suffixClean = suffixInfo.trimmingCharacters(in: .whitespaces)
            if !cleanTitle.contains(suffixClean) {
                cleanTitle = "\(cleanTitle) \(suffixClean)"
            }
        }
        
        return Result(cleanTitle: cleanTitle, maker: maker.isEmpty ? "BANDAI SPIRITS" : maker, scale: scale, series: series, grade: grade)
    }
    
    static private func smartNormalize(_ text: String) -> String {
        let fullWidth = text.applyingTransform(StringTransform("Halfwidth-Fullwidth"), reverse: false) ?? text
        let converted = fullWidth.unicodeScalars.map { scalar -> String in
            let val = scalar.value
            if val >= 0xFF01 && val <= 0xFF5E {
                return String(UnicodeScalar(val - 0xFEE0)!)
            } else if val == 0x3000 {
                return " "
            } else {
                return String(scalar)
            }
        }.joined()
        return converted
    }
    
    static private func decodeHTMLEntities(_ text: String) -> String {
        var t = text
        t = t.replacingOccurrences(of: "&amp;", with: "&")
        t = t.replacingOccurrences(of: "&quot;", with: "\"")
        t = t.replacingOccurrences(of: "&lt;", with: "<")
        t = t.replacingOccurrences(of: "&gt;", with: ">")
        return t
    }
    
    static func extractOnlyModelNumber(from text: String) -> String? {
        let normalized = smartNormalize(text)
        let pattern = "[A-Z]{2,}-[0-9]+[A-Z0-9-]*"
        if let range = normalized.range(of: pattern, options: .regularExpression) {
            return String(normalized[range])
        }
        return nil
    }
}
