//
//  PlayMenu.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//

import SwiftUI
import SpriteKit
import CoreLocation

struct PlayMenu: View {

    @Environment(AppState.self) private var appState
    @State private var showManualPicker = false

    var body: some View {
        VStack {
            Spacer()
            Text("Play")
                .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .padding()
            Spacer()
            HStack(spacing: 10) {
                Spacer()
                Button {
                    HapticManager.tap()
                    withAnimation {
                        appState.locate()
                    }
                } label: {
                    Image(.newGameButton)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                }
                Button {
                    HapticManager.tap()
                    withAnimation {
                        appState.browseRooms()
                    }
                } label: {
                    Image(.joinGameButton)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 200)
                }
                Spacer()
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
            Button {
                HapticManager.tap()
                showManualPicker = true
            } label: {
                Text("Choose Location (Demo)")
                    .font(.custom("AvenirNext-Medium", size: 18, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .sheet(isPresented: $showManualPicker) {
                ManualLocationPickerView(
                    onCancel: { showManualPicker = false },
                    onUse: { coord in
                        showManualPicker = false
                        withAnimation { appState.locate(using: coord) }
                    },
                    onUseRealGPS: {
                        showManualPicker = false
                        withAnimation { appState.locate(using: nil) }
                    }
                )
            }

            Spacer()
        }
    }
}
