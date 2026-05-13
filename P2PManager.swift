import Foundation
import MultipeerConnectivity
import SwiftUI
import Combine
import Photos // ✅ Fix: Import Photos for PHAsset

class P2PManager: NSObject, ObservableObject {
    static let shared = P2PManager()
    
    private let serviceType = "pralog-sync"
    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    
    // MCSession components
    private var session: MCSession!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
    
    @Published var availablePeers: [MCPeerID] = []
    @Published var connectedPeers: [MCPeerID] = []
    @Published var isScanning = false
    @Published var statusMessage = "待機中..."
    @Published var isSyncing = false
    @Published var isCompleted = false
    
    var onDataReceived: ((Data) -> Void)?
    
    // Security: Manual Invitation Handling
    @Published var isPresentingInvitation = false
    @Published var requestingPeerName = ""
    private var pendingInvitationHandler: ((Bool, MCSession?) -> Void)?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        serviceAdvertiser.delegate = self
        
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        serviceBrowser.delegate = self
    }
    
    func start() {
        isScanning = true
        statusMessage = "デバイスを探しています..."
        serviceAdvertiser.startAdvertisingPeer()
        serviceBrowser.startBrowsingForPeers()
    }
    
    func stop() {
        isScanning = false
        statusMessage = "停止"
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
        session.disconnect()
        availablePeers.removeAll()
        connectedPeers.removeAll()
    }
    
    func invite(peer: MCPeerID) {
        serviceBrowser.invitePeer(peer, to: session, withContext: nil, timeout: 30)
        statusMessage = "\(peer.displayName)に接続要求を送信中..."
    }
    
    func acceptInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(true, session)
        statusMessage = "接続を承認しました"
        resetInvitationState()
    }
    
    func rejectInvitation() {
        guard let handler = pendingInvitationHandler else { return }
        handler(false, nil)
        statusMessage = "接続を拒否しました"
        resetInvitationState()
    }
    
    private func resetInvitationState() {
        pendingInvitationHandler = nil
        isPresentingInvitation = false
        requestingPeerName = ""
    }
    
    func send(data: Data) {
        guard !session.connectedPeers.isEmpty else {
            statusMessage = "接続されているデバイスがありません"
            return
        }
        
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            statusMessage = "データを送信しました"
        } catch {
            statusMessage = "送信エラー: \(error.localizedDescription)"
        }
    }
    func sendResource(filename: String, completion: @escaping (Error?) -> Void) {
        guard !session.connectedPeers.isEmpty else {
            completion(NSError(domain: "Pralog", code: -1, userInfo: [NSLocalizedDescriptionKey: "No peers connected"]))
            return
        }
        
        let fileManager = FileManager.default
        
        // 1. Check if it is a PHAsset reference (unchanged logic)
        if filename.hasPrefix("asset://") {
            // ... (Asset handling logic unchanged, omitting for brevity in replacement if possible, but replace_file_content requires exact context match. 
            // Wait, I need to see if I can just wrap the validation around the file access part at line 145)
            // Let's replace the whole method to be safe and insert validation at the top for file paths.
             let assetID = String(filename.dropFirst(8))
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil)
            guard let asset = assets.firstObject else {
                completion(NSError(domain: "Pralog", code: -1, userInfo: [NSLocalizedDescriptionKey: "Asset not found: \(assetID)"]))
                return
            }
            
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .default, options: options) { image, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    completion(error)
                    return
                }
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return // Wait for high quality
                }
                
                guard let img = image, let data = img.jpegData(compressionQuality: 0.8) else {
                    return
                }
                
                let tempName = "temp_" + UUID().uuidString + ".jpg"
                let tempURL = fileManager.temporaryDirectory.appendingPathComponent(tempName)
                
                do {
                    try data.write(to: tempURL)
                    // Sanitize the asset ID for the filename just in case, though it comes from system
                    let cleanID = assetID.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "..", with: "")
                    let safeName = "asset_" + cleanID + ".jpg"
                    
                    let dispatchGroup = DispatchGroup()
                    var lastError: Error?
                    
                    for peer in self.session.connectedPeers {
                        dispatchGroup.enter()
                        self.session.sendResource(at: tempURL, withName: safeName, toPeer: peer) { error in
                            if let error = error { lastError = error }
                            dispatchGroup.leave()
                        }
                    }
                    dispatchGroup.notify(queue: .main) {
                        try? fileManager.removeItem(at: tempURL)
                        completion(lastError)
                    }
                } catch {
                    completion(error)
                }
            }
            return
        }
        
        // REMOVED: Recursive asset_ logic caused "Asset not found" on devices holding only the file.
        // Files starting with "asset_" should be treated as regular files by the logic below.
        
        // --- PATH TRAVERSAL FIX START ---
        // Verify filename is just a filename, not a path
        // RELAXED FIX: Sanitize to lastPathComponent and serve that file.
        // This handles cases where older versions or data might request a full path.
        let sanitized = URL(fileURLWithPath: filename).lastPathComponent
        
        // (Removed strict equality check to allow path requests to be served as flat files)
        
        // Verify extension whitelist
        let ext = (sanitized as NSString).pathExtension.lowercased()
        let allowedExtensions = ["jpg", "jpeg", "png", "csv", "json"]
        guard allowedExtensions.contains(ext) else {
            completion(NSError(domain: "Security", code: 403, userInfo: [NSLocalizedDescriptionKey: "File type not allowed."]))
            return
        }
        
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completion(NSError(domain: "Pralog", code: -1, userInfo: [NSLocalizedDescriptionKey: "Doc dir not found"]))
            return
        }
        let fileURL = documentsURL.appendingPathComponent(sanitized).standardizedFileURL
        
        // Final sandbox check: ensure it starts with documentsURL
        // (standardizedFileURL resolves symlinks and ..)
        guard fileURL.absoluteString.hasPrefix(documentsURL.standardizedFileURL.absoluteString) else {
             completion(NSError(domain: "Security", code: 403, userInfo: [NSLocalizedDescriptionKey: "Access denied."]))
             return
        }
        // --- PATH TRAVERSAL FIX END ---
        
        if fileManager.fileExists(atPath: fileURL.path) {
             let dispatchGroup = DispatchGroup()
             var lastError: Error?
             for peer in session.connectedPeers {
                 dispatchGroup.enter()
                 session.sendResource(at: fileURL, withName: sanitized, toPeer: peer) { error in
                     if let error = error { lastError = error }
                     dispatchGroup.leave()
                 }
             }
             dispatchGroup.notify(queue: .main) { completion(lastError) }
        } else {
             // File not found
             completion(NSError(domain: "Pralog", code: -1, userInfo: [NSLocalizedDescriptionKey: "File not found: \(sanitized)"]))
        }
    }
}

// MARK: - MCSessionDelegate
extension P2PManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                if !self.connectedPeers.contains(peerID) {
                    self.connectedPeers.append(peerID)
                }
                self.statusMessage = "\(peerID.displayName)と接続しました"
                // 双方向リンク: 接続時に自動で同期を開始したければここで行うが、今回は手動
            case .connecting:
                self.statusMessage = "\(peerID.displayName)と接続中..."
            case .notConnected:
                if let index = self.connectedPeers.firstIndex(of: peerID) {
                    self.connectedPeers.remove(at: index)
                }
                self.statusMessage = "接続が切れました"
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Handle received data
        print("Received data from \(peerID.displayName)")
        DispatchQueue.main.async {
            self.onDataReceived?(data)
            // statusMessage update handled by callback
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        DispatchQueue.main.async {
            self.statusMessage = "画像を受信中: \(resourceName)"
        }
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        guard let localURL = localURL, error == nil else { return }
        
        // --- PATH TRAVERSAL FIX START ---
        // 1. Sanitize filename
        let sanitizedName = URL(fileURLWithPath: resourceName).lastPathComponent
        
        // 2. Validate extension
        let ext = (sanitizedName as NSString).pathExtension.lowercased()
        let allowedExtensions = ["jpg", "jpeg", "png", "csv", "json"]
        guard allowedExtensions.contains(ext) else {
             // Reject unknown file types
             return
        }
        
        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        // 3. Construct and Verify URL
        let destinationURL = documentsURL.appendingPathComponent(sanitizedName).standardizedFileURL
        
        guard destinationURL.absoluteString.hasPrefix(documentsURL.standardizedFileURL.absoluteString) else {
             // Attempted path traversal
             return
        }
        // --- PATH TRAVERSAL FIX END ---
        
        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: localURL, to: destinationURL)
            DispatchQueue.main.async {
                self.statusMessage = "画像を保存しました: \(sanitizedName)"
            }
        } catch {
            print("Save Resource Error: \(error)")
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate
extension P2PManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        DispatchQueue.main.async {
            self.pendingInvitationHandler = invitationHandler
            self.requestingPeerName = peerID.displayName
            self.isPresentingInvitation = true
            
            // Auto-reject if already scanning/syncing to prevent interruption? 
            // For now, let user decide.
            LocalHaptics.warning()
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate
extension P2PManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async {
            // 同名のデバイスが既にある場合は削除して入れ替える (再起動時のID変更対応)
            self.availablePeers.removeAll { $0.displayName == peerID.displayName }
            self.availablePeers.append(peerID)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            if let index = self.availablePeers.firstIndex(of: peerID) {
                self.availablePeers.remove(at: index)
            }
        }
    }
}
