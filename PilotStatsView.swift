import SwiftUI
import Charts
import PhotosUI

// MARK: - FIXED RENDER VIEW (For Image Sharing)
struct PilotStatsRenderView: View {
    let allKits: [Kit]
    var userName: String = "COMMANDER"
    var profileImage: UIImage? = nil
    var rankTitle: String // ✅ Passed explicit rank title (computed before render)
    var pilotStyle: PilotStyle
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Computed Stats
    var completedCount: Int { allKits.filter { $0.statusValue == 4 }.count }
    var stockCount: Int { allKits.filter { $0.statusValue == 2 }.count }
    var constructingCount: Int { allKits.filter { $0.statusValue == 3 }.count }
    var wishListCount: Int { allKits.filter { $0.statusValue == 0 }.count }
    var totalOwned: Int { allKits.filter { $0.statusValue != 0 }.count }
    
    var completionRate: Double {
        guard totalOwned > 0 else { return 0 }
        return Double(completedCount) / Double(totalOwned)
    }
    
    
    // Rank logic moved to RankManager (passed in)
    
    var topMaker: String {
        let makers = allKits.filter { $0.statusValue != 0 }.map { $0.maker }
        let counts = Dictionary(grouping: makers, by: { $0 }).mapValues { $0.count }
        return counts.sorted { $0.value > $1.value }.first?.key ?? "N/A"
    }

    // Fixed Render Size: 1080 x 1350 (4:5 Ratio)
    var body: some View {
        ZStack {
            Color.black
            
            // Decor
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "globe.asia.australia.fill")
                        .font(.system(size: 300))
                        .foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.1))
                        .offset(x: 100, y: 100)
                }
            }
            
            // Frame Line
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: 40, y: 40))
                    path.addLine(to: CGPoint(x: geo.size.width - 40, y: 40))
                    path.addLine(to: CGPoint(x: geo.size.width - 40, y: 150))
                    path.addLine(to: CGPoint(x: geo.size.width - 40, y: geo.size.height - 40))
                    path.addLine(to: CGPoint(x: 40, y: geo.size.height - 40))
                    path.closeSubpath()
                }
                .stroke(themeManager.currentTheme.mainColor, lineWidth: 8)
                .opacity(0.5)
            }
            
            VStack(spacing: 30) {
                // Header: ID CARD
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PILOT IDENTIFICATION").font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                        Text(userName).font(.system(size: 48, weight: .black, design: .rounded)).foregroundStyle(.white).tracking(2)
                        
                        Text("RANK: \(rankTitle)")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(themeManager.currentTheme.mainColor.opacity(0.2)).cornerRadius(4)
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(themeManager.currentTheme.mainColor, lineWidth: 2)
                        // Icon Overlay based on Style for context
                        Image(systemName: pilotStyle.icon)
                            .font(.system(size: 20))
                            .foregroundStyle(themeManager.currentTheme.mainColor)
                            .padding(4)
                            .background(Color.black)
                            .clipShape(Circle())
                            .offset(x: 40, y: 40)
                        
                        if let image = profileImage {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill").font(.system(size: 60)).foregroundStyle(.gray)
                        }
                    }.frame(width: 120, height: 120)
                }
                .padding(.horizontal, 60).padding(.top, 80)
                
                Divider().background(Color.gray)
                
                // Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
                    StatBox(label: LanguageManager.shared.t(.stats_logged), value: "\(totalOwned)", unit: LanguageManager.shared.t(.unit_units), theme: themeManager.currentTheme)
                    StatBox(label: LanguageManager.shared.t(.stats_done), value: "\(completedCount)", unit: LanguageManager.shared.t(.unit_units), theme: themeManager.currentTheme)
                    StatBox(label: LanguageManager.shared.t(.stats_stock), value: "\(stockCount)", unit: LanguageManager.shared.t(.unit_boxes), theme: themeManager.currentTheme)
                    StatBox(label: LanguageManager.shared.t(.stats_const), value: "\(constructingCount)", unit: LanguageManager.shared.t(.unit_units), theme: themeManager.currentTheme)
                }
                .padding(.horizontal, 60)
                
                // Achievement Bar
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(LanguageManager.shared.t(.comp_rate)).font(.system(size: 14, weight: .bold, design: .monospaced)).foregroundStyle(.gray)
                        Spacer()
                        Text("\(Int(completionRate * 100))%").font(.system(size: 24, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                    }
                    GeometryReader { barGeo in
                        ZStack(alignment: .leading) {
                            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 20)
                            Rectangle().fill(LinearGradient(colors: [themeManager.currentTheme.mainColor, .white], startPoint: .leading, endPoint: .trailing))
                                .frame(width: barGeo.size.width * completionRate, height: 20)
                        }
                    }.frame(height: 20)
                }.padding(.horizontal, 60)
                
                // Additional Info
                HStack(spacing: 40) {
                    VStack(alignment: .leading) {
                        Text(LanguageManager.shared.t(.fav_maker)).font(.caption).foregroundStyle(.gray)
                        Text(topMaker).font(.title).fontWeight(.bold).foregroundStyle(.white).lineLimit(1)
                    }
                    VStack(alignment: .leading) {
                        Text(LanguageManager.shared.t(.wish_list)).font(.caption).foregroundStyle(.gray)
                        Text("\(wishListCount)\(LanguageManager.shared.t(.unit_items))").font(.title).fontWeight(.bold).foregroundStyle(.white)
                    }
                    Spacer()
                }.padding(.horizontal, 60)
                
                Spacer()
                
                // Footer
                // Footer
                // Footer
                HStack {
                    Text("\(LanguageManager.shared.t(.exp_level)): \(rankTitle)_Class").font(.system(size: 50, weight: .heavy, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.05)).rotationEffect(.degrees(-90)).offset(x: -20)
                    Spacer()
                    VStack(alignment: .trailing) {
                        Image(systemName: "qrcode").font(.system(size: 60)).foregroundStyle(.white)
                        Text("PLALOG_AUTH").font(.caption).foregroundStyle(.gray)
                    }
                }.padding(40)
        }
        .frame(width: 1080, height: 1350)
        .background(Color.black)
    }
    }
}

// MARK: - RESPONSIVE SCREEN VIEW (For Display)
struct PilotStatsScreenView: View {
    let allKits: [Kit]
    var userName: String = "COMMANDER"
    var profileImage: UIImage?
    var onTapAvatar: () -> Void
    var onTapName: () -> Void 
    
    // Rank Inputs
    var rankTitle: String
    var pilotStyle: PilotStyle
    var onStyleChange: (PilotStyle) -> Void // Callback to change style
    var onResetStyle: () -> Void // Callback to reset style
    
    @State private var showStyleSelector = false
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    // Logic extraction to View Model or duplicate for safety? Duplicating for now to ensure consistency.
    var completedCount: Int { allKits.filter { $0.statusValue == 4 }.count }
    var stockCount: Int { allKits.filter { $0.statusValue == 2 }.count }
    var constructingCount: Int { allKits.filter { $0.statusValue == 3 }.count }
    var wishListCount: Int { allKits.filter { $0.statusValue == 0 }.count }
    var totalOwned: Int { allKits.filter { $0.statusValue != 0 }.count }
    
    var completionRate: Double {
        guard totalOwned > 0 else { return 0 }
        return Double(completedCount) / Double(totalOwned)
    }
    
    var rank: String {
        switch completedCount {
        case 0..<5: return "CADET"
        case 5..<15: return "PILOT"
        case 15..<30: return "VETERAN"
        case 30..<50: return "ACE"
        case 50..<100: return "COMMANDER"
        default: return "NEWTYPE"
        }
    }
    
    var topMaker: String {
        let makers = allKits.filter { $0.statusValue != 0 }.map { $0.maker }
        let counts = Dictionary(grouping: makers, by: { $0 }).mapValues { $0.count }
        return counts.sorted { $0.value > $1.value }.first?.key ?? "N/A"
    }

    var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Background Decor
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "globe.asia.australia.fill")
                            .font(.system(size: isLandscape ? 400 : 300))
                            .foregroundStyle(themeManager.currentTheme.mainColor.opacity(0.1))
                            .offset(x: 100, y: 100)
                    }
                }
                
                if isLandscape {
                    // LANDSCAPE LAYOUT: Side by Side
                    HStack(spacing: 40) {
                        // Left Column: Profile
                        VStack(alignment: .leading, spacing: 30) {
                            HStack(alignment: .center) {
                                Button { onTapAvatar() } label: {
                                    ZStack {
                                        Circle().stroke(themeManager.currentTheme.mainColor, lineWidth: 3)
                                        if let image = profileImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 140, height: 140)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.fill").font(.system(size: 80)).foregroundStyle(.gray)
                                        }
                                        Image(systemName: "pencil.circle.fill")
                                            .font(.title)
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(themeManager.currentTheme.mainColor))
                                            .offset(x: 50, y: 50)
                                    }.frame(width: 140, height: 140)
                                }.buttonStyle(.plain)
                                
                                VStack(alignment: .leading) {
                                    Text("PILOT IDENTIFICATION").font(.caption).foregroundStyle(.gray)
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(userName).font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white)
                                        Image(systemName: "pencil").font(.title2).foregroundStyle(.gray.opacity(0.5))
                                    }
                                    .onTapGesture { onTapName() }
                                    
                                    // Style Show Button
                                    Button {
                                        showStyleSelector = true
                                        LocalHaptics.select()
                                    } label: {
                                        Text("\(langManager.t(.rank_prefix))\(rankTitle) ▾")
                                            .font(.title3.weight(.bold).monospaced())
                                            .foregroundStyle(themeManager.currentTheme.mainColor)
                                            .padding(.vertical, 4).padding(.horizontal, 10)
                                            .background(themeManager.currentTheme.mainColor.opacity(0.1)).cornerRadius(4)
                                    }
                                }
                            }
                            
                            Divider().background(Color.gray)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                InfoRow(label: "FAVORITE MAKER", value: topMaker)
                                InfoRow(label: "WISH LIST", value: "\(wishListCount) ITEMS")
                                InfoRow(label: "FAVORITE MAKER", value: topMaker)
                                InfoRow(label: "WISH LIST", value: "\(wishListCount) ITEMS")
                                InfoRow(label: "EXP LEVEL", value: "\(rankTitle)_Class")
                            }
                            
                            Spacer()
                        }
                        .frame(width: max(0, geo.size.width * 0.4))
                        
                        Divider().background(Color.gray)
                        
                        // Right Column: Stats
                        ScrollView {
                            VStack(alignment: .leading, spacing: 40) {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 30) {
                                    StatBox(label: langManager.t(.stats_logged), value: "\(totalOwned)", unit: langManager.t(.unit_units), theme: themeManager.currentTheme)
                                    StatBox(label: langManager.t(.stats_done), value: "\(completedCount)", unit: langManager.t(.unit_units), theme: themeManager.currentTheme)
                                    StatBox(label: langManager.t(.stats_stock), value: "\(stockCount)", unit: langManager.t(.unit_boxes), theme: themeManager.currentTheme)
                                    StatBox(label: langManager.t(.stats_const), value: "\(constructingCount)", unit: langManager.t(.unit_units), theme: themeManager.currentTheme)
                                }
                                
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Text("COMPLETION RATE").font(.headline.monospaced()).foregroundStyle(.gray)
                                        Spacer()
                                        Text("\(Int(completionRate * 100))%").font(.title.monospaced()).foregroundStyle(.white)
                                    }
                                    GeometryReader { barGeo in
                                        ZStack(alignment: .leading) {
                                            Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 30)
                                            Rectangle().fill(LinearGradient(colors: [themeManager.currentTheme.mainColor, .white], startPoint: .leading, endPoint: .trailing))
                                                .frame(width: barGeo.size.width * completionRate, height: 30)
                                        }
                                    }.frame(height: 30)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                    }
                    .padding(50)
                    
                } else {
                    // PORTRAIT LAYOUT (Flexible, similar to original)
                    VStack(spacing: 30) {
                        // Header
                        HStack {
                            VStack(alignment: .leading) {
                                Text("PILOT IDENTIFICATION").font(.caption.monospaced()).foregroundStyle(.gray)
                                HStack(alignment: .firstTextBaseline) {
                                    Text(userName).font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white)
                                    Image(systemName: "pencil").font(.headline).foregroundStyle(.gray.opacity(0.5))
                                }
                                .onTapGesture { onTapName() }
                                
                                Button {
                                    showStyleSelector = true
                                    LocalHaptics.select()
                                } label: {
                                    Text("\(langManager.t(.rank_prefix))\(rankTitle) ▾").font(.headline.monospaced()).foregroundStyle(themeManager.currentTheme.mainColor)
                                }
                            }
                            Spacer()
                            Button { onTapAvatar() } label: {
                                ZStack {
                                    Circle().stroke(themeManager.currentTheme.mainColor, lineWidth: 2)
                                    if let image = profileImage {
                                        Image(uiImage: image)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 80, height: 80)
                                            .clipShape(Circle())
                                    } else {
                                        Image(systemName: "person.fill").font(.system(size: 50)).foregroundStyle(.gray)
                                    }
                                    Image(systemName: "pencil.circle.fill")
                                            .font(.body)
                                            .foregroundStyle(.white)
                                            .background(Circle().fill(themeManager.currentTheme.mainColor))
                                            .offset(x: 30, y: 30)
                                }.frame(width: 80, height: 80)
                            }.buttonStyle(.plain)
                        }.padding(.horizontal, 40).padding(.top, 60)
                        
                        Divider().background(Color.gray)
                        
                        // Stats
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            StatBox(label: "LOGGED UNITS", value: "\(totalOwned)", unit: "UNITS", theme: themeManager.currentTheme)
                            StatBox(label: "COMPLETED", value: "\(completedCount)", unit: "UNITS", theme: themeManager.currentTheme)
                            StatBox(label: "STOCKPILE", value: "\(stockCount)", unit: "BOXES", theme: themeManager.currentTheme)
                            StatBox(label: "CONSTRUCTING", value: "\(constructingCount)", unit: "UNITS", theme: themeManager.currentTheme)
                        }.padding(.horizontal, 40)
                        
                        // Bar
                        VStack(alignment: .leading) {
                            HStack {
                                Text("COMPLETION RATE").font(.caption.bold().monospaced()).foregroundStyle(.gray)
                                Spacer()
                                Text("\(Int(completionRate * 100))%").font(.title3.bold().monospaced()).foregroundStyle(.white)
                            }
                            GeometryReader { barGeo in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 15)
                                    Rectangle().fill(LinearGradient(colors: [themeManager.currentTheme.mainColor, .white], startPoint: .leading, endPoint: .trailing))
                                        .frame(width: barGeo.size.width * completionRate, height: 15)
                                }
                            }.frame(height: 15)
                        }.padding(.horizontal, 40)
                        
                        Spacer()
                    }
                }
            }
            .sheet(isPresented: $showStyleSelector) {
                PilotStyleSelectionSheet(
                    currentStyle: .constant(pilotStyle), // Using constant here for display, real selection via callback
                    onSelect: onStyleChange,
                    onReset: onResetStyle,
                    totalOwned: totalOwned,
                    completedCount: completedCount,
                    stockCount: stockCount,
                    constructingCount: constructingCount
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    @ViewBuilder
    func InfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundStyle(.gray)
            Text(value).font(.title2).fontWeight(.bold).foregroundStyle(.white)
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String
    let unit: String
    let theme: AppTheme
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.system(size: 12, weight: .bold)).foregroundStyle(theme.mainColor)
            HStack(alignment: .lastTextBaseline) {
                Text(value).font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white)
                Text(unit).font(.system(size: 12)).foregroundStyle(.gray)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

// Wrapper for displaying on screen
struct PilotStatsOverlay: View {
    let allKits: [Kit]
    @Binding var isPresented: Bool
    @State private var showShareSheet = false
    @State private var shareImage: UIImage? = nil
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    // Avatar Logic
    @Binding var profileImage: UIImage?
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var showPhotosPicker = false
    
    // Pilot Name Logic
    @AppStorage("pilotName") private var pilotName: String = "COMMANDER"
    
    // Pilot Style Logic (Auto Detect or Manual)
    @AppStorage("pilotStyleRaw") private var pilotStyleRaw: String = "" // Empty = Auto
    
    @State private var showNameEditAlert = false
    @State private var showDuplicateAlert = false // New Alert for conflicts
    @State private var tempName: String = ""
    
    // Computed Properties for Rank
    var currentStyle: PilotStyle {
        if pilotStyleRaw.isEmpty {
            return RankManager.shared.detectStyle(from: allKits)
        } else {
            return PilotStyle(rawValue: pilotStyleRaw) ?? .standard
        }
    }
    
    var currentRankTitle: String {
        let completed = allKits.filter { $0.statusValue == 4 }.count
        return RankManager.shared.getRankTitle(style: currentStyle, count: completed)
    }

    var body: some View {
        ZStack {
            // Screen View (Responsive)
            PilotStatsScreenView(
                allKits: allKits,
                userName: pilotName,
                profileImage: profileImage,
                onTapAvatar: { showPhotosPicker = true },
                onTapName: { 
                    tempName = pilotName
                    showNameEditAlert = true
                },
                rankTitle: currentRankTitle,
                pilotStyle: currentStyle,
                onStyleChange: { newStyle in
                     // If user selects specific style setup
                     pilotStyleRaw = newStyle.rawValue
                },
                onResetStyle: {
                    pilotStyleRaw = ""
                }
            )
            
            // Buttons Overlay (Floating at bottom)
            VStack {
                Spacer()
                HStack(spacing: 40) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text(langManager.t(.close))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 30)
                            .padding(.vertical, 12)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(30)
                            .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.white.opacity(0.3), lineWidth: 1))
                    }
                    
                    Button(action: {
                        LocalHaptics.select()
                        // Use Fixed Render View for Sharing
                        if let image = ImageRendererHelper.render(view: PilotStatsRenderView(allKits: allKits, userName: pilotName, profileImage: profileImage, rankTitle: currentRankTitle, pilotStyle: currentStyle), size: CGSize(width: 1080, height: 1350)) {
                            shareImage = image
                            showShareSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text(langManager.t(.share_card))
                        }
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.mainColor)
                        .cornerRadius(30)
                        .shadow(color: themeManager.currentTheme.mainColor.opacity(0.5), radius: 10)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $selectedItem, matching: .images)
        // Add option to Reset to Auto if manual
        .contextMenu {
            if !pilotStyleRaw.isEmpty {
                Button("Reset Style to Auto") {
                    pilotStyleRaw = ""
                }
            }
        }
        
        
        .alert("Edit Pilot Name", isPresented: $showNameEditAlert) {
            TextField("Enter Name", text: $tempName)
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                print("🖱️ [PilotStats] Save Button Tapped. Input: '\(tempName)'")
                let trimmed = tempName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { 
                    print("⚠️ [PilotStats] Name is empty. Resetting to COMMANDER.")
                    pilotName = "COMMANDER"; 
                    return 
                }
                let newName = trimmed.uppercased()
                
                // If name hasn't changed, just return
                if newName == pilotName { 
                    print("ℹ️ [PilotStats] Name unchanged (\(newName)). Ignoring.")
                    return 
                }
                
                print("🔄 [PilotStats] Starting async reservation for: \(newName)")
                
                // Async Validation
                Task {
                    let success = await DiscoveryManager.shared.reserveUserName(newName)
                    await MainActor.run {
                        if success {
                            pilotName = newName
                            KeyValueSyncManager.shared.push(key: "pilotName", value: pilotName)
                        } else {
                            // Trigger Duplicate Alert
                            showDuplicateAlert = true
                        }
                    }
                }
            }
        }
        .alert("Name Unavailable", isPresented: $showDuplicateAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This name is already taken by another Commander. Please choose a different name.")
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    profileImage = image
                    saveImageToDisk(image)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
    }
    
    private func saveImageToDisk(_ image: UIImage) {
        guard let data = image.pngData() else { return }
        guard let docURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = docURL.appendingPathComponent("pilot_avatar.png")
        try? data.write(to: url)
    }

}

struct PilotStyleSelectionSheet: View {
    @Binding var currentStyle: PilotStyle
    var onSelect: (PilotStyle) -> Void
    var onReset: () -> Void
    
    // Stats
    var totalOwned: Int
    var completedCount: Int
    var stockCount: Int
    var constructingCount: Int
    
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header & Stats
                VStack(spacing: 20) {
                    Text(langManager.t(.select_style))
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                    
                    // Simple Stats Row
                    HStack(spacing: 0) {
                        statItem(label: langManager.t(.stats_logged), value: totalOwned)
                        statItem(label: langManager.t(.stats_stock), value: stockCount)
                        statItem(label: langManager.t(.stats_const), value: constructingCount)
                        statItem(label: langManager.t(.stats_done), value: completedCount)
                    }
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(8)
                }
                .padding(.top, 40) // Padding for Sheet Handle
                .padding(.horizontal, 20)
                
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(PilotStyle.allCases) { style in
                        Button {
                            onSelect(style)
                            dismiss()
                        } label: {
                            VStack(spacing: 15) {
                                Image(systemName: style.icon)
                                    .font(.system(size: 40))
                                Text(style.rawValue)
                                    .font(.caption.bold().monospaced())
                            }
                            .foregroundStyle(currentStyle == style ? .black : themeManager.currentTheme.mainColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(currentStyle == style ? themeManager.currentTheme.mainColor : Color.white.opacity(0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.currentTheme.mainColor, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Button {
                    onReset()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text(langManager.t(.reset_style))
                    }
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(.gray)
                    .padding()
                }
                
                Spacer()
                
                Button {
                     dismiss()
                } label: {
                    Text(langManager.t(.close))
                        .font(.headline.bold().monospaced())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(30)
                }
                .padding(.bottom, 40)
            }
        }
    }

    
    @ViewBuilder
    func statItem(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}
