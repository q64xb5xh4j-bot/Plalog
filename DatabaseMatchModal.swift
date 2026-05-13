//
//  DatabaseMatchModal.swift
//  Plalog
//
//  Created by (User) on 2024/06/xx.
//

import SwiftUI

struct DatabaseMatchModal: View {
    @Binding var isPresented: Bool
    var currentTitle: String
    var onSelect: (CSVKitData) -> Void
    
    @State private var searchText: String = ""
    @State private var searchResults: [CSVKitData] = []
    
    // Filter States
    @State private var selectedSeries: String? = nil
    @State private var selectedGrade: String? = nil
    @State private var selectedScale: String? = nil
    @State private var selectedMaker: String? = nil
    
    // Filter Data Sources
    @State private var allSeries: [String] = []
    @State private var allGrades: [String] = []
    @State private var allScales: [String] = []
    @State private var allMakers: [String] = []
    
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var dataManager = CSVDataManager.shared
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("データベースを検索...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .submitLabel(.search)
                        .onSubmit {
                            performSearch()
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                // Filter Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        filterMenu(title: "メーカー", selection: $selectedMaker, options: allMakers)
                        filterMenu(title: "シリーズ", selection: $selectedSeries, options: allSeries)
                        filterMenu(title: "グレード", selection: $selectedGrade, options: allGrades)
                        filterMenu(title: "スケール", selection: $selectedScale, options: allScales)
                        
                        if selectedMaker != nil || selectedSeries != nil || selectedGrade != nil || selectedScale != nil {
                            Button {
                                withAnimation {
                                    selectedMaker = nil
                                    selectedSeries = nil
                                    selectedGrade = nil
                                    selectedScale = nil
                                    performSearch()
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                
                // Results List
                List {
                    if dataManager.isLoading {
                         HStack {
                             Spacer()
                             ProgressView("データを読み込み中...")
                             Spacer()
                         }
                         .listRowBackground(Color.clear)
                    } else if searchResults.isEmpty {
                        Text("検索結果なし")
                            .foregroundColor(.secondary)
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(searchResults, id: \.jan) { item in
                            Button {
                                onSelect(item)
                                isPresented = false
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(.body)
                                        .bold()
                                        .foregroundColor(.primary)
                                    
                                    HStack {
                                        Text(item.maker)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(4)
                                        
                                        Text(item.grade)
                                            .font(.caption)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.orange.opacity(0.1))
                                            .foregroundColor(.orange)
                                            .cornerRadius(4)
                                        
                                        Spacer()
                                    }
                                    
                                    Text(item.series)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("データベースと照合")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                // Load filter data
                allMakers = CSVDataManager.shared.getAllMakers()
                allSeries = CSVDataManager.shared.getAllSeries()
                allGrades = CSVDataManager.shared.getAllGrades()
                allScales = CSVDataManager.shared.getAllScales()
                
                // Pre-fill search text with current title and auto-search
                searchText = currentTitle
                performSearch()
            }
            .task(id: searchText) {
                // Debounce logic
                if searchText.isEmpty {
                    searchResults = []
                    return
                }
                
                // Don't debounce if it's the initial pre-fill (length check or just let it run)
                // But generally for typing we want a delay.
                // We also want to skip if searchText matches currentTitle initially to avoid double load if logic is weird,
                // but actually we DO want to search on appear.
                
                // Sleep for 0.3s to debounce typing
                do {
                    try await Task.sleep(nanoseconds: 300_000_000)
                } catch { return }
                
                if searchText.count > 1 {
                    performSearch()
                }
            }
            .onChange(of: dataManager.isLoading) { _, loading in
                if !loading {
                    // Update filters
                    allMakers = CSVDataManager.shared.getAllMakers()
                    allSeries = CSVDataManager.shared.getAllSeries()
                    allGrades = CSVDataManager.shared.getAllGrades()
                    allScales = CSVDataManager.shared.getAllScales()
                    
                    // Re-run search
                    performSearch()
                }
            }
        }
    }
    
    private func performSearch() {
        // 1. Get raw search results (Limit 500 to allow for filtering)
        let rawResults = CSVDataManager.shared.searchApproximate(query: searchText, limit: 500)
        let items = rawResults.map { $0.item }
        
        // 2. Apply Filters
        let filtered = items.filter { item in
            if let m = selectedMaker, item.maker != m { return false }
            if let s = selectedSeries, item.series != s { return false }
            if let g = selectedGrade, item.grade != g { return false }
            if let sc = selectedScale, item.scale != sc { return false }
            return true
        }
        
        // 3. Take Top 50 of Filtered
        self.searchResults = Array(filtered.prefix(50))
    }
    
    @ViewBuilder
    private func filterMenu(title: String, selection: Binding<String?>, options: [String]) -> some View {
        Menu {
            Button("指定なし") {
                selection.wrappedValue = nil
                performSearch()
            }
            ForEach(options, id: \.self) { option in
                Button(option) {
                    selection.wrappedValue = option
                    performSearch()
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.wrappedValue ?? title)
                    .font(.caption)
                    .fontWeight(selection.wrappedValue != nil ? .bold : .regular)
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selection.wrappedValue != nil ? themeManager.currentTheme.mainColor.opacity(0.1) : Color(UIColor.secondarySystemBackground))
            .foregroundStyle(selection.wrappedValue != nil ? themeManager.currentTheme.mainColor : .secondary)
            .cornerRadius(16)
        }
    }
}
