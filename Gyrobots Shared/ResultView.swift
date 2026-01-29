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
        Text("Your time: \(appState.formattedTime)")
    }
}

#Preview {
    ResultView()
}
