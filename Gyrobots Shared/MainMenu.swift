//
//  MainMenu.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 11.01.26.
//

import SwiftUI
import Observation

struct MainMenu: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack {
            Spacer()
            Image(.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 50)
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: 10) {
                    Button {
                        HapticManager.tap()
                        appState.selectLevelRandomly()
                        withAnimation {
                            appState.currentView = .PLAY_MENU
                        }
                    } label: {
                        Image(.playButton)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 50)
                    }
                    Button {
                        HapticManager.tap()
                        withAnimation {
                            appState.currentView = .LEVEL_SELECTION
                        }
                    } label: {
                        Image(.levelsButton)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 50)
                    }
                }
                Spacer()
                    .overlay {
                        if appState.bestTime > 0.0 {
                            VStack {
                                Image(.crown)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .padding(.bottom, -5)
                                Text("\(appState.formattedBestTime)")
                                    .font(.custom("AvenirNext-Bold", size: 30, relativeTo: .largeTitle))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                            Text("Best time")
                                .font(.custom("AvenirNext-Regular", size: 15, relativeTo: .largeTitle))
                                .foregroundStyle(.white)
                        }
                    }
                    }
            }
            Spacer()
        }
    }
}

#Preview {
    MainMenu()
}
