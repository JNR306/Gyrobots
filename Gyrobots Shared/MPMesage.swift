//
//  MpMessage.swift
//  Gyrobots
//
//  Created by Mert on 26.01.2026.
//

import Foundation

enum MPMessageType: String, Codable {
    case tilt
    case jump
}

struct MPMessage: Codable {
    let type: MPMessageType
    let value: Double?   // for tilt
}
