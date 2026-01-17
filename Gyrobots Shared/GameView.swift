//
//  ContentView.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 11.01.26.
//

import SwiftUI
import SpriteKit

struct GameView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ZStack {
            Group {
                if let gameScene = appState.gameScene {
                    SpriteView(scene: gameScene)
                        //.border(.yellow, width: 3)
                        .ignoresSafeArea()
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .foregroundStyle(.white)
                }
            }
        }
    }
}

struct GameOverlay: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack {
            Button {
                withAnimation {
                    appState.currentView = .MAIN_MENU
                }
            } label: {
                Text("EXIT")
            }
            Spacer()
        }
    }
}

#Preview {
    ZStack {
        GameView()
        GameOverlay()
    }
}
