//
//  DiscoveryManager.swift
//  Plalog
//
//  Created for API-Free Architecture V1.
//

import Foundation
import CloudKit
import SwiftUI
import SwiftData
import Combine

struct DiscoveryRecord: Identifiable {
    let id: String // JAN Code
    let title: String
    let maker: String
    let scale: String
    let series: String
    let grade: String
    let discovererName: String
    let discoveredDate: Date
    let imageAsset: CKAsset?
    let isLocked: Bool
    let voteCount: Int
}

@MainActor
class DiscoveryManager: ObservableObject {
    static let shared = DiscoveryManager()
    
    // Explicitly use the container ID from entitlements to avoid mismatch
    private let container = CKContainer(identifier: "iCloud.icloud.jp.plalog.Plalog")
    private lazy var publicDB = container.publicCloudDatabase
    
    @Published var topDiscoverers: [(name: String, count: Int)] = []
    
    // MARK: - Check Discovery Status
    func checkDiscovery(jan: String) async -> DiscoveryRecord? {
        // Debug: Check Account Status
        if let status = try? await container.accountStatus() {
            print("🕵️ [DiscoveryManager] iCloud Account Status: \(status.rawValue)")
        }

        let recordID = CKRecord.ID(recordName: jan)
        print("🕵️ [DiscoveryManager] Checking existence for JAN: \(jan)")
        
        do {
            let record = try await publicDB.record(for: recordID)
            print("✅ [DiscoveryManager] Found existing record: \(record.recordID.recordName)")
            return DiscoveryRecord(
                id: jan,
                title: (record["title"] as? String) ?? "Unknown",
                maker: (record["maker"] as? String) ?? "Unknown",
                scale: (record["scale"] as? String) ?? "",
                series: (record["series"] as? String) ?? "",
                grade: (record["grade"] as? String) ?? "",
                discovererName: (record["discovererName"] as? String) ?? "Anonymous",
                discoveredDate: (record["discoveredDate"] as? Date) ?? Date(),
                imageAsset: record["imageAsset"] as? CKAsset,
                isLocked: (record["isLocked"] as? Int) == 1,
                voteCount: (record["voteCount"] as? Int) ?? 0
            )
        } catch {
            if let ckError = error as? CKError {
                if ckError.code == .unknownItem {
                     print("🆕 [DiscoveryManager] Item not found (New Discovery): \(jan)")
                     return nil
                }
                print("❌ [DiscoveryManager] CKError during check: \(ckError.code.rawValue) - \(ckError.localizedDescription)")
            } else {
                print("❌ [DiscoveryManager] Unknown Error during check: \(error)")
            }
            return nil
        }
    }
    
    // MARK: - Check Discovery by Title
    func checkDiscoveryByTitle(title: String) async -> DiscoveryRecord? {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return nil }
        
        print("🔍 [DiscoveryManager] Checking discovery by title: \(cleanTitle)")
        
        // Fetch recent records and filter client-side (same strategy as searchDiscoveries)
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "DiscoveryItem", predicate: predicate)
        query.sortDescriptors = []
        
        do {
            let (results, _) = try await publicDB.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100)
            
            // Find best match by title similarity
            for (_, result) in results {
                guard let record = try? result.get() else { continue }
                let recordTitle = (record["title"] as? String) ?? ""
                
                // Exact match or close match
                if recordTitle.lowercased() == cleanTitle.lowercased() {
                    print("✅ [DiscoveryManager] Found exact title match: \(recordTitle)")
                    return DiscoveryRecord(
                        id: (record["janCode"] as? String) ?? record.recordID.recordName,
                        title: recordTitle,
                        maker: (record["maker"] as? String) ?? "Unknown",
                        scale: (record["scale"] as? String) ?? "",
                        series: (record["series"] as? String) ?? "",
                        grade: (record["grade"] as? String) ?? "",
                        discovererName: (record["discovererName"] as? String) ?? "Anonymous",
                        discoveredDate: (record["discoveredDate"] as? Date) ?? Date(),
                        imageAsset: record["imageAsset"] as? CKAsset,
                        isLocked: (record["isLocked"] as? Int) == 1,
                        voteCount: (record["voteCount"] as? Int) ?? 0
                    )
                }
            }
            
            print("📭 [DiscoveryManager] No match found for title: \(cleanTitle)")
            return nil
            
        } catch {
            print("❌ [DiscoveryManager] Title check failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Local SwiftData Search (Fast, No CloudKit Errors)
    // MARK: - Local SwiftData Search (Fast, No CloudKit Errors)
    
    // NEW: Fetch ALL items for downstream token matching (CSVDataManager)
    func fetchAllCache(modelContext: ModelContext) -> [DiscoveryCache] {
        do {
            let descriptor = FetchDescriptor<DiscoveryCache>()
            return try modelContext.fetch(descriptor)
        } catch {
            print("❌ [DiscoveryManager] Fetch all failed: \(error)")
            return []
        }
    }

    // findAll: true -> Returns ALL matches (for CSV integration)
    // findAll: false -> Returns just the first/best match (legacy behavior)
    func searchLocalByTitle(title: String, modelContext: ModelContext, findAll: Bool = false) -> [DiscoveryCache] {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanTitle.isEmpty else { return [] }
        
        do {
            let descriptor = FetchDescriptor<DiscoveryCache>()
            let allCaches = try modelContext.fetch(descriptor)
            
            // Filter matches
            let matches = allCaches.filter { item in
                let itemTitle = item.title.lowercased()
                return itemTitle == cleanTitle || itemTitle.contains(cleanTitle) || cleanTitle.contains(itemTitle)
            }
            
            if !matches.isEmpty {
                 print("✅ [DiscoveryManager] Local cache hit: found \(matches.count) items for '\(cleanTitle)'")
                 if findAll {
                     return matches
                 } else {
                     // Return best match (exact > partial)
                     if let best = matches.first(where: { $0.title.lowercased() == cleanTitle }) {
                         return [best]
                     }
                     if let first = matches.first {
                         return [first]
                     }
                     return []
                 }
            }
            
            print("📭 [DiscoveryManager] Local cache miss for: \(cleanTitle)")
            // DEBUG: Print what WE DO HAVE
            for item in allCaches {
                print("   💾 Cache content: '\(item.title)' (JAN: \(item.janCode))")
            }
            return []
        } catch {
            print("❌ [DiscoveryManager] Local search failed: \(error)")
            return []
        }
    }
    
    // Convenience overload for legacy single-item return (Optional)
    func searchLocalByTitle(title: String, modelContext: ModelContext) -> DiscoveryCache? {
        return searchLocalByTitle(title: title, modelContext: modelContext, findAll: false).first
    }
    
    // MARK: - Local SwiftData Search by JAN (Exact Match)
    func searchLocalByJAN(jan: String, modelContext: ModelContext) -> DiscoveryCache? {
        let cleanJan = jan.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanJan.isEmpty else { return nil }
        
        do {
            // Predicate based lookup is most efficient
            let descriptor = FetchDescriptor<DiscoveryCache>(
                predicate: #Predicate { $0.janCode == cleanJan }
            )
            let results = try modelContext.fetch(descriptor)
            
            if let hit = results.first {
                print("✅ [DiscoveryManager] Local JAN cache hit: \(cleanJan) -> '\(hit.title)'")
                return hit
            } else {
                print("📭 [DiscoveryManager] Local JAN cache miss for: \(cleanJan)")
                return nil
            }
        } catch {
            print("❌ [DiscoveryManager] Local JAN search failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Sync from CloudKit to Local Cache (Pagination Support)
    func syncFromCloudKit(modelContext: ModelContext) async -> Int {
        print("🔄 [DiscoveryManager] Starting CloudKit sync (Full Fetch)...")
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "DiscoveryItem", predicate: predicate)
        query.sortDescriptors = []
        
        var syncCount = 0
        var cursor: CKQueryOperation.Cursor? = nil
        var isFetching = true
        
        // Loop until all pages are fetched
        while isFetching {
            do {
                let (results, nextCursor) = try await fetchBatch(query: query, cursor: cursor)
                
                // Process batch
                for (_, result) in results {
                    guard let record = try? result.get() else { continue }
                    processSyncedRecord(record, modelContext: modelContext)
                    syncCount += 1
                }
                
                // Prepare for next page
                cursor = nextCursor
                if cursor == nil {
                    isFetching = false
                    print("✅ [DiscoveryManager] Reached end of CloudKit results.")
                } else {
                    print("➡️ [DiscoveryManager] Fetching next page... (Total so far: \(syncCount))")
                }
                
            } catch {
                print("❌ [DiscoveryManager] CloudKit sync failed at count \(syncCount): \(error)")
                return syncCount // Return what we have so far
            }
        }
        
        try? modelContext.save()
        print("✅ [DiscoveryManager] Full Sync Completed! Total items: \(syncCount)")
        return syncCount
    }
    
    // Helper: Fetch a single batch
    private func fetchBatch(query: CKQuery, cursor: CKQueryOperation.Cursor?) async throws -> ([(CKRecord.ID, Result<CKRecord, Error>)], CKQueryOperation.Cursor?) {
        if let cursor = cursor {
            return try await publicDB.records(continuingMatchFrom: cursor, desiredKeys: nil, resultsLimit: 200)
        } else {
            return try await publicDB.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 200)
        }
    }
    
    // Helper: Process individual record
    private func processSyncedRecord(_ record: CKRecord, modelContext: ModelContext) {
        let janCode = (record["janCode"] as? String) ?? record.recordID.recordName
        
        // Check if already in cache
        let descriptor = FetchDescriptor<DiscoveryCache>(
            predicate: #Predicate { $0.janCode == janCode }
        )
        let existing = try? modelContext.fetch(descriptor)
        
        if let existingCache = existing?.first {
            // Update existing
            existingCache.title = (record["title"] as? String) ?? existingCache.title
            existingCache.maker = (record["maker"] as? String) ?? existingCache.maker
            existingCache.scale = (record["scale"] as? String) ?? existingCache.scale
            existingCache.series = (record["series"] as? String) ?? existingCache.series
            existingCache.grade = (record["grade"] as? String) ?? existingCache.grade
            existingCache.discovererName = (record["discovererName"] as? String) ?? existingCache.discovererName
            existingCache.discoveredDate = (record["discoveredDate"] as? Date) ?? existingCache.discoveredDate
            existingCache.isLocked = (record["isLocked"] as? Int) == 1
            existingCache.voteCount = (record["voteCount"] as? Int) ?? existingCache.voteCount
            existingCache.lastSyncDate = Date()
        } else {
            // Create new cache entry
            let newCache = DiscoveryCache(
                janCode: janCode,
                title: (record["title"] as? String) ?? "Unknown",
                maker: (record["maker"] as? String) ?? "Unknown",
                scale: (record["scale"] as? String) ?? "",
                series: (record["series"] as? String) ?? "",
                grade: (record["grade"] as? String) ?? "",
                discovererName: (record["discovererName"] as? String) ?? "Anonymous",
                discoveredDate: (record["discoveredDate"] as? Date) ?? Date(),
                isLocked: (record["isLocked"] as? Int) == 1,
                voteCount: (record["voteCount"] as? Int) ?? 0,
                lastSyncDate: Date()
            )
            modelContext.insert(newCache)
        }
    }
    
    // MARK: - Search
    func searchDiscoveries(keyword: String) async -> [DiscoveryRecord] {
        // Sanitize
        let cleanKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanKeyword.isEmpty else { return [] }
        
        print("🔍 [DiscoveryManager] Fetching recent items for client-side filtering (Keyword: \(cleanKeyword))")
        
        // Fallback Strategy:
        // CloudKit text search/sort often fails without specific indexing.
        // We fetch arbitrary 100 items (Schema limitation) and filter them client-side.
        // Removed sorting to strictly avoid 'not queryable' errors.
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: "DiscoveryItem", predicate: predicate)
        query.sortDescriptors = []
        
        do {
            let (results, _) = try await publicDB.records(matching: query, inZoneWith: nil, desiredKeys: nil, resultsLimit: 100)
            let records = results.compactMap { _, result -> DiscoveryRecord? in
                guard let record = try? result.get() else { return nil }
                 return DiscoveryRecord(
                    id: (record["janCode"] as? String) ?? record.recordID.recordName,
                    title: (record["title"] as? String) ?? "Unknown",
                    maker: (record["maker"] as? String) ?? "Unknown",
                    scale: (record["scale"] as? String) ?? "",
                    series: (record["series"] as? String) ?? "",
                    grade: (record["grade"] as? String) ?? "",
                    discovererName: (record["discovererName"] as? String) ?? "Anonymous",
                    discoveredDate: (record["discoveredDate"] as? Date) ?? Date(),
                    imageAsset: record["imageAsset"] as? CKAsset,
                    isLocked: (record["isLocked"] as? Int) == 1,
                    voteCount: (record["voteCount"] as? Int) ?? 0
                )
            }
            
            // Client-Side Filter
            // Split keyword into tokens
            let tokens = cleanKeyword.components(separatedBy: .whitespacesAndNewlines).filter { $0.count >= 2 }
            guard !tokens.isEmpty else { return [] }
            
            // Return items where Title contains ANY significant token
            let matches = records.filter { rec in
                let title = rec.title.lowercased()
                return tokens.contains { token in 
                    title.contains(token.lowercased()) 
                }
            }
            
            print("✅ [DiscoveryManager] Found \(matches.count) matches via client-side filter.")
            return matches
            
        } catch {
            print("❌ [DiscoveryManager] Search failed: \(error)")
            return []
        }
    }
    
    // MARK: - Register New Discovery
    func registerDiscovery(jan: String, title: String, maker: String, scale: String, series: String, grade: String, imageData: Data?) async throws {
         print("🚀 [DiscoveryManager] Attempting to register: \(jan)")
        
        guard !jan.isEmpty else {
            print("⚠️ [DiscoveryManager] JAN is empty, skipping discovery registration.")
            return
        }
        
        // Use JAN as ID
        let recordID = CKRecord.ID(recordName: jan)
        let record = CKRecord(recordType: "DiscoveryItem", recordID: recordID)
        
        record["janCode"] = jan
        record["title"] = title
        record["maker"] = maker
        record["scale"] = scale
        record["series"] = series
        record["grade"] = grade
        record["discovererName"] = UserDefaults.standard.string(forKey: "pilotName") ?? "COMMANDER"
        record["discoveredDate"] = Date()
        record["voteCount"] = 1 // Self-vote
        
        if let data = imageData {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
            try? data.write(to: tempURL)
            record["imageAsset"] = CKAsset(fileURL: tempURL)
        }
        
        do {
            try await publicDB.save(record)
            print("✅ [DiscoveryManager] Successfully registered: \(jan)")
        } catch {
            if let ckError = error as? CKError {
                if ckError.code == .serverRecordChanged {
                    print("⚠️ [DiscoveryManager] Already exists (Conflict): \(jan)")
                    // Likely someone else registered it. Try to update?
                    // For now, silent ignore or we can try calling updateDiscovery?
                    return
                }
                print("❌ [DiscoveryManager] Save Failed: \(ckError.code.rawValue) - \(ckError.localizedDescription)")
            } else {
                print("❌ [DiscoveryManager] Save Failed (Unknown): \(error)")
            }
            throw error
        }
    }
    
    // MARK: - Update Discovery (Correction)
    func updateDiscovery(jan: String, title: String, maker: String, scale: String, grade: String) async throws {
        print("🛠️ [DiscoveryManager] Updating discovery for: \(jan)")
        let recordID = CKRecord.ID(recordName: jan)
        
        do {
            let record = try await publicDB.record(for: recordID)
            
            // ✅ Lock Check: Prevent editing if verified
            if let isLocked = record["isLocked"] as? Int, isLocked == 1 {
                print("🔒 [DiscoveryManager] Validated Record is Locked. Edit rejected.")
                throw CKError(.serverRecordChanged) // Or custom error
            }

            // ✅ Vandalism Protection & Typo Fix Strategy
            // 1. Allow overwriting non-empty values (to fix typos like "Gundm" -> "Gundam")
            // 2. Prevent overwriting with empty/Unknown (to prevent data loss)
            // 3. Backup old values (to allow revert if "Gundam" -> "Gundm" happens)
            
            var hasChanges = false
            
            if !title.isEmpty, (record["title"] as? String) != title {
                record["backup_title"] = record["title"] // Save history
                record["title"] = title
                hasChanges = true
            }
            
            // Maker Logic: Allow update if new is NOT Unknown, OR if old IS Unknown (filling blank)
            if !maker.isEmpty, maker != "Unknown" {
                if (record["maker"] as? String) != maker {
                    record["backup_maker"] = record["maker"]
                    record["maker"] = maker
                    hasChanges = true
                }
            }
            
            if !scale.isEmpty, (record["scale"] as? String) != scale {
                record["backup_scale"] = record["scale"]
                record["scale"] = scale
                hasChanges = true
            }
            
            if !grade.isEmpty, (record["grade"] as? String) != grade {
                record["backup_grade"] = record["grade"]
                record["grade"] = grade
                hasChanges = true
            }
            
            if hasChanges {
                // Audit Trail
                let editor = UserDefaults.standard.string(forKey: "pilotName") ?? "COMMANDER"
                record["lastEditorName"] = editor
                record["lastEditedDate"] = Date()
                
                try await publicDB.save(record)
                print("✅ [DiscoveryManager] Successfully corrected: \(jan) by \(editor)")
            } else {

                print("⚠️ [DiscoveryManager] No changes needed for: \(jan)")
            }
            
        } catch {
            print("❌ [DiscoveryManager] Update failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Auto-Fill Blanks (Non-Destructive Update)
    func fillBlanks(jan: String, title: String?, maker: String?, scale: String?, series: String?, grade: String?) async {
        print("🧩 [DiscoveryManager] Attempting to auto-fill blanks for: \(jan)")
        let recordID = CKRecord.ID(recordName: jan)
        
        do {
            let record = try await publicDB.record(for: recordID)
            var hasChanges = false
            
            // Only update if Record value is empty AND we have a value
            if let t = title, !t.isEmpty, (record["title"] as? String)?.isEmpty ?? true {
                record["title"] = t; hasChanges = true
            }
            if let m = maker, !m.isEmpty, (record["maker"] as? String)?.isEmpty ?? true {
                record["maker"] = m; hasChanges = true
            }
            if let s = scale, !s.isEmpty, (record["scale"] as? String)?.isEmpty ?? true {
                record["scale"] = s; hasChanges = true
            }
            if let ser = series, !ser.isEmpty, (record["series"] as? String)?.isEmpty ?? true {
                record["series"] = ser; hasChanges = true
            }
            if let g = grade, !g.isEmpty, (record["grade"] as? String)?.isEmpty ?? true {
                record["grade"] = g; hasChanges = true
            }
            
            if hasChanges {
                let editor = UserDefaults.standard.string(forKey: "pilotName") ?? "COMMANDER"
                record["lastEditorName"] = editor // Mark who filled the blanks
                // Don't update lastEditedDate for simple blank fills to keep original discovery date dominant? 
                // Actually, updating date is fine.
                try await publicDB.save(record)
                print("✅ [DiscoveryManager] Auto-filled blanks for: \(jan)")
            }
        } catch {
            print("⚠️ [DiscoveryManager] Fill blanks failed (ignoring): \(error)")
        }
    }
    
    // MARK: - Voting & Verification (Locking System)
    func voteDiscovery(jan: String) async throws -> Bool {
        print("👍 [DiscoveryManager] Upvoting: \(jan)")
        let recordID = CKRecord.ID(recordName: jan)
        
        do {
            let record = try await publicDB.record(for: recordID)
            
            // Increment Vote
            let currentVotes = (record["voteCount"] as? Int) ?? 0
            let newVotes = currentVotes + 1
            record["voteCount"] = newVotes
            
            // Check Locking Threshold (e.g., 3 votes)
            if newVotes >= 3 {
                record["isLocked"] = 1
                record["verifiedDate"] = Date()
                print("🔒 [DiscoveryManager] Record reached verification threshold! LOCKED.")
            }
            
            try await publicDB.save(record)
            print("✅ [DiscoveryManager] Voted. Count: \(newVotes)")
            return (record["isLocked"] as? Int) == 1
            
        } catch {
            print("❌ [DiscoveryManager] Vote failed: \(error)")
            throw error
        }
    }
    
    // MARK: - Reputation Check (Vandalism Protection)
    func checkEditPermission() async -> Bool {
        let name = UserDefaults.standard.string(forKey: "pilotName") ?? "COMMANDER"
        print("🕵️ [DiscoveryManager] Checking reputation for: \(name)")
        
        let predicate = NSPredicate(format: "discovererName == %@", name)
        let query = CKQuery(recordType: "DiscoveryItem", predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "discoveredDate", ascending: false)]
        
        do {
            // Optimization: Fetch only 3 items to verify status
            let (matchResults, _) = try await publicDB.records(matching: query, inZoneWith: nil, desiredKeys: ["discovererName"], resultsLimit: 3)
            let count = matchResults.count
            print("🕵️ [DiscoveryManager] Found \(count) discoveries by user.")
            
            // Threshold: Must have discovered at least 1 item (or 3 as requested) to edit others
            return count >= 1 // Start lenient: 1 discovery allows editing. Increase to 3 if needed.
        } catch {
            print("❌ [DiscoveryManager] Permission check failed: \(error)")
            return false
        }
    }
    
    // MARK: - Unique Username System
    func reserveUserName(_ name: String) async -> Bool {
        // Normalize name: Uppercase to avoid case variants
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return false }
        
        let recordID = CKRecord.ID(recordName: normalized)
        let record = CKRecord(recordType: "UniqueUser", recordID: recordID)
        record["display"] = name // Store original display name if needed
        
        do {
            try await publicDB.save(record)
            print("✅ [DiscoveryManager] Username reserved: \(normalized)")
            return true
        } catch {
            if let ckError = error as? CKError {
                if ckError.code == .serverRecordChanged {
                    // Already exists. Check ownership.
                    // To check ownership, we need to fetch the existing record and check 'creatorUserRecordID'
                    // For now, let's assume if it exists, it's TAKEN (unless we implement full auth check).
                    // Simple "First Come First Served".
                    print("⚠️ [DiscoveryManager] Username taken: \(normalized)")
                    
                    // Optional: If I own it, return true.
                    // But checking ownership requires a fetch.
                    return await verifyOwnership(of: recordID)
                }
            }
            print("❌ [DiscoveryManager] Username reservation failed: \(error)")
            return false
        }
    }
    
    private func verifyOwnership(of recordID: CKRecord.ID) async -> Bool {
        do {
            let record = try await publicDB.record(for: recordID)
            // If the record was created by THIS user, then it's fine.
            if let creator = record.creatorUserRecordID,
               let myID = try? await container.userRecordID(),
               creator.recordName == myID.recordName {
                print("✅ [DiscoveryManager] User already owns this name.")
                return true
            }
        } catch {
            print("❌ [DiscoveryManager] Ownership check failed: \(error)")
        }
        return false
    }
    
    // MARK: - Fetch Rankings
    func fetchRankings() async {
        // This requires aggregation which isn't directly supported in simple CKQuery.
        // For V1, we might just fetch recent discoveries or need a separate "DiscovererStats" record type.
        // Skipping complex ranking logic for now to focus on registration flow.
    }
}
