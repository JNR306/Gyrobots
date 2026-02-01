//
//  RoomList.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//


import SwiftUI
import SpriteKit

struct RoomList: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image(.person)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .offset(y: -1)
                    .padding(.trailing, 2)
                Text("Join Game")
                    .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .padding()
            Spacer()
            Rectangle()
                .foregroundStyle(.highlight)
                .frame(width: 410, height: 200)
                .overlay {
                    ScrollView {
                        if appState.availableRooms.isEmpty {
                            Text("No rooms found nearby")
                                .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .containerRelativeFrame(.vertical)
                        } else {
                            ForEach(appState.availableRooms, id: \.id) { room in
                                Button {
                                    HapticManager.tap()
                                    withAnimation {
                                        appState.join(room: room)
                                    }
                                } label: {
                                    Text(room.name)
                                        .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .containerRelativeFrame(.vertical)
                        }
                    }
                }
            Spacer()
            Button {
                HapticManager.tap()
                withAnimation {
                    appState.currentView = .PLAY_MENU
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
            .onAppear {
                AppState.shared.startMenuMusicIfNeeded()
            }
        }
    }
}
