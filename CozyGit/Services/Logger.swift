//
//  Logger.swift
//  CozyGit
//

import Foundation
import os.log

final class Logger {
    static let shared = Logger()

    enum Level: String {
        case debug = "DEBUG"
        case info = "INFO"
        case warning = "WARNING"
        case error = "ERROR"
    }

    enum Category: String {
        case git = "Git"
        case ui = "UI"
        case app = "App"
        case network = "Network"
    }

    private let osLog: OSLog
    private let dateFormatter: DateFormatter

    private init() {
        self.osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.cozy.git", category: "General")
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    }

    func debug(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }

    func info(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }

    func warning(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }

    func error(_ message: String, category: Category = .app, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }

    private func log(level: Level, message: String, category: Category, file: String, function: String, line: Int) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(category.rawValue)] \(fileName):\(line) \(function) - \(message)"

        #if DEBUG
        print(logMessage)
        #endif

        let osLogType: OSLogType
        switch level {
        case .debug:
            osLogType = .debug
        case .info:
            osLogType = .info
        case .warning:
            osLogType = .default
        case .error:
            osLogType = .error
        }

        os_log("%{public}@", log: osLog, type: osLogType, logMessage)
    }
}
