// ImagePicker.swift V3
// 1. ファイル冒頭のバージョン管理ルールに基づき更新 (V2 -> V3)
// 2. 変更点: 撮影した写真を自動的に「PLALOG」アルバムに保存する機能を追加
// 3. 全文差し替えルール適用

import SwiftUI
import UIKit
import Photos

// MARK: - Image Picker
// カメラとフォトライブラリを扱うための部品
// V3: カメラ撮影時、自動的に「PLALOG」アルバムを作成・保存する機能を追加

struct ImagePicker: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Binding var selectedImage: UIImage?
    
    // 写真アプリ上のIDを受け渡すためのBinding
    var selectedAssetID: Binding<String?>? = nil
    
    @Environment(\.presentationMode) private var presentationMode

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let imagePicker = UIImagePickerController()
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        imagePicker.delegate = context.coordinator
        return imagePicker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // 更新不要
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var parent: ImagePicker
        private let albumName = "PLALOG" // ✅ 保存先のアルバム名

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                
                if parent.sourceType == .photoLibrary {
                    // アルバムから選んだ場合: IDをそのまま取得
                    if let asset = info[.phAsset] as? PHAsset {
                        let id = asset.localIdentifier
                        DispatchQueue.main.async {
                            self.parent.selectedAssetID?.wrappedValue = id
                        }
                    }
                } else if parent.sourceType == .camera {
                    // カメラで撮影した場合: 「PLALOG」アルバムに保存してIDを取得
                    saveImageToCustomAlbum(image)
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        // MARK: - Album Logic
        
        private func saveImageToCustomAlbum(_ image: UIImage) {
            // 1. アルバムの存在確認・取得
            if let album = fetchAssetCollection(for: albumName) {
                saveImage(image, to: album)
            } else {
                // 2. なければ作成してから保存
                createAlbum(name: albumName) { [weak self] success in
                    if success, let album = self?.fetchAssetCollection(for: self?.albumName ?? "") {
                        self?.saveImage(image, to: album)
                    } else {
                        // 失敗時は通常のカメラロール保存にフォールバック
                        self?.saveImageToLibraryAndGetIDFallback(image)
                    }
                }
            }
        }
        
        private func fetchAssetCollection(for title: String) -> PHAssetCollection? {
            let fetchOptions = PHFetchOptions()
            fetchOptions.predicate = NSPredicate(format: "title = %@", title)
            let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
            return collection.firstObject
        }
        
        private func createAlbum(name: String, completion: @escaping (Bool) -> Void) {
            PHPhotoLibrary.shared().performChanges({
                PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
            }, completionHandler: { success, error in
                if !success { print("Error creating album: \(String(describing: error))") }
                completion(success)
            })
        }
        
        private func saveImage(_ image: UIImage, to album: PHAssetCollection) {
            var placeholder: PHObjectPlaceholder?
            
            PHPhotoLibrary.shared().performChanges({
                // 1. 画像アセットの作成リクエスト
                let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                placeholder = createAssetRequest.placeholderForCreatedAsset
                
                // 2. アルバムへの追加リクエスト
                guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                      let assetPlaceholder = placeholder else { return }
                
                // 列挙型で渡す必要があるため配列にラップ
                let fastEnumeration = NSArray(object: assetPlaceholder)
                albumChangeRequest.addAssets(fastEnumeration)
                
            }, completionHandler: { success, error in
                if success, let id = placeholder?.localIdentifier {
                    DispatchQueue.main.async {
                        self.parent.selectedAssetID?.wrappedValue = id
                    }
                } else {
                    print("Error saving to album: \(String(describing: error))")
                    // 失敗したら通常保存を試みる
                    self.saveImageToLibraryAndGetIDFallback(image)
                }
            })
        }
        
        private func saveImageToLibraryAndGetIDFallback(_ image: UIImage) {
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                placeholder = request.placeholderForCreatedAsset
            } completionHandler: { success, _ in
                if success, let id = placeholder?.localIdentifier {
                    DispatchQueue.main.async {
                        self.parent.selectedAssetID?.wrappedValue = id
                    }
                }
            }
        }
    }
}
