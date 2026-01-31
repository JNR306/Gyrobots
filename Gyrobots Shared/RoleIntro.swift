//
//  RoleIntro.swift
//  Gyrobots
//
//  Created by Mert on 31.01.2026.
//

import SwiftUI
import SpriteKit
internal import Combine

struct RoleIntro: View {

    @Environment(AppState.self) private var appState

    private var roleTitle: String {
        appState.role == .jump ? "JUMPER" : "RUNNER"
    }

    private var roleDescription: String {
        if appState.role == .jump {
            return "You are the Jumper. Press the jump buttons at the right times to make the character jump."
        } else {
            return "You are the Runner. Tilt your phone to move left and right using the gyroscope."
        }
    }

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Image(.plus)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .offset(y: -1)
                    .padding(.trailing, 2)
                Text("Your Role")
                    .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .padding()

            Spacer()

            Text(roleTitle)
                .font(.custom("AvenirNext-Bold", size: 64, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .padding(.bottom, 8)

            Text(roleDescription)
                .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()

            Button {
                HapticManager.tap()
                withAnimation {
                    appState.cancelMultipeerAndReturnToMenu()
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
        .onAppear {
            // Auto-continue after 2–3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    appState.currentView = .GAME
                }
            }
        }
    }
}
