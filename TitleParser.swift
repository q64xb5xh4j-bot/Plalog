//  TitleParser.swift V23
//  Modified: 2026-01-04 16:40
//  Plalog
//
//  Created by (User) on 2026/01/03.
//  1. バージョン管理ルールに基づき更新 (V19 -> V20)
//  2. 修正点:
//     - Modified: 2026-01-04 15:15
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
    
    // ✅ Keyword to Series Inference Map
    // Helps identify series even if the explicit series name is missing (e.g. "RX-78" -> "Mobile Suit Gundam")
    static let seriesInferenceMap: [String: String] = [
        "RX-78": "機動戦士ガンダム",
        "アムロ": "機動戦士ガンダム",
        "シャア": "機動戦士ガンダム",
        "ザク": "機動戦士ガンダム",
        "グフ": "機動戦士ガンダム",
        "ドム": "機動戦士ガンダム",
        "ゲルググ": "機動戦士ガンダム",
        "ジオング": "機動戦士ガンダム",
        "ズゴック": "機動戦士ガンダム",
        "ゴッグ": "機動戦士ガンダム",
        "アッガイ": "機動戦士ガンダム",
        "Mk-II": "機動戦士Zガンダム",
        "ゼータ": "機動戦士Zガンダム",
        "Zガンダム": "機動戦士Zガンダム",
        "百式": "機動戦士Zガンダム",
        "キュベレイ": "機動戦士Zガンダム",
        "ダブルゼータ": "機動戦士ガンダムZZ",
        "ZZ": "機動戦士ガンダムZZ",
        "ニューガンダム": "機動戦士ガンダム 逆襲のシャア",
        "νガンダム": "機動戦士ガンダム 逆襲のシャア",
        "サザビー": "機動戦士ガンダム 逆襲のシャア",
        "ユニコーン": "機動戦士ガンダムUC",
        "バンシィ": "機動戦士ガンダムUC",
        "シナンジュ": "機動戦士ガンダムUC",
        "クシャトリヤ": "機動戦士ガンダムUC",
        "ナラティブ": "機動戦士ガンダムNT",
        "フェネクス": "機動戦士ガンダムNT",
        "ハサウェイ": "機動戦士ガンダム 閃光のハサウェイ",
        "クスィー": "機動戦士ガンダム 閃光のハサウェイ",
        "ペーネロペー": "機動戦士ガンダム 閃光のハサウェイ",
        "フリーダム": "機動戦士ガンダムSEED",
        "ストライク": "機動戦士ガンダムSEED",
        "イージス": "機動戦士ガンダムSEED",
        "デュエル": "機動戦士ガンダムSEED",
        "バスター": "機動戦士ガンダムSEED",
        "ブリッツ": "機動戦士ガンダムSEED",
        "インパルス": "機動戦士ガンダムSEED DESTINY",
        "デスティニー": "機動戦士ガンダムSEED DESTINY",
        "ストライクフリーダム": "機動戦士ガンダムSEED DESTINY",
        "インフィニットジャスティス": "機動戦士ガンダムSEED DESTINY",
        "ダブルオー": "機動戦士ガンダム00",
        "エクシア": "機動戦士ガンダム00",
        "バルバトス": "機動戦士ガンダム 鉄血のオルフェンズ",
        "エアリアル": "機動戦士ガンダム 水星の魔女",
        "キャリバーン": "機動戦士ガンダム 水星の魔女",
        "ルブリス": "機動戦士ガンダム 水星の魔女",
        "UNLEASHED": "機動戦士ガンダム",
        "アンリーシュド": "機動戦士ガンダム",
        "G-3": "機動戦士ガンダム",
        "オリジン": "機動戦士ガンダム THE ORIGIN",
        "THE ORIGIN": "機動戦士ガンダム THE ORIGIN",
        "鉄血": "機動戦士ガンダム 鉄血のオルフェンズ",
        "オルフェンズ": "機動戦士ガンダム 鉄血のオルフェンズ",
        "バエル": "機動戦士ガンダム 鉄血のオルフェンズ"
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
        
        // ✅ 修正: ノイズ除去 (PTM, 日付コードなど)
        workTitle = workTitle.replacingOccurrences(of: "PTM", with: " ", options: [.caseInsensitive]) // "PTM" (Plastic Model) suffix/prefix
        if let dateRange = workTitle.range(of: "\\b[12][0-9]{7}\\b", options: .regularExpression) { // 8-digit dates (e.g. 19991231)
            workTitle.replaceSubrange(dateRange, with: " ")
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
        
        // Added based on user feedback (2026-01-12)
        let sellingKeywords = [
            "中古", "即納", "即日", "発送", "新品", "未開封", "未組立", "塗装済み", "完成品", "送料無料", "送料込", "在庫", "あす楽", "国内", "正規品", "訳あり", "箱傷み", "同梱", "代引き", "セット", "再販", "プラモデル",
            "予約", "新製品", "新作", "特典", "期間限定", "セール", "OFF", "オフ", "クーポン", "ポイント", "おすすめ", "オススメ", "人気",
            "返品種別", "返品種別B", "使用感あり", "使用感", "単品", "食玩", "おもちゃ", "お取り寄せ", "発売済", "取り寄せ",
            "有り", "切れ"
        ]
        for word in sellingKeywords {
            workTitle = workTitle.replacingOccurrences(of: word, with: " ")
        }
        
        var maker = originalMaker
        // Modified: V23 - Do NOT trust originalSeries from Yahoo (it's often generic "Gundam")
        var series = "" 
        
        // Brand to Maker Mapping (Inference)
        let brandToMaker: [String: String] = [
            "PLAMAX": "Max Factory",
            "MODEROID": "Good Smile Company",
            "MSG": "KOTOBUKIYA",
            "M.S.G": "KOTOBUKIYA",
            "フレームアームズ": "KOTOBUKIYA",
            "メガミデバイス": "KOTOBUKIYA",
            "創彩少女庭園": "KOTOBUKIYA",
            "アルカナディア": "KOTOBUKIYA",
            "ヘキサギア": "KOTOBUKIYA",
            "IMS": "VOLKS",
            "SWS": "VOLKS",
            "COMBAT ARMORS": "Max Factory"
        ]
        
        for (brand, brandMaker) in brandToMaker {
            if workTitle.localizedCaseInsensitiveContains(brand) {
                if maker.isEmpty || maker == "BANDAI SPIRITS" { maker = brandMaker }
                // Don't remove brand name as it's often part of the product identity (e.g. PLAMAX)
            }
        } 
        
        let makerPatterns = [
            "BANDAI SPIRITS", "BANDAI", "バンダイ",
            "KOTOBUKIYA", "コトブキヤ",
            "TAMIYA", "タミヤ",
            "HASEGAWA", "ハセガワ",
            "AOSHIMA", "アオシマ",
            "WAVE", "ウェーブ",
            "VOLKS", "ボークス",
            "PLUM", "プラム",
            "Max Factory", "マックスファクトリー",
            "FUJIMI", "フジミ", "フジミ模型",
            "Fine Molds", "ファインモールド",
            "Good Smile Company", "グッドスマイルカンパニー",
            "DOYUSHA", "童友社",
            "PLATZ", "プラッツ",
            "MENG", "モンモデル",
            "TAKOM", "タコム",
            "ACADEMY", "アカデミー",
            "ITALERI", "イタレリ",
            "AIRFIX", "エアフィックス",
            "REVELL", "レベル"
        ]
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
        
        // Logical Inference: If series is still unknown, try to infer from unit name
        if series.isEmpty {
            for (key, val) in seriesInferenceMap {
                if workTitle.localizedCaseInsensitiveContains(key) {
                    series = val
                    break
                }
            }
        }
        
        // Added 《 》 based on user feedback
        let symbols = ["「", "」", "『", "』", "(", ")", "{", "}", ":", "：", " - ", "｜", "|", "■", "★", "●", "◆", "－", "≪", "≫", "！", "♪", "◎", "※", "◇", "○", "☆", "《", "》", "・"]
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
        
        return Result(cleanTitle: cleanTitle, maker: maker.isEmpty ? "Unknown" : maker, scale: scale, series: series, grade: grade)
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
        var decoded = text
        let entities = [
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&amp;", "&"), // Must be last or handled recursively
            ("&nbsp;", " "),
            ("&copy;", "©"),
            ("&reg;", "®"),
            ("&trade;", "™")
        ]
        
        // Recursive decoding loop (max 30 passes to handle deep nesting)
        var previous = ""
        var loopCount = 0
        while decoded != previous && loopCount < 30 {
            previous = decoded
            for (entity, value) in entities {
                decoded = decoded.replacingOccurrences(of: entity, with: value)
            }
            // Handle numeric entities roughly
            // decimal
            if let regex = try? NSRegularExpression(pattern: "&#([0-9]+);") {
                let nsString = decoded as NSString
                let matches = regex.matches(in: decoded, range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    if let range = Range(match.range(at: 1), in: decoded),
                       let num = Int(decoded[range]),
                       let scalar = UnicodeScalar(num) {
                        let fullRange = Range(match.range, in: decoded)!
                        decoded.replaceSubrange(fullRange, with: String(scalar))
                    }
                }
            }
            // hex
            if let regex = try? NSRegularExpression(pattern: "&#x([0-9a-fA-F]+);") {
                let nsString = decoded as NSString
                let matches = regex.matches(in: decoded, range: NSRange(location: 0, length: nsString.length))
                for match in matches.reversed() {
                    if let range = Range(match.range(at: 1), in: decoded),
                       let num = Int(decoded[range], radix: 16),
                       let scalar = UnicodeScalar(num) {
                        let fullRange = Range(match.range, in: decoded)!
                        decoded.replaceSubrange(fullRange, with: String(scalar))
                    }
                }
            }
            loopCount += 1
        }
        
        return decoded
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
