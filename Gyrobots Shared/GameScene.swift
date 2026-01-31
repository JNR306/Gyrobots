//
//  GameScene.swift
//  Gyrobots Shared
//
//  Created by Jan-Niklas Röhlig on 18.12.25.
//

import SpriteKit
import GameplayKit
import SwiftUI

struct PhysicsCategory {
    static let none: UInt32 = 0      // 0
    static let player: UInt32 = 0x1    // 1
    static let finishLine: UInt32 = 0x2 // 2
    static let terrain: UInt32 = 0x4    // 4
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Nodes
    var player: SKSpriteNode!
    var gameCamera: SKCameraNode!
    var terrainNode: SKShapeNode!
    var obstaclesNode: SKNode!

    // MARK: - Settings
    let moveSpeed: CGFloat = 300.0
    let jumpForce: CGFloat = 1000.0
    let smallJumpForce: CGFloat = 1000.0

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
    
    // MARK: - Timer send throttling (host -> joiner)
    private var lastTimerSendTime: TimeInterval = 0
    private let timerSendInterval: TimeInterval = 1.0 / 5.0 // 5 Hz

    // MARK: - Local flags (optional / future use)
    var isMovingLeft = false
    var isMovingRight = false
    var isCrouching = false
    
    // MARK: - Paralax Background
    var backgroundLayer1: SKNode!
    var backgroundLayer2: SKNode!

    // MARK: - Scene loading
    class func newGameScene() -> GameScene {
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else { abort() }
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        setBackground()
        
        physicsWorld.gravity = CGVector(dx: 0, dy: -12.0)
        setupBackground()
        setupCamera()
    }
    
    func setBackground() {
        // Setting background color
        switch AppState.shared.currentLevel {
        case .DESERT:
            self.backgroundColor = SKColor(named: "BackgroundDesert") ?? .white
        case .CITY:
            self.backgroundColor = SKColor(named: "BackgroundCity") ?? .white
        default:
            self.backgroundColor = .white
        }
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
        // player.physicsBody?.isDynamic = false
    }

    private func configureLevel(seed: Int32) {
        // Deterministic RNG for obstacles
        rng = GKARC4RandomSource(seed: Data([
            UInt8(truncatingIfNeeded: seed & 0xFF),
            UInt8(truncatingIfNeeded: (seed >> 8) & 0xFF),
            UInt8(truncatingIfNeeded: (seed >> 16) & 0xFF),
            UInt8(truncatingIfNeeded: (seed >> 24) & 0xFF)
        ]))
    }
    
    // MARK: - Mock/Test Level -- REMOVE LATER

    func startMockLevelAsHost() {
        isRemoteViewOnly = false
        buildMockLevel()
        setupPlayer()
    }

    func startMockLevelAsJoiner() {
        isRemoteViewOnly = true
        buildMockLevel()
        setupPlayer()
        player.physicsBody?.isDynamic = false
    }

    private func buildMockLevel() {
        // wipe previous run
        removeAllChildren()
        noise = nil
        rng = nil
        lastStateSendTime = 0

        backgroundColor = .darkGray
        physicsWorld.gravity = CGVector(dx: 0, dy: -12.0)

        setupCamera()

        // Ground (flat)
        let groundY: CGFloat = -200
        let groundWidth: CGFloat = 4000
        let groundHeight: CGFloat = 80

        let ground = SKShapeNode(rectOf: CGSize(width: groundWidth, height: groundHeight))
        ground.fillColor = .black
        ground.strokeColor = .lightGray
        ground.lineWidth = 2
        ground.position = CGPoint(x: groundWidth * 0.5 - 400, y: groundY)
        ground.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: groundWidth, height: groundHeight))
        ground.physicsBody?.isDynamic = false
        ground.physicsBody?.friction = 0.8
        addChild(ground)

        // A few platforms to test jumping
        func addPlatform(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 30) {
            let p = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 6)
            p.fillColor = .gray
            p.strokeColor = .white
            p.lineWidth = 1
            p.position = CGPoint(x: x, y: y)
            p.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: w, height: h))
            p.physicsBody?.isDynamic = false
            p.physicsBody?.friction = 0.8
            addChild(p)
        }

        addPlatform(x: 200,  y: groundY + 120, w: 220)
        addPlatform(x: 520,  y: groundY + 200, w: 220)
        addPlatform(x: 860,  y: groundY + 280, w: 260)
        addPlatform(x: 1250, y: groundY + 180, w: 300)

        // A “wall” to test bumping / stopping
        let wall = SKShapeNode(rectOf: CGSize(width: 60, height: 300), cornerRadius: 8)
        wall.fillColor = .orange
        wall.strokeColor = .clear
        wall.position = CGPoint(x: 1650, y: groundY + 150)
        wall.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 60, height: 300))
        wall.physicsBody?.isDynamic = false
        addChild(wall)
    }


    // MARK: - Multiplayer hooks

    /// Tilt updates can come from the gyro device.
    func applyRemoteTilt(_ x: CGFloat) {
        tiltX = x
    }

    /// Joiner mirrors the host player state.
    func applyRemotePlayerState(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat) {
        guard isRemoteViewOnly else { return }
        guard player != nil else { return } // joiner might receive state before scene started

        player.position = CGPoint(x: x, y: player.position.y)
        player.physicsBody?.velocity = CGVector(dx: vx, dy: vy)
    }

    // MARK: - Setup

    private func setupCamera() {
        gameCamera = SKCameraNode()
        if UIDevice.current.userInterfaceIdiom == .phone {
            gameCamera.setScale(1.5)
        }
        addChild(gameCamera)
        camera = gameCamera
    }
    
    func setupBackground() {
        // 1. Determine Asset Names
        var assetName = "City"
        switch AppState.shared.currentLevel {
            case .DESERT: assetName = "Desert"
            case .CITY: assetName = "City"
            case .FOREST: assetName = "Desert"
            default : assetName = "Desert"
        }
    
    
        let image1 = "Background\(assetName)1"
        let image2 = "Background\(assetName)2"
        
        // 2. Create Containers
        backgroundLayer1 = SKNode()
        backgroundLayer2 = SKNode()
        
        // Z-Positions: Player is 0. Backgrounds must be negative.
        // Layer 1 is closer than Layer 2, so it sits on top (-10 vs -20).
        backgroundLayer1.zPosition = -10
        backgroundLayer2.zPosition = -20
        
        addChild(backgroundLayer1)
        addChild(backgroundLayer2)
        
        // 3. Helper to Tile Images
        // This function places copies of the image side-by-side to cover the world width
        func createStrip(imageName: String, parentNode: SKNode, factor: CGFloat, yOffset: CGFloat) {
                let tempSprite = SKSpriteNode(imageNamed: imageName)
                let width = tempSprite.size.width
                
                // Calculate how many sprites we need to cover the level
                // Since parallax layers move slower, they actually need LESS width than the full level,
                // but tiling the full length is the safest/easiest way to prevent gaps.
                let numberOfTiles = Int((rightFixedX - leftFixedX) / width) + 5
                
                for i in 0..<numberOfTiles {
                    let sprite = SKSpriteNode(imageNamed: imageName)
                    sprite.anchorPoint = CGPoint(x: 0, y: 0.5) // Anchor left-center
                    // Position starting from leftFixedX
                    sprite.position = CGPoint(x: leftFixedX + CGFloat(i) * width, y: yOffset)
                    
                    // Optional: Scale to fit screen height if needed
                     sprite.size = CGSize(width: width, height: self.size.height)
                    
                    parentNode.addChild(sprite)
                }
            }
            
            // 4. Generate the Strips
            createStrip(imageName: image1, parentNode: backgroundLayer1, factor: 0.2, yOffset: 100.0)
            createStrip(imageName: image2, parentNode: backgroundLayer2, factor: 0.5, yOffset: 200.0)
        }

    func setupPlayer() {
        // Remove an existing player if we’re restarting / re-entering
        if let existing = player {
            existing.removeFromParent()
        }
        childNode(withName: "player")?.removeFromParent()
        var imageName = "PlayerCity"
        switch AppState.shared.currentLevel {
            case .CITY: imageName = "RobotCity"
            case .DESERT: imageName = "RobotDesert"
            case .FOREST: imageName = "RobotDesert"
            default : imageName = "RobotCity"
        }
        
        player = SKSpriteNode(imageNamed: imageName)
        player.name = "player"
        
        let startY = 200
        player.position = CGPoint(x: 0, y: startY)

        player.physicsBody = SKPhysicsBody(
            rectangleOf: player.size,
            center: CGPoint(x: 0, y: 0)
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
    
    func destructLevel() {
        player?.removeFromParent()
        gameCamera?.removeFromParent()
        terrainNode?.removeFromParent()
        obstaclesNode?.removeFromParent()
        
        backgroundLayer1?.removeFromParent()
        backgroundLayer2?.removeFromParent()
    }

    // MARK: - Procedural Terrain
    
    let startX: CGFloat = 0
    let endX: CGFloat = 15000
    let leftFixedX: CGFloat = -2000
    let rightFixedX: CGFloat = 17000
    let topFixedY: CGFloat = 2000
    let bottomFixedY: CGFloat = -2000
    
    func generateTerrain() {
        obstaclesNode = SKNode()
        addChild(obstaclesNode)
        let path = CGMutablePath()
        
        // Start the shape far below/left to ensure it's solid
        path.move(to: CGPoint(x: leftFixedX, y: bottomFixedY))
        path.addLine(to: CGPoint(x: leftFixedX, y: topFixedY))
        path.addLine(to: CGPoint(x: startX-1000, y: topFixedY))
        path.addLine(to: CGPoint(x: startX-1000, y: 0))
        
        let totalSegments = Int((endX-startX))/500
        var isTerrainHigh: [Bool] = Array(repeating: false, count: totalSegments)
        
        // 1. Calculate Heights
        for i in 1..<isTerrainHigh.count {
            if let rng = rng {
                // STREAK PREVENTION:
                // If the last 2 sections were flat (false), FORCE a hill (true).
                // Otherwise, flip a coin (50/50).
                if i >= 2 && !isTerrainHigh[i-1] && !isTerrainHigh[i-2] {
                    isTerrainHigh[i] = true
                } else {
                    isTerrainHigh[i] = rng.nextInt(upperBound: 2) == 0
                }
            } else {
                isTerrainHigh[i] = Bool.random()
            }
        }
        
        // 2. Draw Path & Spawn Obstacles
        for i in 0..<isTerrainHigh.count {
            let chunkX = CGFloat(i * 500)
            let chunkY: CGFloat = isTerrainHigh[i] ? 100 : 0
            
            // Draw lines
            if i == 0 {
                path.addLine(to: CGPoint(x: chunkX, y: 0))
            } else {
                let prevY: CGFloat = isTerrainHigh[i-1] ? 100 : 0
                path.addLine(to: CGPoint(x: chunkX, y: prevY))
            }
            path.addLine(to: CGPoint(x: chunkX + 100, y: chunkY))
            
            if i > 1, let rng = rng, rng.nextInt(upperBound: 3) < 2 {
                spawnRandomObstacle(at: chunkX + 250, groundY: chunkY)
            }
        }
        
        // Close shape
        path.addLine(to: CGPoint(x: endX+200, y: isTerrainHigh.last ?? false ? 100 : 0))
        path.addLine(to: CGPoint(x: endX+200, y: topFixedY))
        path.addLine(to: CGPoint(x: rightFixedX, y: topFixedY))
        path.addLine(to: CGPoint(x: rightFixedX, y: bottomFixedY))
        path.closeSubpath()

        terrainNode = SKShapeNode(path: path)
        terrainNode.fillColor = SKColor(named: "Terrain") ?? .white
        terrainNode.strokeColor = .clear
        
        terrainNode.physicsBody = SKPhysicsBody(edgeLoopFrom: path)
        terrainNode.physicsBody?.isDynamic = false
        terrainNode.physicsBody?.friction = 0.5
        terrainNode.physicsBody?.categoryBitMask = PhysicsCategory.terrain
        
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
            if !isRemoteViewOnly {
                destructLevel()
                mp?.sendImportant(MPMessage(type: .finished, a: AppState.shared.elapsedTime))
                AppState.shared.finishGame()
            }
        }
    }

    func spawnRandomObstacle(at x: CGFloat, groundY: CGFloat) {
        // 1. Determine Asset Name based on Level
        var assetPrefix = "City" // Default
        if AppState.shared.currentLevel == .DESERT {
            assetPrefix = "Beach"
        }
        
        // Choose random size
        var isLarge = false
        if let rng = rng {
            isLarge = rng.nextInt(upperBound: 2) == 0
        } else {
            isLarge = Bool.random()
        }
        
        let sizeSuffix = isLarge ? "ObstacleLarge" : "ObstacleSmall"
        let imageName = "\(assetPrefix)\(sizeSuffix)"
        
        let obstacle = SKSpriteNode(imageNamed: imageName)
        let targetHeight: CGFloat = isLarge ? 110.0 : 90.0
        
        if let texture = obstacle.texture {
            // Calculate width to maintain the original aspect ratio
            let aspectRatio = texture.size().width / texture.size().height
            obstacle.size = CGSize(width: targetHeight * aspectRatio, height: targetHeight)
        } else {
            // Fallback if image is missing
            obstacle.size = CGSize(width: targetHeight, height: targetHeight)
            obstacle.color = .red
        }
        
        // 5. Position
        // Place it sitting exactly on top of the ground
        obstacle.position = CGPoint(x: x, y: groundY + obstacle.size.height / 2)
        
        // 6. Physics Body
        // Matches the visual size exactly
        obstacle.physicsBody = SKPhysicsBody(rectangleOf: obstacle.size)
        obstacle.physicsBody?.isDynamic = false
        obstacle.physicsBody?.friction = 0.5
        obstacle.physicsBody?.categoryBitMask = PhysicsCategory.terrain
        
        obstaclesNode.addChild(obstacle)
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
        
        if let cam = gameCamera {
            backgroundLayer1.position.x = cam.position.x * 0.1
            backgroundLayer2.position.x = cam.position.x * 0.5
            
            backgroundLayer1.position.y = cam.position.y * 0.05
            backgroundLayer2.position.y = cam.position.y * 0.1
        }
        
        AppState.shared.updateTimer()

        // Host broadcasts authoritative player state at 30 Hz
        if !isRemoteViewOnly, let body = player.physicsBody, currentTime - lastStateSendTime >= stateSendInterval {
            lastStateSendTime = currentTime

            mp?.send(MPMessage(
                type: .playerState,
                a: Double(player.position.x),
                b: Double(player.position.y),
                c: Double(body.velocity.dx),
                d: Double(body.velocity.dy)
            ))
        }
        
        // Host broadcasts timer state at 5 Hz
        if !isRemoteViewOnly, currentTime - lastTimerSendTime >= timerSendInterval {
            lastTimerSendTime = currentTime
            
            mp?.send(MPMessage(type: .time, a: AppState.shared.elapsedTime))
        }
    }

    // MARK: - Actions

    func isGrounded() -> Bool {
        guard let body = player.physicsBody else { return false }

        // Use the physics body's actual frame
        let frame = body.node!.frame
        let footY = frame.minY

        let start = CGPoint(x: player.position.x, y: footY + 5)
        let end   = CGPoint(x: player.position.x, y: footY - 20)

        var hit = false
        physicsWorld.enumerateBodies(alongRayStart: start, end: end) { otherBody, _, _, stop in
            if otherBody !== body {
                hit = true
                stop.pointee = true
            }
        }
        return hit
    }
    
    func forcedJump() {
        guard isRemoteViewOnly else { return }
        player.physicsBody?.velocity.dy = 0
        player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: smallJumpForce))
    }

    // return if jump was successfull
    func jump() -> Bool {
        guard !isRemoteViewOnly else { return false }
        if isGrounded() {
            if AppState.shared.role == .jump {
                HapticManager.tap()
            }
            player.physicsBody?.velocity.dy = 0
            player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: smallJumpForce))
            return true
        } else {
            return false
        }
    }

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
