//
//  TapNode.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//


import SpriteKit

private final class TapNode: SKNode {
    let action: () -> Void
    init(action: @escaping () -> Void) {
        self.action = action
        super.init()
        isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        action()
    }
}

extension SKNode {
    func onTap(_ action: @escaping () -> Void) {
        let tapNode = TapNode(action: action)
        addChild(tapNode)
    }
}
