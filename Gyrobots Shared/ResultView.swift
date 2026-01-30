//
//  ResultView.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 30.01.26.
//

import SwiftUI

struct ResultView: View {
    
    @Environment(AppState.self) private var appState
    
    var body: some View {
        VStack {
            Text("Your time: \(appState.formattedElapsedTime)")
            Button {
                appState.mp.sendImportant(MPMessage(type: .restartedGame))
                appState.restartGame()
            } label: {
                Text("TRY AGAIN")
                    .frame(width: 100, height: 100)
            }
        }
    }
}

#Preview {
    ResultView()
}
