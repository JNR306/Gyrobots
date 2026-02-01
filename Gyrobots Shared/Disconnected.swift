//
//  Disconnected.swift
//  Gyrobots
//
//  Created by Mert on 31.01.2026.
//

import SwiftUI
import SpriteKit
internal import Combine

struct Disconnected: View {

    @Environment(AppState.self) private var appState

    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            Spacer()

            HStack {
                Image(.warning)
                    .resizable()
                    .frame(width: 33, height: 33)
                    .padding(.trailing, 2)
                Text("Disconnected")
                    .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .padding()

            Spacer()

            ZStack(alignment: .leading) {
                Text("The other person has disconnected, sending you to main menu...")
                    .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                    .opacity(0.0)

                Text("The other person has disconnected, sending you to main menu\(String(repeating: ".", count: dotCount))")
                    .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .onReceive(timer) { _ in
                withAnimation {
                    dotCount = (dotCount < 3) ? (dotCount + 1) : 0
                }
            }
            .onAppear {
                // Backup (in case handler isn't called for some reason)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        appState.cancelMultipeerAndReturnToMenu()
                    }
                }
            }

            Spacer()
            .onAppear {
                AppState.shared.startMenuMusicIfNeeded()
            }
            /*
            Button {
                HapticManager.tap()
                withAnimation {
                    appState.cancelMultipeerAndReturnToMenu()
                }
            } label: {
                HStack {
                    Image(.home)
                        .resizable()
                        .frame(width: 16, height: 16)
                        .offset(y: -1)
                    Text("Main Menu")
                        .font(.custom("AvenirNext-Medium", size: 20, relativeTo: .largeTitle))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
            */
            Spacer()
        }
    }
}
