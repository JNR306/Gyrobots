//
//  MenuScene.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//


import SpriteKit

final class MenuScene: SKScene {

    private var actionsByNodeName: [String: () -> Void] = [:]

    override func didMove(to view: SKView) {
        // Ensure sizing is correct even after rotations / SwiftUI layout changes
        size = view.bounds.size
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)

        backgroundColor = .black
        view.ignoresSiblingOrder = true
    }

    func registerTap(for node: SKNode, name: String, action: @escaping () -> Void) {
        node.name = name
        actionsByNodeName[name] = action
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)

        // Get topmost tapped node (including its parents)
        let tappedNodes = nodes(at: location)

        for node in tappedNodes {
            // Walk up parent chain until we find a named node we registered
            var current: SKNode? = node
            while let c = current {
                if let name = c.name, let action = actionsByNodeName[name] {
                    action()
                    return
                }
                current = c.parent
            }
        }
    }
}
