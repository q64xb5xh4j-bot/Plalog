import SwiftUI

struct DigitalBoxArtView: View {
    let kit: Kit
    var heroImage: UIImage? = nil // ✅ External Image Injection
    @ObservedObject private var themeManager = ThemeManager.shared
    
    // Fixed Size for Render (e.g. 1080 x 1350 for 4:5 Aspect Ratio)
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 1. Background Image
            GeometryReader { geo in
                if let img = heroImage {
                     Image(uiImage: img)
                         .resizable()
                         .scaledToFill()
                         .frame(width: geo.size.width, height: geo.size.height)
                         .clipped()
                } else {
                    // Fallback or Async (Mainly for preview, but render should use heroImage)
                    Color.black
                }
            }
            
            // 2. Cyber Overlay Gradient
            LinearGradient(
                colors: [
                    .black.opacity(0.9),
                    .black.opacity(0.6),
                    .black.opacity(0.0)
                ],
                startPoint: .bottom,
                endPoint: .top
            )
            
            // 3. Deco Frame
            Rectangle()
                .strokeBorder(themeManager.currentTheme.mainColor, lineWidth: 10)
                .opacity(0.8)
            
            // 4. Data Overlay
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .bottom) {
                    // ID / Status Badge
                    Text("#\(String(kit.uuid.prefix(4)).uppercased())")
                        .font(.system(size: 30, weight: .black, design: .monospaced))
                        .foregroundStyle(themeManager.currentTheme.mainColor)
                        .padding(.trailing, 10)
                    
                    // Status
                    Text(getStatusString(value: kit.statusValue).uppercased())
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.currentTheme.mainColor)
                        .cornerRadius(4)
                }
                
                Spacer() // Push to bottom
                
                // Kit Data
                VStack(alignment: .leading, spacing: 10) {
                    // Maker & Series
                    HStack {
                        if !kit.maker.isEmpty {
                            Text(kit.maker.uppercased())
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.gray)
                        }
                        if !kit.series.isEmpty {
                            Text("/")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(.gray.opacity(0.5))
                            Text(kit.series.uppercased())
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.gray)
                        }
                    }
                    
                    // Title
                    Text(kit.title)
                        .font(.system(size: 56, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .shadow(color: .black, radius: 2, x: 2, y: 2)
                    
                    // Specs Line
                    HStack(spacing: 20) {
                        SpecValues(label: "GRADE", value: kit.grade)
                        SpecValues(label: "SCALE", value: kit.scale)
                        SpecValues(label: "COMPLETED", value: formatDate(kit.createdDate))
                    }
                    .padding(.top, 10)
                }
                .padding(.bottom, 60)
                .padding(.leading, 40)
            }
            .padding(40)
            
            // Brand Logo
            VStack {
                HStack {
                    Spacer()
                    Text("PRALOG")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .tracking(8)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(40)
                }
                Spacer()
            }
        }
        .frame(width: 1080, height: 1350) // Instagram Portrait 4:5 Ratio
        .background(Color.black)
    }
    
    @ViewBuilder
    private func SpecValues(label: String, value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading) {
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(themeManager.currentTheme.mainColor)
                Text(value)
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }

    private func getStatusString(value: Int) -> String {
        switch value {
        case 0: return "WISH LIST"
        case 1: return "RESERVED"
        case 2: return "STOCKPILE"
        case 3: return "CONSTRUCTING"
        case 4: return "COMPLETED"
        default: return "UNKNOWN"
        }
    }
}
