//
//  MpMessage.swift
//  Gyrobots
//
//  Created by Mert on 26.01.2026.
//

import Foundation

enum MPMessageType: String, Codable {
    case requestLevel
    case levelSeed
    case tilt
    case jump
    case playerState
    case time
    case finished
    case assignRoles
    case cancelMultipeer
    case restartedGame
    case joining
    case jumpSuccessfull
    case collect
    case removeItem
}

struct MPMessage: Codable {
    let type: MPMessageType
    let a: Double?
    let b: Double?
    let c: Double?
    let d: Double?
    let e: Double?
    let f: Double?

    init(type: MPMessageType, a: Double? = nil, b: Double? = nil, c: Double? = nil, d: Double? = nil, e: Double? = nil, f: Double? = nil) {
        self.type = type
        self.a = a; self.b = b; self.c = c; self.d = d; self.e = e; self.f = f
    }
}
