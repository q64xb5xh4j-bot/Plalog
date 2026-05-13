import Foundation

struct GitHubRelease: Codable {
    let tagName: String
    let assets: [ReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}

struct ReleaseAsset: Codable {
    let name: String
    let downloadUrl: String

    enum CodingKeys: String, CodingKey {
        case name
        case downloadUrl = "browser_download_url"
    }
}

actor GitHubReleaseManager {
    static let shared = GitHubReleaseManager()

    private let repoOwner = "q64xb5xh4j-bot"
    private let repoName = "Plalog"
    private let catalogName = "gunpla_catalog.csv"
    private let cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    private var cachedVersion: String?

    nonisolated private var catalogCachePath: URL {
        return cacheDirectory.appendingPathComponent("gunpla_catalog_cache.csv")
    }

    nonisolated private var versionFilePath: URL {
        return cacheDirectory.appendingPathComponent("catalog_version.txt")
    }

    // MARK: - Public API

    /// Check for updates and download if available
    func checkAndUpdateIfNeeded() async {
        do {
            if let latestVersion = try await fetchLatestReleaseVersion() {
                let currentVersion = loadCachedVersion()

                if currentVersion != latestVersion {
                    print("[GitHubReleaseManager] New version available: \(latestVersion) (current: \(currentVersion ?? "none"))")

                    if try await downloadLatestCatalog() {
                        saveCachedVersion(latestVersion)
                        print("[GitHubReleaseManager] ✅ Catalog updated successfully")
                    }
                }
            }
        } catch {
            print("[GitHubReleaseManager] ❌ Update check failed: \(error.localizedDescription)")
        }
    }

    /// Load catalog from cache or Bundle
    nonisolated func loadCatalog(filename: String) -> String? {
        // For gunpla_catalog, try cache first
        if filename == "gunpla_catalog" {
            if let cached = try? String(contentsOf: catalogCachePath, encoding: .utf8) {
                print("[GitHubReleaseManager] 📂 Loaded \(filename) from cache")
                return cached
            }
        }

        // Fallback to Bundle
        if let path = Bundle.main.path(forResource: filename, ofType: "csv"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("[GitHubReleaseManager] 📦 Loaded \(filename) from Bundle")
            return content
        }

        return nil
    }

    // MARK: - Private Methods

    private func fetchLatestReleaseVersion() async throws -> String? {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        let request = URLRequest(url: url)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[GitHubReleaseManager] API request failed with status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return nil
        }

        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
        return release.tagName
    }

    private func downloadLatestCatalog() async throws -> Bool {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        let request = URLRequest(url: url)

        let (data, _) = try await URLSession.shared.data(for: request)
        let release = try JSONDecoder().decode(GitHubRelease.self, from: data)

        // Find gunpla_catalog.csv asset
        guard let asset = release.assets.first(where: { $0.name == catalogName }) else {
            print("[GitHubReleaseManager] ⚠️ gunpla_catalog.csv not found in release assets")
            return false
        }

        print("[GitHubReleaseManager] 📥 Downloading from: \(asset.downloadUrl)")

        let downloadUrl = URL(string: asset.downloadUrl)!
        let (csvData, _) = try await URLSession.shared.data(from: downloadUrl)

        try csvData.write(to: catalogCachePath)
        print("[GitHubReleaseManager] 💾 Saved to cache: \(catalogCachePath.lastPathComponent)")

        return true
    }

    nonisolated private func loadCachedVersion() -> String? {
        guard let version = try? String(contentsOf: versionFilePath, encoding: .utf8) else {
            return nil
        }
        return version.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private func saveCachedVersion(_ version: String) {
        try? version.write(to: versionFilePath, atomically: true, encoding: .utf8)
    }
}
