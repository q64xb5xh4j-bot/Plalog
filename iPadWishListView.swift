
import SwiftUI
import SwiftData
import Combine

struct iPadWishListView: View {
    @Query(filter: #Predicate<Kit> { $0.statusValue == 0 }, sort: \Kit.createdDate, order: .reverse) private var wishListKits: [Kit]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    @AppStorage("googleApiKey") private var googleApiKey: String = ""
    @AppStorage("isGodModeEnabled") private var isGodModeEnabled: Bool = false
    
    // Search State
    @State private var query: String = ""
    @State private var searchResults: [Candidate] = []
    @State private var isSearching: Bool = false
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    // Grid Setup
    let columns = [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)]
    
    var body: some View {
        ZStack {
            // Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header & Search Area
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundStyle(themeManager.currentTheme.mainColor)
                        TextField(langManager.t(.ipad_search_placeholder), text: $query)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .onSubmit { runWebSearch() }
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                        
                        if !query.isEmpty {
                            Button(action: { query = ""; searchResults = [] }) {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        Button(action: { runWebSearch() }) {
                            Text(langManager.t(.ipad_scan))
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(themeManager.currentTheme.mainColor)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .disabled(query.isEmpty)
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // MARK: - List Actions
                    if !wishListKits.isEmpty {
                        HStack {
                            Spacer()
                            Button(action: {
                                if let image = ImageRendererHelper.render(view: LootReportView(kits: wishListKits, title: "PROCUREMENT ORDER"), size: CGSize(width: 1080, height: 1350)) {
                                    shareImage = image
                                    showShareSheet = true
                                }
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text(langManager.t(.share_list))
                                }
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(themeManager.currentTheme.mainColor.opacity(0.1))
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 20)
                        }
                    }
                    
                    // MARK: - Search Results Area
                    if isSearching {
                        HStack {
                            ProgressView().tint(themeManager.currentTheme.mainColor)
                            Text(langManager.t(.ipad_scanning)).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(height: 100)
                    } else if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(langManager.t(.ipad_search_results) + " (\(searchResults.count))")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                                .padding(.horizontal, 20)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(searchResults) { candidate in
                                        SearchResultCard(candidate: candidate) {
                                            addToWishList(candidate)
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 10)
                            }
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .background(Color(UIColor.systemBackground).opacity(0.5))
                
                Divider()
                
                // MARK: - Wish List Grid
                ScrollView {
                    if wishListKits.isEmpty {
                        VStack(spacing: 20) {
                            Spacer().frame(height: 50)

                            Image(systemName: "cart.badge.plus")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary.opacity(0.3))
                            Text(langManager.t(.ipad_wish_empty))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                            Text(langManager.t(.ipad_wish_empty_desc))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(wishListKits) { kit in
                                Button(action: { selectedKit = kit }) {
                                    WishListCard(kit: kit)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                }
            }
        }
        .navigationTitle(langManager.t(.wish_list))
        .toolbarBackground(.hidden, for: .navigationBar)
        .alert("Search Error", isPresented: $showErrorAlert) { Button("OK") {} } message: { Text(errorMessage) }
        .sheet(item: $selectedKit) { kit in
            KitDetailOverlay(kit: $selectedKit)
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
    }
    
    @State private var selectedKit: Kit? = nil
    
    // Share State
    @State private var showShareSheet: Bool = false
    @State private var shareImage: UIImage? = nil
    
    // MARK: - Logic
    
    private func runWebSearch() {
        let base = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        isSearching = true
        searchResults = []
        
        Task {
            do {
                // 1. Search Local Database (MasterCatalogDB)
                let localItems = MasterCatalogDB.shared.search(query: base)
                self.searchResults = localItems
                
                // 2. God Mode Google Search (Optional)
                if isGodModeEnabled && !googleApiKey.isEmpty {
                     // Only run if God Mode
                     let googleItems = try await GoogleSearchClient.shared.search(query: "\(base) プラモデル")
                     var googleCandidates: [Candidate] = []
                     
                     for item in googleItems {
                         let fullText = "\(item.title) \(item.snippet)"
                         let parsed = TitleParser.parse(title: fullText, originalMaker: "", originalSeries: "")
                         let c = Candidate(
                             title: parsed.cleanTitle,
                             maker: parsed.maker,
                             scale: parsed.scale,
                             series: parsed.series,
                             grade: parsed.grade,
                             jan: "",
                             imageURLString: item.imageURL,
                             price: "",
                             isOfficial: item.link.contains("bandai-hobby.net")
                         )
                         googleCandidates.append(c)
                     }
                     
                     await MainActor.run {
                         withAnimation {
                             self.searchResults.insert(contentsOf: googleCandidates, at: 0)
                             self.isSearching = false
                         }
                     }
                } else {
                     await MainActor.run {
                         self.isSearching = false
                     }
                }
                
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    self.errorMessage = "Search Completed (Local Only)"
                }
            }
        }
    }
    
    private func addToWishList(_ candidate: Candidate) {
        let newKit = Kit(
            title: candidate.title,
            maker: candidate.maker,
            series: candidate.series,
            grade: candidate.grade,
            scale: candidate.scale,
            jan: candidate.jan,
            statusValue: 0, // 0 = Wish List
            imageURLString: candidate.imageURLString,
            memo: "Added from Web Search"
        )
        modelContext.insert(newKit)
        
        // Remove from search results to indicate action taken
        withAnimation {
            searchResults.removeAll { $0.id == candidate.id }
        }
        
        // Clear search if empty
        if searchResults.isEmpty {
            query = ""
        }
        
        // Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - Subviews

struct SearchResultCard: View {
    let candidate: Candidate
    let onAdd: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                // Image
                if let urlStr = candidate.imageURLString, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        if let img = phase.image { img.resizable().scaledToFill() }
                        else { Color.gray.opacity(0.1) }
                    }
                    .frame(width: 140, height: 140)
                    .clipped()
                } else {
                    Color.gray.opacity(0.1).frame(width: 140, height: 140)
                    Image(systemName: "photo").foregroundStyle(.gray)
                }
                
                // Add Button Overlay
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .background(Circle().fill(Color.white))
                        .shadow(radius: 2)
                }
                .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.title)
                    .font(.system(size: 12, weight: .bold))
                    .lineLimit(2)
                    .frame(height: 32, alignment: .topLeading)
                
                HStack {
                    if !candidate.grade.isEmpty {
                        Text(candidate.grade)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Color.primary.opacity(0.05))
                            .cornerRadius(4)
                    }
                    Spacer()
                    if !candidate.price.isEmpty {
                        Text(candidate.price).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .frame(width: 140)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct WishListCard: View {
    let kit: Kit
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var langManager = LanguageManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Area
            ZStack(alignment: .topTrailing) {
                let urlStr = kit.imageURLString
                
                if let path = urlStr, !path.isEmpty {
                    if path.hasPrefix("asset://") {
                         PhAssetImage(localIdentifier: String(path.dropFirst(8))).scaledToFit()
                    } else if let url = ImageLinker.resolve(urlString: path) {
                        AsyncImage(url: url) { phase in
                            if let img = phase.image { img.resizable().scaledToFit() }
                            else { Color.gray.opacity(0.3) }
                        }
                    }
                } else {
                    Color.gray.opacity(0.2)
                    Image(systemName: "cube").font(.largeTitle).foregroundStyle(.gray)
                }
                
                // Delete Button
                Button(action: {
                    modelContext.delete(kit)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.gray.opacity(0.8))
                        .padding(8)
                }
            }
            .frame(height: 160)
            .clipped()
            .background(Color.black)
            
            // Info Area
            VStack(alignment: .leading, spacing: 8) {
                Text(kit.title)
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(2)
                    .frame(height: 40, alignment: .topLeading)
                
                Button(action: {
                    withAnimation {
                        kit.statusValue = 2 // Move to Stock
                        // kit.modifiedDate = Date()
                    }
                    let gen = UINotificationFeedbackGenerator()
                    gen.notificationOccurred(.success)
                }) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                        Text(langManager.t(.btn_purchased))
                    }
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(themeManager.currentTheme.mainColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 4)
    }
}
