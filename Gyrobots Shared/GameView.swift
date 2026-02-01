//
//  ContentView.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 11.01.26.
//

import SwiftUI
import SpriteKit
import MultipeerConnectivity

struct GameView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        ZStack {
            SpriteView(scene: appState.gameScene)
                .ignoresSafeArea()
        }
        .onAppear {
            appState.startSensors()
            appState.startGameIfNeeded()
            AppDelegate.lockOrientation()
        }
        .onDisappear {
            appState.stopSensors()
            AppDelegate.unlockOrientation()
        }
    }
}

struct GameOverlay: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var collectIsDisabled = false
    
    var body: some View {
        VStack {
            HStack {
                Button {
                    HapticManager.tap()
                    if !appState.mp.session.connectedPeers.isEmpty {
                            appState.mp.sendImportant(MPMessage(type: .cancelMultipeer))

                            // Give the message a moment to flush
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                appState.cancelMultipeerAndReturnToMenu()
                            }
                        } else {
                            appState.cancelMultipeerAndReturnToMenu()
                        }
                } label: {
                    Image(.closeButton)
                        .resizable()
                        .frame(width: 40, height: 40)
                }
                Spacer()
                Text("\(appState.formattedElapsedTimeWithoutLabel)")
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
                let buttonSize = UIDevice.current.userInterfaceIdiom == .pad ? CGFloat(100) : CGFloat(80)
                HStack {
                    Button {
                        //collect
                        print("Try to collect")
                        appState.handleCollectAction()
                        withAnimation {
                            collectIsDisabled = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                collectIsDisabled = false
                            }
                        }
                    } label: {
                        Image(.collectButton)
                            .resizable()
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: buttonSize, height: buttonSize)
                    .padding()
                    .disabled(collectIsDisabled)
                    .opacity(collectIsDisabled ? 0.5 : 1.0)
                    Spacer()
                    Button {
                        appState.handleJumpAction()
                    } label: {
                        Image(.jumpButton)
                            .resizable()
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .frame(width: buttonSize, height: buttonSize)
                    .padding()
                }
            }
        }
    }
}

struct TiltOverlay: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                if appState.role == .gyro {
                    Image(appState.tiltX > appState.gameScene.tiltDeadzone ? .rightMovementIndicator : appState.tiltX < -appState.gameScene.tiltDeadzone ? .leftMovementIndicator : .noMovementIndicator)
                        .resizable()
                        .scaledToFit()
                        .frame(height: UIDevice.current.userInterfaceIdiom == .pad ? 50 : 30)
                        .padding(.bottom, UIDevice.current.userInterfaceIdiom == .pad ? 10 : 5)
                    Rectangle()
                        .foregroundStyle(.darkHighlight)
                        .frame(width: geo.size.width, height: 10)
                        .overlay {
                            Rectangle()
                                .foregroundStyle(.white)
                                .frame(width: 100, height: 10)
                                .offset(x: appState.tiltX * (geo.size.width - 100) / 2)
                        }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        GameView()
        GameOverlay()
    }
}
