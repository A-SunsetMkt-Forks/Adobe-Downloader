import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var eventMonitor: Any?
    var networkManager: NetworkManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = nil
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains(.command) && event.characters?.lowercased() == "q" {
                if let mainWindow = NSApp.mainWindow,
                   mainWindow.sheets.isEmpty && !mainWindow.isSheet {
                    self?.handleQuitCommand()
                    return nil
                }
            }
            return event
        }
    }

    @MainActor private func handleQuitCommand() {
        guard let manager = networkManager else {
            NSApplication.shared.terminate(nil)
            return
        }

        let hasActiveDownloads = manager.downloadTasks.contains { task in
            if case .downloading = task.totalStatus {
                return true
            }
            return false
        }

        if hasActiveDownloads {
            Task {
                for task in manager.downloadTasks {
                    if case .downloading = task.totalStatus {
                        await manager.downloadUtils.pauseDownloadTask(
                            taskId: task.id,
                            reason: .other(String(localized: "程序即将退出"))
                        )
                    }
                }

                await MainActor.run {
                    let alert = NSAlert()
                    alert.messageText = String(localized: "确认退出")
                    alert.informativeText = String(localized:"有正在进行的下载任务，确定要退出吗？\n所有下载任务的进度已保存，下次启动可以继续下载")
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: String(localized:"退出"))
                    alert.addButton(withTitle: String(localized:"取消"))

                    let response = alert.runModal()
                    if response == .alertSecondButtonReturn {
                        Task {
                            for task in manager.downloadTasks {
                                if case .paused = task.totalStatus {
                                    await manager.downloadUtils.resumeDownloadTask(taskId: task.id)
                                }
                            }
                        }
                    } else {
                        NSApplication.shared.terminate(0)
                    }
                }
            }
        } else {
            NSApplication.shared.terminate(nil)
        }
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        networkManager = nil
    }
} 
