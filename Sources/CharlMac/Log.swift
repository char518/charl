import os

public enum Log {
    public static let app = Logger(subsystem: "com.charl.charl", category: "app")
    public static let hotkey = Logger(subsystem: "com.charl.charl", category: "hotkey")
    public static let clipboard = Logger(subsystem: "com.charl.charl", category: "clipboard")
    public static let calendar = Logger(subsystem: "com.charl.charl", category: "calendar")
    public static let screenshot = Logger(subsystem: "com.charl.charl", category: "screenshot")
    public static let storage = Logger(subsystem: "com.charl.charl", category: "storage")
}