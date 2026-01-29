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
import CoreMotion

enum CurrentView {
    case MAIN_MENU, GAME, RESULT
}

enum Role {
    case gyro, jump
}

enum Level {
    case DESERT, CITY
}

@Observable
class AppState {
    
    static let shared: AppState = AppState()
    
    var gameScene: GameScene
    
    var currentView: CurrentView = .MAIN_MENU
    
    let motionManager = CMMotionManager()
    let mp = MultipeerManager()
    
    var role: Role = .gyro
    
    //let locationHelper = LocationHelper()
    
    var currentTime: Double? = nil
    var bestTime: Double? = nil
    
    var currentLevel: Level? = .DESERT
    
    var startTime: Double = 0
    var elapsedTime: Double = 0
    var isTimerRunning = false
    
    init() {
        let scene = GameScene()
        scene.scaleMode = .resizeFill
        scene.mp = mp
        self.gameScene = scene
        
        setupGame()
        setupMultipeer()
        
        //locationHelper.start()
    }
    
    private func setupGame() {
        self.gameScene.roleIsJumpSender = (role == .jump)
        if role == .jump {
            self.gameScene.tiltX = 0
        }
    }
    
    private func setupMultipeer() {
        mp.onReceivedMessage = { [weak self] msg in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch msg.type {
                case .tilt:
                    let x = CGFloat(msg.value ?? 0)
                    self.gameScene.applyRemoteTilt(x)
                case .jump:
                    self.gameScene.applyRemoteJump(force: msg.value.map { CGFloat($0) })
                }
            }
        }
        
        // For testing: one device hosts, one joins.
        // Pick ONE of these per device:
        //mp.startHosting()
        mp.startJoining()
    }
    
    func startSensors() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self = self, let motion = motion, self.role == .gyro else { return }
            
            let roll = motion.attitude.roll
            let normalized = max(-1.0, min(1.0, roll / 0.6))
            
            self.gameScene.tiltX = CGFloat(normalized)
            self.mp.send(MPMessage(type: .tilt, value: normalized))
        }
    }
    
    func stopSensors() {
        motionManager.stopDeviceMotionUpdates()
    }
    
    func handleJumpAction() {
        self.gameScene.smallJump()
        mp.send(MPMessage(type: .jump, value: Double(self.gameScene.smallJumpForce)))
    }
    
    func startTimer() {
        startTime = CFAbsoluteTimeGetCurrent()
        isTimerRunning = true
    }
    
    func updateTimer() {
        if isTimerRunning {
            elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        }
    }
    
    func stopTimer() {
        if isTimerRunning {
            elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
            isTimerRunning = false
        }
    }
    
    var formattedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        
        return formatter.string(from: elapsedTime) ?? "00:00"
    }
}
