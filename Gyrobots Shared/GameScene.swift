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
    static let none: UInt32 = 0
    static let player: UInt32 = 0x1
    static let finishLine: UInt32 = 0x2
    static let terrain: UInt32 = 0x4
    static let item: UInt32 = 0x8
}

final class GameScene: SKScene, SKPhysicsContactDelegate {
    
    // MARK: - Nodes
    var player: SKSpriteNode!
    var gameCamera: SKCameraNode!
    var terrainNode: SKShapeNode!
    var obstaclesNode: SKNode!
    var bgDecorationsNode: SKNode!

    // MARK: - Settings
    var baseMoveSpeed: CGFloat = 300.0
    var moveSpeed: CGFloat = 300.0
    var boostMultiplier: CGFloat = 1.5
    var isSpeedBoostActive = false

    let jumpForce: CGFloat = 1000.0
    let smallJumpForce: CGFloat = 1000.0
    
    //Player character visual tilt
    let maxTilt: CGFloat = 0.15
    let leanSpeed: CGFloat = 0.1

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
    
    var generatedItemsCount = 0
    
    var allTerrainNodes: [SKNode] = []
    var allSlopeStarts: [(x: CGFloat, up: Bool)] = [] // left x coordinate of all slopes

    // MARK: - Scene loading
    class func newGameScene() -> GameScene {
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else { abort() }
        scene.scaleMode = .resizeFill
        return scene
    }

    override func didMove(to view: SKView) {
        //view.showsPhysics = true
        setBackground()
        physicsWorld.gravity = CGVector(dx: 0, dy: -12.0)
        setupCamera()
    }
    
    func setBackground() {
        // Setting background color
        switch AppState.shared.currentLevel {
        case .DESERT:
            self.backgroundColor = SKColor(named: "BackgroundDesert") ?? .white
        case .CITY:
            self.backgroundColor = SKColor(named: "BackgroundCity") ?? .white
        case .some(.FOREST):
            self.backgroundColor = SKColor(named: "BackgroundForest") ?? .white
        case .none:
            self.backgroundColor = .white
        }
    }
    
    func setEmptyBackground() {
        self.backgroundColor = SKColor(named: "Terrain") ?? .white
    }

    // MARK: - Level start (seeded)

    /// Host calls this once it decides the seed.
    func startLevelAsHost(seed: Int32) {
        isRemoteViewOnly = false
        configureLevel(seed: seed)
        generateTerrain()
        setupPlayer()
        
        startLevelMusic()
        
        print("Started level as host")

        self.physicsWorld.contactDelegate = self
    }

    /// Joiner calls this after receiving the host’s seed.
    func startLevelAsJoiner(seed: Int32) {
        isRemoteViewOnly = true
        configureLevel(seed: seed)
        generateTerrain()
        setupPlayer()
        
        startLevelMusic()
        
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
    func applyRemotePlayerState(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, rotation: CGFloat, wheelRotation: CGFloat) {
        guard isRemoteViewOnly else { return }
        guard player != nil else { return } // joiner might receive state before scene started

        player.position = CGPoint(x: x, y: player.position.y)
        player.zRotation = rotation
        player.physicsBody?.velocity = CGVector(dx: vx, dy: vy)
        player.childNode(withName: "wheel")?.zRotation = wheelRotation
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
        // get the right asset
        var assetName = "City"
        switch AppState.shared.currentLevel {
            case .DESERT: assetName = "Desert"
            case .CITY: assetName = "City"
            case .FOREST: assetName = "Forest"
            default : assetName = "City"
        }
    
        let image1 = "Background\(assetName)1"
        let image2 = "Background\(assetName)2"
        
        // creat containers
        backgroundLayer1 = SKNode()
        backgroundLayer2 = SKNode()
        
        backgroundLayer1.zPosition = -10
        backgroundLayer2.zPosition = -20
        
        addChild(backgroundLayer1)
        addChild(backgroundLayer2)
        
        // helper for tiling images
        func createStrip(imageName: String, parentNode: SKNode, factor: CGFloat, yOffset: CGFloat) {
            let tempSprite = SKSpriteNode(imageNamed: imageName)
            let width = tempSprite.size.width
            
            // how many sprites to cover whole level
            let numberOfTiles = Int((rightFixedX - leftFixedX) / width) + 5
            
            for i in 0..<numberOfTiles {
                let sprite = SKSpriteNode(imageNamed: imageName)
                sprite.anchorPoint = CGPoint(x: 0, y: 0.5)
                sprite.position = CGPoint(x: leftFixedX + CGFloat(i) * width, y: yOffset)
                 sprite.size = CGSize(width: width, height: self.size.height)
                
                parentNode.addChild(sprite)
            }
        }
        
        // generate strips
        createStrip(imageName: image1, parentNode: backgroundLayer1, factor: 0.2, yOffset: 50.0)
        createStrip(imageName: image2, parentNode: backgroundLayer2, factor: 0.5, yOffset: 150.0)
    }

    func setupPlayer() {
        // remove an existing player if were restarting/reentering
        if let existing = player {
            existing.removeFromParent()
        }
        childNode(withName: "player")?.removeFromParent()
        var imageName = "PlayerCity"
        switch AppState.shared.currentLevel {
            case .CITY: imageName = "RobotCity"
            case .DESERT: imageName = "RobotDesert"
            case .FOREST: imageName = "RobotForest"
            default : imageName = "RobotCity"
        }
        
        player = SKSpriteNode(imageNamed: imageName)
        player.name = "player"
        
        player.anchorPoint = CGPoint(x: 0.5, y: 0.0)
        
        let startY = 200 - (player.size.height / 2)
        player.position = CGPoint(x: 0, y: startY)
        
        let wheel = SKSpriteNode(imageNamed: "Wheel")
        wheel.name = "wheel"
        
        wheel.position = CGPoint(x: -14, y: 10)
        wheel.zPosition = -1
        
        let wheelScale = (player.size.height * 0.37) / wheel.size.height
        wheel.setScale(wheelScale)
        
        player.addChild(wheel)
        
        // Endless spin
        //let spin = SKAction.rotate(byAngle: -.pi * 2, duration: 4.0)
        //wheel.run(SKAction.repeatForever(spin))
        
        let hitboxSize = CGSize(width: player.size.width * 0.5, height: player.size.height * 1.0)
        
        let ellipsePath = CGPath(ellipseIn: CGRect(
            x: (-hitboxSize.width / 2) - 18,
            y: 0.0 - 3,
            width: hitboxSize.width,
            height: hitboxSize.height
        ), transform: nil)

        player.physicsBody = SKPhysicsBody(polygonFrom: ellipsePath)
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
        allTerrainNodes = []
        player?.removeFromParent()
        gameCamera?.removeFromParent()
        terrainNode?.removeFromParent()
        obstaclesNode?.removeFromParent()
        
        backgroundLayer1?.removeFromParent()
        backgroundLayer2?.removeFromParent()
        
        bgDecorationsNode?.removeFromParent()
        
        print("destructed everything")
    }

    // MARK: - Procedural Terrain
    
    let startX: CGFloat = 0
    let endX: CGFloat = 15000
    let leftFixedX: CGFloat = -2000
    let rightFixedX: CGFloat = 17000
    let topFixedY: CGFloat = 2000
    let bottomFixedY: CGFloat = -2000
    
    func generateTerrain() {
        setBackground()
        setupBackground()
        
        bgDecorationsNode = SKNode()
        bgDecorationsNode.zPosition = -5
        addChild(bgDecorationsNode)
        
        obstaclesNode = SKNode()
        addChild(obstaclesNode)
        
        obstaclesNode = SKNode()
        addChild(obstaclesNode)
        
        let totalWidth = rightFixedX - leftFixedX
        let fillRect = CGRect(x: leftFixedX, y: -100, width: totalWidth, height: 100)
        
        let valleyBackground = SKShapeNode(rect: fillRect)
        
        switch AppState.shared.currentLevel {
        case .DESERT:
            valleyBackground.fillColor = SKColor(named: "FloorDesert") ?? .white
        case .CITY:
            valleyBackground.fillColor = SKColor(named: "FloorCity") ?? .white
        case .FOREST:
            valleyBackground.fillColor = SKColor(named: "FloorForest") ?? .white
        default:
            valleyBackground.fillColor = SKColor(named: "TerrainLight") ?? .white
        }
        
        valleyBackground.strokeColor = .clear
        valleyBackground.zPosition = -8
        
        addChild(valleyBackground)
        let path = CGMutablePath()
        
        // go far below to make sure there is no gap
        path.move(to: CGPoint(x: leftFixedX, y: bottomFixedY))
        path.addLine(to: CGPoint(x: leftFixedX, y: topFixedY))
        path.addLine(to: CGPoint(x: startX-1000, y: topFixedY))
        path.addLine(to: CGPoint(x: startX-1000, y: 0))
        
        let totalSegments = Int((endX-startX))/500
        var isTerrainLow: [Bool] = Array(repeating: false, count: totalSegments)
        
        // caculate heights
        for i in 1..<isTerrainLow.count {
            if let rng = rng {
                // prevent the same object from spawning too many times ina row
                if i >= 2 && !isTerrainLow[i-1] && !isTerrainLow[i-2] {
                    isTerrainLow[i] = true
                } else {
                    isTerrainLow[i] = rng.nextInt(upperBound: 2) == 0
                }
            } else {
                isTerrainLow[i] = Bool.random()
            }
        }
        
        print(isTerrainLow)
        
        // path and obstacles
        for i in 0..<isTerrainLow.count {
            let chunkX = CGFloat(i * 500)
            let chunkY: CGFloat = isTerrainLow[i] ? -100 : 0
            
            // drawing cliff
            if i == 0 {
                if chunkY == 0 {
                    //terrain stays at the current level
                    path.addLine(to: CGPoint(x: chunkX + 100, y: chunkY))
                } else {
                    //terrain goes down
                    path.addLine(to: CGPoint(x: chunkX, y: 0))
                    path.addLine(to: CGPoint(x: chunkX, y: -100))
                    addTriangle(isGoingUp: false, leftX: chunkX)
                }
            } else {
                let prevY: CGFloat = isTerrainLow[i-1] ? -100 : 0
                if chunkY == prevY {
                    //terrain stays at the current level
                    path.addLine(to: CGPoint(x: chunkX + 100, y: chunkY))
                } else {
                    if chunkY == 0 {
                        //terrain goes up
                        path.addLine(to: CGPoint(x: chunkX, y: prevY))
                        path.addLine(to: CGPoint(x: chunkX + 100, y: -100))
                        addTriangle(isGoingUp: true, leftX: chunkX)
                    } else {
                        //terrain goes down
                        path.addLine(to: CGPoint(x: chunkX, y: prevY))
                        path.addLine(to: CGPoint(x: chunkX, y: -100))
                        addTriangle(isGoingUp: false, leftX: chunkX)
                    }
                    
                }
            }
            path.addLine(to: CGPoint(x: chunkX + 100, y: chunkY))
            
            // adding the real hitbox slope and the fake texture
            func addTriangle(isGoingUp: Bool, leftX: CGFloat) {
                allSlopeStarts.append((x: leftX, up: isGoingUp))
                
                let path = CGMutablePath()
                path.move(to: CGPoint(x: leftX, y: isGoingUp ? -100 : 0))
                path.addLine(to: CGPoint(x: leftX + 100, y: isGoingUp ? 0 : -100))
                path.addLine(to: CGPoint(x: isGoingUp ? leftX + 100 : leftX, y: -100))
                path.closeSubpath()
                
                let triangle = SKShapeNode(path: path)
                triangle.fillColor = .clear
                triangle.strokeColor = .clear
                
                triangle.physicsBody = SKPhysicsBody(edgeLoopFrom: path)
                triangle.physicsBody?.isDynamic = false
                triangle.physicsBody?.friction = 0.5
                triangle.physicsBody?.categoryBitMask = PhysicsCategory.terrain
                
                allTerrainNodes.append(triangle)
                
                let isCity = AppState.shared.currentLevel == .CITY
                var imageName = ""

                if isGoingUp {
                    imageName = isCity ? "SlopeStairsUp" : "SlopeUp"
                } else {
                    imageName = isCity ? "SlopeStairsDown" : "SlopeDown"
                }

                let slope = SKSpriteNode(imageNamed: imageName)
                slope.size = CGSize(width: 100, height: 100)

                slope.position = CGPoint(x: leftX + 50, y: -50)

                allTerrainNodes.append(slope)
            }
            
            let flatStart: CGFloat = 130
            let flatRange: Int = 340
            
            // attempt to spawn the obstacle
            if i > 1, let rng = rng, rng.nextInt(upperBound: 3) < 2 {
                let randomOffset = CGFloat(rng.nextInt(upperBound: flatRange))
                let spawnX = chunkX + flatStart + randomOffset
                
                spawnRandomObstacle(at: spawnX, groundY: chunkY)
            }
            
            // attempt to spawn deco 2 times
            for _ in 0..<2 {
                // 80% chance
                if (rng?.nextInt(upperBound: 5) ?? Int.random(in: 0...4)) < 4 {
                    
                    let randomDecoOffset = CGFloat(rng?.nextInt(upperBound: flatRange) ?? Int.random(in: 0..<flatRange))
                    let decoX = chunkX + flatStart + randomDecoOffset
                    
                    spawnDecoration(at: decoX, groundY: chunkY)
                }
            }
        }
        
        
        // close path
        path.addLine(to: CGPoint(x: endX+1000, y: isTerrainLow.last ?? false ? -100 : 0))
        path.addLine(to: CGPoint(x: endX+1000, y: topFixedY))
        path.addLine(to: CGPoint(x: rightFixedX, y: topFixedY))
        path.addLine(to: CGPoint(x: rightFixedX, y: bottomFixedY))
        path.closeSubpath()
        
        let tileTexture = SKTexture(imageNamed: "BG2")

        terrainNode = SKShapeNode(path: path)
        terrainNode.fillTexture = tileTexture
        terrainNode.fillColor = .white
        terrainNode.strokeColor = .clear
        
        let tileSizeInPoints = tileTexture.size()
        let tilesAcross  = Float(terrainNode.frame.size.width  / tileSizeInPoints.width)
        let tilesDown    = Float(terrainNode.frame.size.height / tileSizeInPoints.height)
        let uniformX = SKUniform(name: "u_tilesX", float: tilesAcross)
        let uniformY = SKUniform(name: "u_tilesY", float: tilesDown)

        let tileShader =
        """
        void main() {
            vec2 tiles = vec2(u_tilesX, u_tilesY);
            vec2 uv = v_tex_coord * tiles;
            vec2 tileUV = fract(uv);
            gl_FragColor = texture2D(u_texture, tileUV);
        }
        """
        
        let shader = SKShader(
            source: tileShader,
            uniforms: [uniformX, uniformY]
        )

        terrainNode.fillShader = shader
        
        terrainNode.physicsBody = SKPhysicsBody(edgeLoopFrom: path)
        terrainNode.physicsBody?.isDynamic = false
        terrainNode.physicsBody?.friction = 0.5
        terrainNode.physicsBody?.categoryBitMask = PhysicsCategory.terrain
        
        for node in allTerrainNodes {
            terrainNode?.addChild(node)
        }
        
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
        var assetPrefix = "City"
        switch AppState.shared.currentLevel {
        case .DESERT:
            assetPrefix = "Beach"
        case .FOREST:
            assetPrefix = "Forest"
        default:
            assetPrefix = "City"
        }
        
        // Randomly choose type
        // 0 = Small1, 1 = Small2, 2 = Large, 3 = Item (Bolt)
        let choice = rng?.nextInt(upperBound: 4) ?? Int.random(in: 0...3)
        
        // --- ITEM SPAWN ---
        if choice == 3 {
            let container = SKNode()
            let size = CGSize(width: 94, height: 103)
            
            // Bolt
            let boltSprite = AppState.shared.currentLevel == .DESERT ? SKSpriteNode(imageNamed: "DesertBolt") : AppState.shared.currentLevel == .CITY ? SKSpriteNode(imageNamed: "CityBolt") : SKSpriteNode(imageNamed: "ForestBolt")
            boltSprite.name = "bolt\(generatedItemsCount)"
            boltSprite.size = CGSize(width: size.width * 0.7, height: size.height * 0.7)
            boltSprite.zPosition = 2
            
            generatedItemsCount += 1
            
            // Animation
            let moveUp = SKAction.moveBy(x: 0, y: 10, duration: 1.0)
            let moveDown = moveUp.reversed()
            let sequence = SKAction.sequence([moveUp, moveDown])
            let repeatForever = SKAction.repeatForever(sequence)

            sequence.timingMode = .easeInEaseOut
            boltSprite.run(repeatForever)
            
            container.addChild(boltSprite)
            
            // Item Plate
            let plateSprite = SKSpriteNode(imageNamed: "ItemPlate")
            plateSprite.name = "plate"
            plateSprite.size = CGSize(width: size.width * 0.7, height: size.height * 0.7)
            plateSprite.zPosition = 3
            container.addChild(plateSprite)
            
            // Position and Physics
            container.position = CGPoint(x: x, y: groundY + size.height * 0.7 / 2)
            
            container.physicsBody = SKPhysicsBody(rectangleOf: size)
            container.physicsBody?.isDynamic = false
            container.physicsBody?.categoryBitMask = PhysicsCategory.item
            container.physicsBody?.collisionBitMask = PhysicsCategory.none
            container.physicsBody?.contactTestBitMask = PhysicsCategory.player
            
            obstaclesNode.addChild(container)
            
            return
        }

        // --- OBSTACLE SPAWN ---
        var suffix = ""
        var isLarge = false
        
        switch choice {
        case 0:
            suffix = "ObstacleSmall1"
            isLarge = false
        case 1:
            suffix = "ObstacleSmall2"
            isLarge = false
        default:
            suffix = "ObstacleLarge"
            isLarge = true
        }
        
        //rng for cactus
        // Determine if it's a cactus ONLY for desert
        let canBeCactus = AppState.shared.currentLevel == .DESERT
        let isCactus = canBeCactus && ((rng?.nextInt(upperBound: 11) ?? 0) == 0)

        if isCactus {
            suffix = "" // We won't use the suffix
            isLarge = false
        }

        let obstacle: SKSpriteNode
        if isCactus {
            obstacle = SKSpriteNode(imageNamed: "Cactus")
        } else {
            obstacle = SKSpriteNode(imageNamed: "\(assetPrefix)\(suffix)")
        }
        
        // Apply Scaling
        let targetHeight: CGFloat = isLarge ? 110.0 : 90.0
        
        if let texture = obstacle.texture {
            let aspectRatio = texture.size().width / texture.size().height
            obstacle.size = CGSize(width: targetHeight * aspectRatio, height: targetHeight)
        } else {
            // Fallback
            obstacle.size = CGSize(width: targetHeight, height: targetHeight)
            obstacle.color = .red
        }
        
        // Position
        obstacle.position = CGPoint(x: x, y: groundY + obstacle.size.height / 2)
        
        // Physics
        if isCactus {
            let hitboxSize = CGSize(width: obstacle.size.width * 0.5, height: obstacle.size.height * 1.0)
            obstacle.physicsBody = SKPhysicsBody(
                rectangleOf: hitboxSize,
                center: CGPoint(x: 0, y: 0)
            )
        } else if isLarge == false {
            let hitboxSize = CGSize(width: obstacle.size.width * 0.8, height: obstacle.size.height * 1.0)
            obstacle.physicsBody = SKPhysicsBody(
                rectangleOf: hitboxSize,
                center: CGPoint(x: 0, y: 0)
            )
        } else if AppState.shared.currentLevel == .CITY && suffix == "ObstacleLarge" {
            let hitboxSize = CGSize(width: obstacle.size.width * 0.9, height: obstacle.size.height * 0.7)
            obstacle.physicsBody = SKPhysicsBody(
                rectangleOf: hitboxSize,
                center: CGPoint(x: 0, y: -hitboxSize.height * 0.7 / 2)
            )
        } else if AppState.shared.currentLevel == .DESERT && suffix == "ObstacleLarge" {
            let hitboxSize = CGSize(width: obstacle.size.width * 1.0, height: obstacle.size.height * 0.7)
            obstacle.physicsBody = SKPhysicsBody(
                rectangleOf: hitboxSize,
                center: CGPoint(x: 0, y: -hitboxSize.height * 0.7 / 2)
            )
        } else if AppState.shared.currentLevel == .FOREST && suffix == "ObstacleLarge" {
            let hitboxSize = CGSize(width: obstacle.size.width * 0.95, height: obstacle.size.height * 1.0)
            obstacle.physicsBody = SKPhysicsBody(
                rectangleOf: hitboxSize,
                center: CGPoint(x: 0, y: 0)
            )
        } else {
            obstacle.physicsBody = SKPhysicsBody(rectangleOf: obstacle.size)
        }
        
        obstacle.physicsBody?.isDynamic = false
        obstacle.physicsBody?.friction = 0.5
        obstacle.physicsBody?.categoryBitMask = PhysicsCategory.terrain
        
        // Add to Container
        obstaclesNode.addChild(obstacle)
    }
    
    func spawnDecoration(at x: CGFloat, groundY: CGFloat) {
        // get asset
        var assetPrefix = "City"
        switch AppState.shared.currentLevel {
        case .DESERT: assetPrefix = "Beach"
        case .FOREST: assetPrefix = "Forest"
        default: assetPrefix = "City"
        }

        // foreground
        if let rng = rng, rng.nextInt(upperBound: 3) == 0 {
            let fgNode = SKSpriteNode(imageNamed: "\(assetPrefix)ObjectFG")
            
            //scaling
            let targetH: CGFloat = 250.0
            if let tex = fgNode.texture {
                let ratio = tex.size().width / tex.size().height
                fgNode.size = CGSize(width: targetH * ratio, height: targetH)
            }
            
            fgNode.position = CGPoint(x: x, y: groundY + fgNode.size.height / 2)
            fgNode.zPosition = -1
            
            let hitboxSize = CGSize(width: fgNode.size.width * 0.3, height: fgNode.size.height * 0.85)
            
            fgNode.physicsBody = SKPhysicsBody(
                rectangleOf: hitboxSize,
                center: CGPoint(x: 0, y: -hitboxSize.height * 0.7 / 2)
            )
            fgNode.physicsBody?.isDynamic = false
            fgNode.physicsBody?.friction = 0.5
            fgNode.physicsBody?.categoryBitMask = PhysicsCategory.terrain
            
            obstaclesNode.addChild(fgNode)
        }
        
        // background
        if let rng = rng, rng.nextInt(upperBound: 2) == 0 {
            //rng for bush
            let isBush = rng.nextInt(upperBound: 2) == 0
            
            let bgNode = (AppState.shared.currentLevel == .DESERT || AppState.shared.currentLevel == .FOREST) && isBush ? SKSpriteNode(imageNamed: AppState.shared.currentLevel == .DESERT ? "DryBush" : "Bush") : SKSpriteNode(imageNamed: "\(assetPrefix)ObjectBG")
            
            if isBush {
                bgNode.alpha = 0.7
            }
            
            // scale
            let targetH: CGFloat = isBush ? 40.0 : 200.0
            if let tex = bgNode.texture {
                let ratio = tex.size().width / tex.size().height
                bgNode.size = CGSize(width: targetH * ratio, height: targetH)
            }
            
            bgNode.position = CGPoint(x: x, y: groundY + bgNode.size.height / 2)
            bgNode.zPosition = -2
            
            bgDecorationsNode.addChild(bgNode)
        }
    }
    
    func removeItem(id: Int) {
        let targetName = "bolt\(id)"
        
        if let boltNode = self.childNode(withName: "//\(targetName)") {
            boltNode.parent?.physicsBody?.categoryBitMask = PhysicsCategory.none
            boltNode.removeFromParent()
            
            HapticManager.collect()
            print("Successfully removed \(targetName)")
        } else {
            print("Bolt with ID \(id) not found in scene.")
        }
    }
    
    func collectItem() {
        guard let physicsBody = player.physicsBody else { return }
        
        // Get all bodies currently touching the player
        let contactedBodies = physicsBody.allContactedBodies()
        print(contactedBodies)
            
        for body in contactedBodies {
            // Compare the other body's category to your specific item category
            if body.categoryBitMask == PhysicsCategory.item {
                print("Player is touching an item!")
                if let container = body.node {
                    for child in container.children {
                        if let name = child.name, name.hasPrefix("bolt") {
                            
                            // Extract the id
                            let idString = name.replacingOccurrences(of: "bolt", with: "")
                            if let boltID = Int(idString) {
                                print("Collected bolt with ID: \(boltID)")
                                
                                mp?.send(MPMessage(type: .removeItem, a: Double(boltID)))
                            }
                            
                            // Remove bolt
                            child.removeFromParent()
                            applySpeedBoost()
                            SoundManager.shared.playSFX("01_bleep.wav", volume: 0.7)
                            HapticManager.collect()
                            
                            // Disable the item
                            container.physicsBody?.categoryBitMask = PhysicsCategory.none
                            
                            break
                        }
                    }
                    if let bolt = container.childNode(withName: "bolt") {
                        bolt.removeFromParent()
                        container.physicsBody?.categoryBitMask = PhysicsCategory.none
                    }
                }
            }
        }
    }
    
    func applySpeedBoost() {
        isSpeedBoostActive = true
        moveSpeed = baseMoveSpeed * boostMultiplier
        
        // Wait 5 seconds, then return to normal
        let wait = SKAction.wait(forDuration: 5.0)
        let reset = SKAction.run { [weak self] in
            self?.moveSpeed = self?.baseMoveSpeed ?? 300.0
            self?.isSpeedBoostActive = false
        }
        self.run(SKAction.sequence([wait, reset]), withKey: "speedBoostTimer")
    }
    
    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard player != nil else { return }

        // Host simulates movement
        if !isRemoteViewOnly {
            var xInput = tiltX
            if abs(xInput) < tiltDeadzone { xInput = 0 }
            player.physicsBody?.velocity.dx = xInput * moveSpeed
            
            let targetRotation = -CGFloat(xInput) * maxTilt
            player.zRotation = player.zRotation + (targetRotation - player.zRotation) * leanSpeed
            
            if let wheel = player.childNode(withName: "wheel") {
                let velocityX = player.physicsBody?.velocity.dx ?? 0.0
                
                if abs(velocityX) > 0.5 {
                    let rotationAmount = (velocityX / moveSpeed) * 0.15
                    wheel.zRotation -= rotationAmount
                }
            }
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
            backgroundLayer1.position.x = cam.position.x * 0.2
            backgroundLayer2.position.x = cam.position.x * 0.5
            
            backgroundLayer1.position.y = cam.position.y * 0.05
            backgroundLayer2.position.y = cam.position.y * 0.1
            
            bgDecorationsNode.position.x = cam.position.x * 0.1
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
                d: Double(body.velocity.dy),
                e: Double(player.zRotation),
                f: Double(player.childNode(withName: "wheel")?.zRotation ?? 0.0)
            ))
        }
        
        // Host broadcasts timer state at 5 Hz
        if !isRemoteViewOnly, currentTime - lastTimerSendTime >= timerSendInterval {
            lastTimerSendTime = currentTime
            
            mp?.send(MPMessage(type: .time, a: AppState.shared.elapsedTime))
        }
    }
    
    //MARK: - Level Music
    private func startLevelMusic() {
        SoundManager.shared.stopMusic()
        
        switch AppState.shared.currentLevel {
        case .CITY:
            SoundManager.shared.playMusic("city-loop.mp3", volume: 0.45)
        case .FOREST:
            SoundManager.shared.playMusic("forest.mp3", volume: 0.45)
        case .DESERT:
            SoundManager.shared.playMusic("Cavernous_Desert02.mp3", volume: 0.45)
        default:
            break
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
        SoundManager.shared.playSFX("jump_08.wav", volume: 0.9)
        player.physicsBody?.velocity.dy = 0
        player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: smallJumpForce))
    }

    // return if jump was successfull
    func jump() -> Bool {
        guard !isRemoteViewOnly else { return false }
        if isGrounded() {
            SoundManager.shared.playSFX("jump_08.wav", volume: 0.9)
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
