//
//  GameScene.swift
//  Gyrobots Shared
//
//  Created by Jan-Niklas Röhlig on 18.12.25.
//

import SpriteKit
import GameplayKit

struct PhysicsCategory {
    static let none: UInt32 = 0      // 0
    static let player: UInt32 = 0x1    // 1
    static let finishLine: UInt32 = 0x2 // 2
    static let terrain: UInt32 = 0x4    // 4
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Nodes
    var player: SKShapeNode!
    var gameCamera: SKCameraNode!
    var terrainNode: SKShapeNode!

    // MARK: - Settings
    let moveSpeed: CGFloat = 300.0
    let jumpForce: CGFloat = 800.0
    let smallJumpForce: CGFloat = 450.0
    let playerSize = CGSize(width: 50, height: 100)

    // MARK: - Multiplayer
    weak var mp: MultipeerManager?

    /// If true: this device does NOT simulate physics; it only mirrors host state.
    var isRemoteViewOnly: Bool = false

    // MARK: - Input (fed by host locally or from peer)
    /// Horizontal input in [-1, 1]
    var tiltX: CGFloat = 0
    let tiltDeadzone: CGFloat = 0.08

    // MARK: - Seeded generation
    private var noise: GKNoise?
    private var rng: GKRandomSource?

    // MARK: - State send throttling (host -> joiner)
    private var lastStateSendTime: TimeInterval = 0
    private let stateSendInterval: TimeInterval = 1.0 / 30.0 // 30 Hz

    // MARK: - Local flags (optional / future use)
    var isMovingLeft = false
    var isMovingRight = false
    var isCrouching = false

    // MARK: - Scene loading
    class func newGameScene() -> GameScene {
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else { abort() }
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        // Setting background color
        switch AppState.shared.currentLevel {
        case .DESERT:
            self.backgroundColor = SKColor(named: "BackgroundDesert") ?? .white
        case .CITY:
            self.backgroundColor = SKColor(named: "BackgroundCity") ?? .white
        case .none:
            self.backgroundColor = .white
        }
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -12.0)

        setupCamera()

        // 🔹 IMPORTANT:
        // Do not start generating the world here.
        // Host will call startLevelAsHost(seed:)
        // Joiner will call startLevelAsJoiner(seed:)
    }

    // MARK: - Level start (seeded)

    /// Host calls this once it decides the seed.
    func startLevelAsHost(seed: Int32) {
        isRemoteViewOnly = false
        configureLevel(seed: seed)
        generateTerrain()
        setupPlayer()
        
        print("Started level as host")

        self.physicsWorld.contactDelegate = self
    }

    /// Joiner calls this after receiving the host’s seed.
    func startLevelAsJoiner(seed: Int32) {
        isRemoteViewOnly = true
        configureLevel(seed: seed)
        generateTerrain()
        setupPlayer()
        
        print("Started level as joiner")

        // Joiner should not simulate
        player.physicsBody?.isDynamic = false
    }

    private func configureLevel(seed: Int32) {
        let source = GKPerlinNoiseSource(
            frequency: 0.002,
            octaveCount: 3,
            persistence: 0.5,
            lacunarity: 2.0,
            seed: seed
        )
        noise = GKNoise(source)

        // Deterministic RNG for obstacles
        rng = GKARC4RandomSource(seed: Data([
            UInt8(truncatingIfNeeded: seed & 0xFF),
            UInt8(truncatingIfNeeded: (seed >> 8) & 0xFF),
            UInt8(truncatingIfNeeded: (seed >> 16) & 0xFF),
            UInt8(truncatingIfNeeded: (seed >> 24) & 0xFF)
        ]))
    }

    // MARK: - Multiplayer hooks

    /// Tilt updates can come from the gyro device.
    func applyRemoteTilt(_ x: CGFloat) {
        tiltX = x
    }

    /// Jump request (applied only on host).
    func applyRemoteJump(force: CGFloat) {
        guard !isRemoteViewOnly else { return }
        jump(with: force)
    }

    /// Joiner mirrors the host player state.
    func applyRemotePlayerState(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat) {
        guard isRemoteViewOnly else { return }
        guard player != nil else { return } // joiner might receive state before scene started

        player.position = CGPoint(x: x, y: y)
        player.physicsBody?.velocity = CGVector(dx: vx, dy: vy)
    }

    // MARK: - Setup

    private func setupCamera() {
        gameCamera = SKCameraNode()
        addChild(gameCamera)
        camera = gameCamera
    }

    func setupPlayer() {
        let rect = CGRect(x: -playerSize.width / 2, y: 0, width: playerSize.width, height: playerSize.height)
        player = SKShapeNode(rect: rect)
        player.fillColor = SKColor.red
        player.strokeColor = SKColor.clear
        
        let startY = 100
        player.position = CGPoint(x: 0, y: startY)

        player.physicsBody = SKPhysicsBody(
            rectangleOf: playerSize,
            center: CGPoint(x: 0, y: playerSize.height / 2)
        )
        player.physicsBody?.isDynamic = true
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.friction = 0.2
        player.physicsBody?.restitution = 0.0
        player.physicsBody?.mass = 1.0
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.collisionBitMask = PhysicsCategory.terrain
        player.physicsBody?.contactTestBitMask = PhysicsCategory.finishLine
        
        addChild(player)
    }

    // MARK: - Procedural Terrain (Perlin Noise)
    
    func getNoiseValue(at x: CGFloat) -> CGFloat {
        guard let noise else { return 0 } // safety until configured
        let position = vector_float2(Float(x), 0)
        let noiseValue = noise.value(atPosition: position)
        return CGFloat(noiseValue)
    }
    
    let startX: CGFloat = 0
    let endX: CGFloat = 5000
    let leftFixedX: CGFloat = -2000
    let rightFixedX: CGFloat = 7000
    let topFixedY: CGFloat = 2000
    let bottomFixedY: CGFloat = -2000
    
    func generateTerrain() {
        let path = CGMutablePath()
        
        path.move(to: CGPoint(x: leftFixedX, y: bottomFixedY))
        path.addLine(to: CGPoint(x: leftFixedX, y: topFixedY))
        path.addLine(to: CGPoint(x: startX-200, y: topFixedY))
        path.addLine(to: CGPoint(x: startX-200, y: 0))
        
        var isTerrainHigh: [Bool] = Array(repeating: false, count: Int((endX-startX))/500)
        for i in 1..<isTerrainHigh.count {
            isTerrainHigh[i] = getNoiseValue(at: CGFloat(i*500)) > 0 ? true : false
        }
        print(isTerrainHigh)
        for i in 0..<isTerrainHigh.count {
            if i == 0 {
                path.addLine(to: CGPoint(x: i*500, y: 0))
            } else {
                path.addLine(to: CGPoint(x: i*500, y: isTerrainHigh[i-1] ? 100 : 0))
            }
            path.addLine(to: CGPoint(x: i*500+100, y: isTerrainHigh[i] ? 100 : 0))
        }
        //close shape
        path.addLine(to: CGPoint(x: endX+200, y: isTerrainHigh.last ?? false ? 100 : 0))
        path.addLine(to: CGPoint(x: endX+200, y: topFixedY))
        path.addLine(to: CGPoint(x: rightFixedX, y: topFixedY))
        path.addLine(to: CGPoint(x: rightFixedX, y: bottomFixedY))
        path.closeSubpath()

        terrainNode = SKShapeNode(path: path)
        terrainNode.fillColor = SKColor(named: "Terrain") ?? .white
        terrainNode.strokeColor = .clear
        
        terrainNode.physicsBody = SKPhysicsBody(edgeLoopFrom: path) //hitbox is of course same path
        terrainNode.physicsBody?.isDynamic = false
        terrainNode.physicsBody?.friction = 0.5 //interacts with player friciton
        
        addChild(terrainNode)
        
        addFinishLine()
    }
    
    func addFinishLine() {
        //Finish line
        
        let dashedLine = SKNode()
        let dashLength: CGFloat = 40
        let gapLength: CGFloat = 20
        var currentY: CGFloat = topFixedY
        
        while currentY > bottomFixedY {
            let dash = SKShapeNode(rectOf: CGSize(width: 10, height: dashLength))
            dash.fillColor = SKColor(named: "Terrain") ?? .white
            dash.strokeColor = .clear
            dash.position = CGPoint(x: endX, y: currentY)
            dashedLine.addChild(dash)
            
            currentY -= dashLength + gapLength
        }
        
        dashedLine.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 10, height: topFixedY-bottomFixedY), center: CGPoint(x: endX, y: 0))
        dashedLine.physicsBody?.isDynamic = false
        dashedLine.physicsBody?.categoryBitMask = PhysicsCategory.finishLine
        dashedLine.physicsBody?.collisionBitMask = PhysicsCategory.none
        dashedLine.physicsBody?.contactTestBitMask = PhysicsCategory.player
        
        addChild(dashedLine)
    }
    
    func didBegin(_ contact: SKPhysicsContact) {
        let contactMask = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask
        
        // Check if the combination is Player + FinishLine
        if contactMask == (PhysicsCategory.player | PhysicsCategory.finishLine) {
            AppState.shared.stopTimer()
            AppState.shared.currentView = .RESULT
        }
    }

    func spawnRandomObstacle(at x: CGFloat, groundY: CGFloat) {
        guard let rng else { return }

        let isHigh = (rng.nextInt(upperBound: 2) == 0)
        let size = CGSize(width: 60, height: 60)

        let obstacle = SKShapeNode(rectOf: size)
        obstacle.fillColor = .orange
        obstacle.lineWidth = 0

        let yOffset = isHigh ? 130.0 : 30.0
        obstacle.position = CGPoint(x: x, y: groundY + yOffset)

        obstacle.physicsBody = SKPhysicsBody(rectangleOf: size)
        obstacle.physicsBody?.isDynamic = false

        addChild(obstacle)
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard player != nil else { return }

        // Host simulates movement
        if !isRemoteViewOnly {
            var xInput = tiltX
            if abs(xInput) < tiltDeadzone { xInput = 0 }
            player.physicsBody?.velocity.dx = xInput * moveSpeed
        }

        // Camera follows on both devices
        if let cam = gameCamera, let p = player {
            let targetX = p.position.x
            let targetY = p.position.y + 100

            let currentY = cam.position.y
            let newY = currentY + (targetY - currentY) * 0.1

            cam.position = CGPoint(x: targetX, y: newY)
        }
        
        AppState.shared.updateTimer()

        // Host broadcasts authoritative player state at 30 Hz
        if !isRemoteViewOnly,
           let body = player.physicsBody,
           currentTime - lastStateSendTime >= stateSendInterval {

            lastStateSendTime = currentTime

            mp?.send(MPMessage(
                type: .playerState,
                a: Double(player.position.x),
                b: Double(player.position.y),
                c: Double(body.velocity.dx),
                d: Double(body.velocity.dy)
            ))
        }
    }

    // MARK: - Actions

    func isGrounded() -> Bool {
        guard player.physicsBody != nil else { return false }

        let start = player.position
        let end = CGPoint(x: start.x, y: start.y - 55)

        var hitGround = false
        physicsWorld.enumerateBodies(alongRayStart: start, end: end) { body, _, _, stop in
            if body != self.player.physicsBody {
                hitGround = true
                stop.pointee = true
            }
        }
        return hitGround
    }

    func jump(with force: CGFloat) {
        guard !isRemoteViewOnly else { return }
        if isGrounded() {
            player.physicsBody?.velocity.dy = 0
            player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: force))
        }
    }

    func jump() { jump(with: jumpForce) }
    func smallJump() { jump(with: smallJumpForce) }

    func startCrouch() {
        if !isCrouching {
            player.yScale = 0.5
            isCrouching = true
        }
    }

    func stopCrouch() {
        if isCrouching {
            player.yScale = 1.0
            isCrouching = false
        }
    }
}
