//
//  RoomList.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//


import SwiftUI
import SpriteKit

struct RoomList: View {

    @Environment(AppState.self) private var appState
    @State private var scene = MenuScene()

    var body: some View {
        SpriteView(scene: scene)
            .ignoresSafeArea()
            .onAppear { rebuild() }
            .onChange(of: appState.availableRooms) { _, _ in
                rebuild()
            }
    }

    private func rebuild() {
        scene.removeAllChildren()

        let title = SKLabelNode(text: "JOIN ROOM")
        title.fontName = "AvenirNext-Bold"
        title.fontSize = 42
        title.fontColor = .white
        title.position = CGPoint(x: 0, y: 200)
        scene.addChild(title)

        if appState.availableRooms.isEmpty {
            let empty = SKLabelNode(text: "No rooms found nearby")
            empty.fontName = "AvenirNext-Regular"
            empty.fontSize = 20
            empty.fontColor = .white
            empty.position = CGPoint(x: 0, y: 80)
            scene.addChild(empty)
        } else {
            for (index, room) in appState.availableRooms.enumerated() {
                let y = 120 - CGFloat(index) * 44
                let label = makeTextButton(text: room.name, y: y)
                scene.addChild(label)

                let name = "room_\(index)"
                scene.registerTap(for: label, name: name) {
                    DispatchQueue.main.async {
                        withAnimation { appState.join(room: room) }
                    }
                }
            }
        }

        let back = makeTextButton(text: "Back", y: -200)
        scene.addChild(back)
        scene.registerTap(for: back, name: "back") {
            DispatchQueue.main.async {
                withAnimation { appState.currentView = .PLAY_MENU }
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
