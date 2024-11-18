//
//  StorageData.swift
//  Adobe Downloader
//
//  Created by X1a0He on 11/14/24.
//

import SwiftUI

final class StorageData: ObservableObject {
    static let shared = StorageData()

    @Published var installedHelperBuild: String {
        didSet {
            UserDefaults.standard.set(installedHelperBuild, forKey: "InstalledHelperBuild")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }

    @Published var downloadAppleSilicon: Bool {
        didSet {
            UserDefaults.standard.set(downloadAppleSilicon, forKey: "downloadAppleSilicon")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }
    
    @Published var useDefaultLanguage: Bool {
        didSet {
            UserDefaults.standard.set(useDefaultLanguage, forKey: "useDefaultLanguage")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }
    
    @Published var defaultLanguage: String {
        didSet {
            UserDefaults.standard.set(defaultLanguage, forKey: "defaultLanguage")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }
    
    @Published var useDefaultDirectory: Bool {
        didSet {
            UserDefaults.standard.set(useDefaultDirectory, forKey: "useDefaultDirectory")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }
    
    @Published var defaultDirectory: String {
        didSet {
            UserDefaults.standard.set(defaultDirectory, forKey: "defaultDirectory")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }
    
    @Published var confirmRedownload: Bool {
        didSet {
            UserDefaults.standard.set(confirmRedownload, forKey: "confirmRedownload")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }

    @Published var apiVersion: String {
        didSet {
            UserDefaults.standard.set(apiVersion, forKey: "apiVersion")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }

    @Published var isFirstLaunch: Bool {
        didSet {
            UserDefaults.standard.set(isFirstLaunch, forKey: "isFirstLaunch")
            objectWillChange.send()
            NotificationCenter.default.post(name: .storageDidChange, object: nil)
        }
    }
    
    var allowedPlatform: [String] {
        if downloadAppleSilicon {
            return ["macuniversal", "macarm64"]
        } else {
            return ["macuniversal", "osx10-64", "osx10"]
        }
    }
    
    private init() {
        let isFirstLaunchKey = "isFirstLaunch"
        if !UserDefaults.standard.contains(key: isFirstLaunchKey) {
            self.isFirstLaunch = true
            UserDefaults.standard.set(true, forKey: isFirstLaunchKey)
        } else {
            self.isFirstLaunch = UserDefaults.standard.bool(forKey: isFirstLaunchKey)
        }
        
        self.installedHelperBuild = UserDefaults.standard.string(forKey: "InstalledHelperBuild") ?? "0"
        self.downloadAppleSilicon = UserDefaults.standard.bool(forKey: "downloadAppleSilicon")
        self.useDefaultLanguage = UserDefaults.standard.bool(forKey: "useDefaultLanguage")
        self.defaultLanguage = UserDefaults.standard.string(forKey: "defaultLanguage") ?? "ALL"
        self.useDefaultDirectory = UserDefaults.standard.bool(forKey: "useDefaultDirectory")
        self.defaultDirectory = UserDefaults.standard.string(forKey: "defaultDirectory") ?? ""
        self.confirmRedownload = UserDefaults.standard.bool(forKey: "confirmRedownload")
        self.apiVersion = UserDefaults.standard.string(forKey: "apiVersion") ?? "6"
    }
}

@propertyWrapper
struct StorageValue<T>: DynamicProperty {
    @ObservedObject private var storage = StorageData.shared
    private let keyPath: ReferenceWritableKeyPath<StorageData, T>
    
    var wrappedValue: T {
        get { storage[keyPath: keyPath] }
        nonmutating set {
            storage[keyPath: keyPath] = newValue
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { storage[keyPath: keyPath] },
            set: { storage[keyPath: keyPath] = $0 }
        )
    }
    
    init(_ keyPath: ReferenceWritableKeyPath<StorageData, T>) {
        self.keyPath = keyPath
    }
}

extension Notification.Name {
    static let storageDidChange = Notification.Name("storageDidChange")
}

extension UserDefaults {
    func contains(key: String) -> Bool {
        return object(forKey: key) != nil
    }
}

