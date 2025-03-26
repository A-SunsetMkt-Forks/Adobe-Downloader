import SwiftUI

struct ContentView: View {
    @StateObject private var networkManager = globalNetworkManager
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var showDownloadManager = false
    @State private var searchText = ""
    @State private var currentApiVersion = StorageData.shared.apiVersion

    private var filteredProducts: [UniqueProduct] {
        if searchText.isEmpty { return globalUniqueProducts }
        return globalUniqueProducts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) || 
            $0.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    private func refreshData() {
        isRefreshing = true
        errorMessage = nil
        Task {
            await networkManager.fetchProducts()
            await MainActor.run { isRefreshing = false }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(
                downloadAppleSilicon: Binding(
                    get: { StorageData.shared.downloadAppleSilicon },
                    set: { newValue in
                        StorageData.shared.downloadAppleSilicon = newValue
                        Task {
                            await networkManager.fetchProducts()
                        }
                    }
                ),
                currentApiVersion: $currentApiVersion,
                searchText: $searchText,
                showDownloadManager: $showDownloadManager,
                isRefreshing: isRefreshing,
                downloadTasksCount: networkManager.downloadTasks.count,
                onRefresh: refreshData,
                openSettings: openSettings
            )
            
            BannerView()
            
            MainContentView(
                loadingState: networkManager.loadingState,
                filteredProducts: filteredProducts,
                onRetry: { networkManager.retryFetchData() }
            )
            .background(Color(.clear))
            .animation(.easeInOut, value: networkManager.loadingState)
            .animation(.easeInOut, value: filteredProducts)
        }
        .background(Color(.clear))
        .sheet(isPresented: $showDownloadManager) {
            DownloadManagerView() 
        }
        .onChange(of: currentApiVersion) { newValue in
            StorageData.shared.apiVersion = newValue
            refreshData()
        }
        .onAppear { 
            if globalCcmResult.products.isEmpty { 
                refreshData() 
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
