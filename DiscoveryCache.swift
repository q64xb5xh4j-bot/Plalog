// DiscoveryCache.swift
// SwiftData model for caching CloudKit Discovery data locally.
// This enables fast local search and avoids CloudKit query limitations.

import Foundation
import SwiftData

@Model
final class DiscoveryCache {
    // Primary Key - JAN Code (uniqueness handled in sync logic, not via constraint)
    var janCode: String = ""
    
    // Product Information
    var title: String = ""
    var maker: String = ""
    var scale: String = ""
    var series: String = ""
    var grade: String = ""
    
    // Discovery Information
    var discovererName: String = ""
    var discoveredDate: Date = Date()
    var isLocked: Bool = false
    var voteCount: Int = 0
    
    // Sync Metadata
    var lastSyncDate: Date = Date()
    
    init(
        janCode: String,
        title: String = "",
        maker: String = "",
        scale: String = "",
        series: String = "",
        grade: String = "",
        discovererName: String = "",
        discoveredDate: Date = Date(),
        isLocked: Bool = false,
        voteCount: Int = 0,
        lastSyncDate: Date = Date()
    ) {
        self.janCode = janCode
        self.title = title
        self.maker = maker
        self.scale = scale
        self.series = series
        self.grade = grade
        self.discovererName = discovererName
        self.discoveredDate = discoveredDate
        self.isLocked = isLocked
        self.voteCount = voteCount
        self.lastSyncDate = lastSyncDate
    }
}
