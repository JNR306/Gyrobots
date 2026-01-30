//
//  PlayMenu.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//

import SwiftUI
import SpriteKit

struct PlayMenu: View {

    @Environment(AppState.self) private var appState
    @State private var scene = MenuScene()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onAppear {
                buildIfNeeded()
            }
    }

    private func buildIfNeeded() {
        // Prevent rebuilding if SwiftUI calls onAppear again
        guard scene.children.isEmpty else { return }

        let title = SKLabelNode(text: "PLAY")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 48
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 160)
        scene.addChild(title)

        let create = makeButton(text: "CREATE ROOM", y: 40)
        scene.addChild(create)
        scene.registerTap(for: create, name: "create") {
            DispatchQueue.main.async {
                withAnimation { appState.createRoom() }
            }
        }

        let join = makeButton(text: "JOIN ROOM", y: -30)
        scene.addChild(join)
        scene.registerTap(for: join, name: "join") {
            DispatchQueue.main.async {
                withAnimation { appState.browseRooms() }
            }
        }

        let back = makeTextButton(text: "Back", y: -160)
        scene.addChild(back)
        scene.registerTap(for: back, name: "back") {
            DispatchQueue.main.async {
                withAnimation { appState.currentView = .MAIN_MENU }
            }
        }
    }
}

private func makeButton(text: String, y: CGFloat) -> SKShapeNode {
    let button = SKShapeNode(rectOf: CGSize(width: 280, height: 56), cornerRadius: 12)
    button.fillColor = .darkGray
    button.strokeColor = .white
    button.lineWidth = 2
    button.position = CGPoint(x: 0, y: y)

    let label = SKLabelNode(text: text)
    label.fontName = "AvenirNext-DemiBold"
    label.fontSize = 22
    label.fontColor = .white
    label.verticalAlignmentMode = .center
    label.horizontalAlignmentMode = .center
    label.position = .zero
    button.addChild(label)

    return button
}

private func makeTextButton(text: String, y: CGFloat) -> SKLabelNode {
    let label = SKLabelNode(text: text)
    label.fontName = "AvenirNext-DemiBold"
    label.fontSize = 22
    label.fontColor = .white
    label.position = CGPoint(x: 0, y: y)
    return label
}
