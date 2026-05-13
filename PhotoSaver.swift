
import UIKit
import Photos

class PhotoSaver {
    static let shared = PhotoSaver()
    private let albumName = "PLALOG"
    
    func saveImageToCustomAlbum(_ image: UIImage, completion: @escaping (String?) -> Void) {
        // 1. Check/Fetch Album
        if let album = fetchAssetCollection(for: albumName) {
            saveImage(image, to: album, completion: completion)
        } else {
            // 2. Create if missing
            createAlbum(name: albumName) { [weak self] success in
                guard let self = self else { completion(nil); return }
                if success, let album = self.fetchAssetCollection(for: self.albumName) {
                    self.saveImage(image, to: album, completion: completion)
                } else {
                    // Fallback
                    self.saveImageToLibraryAndGetIDFallback(image, completion: completion)
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
    
    private func saveImage(_ image: UIImage, to album: PHAssetCollection, completion: @escaping (String?) -> Void) {
        var placeholder: PHObjectPlaceholder?
        
        PHPhotoLibrary.shared().performChanges({
            let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = createAssetRequest.placeholderForCreatedAsset
            
            guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album),
                  let assetPlaceholder = placeholder else { return }
            
            let fastEnumeration = NSArray(object: assetPlaceholder)
            albumChangeRequest.addAssets(fastEnumeration)
            
        }, completionHandler: { success, error in
            if success, let id = placeholder?.localIdentifier {
                completion(id)
            } else {
                print("Error saving to album: \(String(describing: error))")
                self.saveImageToLibraryAndGetIDFallback(image, completion: completion)
            }
        })
    }
    
    private func saveImageToLibraryAndGetIDFallback(_ image: UIImage, completion: @escaping (String?) -> Void) {
        var placeholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
            placeholder = request.placeholderForCreatedAsset
        } completionHandler: { success, _ in
            if success, let id = placeholder?.localIdentifier {
                completion(id)
            } else {
                completion(nil)
            }
        }
    }
}
