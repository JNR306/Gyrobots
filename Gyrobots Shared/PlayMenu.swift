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
        VStack {
            Spacer()
            Text("Play")
                .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .padding()
            Spacer()
            HStack(spacing: 10) {
                Spacer()
                Button {
                    HapticManager.tap()
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
                    HapticManager.tap()
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
            Spacer()
            Button {
                HapticManager.tap()
                withAnimation {
                    appState.currentView = .MAIN_MENU
                }
            } label: {
                HStack {
                    Image(.backArrow)
                        .resizable()
                        .frame(width: 15, height: 15)
                    Text("Back")
                        .font(.custom("AvenirNext-Medium", size: 20, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            Spacer()
        }
    }
}
