//
//  GameScene.swift
//  Gyrobots Shared
//
//  Created by Jan-Niklas Röhlig on 18.12.25.
//

import SpriteKit
import GameplayKit

final class GameScene: SKScene {

    // MARK: - Nodes
    var player: SKShapeNode!
    var gameCamera: SKCameraNode!
    var terrainNode: SKShapeNode!

    // MARK: - Settings
    let moveSpeed: CGFloat = 300.0
    let jumpForce: CGFloat = 800.0
    let smallJumpForce: CGFloat = 450.0
    let playerSize = CGSize(width: 50, height: 100)

    // Terrain
    let chunkWidth: CGFloat = 30000

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
        backgroundColor = .darkGray
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
        generateTerrainAndObstacles()
        setupPlayer()
    }

    /// Joiner calls this after receiving the host’s seed.
    func startLevelAsJoiner(seed: Int32) {
        isRemoteViewOnly = true
        configureLevel(seed: seed)
        generateTerrainAndObstacles()
        setupPlayer()

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
        player.fillColor = .red
        player.strokeColor = .white

        let startY = getNoiseHeight(at: 0) + 100
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

        addChild(player)
    }

    // MARK: - Procedural Terrain (Perlin Noise)

    func getNoiseHeight(at x: CGFloat) -> CGFloat {
        guard let noise else { return 0 } // safety until configured
        let position = vector_float2(Float(x), 0)
        let noiseValue = noise.value(atPosition: position)
        return CGFloat(noiseValue) * 150.0
    }

    func generateTerrainAndObstacles() {
        guard noise != nil, rng != nil else { return } // must be configured with seed first

        let path = CGMutablePath()
        let startX: CGFloat = -1000
        let endX: CGFloat = chunkWidth
        let bottomFixedY: CGFloat = -2000

        path.move(to: CGPoint(x: startX, y: bottomFixedY))
        path.addLine(to: CGPoint(x: startX, y: getNoiseHeight(at: startX)))

        for x in stride(from: startX, to: endX, by: 40) {
            let y = getNoiseHeight(at: CGFloat(x))
            path.addLine(to: CGPoint(x: CGFloat(x), y: y))

            // Deterministic obstacle placement choice
            if x > 500 && Int(x) % 1000 == 0 {
                spawnRandomObstacle(at: CGFloat(x), groundY: y)
            }
        }

        path.addLine(to: CGPoint(x: endX, y: bottomFixedY))
        path.closeSubpath()

        terrainNode = SKShapeNode(path: path)
        terrainNode.strokeColor = .lightGray
        terrainNode.lineWidth = 2
        terrainNode.fillColor = .black

        terrainNode.physicsBody = SKPhysicsBody(edgeLoopFrom: path)
        terrainNode.physicsBody?.isDynamic = false
        terrainNode.physicsBody?.friction = 0.5

        addChild(terrainNode)
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
