// YahooShoppingClient.swift V9
// 1. バージョン管理ルールに基づき更新 (V8 -> V9)
// 2. 修正点: GOD MODE対応
//    - UserDefaults("custom_client_id")を確認し、存在すればそのIDを優先使用する
//    - これによりAPI制限回避(GOD MODE)を実現
// 3. 全文差し替えルール適用

import Foundation

// MARK: - Yahoo Shopping API Client (V9: GOD MODE Support)
// URLを壊さないよう、フォルダ名「/i/g/」を「/i/l/」に置換してLサイズ画像を取得

struct YahooSearchResult: Codable {
    let hits: [YahooItem]
}

struct YahooItem: Codable, Identifiable {
    let code: String
    let name: String
    let image: YahooImage?
    let maker: YahooMaker?
    let brand: YahooBrand?
    let janCode: String?
    let price: Int?
    
    var id: String { code }
    var title: String { name }
    
    var priceLabel: String {
        if let p = price { return "¥\(p)" }
        return ""
    }
    
    // 安全に「Lサイズ」の画像URLに変換
    var imageURL: URL? {
        guard let urlString = image?.medium else { return nil }
        
        // Yahoo!の画像URLルール: /i/g/ (中) を /i/l/ (大) に変えると高解像度版になる
        let highResUrlString = urlString.replacingOccurrences(of: "/i/g/", with: "/i/l/")
        
        return URL(string: highResUrlString)
    }
}

struct YahooImage: Codable {
    let medium: String?
}

struct YahooMaker: Codable {
    let name: String?
}

struct YahooBrand: Codable {
    let name: String?
}

enum YahooAPIError: Error {
    case invalidURL
    case serverError(statusCode: Int)
    case decodeError(String)
}

class YahooShoppingClient {
    static let shared = YahooShoppingClient()
    private init() {}
    
    // デフォルトID
    private let defaultAppID = "dj00aiZpPWdXc3hOMmhqUldDVyZzPWNvbnN1bWVyc2VjcmV0Jng9NTE-"
    
    // ✅ GOD MODE: Custom ID Retrieval
    private var appID: String {
        let custom = UserDefaults.standard.string(forKey: "custom_client_id")
        if let custom = custom, !custom.isEmpty {
            return custom
        }
        return defaultAppID
    }
    
    private let baseURL = "https://shopping.yahooapis.jp/ShoppingWebService/V3/itemSearch"
    
    func search(query: String) async throws -> [YahooItem] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw YahooAPIError.invalidURL
        }
        // appIDプロパティ(computed var)を使用することで動的にIDを切り替え
        let urlString = "\(baseURL)?appid=\(appID)&query=\(encodedQuery)&results=20&image_size=600"
        guard let url = URL(string: urlString) else { throw YahooAPIError.invalidURL }
        return try await performRequest(url: url)
    }
    
    func searchByJAN(_ jan: String) async throws -> YahooItem? {
        let urlString = "\(baseURL)?appid=\(appID)&jan_code=\(jan)&results=1&image_size=600"
        guard let url = URL(string: urlString) else { return nil }
        return try await performRequest(url: url).first
    }
    
    private func performRequest(url: URL) async throws -> [YahooItem] {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            throw YahooAPIError.serverError(statusCode: httpResponse.statusCode)
        }
        let result = try JSONDecoder().decode(YahooSearchResult.self, from: data)
        return result.hits
    }
}
