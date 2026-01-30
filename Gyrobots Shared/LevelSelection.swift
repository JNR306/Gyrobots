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
            HStack(spacing: 10) {
                Spacer()
                Button {
                    withAnimation {
                        appState.currentView = .PLAY_MENU
                    }
                } label: {
                    Image(.desertButton)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                }
                Button {
                    withAnimation {
                        appState.currentView = .PLAY_MENU
                    }
                } label: {
                    Image(.cityButton)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                }
                Spacer()
            }
            Spacer()
            Button {
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
