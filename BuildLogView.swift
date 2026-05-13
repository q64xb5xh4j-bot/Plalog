//
//  BuildLogView.swift
//  Plalog
//
//  Created by (User) on 2024/06/xx.
//

import SwiftUI
import SwiftData
import PhotosUI
import Combine // ✅ Added

struct BuildLogView: View {
    @Bindable var kit: Kit
    @Binding var isPresented: Bool
    
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Add Log State
    @State private var showAddSheet: Bool = false
    @State private var newLogText: String = ""
    @State private var newLogImage: UIImage? = nil
    @State private var newLogDate: Date = Date()
    @State private var activePicker: ImagePickerType? = nil
    
    // Timelapse State
    @State private var showTimelapse: Bool = false
    
    enum ImagePickerType: Identifiable {
        case camera, library
        var id: Int { hashValue }
    }
    
    var sortedLogs: [BuildLog] {
        (kit.buildLogs ?? []).sorted { $0.date > $1.date } // Newest first
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                if (kit.buildLogs ?? []).isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text.image")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary.opacity(0.3))
                        Text("NO BUILD LOGS")
                            .font(.title3).bold().foregroundStyle(.secondary)
                        Text("Record your build process.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(sortedLogs) { log in
                                TimelineRow(log: log, onDelete: {
                                    if var logs = kit.buildLogs, let index = logs.firstIndex(of: log) {
                                        kit.buildLogs?.remove(at: index) 
                                        // Also delete image file? Yes.
                                        if let p = log.imagePath {
                                            ImageLinker.deleteLocalImageFile(named: p)
                                        }
                                        modelContext.delete(log) // Explicitly delete from context
                                    }
                                })
                            }
                        }
                        .padding(.vertical, 20)
                    }
                }

                
                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showAddSheet = true }) {
                            Image(systemName: "plus")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 60, height: 60)
                                .background(themeManager.currentTheme.mainColor)
                                .clipShape(Circle())
                                .shadow(radius: 4, y: 4)
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("BUILD LOGS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("CLOSE") { isPresented = false }
                        .font(.system(size: 14, weight: .bold))
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !(kit.buildLogs ?? []).isEmpty {
                        Button(action: { startTimelapse() }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(themeManager.currentTheme.mainColor)
                        }
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddLogSheet(
                    isPresented: $showAddSheet,
                    image: $newLogImage,
                    text: $newLogText,
                    date: $newLogDate,
                    activePicker: $activePicker,
                    onSave: saveNewLog
                )
            }
            .sheet(item: $activePicker) { type in
                ImagePicker(
                    sourceType: (type == .camera ? .camera : .photoLibrary),
                    selectedImage: $newLogImage,
                    selectedAssetID: .constant(nil) // We don't track asset ID persistence for logs for now, just file copy
                )
                .ignoresSafeArea()
            }
            .fullScreenCover(isPresented: $showTimelapse) {
                let sorted = (kit.buildLogs ?? []).sorted { $0.date < $1.date }
                if !sorted.isEmpty {
                    LogTimelapseView(logs: sorted, isPresented: $showTimelapse)
                } else {
                    Text("No logs to display")
                }
            }
        }
    }
    
    private func saveNewLog() {
        var savedPath: String? = nil
        var savedData: Data? = nil
        
        if let img = newLogImage, let data = img.jpegData(compressionQuality: 0.8) {
             savedData = data
             // No file writing for CloudKit
        }
        
        let newLog = BuildLog(date: newLogDate, imagePath: savedPath, text: newLogText, logImageData: savedData)
        if kit.buildLogs == nil { kit.buildLogs = [] }
        kit.buildLogs?.append(newLog)
        
        // Reset
        newLogImage = nil
        newLogText = ""
        newLogDate = Date()
    }
    
    private func startTimelapse() {
        showTimelapse = true
    }
}

// MARK: - Subviews

struct TimelineRow: View {
    let log: BuildLog
    let onDelete: () -> Void
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Date Column
            VStack {
                Text(formatDate(log.date))
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            
            // Content Card
            VStack(alignment: .leading, spacing: 8) {
                if (log.logImageData != nil) || (log.imagePath != nil && !log.imagePath!.isEmpty) {
                    UniversalImageView(imageData: log.logImageData, imagePath: log.imagePath)
                        .scaleEffect(1.0) // Needed to match view modifier requirement if any
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .clipped() // Ensure fill doesn't overflow
                }
                
                if !log.text.isEmpty {
                    Text(log.text)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemBackground).opacity(0.5))
            .cornerRadius(12)
            .contextMenu {
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Log", systemImage: "trash")
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MM/dd\nHH:mm"
        return f.string(from: date)
    }
}

struct AddLogSheet: View {
    @Binding var isPresented: Bool
    @Binding var image: UIImage?
    @Binding var text: String
    @Binding var date: Date
    @Binding var activePicker: BuildLogView.ImagePickerType?
    let onSave: () -> Void
    
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date)
                }
                
                Section {
                    if let img = image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                            .onTapGesture {
                                activePicker = .library // Re-select
                            }
                        
                        Button("Remove Image", role: .destructive) {
                            image = nil
                        }
                    } else {
                        HStack {
                            Button(action: { activePicker = .camera }) {
                                Label("Camera", systemImage: "camera")
                            }
                            Spacer()
                            Button(action: { activePicker = .library }) {
                                Label("Library", systemImage: "photo")
                            }
                        }
                        .buttonStyle(.borderless)
                    }
                } header: {
                    Text("IMAGE")
                }
                
                Section {
                    TextEditor(text: $text)
                        .frame(height: 100)
                } header: {
                    Text("NOTE")
                }
            }
            .navigationTitle("New Log Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        isPresented = false
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(themeManager.currentTheme.mainColor)
                    .disabled(image == nil && text.isEmpty)
                }
            }
        }
    }
}

// MARK: - Log Timelapse View

struct LogTimelapseView: View {
    let logs: [BuildLog]
    @Binding var isPresented: Bool
    
    @State private var currentIndex = 0
    @State private var isPlaying = true
    @State private var timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(0..<logs.count, id: \.self) { index in
                    ZStack {
                        if (logs[index].logImageData != nil) || (logs[index].imagePath != nil && !logs[index].imagePath!.isEmpty) {
                            UniversalImageView(imageData: logs[index].logImageData, imagePath: logs[index].imagePath)
                                .scaledToFit()
                        } else {
                            Text("No Image").foregroundStyle(.white)
                        }
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            
            // Info Overlay
            VStack {
                HStack {
                    Spacer()
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding()
                    }
                }
                Spacer()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(formatDate(logs[currentIndex].date))
                        .font(.title2).fontWeight(.heavy).monospaced()
                        .foregroundStyle(.white)
                    
                    if !logs[currentIndex].text.isEmpty {
                        Text(logs[currentIndex].text)
                            .font(.body)
                            .foregroundStyle(.white)
                            .shadow(color: .black, radius: 1)
                    }
                }
                .padding()
                .background(.black.opacity(0.5))
                .cornerRadius(12)
                .padding(.bottom, 20)
                
                // Controls
                HStack(spacing: 40) {
                    Button {
                        withAnimation { currentIndex = (currentIndex - 1 + logs.count) % logs.count }
                    } label: { Image(systemName: "backward.fill").font(.title) }
                    
                    Button {
                        isPlaying.toggle()
                    } label: {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.largeTitle)
                    }
                    
                    Button {
                        withAnimation { currentIndex = (currentIndex + 1) % logs.count }
                    } label: { Image(systemName: "forward.fill").font(.title) }
                }
                .foregroundStyle(.white)
                .padding(.bottom, 50)
            }
        }
        .onReceive(timer) { _ in
            if isPlaying && !logs.isEmpty {
                withAnimation { currentIndex = (currentIndex + 1) % logs.count }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm"
        return f.string(from: date)
    }
}
