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
            if appState.availableRooms.isEmpty {
                Text("No rooms found nearby")
                    .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            } else {
                ForEach(appState.availableRooms, id: \.id) { room in
                    Button {
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
            }
            
            //appState.currentView = .PLAY_MENU
        }
    }
}
