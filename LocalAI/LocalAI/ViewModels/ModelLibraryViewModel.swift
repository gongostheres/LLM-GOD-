import Foundation
import Observation
import UIKit

@Observable
final class ModelLibraryViewModel {

    var models: [AIModel] = []
    var downloadProgress: [String: Double] = [:]
    var downloadingIds: Set<String> = []
    var connectingIds: Set<String> = []      // waiting for first byte
    var failedIds: Set<String> = []
    var errorMessage: String?

    private let key = "downloaded_model_ids"
    // One watchdog Task per active download — cancelled in endDownload
    private var watchdogs: [String: Task<Void, Never>] = [:]
    // Background task tokens — keep iOS from suspending us mid-download
    private var bgTaskIds: [String: UIBackgroundTaskIdentifier] = [:]

    init() { reload() }

    // MARK: - Computed

    var downloadedModels: [AIModel] { models.filter(\.isDownloaded) }

    var totalDownloadedGB: Double {
        downloadedModels.reduce(0) { $0 + $1.sizeGB }
    }

    // MARK: - Actions

    func download(_ model: AIModel) {
        guard !downloadingIds.contains(model.id) else { return }
        downloadingIds.insert(model.id)
        connectingIds.insert(model.id)
        downloadProgress[model.id] = 0

        // Prevent screen from locking — iOS kills URLSession network when display sleeps
        UIApplication.shared.isIdleTimerDisabled = true

        // Request background execution time so download survives going to background
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "localai-dl-\(model.id)") {
            // Expiration handler: system is about to suspend — nothing we can do, let it fail
        }
        bgTaskIds[model.id] = bgTask

        Task {
            do {
                try await InferenceService.shared.preloadModel(model) { [weak self] completed, total, fileFraction in
                    Task { @MainActor [weak self] in
                        guard let self else { return }

                        // First callback — leave connecting state and arm the stall watchdog
                        if self.connectingIds.contains(model.id) {
                            self.connectingIds.remove(model.id)
                            self.armWatchdog(for: model.id)
                        }

                        // Smooth progress: completed files + byte-fraction of current file
                        let fraction: Double
                        if total > 0 {
                            fraction = min((Double(completed) + fileFraction) / Double(total), 1.0)
                        } else {
                            fraction = fileFraction   // fall back to per-file fraction
                        }
                        self.downloadProgress[model.id] = fraction
                    }
                }
                await markDownloaded(model.id)
            } catch is CancellationError {
                // Watchdog cancelled us — error already set, endDownload will clean up
            } catch {
                await fail(model.id, message: error.localizedDescription)
            }
            await endDownload(model.id)
        }
    }

    func retry(_ model: AIModel) {
        failedIds.remove(model.id)
        download(model)
    }

    func delete(_ model: AIModel) {
        InferenceService.shared.evictModel(model)
        setDownloaded(model.id, value: false)
    }

    // MARK: - Watchdog

    /// Cancels the download after 90 seconds of zero progress — surfaces a clear error.
    @MainActor
    private func armWatchdog(for modelId: String) {
        watchdogs[modelId]?.cancel()
        watchdogs[modelId] = Task { @MainActor [weak self] in
            var lastProgress: Double = 0
            var stallSeconds = 0

            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 15_000_000_000) // check every 15 s
                } catch {
                    return // Task was cancelled — clean exit
                }

                guard let self, self.downloadingIds.contains(modelId) else { return }

                let current = self.downloadProgress[modelId] ?? 0
                let moved = abs(current - lastProgress) > 0.004 // > 0.4% counts as progress
                lastProgress = current

                if moved {
                    stallSeconds = 0
                } else {
                    stallSeconds += 15
                    if stallSeconds >= 90 {
                        self.fail(modelId, message: "Загрузка зависла. Проверьте интернет и нажмите «Повторить».")
                        self.endDownload(modelId)
                        return
                    }
                }
            }
        }
    }

    // MARK: - Private

    @MainActor private func markDownloaded(_ id: String) { setDownloaded(id, value: true) }

    @MainActor private func endDownload(_ id: String) {
        downloadingIds.remove(id)
        connectingIds.remove(id)
        downloadProgress.removeValue(forKey: id)
        // keep failedIds so UI shows retry

        // Cancel watchdog
        watchdogs[id]?.cancel()
        watchdogs.removeValue(forKey: id)

        // End background task token
        if let token = bgTaskIds.removeValue(forKey: id) {
            UIApplication.shared.endBackgroundTask(token)
        }

        // Re-enable idle timer once all downloads are done
        if downloadingIds.isEmpty {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    @MainActor private func fail(_ id: String, message: String) {
        failedIds.insert(id)
        errorMessage = "Ошибка загрузки: \(message)"
    }

    private func setDownloaded(_ id: String, value: Bool) {
        if let i = models.firstIndex(where: { $0.id == id }) { models[i].isDownloaded = value }
        var saved = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        if value { saved.insert(id) } else { saved.remove(id) }
        UserDefaults.standard.set(Array(saved), forKey: key)
    }

    private func reload() {
        let downloaded = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        models = AIModel.catalog.map { var m = $0; m.isDownloaded = downloaded.contains(m.id); return m }
    }
}
