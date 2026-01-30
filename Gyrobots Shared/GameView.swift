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
            appState.startGameIfNeeded()
            appState.startSensors()
            appState.startGameIfNeeded()
        }
        .onDisappear {
            appState.stopSensors()
        }
        .overlay(alignment: .topLeading) { //TEMPORARY - ONLY FOR DEVELOPMENT
            Text("isHost: \(appState.isHost ? "YES" : "NO")  role: \(appState.role == .gyro ? "GYRO" : "JUMP")")
                .padding(8)
                .background(.black.opacity(0.6))
                .foregroundStyle(.white)
        }
    }
}

struct GameOverlay: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    appState.cancelMultipeerAndReturnToMenu()
                } label: {
                    Text("EXIT")
                        .frame(width: 100, height: 100)
                }
                Spacer()
                Text("\(appState.formattedTime)")
                    .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(.terrain)
                    .contentTransition(.numericText(countsDown: false))
                Image(.clock)
                    .resizable()
                    .frame(width: 40, height: 40)
            }
            .padding()
            Spacer()
            if appState.role == .jump {
                HStack {
                    Spacer()
                    Button {
                        appState.handleJumpAction()
                    } label: {
                        Text("JUMP")
                            .foregroundStyle(.white)
                            .frame(width: 100, height: 100)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: 100, height: 100)
                    //.border(.red, width: 10)
                }
            }
        }
        //.border(.yellow, width: 10)
    }
}

#Preview {
    ZStack {
        GameView()
        GameOverlay()
    }
}
