//
//  Adobe Downloader
//
//  Created by X1a0He on 2/26/25.
//

import Foundation
struct Product: Codable, Equatable {
    var type: String
    var displayName: String
    var family: String
    var appLineage: String
    var familyName: String
    var productIcons: [ProductIcon]
    var platforms: [Platform]
    var referencedProducts: [ReferencedProduct]
    var version: String
    var id: String
    var hidden: Bool
    
    func hasValidVersions(allowedPlatform: [String]) -> Bool {
        return platforms.contains { platform in
            allowedPlatform.contains(platform.id) && !platform.languageSet.isEmpty
        }
    }

    struct ProductIcon: Codable, Equatable {
        var value: String
        var size: String

        var dimension: Int {
            let components = size.split(separator: "x")
            if components.count == 2,
               let dimension = Int(components[0]) {
                return dimension
            }
            return 0
        }
    }

    struct Platform: Codable, Equatable {
        var languageSet: [LanguageSet]
        var modules: [Module]
        var range: [Range]
        var id: String

        struct LanguageSet: Codable, Equatable {
            var manifestURL: String
            var dependencies: [Dependency]
            var productCode: String
            var name: String
            var installSize: Int
            var buildGuid: String
            var baseVersion: String
            var productVersion: String

            struct Dependency: Codable, Equatable {
                var sapCode: String
                var baseVersion: String
                var productVersion: String
                var buildGuid: String
                var isMatchPlatform: Bool
                var targetPlatform: String
                var selectedPlatform: String
                var selectedReason: String
                
                init(sapCode: String, baseVersion: String, productVersion: String, buildGuid: String, isMatchPlatform: Bool = false, targetPlatform: String = "", selectedPlatform: String = "", selectedReason: String = "") {
                    self.sapCode = sapCode
                    self.baseVersion = baseVersion
                    self.productVersion = productVersion
                    self.buildGuid = buildGuid
                    self.isMatchPlatform = isMatchPlatform
                    self.targetPlatform = targetPlatform
                    self.selectedPlatform = selectedPlatform
                    self.selectedReason = selectedReason
                }
            }
        }

        struct Module: Codable, Equatable {
            var displayName: String
            var deploymentType: String
            var id: String
        }

        struct Range: Codable, Equatable {
            var min: String
            var max: String
        }
    }

    struct ReferencedProduct: Codable, Equatable {
        var sapCode: String
        var version: String
    }

    func getBestIcon() -> ProductIcon? {
        if let icon = productIcons.first(where: { $0.size == "192x192" }) {
            return icon
        }
        return productIcons.max(by: { $0.dimension < $1.dimension })
    }
}

struct NewParseResult {
    var products: [Product]
    var cdn: String
}

/* ========== */
struct UniqueProduct {
    var id: String
    var displayName: String
}

/* ========== */
class DependenciesToDownload: ObservableObject, Codable {
    // 别人依赖就他吗叫sapCode，Adobe也是傻逼，一会id一会sapCode
    var sapCode: String
    var version: String
    var buildGuid: String
    var applicationJson: String?
    @Published var packages: [Package] = []
    @Published var completedPackages: Int = 0

    var totalPackages: Int {
        packages.count
    }

    init(sapCode: String, version: String, buildGuid: String, applicationJson: String = "") {
        self.sapCode = sapCode
        self.version = version
        self.buildGuid = buildGuid
        self.applicationJson = applicationJson
    }

    func updateCompletedPackages() {
        Task { @MainActor in
            completedPackages = packages.filter { $0.downloaded }.count
            objectWillChange.send()
        }
    }

    enum CodingKeys: String, CodingKey {
        case sapCode, version, buildGuid, applicationJson, packages
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sapCode, forKey: .sapCode)
        try container.encode(version, forKey: .version)
        try container.encode(buildGuid, forKey: .buildGuid)
        try container.encodeIfPresent(applicationJson, forKey: .applicationJson)
        try container.encode(packages, forKey: .packages)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sapCode = try container.decode(String.self, forKey: .sapCode)
        version = try container.decode(String.self, forKey: .version)
        buildGuid = try container.decode(String.self, forKey: .buildGuid)
        applicationJson = try container.decodeIfPresent(String.self, forKey: .applicationJson)
        packages = try container.decode([Package].self, forKey: .packages)
        completedPackages = 0
    }
}

/* ========== */
class Package: Identifiable, ObservableObject, Codable {
    var id = UUID()
    var type: String
    var fullPackageName: String
    var downloadSize: Int64
    var downloadURL: String
    var packageVersion: String

    @Published var downloadedSize: Int64 = 0 {
        didSet {
            if downloadSize > 0 {
                progress = Double(downloadedSize) / Double(downloadSize)
            }
        }
    }
    @Published var progress: Double = 0
    @Published var speed: Double = 0
    @Published var status: PackageStatus = .waiting
    @Published var downloaded: Bool = false

    var lastUpdated: Date = Date()
    var lastRecordedSize: Int64 = 0
    var retryCount: Int = 0
    var lastError: Error?

    var canRetry: Bool {
        if case .failed = status {
            return retryCount < 3
        }
        return false
    }

    func markAsFailed(_ error: Error) {
        Task { @MainActor in
            self.lastError = error
            self.status = .failed(error.localizedDescription)
            objectWillChange.send()
        }
    }

    func prepareForRetry() {
        Task { @MainActor in
            self.retryCount += 1
            self.status = .waiting
            self.progress = 0
            self.speed = 0
            self.downloadedSize = 0
            objectWillChange.send()
        }
    }

    init(type: String, fullPackageName: String, downloadSize: Int64, downloadURL: String, packageVersion: String) {
        self.type = type
        self.fullPackageName = fullPackageName
        self.downloadSize = downloadSize
        self.downloadURL = downloadURL
        self.packageVersion = packageVersion
    }

    func updateProgress(downloadedSize: Int64, speed: Double) {
        Task { @MainActor in
            self.downloadedSize = downloadedSize
            self.speed = speed
            self.status = .downloading
            objectWillChange.send()
        }
    }

    func markAsCompleted() {
        Task { @MainActor in
            self.downloaded = true
            self.progress = 1.0
            self.speed = 0
            self.status = .completed
            self.downloadedSize = downloadSize
            objectWillChange.send()
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: downloadSize, countStyle: .file)
    }

    var formattedDownloadedSize: String {
        ByteCountFormatter.string(fromByteCount: downloadedSize, countStyle: .file)
    }

    var formattedSpeed: String {
        ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }

    var hasValidSize: Bool {
        downloadSize > 0
    }

    func updateStatus(_ status: PackageStatus) {
        Task { @MainActor in
            self.status = status
            objectWillChange.send()
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, type, fullPackageName, downloadSize, downloadURL, packageVersion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type, forKey: .type)
        try container.encode(fullPackageName, forKey: .fullPackageName)
        try container.encode(downloadSize, forKey: .downloadSize)
        try container.encode(downloadURL, forKey: .downloadURL)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        type = try container.decode(String.self, forKey: .type)
        fullPackageName = try container.decode(String.self, forKey: .fullPackageName)
        downloadSize = try container.decode(Int64.self, forKey: .downloadSize)
        downloadURL = try container.decode(String.self, forKey: .downloadURL)
        packageVersion = try container.decode(String.self, forKey: .packageVersion)
    }
}

struct NetworkConstants {
    static let downloadTimeout: TimeInterval = 300
    static let maxRetryAttempts = 3
    static let retryDelay: UInt64 = 3_000_000_000
    static let bufferSize = 1024 * 1024
    static let maxConcurrentDownloads = 3
    static let progressUpdateInterval: TimeInterval = 1

    static func generateCookie() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let randomString = (0..<26).map { _ in chars.randomElement()! }
        return "fg=\(String(randomString))======"
    }

    static var productsJSONURL: String {
        "https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v\(UserDefaults.standard.string(forKey: "apiVersion") ?? "6")/products/all"
    }

    static let applicationJsonURL = "https://cdn-ffc.oobesaas.adobe.com/core/v3/applications"

    static var adobeRequestHeaders: [String: String] {
        [
            "x-adobe-app-id": "accc-apps-panel-desktop",
            "x-api-key": "Creative Cloud_v\(UserDefaults.standard.string(forKey: "apiVersion") ?? "6")_4",
            "User-Agent": "Creative Cloud/6.4.0.361/Mac-15.1",
            "Cookie": generateCookie()
        ]
    }

    static let downloadHeaders = [
        "User-Agent": "Creative Cloud"
    ]
}
