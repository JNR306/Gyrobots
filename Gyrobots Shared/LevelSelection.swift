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
                HStack(spacing: 10) {
                    Button {
                        HapticManager.tap()
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
                }
                .containerRelativeFrame(.horizontal)
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

#Preview {
    LevelSelection()
}
