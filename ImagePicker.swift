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
    
    // ✅ Optional Callback to bypass auto-save (for Editing)
    var onCameraCapture: ((UIImage) -> Void)? = nil
    
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
                    // カメラで撮影した場合
                    
                    if let onCapture = parent.onCameraCapture {
                        // ✅ Bypass Saving -> Callback for Editor
                        DispatchQueue.main.async {
                            onCapture(image)
                        }
                    } else {
                        // Default: Save to PLALOG Album
                        PhotoSaver.shared.saveImageToCustomAlbum(image) { id in
                            DispatchQueue.main.async {
                                self.parent.selectedAssetID?.wrappedValue = id
                            }
                        }
                    }
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
