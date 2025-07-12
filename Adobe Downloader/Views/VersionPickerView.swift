//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//
import SwiftUI


private enum VersionPickerConstants {
    static let headerPadding: CGFloat = 5
    static let viewWidth: CGFloat = 500
    static let viewHeight: CGFloat = 600
    static let iconSize: CGFloat = 32
    static let verticalSpacing: CGFloat = 8
    static let horizontalSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 8
    static let buttonPadding: CGFloat = 8
    
    static let titleFontSize: CGFloat = 14
    static let captionFontSize: CGFloat = 12
}

struct VersionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StorageValue(\.defaultLanguage) private var defaultLanguage
    @StorageValue(\.downloadAppleSilicon) private var downloadAppleSilicon
    @State private var expandedVersions: Set<String> = []
    @State private var showingCustomDownload = false
    @State private var customDownloadVersion = ""
    @State private var showExistingFileAlert = false
    @State private var existingFilePath: URL?
    @State private var pendingDependencies: [DependenciesToDownload] = []
    @State private var productIcon: NSImage? = nil
    
    private let productId: String
    private let onSelect: (String) -> Void
    
    init(productId: String, onSelect: @escaping (String) -> Void) {
        self.productId = productId
        self.onSelect = onSelect
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VersionPickerHeaderView(productId: productId, downloadAppleSilicon: downloadAppleSilicon)
            VersionListView(
                productId: productId,
                expandedVersions: $expandedVersions,
                onSelect: onSelect,
                dismiss: dismiss,
                onCustomDownload: { version in
                    customDownloadVersion = version
                    showingCustomDownload = true
                }
            )
        }
        .frame(width: VersionPickerConstants.viewWidth, height: VersionPickerConstants.viewHeight)
        .onAppear {
            loadProductIcon()
        }
        .sheet(isPresented: $showingCustomDownload) {
            CustomDownloadView(
                productId: productId,
                version: customDownloadVersion,
                onDownloadStart: { dependencies in
                    handleCustomDownload(dependencies: dependencies)
                }
            )
        }
        .sheet(isPresented: $showExistingFileAlert) {
            if let existingPath = existingFilePath {
                ExistingFileAlertView(
                    path: existingPath,
                    onUseExisting: {
                        showExistingFileAlert = false
                        if let existingPath = existingFilePath {
                            Task {
                                await createCompletedCustomTask(
                                    path: existingPath,
                                    dependencies: pendingDependencies
                                )
                            }
                        }
                        pendingDependencies = []
                    },
                    onRedownload: {
                        showExistingFileAlert = false
                        startCustomDownloadProcess(dependencies: pendingDependencies)
                    },
                    onCancel: {
                        showExistingFileAlert = false
                        pendingDependencies = []
                    },
                    iconImage: productIcon
                )
            }
        }
    }
    
    private func getDestinationURL(productId: String, version: String, language: String) async throws -> URL {
        let platform = globalProducts.first(where: { $0.id == productId && $0.version == version })?.platforms.first?.id ?? "unknown"
        let installerName = productId == "APRO"
            ? "Adobe Downloader \(productId)_\(version)_\(platform).dmg"
            : "Adobe Downloader \(productId)_\(version)-\(language)-\(platform)"

        if StorageData.shared.useDefaultDirectory && !StorageData.shared.defaultDirectory.isEmpty {
            return URL(fileURLWithPath: StorageData.shared.defaultDirectory)
                .appendingPathComponent(installerName)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.title = "选择保存位置"
                panel.canCreateDirectories = true
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                
                if let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
                    panel.directoryURL = downloadsDir
                }
                
                let result = panel.runModal()
                if result == .OK, let selectedURL = panel.url {
                    continuation.resume(returning: selectedURL.appendingPathComponent(installerName))
                } else {
                    continuation.resume(throwing: NetworkError.cancelled)
                }
            }
        }
    }

    private func handleCustomDownload(dependencies: [DependenciesToDownload]) {
        showingCustomDownload = false
        
        Task {
            await checkAndStartCustomDownload(dependencies: dependencies)
        }
    }
    
    private func checkAndStartCustomDownload(dependencies: [DependenciesToDownload]) async {
        if let existingPath = globalNetworkManager.isVersionDownloaded(
            productId: productId, 
            version: customDownloadVersion, 
            language: StorageData.shared.defaultLanguage
        ) {
            await MainActor.run {
                existingFilePath = existingPath
                pendingDependencies = dependencies
                showExistingFileAlert = true
            }
        } else {
            await MainActor.run {
                startCustomDownloadProcess(dependencies: dependencies)
            }
        }
    }
    
    private func startCustomDownloadProcess(dependencies: [DependenciesToDownload]) {
        Task {
            let destinationURL: URL
            do {
                destinationURL = try await getDestinationURL(
                    productId: productId,
                    version: customDownloadVersion,
                    language: StorageData.shared.defaultLanguage
                )
            } catch {
                await MainActor.run { dismiss() }
                return
            }
            
            do {
                try await globalNetworkManager.startCustomDownload(
                    productId: productId,
                    selectedVersion: customDownloadVersion,
                    language: StorageData.shared.defaultLanguage,
                    destinationURL: destinationURL,
                    customDependencies: dependencies
                )
            } catch {
                print("自定义下载失败: \(error.localizedDescription)")
            }

            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func createCompletedCustomTask(path: URL, dependencies: [DependenciesToDownload]) async {
        let platform = globalProducts.first(where: { $0.id == productId && $0.version == customDownloadVersion })?.platforms.first?.id ?? "unknown"

        let task = NewDownloadTask(
            productId: productId,
            productVersion: customDownloadVersion,
            language: StorageData.shared.defaultLanguage,
            displayName: findProduct(id: productId)?.displayName ?? productId,
            directory: path.deletingLastPathComponent(),
            dependenciesToDownload: dependencies,
            retryCount: 0,
            createAt: Date(),
            totalProgress: 1.0,
            platform: platform
        )

        task.dependenciesToDownload = dependencies

        let totalSize = dependencies.reduce(0) { productSum, product in
            productSum + product.packages.reduce(0) { packageSum, pkg in
                packageSum + (pkg.downloadSize > 0 ? pkg.downloadSize : 0)
            }
        }
        task.totalSize = totalSize
        task.totalDownloadedSize = totalSize
        task.totalProgress = 1.0

        for dependency in dependencies {
            for package in dependency.packages where package.isSelected {
                package.downloaded = true
                package.progress = 1.0
                package.downloadedSize = package.downloadSize
                package.status = .completed
            }
        }

        task.setStatus(DownloadStatus.completed(DownloadStatus.CompletionInfo(
            timestamp: Date(),
            totalTime: 0,
            totalSize: totalSize
        )))

        await MainActor.run {
            globalNetworkManager.downloadTasks.append(task)
            globalNetworkManager.updateDockBadge()
            globalNetworkManager.objectWillChange.send()
        }

        await globalNetworkManager.saveTask(task)
        
        await MainActor.run {
            dismiss()
        }
    }
    
    private func loadProductIcon() {
        guard let product = findProduct(id: productId),
              let icon = product.getBestIcon(),
              let iconURL = URL(string: icon.value) else {
            return
        }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: iconURL)
                if let image = NSImage(data: data) {
                    await MainActor.run {
                        productIcon = image
                    }
                }
            } catch {
                print("加载产品图标失败: \(error.localizedDescription)")
            }
        }
    }
}

private struct VersionPickerHeaderView: View {
    let productId: String
    let downloadAppleSilicon: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            HStack {
                if let product = findProduct(id: productId) {
                    if let icon = product.getBestIcon() {
                        AsyncImage(url: URL(string: icon.value)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                        } placeholder: {
                            Image(systemName: "app.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("\(product.displayName)")
                        .font(.headline)
                }
                Text("选择版本")
                    .foregroundColor(.secondary)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.gray.opacity(0.2)))
            }
            .padding(.bottom, VersionPickerConstants.headerPadding)
            
            HStack(spacing: 6) {
                Image(systemName: downloadAppleSilicon ? "m.square" : "x.square")
                    .foregroundColor(.blue)
                Text(downloadAppleSilicon ? "Apple Silicon" : "Intel")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("•")
                    .foregroundColor(.secondary)
                Text(platformText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 10)
        }
        .padding(.horizontal)
        .padding(.top)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var platformText: String {
        StorageData.shared.allowedPlatform.joined(separator: ", ")
    }
}

private struct VersionListView: View {
    let productId: String
    @Binding var expandedVersions: Set<String>
    let onSelect: (String) -> Void
    let dismiss: DismissAction
    let onCustomDownload: (String) -> Void
    @State private var scrollPosition: String?
    @State private var cachedVersions: [(key: String, value: Product.Platform)] = []
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    LazyVStack(spacing: VersionPickerConstants.verticalSpacing) {
                        ForEach(getFilteredVersions(), id: \.key) { version, info in
                            VersionRow(
                                productId: productId,
                                version: version,
                                info: info,
                                isExpanded: expandedVersions.contains(version),
                                onSelect: handleVersionSelect,
                                onToggle: handleVersionToggle,
                                onCustomDownload: handleCustomDownload
                            )
                            .id(version)
                            .transition(.opacity)
                        }
                    }
                    .padding()

                    HStack(spacing: 8) {
                        Capsule()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("获取到 \(getFilteredVersions().count) 个版本")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 16)
                }
            }
            .background(Color(.clear))
            .onChange(of: expandedVersions) { newValue in
                if let lastExpanded = newValue.sorted().last {
                    withAnimation {
                        proxy.scrollTo(lastExpanded, anchor: .top)
                    }
                }
            }
            .onAppear {
                if cachedVersions.isEmpty {
                    cachedVersions = loadFilteredVersions()
                }
            }
        }
    }
    
    private func getFilteredVersions() -> [(key: String, value: Product.Platform)] {
        if !cachedVersions.isEmpty {
            return cachedVersions
        }
        return loadFilteredVersions()
    }
    
    private func loadFilteredVersions() -> [(key: String, value: Product.Platform)] {
        let products = findProducts(id: productId)
        if products.isEmpty {
            return []
        }

        var versionPlatformMap: [String: Product.Platform] = [:]
        
        for product in products {
            let platforms = product.platforms.filter { platform in
                StorageData.shared.allowedPlatform.contains(platform.id)
            }
            
            if let firstPlatform = platforms.first {
                versionPlatformMap[product.version] = firstPlatform
            }
        }

        return versionPlatformMap.map { (key: $0.key, value: $0.value) }
            .sorted { pair1, pair2 in
                AppStatics.compareVersions(pair1.key, pair2.key) > 0
            }
    }
    
    private func handleVersionSelect(_ version: String) {
        onSelect(version)
        dismiss()
    }
    
    private func handleVersionToggle(_ version: String) {
        withAnimation {
            if expandedVersions.contains(version) {
                expandedVersions.remove(version)
            } else {
                expandedVersions.insert(version)
            }
        }
    }
    
    private func handleCustomDownload(_ version: String) {
        onCustomDownload(version)
    }
}

private struct VersionRow: View, Equatable {
    @StorageValue(\.defaultLanguage) private var defaultLanguage
    
    let productId: String
    let version: String
    let info: Product.Platform
    let isExpanded: Bool
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void
    let onCustomDownload: (String) -> Void
    
    static func == (lhs: VersionRow, rhs: VersionRow) -> Bool {
        lhs.productId == rhs.productId &&
        lhs.version == rhs.version &&
        lhs.isExpanded == rhs.isExpanded
    }
    
    @State private var cachedExistingPath: URL? = nil
    
    private var existingPath: URL? {
        cachedExistingPath
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VersionHeader(
                version: version,
                info: info,
                isExpanded: isExpanded,
                hasExistingPath: existingPath != nil,
                onSelect: { onToggle(version) },
                onToggle: { onToggle(version) }
            )
            
            if isExpanded {
                VersionDetails(
                    info: info,
                    version: version,
                    onSelect: onSelect,
                    onCustomDownload: onCustomDownload
                )
            }
        }
        .padding(.horizontal)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(VersionPickerConstants.cornerRadius)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onAppear {
            if cachedExistingPath == nil {
                cachedExistingPath = globalNetworkManager.isVersionDownloaded(
                    productId: productId,
                    version: version,
                    language: defaultLanguage
                )
            }
        }
    }
}

private struct VersionHeader: View {
    let version: String
    let info: Product.Platform
    let isExpanded: Bool
    let hasExistingPath: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    
    private var hasDependencies: Bool {
        !(info.languageSet.first?.dependencies.isEmpty ?? true)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VersionInfo(version: version, platform: info.id, info: info)
                Spacer()
                ExistingPathButton(isVisible: hasExistingPath)
                ExpandButton(
                    isExpanded: isExpanded,
                    onToggle: onToggle,
                    hasDependencies: hasDependencies
                )
            }
            .padding(.vertical, VersionPickerConstants.buttonPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct VersionInfo: View {
    let version: String
    let platform: String
    let info: Product.Platform
    
    private var productVersion: String? {
        info.languageSet.first?.productVersion
    }
    
    private var buildGuid: String? {
        info.languageSet.first?.buildGuid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(version)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.9))
                
                if let pv = productVersion, pv != version {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("v\(pv)")
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.blue.opacity(0.8))
                }
            }

            HStack(spacing: 4) {
                Text(platform)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
                
                if let guid = buildGuid {
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(guid)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct ExistingPathButton: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            Text("已存在")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
}

private struct ExpandButton: View {
    let isExpanded: Bool
    let onToggle: () -> Void
    let hasDependencies: Bool
    
    var body: some View {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
    }
}

private struct VersionDetails: View {
    let info: Product.Platform
    let version: String
    let onSelect: (String) -> Void
    let onCustomDownload: (String) -> Void
    
    private var hasDependencies: Bool {
        !(info.languageSet.first?.dependencies.isEmpty ?? true)
    }
    
    private var hasModules: Bool {
        !(info.modules.isEmpty)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: VersionPickerConstants.verticalSpacing) {
            if hasDependencies || hasModules {
                VStack(alignment: .leading, spacing: 8) {
                    if hasDependencies {
                        HStack(spacing: 5) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.blue.opacity(0.8))
                            Text("依赖组件")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("(\(info.languageSet.first?.dependencies.count ?? 0))")
                                .font(.system(size: 11))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                        DependenciesList(dependencies: info.languageSet.first?.dependencies ?? [])
                            .padding(.leading, 8)
                    }
                    #if DEBUG
                    if hasModules {
                        if hasDependencies {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        
                        HStack(spacing: 5) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.blue.opacity(0.8))
                            Text("可选模块")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("(\(info.modules.count))")
                                .font(.system(size: 11))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                        ModulesList(modules: info.modules)
                            .padding(.leading, 8)
                    }
                    #endif
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
            
            DownloadButton(
                version: version, 
                onSelect: onSelect,
                onCustomDownload: { version in
                    onCustomDownload(version)
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

private struct DependenciesList: View {
    let dependencies: [Product.Platform.LanguageSet.Dependency]

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(dependencies, id: \.sapCode) { dependency in
                DependencyRow(dependency: dependency)
                    .padding(.vertical, 4)
            }
        }
    }
}

private struct DependencyRow: View, Equatable {
    let dependency: Product.Platform.LanguageSet.Dependency
    
    static func == (lhs: DependencyRow, rhs: DependencyRow) -> Bool {
        lhs.dependency.sapCode == rhs.dependency.sapCode &&
        lhs.dependency.productVersion == rhs.dependency.productVersion
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                getPlatformIcon(for: dependency.selectedPlatform)
                    .foregroundColor(.blue.opacity(0.8))
                    .font(.system(size: 12))
                    .frame(width: 16)
                
                Text(dependency.sapCode)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                
                Text("\(dependency.productVersion)")
                    .font(.system(size: 11))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.blue.opacity(0.1))
                    )
                    .foregroundColor(.blue.opacity(0.8))

                if dependency.baseVersion != dependency.productVersion {
                    HStack(spacing: 3) {
                        Text("base:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                        Text(dependency.baseVersion)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.9))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
            }
            .padding(.vertical, 2)

            HStack(spacing: 10) {
                if !dependency.buildGuid.isEmpty {
                    HStack(spacing: 3) {
                        Text("buildGuid:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                        Text(dependency.buildGuid)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.9))
                            .textSelection(.enabled)
                    }
                }
            }
            .padding(.top, 2)
            .padding(.leading, 24)
            
            #if DEBUG
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Match:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(dependency.isMatchPlatform ? "✅" : "❌")
                        .font(.caption2)
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        
                    Text("Target:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(dependency.targetPlatform)
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                
                if !dependency.selectedReason.isEmpty {
                    HStack(spacing: 4) {
                        Text("Reason:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(dependency.selectedReason)
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.leading, 22)
            #endif
        }
    }
    
    private func getPlatformIcon(for platform: String) -> Image {
        switch platform {
        case "macarm64":
            return Image(systemName: "m.square")
        case "macuniversal":
            return Image(systemName: "m.circle")
        case "osx10", "osx10-64":
            return Image(systemName: "x.square")
        default:
            return Image(systemName: "questionmark.square")
        }
    }
}

private struct ModulesList: View {
    let modules: [Product.Platform.Module]
    
    var body: some View {
        ForEach(modules, id: \.id) { module in
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 6, height: 6)
                
                Text(module.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                
                if !module.deploymentType.isEmpty {
                    Text("(\(module.deploymentType))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.vertical, 3)
        }
    }
}

private struct DownloadButton: View {
    let version: String
    let onSelect: (String) -> Void
    let onCustomDownload: (String) -> Void
    
    var body: some View {
        Button("下载") {
            onCustomDownload(version)
        }
        .foregroundColor(.white)
        .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue))
        .padding(.top, 8)
    }
}
