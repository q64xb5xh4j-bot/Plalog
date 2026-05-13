import Foundation
import SwiftUI

class KeyValueSyncManager {
    static let shared = KeyValueSyncManager()
    
    private let store = NSUbiquitousKeyValueStore.default
    private let defaults = UserDefaults.standard
    
    // Keys to sync
    private let syncKeys = ["pilotName"]
    
    private init() {}
    
    func start() {
        // Register for iCloud updates
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didChangeExternally),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        
        // Initial Sync (Pull from iCloud if available)
        store.synchronize()
    }
    
    @objc private func didChangeExternally(notification: Notification) {
        // Get changes
        guard let userInfo = notification.userInfo,
              let reasonForChange = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }
        
        // Loop through keys and update local UserDefaults
        // If a specific key changed, update it.
        // For simplicity, we just check all our tracked keys.
        
        // Note: In a real robust app, we might check timestamps or use conflict resolution.
        // Here we assume "Cloud is Truth" when notification arrives.
        
        for key in syncKeys {
            if let cloudValue = store.string(forKey: key) {
                // Update Local
                DispatchQueue.main.async {
                    self.defaults.set(cloudValue, forKey: key)
                }
            }
        }
    }
    
    func push(key: String, value: String) {
        store.set(value, forKey: key)
        store.synchronize()
    }
}
