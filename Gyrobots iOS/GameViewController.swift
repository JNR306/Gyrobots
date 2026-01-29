//
//  GameViewController.swift
//  Gyrobots iOS
//

import UIKit
import SpriteKit
import CoreMotion

final class GameViewController: UIViewController {

    // MARK: - Core
    private let mp = MultipeerManager()
    private let motionManager = CMMotionManager()
    private weak var gameScene: GameScene?

    // MARK: - Roles
    enum Role {
        case hostJump      // iPad
        case joinGyro      // iPhone
    }

    // 🔹 Automatic role selection
    private let role: Role = (UIDevice.current.userInterfaceIdiom == .pad)
        ? .hostJump
        : .joinGyro

    // MARK: - UI
    private let roleLabel = UILabel()
    private let peersLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // --- Scene ---
        let scene = GameScene.newGameScene()
        self.gameScene = scene
        scene.mp = mp
        scene.isRemoteViewOnly = (role == .joinGyro)

        let skView = view as! SKView
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        skView.showsFPS = true
        skView.showsNodeCount = true

        // --- UI ---
        setupStatusLabels()
        updatePeersLabel([])

        // --- Multipeer callbacks ---
        setupMultipeerCallbacks()

        // --- Start role behavior ---
        if role == .hostJump {
            mp.startHosting()
            setupJumpButton()
        } else {
            mp.startJoining()
            startGyro()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        motionManager.stopDeviceMotionUpdates()
        mp.stop()
    }

    // MARK: - Multipeer Setup

    private func setupMultipeerCallbacks() {

        // Receive messages
        mp.onReceivedMessage = { [weak self] msg in
            guard let self, let scene = self.gameScene else { return }

            switch msg.type {

            case .levelSeed:
                // Joiner starts level using host seed
                let seed = Int32(msg.a ?? 0)
                scene.startLevelAsJoiner(seed: seed)
                self.peersLabel.text = "Level synced ✅"

            case .tilt:
                // Host receives gyro input from joiner
                if self.role == .hostJump {
                    scene.applyRemoteTilt(CGFloat(msg.a ?? 0))
                }

            case .jump:
                // (Not used in this role split, but safe)
                if self.role == .hostJump {
                    scene.applyRemoteJump(force: CGFloat(msg.a ?? 0))
                }

            case .playerState:
                // Joiner mirrors authoritative host state
                if self.role == .joinGyro {
                    scene.applyRemotePlayerState(
                        x: CGFloat(msg.a ?? 0),
                        y: CGFloat(msg.b ?? 0),
                        vx: CGFloat(msg.c ?? 0),
                        vy: CGFloat(msg.d ?? 0)
                    )
                }
            }
        }

        // Peer connection changes
        mp.onConnectedPeersChanged = { [weak self] peers in
            guard let self, let scene = self.gameScene else { return }
            self.updatePeersLabel(peers)

            // Host decides seed once a peer connects
            if self.role == .hostJump, !peers.isEmpty {
                let seed = Int32.random(in: 1...Int32.max / 2)

                scene.startLevelAsHost(seed: seed)
                self.mp.send(MPMessage(type: .levelSeed, a: Double(seed)))

                self.peersLabel.text = "Host ready ✅"
            }
        }
    }

    // MARK: - Gyro (JOINER)

    private func startGyro() {
        guard motionManager.isDeviceMotionAvailable else {
            peersLabel.text = "Gyro unavailable ❌"
            return
        }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }

            // Stable landscape mapping using gravity
            let g = motion.gravity
            let raw = -g.y
            let normalized = max(-1.0, min(1.0, raw * 2.0))

            self.mp.send(MPMessage(type: .tilt, a: normalized))
        }
    }

    // MARK: - Jump Button (HOST)

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

        button.addTarget(self, action: #selector(jumpPressed), for: .touchDown)
    }

    @objc private func jumpPressed() {
        // Host jumps locally (authoritative)
        gameScene?.smallJump()
    }

    // MARK: - Status Labels

    private func setupStatusLabels() {
        roleLabel.translatesAutoresizingMaskIntoConstraints = false
        peersLabel.translatesAutoresizingMaskIntoConstraints = false

        roleLabel.textColor = .white
        peersLabel.textColor = .white

        roleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        peersLabel.font = .systemFont(ofSize: 12)

        roleLabel.text = (role == .hostJump)
            ? "Role: HOST (Jump)"
            : "Role: JOINER (Gyro)"

        view.addSubview(roleLabel)
        view.addSubview(peersLabel)

        NSLayoutConstraint.activate([
            roleLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
            roleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),

            peersLabel.leadingAnchor.constraint(equalTo: roleLabel.leadingAnchor),
            peersLabel.topAnchor.constraint(equalTo: roleLabel.bottomAnchor, constant: 6)
        ])
    }

    private func updatePeersLabel(_ peers: [Any]) {
        let count = peers.count
        peersLabel.text = (count == 0)
            ? "Peers: 0 (waiting…)"
            : "Peers: \(count) connected ✅"
    }

    // MARK: - Orientation

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .landscapeRight
    }

    override var prefersStatusBarHidden: Bool {
        true
    }
}
