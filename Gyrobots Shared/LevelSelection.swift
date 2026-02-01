//
//  LevelSelection.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 30.01.26.
//

import SwiftUI

struct LevelSelection: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Spacer()
            Text("Levels")
                .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .padding()
            Spacer()
            ScrollView(.horizontal) {
                ZStack {
                    Color.clear
                        .containerRelativeFrame(.horizontal)

                    HStack(spacing: 10) {
                        Spacer()
                        Button {
                            HapticManager.tap()
                            appState.selectLevel(Level(rawValue: Int.random(in: 1...3)) ?? .CITY)
                            withAnimation {
                                appState.createRoom()
                            }
                        } label: {
                            Image(.randomButton)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                        }
                        Button {
                            HapticManager.tap()
                            SoundManager.shared.playSFX("menu-button-89141.mp3", volume: 0.9)
                            appState.selectLevel(.DESERT)
                            withAnimation {
                                appState.createRoom()
                            }
                        } label: {
                            Image(.desertButton)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                        }
                        Button {
                            HapticManager.tap()
                            SoundManager.shared.playSFX("menu-button-89141.mp3", volume: 0.9)
                            appState.selectLevel(.CITY)
                            withAnimation {
                                appState.createRoom()
                            }
                        } label: {
                            Image(.cityButton)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                        }
                        Button {
                            HapticManager.tap()
                            SoundManager.shared.playSFX("menu-button-89141.mp3", volume: 0.9)
                            appState.selectLevel(.FOREST)
                            withAnimation {
                                appState.createRoom()
                            }
                        } label: {
                            Image(.forestButton)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 200)
                        }
                        Spacer()
                        .onAppear {
                            AppState.shared.startMenuMusicIfNeeded()
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            .scrollIndicators(.hidden)
            Spacer()
            Button {
                HapticManager.tap()
                SoundManager.shared.playSFX("menu-button-89141.mp3", volume: 0.9)
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

#Preview {
    LevelSelection()
}
