import Foundation
import SwiftUI
import Observation
import SpriteKit
import MultipeerConnectivity
import CoreMotion
import CoreLocation

enum CurrentView {
    case MAIN_MENU
    case PLAY_MENU
    case WAITING
    case JOINING
    case ROOM_LIST
    case GAME
    case RESULT
    case LEVEL_SELECTION
    case DISCONNECTED
    case ROLE_INTRO
    case LOCATION
}

enum Role {
    case gyro, jump
}

enum Level: Int {
    case DESERT = 1
    case CITY = 2
    case FOREST = 3
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
    private var isHandlingDisconnect = false
    
    var availableRooms: [Room] = []
    private var hasSentHandshake = false
    
    var useMockLevel: Bool = false

    // choose per device before connecting
    var role: Role = .gyro
    
    let locationHelper = LocationHelper()
        
    var currentLevel: Level? = nil
    var wasLevelSetByLocation = false
    var isShowingManualLocationPicker: Bool = false
    
    var startTime: Double = 0
    var elapsedTime: Double = 0
    var isTimerRunning = false
    
    @ObservationIgnored
    @AppStorage("bestTime") var bestTime: Double = 0
    var isNewBestTime: Bool = false
    
    var tiltX: Double = 0.0
    
    // Demo/testing: if set, LocationHelper should generate using this coordinate
    var manualLocationOverride: CLLocationCoordinate2D? = nil
    
    init() {
        let scene = GameScene.newGameScene()
        scene.scaleMode = .resizeFill
        scene.mp = mp
        self.gameScene = scene

        setupMultipeer()
        
        setupGameRoleFlags()
    }
    
    func locate(using coordinate: CLLocationCoordinate2D? = nil) {
        currentLevel = nil
        wasLevelSetByLocation = false
        
        // set/clear override
        manualLocationOverride = coordinate
        
        print("L1")
        locationHelper.start(override: coordinate)
        withAnimation {
            self.currentView = .LOCATION
        }
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
        mp.stop()
        isHost = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
           self.mp.startHosting(roomName: "\(UIDevice.current.name)'s Room")
           withAnimation { self.currentView = .WAITING }
       }
    }

    func browseRooms() {
        currentLevel = nil
        mp.stop()
        isHost = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.mp.startBrowsingRooms()
            withAnimation { self.currentView = .ROOM_LIST }
        }
    }
    
    func join(room: Room) {
        currentLevel = nil
        withAnimation {
            currentView = .JOINING
        }
        mp.invite(room: room)
        //mp.sendImportant(MPMessage(type: .joining))
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
                    //Host assigns roles and immediately shows role screen
                    if self.isHost {
                        self.assignRandomRolesOnce()
                        if let level = self.currentLevel {
                                self.mp.send(MPMessage(type: .levelSelected, a: Double(level.rawValue)), mode: .reliable)
                            }
                        withAnimation {
                            self.currentView = .ROLE_INTRO
                        }
                    }
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
                            self.gameScene.setEmptyBackground()
                            self.gameScene.startLevelAsHost(seed: seed)
                        }
                        self.hostStartedLevel = true
                    }

                    guard let level = self.currentLevel else {
                        print("Host has no level yet; ignoring requestLevel")
                        return
                    }
                    let seedToSend = Double(self.hostSeed ?? 1)
                    print("Level to send: \(self.currentLevel == .DESERT ? "Desert" : "City")")
                    self.mp.send(MPMessage(type: .levelSeed, a: seedToSend, b: Double(level.rawValue)))

                case .levelSeed:
                    let seed = Int32(msg.a ?? 0)
                    
                    let receivedLevel: Level? = Level(rawValue: Int(msg.b ?? 0.0))
                    print("Rceived level: \(receivedLevel == .DESERT ? "Desert" : "City")")
                    if let level = receivedLevel {
                        self.currentLevel = level
                    }
                    self.gameScene.setBackground()
                    
                    if self.useMockLevel {
                        self.gameScene.startMockLevelAsJoiner()
                    } else {
                        self.gameScene.startLevelAsJoiner(seed: seed)
                    }

                    // IMPORTANT: transition joiner into game
                    withAnimation {
                        self.currentView = .GAME
                    }

                case .assignRoles:
                    let hostIsGyro = (msg.a ?? 0) == 1
                    if !self.isHost {
                        self.role = hostIsGyro ? .jump : .gyro
                        self.setupGameRoleFlags()

                        withAnimation {
                            self.currentView = .ROLE_INTRO
                        }
                    }

                case .tilt:
                    let x = CGFloat(msg.a ?? 0)
                    self.gameScene.applyRemoteTilt(x)

                case .jump:
                    //let force = CGFloat(msg.a ?? Double(self.gameScene.smallJumpForce))
                    //self.gameScene.applyRemoteJump(force: force)
                    if self.isHost {
                        let successfull = self.gameScene.jump()
                        if successfull {
                            self.mp.send(MPMessage(type: .jumpSuccessfull))
                        }
                    } else {
                        self.gameScene.forcedJump()
                    }

                case .playerState:
                    self.gameScene.applyRemotePlayerState(
                        x: CGFloat(msg.a ?? 0),
                        y: CGFloat(msg.b ?? 0),
                        vx: CGFloat(msg.c ?? 0),
                        vy: CGFloat(msg.d ?? 0),
                        rotation: CGFloat(msg.e ?? 0),
                        wheelRotation: CGFloat(msg.f ?? 0)
                    )
                case .time:
                    let time = CGFloat(msg.a ?? 0)
                    self.elapsedTime = time
                case .finished:
                    self.gameScene.destructLevel()
                    let finishTime = CGFloat(msg.a ?? 0)
                    self.elapsedTime = finishTime
                    self.finishGame()
                case .cancelMultipeer:
                    self.cancelMultipeerAndReturnToMenu()
                case .restartedGame:
                    withAnimation {
                        self.restartGame()
                    }
                case .joining:
                    withAnimation {
                        self.currentView = .JOINING
                    }
                case .jumpSuccessfull:
                    self.gameScene.forcedJump()
                    if self.role == .jump {
                        HapticManager.tap()
                    }
                case .collect:
                    self.gameScene.collectItem()
                case .removeItem:
                    self.gameScene.removeItem(id: Int(msg.a ?? 0))
                case .levelSelected:
                    let raw = Int(msg.a ?? 0)
                    if let lvl = Level(rawValue: raw) {
                        self.currentLevel = lvl
                        print("Joiner received levelSelected:", lvl)
                    }
                }
            }
        }
        
        mp.onPeerDisconnected = { [weak self] in
            guard let self else { return }
            DispatchQueue.main.async {
                self.handlePeerDisconnected()
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
                    gameScene.setEmptyBackground()
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

    func startMenuMusicIfNeeded() {
            SoundManager.shared.playMusic("The-Pixeltown-Shuffle-2.mp3", volume: 0.35)
        }

        func stopMenuMusic() {
            SoundManager.shared.stopMusic()
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
            
            // to display the device rotation
            if self.role == .gyro {
                self.tiltX = x
                //print("Sensor: \(x)")
            }
            
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

    func handleJumpAction() {
        guard role == .jump else { return }

        let force = Double(gameScene.smallJumpForce)

        if isHost {
            let successfull = gameScene.jump()
            if successfull {
                mp.send(MPMessage(type: .jump, a: force), mode: .reliable)
            }
        } else {
            print("JUMPPPY")
            mp.send(MPMessage(type: .jump, a: force), mode: .reliable)
        }
    }
    
    func handleCollectAction() {
        if isHost {
            self.gameScene.collectItem()
        } else {
            self.mp.send(MPMessage(type: .collect))
        }
        HapticManager.tap()
    }
    
    func startTimer() {
        startTime = CFAbsoluteTimeGetCurrent()
        elapsedTime = 0.0
        isTimerRunning = true
    }
    
    func updateTimer() {
        if isTimerRunning {
            elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        }
    }
    
    func stopTimer() {
        isTimerRunning = false
    }
    
    func updateBestTime() {
        isNewBestTime = false
        if elapsedTime > 0 && elapsedTime < bestTime {
            bestTime = elapsedTime
            isNewBestTime = true
            print("Best time")
        } else if bestTime == 0 {
            bestTime = elapsedTime
            isNewBestTime = true
            print("First best time")
        }
    }
    
    var formattedElapsedTimeWithoutLabel: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        let string = formatter.string(from: elapsedTime) ?? "00:00"
        return string
    }
    
    var formattedElapsedTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        var string = formatter.string(from: elapsedTime) ?? "00:00"
        string += elapsedTime < 60 ? "s" : "min"
        return string
    }
    
    var formattedBestTime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        var string = formatter.string(from: bestTime) ?? "00:00"
        string += bestTime < 60 ? "s" : "min"
        return string
    }
    
    func finishGame() {
        stopTimer()
        updateBestTime()
        SoundManager.shared.stopMusic()
        startMenuMusicIfNeeded()
        withAnimation {
            self.currentView = .RESULT
        }
    }
    
    func selectLevel(_ level: Level) {
        self.currentLevel = level
        print("Selected level: \(level == .DESERT ? "Desert" : level == .CITY ? "City" : "Forest")")
    }
    
    func selectLevelRandomly() {
        self.currentLevel = .DESERT
    }
    
    func restartGame() {
        // Reset run-specific flags
        hostStartedLevel = false
        hostSeed = nil

        didAssignRoles = false

        // Reset timer
        elapsedTime = 0
        isTimerRunning = false
        startTime = 0

        // Recreate the scene
        let newScene = GameScene.newGameScene()
        newScene.scaleMode = .resizeFill
        newScene.mp = mp
        self.gameScene = newScene

        if isHost {
            assignRandomRolesOnce()
            withAnimation {
                currentView = .ROLE_INTRO
            }
        } else {
            withAnimation {
                currentView = .JOINING
            }
        }
    }

    func handlePeerDisconnected() {
        // Prevent repeated triggers (MCSession can spam state changes)
        guard !isHandlingDisconnect else { return }
        isHandlingDisconnect = true

        // If we're already in menu-ish screens, just clean up and go menu.
        if currentView == .MAIN_MENU || currentView == .PLAY_MENU || currentView == .ROOM_LIST || currentView == .LEVEL_SELECTION {
            cancelMultipeerAndReturnToMenu()
            isHandlingDisconnect = false
            return
        }

        // Show "Disconnected" screen
        withAnimation {
            currentView = .DISCONNECTED
        }

        // After 3s, reset everything and return to menu
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self else { return }
            self.cancelMultipeerAndReturnToMenu()
            self.isHandlingDisconnect = false
        }
    }


    func cancelMultipeerAndReturnToMenu() {
        stopTimer()
        elapsedTime = 0.0

        stopSensors()
        mp.stop()

        //Reset multiplayer / run flags
        availableRooms.removeAll()
        hostSeed = nil
        hostStartedLevel = false
        hasSentHandshake = false

        didAssignRoles = false
        isHandlingDisconnect = false
        isHost = false

        // Optional: also reset level selection per your design
        // currentLevel = .DESERT

        role = (UIDevice.current.userInterfaceIdiom == .pad) ? .jump : .gyro
        setupGameRoleFlags()

        gameScene.isRemoteViewOnly = (role == .gyro)
        gameScene.tiltX = 0
        gameScene.destructLevel()

        withAnimation {
            currentView = .MAIN_MENU
        }
    }



}
