import Foundation
import SwiftUI
import Observation
import SpriteKit
import CoreMotion

enum CurrentView {
    case MAIN_MENU, GAME
}

enum Role {
    case gyro, jump   // gyro = joiner, jump = host
}

@Observable
class AppState {

    var gameScene: GameScene
    var currentView: CurrentView = .MAIN_MENU

    let motionManager = CMMotionManager()
    let mp = MultipeerManager()

    // choose per device before connecting
    var role: Role = .gyro

    init() {
        // IMPORTANT: use the .sks-backed scene if you have one
        let scene = GameScene.newGameScene()
        scene.scaleMode = .resizeFill
        scene.mp = mp
        self.gameScene = scene

        setupMultipeer()
        setupGameRoleFlags()
    }

    private func setupGameRoleFlags() {
        // gyro device is "remote view only"
        gameScene.isRemoteViewOnly = (role == .gyro)
        if role == .gyro {
            gameScene.tiltX = 0
        }
    }

    private func setupMultipeer() {
        mp.onReceivedMessage = { [weak self] msg in
            guard let self else { return }
            DispatchQueue.main.async {
                switch msg.type {
                case .tilt:
                    // use a as tilt
                    let x = CGFloat(msg.a ?? 0)
                    self.gameScene.applyRemoteTilt(x)

                case .jump:
                    // use a as jump force
                    let force = CGFloat(msg.a ?? Double(self.gameScene.smallJumpForce))
                    self.gameScene.applyRemoteJump(force: force)

                case .playerState:
                    // a,b,c,d = x,y,vx,vy
                    self.gameScene.applyRemotePlayerState(
                        x: CGFloat(msg.a ?? 0),
                        y: CGFloat(msg.b ?? 0),
                        vx: CGFloat(msg.c ?? 0),
                        vy: CGFloat(msg.d ?? 0)
                    )

                case .levelSeed:
                    // a = seed
                    let seed = Int32(msg.a ?? 0)
                    self.gameScene.startLevelAsJoiner(seed: seed)
                }
            }
        }

        // One device hosts, one joins
        if role == .jump {
            mp.startHosting()
        } else {
            mp.startJoining()
        }
    }

    /// Call this when you enter GAME (host starts + broadcasts seed)
    func startGameIfNeeded() {
        guard currentView == .GAME else { return }

        if role == .jump {
            let seed = Int32.random(in: Int32.min...Int32.max)
            gameScene.startLevelAsHost(seed: seed)

            // send seed in a
            mp.send(MPMessage(type: .levelSeed, a: Double(seed)))
        }
        // gyro device waits for .levelSeed then calls startLevelAsJoiner in handler
    }

    func startSensors() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard role == .gyro else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            let roll = motion.attitude.roll
            let normalized = max(-1.0, min(1.0, roll / 0.6))

            // send tilt in a
            self.mp.send(MPMessage(type: .tilt, a: normalized))
        }
    }

    func stopSensors() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// Called by UI button on the jump device (or could be called anywhere)
    func handleJumpAction() {
        // Always send jump request to host
        let force = Double(gameScene.smallJumpForce)
        mp.send(MPMessage(type: .jump, a: force))

        // Only host applies locally (joiner is remote-view-only anyway)
        if role == .jump {
            gameScene.smallJump()
        }
    }
}
