//
//  LanguageManager.swift
//  Plalog
//
//  Created by (User) on 2026/01/11.
//

import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case de = "de"
    case en = "en"
    case fr = "fr"
    case ja = "ja"
    case ko = "ko"
    case th = "th"
    case vi = "vi"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .de: return "Deutsch"
        case .en: return "English"
        case .fr: return "Français"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .th: return "ภาษาไทย"
        case .vi: return "Tiếng Việt"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        }
    }
    
    var flag: String {
        switch self {
        case .de: return "🇩🇪"
        case .en: return "🇺🇸"
        case .fr: return "🇫🇷"
        case .ja: return "🇯🇵"
        case .ko: return "🇰🇷"
        case .th: return "🇹🇭"
        case .vi: return "🇻🇳"
        case .zhHans: return "🇨🇳"
        case .zhHant: return "🇹🇼"
        }
    }
}

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @AppStorage("appLanguage") var currentLanguageRaw: String = ""
    
    var currentLanguage: AppLanguage {
        get {
            if let lang = AppLanguage(rawValue: currentLanguageRaw) {
                return lang
            }
            return .en
        }
        set { currentLanguageRaw = newValue.rawValue }
    }
    
    init() {
        if UserDefaults.standard.string(forKey: "appLanguage") == nil || UserDefaults.standard.string(forKey: "appLanguage") == "" {
            let detected = LanguageManager.detectSystemLanguage()
            currentLanguageRaw = detected.rawValue
        }
    }
    
    static func detectSystemLanguage() -> AppLanguage {
        guard let systemLang = Locale.preferredLanguages.first else { return .en }
        
        if systemLang.starts(with: "ja") { return .ja }
        if systemLang.starts(with: "vi") { return .vi }
        if systemLang.starts(with: "ko") { return .ko }
        if systemLang.starts(with: "th") { return .th }
        if systemLang.starts(with: "de") { return .de }
        if systemLang.starts(with: "fr") { return .fr }
        
        if systemLang.contains("Hans") || systemLang == "zh-CN" || systemLang == "zh-SG" { return .zhHans }
        if systemLang.contains("Hant") || systemLang == "zh-TW" || systemLang == "zh-HK" || systemLang.starts(with: "zh") { return .zhHant }
        if systemLang.starts(with: "zh") { return .zhHans }
        
        return .en
    }
    
    // MARK: - Translation Keys
    enum Key: String {
        // Stats
        case stats_logged
        case stats_stock
        case stats_const
        case stats_done
        
        // Commander Menu
        case cmd_title
        case cmd_status_title
        case cmd_status_desc
        case cmd_sync_title
        case cmd_sync_desc
        case cmd_slide_title
        case cmd_slide_desc
        case cmd_system_title
        case cmd_system_desc
        case cmd_close_guide
        
        // Settings - Main
        case settings_title
        case settings_language
        case settings_language_note
        case settings_theme
        case settings_library
        case settings_cloud
        case settings_sync
        case settings_godmode
        case settings_dbstore
        case settings_sysinfo
        
        // Settings - Items
        case lib_manage_title
        case lib_manage_desc
        case lib_missing_title
        case lib_missing_desc_pre
        case lib_missing_desc_post
        case lib_repair_title
        case lib_repair_desc
        case lib_storage_title
        case lib_storage_desc
        case lib_reset_btn
        
        case cloud_low_data
        case cloud_low_data_desc
        case cloud_migrate_title
        case cloud_migrate_desc
        
        case sync_direct_title
        case sync_direct_desc
        case sync_export_title
        case sync_export_desc
        case sync_import_title
        case sync_import_desc
        
        case god_active
        case god_inactive
        case god_system_activated
        case god_enable_guide
        case god_locked_guide
        case god_api_key
        case god_enter_key
        case god_engine_id
        case god_enter_id
        
        case db_military_desc
        case db_car_desc
        
        // Pilot Stats Keys
        case pilot_id
        case rank_prefix
        case fav_maker
        case wish_list
        case exp_level
        case comp_rate
        case select_style
        case reset_style
        case close
        case share_card
        case share_list
        case btn_purchased
        
        // Units
        case unit_units
        case unit_boxes
        case unit_items
        
        // iPad Sidebar
        case sidebar_all
        case sidebar_wish
        case sidebar_reserved
        case sidebar_stock
        case sidebar_progress
        case sidebar_complete
        case sidebar_slideshow
        case sidebar_settings
        case sidebar_modules
        case sidebar_system
        
        // iPad UI
        case ipad_acquire_unit
        case ipad_search_placeholder
        case ipad_scan
        case ipad_scanning
        case ipad_search_results
        case ipad_wish_empty
        case ipad_wish_empty_desc
        case ipad_select_module
        
        // Hangar Buttons
        case btn_add_unit
        case btn_filter
        
        // Status Filters
        case status_all
        case status_wish
        case status_reserved
        case status_stock
        case status_wip
        case status_done
    }
    
    func t(_ key: Key) -> String {
        let lang = currentLanguage
        return translations[lang]?[key] ?? key.rawValue
    }
    
    // MARK: - Dictionary
    private let translations: [AppLanguage: [Key: String]] = [
        .en: [
            .stats_logged: "LOGGED",
            .stats_stock: "STOCK",
            .stats_const: "CONST.",
            .stats_done: "DONE",
            
            .cmd_title: " MENU",
            .cmd_status_title: "PILOT STATUS",
            .cmd_status_desc: "Check your rank",
            .cmd_sync_title: "SYNC DATA",
            .cmd_sync_desc: "Connect devices",
            .cmd_slide_title: "SLIDESHOW",
            .cmd_slide_desc: "View collection",
            .cmd_system_title: "SYSTEM",
            .cmd_system_desc: "Config & Backup",
            .cmd_close_guide: "TAP ORB TO CLOSE",
            
            .settings_title: "SYSTEM TERMINAL",
            .settings_language: "LANGUAGE",
            .settings_language_note: "Languages are sorted by ISO 639-1 code standard.",
            .settings_theme: "THEME COLOR",
            .settings_library: "LIBRARY MANAGEMENT",
            .settings_cloud: "CLOUD STORAGE (iCloud)",
            .settings_sync: "SYNC & BACKUP",
            .settings_godmode: "GOD MODE (GOOGLE API)",
            .settings_dbstore: "DATABASE STORE",
            .settings_sysinfo: "SYSTEM INFO",
            
            .lib_manage_title: "ITEM MANAGEMENT",
            .lib_manage_desc: "Edit / Batch operation",
            .lib_missing_title: "MISSING LINKS",
            .lib_missing_desc_pre: "Unfetched Images: BOX ",
            .lib_missing_desc_post: " / COMPLETE ",
            .lib_repair_title: "IMAGE REPAIR",
            .lib_repair_desc: "Auto-detect & delete broken images",
            .lib_storage_title: "STORAGE MAINTENANCE",
            .lib_storage_desc: "Delete unused image files",
            .lib_reset_btn: "RESET",
            
            .cloud_low_data: "Low Data Mode (iCloud)",
            .cloud_low_data_desc: "Save web images to Photos app to save space.",
            .cloud_migrate_title: "MIGRATE TO CLOUD",
            .cloud_migrate_desc: "Move existing images to albums",
            
            .sync_direct_title: "DIRECT SYNC",
            .sync_direct_desc: "Direct sync with nearby devices",
            .sync_export_title: "DATA EXPORT (BACKUP)",
            .sync_export_desc: "Export full backup with images",
            .sync_import_title: "DATA IMPORT (RESTORE)",
            .sync_import_desc: "Select all files in backup",
            
            .god_active: "GOD MODE: ACTIVE",
            .god_inactive: "GOD MODE: INACTIVE",
            .god_system_activated: "SYSTEM ACTIVATED",
            .god_enable_guide: "Turn switch ON to enable features.",
            .god_locked_guide: "SYSTEM LOCKED: Enter both API KEY and ENGINE ID to enable.",
            .god_api_key: "API KEY",
            .god_enter_key: "ENTER API KEY...",
            .god_engine_id: "SEARCH ENGINE ID (CX)",
            .god_enter_id: "ENTER ENGINE ID...",
            
            .db_military_desc: "Over 2,000 military scale models.",
            .db_car_desc: "Famous extensive car catalog.",
            
            .pilot_id: "PILOT IDENTIFICATION",
            .rank_prefix: "RANK: ",
            .fav_maker: "FAVORITE MAKER",
            .wish_list: "WISH LIST",
            .exp_level: "EXP LEVEL",
            .comp_rate: "COMPLETION RATE",
            .select_style: "SELECT PILOT STYLE",
            .reset_style: "RESET TO AUTO DETECT",
            .close: "CLOSE",
            .share_card: "SHARE CARD",
            .share_list: "SHARE LIST",
            .btn_purchased: "PURCHASED",
            
            .unit_units: "UNITS",
            .unit_boxes: "BOXES",
            .unit_items: " ITEMS",
            
            .sidebar_all: "ALL UNITS",
            .sidebar_wish: "PROCUREMENT",
            .sidebar_reserved: "ARRANGED",
            .sidebar_stock: "VAULT",
            .sidebar_progress: "CONSTRUCTING",
            .sidebar_complete: "DEPLOYED",
            .sidebar_slideshow: "VISUAL ARCHIVE",
            .sidebar_settings: "SYSTEM CONFIG",
            .sidebar_modules: "MODULES",
            .sidebar_system: "SYSTEM",
            
            .ipad_acquire_unit: "ACQUIRE NEW UNIT",
            .ipad_search_placeholder: "SEARCH NEW UNIT...",
            .ipad_scan: "SCAN",
            .ipad_scanning: "SCANNING DATA STREAM...",
            .ipad_search_results: "SEARCH RESULTS",
            .ipad_wish_empty: "WISH LIST IS EMPTY",
            .ipad_wish_empty_desc: "Use the search bar above to add desired units.",

            .ipad_select_module: "SELECT MODULE",
            
            .btn_add_unit: "ADD UNIT",
            .btn_filter: "FILTER",
            
            .status_all: "ALL",
            .status_wish: "WISH",
            .status_reserved: "RESERVED",
            .status_stock: "STOCK",
            .status_wip: "WIP",
            .status_done: "DONE"
        ],
        .ja: [
            .stats_logged: "総数",
            .stats_stock: "積み",
            .stats_const: "作成中",
            .stats_done: "完成",
            
            .cmd_title: " メニュー",
            .cmd_status_title: "パイロット情報",
            .cmd_status_desc: "ランク・称号の確認",
            .cmd_sync_title: "データ同期",
            .cmd_sync_desc: "デバイス間接続",
            .cmd_slide_title: "スライドショー",
            .cmd_slide_desc: "コレクション鑑賞",
            .cmd_system_title: "システム設定",
            .cmd_system_desc: "設定・バックアップ",
            .cmd_close_guide: "オーブをタップして閉じる",
            
            .settings_title: "システム設定",
            .settings_language: "言語設定",
            .settings_language_note: "言語はISO 639-1コード(国際標準)順に表示されています。",
            .settings_theme: "テーマカラー",
            .settings_library: "ライブラリ管理",
            .settings_cloud: "クラウドストレージ (iCloud)",
            .settings_sync: "同期・バックアップ",
            .settings_godmode: "ゴッドモード (Google API)",
            .settings_dbstore: "データベースストア",
            .settings_sysinfo: "システム情報",
            
            .lib_manage_title: "データ管理",
            .lib_manage_desc: "登録データの編集・一括操作",
            .lib_missing_title: "リンク切れ確認",
            .lib_missing_desc_pre: "未取得画像: 箱 ",
            .lib_missing_desc_post: " / 完成 ",
            .lib_repair_title: "画像修復",
            .lib_repair_desc: "表示されない破損画像を自動検出・削除",
            .lib_storage_title: "ストレージ整理",
            .lib_storage_desc: "不要な画像ファイルを削除",
            .lib_reset_btn: "リセット",
            
            .cloud_low_data: "省スペースモード (iCloud連携)",
            .cloud_low_data_desc: "Web画像を写真アプリに保存し、アプリ容量を節約します。",
            .cloud_migrate_title: "クラウドへの移行",
            .cloud_migrate_desc: "既存の画像をアルバムへ移行",
            
            .sync_direct_title: "ダイレクト同期",
            .sync_direct_desc: "近くのiPhone/iPadと直接同期",
            .sync_export_title: "データ書き出し (バックアップ)",
            .sync_export_desc: "画像込みの完全バックアップを出力",
            .sync_import_title: "データ読み込み (復元)",
            .sync_import_desc: "バックアップ内の全ファイルを選択",
            
            .god_active: "ゴッドモード: 有効",
            .god_inactive: "ゴッドモード: 無効",
            .god_system_activated: "システム認証済み",
            .god_enable_guide: "スイッチをONにして機能を有効化してください。",
            .god_locked_guide: "システムロック: 有効化するにはAPI KEYとENGINE IDの両方を入力してください。",
            .god_api_key: "API KEY",
            .god_enter_key: "API キーを入力...",
            .god_engine_id: "検索エンジンID (CX)",
            .god_enter_id: "エンジンIDを入力...",
            
            .db_military_desc: "2,000件以上のミリタリーモデルデータ",
            .db_car_desc: "主要自動車モデルの広範なカタログ",
            
            .pilot_id: "パイロットID",
            .rank_prefix: "階級: ",
            .fav_maker: "お気に入りメーカー",
            .wish_list: "欲しいものリスト",
            .exp_level: "経験レベル",
            .comp_rate: "達成率",
            .select_style: "スタイル選択",
            .reset_style: "自動判定にリセット",
            .close: "閉じる",
            .share_card: "カードを共有",
            .share_list: "リストを共有",
            .btn_purchased: "購入済み",
            
            .unit_units: "機",
            .unit_boxes: "個",
            .unit_items: "個",
            
            .sidebar_all: "全て",
            .sidebar_wish: "調達リスト",
            .sidebar_reserved: "手配済み",
            .sidebar_stock: "収蔵庫",
            .sidebar_progress: "建造中",
            .sidebar_complete: "完成機体",
            .sidebar_slideshow: "ビジュアルアーカイブ",
            .sidebar_settings: "システム設定",
            .sidebar_modules: "モジュール",
            .sidebar_system: "システム",
            
            .ipad_acquire_unit: "新規ユニット取得",
            .ipad_search_placeholder: "新規ユニットを検索...",
            .ipad_scan: "スキャン",
            .ipad_scanning: "データストリームをスキャン中...",
            .ipad_search_results: "検索結果",
            .ipad_wish_empty: "リストは空です",
            .ipad_wish_empty_desc: "上の検索バーを使って欲しいユニットを追加してください。",

            .ipad_select_module: "モジュールを選択",
            
            .btn_add_unit: "新規登録",
            .btn_filter: "絞り込み",
            
            .status_all: "すべて",
            .status_wish: "欲しい",
            .status_reserved: "予約済み",
            .status_stock: "積み",
            .status_wip: "製作中",
            .status_done: "完成"
        ],
        .vi: [
            .stats_logged: "TỔNG SỐ",
            .stats_stock: "KHO",
            .stats_const: "ĐANG LẮP",
            .stats_done: "HOÀN THÀNH",
            
            .cmd_title: " MENU",
            .cmd_status_title: "THÔNG TIN PILOT",
            .cmd_status_desc: "Kiểm tra xếp hạng",
            .cmd_sync_title: "ĐỒNG BỘ",
            .cmd_sync_desc: "Kết nối thiết bị",
            .cmd_slide_title: "TRÌNH CHIẾU",
            .cmd_slide_desc: "Xem bộ sưu tập",
            .cmd_system_title: "HỆ THỐNG",
            .cmd_system_desc: "Cấu hình & Sao lưu",
            .cmd_close_guide: "CHẠM ORB ĐỂ ĐÓNG",
            
            .settings_title: "CẤU HÌNH HỆ THỐNG",
            .settings_language: "NGÔN NGỮ",
            .settings_language_note: "Ngôn ngữ được sắp xếp theo mã tiêu chuẩn ISO 639-1.",
            .settings_theme: "MÀU CHỦ ĐẠO",
            .settings_library: "QUẢN LÝ THƯ VIỆN",
            .settings_cloud: "LƯU TRỮ CLOUD (iCloud)",
            .settings_sync: "ĐỒNG BỘ & SAO LƯU",
            .settings_godmode: "CHẾ ĐỘ THẦN THÁNH",
            .settings_dbstore: "CỬA HÀNG CƠ SỞ DỮ LIỆU",
            .settings_sysinfo: "THÔNG TIN HỆ THỐNG",
            
            .lib_manage_title: "QUẢN LÝ MỤC",
            .lib_manage_desc: "Chỉnh sửa / Thao tác hàng loạt",
            .lib_missing_title: "LIÊN KẾT THIẾU",
            .lib_missing_desc_pre: "Ảnh thiếu: HỘP ",
            .lib_missing_desc_post: " / HOÀN THÀNH ",
            .lib_repair_title: "SỬA ẢNH",
            .lib_repair_desc: "Tự động phát hiện & xóa ảnh lỗi",
            .lib_storage_title: "BẢO TRÌ BỘ NHỚ",
            .lib_storage_desc: "Xóa tệp hình ảnh không dùng",
            .lib_reset_btn: "ĐẶT LẠI",
            
            .cloud_low_data: "Chế độ dữ liệu thấp",
            .cloud_low_data_desc: "Lưu ảnh web vào Ảnh để tiết kiệm dung lượng.",
            .cloud_migrate_title: "DI CƯ LÊN CLOUD",
            .cloud_migrate_desc: "Di chuyển ảnh hiện có vào album",
            
            .sync_direct_title: "ĐỒNG BỘ TRỰC TIẾP",
            .sync_direct_desc: "Đồng bộ trực tiếp với thiết bị gần",
            .sync_export_title: "XUẤT DỮ LIỆU (BACKUP)",
            .sync_export_desc: "Xuất dữ liệu đầy đủ kèm ảnh",
            .sync_import_title: "NHẬP DỮ LIỆU (RESTORE)",
            .sync_import_desc: "Chọn tất cả tệp trong bản sao lưu",
            
            .god_active: "GOD MODE: BẬT",
            .god_inactive: "GOD MODE: TẮT",
            .god_system_activated: "HỆ THỐNG ĐÃ KÍCH HOẠT",
            .god_enable_guide: "Bật công tắc để kích hoạt tính năng.",
            .god_locked_guide: "HỆ THỐNG KHÓA: Nhập cả API KEY và ENGINE ID.",
            .god_api_key: "API KEY",
            .god_enter_key: "NHẬP API KEY...",
            .god_engine_id: "SEARCH ENGINE ID (CX)",
            .god_enter_id: "NHẬP ENGINE ID...",
            
            .db_military_desc: "Hơn 2,000 mô hình quân sự.",
            .db_car_desc: "Danh mục xe hơi phong phú.",
            
            .pilot_id: "ĐỊNH DANH PILOT",
            .rank_prefix: "CẤP BẬC: ",
            .fav_maker: "HÃNG YÊU THÍCH",
            .wish_list: "DANH SÁCH MONG MUỐN",
            .exp_level: "CẤP ĐỘ EXP",
            .comp_rate: "TỶ LỆ HOÀN THÀNH",
            .select_style: "CHỌN PHONG CÁCH",
            .reset_style: "ĐẶT LẠI TỰ ĐỘNG",
            .close: "ĐÓNG",
            .share_card: "CHIA SẺ THẺ",
            .share_list: "CHIA SẺ DANH SÁCH",
            .btn_purchased: "ĐÃ MUA",
            
            .unit_units: "MÁY",
            .unit_boxes: "HỘP",
            .unit_items: " MỤC",
            
            .sidebar_all: "CYBER HANGAR",
            .sidebar_wish: "MONG MUỐN",
            .sidebar_reserved: "ĐÃ ĐẶT",
            .sidebar_stock: "KHO",
            .sidebar_progress: "ĐANG LẮP",
            .sidebar_complete: "HOÀN THÀNH",
            .sidebar_slideshow: "TRÌNH CHIẾU",
            .sidebar_settings: "CẤU HÌNH",
            .sidebar_modules: "MODULE",
            .sidebar_system: "HỆ THỐNG",
            
            .ipad_acquire_unit: "THU THẬP ĐƠN VỊ MỚI",
            .ipad_search_placeholder: "Tìm kiếm...",
            .ipad_scan: "QUÉT",
            .ipad_scanning: "Đang quét dữ liệu...",
            .ipad_search_results: "KẾT QUẢ TÌM KIẾM",
            .ipad_wish_empty: "DANH SÁCH TRỐNG",
            .ipad_wish_empty_desc: "Sử dụng thanh tìm kiếm ở trên để thêm.",

            .ipad_select_module: "CHỌN MODULE",
            
            .btn_add_unit: "THÊM MỚI",
            .btn_filter: "BỘ LỌC",
            
            .status_all: "TẤT CẢ",
            .status_wish: "MONG MUỐN",
            .status_reserved: "ĐÃ ĐẶT",
            .status_stock: "KHO",
            .status_wip: "ĐANG LÀM",
            .status_done: "HOÀN THÀNH"
        ],
        .zhHans: [
            .stats_logged: "总数",
            .stats_stock: "堆积",
            .stats_const: "制作中",
            .stats_done: "完成",
            
            .cmd_title: " 菜单",
            .cmd_status_title: "驾驶员状态",
            .cmd_status_desc: "确认军衔",
            .cmd_sync_title: "数据同步",
            .cmd_sync_desc: "连接设备",
            .cmd_slide_title: "幻灯片",
            .cmd_slide_desc: "欣赏收藏",
            .cmd_system_title: "系统设定",
            .cmd_system_desc: "设置与备份",
            .cmd_close_guide: "点击宝珠关闭",
            
            .settings_title: "系统终端",
            .settings_language: "语言",
            .settings_language_note: "语言列表按 ISO 639-1 标准代码排序。",
            .settings_theme: "主题颜色",
            .settings_library: "库管理",
            .settings_cloud: "云存储 (iCloud)",
            .settings_sync: "同步与备份",
            .settings_godmode: "上帝模式 (Google API)",
            .settings_dbstore: "数据库商店",
            .settings_sysinfo: "系统信息",
            
            .lib_manage_title: "项目管理",
            .lib_manage_desc: "编辑 / 批量操作",
            .lib_missing_title: "缺失链接",
            .lib_missing_desc_pre: "未获取图片: 盒 ",
            .lib_missing_desc_post: " / 完成 ",
            .lib_repair_title: "图片修复",
            .lib_repair_desc: "自动检测并删除损坏图片",
            .lib_storage_title: "存储维护",
            .lib_storage_desc: "删除未使用的图片文件",
            .lib_reset_btn: "重置",
            
            .cloud_low_data: "低数据模式",
            .cloud_low_data_desc: "将网络图片保存到相册以节省空间。",
            .cloud_migrate_title: "迁移到云端",
            .cloud_migrate_desc: "将现有图片移动到相册",
            
            .sync_direct_title: "直接同步",
            .sync_direct_desc: "与附近设备直接同步",
            .sync_export_title: "数据导出 (备份)",
            .sync_export_desc: "导出包含图片的完整备份",
            .sync_import_title: "数据导入 (恢复)",
            .sync_import_desc: "选择备份中的所有文件",
            
            .god_active: "上帝模式: 已激活",
            .god_inactive: "上帝模式: 未激活",
            .god_system_activated: "系统已激活",
            .god_enable_guide: "打开开关启用功能。",
            .god_locked_guide: "系统锁定: 输入 API KEY 和 ENGINE ID 以启用。",
            .god_api_key: "API KEY",
            .god_enter_key: "输入 API KEY...",
            .god_engine_id: "搜索引擎 ID (CX)",
            .god_enter_id: "输入 ENGINE ID...",
            
            .db_military_desc: "超过 2,000 个军事模型数据。",
            .db_car_desc: "著名的广泛汽车目录。",
            
            .pilot_id: "驾驶员识别",
            .rank_prefix: "军衔: ",
            .fav_maker: "最爱厂商",
            .wish_list: "愿望清单",
            .exp_level: "经验等级",
            .comp_rate: "完成率",
            .select_style: "选择风格",
            .reset_style: "重置为自动检测",
            .close: "关闭",
            .share_card: "分享卡片",
            .share_list: "分享列表",
            .btn_purchased: "已购买",
            
            .unit_units: "机",
            .unit_boxes: "盒",
            .unit_items: "项",
            
            .sidebar_all: "全机体",
            .sidebar_wish: "采购计划",
            .sidebar_reserved: "已安排",
            .sidebar_stock: "珍藏库",
            .sidebar_progress: "建造中",
            .sidebar_complete: "完成机体",
            .sidebar_slideshow: "影像档案",
            .sidebar_settings: "系统配置",
            .sidebar_modules: "模块",
            .sidebar_system: "系统",
            
            .ipad_acquire_unit: "获取新单位",
            .ipad_search_placeholder: "搜索新单位...",
            .ipad_scan: "扫描",
            .ipad_scanning: "正在扫描数据流...",
            .ipad_search_results: "搜索结果",
            .ipad_wish_empty: "清单为空",
            .ipad_wish_empty_desc: "使用上方搜索栏添加想要的单位。",

            .ipad_select_module: "选择模块",
            
            .btn_add_unit: "添加单位",
            .btn_filter: "筛选",
            
            .status_all: "全部",
            .status_wish: "愿望",
            .status_reserved: "预订",
            .status_stock: "堆积",
            .status_wip: "制作中",
            .status_done: "完成"
        ],
        .zhHant: [
            .stats_logged: "總數",
            .stats_stock: "山積",
            .stats_const: "製作中",
            .stats_done: "完成",
            
            .cmd_title: " 選單",
            .cmd_status_title: "駕駛員狀態",
            .cmd_status_desc: "確認軍階",
            .cmd_sync_title: "數據同步",
            .cmd_sync_desc: "連接設備",
            .cmd_slide_title: "幻燈片",
            .cmd_slide_desc: "欣賞收藏",
            .cmd_system_title: "系統設定",
            .cmd_system_desc: "設置與備份",
            .cmd_close_guide: "點擊寶珠關閉",
            
            .settings_title: "系統終端",
            .settings_language: "語言",
            .settings_language_note: "語言列表按 ISO 639-1 標準代碼排序。",
            .settings_theme: "主題顏色",
            .settings_library: "庫管理",
            .settings_cloud: "雲端存儲 (iCloud)",
            .settings_sync: "同步與備份",
            .settings_godmode: "上帝模式 (Google API)",
            .settings_dbstore: "數據庫商店",
            .settings_sysinfo: "系統信息",
            
            .lib_manage_title: "項目管理",
            .lib_manage_desc: "編輯 / 批量操作",
            .lib_missing_title: "缺失連結",
            .lib_missing_desc_pre: "未獲取圖片: 盒 ",
            .lib_missing_desc_post: " / 完成 ",
            .lib_repair_title: "圖片修復",
            .lib_repair_desc: "自動檢測並刪除損壞圖片",
            .lib_storage_title: "存儲維護",
            .lib_storage_desc: "刪除未使用的圖片文件",
            .lib_reset_btn: "重置",
            
            .cloud_low_data: "低數據模式",
            .cloud_low_data_desc: "將網絡圖片保存到相冊以節省空間。",
            .cloud_migrate_title: "遷移到雲端",
            .cloud_migrate_desc: "將現有圖片移動到相冊",
            
            .sync_direct_title: "直接同步",
            .sync_direct_desc: "與附近設備直接同步",
            .sync_export_title: "數據導出 (備份)",
            .sync_export_desc: "導出包含圖片的完整備份",
            .sync_import_title: "數據導入 (恢復)",
            .sync_import_desc: "選擇備份中的所有文件",
            
            .god_active: "上帝模式: 已激活",
            .god_inactive: "上帝模式: 未激活",
            .god_system_activated: "系統已激活",
            .god_enable_guide: "打開開關啟用功能。",
            .god_locked_guide: "系統鎖定: 輸入 API KEY 和 ENGINE ID 以啟用。",
            .god_api_key: "API KEY",
            .god_enter_key: "輸入 API KEY...",
            .god_engine_id: "搜索引擎 ID (CX)",
            .god_enter_id: "輸入 ENGINE ID...",
            
            .db_military_desc: "超過 2,000 個軍事模型數據。",
            .db_car_desc: "著名的廣泛汽車目錄。",
            
            .pilot_id: "駕駛員識別",
            .rank_prefix: "軍階: ",
            .fav_maker: "最愛廠商",
            .wish_list: "願望清單",
            .exp_level: "經驗等級",
            .comp_rate: "完成率",
            .select_style: "選擇風格",
            .reset_style: "重置為自動檢測",
            .close: "關閉",
            .share_card: "分享卡片",
            .share_list: "分享列表",
            .btn_purchased: "已購買",
            
            .unit_units: "機",
            .unit_boxes: "盒",
            .unit_items: "項",
            
            .sidebar_all: "全機體",
            .sidebar_wish: "採購計畫",
            .sidebar_reserved: "已安排",
            .sidebar_stock: "珍藏庫",
            .sidebar_progress: "建造中",
            .sidebar_complete: "完成機體",
            .sidebar_slideshow: "影像檔案",
            .sidebar_settings: "系統配置",
            .sidebar_modules: "模塊",
            .sidebar_system: "系統",
            
            .ipad_acquire_unit: "獲取新單位",
            .ipad_search_placeholder: "搜索新單位...",
            .ipad_scan: "掃描",
            .ipad_scanning: "正在掃描數據流...",
            .ipad_search_results: "搜索結果",
            .ipad_wish_empty: "清單為空",
            .ipad_wish_empty_desc: "使用上方搜索欄添加想要的單位。",

            .ipad_select_module: "選擇模塊",
            
            .btn_add_unit: "添加單位",
            .btn_filter: "篩選",
            
            .status_all: "全部",
            .status_wish: "願望",
            .status_reserved: "預訂",
            .status_stock: "山積",
            .status_wip: "製作中",
            .status_done: "完成"
        ],
        .ko: [
            .stats_logged: "전체",
            .stats_stock: "미조립",
            .stats_const: "작업중",
            .stats_done: "완성",
            
            .cmd_title: " 메뉴",
            .cmd_status_title: "파일럿 정보",
            .cmd_status_desc: "랭크 확인",
            .cmd_sync_title: "데이터 동기화",
            .cmd_sync_desc: "기기 연결",
            .cmd_slide_title: "슬라이드쇼",
            .cmd_slide_desc: "컬렉션 감상",
            .cmd_system_title: "시스템 설정",
            .cmd_system_desc: "설정 및 백업",
            .cmd_close_guide: "오브를 탭하여 닫기",
            
            .settings_title: "시스템 터미널",
            .settings_language: "언어",
            .settings_language_note: "언어는 ISO 639-1 코드로 정렬됩니다.",
            .settings_theme: "테마 색상",
            .settings_library: "라이브러리 관리",
            .settings_cloud: "클라우드 저장소 (iCloud)",
            .settings_sync: "동기화 및 백업",
            .settings_godmode: "갓 모드 (Google API)",
            .settings_dbstore: "데이터베이스 스토어",
            .settings_sysinfo: "시스템 정보",
            
            .lib_manage_title: "항목 관리",
            .lib_manage_desc: "편집 / 일괄 작업",
            .lib_missing_title: "누락된 링크",
            .lib_missing_desc_pre: "미수집 이미지: 박스 ",
            .lib_missing_desc_post: " / 완성 ",
            .lib_repair_title: "이미지 복구",
            .lib_repair_desc: "손상된 이미지 자동 감지 및 삭제",
            .lib_storage_title: "저장소 유지관리",
            .lib_storage_desc: "사용하지 않는 이미지 파일 삭제",
            .lib_reset_btn: "재설정",
            
            .cloud_low_data: "저데이터 모드",
            .cloud_low_data_desc: "웹 이미지를 사진 앱에 저장하여 공간 절약.",
            .cloud_migrate_title: "클라우드로 마이그레이션",
            .cloud_migrate_desc: "기존 이미지를 앨범으로 이동",
            
            .sync_direct_title: "직접 동기화",
            .sync_direct_desc: "주변 기기와 직접 동기화",
            .sync_export_title: "데이터 내보내기 (백업)",
            .sync_export_desc: "이미지 포함 전체 백업",
            .sync_import_title: "데이터 가져오기 (복원)",
            .sync_import_desc: "백업 내 모든 파일 선택",
            
            .god_active: "갓 모드: 활성",
            .god_inactive: "갓 모드: 비활성",
            .god_system_activated: "시스템 활성화됨",
            .god_enable_guide: "기능을 사용하려면 스위치를 켜세요.",
            .god_locked_guide: "시스템 잠김: 활성화하려면 API KEY와 ENGINE ID를 모두 입력하세요.",
            .god_api_key: "API KEY",
            .god_enter_key: "API KEY 입력...",
            .god_engine_id: "검색 엔진 ID (CX)",
            .god_enter_id: "ENGINE ID 입력...",
            
            .db_military_desc: "2,000개 이상의 군사 모델 데이터.",
            .db_car_desc: "유명한 광범위한 자동차 카탈로그.",
            
            .pilot_id: "파일럿 식별",
            .rank_prefix: "계급: ",
            .fav_maker: "선호 제조사",
            .wish_list: "위시리스트",
            .exp_level: "경험 레벨",
            .comp_rate: "완성률",
            .select_style: "스타일 선택",
            .reset_style: "자동 감지로 초기화",
            .close: "닫기",
            .share_card: "카드 공유",
            .share_list: "리스트 공유",
            .btn_purchased: "구매 완료",
            
            .unit_units: "기",
            .unit_boxes: "박스",
            .unit_items: "개",
            
            .sidebar_all: "사이버 격납고",
            .sidebar_wish: "위시리스트",
            .sidebar_reserved: "예약됨",
            .sidebar_stock: "미조립 (재고)",
            .ipad_wish_empty: "목록이 비었습니다",
            .ipad_wish_empty_desc: "위의 검색창을 사용하여 원하는 유닛을 추가하세요.",
            .ipad_select_module: "모듈 선택",
            
            .btn_add_unit: "유닛 추가",
            .btn_filter: "필터",
            
            .status_all: "전체",
            .status_wish: "위시",
            .status_reserved: "예약됨",
            .status_stock: "재고",
            .status_wip: "작업중",
            .status_done: "완성"
        ],
        .th: [
            .stats_logged: "ทั้งหมด",
            .stats_stock: "ดองไว้",
            .stats_const: "ระหว่างทำ",
            .stats_done: "เสร็จแล้ว",
            
            .cmd_title: " เมนู",
            .cmd_status_title: "สถานะนักบิน",
            .cmd_status_desc: "ตรวจสอบยศ",
            .cmd_sync_title: "ซิงค์ข้อมูล",
            .cmd_sync_desc: "เชื่อมต่ออุปกรณ์",
            .cmd_slide_title: "สไลด์โชว์",
            .cmd_slide_desc: "ดูคอลเลกชัน",
            .cmd_system_title: "ระบบ",
            .cmd_system_desc: "ตั้งค่า & สำรองข้อมูล",
            .cmd_close_guide: "แตะลูกแก้วเพื่อปิด",
            
            .settings_title: "เทอร์มินัลระบบ",
            .settings_language: "ภาษา",
            .settings_language_note: "เรียงตามรหัสภาษา ISO 639-1",
            .settings_theme: "สีธีม",
            .settings_library: "จัดการคลัง",
            .settings_cloud: "คลาวด์ (iCloud)",
            .settings_sync: "ซิงค์และสำรองข้อมูล",
            .settings_godmode: "โหมดพระเจ้า (Google API)",
            .settings_dbstore: "ร้านฐานข้อมูล",
            .settings_sysinfo: "ข้อมูลระบบ",
            
            .lib_manage_title: "จัดการรายการ",
            .lib_manage_desc: "แก้ไข / ทำงานเป็นชุด",
            .lib_missing_title: "ลิงก์ที่หายไป",
            .lib_missing_desc_pre: "รูปที่ขาด: กล่อง ",
            .lib_missing_desc_post: " / เสร็จ ",
            .lib_repair_title: "ซ่อมแซมรูปภาพ",
            .lib_repair_desc: "ตรวจจับและลบรูปเสียอัตโนมัติ",
            .lib_storage_title: "บำรุงรักษาพื้นที่",
            .lib_storage_desc: "ลบไฟล์รูปภาพที่ไม่ได้ใช้",
            .lib_reset_btn: "รีเซ็ต",
            
            .cloud_low_data: "โหมดข้อมูลต่ำ",
            .cloud_low_data_desc: "บันทึกรูปเว็บลง Photos เพื่อประหยัดพื้นที่",
            .cloud_migrate_title: "ย้ายไปคลาวด์",
            .cloud_migrate_desc: "ย้ายรูปภาพที่มีอยู่ไปยังอัลบั้ม",
            
            .sync_direct_title: "ซิงค์โดยตรง",
            .sync_direct_desc: "ซิงค์กับอุปกรณ์ใกล้เคียง",
            .sync_export_title: "ส่งออกข้อมูล (สำรอง)",
            .sync_export_desc: "ส่งออกข้อมูลสำรองพร้อมรูปภาพ",
            .sync_import_title: "นำเข้าข้อมูล (กู้คืน)",
            .sync_import_desc: "เลือกไฟล์ทั้งหมดในข้อมูลสำรอง",
            
            .god_active: "โหมดพระเจ้า: เปิด",
            .god_inactive: "โหมดพระเจ้า: ปิด",
            .god_system_activated: "ระบบเปิดใช้งานแล้ว",
            .god_enable_guide: "เปิดสวิตช์เพื่อใช้งาน",
            .god_locked_guide: "ระบบล็อค: ป้อน API KEY และ ENGINE ID",
            .god_api_key: "API KEY",
            .god_enter_key: "ป้อน API KEY...",
            .god_engine_id: "รหัสเครื่องมือค้นหา (CX)",
            .god_enter_id: "ป้อน ENGINE ID...",
            
            .db_military_desc: "ข้อมูลโมเดลทหารกว่า 2,000 รายการ",
            .db_car_desc: "แคตตาล็อกรถยนต์ที่ครอบคลุม",
            
            .pilot_id: "ระบุตัวตนนักบิน",
            .rank_prefix: "ยศ: ",
            .fav_maker: "ค่ายที่ชอบ",
            .wish_list: "รายการที่อยากได้",
            .exp_level: "ระดับประสบการณ์",
            .comp_rate: "อัตราการเสร็จ",
            .select_style: "เลือกสไตล์",
            .reset_style: "รีเซ็ตเป็นอัตโนมัติ",
            .close: "ปิด",
            .share_card: "แชร์การ์ด",
            .share_list: "แชร์รายการ",
            .btn_purchased: "ซื้อแล้ว",
            
            .unit_units: " เครื่อง",
            .unit_boxes: " กล่อง",
            .unit_items: " รายการ",
            
            .sidebar_all: "ไซเบอร์แฮงการ์",
            .sidebar_wish: "รายการที่อยากได้",
            .sidebar_reserved: "จองแล้ว",
            .sidebar_stock: "ดองไว้ (สต็อก)",
            .sidebar_progress: "กำลังสร้าง",
            .sidebar_complete: "เสร็จสมบูรณ์",
            .sidebar_slideshow: "สไลด์เด็ค",
            .sidebar_settings: "ตั้งค่าระบบ",
            .sidebar_modules: "โมดูล",
            .sidebar_system: "ระบบ",
            
            .ipad_acquire_unit: "รับหน่วยใหม่",
            .ipad_search_placeholder: "ค้นหาหน่วยใหม่...",
            .ipad_scan: "สแกน",
            .ipad_scanning: "กำลังสแกน...",
            .ipad_search_results: "ผลการค้นหา",
            .ipad_wish_empty: "รายการว่างเปล่า",
            .ipad_wish_empty_desc: "ใช้แถบค้นหาด้านบนเพื่อเพิ่มหน่วย",
            .ipad_select_module: "เลือกโมดูล"
        ],
        .de: [
            .stats_logged: "GESAMT",
            .stats_stock: "LAGER",
            .stats_const: "IN ARBEIT",
            .stats_done: "FERTIG",
            
            .cmd_title: " MENÜ",
            .cmd_status_title: "PILOTENSTATUS",
            .cmd_status_desc: "Rang prüfen",
            .cmd_sync_title: "DATENSYNC",
            .cmd_sync_desc: "Geräte verbinden",
            .cmd_slide_title: "DIASHOW",
            .cmd_slide_desc: "Sammlung ansehen",
            .cmd_system_title: "SYSTEM",
            .cmd_system_desc: "Konfig & Backup",
            .cmd_close_guide: "ORB TIPPEN ZUM SCHLIESSEN",
            
            .settings_title: "SYSTEMTERMINAL",
            .settings_language: "SPRACHE",
            .settings_language_note: "Sortiert nach ISO 639-1 Code.",
            .settings_theme: "THEMENFARBE",
            .settings_library: "BIBLIOTHEKVERWALTUNG",
            .settings_cloud: "CLOUD-SPEICHER (iCloud)",
            .settings_sync: "SYNC & BACKUP",
            .settings_godmode: "GOTT-MODUS (Google API)",
            .settings_dbstore: "DATENBANK-STORE",
            .settings_sysinfo: "SYSTEMINFO",
            
            .lib_manage_title: "ARTIKELVERWALTUNG",
            .lib_manage_desc: "Bearbeiten / Stapelverarbeitung",
            .lib_missing_title: "FEHLENDE LINKS",
            .lib_missing_desc_pre: "Bilder fehlen: BOX ",
            .lib_missing_desc_post: " / FERTIG ",
            .lib_repair_title: "BILDREPARATUR",
            .lib_repair_desc: "Defekte Bilder automatisch erkennen & löschen",
            .lib_storage_title: "SPEICHERWARTUNG",
            .lib_storage_desc: "Ungenutzte Bilddateien löschen",
            .lib_reset_btn: "RESET",
            
            .cloud_low_data: "Datensparmodus",
            .cloud_low_data_desc: "Webbilder in Fotos speichern, um Platz zu sparen.",
            .cloud_migrate_title: "IN CLOUD VERSCHIEBEN",
            .cloud_migrate_desc: "Bestehende Bilder in Alben verschieben",
            
            .sync_direct_title: "DIREKT-SYNC",
            .sync_direct_desc: "Direkt mit Geräten in der Nähe synchronisieren",
            .sync_export_title: "DATENEXPORT (BACKUP)",
            .sync_export_desc: "Vollständiges Backup mit Bildern exportieren",
            .sync_import_title: "DATENIMPORT (RESTORE)",
            .sync_import_desc: "Alle Dateien im Backup auswählen",
            
            .god_active: "GOTT-MODUS: AKTIV",
            .god_inactive: "GOTT-MODUS: INAKTIV",
            .god_system_activated: "SYSTEM AKTIVIERT",
            .god_enable_guide: "Schalter einschalten, um Funktionen zu aktivieren.",
            .god_locked_guide: "SYSTEM GESPERRT: Geben Sie API KEY und ENGINE ID ein.",
            .god_api_key: "API KEY",
            .god_enter_key: "API KEY EINGEBEN...",
            .god_engine_id: "SUCHMASCHINEN-ID (CX)",
            .god_enter_id: "ENGINE ID EINGEBEN...",
            
            .db_military_desc: "Über 2.000 Militärmodelldaten.",
            .db_car_desc: "Berühmter umfangreicher Autokatalog.",
            
            .pilot_id: "PILOTENIDENTIFIKATION",
            .rank_prefix: "RANG: ",
            .fav_maker: "LIEBLINGSHERSTELLER",
            .wish_list: "WUNSCHLISTE",
            .exp_level: "EXP LEVEL",
            .comp_rate: "ABSCHLUSSRATE",
            .select_style: "STIL WÄHLEN",
            .reset_style: "AUF AUTOMATISCH ZURÜCKSETZEN",
            .close: "SCHLIESSEN",
            .share_card: "KARTE TEILEN",
            .share_list: "LISTE TEILEN",
            .btn_purchased: "GEKAUFT",
            
            .unit_units: " EINH.",
            .unit_boxes: " BOXEN",
            .unit_items: " ELEMENTE",
            
            .sidebar_all: "CYBER HANGAR",
            .sidebar_wish: "WUNSCHLISTE",
            .sidebar_reserved: "RESERVIERT",
            .sidebar_stock: "LAGERBESTAND",
            .sidebar_progress: "IM BAU",
            .sidebar_complete: "FERTIGGESTELLT",
            .sidebar_slideshow: "SLIDE DECK",
            .sidebar_settings: "SYSTEMKONFIG.",
            .sidebar_modules: "MODULE",
            .sidebar_system: "SYSTEM",
            
            .ipad_acquire_unit: "NEUE EINHEIT ERWERBEN",
            .ipad_search_placeholder: "NEUE EINHEIT SUCHEN...",
            .ipad_scan: "SCANNEN",
            .ipad_scanning: "DATENSTROM SCANNEN...",
            .ipad_search_results: "SUCHERGEBNISSE",
            .ipad_wish_empty: "WUNSCHLISTE LEER",
            .ipad_wish_empty_desc: "Nutzen Sie die Suchleiste oben, um Einheiten hinzuzufügen.",
            .ipad_select_module: "MODUL WÄHLEN"
        ],
        .fr: [
            .stats_logged: "TOTAL",
            .stats_stock: "STOCK",
            .stats_const: "EN COURS",
            .stats_done: "TERMINÉ",
            
            .cmd_title: " MENU",
            .cmd_status_title: "STATUT PILOTE",
            .cmd_status_desc: "Vérifier le rang",
            .cmd_sync_title: "SYNCHRO",
            .cmd_sync_desc: "Connecter appareils",
            .cmd_slide_title: "DIAPORAMA",
            .cmd_slide_desc: "Voir la collection",
            .cmd_system_title: "SYSTÈME",
            .cmd_system_desc: "Config & Sauvegarde",
            .cmd_close_guide: "APPUYER SUR L'ORBE POUR FERMER",
            
            .settings_title: "TERMINAL SYSTÈME",
            .settings_language: "LANGUE",
            .settings_language_note: "Trié par code ISO 639-1.",
            .settings_theme: "COULEUR THÈME",
            .settings_library: "GESTION BIBLIOTHÈQUE",
            .settings_cloud: "STOCKAGE CLOUD (iCloud)",
            .settings_sync: "SYNCHRO & SAUVEGARDE",
            .settings_godmode: "GOD MODE (Google API)",
            .settings_dbstore: "MAGASIN DE DONNÉES",
            .settings_sysinfo: "INFO SYSTÈME",
            
            .lib_manage_title: "GESTION DES ARTICLES",
            .lib_manage_desc: "Édition / Opération par lot",
            .lib_missing_title: "LIENS MANQUANTS",
            .lib_missing_desc_pre: "Images manquantes : BOÎTE ",
            .lib_missing_desc_post: " / TERMINÉ ",
            .lib_repair_title: "RÉPARATION D'IMAGE",
            .lib_repair_desc: "Détection et suppression auto des images",
            .lib_storage_title: "MAINTENANCE STOCKAGE",
            .lib_storage_desc: "Supprimer les fichiers images inutilisés",
            .lib_reset_btn: "RÉINIT",
            
            .cloud_low_data: "Mode données réduites",
            .cloud_low_data_desc: "Sauvegarder images web dans Photos pour économiser.",
            .cloud_migrate_title: "MIGRER VERS LE CLOUD",
            .cloud_migrate_desc: "Déplacer les images vers des albums",
            
            .sync_direct_title: "SYNCHRO DIRECTE",
            .sync_direct_desc: "Synchro directe avec appareils proches",
            .sync_export_title: "EXPORT DONNÉES (SAUVEGARDE)",
            .sync_export_desc: "Exporter sauvegarde complète avec images",
            .sync_import_title: "IMPORT DONNÉES (RESTAURER)",
            .sync_import_desc: "Sélectionner tous les fichiers",
            
            .god_active: "GOD MODE: ACTIVE",
            .god_inactive: "GOD MODE: INACTIVE",
            .god_system_activated: "SYSTÈME ACTIVÉ",
            .god_enable_guide: "Allumer l'interrupteur pour activer.",
            .god_locked_guide: "SYSTÈME VERROUILLÉ : Entrez API KEY et ENGINE ID.",
            .god_api_key: "API KEY",
            .god_enter_key: "ENTREZ API KEY...",
            .god_engine_id: "ID MOTEUR DE RECHERCHE (CX)",
            .god_enter_id: "ENTREZ ENGINE ID...",
            
            .db_military_desc: "Plus de 2 000 modèles militaires.",
            .db_car_desc: "Catalogue automobile étendu célèbre.",
            
            .pilot_id: "IDENTIFICATION PILOTE",
            .rank_prefix: "RANG: ",
            .fav_maker: "FABRICANT FAVORI",
            .wish_list: "LISTE DE SOUHAITS",
            .exp_level: "NIVEAU D'EXP",
            .comp_rate: "TAUX D'ACHÈVEMENTS",
            .select_style: "CHOISIR STYLE",
            .reset_style: "RÉINITIALISER EN AUTO",
            .close: "FERMER",
            .share_card: "PARTAGER CARTE",
            .share_list: "PARTAGER LISTE",
            .btn_purchased: "ACHETÉ",
            
            .unit_units: " UNITÉS",
            .unit_boxes: " BOÎTES",
            .unit_items: " ARTICLES",
            
            .sidebar_all: "HANGAR CYBER",
            .sidebar_wish: "LISTE DE SOUHAITS",
            .sidebar_reserved: "RÉSERVÉ",
            .sidebar_stock: "STOCK",
            .sidebar_progress: "EN CONSTRUCTION",
            .sidebar_complete: "TERMINÉ",
            .sidebar_slideshow: "TERRASSE",
            .sidebar_settings: "CONFIG SYSTÈME",
            .sidebar_modules: "MODULES",
            .sidebar_system: "SYSTÈME",
            
            .ipad_acquire_unit: "ACQUÉRIR UNITÉ",
            .ipad_search_placeholder: "RECHERCHER...",
            .ipad_scan: "SCANNER",
            .ipad_scanning: "SCAN DU FLUX DE DONNÉES...",
            .ipad_search_results: "RÉSULTATS RECHERCHE",
            .ipad_wish_empty: "LISTE VIDE",
            .ipad_wish_empty_desc: "Utilisez la barre de recherche pour ajouter.",
            .ipad_select_module: "SÉLECTIONNER MODULE"
        ]
    ]
}
