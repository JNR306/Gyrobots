//
//  HapticManager.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 31.01.26.
//

import Foundation
import UIKit

class HapticManager {
    
    static func tap() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    static func collect() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
}
