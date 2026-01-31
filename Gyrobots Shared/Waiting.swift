//
//  Waiting.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//


import SwiftUI
import SpriteKit
internal import Combine

struct Waiting: View {

    @Environment(AppState.self) private var appState
    
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Image(.plus)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .offset(y: -1)
                    .padding(.trailing, 2)
                Text("New Game")
                    .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .padding()
            Spacer()
            ZStack(alignment: .leading) {
                Text("Waiting for other player...")
                    .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                    .opacity(0.0)
                Text("Waiting for other player\(String(repeating: ".", count: dotCount))")
                    .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .onReceive(timer) { _ in
                withAnimation {
                    if dotCount < 3 {
                        dotCount += 1
                    } else {
                        dotCount = 0
                    }
                }
            }
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
    }
}
