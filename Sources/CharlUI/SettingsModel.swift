import CharlCore
import CharlPlatform
import Combine
import Foundation

/// 设置持久化与变更广播。启动即加载（热键依赖），写入防抖。
public final class SettingsModel: ObservableObject {
    @Published public var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            if settings.language != oldValue.language { Lang.preference = settings.language }
            onChange?(settings)
            scheduleSave()
        }
    }

    public var onChange: ((AppSettings) -> Void)?

    private let storage: StorageService
    private var saveWork: DispatchWorkItem?
    private static let path = "settings.json"

    public init(storage: StorageService) {
        self.storage = storage
        if let data = try? storage.read(Self.path),
           var decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            decoded.clamp()
            settings = decoded
        } else {
            settings = .default
        }
        Lang.preference = settings.language
    }

    public func resetToDefaults() {
        settings = .default
    }

    public func flushSave() {
        saveWork?.cancel()
        saveWork = nil
        persist()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.persist() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? storage.write(data, to: Self.path)
    }
}