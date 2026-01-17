//
//  AppState.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 11.01.26.
//

import Foundation
import SwiftUI
import Observation
import SpriteKit

enum CurrentView {
    case MAIN_MENU, GAME
}

@Observable
class AppState {
    
    var gameScene: GameScene? = nil
    var isReady: Bool = false
    
    var currentView: CurrentView = .MAIN_MENU
    
    func prepareGame() {
        DispatchQueue.global(qos: .userInitiated).async {
            let scene = GameScene()
            scene.scaleMode = .resizeFill
            DispatchQueue.main.async {
                self.gameScene = scene
                self.isReady = true
            }
        }
    }
}
