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
    var imageURL: URL?
    var price: String = ""
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
