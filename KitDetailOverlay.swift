// KitDetailOverlay.swift V40
// 1. バージョン管理ルールに基づき更新 (V39 -> V40)
// 2. 修正点:
//    - デバイス分岐用のラッパーとして再構築
//    - 共通のサブビュー(DetailWebImageSearchModal)をここに定義
// 3. 全文差し替え・分割送付ルール適用

import SwiftUI
import SwiftData
import Combine
import Photos

// MARK: - Main Wrapper (分岐ポイント)
struct KitDetailOverlay: View {
    @Binding var kit: Kit?
    
    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            KitDetailOverlay_iPad(kit: $kit)
        } else {
            KitDetailOverlay_iPhone(kit: $kit)
        }
    }
}

// MARK: - Shared Helper Components (共通コンポーネント)

struct DetailWebImageSearchModal: View {
    let kit: Kit
    @Binding var isPresented: Bool
    let initialSearchText: String
    
    var body: some View {
        WebImageSearchModal(
            kit: kit,
            isPresented: $isPresented,
            initialQuery: initialSearchText,
            onImageSelected: { resultString in
                Task {
                    var finalData: Data? = nil
                    
                    if resultString.hasPrefix("asset://") {
                         let assetID = String(resultString.dropFirst(8))
                         finalData = await fetchAssetData(localIdentifier: assetID)
                    } else {
                         // Local file
                         if let url = ImageLinker.resolve(urlString: resultString) {
                             finalData = try? Data(contentsOf: url)
                         }
                    }
                    
                    if let data = finalData {
                        await MainActor.run {
                            // Cleanup old file reference if needed, but since we switch to Data, it's fine.
                            ImageLinker.deleteLocalImageFile(named: kit.imageURLString)
                            
                            kit.imageData = data
                            kit.imageURLString = nil // Use CloudKit Data
                            kit.updatedDate = Date()
                        }
                    }
                }
            }
        )
    }
    
    // Helper Copy
    private func fetchAssetData(localIdentifier: String) async -> Data? {
        return await withCheckedContinuation { continuation in
             let options = PHImageRequestOptions()
             options.isSynchronous = false
             options.deliveryMode = .highQualityFormat
             options.isNetworkAccessAllowed = true
             
             let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
             if let asset = assets.firstObject {
                 PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                     continuation.resume(returning: data)
                 }
             } else {
                 continuation.resume(returning: nil)
             }
        }
    }
}
