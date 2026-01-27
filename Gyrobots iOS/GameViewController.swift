import UIKit
import SpriteKit
import GameplayKit
import CoreMotion
import MultipeerConnectivity

class GameViewController: UIViewController {

    // MARK: - Properties
    private let motionManager = CMMotionManager()
    private weak var gameScene: GameScene?
    
    private let mp = MultipeerManager()
    
    enum Role { case gyro, jump }
    var role: Role = .jump   // DEBUG: switch per device

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let scene = GameScene.newGameScene()
        self.gameScene = scene
        
        scene.mp = mp
        scene.roleIsJumpSender = (role == .jump)
        
        if role == .jump {
            scene.tiltX = 0
        }
        
        mp.onReceivedMessage = { [weak self] msg in
            guard let self, let scene = self.gameScene else { return }
            switch msg.type {
            case .tilt:
                let x = CGFloat(msg.value ?? 0)
                scene.applyRemoteTilt(x)
            case .jump:
                scene.applyRemoteJump(force: msg.value.map { CGFloat($0) })
            }
        }

        // For testing: one device hosts, one joins.
        // Pick ONE of these per device:
        //mp.startHosting()
         mp.startJoining()


        let skView = self.view as! SKView
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true

        startGyro()
        if role == .jump {
            setupJumpButton()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Gyroscope
    private func startGyro() {
        guard motionManager.isDeviceMotionAvailable else {
            print("DeviceMotion not available")
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0

        // Use main queue so updates safely touch SpriteKit state
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self, let motion else { return }

            // Portrait mode: roll = left/right tilt
            let roll = motion.attitude.roll

            // Normalize to [-1, 1]
            let normalized = max(-1.0, min(1.0, roll / 0.6))
            
            if self.role == .gyro {
                self.gameScene?.tiltX = CGFloat(normalized)
                self.mp.send(MPMessage(type: .tilt, value: normalized))
            }
        }
    }
    
    // MARK: - Jump Button for jumper role
    private func setupJumpButton() {
        let button = UIButton(type: .system)
        button.setTitle("JUMP", for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 20)
        button.backgroundColor = UIColor(white: 1.0, alpha: 0.25)
        button.layer.cornerRadius = 18
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)

        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])

        // Trigger on press (feels responsive)
        button.addTarget(self, action: #selector(jumpButtonPressed), for: .touchDown)
    }

    @objc private func jumpButtonPressed() {
        // small jump locally
        gameScene?.smallJump()

        // and send to the other device (small jump force)
        mp.send(MPMessage(type: .jump, value: Double(gameScene?.smallJumpForce ?? 450.0)))
    }


    // MARK: - Orientation / Status Bar
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .landscapeRight
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }
}
