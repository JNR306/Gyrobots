//
//  Location.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 31.01.26.
//

import SwiftUI
internal import Combine


struct Location: View {
    
    @Environment(AppState.self) private var appState
    
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text("Level Generation")
                    .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .padding()
            Spacer()
            ZStack(alignment: .leading) {
                Text("Detecting your location to generate a level...")
                    .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
                    .opacity(0.0)
                Text("Detecting your location to generate a level\(String(repeating: ".", count: dotCount))")
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
            .onChange(of: appState.wasLevelSetByLocation) {
                if appState.wasLevelSetByLocation {
                    appState.createRoom()
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
            .onAppear {
                AppState.shared.startMenuMusicIfNeeded()
            }
        }
    }
}

#Preview {
    Location()
}
