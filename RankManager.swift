//
//  RankManager.swift
//  Plalog
//
//  Created by (User) on 2026/01/11.
//  Dynamic Rank System logic based on collection style.
//

import SwiftUI

enum PilotStyle: String, CaseIterable, Identifiable {
    case mecha = "MECHA"
    case air = "AIR"
    case land = "LAND"
    case sea = "SEA"
    case auto = "AUTO"
    case standard = "STANDARD"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .mecha: return "command.circle.fill" // Robot/Sci-Fi
        case .air: return "airplane.circle.fill" // Plane
        case .land: return "car.circle.fill" // Tank/Car (using car for general vehicle)
        case .sea: return "ferry.fill" // Ship
        case .auto: return "steeringwheel" // Steering wheel
        case .standard: return "hammer.fill" // Tool
        }
    }
    
    var displayName: String {
        switch self {
        case .mecha: return "MECHA PILOT"
        case .air: return "AIR FORCE"
        case .land: return "GROUND FORCE"
        case .sea: return "NAVAL FLEET"
        case .auto: return "MOTOR SPORTS"
        case .standard: return "MODELER"
        }
    }
}

class RankManager {
    static let shared = RankManager()
    
    // MARK: - Rank Tables
    func getRankTitle(style: PilotStyle, count: Int) -> String {
        let level = getLevel(count: count)
        
        switch style {
        case .mecha:
            switch level {
            case 1: return "CADET"
            case 2: return "PILOT"
            case 3: return "VETERAN"
            case 4: return "ACE"
            case 5: return "COMMANDER"
            case 6: return "NEWTYPE"
            default: return "CADET"
            }
        case .air:
            switch level {
            case 1: return "STUDENT"
            case 2: return "AVIATOR"
            case 3: return "WINGMAN"
            case 4: return "TOP GUN"
            case 5: return "SQUADRON LDR"
            case 6: return "SKY KING"
            default: return "STUDENT"
            }
        case .land:
            switch level {
            case 1: return "RECRUIT"
            case 2: return "SOLDIER"
            case 3: return "SERGEANT"
            case 4: return "ZAPPER" // 熟練兵ぽい響き
            case 5: return "COLONEL"
            case 6: return "GENERAL"
            default: return "RECRUIT"
            }
        case .sea:
            switch level {
            case 1: return "SAILOR"
            case 2: return "ENSIGN"
            case 3: return "LIEUTENANT"
            case 4: return "CAPTAIN"
            case 5: return "COMMODORE"
            case 6: return "ADMIRAL"
            default: return "SAILOR"
            }
        case .auto:
            switch level {
            case 1: return "ROOKIE"
            case 2: return "DRIVER"
            case 3: return "RACER"
            case 4: return "PRO RACER"
            case 5: return "CHAMPION"
            case 6: return "LEGEND"
            default: return "ROOKIE"
            }
        case .standard:
            switch level {
            case 1: return "BEGINNER"
            case 2: return "BUILDER"
            case 3: return "CRAFTER"
            case 4: return "ARTISAN"
            case 5: return "MASTER"
            case 6: return "MAESTRO"
            default: return "BEGINNER"
            }
        }
    }
    
    func getLevel(count: Int) -> Int {
        switch count {
        case 0..<5: return 1
        case 5..<15: return 2
        case 15..<30: return 3
        case 30..<50: return 4
        case 50..<100: return 5
        default: return 6
        }
    }
    
    // MARK: - Auto Detection Logic
    func detectStyle(from kits: [Kit]) -> PilotStyle {
        guard !kits.isEmpty else { return .standard }
        
        var scores: [PilotStyle: Int] = [
            .mecha: 0, .air: 0, .land: 0, .sea: 0, .auto: 0, .standard: 0
        ]
        
        for kit in kits {
            let text = (kit.maker + " " + kit.title + " " + kit.series + " " + kit.grade).uppercased()
            
            // Dictionary of Keywords
            if text.contains("GUNDAM") || text.contains("BANDAI") || text.contains("HG") || text.contains("MG") || text.contains("RG") || text.contains("PG") || text.contains("ROBOT") || text.contains("MECHA") || text.contains("FRAME ARMS") || text.contains("KOTOBUKIYA") {
                scores[.mecha, default: 0] += 1
            }
            else if text.contains("TAMIYA") || text.contains("HASEGAWA") || text.contains("1/72") || text.contains("1/48") || text.contains("JET") || text.contains("WING") || text.contains("AIRPLANE") || text.contains("F-") || text.contains("AIRCRAFT") {
                // Tamiya is tricky, overlaps with Land/Auto. Check specific keywords.
                if text.contains("TANK") || text.contains("1/35") || text.contains("AFV") || text.contains("MILITARY") {
                    scores[.land, default: 0] += 1
                } else if text.contains("CAR") || text.contains("BIKE") || text.contains("1/24") || text.contains("AUTO") || text.contains("NISSAN") || text.contains("TOYOTA") || text.contains("HONDA") || text.contains("FERRARI") {
                    scores[.auto, default: 0] += 1
                } else {
                    scores[.air, default: 0] += 1 // Default Tamiya/Hasegawa to Air if no other hints? No, risky.
                }
            }
            else if text.contains("AOSHIMA") || text.contains("FUJIMI") || text.contains("SHIP") || text.contains("1/700") || text.contains("NAVY") || text.contains("YAMATO") || text.contains("DESTROYER") {
                scores[.sea, default: 0] += 1
            }
            else if text.contains("WARHAMMER") || text.contains("FIGURE") {
                scores[.standard, default: 0] += 1
            }
            else {
                scores[.standard, default: 0] += 1
            }
            
            // Specific Tamiya/Hasegawa disambiguation if just maker
            if text.contains("TAMIYA") && !text.contains("1/35") && !text.contains("1/24") {
                 scores[.land, default: 0] += 1 // Slight bias to Land for Tamiya
            }
        }
        
        // Find highest score
        let sorted = scores.sorted { $0.value > $1.value }
        return sorted.first?.key ?? .standard
    }
}
