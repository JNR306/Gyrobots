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
            SpriteView(scene: appState.gameScene)
                //.border(.yellow, width: 3)
                .ignoresSafeArea()
        }
        .onAppear {
            appState.startSensors()
        }
        .onDisappear {
            appState.stopSensors()
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
            if appState.role == .jump {
                HStack {
                    Spacer()
                    Button {
                        appState.handleJumpAction()
                    } label: {
                        Text("JUMP")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 100, height: 100)
                    .border(.red, width: 10)
                }
            }
        }
        .border(.yellow, width: 10)
    }
}

#Preview {
    ZStack {
        GameView()
        GameOverlay()
    }
}
