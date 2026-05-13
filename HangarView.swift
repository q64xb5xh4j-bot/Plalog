import SwiftUI
import SwiftData

struct HangarView: View {
    @Binding var showBridge: Bool
    @Query(sort: \Kit.createdDate, order: .reverse) private var allKits: [Kit]
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Filters
    @State private var selectedFilter: Int? = nil // Status Filter
    @State private var filterSeries: String? = nil
    @State private var filterMaker: String? = nil
    @State private var filterGrade: String? = nil
    
    @State private var selectedKit: Kit? = nil
    @State private var showAddSheet: Bool = false
    @State private var showSlideshowConfig: Bool = false // [NEW] Visual Archive State
    
    // Grid Setup
    let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 20, alignment: .top)
    ]
    
    var body: some View {
        ZStack {
            // NOTE: Background provided by MainTabView
            
            VStack(spacing: 0) {
                 // Header Console
                VStack(spacing: 8) {
                    // Top Bar: Status & Add Button
                    HStack {
                         // [NEW] Bridge / System Button
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            withAnimation { showBridge = true }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "cpu.fill")
                                Text("BRIDGE")
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                themeManager.currentTheme.mainColor.opacity(0.1)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(themeManager.currentTheme.mainColor.opacity(0.5), lineWidth: 1)
                            )
                            .cornerRadius(4)
                        }
                        
                        // [NEW] Visual Archive Button (Prominent)
                        Button {
                            showSlideshowConfig = true
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "play.rectangle.on.rectangle")
                                Text("ARCHIVE")
                            }
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background {
                                themeManager.currentTheme.mainColor.opacity(0.8)
                            }
                            .cornerRadius(4)
                            //.shadow(color: .cyan.opacity(0.5), radius: 4, x: 0, y: 0) // Removed glow for calmer look
                        }
                        
                        Spacer()
                        
                        // [REFINE] Localized Filter Button
                        Menu {
                            Button("CLEAR ALL FILTERS") { clearFilters() }
                            
                            Menu("SERIES") {
                                ForEach(availableSeries, id: \.self) { series in
                                    Button(series) { filterSeries = series }
                                }
                            }
                            Menu("MAKER") {
                                ForEach(availableMakers, id: \.self) { maker in
                                    Button(maker) { filterMaker = maker }
                                }
                            }
                            Menu("GRADE") {
                                ForEach(availableGrades, id: \.self) { grade in
                                    Button(grade) { filterGrade = grade }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                // Text(LanguageManager.shared.t(.btn_filter)) // Icon only to save space
                            }
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(hasActiveFilters ? .white : themeManager.currentTheme.mainColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4) // Compact vertical
                            .background {
                                if hasActiveFilters {
                                    themeManager.currentTheme.mainColor
                                } else {
                                    themeManager.currentTheme.mainColor.opacity(0.1)
                                }
                            }
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(themeManager.currentTheme.mainColor, lineWidth: 1)
                                    .opacity(0.5)
                            )
                        }
                        
                        // [REFINE] Localized Add Button
                        Button {
                             showAddSheet = true
                             let impact = UIImpactFeedbackGenerator(style: .medium)
                             impact.impactOccurred()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text(LanguageManager.shared.t(.btn_add_unit))
                            }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white) // Always white text for contrast
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background { themeManager.currentTheme.mainColor.opacity(0.8) } // clear/strong background
                            .cornerRadius(8)
                        }
                    }
                    .padding(.top, 60) // Safe Area
                    .padding(.horizontal, 20)
                    
                    // Active Filter Indicators
                    if hasActiveFilters {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                if let s = filterSeries { filterTag(label: s) { filterSeries = nil } }
                                if let m = filterMaker { filterTag(label: m) { filterMaker = nil } }
                                if let g = filterGrade { filterTag(label: g) { filterGrade = nil } }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                    
                    // Compact Status HUD (2 Rows, Equal Width)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            FilterChip(label: LanguageManager.shared.t(.status_all), icon: "square.grid.2x2", isSystemIcon: true, value: nil, selectedFilter: $selectedFilter)
                            FilterChip(label: LanguageManager.shared.t(.status_wish), icon: "wish", value: 0, selectedFilter: $selectedFilter)
                            FilterChip(label: LanguageManager.shared.t(.status_reserved), icon: "reservation", value: 1, selectedFilter: $selectedFilter)
                        }
                        HStack(spacing: 6) {
                            FilterChip(label: LanguageManager.shared.t(.status_stock), icon: "stock", value: 2, selectedFilter: $selectedFilter)
                            FilterChip(label: LanguageManager.shared.t(.status_wip), icon: "inprogress", value: 3, selectedFilter: $selectedFilter)
                            FilterChip(label: LanguageManager.shared.t(.status_done), icon: "complete", value: 4, selectedFilter: $selectedFilter)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                }
                .background(
                    LinearGradient(
                        colors: [Color(UIColor.systemBackground).opacity(0.9), Color(UIColor.systemBackground).opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                // List Content
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredKits) { kit in
                            Button {
                                selectedKit = kit
                            } label: {
                                HoloKitCard(kit: kit)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    Spacer().frame(height: 100)
                }
            }
        }
        .sheet(item: $selectedKit) { _ in
            KitDetailOverlay(kit: $selectedKit)
        }
        .fullScreenCover(isPresented: $showAddSheet) {
            AddRegistrationFlowOverlay(isPresented: $showAddSheet)
        }
        .fullScreenCover(isPresented: $showSlideshowConfig) {
            iPhoneSlideshowConfigOverlay(isPresented: $showSlideshowConfig)
        }
    }
    
    // MARK: - Computed Properties
    
    var filteredKits: [Kit] {
        allKits.filter { kit in
            let statusMatch = (selectedFilter == nil) || (kit.statusValue == selectedFilter)
            let seriesMatch = (filterSeries == nil) || (kit.series == filterSeries)
            let makerMatch = (filterMaker == nil) || (kit.maker == filterMaker)
            let gradeMatch = (filterGrade == nil) || (kit.grade == filterGrade)
            return statusMatch && seriesMatch && makerMatch && gradeMatch
        }
    }
    
    var hasActiveFilters: Bool {
        filterSeries != nil || filterMaker != nil || filterGrade != nil
    }
    
    var availableSeries: [String] {
        Array(Set(allKits.map { $0.series })).sorted()
    }
    var availableMakers: [String] {
        Array(Set(allKits.map { $0.maker })).sorted()
    }
    var availableGrades: [String] {
        Array(Set(allKits.map { $0.grade })).filter { !$0.isEmpty }.sorted()
    }
    
    private func clearFilters() {
        withAnimation {
            filterSeries = nil
            filterMaker = nil
            filterGrade = nil
        }
    }
    
    @ViewBuilder
    private func filterTag(label: String, action: @escaping () -> Void) -> some View {
        HStack {
            Text(label).font(.caption).bold()
            Button(action: action) {
                Image(systemName: "xmark.circle.fill")
            }
        }
        .padding(6)
        .background(themeManager.currentTheme.mainColor.opacity(0.2))
        .foregroundStyle(themeManager.currentTheme.mainColor)
        .cornerRadius(4)
    }
}

// MARK: - Components

struct FilterChip: View {
    let label: String
    let icon: String?
    let isSystemIcon: Bool
    let value: Int?
    @Binding var selectedFilter: Int?
    @ObservedObject private var themeManager = ThemeManager.shared
    
    init(label: String, icon: String? = nil, isSystemIcon: Bool = false, value: Int?, selectedFilter: Binding<Int?>) {
        self.label = label
        self.icon = icon
        self.isSystemIcon = isSystemIcon
        self.value = value
        self._selectedFilter = selectedFilter
    }
    
    var isSelected: Bool { selectedFilter == value }
    
    var body: some View {
        Button {
             withAnimation { selectedFilter = value }
             let impact = UIImpactFeedbackGenerator(style: .light)
             impact.impactOccurred()
        } label: {
            // Content
            HStack(spacing: 6) {
                if let icon = icon {
                    if isSystemIcon {
                        Image(systemName: icon)
                            .font(.system(size: 10, weight: .bold))
                    } else {
                        Image(icon)
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                    }
                }
                
                Text(label)
                    .font(.caption.bold().monospaced())
            }
            .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : .gray)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background {
                if isSelected {
                    themeManager.currentTheme.mainColor.opacity(0.1)
                } else {
                    Color.clear
                }
            }
            // Bottom Border
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : .gray.opacity(0.3)),
                alignment: .bottom
            )
            // Leading Border
            .overlay(
                Rectangle()
                    .frame(width: 1)
                    .foregroundStyle(isSelected ? themeManager.currentTheme.mainColor : .gray.opacity(0.3)),
                alignment: .leading
            )
            .fixedSize(horizontal: false, vertical: true) // Prevent vertical stretching
        }
    }
}

struct HoloKitCard: View {
    let kit: Kit
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Area (Clear View)
            ZStack {
                // Background
                Color(UIColor.secondarySystemBackground)
                
                let showUserPhoto = (kit.statusValue == 4 && kit.completedImageURLString != nil && !kit.completedImageURLString!.isEmpty)
                let targetData = showUserPhoto ? kit.completedImageData : kit.imageData
                let targetPath = showUserPhoto ? kit.completedImageURLString : kit.imageURLString
                
                if (targetData != nil) || (targetPath != nil && !targetPath!.isEmpty) {
                    UniversalImageView(imageData: targetData, imagePath: targetPath)
                        .scaledToFit()
                } else {
                     Image(systemName: "cube.transparent")
                        .font(.largeTitle)
                        .foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.3))
                }
                
                // Status Badge
                if kit.statusValue == 4 {
                    VStack {
                        HStack {
                            Spacer()
                            Image("complete")
                                .resizable()
                                .renderingMode(.template)
                                .scaledToFit()
                                .frame(width: 30, height: 30) // Slightly larger for impact
                                .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0)) // Gold
                                .shadow(color: .black.opacity(0.5), radius: 2)
                        }
                        Spacer()
                    }
                    .padding(6)
                }
            }
            .frame(height: 140)
            .border(width: 1, edges: [.top, .leading, .trailing], color: themeManager.currentTheme.mainColor.opacity(0.3))
            
            // Meta Info (Data Plate)
            VStack(alignment: .leading, spacing: 4) {
                Text(kit.title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(height: 24, alignment: .topLeading)
                
                HStack {
                     Text(kit.maker.uppercased())
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.horizontal, 4)
                        .background(themeManager.currentTheme.mainColor.opacity(0.2))
                    
                    Spacer()
                    
                    Text(kit.grade)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.gray)
                }
            }
            .padding(8)
            .background(Color(UIColor.systemBackground).opacity(0.9))
            .border(width: 1, edges: [.bottom, .leading, .trailing], color: themeManager.currentTheme.mainColor.opacity(0.3))
        }
        .background(Color(UIColor.systemBackground))
        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.1), radius: 3, x: 0, y: 0)
    }
}

extension View {
    func border(width: CGFloat, edges: [Edge], color: Color) -> some View {
        overlay(
            EdgeBorder(width: width, edges: edges).foregroundColor(color)
        )
    }
}

struct EdgeBorder: Shape {
    var width: CGFloat
    var edges: [Edge]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for edge in edges {
            var x: CGFloat {
                switch edge {
                case .top, .bottom, .leading: return rect.minX
                case .trailing: return rect.maxX - width
                }
            }

            var y: CGFloat {
                switch edge {
                case .top, .leading, .trailing: return rect.minY
                case .bottom: return rect.maxY - width
                }
            }

            var w: CGFloat {
                switch edge {
                case .top, .bottom: return rect.width
                case .leading, .trailing: return width
                }
            }

            var h: CGFloat {
                switch edge {
                case .top, .bottom: return width
                case .leading, .trailing: return rect.height
                }
            }
            path.addRect(CGRect(x: x, y: y, width: w, height: h))
        }
        return path
    }
}
