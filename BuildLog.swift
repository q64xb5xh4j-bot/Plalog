//
//  BuildLog.swift
//  Plalog
//
//  Created by (User) on 2024/06/xx.
//

import Foundation
import SwiftData

@Model
final class BuildLog {
    var date: Date = Date()
    var imagePath: String? = nil
    var text: String = ""
    var uuid: String = UUID().uuidString
    @Attribute(.externalStorage) var logImageData: Data?
    
    @Relationship(inverse: \Kit.buildLogs) var kit: Kit?
    
    init(date: Date = Date(), imagePath: String? = nil, text: String = "", uuid: String? = nil, logImageData: Data? = nil) {
        self.date = date
        self.imagePath = imagePath
        self.text = text
        if let id = uuid { self.uuid = id }
        self.logImageData = logImageData
    }
}
