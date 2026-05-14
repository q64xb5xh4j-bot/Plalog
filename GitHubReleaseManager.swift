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
    private let cacheDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    // ダウンロード対象 CSV（GitHub Release に含まれる全ファイル）
    private let catalogFileNames = [
        "gunpla_catalog.csv",
        "kotobukiya_models.csv",
        "hasegawa_models.csv",
        "volks_models.csv",
        "gsc_models.csv",
        "tamiya_models.csv",
    ]

    nonisolated private var versionFilePath: URL {
        return cacheDirectory.appendingPathComponent("catalog_version.txt")
    }

    // キャッシュパスを動的生成: filename は拡張子なし or あり どちらでも可
    nonisolated private func cachePath(for filename: String) -> URL {
        let base = filename.hasSuffix(".csv") ? filename : "\(filename).csv"
        return cacheDirectory.appendingPathComponent("\(base)_cache")
    }

    // MARK: - Public API

    /// Check for updates and download all catalogs if a new release is available.
    /// Returns true if any catalog was updated.
    @discardableResult
    func checkAndUpdateIfNeeded() async -> Bool {
        do {
            guard let release = try await fetchLatestRelease() else { return false }

            let currentVersion = loadCachedVersion()
            guard currentVersion != release.tagName else {
                print("[GitHubReleaseManager] ✅ Catalog is up to date (\(release.tagName))")
                return false
            }

            print("[GitHubReleaseManager] New version: \(release.tagName) (current: \(currentVersion ?? "none"))")

            let updated = try await downloadAllCatalogs(release: release)
            if updated {
                saveCachedVersion(release.tagName)
                print("[GitHubReleaseManager] ✅ All catalogs updated to \(release.tagName)")
            }
            return updated

        } catch {
            print("[GitHubReleaseManager] ❌ Update check failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Load catalog CSV string from cache (Documents) or Bundle fallback.
    /// filename は拡張子なし（例: "gunpla_catalog"）または あり（"gunpla_catalog.csv"）どちらでも可。
    nonisolated func loadCatalog(filename: String) -> String? {
        // 1. Documents キャッシュを確認
        let cache = cachePath(for: filename)
        if let cached = try? String(contentsOf: cache, encoding: .utf8) {
            print("[GitHubReleaseManager] 📂 Loaded \(filename) from cache")
            return cached
        }

        // 2. Bundle にフォールバック（拡張子なしで検索）
        let resourceName = filename.hasSuffix(".csv")
            ? String(filename.dropLast(4))
            : filename
        if let path = Bundle.main.path(forResource: resourceName, ofType: "csv"),
           let content = try? String(contentsOfFile: path, encoding: .utf8) {
            print("[GitHubReleaseManager] 📦 Loaded \(filename) from Bundle")
            return content
        }

        return nil
    }

    // MARK: - Private Methods

    private func fetchLatestRelease() async throws -> GitHubRelease? {
        let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print("[GitHubReleaseManager] API request failed with status \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            return nil
        }

        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }

    /// Download all catalog CSVs from the given release and save to Documents cache.
    /// Returns true if at least one file was saved successfully.
    private func downloadAllCatalogs(release: GitHubRelease) async throws -> Bool {
        var anySuccess = false
        for csvName in catalogFileNames {
            guard let asset = release.assets.first(where: { $0.name == csvName }) else {
                print("[GitHubReleaseManager] ⚠️ \(csvName) not found in release assets")
                continue
            }

            guard let downloadUrl = URL(string: asset.downloadUrl) else { continue }

            do {
                print("[GitHubReleaseManager] 📥 Downloading \(csvName)...")
                let (csvData, _) = try await URLSession.shared.data(from: downloadUrl)
                let dest = cachePath(for: csvName)
                try csvData.write(to: dest)
                print("[GitHubReleaseManager] 💾 Saved \(csvName) (\(csvData.count) bytes)")
                anySuccess = true
            } catch {
                print("[GitHubReleaseManager] ⚠️ Failed to download \(csvName): \(error.localizedDescription)")
            }
        }
        return anySuccess
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
