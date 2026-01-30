//
//  GitOperationResult.swift
//  CozyGit
//

import Foundation

struct GitOperationResult {
    let success: Bool
    let output: String
    let error: String?
    let exitCode: Int32

    init(success: Bool, output: String, error: String? = nil, exitCode: Int32 = 0) {
        self.success = success
        self.output = output
        self.error = error
        self.exitCode = exitCode
    }

    static func success(output: String) -> GitOperationResult {
        GitOperationResult(success: true, output: output, exitCode: 0)
    }

    static func failure(error: String, exitCode: Int32 = 1) -> GitOperationResult {
        GitOperationResult(success: false, output: "", error: error, exitCode: exitCode)
    }
}
