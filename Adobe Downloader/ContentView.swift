import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var networkManager: NetworkManager
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showDownloadManager = false
    @State private var searchText = ""
    @State private var currentApiVersion = StorageData.shared.apiVersion
    @State private var cachedProducts: [Sap] = []
    
    private var apiVersion: String {
        get { StorageData.shared.apiVersion }
        set {
            StorageData.shared.apiVersion = newValue
            refreshData()
        }
    }
    
    private var filteredProducts: [Sap] {
        if searchText.isEmpty {
            return cachedProducts
        }
        
        return cachedProducts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.sapCode.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
    
    private func updateProductsCache() {
        let products = networkManager.saps.values
            .filter { $0.hasValidVersions(allowedPlatform: StorageData.shared.allowedPlatform) }
            .sorted { $0.displayName < $1.displayName }
        cachedProducts = products
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack() {
                Text("Adobe Downloader")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fixedSize()

                Spacer()
                
                HStack {
                    Toggle(isOn: Binding(
                        get: { StorageData.shared.downloadAppleSilicon },
                        set: { newValue in
                            StorageData.shared.downloadAppleSilicon = newValue
                            Task {
                                await networkManager.fetchProducts()
                            }
                        }
                    )) {
                        Text("Apple Silicon")
                    }
                    .toggleStyle(.switch)
                    .tint(.green)
                    .disabled(isRefreshing)
                }
                .padding(.horizontal, 10)

                HStack {
                    Text("API:")
                    Picker("", selection: $currentApiVersion) {
                        Text("v4").tag("4")
                        Text("v5").tag("5")
                        Text("v6").tag("6")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .onChange(of: currentApiVersion) { newValue in
                        StorageData.shared.apiVersion = newValue
                        refreshData()
                    }
                }
                .disabled(isRefreshing)
                .padding(.horizontal, 10)

                HStack(spacing: 8) {
                    SearchField(text: $searchText)
                        .frame(maxWidth: 200)

                    if #available(macOS 14.0, *) {
                        SettingsLink {
                            Image(systemName: "gearshape")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.borderless)
                    } else {
                        Button(action: openSettings) {
                            Image(systemName: "gearshape")
                                .imageScale(.medium)
                        }
                        .buttonStyle(.borderless)
                    }

                    Button(action: refreshData) {
                        Image(systemName: "arrow.clockwise")
                            .imageScale(.medium)
                    }
                    .disabled(isRefreshing)
                    .buttonStyle(.borderless)
                    
                    Button(action: { showDownloadManager.toggle() }) {
                        Image(systemName: "arrow.down.circle")
                            .imageScale(.medium)
                    }
                    .disabled(isRefreshing)
                    .buttonStyle(.borderless)
                    .overlay(
                        Group {
                            if !networkManager.downloadTasks.isEmpty {
                                Text("\(networkManager.downloadTasks.count)")
                                    .font(.caption2)
                                    .padding(3)
                                    .background(Color.blue)
                                    .clipShape(Circle())
                                    .foregroundColor(.white)
                                    .offset(x: 8, y: -8)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Adobe Downloader 完全开源免费: https://github.com/X1a0He/Adobe-Downloader")
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal)
            .padding(.bottom, 5)
            .background(Color(NSColor.windowBackgroundColor))

            ZStack {
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                
                switch networkManager.loadingState {
                case .idle, .loading:
                    ProgressView("正在加载...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                case .failed(let error):
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundColor(.red)
                        
                        Text("加载失败")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text(error.localizedDescription)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .padding(.bottom, 10)
                        
                        Button(action: {
                            networkManager.retryFetchData()
                        }) {
                            HStack() {
                                Image(systemName: "arrow.clockwise")
                                Text("重试")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                case .success:
                    if filteredProducts.isEmpty {
                        VStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("没有找到产品")
                                .font(.headline)
                                .padding(.top)
                            Text("尝试使用不同的搜索关键词")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 250))],
                                spacing: 20
                            ) {
                                ForEach(filteredProducts, id: \.sapCode) { sap in
                                    AppCardView(sap: sap)
                                }
                            }
                            .padding()
                            
                            HStack(spacing: 8) {
                                Capsule()
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(width: 6, height: 6)
                                Text("获取到 \(filteredProducts.count) 款产品")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.bottom, 16)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDownloadManager) {
            DownloadManagerView()
                .environmentObject(networkManager)
        }
        .onAppear {
            if networkManager.saps.isEmpty {
                refreshData()
            } else {
                updateProductsCache()
            }
        }
        .onChange(of: networkManager.saps) { _ in
            updateProductsCache()
        }
    }
    
    private func refreshData() {
        isRefreshing = true
        errorMessage = nil
        
        Task {
            await networkManager.fetchProducts()
            await MainActor.run {
                updateProductsCache()
                isRefreshing = false
            }
        }
    }
}

struct SearchField: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索应用", text: $text)
                .textFieldStyle(PlainTextFieldStyle())
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    let networkManager = NetworkManager()
    
    return ContentView()
        .environmentObject(networkManager)
        .frame(width: 850, height: 700)
}

