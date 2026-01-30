//
//  RemoteTrackingStatus.swift
//  CozyGit
//

import Foundation

struct RemoteTrackingStatus: Equatable {
    let ahead: Int
    let behind: Int

    var hasChanges: Bool {
        ahead > 0 || behind > 0
    }

    var isAhead: Bool {
        ahead > 0
    }

    var isBehind: Bool {
        behind > 0
    }

    static let zero = RemoteTrackingStatus(ahead: 0, behind: 0)
}
