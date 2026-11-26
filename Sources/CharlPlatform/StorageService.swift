import Foundation

/// 持久化能力：相对路径 → 应用私有数据目录下的文件。
/// 数据格式约定为 JSON + 二进制附件，跨平台一致。
public protocol StorageService: AnyObject {
    func url(for relativePath: String) -> URL
    /// 文件不存在时返回 nil。
    func read(_ relativePath: String) throws -> Data?
    /// 原子写入，自动创建中间目录。
    func write(_ data: Data, to relativePath: String) throws
    func remove(_ relativePath: String) throws
}