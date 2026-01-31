import Foundation
import SwiftUI
import Observation
import SpriteKit
import MultipeerConnectivity
import CoreMotion

enum CurrentView {
    case MAIN_MENU
    case PLAY_MENU
    case WAITING
    case ROOM_LIST
    case GAME
    case RESULT
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
    var isHost: Bool = false

    let motionManager = CMMotionManager()
    let mp = MultipeerManager()
    
    private var hostSeed: Int32?
    private var hostStartedLevel = false
    private var didAssignRoles = false
    
    var availableRooms: [Room] = []
    private var hasSentHandshake = false
    
    var useMockLevel: Bool = false

    // choose per device before connecting
    var role: Role = .gyro
    
    //let locationHelper = LocationHelper()
    
    var currentTime: Double? = nil
    var bestTime: Double? = nil
    
    var currentLevel: Level? = .DESERT
    var startTime: Double = 0
    var elapsedTime: Double = 0
    var isTimerRunning = false
    
    init() {
        // IMPORTANT: use the .sks-backed scene if you have one
        let scene = GameScene.newGameScene()
        scene.scaleMode = .resizeFill
        scene.mp = mp
        self.gameScene = scene

        setupMultipeer()
        
        //locationHelper.start()
        setupGameRoleFlags()
    }

    private func setupGameRoleFlags() {
        // Only host simulates
        gameScene.isRemoteViewOnly = !isHost

        // Start/stop sensors depending on current role
        if role == .gyro {
            startSensors()
        } else {
            stopSensors()
            gameScene.tiltX = 0
        }
    }

    
    func createRoom() {
        isHost = true
        mp.startHosting(roomName: "\(UIDevice.current.name)'s Room")
        currentView = .WAITING
    }

    func browseRooms() {
        isHost = false
        mp.startBrowsingRooms()
        currentView = .ROOM_LIST
    }
    
    func join(room: Room) {
        currentView = .WAITING
        mp.invite(room: room)
    }
    
    private func assignRandomRolesOnce() {
        guard !didAssignRoles else { return }
        didAssignRoles = true

        if isHost {
            // random: host is gyro or jump
            let hostIsGyro = Bool.random()
            role = hostIsGyro ? .gyro : .jump
            setupGameRoleFlags()

            // tell peer to take the opposite role
            mp.send(MPMessage(type: .assignRoles, a: hostIsGyro ? 1 : 0))
        }
        // joiner will set role when receiving assignRoles
    }

    private func setupMultipeer() {
        mp.onConnectedPeersChanged = { [weak self] peers in
            guard let self else { return }
            DispatchQueue.main.async {
                if peers.count == 1 { // 1v1
                    // Assign random control roles once connected
                    self.assignRandomRolesOnce()

                    // Move both devices into the game view
                    self.currentView = .GAME
                }
            }
        }
        mp.onFoundRooms = { [weak self] rooms in
            DispatchQueue.main.async {
                self?.availableRooms = rooms
            }
        }
        mp.onReceivedMessage = { [weak self] msg in
            guard let self else { return }
            DispatchQueue.main.async {
                switch msg.type {

                case .requestLevel:
                    // Only host answers
                    guard self.isHost else { return }

                        if !self.hostStartedLevel {
                            if self.useMockLevel {
                                self.gameScene.startMockLevelAsHost()
                                self.hostSeed = 1
                            } else {
                                let seed = Int32.random(in: Int32.min...Int32.max)
                                self.hostSeed = seed
                                self.gameScene.startLevelAsHost(seed: seed)
                            }
                            self.hostStartedLevel = true
                        }

                        let seedToSend = Double(self.hostSeed ?? 1)
                        self.mp.send(MPMessage(type: .levelSeed, a: seedToSend))

                case .levelSeed:
                    let seed = Int32(msg.a ?? 0)
                    if self.useMockLevel {
                        self.gameScene.startMockLevelAsJoiner()
                    } else {
                        self.gameScene.startLevelAsJoiner(seed: seed)
                    }

                    // IMPORTANT: transition joiner into game
                    self.currentView = .GAME

                case .assignRoles:
                    let hostIsGyro = (msg.a ?? 0) == 1
                    if !self.isHost {
                        self.role = hostIsGyro ? .jump : .gyro
                        self.setupGameRoleFlags()
                    }

                case .tilt:
                    let x = CGFloat(msg.a ?? 0)
                    self.gameScene.applyRemoteTilt(x)

                case .jump:
                    let force = CGFloat(msg.a ?? Double(self.gameScene.smallJumpForce))
                    self.gameScene.applyRemoteJump(force: force)

                case .playerState:
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
                case .time:
                    let time = CGFloat(msg.a ?? 0)
                    self.elapsedTime = time
                case .finished:
                    self.gameScene.destructLevel()
                    withAnimation {
                        self.currentView = .RESULT
                    }
                }

            }
        }

        // One device hosts, one joins, for now, ipad = host (jump)
        //if role == .gyro {
        //    mp.startHosting()
        //} else {
        //    mp.startJoining()
        //}
    }

    /// Call this when you enter GAME (host starts + broadcasts seed)
    func startGameIfNeeded() {
        guard currentView == .GAME else { return }

        if isHost {
            // Host: start once, but DO NOT broadcast blindly (wait for request)
            if !hostStartedLevel {
                if useMockLevel {
                    gameScene.startMockLevelAsHost()
                    hostSeed = 1
                } else {
                    let seed = Int32.random(in: Int32.min...Int32.max)
                    hostSeed = seed
                    gameScene.startLevelAsHost(seed: seed)
                    mp.send(MPMessage(type: .requestLevel))
                }
                hostStartedLevel = true
            }
            
            self.startTimer()
        } else {
            // Joiner: request level from host when Play is pressed
            mp.send(MPMessage(type: .requestLevel))
        }
    }

    func startSensors() {
        guard motionManager.isDeviceMotionAvailable else { return }
        guard role == .gyro else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self else { return }
            guard error == nil, let motion else { return }

            let g = motion.gravity

            // Current interface orientation (iPad can be portrait or landscape)
            let orientation: UIInterfaceOrientation = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .effectiveGeometry.interfaceOrientation ?? .portrait

            // Map "tilt left/right" to a consistent axis depending on orientation.
            // (Signs chosen so it feels the same directionally when rotating the device.)
            let raw: Double
            switch orientation {
            case .portrait:
                raw = g.x
            case .portraitUpsideDown:
                raw = -g.x
            case .landscapeLeft:
                raw = g.y
            case .landscapeRight:
                raw = -g.y
            default:
                raw = g.x
            }

            let sensitivity: Double = 0.35
            let normalized = max(-1.0, min(1.0, raw / sensitivity))
            let x = CGFloat(normalized)

            if self.isHost {
                self.gameScene.tiltX = x
            } else {
                self.mp.send(MPMessage(type: .tilt, a: normalized), mode: .unreliable)
            }
        }
    }




    func stopSensors() {
        motionManager.stopDeviceMotionUpdates()
    }

    /// Called by UI button on the jump device (or could be called anywhere)
    func handleJumpAction() {
        guard role == .jump else { return }

        let force = Double(gameScene.smallJumpForce)

        if isHost {
            gameScene.smallJump()
        } else {
            mp.send(MPMessage(type: .jump, a: force), mode: .reliable)
        }
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
    func cancelMultipeerAndReturnToMenu() {
        // 1. Stop motion updates safely (gyro device)
        stopSensors()

        // 2. Stop ALL multipeer activity
        //    (advertising, browsing, session)
        mp.stop()

        // 3. Reset multiplayer / room state
        availableRooms.removeAll()
        hostSeed = nil
        hostStartedLevel = false
        hasSentHandshake = false

        // 4. Reset role to a safe default
        //    (actual role will be set again when creating/joining)
        role = (UIDevice.current.userInterfaceIdiom == .pad) ? .jump : .gyro
        setupGameRoleFlags()

        // 5. (Optional but recommended) reset scene-side MP state
        gameScene.isRemoteViewOnly = (role == .gyro)
        gameScene.tiltX = 0

        // 6. Navigate back to main menu
        withAnimation {
            currentView = .MAIN_MENU
        }
    }


}
