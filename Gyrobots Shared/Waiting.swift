//
//  Waiting.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//


import SwiftUI
import SpriteKit

struct Waiting: View {

    @Environment(AppState.self) private var appState
    @State private var scene = MenuScene()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onAppear { buildIfNeeded() }
    }

    private func buildIfNeeded() {
        guard scene.children.isEmpty else { return }

        let label = SKLabelNode(text: "Waiting for other player…")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 28
        label.fontColor = .white
        label.numberOfLines = 2
        label.preferredMaxLayoutWidth = 320
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 0, y: 60)
        scene.addChild(label)

        let cancel = makeTextButton(text: "Cancel", y: -160)
        scene.addChild(cancel)
        scene.registerTap(for: cancel, name: "cancel") {
            DispatchQueue.main.async {
                withAnimation { appState.cancelMultipeerAndReturnToMenu() }
            }
        }
    }
}

private func makeTextButton(text: String, y: CGFloat) -> SKLabelNode {
    let label = SKLabelNode(text: text)
    label.fontName = "AvenirNext-DemiBold"
    label.fontSize = 22
    label.fontColor = .white
    label.position = CGPoint(x: 0, y: y)
    return label
}
