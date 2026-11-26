import CharlCore
import CharlPlatform
import Foundation

public final class MacStorage: StorageService {
    public let baseURL: URL

    public init(appSupport: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]) {
        baseURL = Self.resolveDirectory(appSupport: appSupport)
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    /// 复制完成后才发布新目录，迁移失败时继续读取旧目录并在下次启动重试。
    private static func resolveDirectory(appSupport: URL) -> URL {
        let fm = FileManager.default
        let target = appSupport.appendingPathComponent(AppConfig.dataDirectoryName, isDirectory: true)
        let legacy = appSupport.appendingPathComponent(AppConfig.legacyDataDirectoryName, isDirectory: true)
        guard fm.fileExists(atPath: legacy.path), !fm.fileExists(atPath: target.path) else { return target }
        let staging = appSupport.appendingPathComponent(".charl-migration-" + UUID().uuidString, isDirectory: true)
        do {
            try fm.copyItem(at: legacy, to: staging)
            try fm.moveItem(at: staging, to: target)
            Log.storage.notice("copied legacy data into charl; original directory retained")
            return target
        } catch {
            try? fm.removeItem(at: staging)
            Log.storage.error("data migration failed; using legacy directory: \(error.localizedDescription, privacy: .public)")
            return legacy
        }
    }

    public func url(for relativePath: String) -> URL {
        baseURL.appendingPathComponent(relativePath)
    }

    public func read(_ relativePath: String) throws -> Data? {
        let fileURL = url(for: relativePath)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try Data(contentsOf: fileURL)
    }

    public func write(_ data: Data, to relativePath: String) throws {
        let fileURL = url(for: relativePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    public func remove(_ relativePath: String) throws {
        let fileURL = url(for: relativePath)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}