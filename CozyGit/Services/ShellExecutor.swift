//
//  ShellExecutor.swift
//  CozyGit
//

import Foundation

actor ShellExecutor {
    private let defaultTimeout: TimeInterval = 30.0

    func execute(
        command: String,
        arguments: [String] = [],
        workingDirectory: URL? = nil,
        timeout: TimeInterval? = nil
    ) async -> GitOperationResult {
        let effectiveTimeout = timeout ?? defaultTimeout

        return await withCheckedContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [command] + arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            if let workingDirectory = workingDirectory {
                process.currentDirectoryURL = workingDirectory
            }

            // Set up environment
            var environment = ProcessInfo.processInfo.environment
            environment["LANG"] = "en_US.UTF-8"
            environment["LC_ALL"] = "en_US.UTF-8"
            process.environment = environment

            var didComplete = false
            let completionLock = NSLock()

            // Timeout handler
            let timeoutWorkItem = DispatchWorkItem {
                completionLock.lock()
                if !didComplete {
                    didComplete = true
                    completionLock.unlock()
                    process.terminate()
                    continuation.resume(returning: GitOperationResult(
                        success: false,
                        output: "",
                        error: "Operation timed out after \(effectiveTimeout) seconds",
                        exitCode: -1
                    ))
                } else {
                    completionLock.unlock()
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + effectiveTimeout, execute: timeoutWorkItem)

            do {
                try process.run()
                process.waitUntilExit()

                timeoutWorkItem.cancel()

                completionLock.lock()
                if didComplete {
                    completionLock.unlock()
                    return
                }
                didComplete = true
                completionLock.unlock()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8)

                let success = process.terminationStatus == 0

                continuation.resume(returning: GitOperationResult(
                    success: success,
                    output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                    error: errorOutput?.trimmingCharacters(in: .whitespacesAndNewlines),
                    exitCode: process.terminationStatus
                ))
            } catch {
                timeoutWorkItem.cancel()

                completionLock.lock()
                if didComplete {
                    completionLock.unlock()
                    return
                }
                didComplete = true
                completionLock.unlock()

                continuation.resume(returning: GitOperationResult(
                    success: false,
                    output: "",
                    error: error.localizedDescription,
                    exitCode: -1
                ))
            }
        }
    }

    func executeGit(
        arguments: [String],
        workingDirectory: URL? = nil,
        timeout: TimeInterval? = nil
    ) async -> GitOperationResult {
        await execute(
            command: "git",
            arguments: arguments,
            workingDirectory: workingDirectory,
            timeout: timeout
        )
    }
}
