import SwiftUI
import Combine // ✅ これが必要です！これがないと @Published が使えません

// MARK: - App Theme Definition
enum AppTheme: String, CaseIterable, Identifiable {
    case blue, red, green, white, orange
    
    var id: String { rawValue }
    
    var mainColor: Color {
        switch self {
        case .blue:   return Color(red: 0.0, green: 0.5, blue: 1.0)
        case .red:    return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .green:  return Color(red: 0.1, green: 0.8, blue: 0.3)
        case .white:  return Color.primary
        case .orange: return Color(red: 1.0, green: 0.5, blue: 0.0)
        }
    }
    
    var secondaryColor: Color {
        mainColor.opacity(0.15)
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    // ✅ 変化を監視・通知するためのプロパティ
    @Published var currentTheme: AppTheme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "selected_theme")
        }
    }
    
    // ✅ 保存された値を読み込み、なければ blue を初期値にする
    private init() {
        let saved = UserDefaults.standard.string(forKey: "selected_theme") ?? AppTheme.blue.rawValue
        self.currentTheme = AppTheme(rawValue: saved) ?? .blue
    }
    
    // テーマを切り替える関数
    func setTheme(_ theme: AppTheme) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTheme = theme
        }
    }
}
