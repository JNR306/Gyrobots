//
//  GameScene.swift
//  Gyrobots Shared
//
//  Created by Jan-Niklas Röhlig on 18.12.25.
//

import UIKit
import SpriteKit
import GameplayKit
import CoreMotion

class GameScene: SKScene {
    
    // MARK: - Nodes
    var player: SKShapeNode!
    var gameCamera: SKCameraNode!
    var terrainNode: SKShapeNode!
    
    // MARK: - Settings
    let moveSpeed: CGFloat = 300.0
    let jumpForce: CGFloat = 800.0
    let playerSize = CGSize(width: 50, height: 100)
    let smallJumpForce: CGFloat = 450.0
    
    // terrain
    let chunkWidth: CGFloat = 30000
    
    // MARK: - Noise Generator
    let noise: GKNoise = {
        let source = GKPerlinNoiseSource(frequency: 0.002, octaveCount: 3, persistence: 0.5, lacunarity: 2.0, seed: Int32(Int.random(in: 0...123123)))
        return GKNoise(source)
    }()
    
    // MARK: - State Flags
    var isMovingLeft = false
    var isMovingRight = false
    var isCrouching = false
    
    class func newGameScene() -> GameScene {
        guard let scene = SKScene(fileNamed: "GameScene") as? GameScene else { abort() }
        scene.scaleMode = .resizeFill
        return scene
    }
    
    override func didMove(to view: SKView) {
        self.backgroundColor = SKColor.darkGray
        
        self.physicsWorld.gravity = CGVector(dx: 0, dy: -12.0)
        
        setupCamera()
        generateTerrainAndObstacles()
        setupPlayer()
    }
    
    // MARK: - Multiplayer
    weak var mp: MultipeerManager?
    var roleIsJumpSender = false
    
    // MARK: - Gyro Input
    /// Horizontal input from tilt in range [-1, 1]
    var tiltX: CGFloat = 0

    /// Deadzone to prevent drift when device is almost flat
    let tiltDeadzone: CGFloat = 0.08

    // MARK: - Multipeer Stuff
    func applyRemoteTilt(_ x: CGFloat) {
        tiltX = x
    }

    func applyRemoteJump(force: CGFloat?) {
        if let f = force {
            jump(with: f)
        } else {
            jump()
        }
    }

    
    // MARK: - Setup
    
    func setupCamera() {
        gameCamera = SKCameraNode()
        addChild(gameCamera)
        camera = gameCamera
    }
    
    func setupPlayer() {
        let rect = CGRect(x: -playerSize.width/2, y: 0, width: playerSize.width, height: playerSize.height)
        player = SKShapeNode(rect: rect)
        player.fillColor = SKColor.red
        player.strokeColor = SKColor.white
        
        let startY = getNoiseHeight(at: 0) + 100 // to have player not intersect terrain
        player.position = CGPoint(x: 0, y: startY)
        
        // Physics
        player.physicsBody = SKPhysicsBody(rectangleOf: playerSize, center: CGPoint(x: 0, y: playerSize.height/2))
        player.physicsBody?.isDynamic = true
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.friction = 0.2
        player.physicsBody?.restitution = 0.0
        player.physicsBody?.mass = 1.0
        
        addChild(player)
    }
    
    // MARK: - Procedural Terrain (Perlin Noise)
    
    func getNoiseHeight(at x: CGFloat) -> CGFloat {
        let position = vector_float2(Float(x), 0)
        let noiseValue = noise.value(atPosition: position)
        
        return CGFloat(noiseValue) * 150.0 // scale of the terrain
    }
    
    func generateTerrainAndObstacles() {
        let path = CGMutablePath()
        let startX: CGFloat = -1000
        let endX: CGFloat = chunkWidth
        let bottomFixedY: CGFloat = -2000 //close shape under bottom edge of screen
        
        path.move(to: CGPoint(x: startX, y: bottomFixedY))
        path.addLine(to: CGPoint(x: startX, y: getNoiseHeight(at: startX)))
        
        for x in stride(from: startX, to: endX, by: 40) {
            let y = getNoiseHeight(at: CGFloat(x))
            path.addLine(to: CGPoint(x: CGFloat(x), y: y))
            
            if x > 500 && Int(x) % 1000 == 0 { //do random obtsacle every around 1000 pixels
                spawnRandomObstacle(at: CGFloat(x), groundY: y)
            }
        }
        //close shape
        path.addLine(to: CGPoint(x: endX, y: bottomFixedY))
        path.closeSubpath()
        
        //terrain node
        terrainNode = SKShapeNode(path: path)
        terrainNode.strokeColor = SKColor.lightGray
        terrainNode.lineWidth = 2
        terrainNode.fillColor = SKColor.black
        
        terrainNode.physicsBody = SKPhysicsBody(edgeLoopFrom: path) //hitbox is of course same path
        terrainNode.physicsBody?.isDynamic = false
        terrainNode.physicsBody?.friction = 0.5 //interacts with player friciton
        addChild(terrainNode)
    }
    
    func spawnRandomObstacle(at x: CGFloat, groundY: CGFloat) {
        let isHigh = Bool.random()
        let size = CGSize(width: 60, height: 60)
        
        let obstacle = SKShapeNode(rectOf: size)
        obstacle.fillColor = SKColor.orange
        obstacle.lineWidth = 0
        
        let yOffset = isHigh ? 130.0 : 30.0 //have high for crouching under and low for jumping over
        obstacle.position = CGPoint(x: x, y: groundY + yOffset)
        
        obstacle.physicsBody = SKPhysicsBody(rectangleOf: size)
        obstacle.physicsBody?.isDynamic = false
        
        addChild(obstacle)
    }
    
    // MARK: - Game Loop
    
    override func update(_ currentTime: TimeInterval) {
        // --- horizontal movement (gyro first, touches as fallback) ---
        var xInput = tiltX

        // apply deadzone
        if abs(xInput) < tiltDeadzone { xInput = 0 }

        if xInput != 0 {
            player.physicsBody?.velocity.dx = xInput * moveSpeed
        } else {
            // fallback to existing touch controls (optional)
            if isMovingLeft {
                player.physicsBody?.velocity.dx = -moveSpeed
            } else if isMovingRight {
                player.physicsBody?.velocity.dx = moveSpeed
            } else {
                // optional: stop sliding forever when no input
                player.physicsBody?.velocity.dx = 0
            }
        }

        // cam
        if let cam = gameCamera, let p = player {
            let targetX = p.position.x
            let targetY = p.position.y + 100
            let currentY = cam.position.y
            let newY = currentY + (targetY - currentY) * 0.1
            cam.position = CGPoint(x: targetX, y: newY)
        }
    }

    
    // MARK: - Actions
    
    func isGrounded() -> Bool {
        guard player.physicsBody != nil else { return false }
        
        let start = player.position
        let end = CGPoint(x: start.x, y: start.y - 55) //as player is 50 tall
        
        var hitGround = false
        
        self.physicsWorld.enumerateBodies(alongRayStart: start, end: end) { (body, point, normal, stop) in
            if body != self.player.physicsBody {
                hitGround = true
                stop.pointee = true
            }
        }
        
        return hitGround
    }
    
    func jump(with force: CGFloat) {
        if isGrounded() {
            player.physicsBody?.velocity.dy = 0
            player.physicsBody?.applyImpulse(CGVector(dx: 0, dy: force))
        }
    }

    func jump() {
        jump(with: jumpForce)
    }

    func smallJump() {
        jump(with: smallJumpForce)
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

// MARK: - Input Handling (iOS/tvOS)
#if os(iOS) || os(tvOS)
import UIKit
extension GameScene {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self.camera!)
        if roleIsJumpSender { return }
        if loc.y > 50 {
            jump()
            if roleIsJumpSender {
                mp?.send(MPMessage(type: .jump, value: nil))
            }
        }
        else if loc.x < -80 { isMovingLeft = true }
        else if loc.x > 80 { isMovingRight = true }
        else { startCrouch() }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isMovingLeft = false; isMovingRight = false; stopCrouch()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) { touchesEnded(touches, with: event) }
}
#endif

// MARK: - Input Handling (macOS)
#if os(macOS)
import Cocoa
extension GameScene {
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 49: jump()
        case 123: isMovingLeft = true
        case 124: isMovingRight = true
        case 125: startCrouch()
        default: break
        }
    }
    override func keyUp(with event: NSEvent) {
        switch event.keyCode {
        case 123: isMovingLeft = false
        case 124: isMovingRight = false
        case 125: stopCrouch()
        default: break
        }
    }
}
#endif

