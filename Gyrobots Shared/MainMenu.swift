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
        VStack(spacing: 10) {
            Image(.logo)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 50)
            Spacer()
                .frame(height: 30)
            Button {
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
                
            } label: {
                Image(.levelsButton)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50)
            }
            Button {
                
            } label: {
                Image(.leaderboardButton)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 50)
            }
        }
    }
}

#Preview {
    MainMenu()
}
