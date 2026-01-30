//
//  Waiting.swift
//  Gyrobots
//
//  Created by Mert on 30.01.2026.
//


import SwiftUI
import SpriteKit

struct Waiting: View {

    @Environment(AppState.self) private var appState

    var body: some View {
        Text("Waiting for other player...")
            .font(.custom("AvenirNext-Regular", size: 20, relativeTo: .largeTitle))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
        //appState.cancelMultipeerAndReturnToMenu()
    }
}
