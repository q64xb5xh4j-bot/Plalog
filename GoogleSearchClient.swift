//
//  GoogleSearchClient.swift V5
//  Plalog
//
//  Created by (User) on 2026/01/03.
//  GOD MODE: Google Custom Search API Client (H1 Product Scraper Enhanced)
//  修正点:
//  - バンダイホビーサイトの正式名称タグ `p-heading__h1-product` を最優先で取得。
//  - HTMLデコード処理を強化し、&amp; などの記号を完全に除去。
//  - 構造体の閉じ括弧を含め、全張りルールを遵守。
//

import Foundation

struct GoogleItem: Identifiable {
    let id = UUID()
    var title: String
    let link: String
    let snippet: String
    let imageURL: String?
}

class GoogleSearchClient {
    static let shared = GoogleSearchClient()
    private init() {}
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "googleApiKey")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    
    private var cx: String {
        let rawCx = UserDefaults.standard.string(forKey: "googleSearchEngineId")?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if rawCx.hasPrefix("cx=") { return String(rawCx.dropFirst(3)) }
        return rawCx
    }
    
    func search(query: String) async throws -> [GoogleItem] {
        guard !apiKey.isEmpty, !cx.isEmpty else {
            throw NSError(domain: "GoogleSearchClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "設定画面でAPI KeyとSearch Engine IDを正しく入力してください。"])
        }
        
        var components = URLComponents(string: "https://www.googleapis.com/customsearch/v1")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "cx", value: cx),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "searchType", value: "image")
        ]
        
        guard let url = components.url else {
            throw NSError(domain: "GoogleSearchClient", code: 400, userInfo: [NSLocalizedDescriptionKey: "無効な検索クエリです。"])
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let errorJson = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
            let details = (errorJson["error"] as? [String: Any])?["message"] as? String ?? "Unknown Error"
            throw NSError(domain: "GoogleSearchClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Google API Error (\(httpResponse.statusCode)): \(details)"])
        }
        
        let res = try JSONDecoder().decode(GoogleSearchResponse.self, from: data)
        guard let items = res.items else { return [] }
        
        // Parallel Fetching: Process all items concurrently
        return await withTaskGroup(of: GoogleItem.self) { group in
            for item in items {
                group.addTask {
                    let contextLink = item.image?.contextLink ?? ""
                    var finalTitle = item.title ?? "No Title"
                    
                    // スクレイピングは失敗しても元のタイトルを使うため、try?等で囲むか内部でハンドリング
                    if self.isOfficialBandaiSite(url: contextLink) {
                        if let officialTitle = await self.fetchOfficialTitle(from: contextLink) {
                            finalTitle = officialTitle
                        }
                    }
                    
                    return GoogleItem(
                        title: finalTitle,
                        link: contextLink,
                        snippet: item.snippet ?? "",
                        imageURL: item.link
                    )
                }
            }
            
            var results: [GoogleItem] = []
            for await item in group {
                results.append(item)
            }
            return results
        }
    }
    
    private func isOfficialBandaiSite(url: String) -> Bool {
        let officialDomains = ["bandai-hobby.net", "gundam-base.net"]
        return officialDomains.contains { url.contains($0) }
    }
    
    private func fetchOfficialTitle(from urlString: String) async -> String? {
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 3.0 // Short timeout for speed
            let session = URLSession(configuration: config)
            
            let (data, _) = try await session.data(from: url)
            guard let html = String(data: data, encoding: .utf8) else { return nil }
            
            // 1. バンダイホビーサイト: h1 (p-heading__h1-product) を最優先
            if urlString.contains("bandai-hobby.net") {
                if let title = extractText(from: html, startTag: "class=\"p-heading__h1-product\">", endTag: "</h1>") {
                    return decodeHTMLEntities(title)
                }
            }
            
            // 2. ガンダムベース公式サイト: h2
            if urlString.contains("gundam-base.net") {
                if let title = extractText(from: html, startTag: "<h2>", endTag: "</h2>") {
                    return decodeHTMLEntities(title)
                }
            }
            
            // 3. ページタイトルからの抽出
            if let pageTitle = extractText(from: html, startTag: "<title>", endTag: "</title>") {
                let clean = pageTitle.components(separatedBy: "｜").first ?? pageTitle
                return decodeHTMLEntities(clean)
            }
            
        } catch {
            print("Failed to fetch official title for \(urlString): \(error)")
        }
        return nil
    }
    
    private func extractText(from html: String, startTag: String, endTag: String) -> String? {
        guard let startRange = html.range(of: startTag) else { return nil }
        let subHtml = html[startRange.upperBound...]
        guard let endRange = subHtml.range(of: endTag) else { return nil }
        return String(subHtml[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeHTMLEntities(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return text }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        if let attributedString = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributedString.string
        }
        return text
    }
}

struct GoogleSearchResponse: Codable {
    let items: [GoogleSearchItem]?
}

struct GoogleSearchItem: Codable {
    let title: String?
    let link: String?
    let snippet: String?
    let image: GoogleImageDetails?
}

struct GoogleImageDetails: Codable {
    let contextLink: String?
}
