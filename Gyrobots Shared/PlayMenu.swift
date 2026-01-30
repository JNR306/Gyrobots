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

    var body: some View {
        HStack(spacing: 10) {
            Spacer()
            Button {
                withAnimation {
                    appState.createRoom()
                }
            } label: {
                Image(.newGameButton)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
            }
            Button {
                withAnimation {
                    appState.browseRooms()
                }
            } label: {
                Image(.joinGameButton)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 200)
            }
            Spacer()
        }
    }
}
