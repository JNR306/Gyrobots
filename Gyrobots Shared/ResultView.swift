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
            Spacer()
            HStack {
                Image(.stars)
                    .resizable()
                    .frame(width: 37, height: 37)
                    .offset(y: -1)
                    .padding(.trailing, 2)
                Text("Results")
                    .font(.custom("AvenirNext-Bold", size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(.white)
            }
            .padding()
            Spacer()
            Text("\(appState.formattedElapsedTime)")
                .font(.custom("AvenirNext-Bold", size: 55, relativeTo: .largeTitle))
                .foregroundStyle(.white)
                .padding(.horizontal, 60)
                .padding(.vertical, 20)
                .background {
                    Rectangle()
                        .foregroundStyle(.highlight)
                }
                .overlay(alignment: .topTrailing) {
                    if appState.isNewBestTime {
                        Image(.highscore)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 50)
                            .offset(x: 50, y: -30)
                            .rotationEffect(.degrees(15))
                    }
                }
            Spacer()
            HStack(spacing: 20) {
                Button {
                    appState.mp.sendImportant(MPMessage(type: .cancelMultipeer))
                    appState.cancelMultipeerAndReturnToMenu()
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
                Button {
                    appState.mp.sendImportant(MPMessage(type: .restartedGame))
                    appState.restartGame()
                } label: {
                    HStack {
                        Image(.retry)
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text("Play again")
                            .font(.custom("AvenirNext-Medium", size: 20, relativeTo: .largeTitle))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            Spacer()
        }
    }
}

#Preview {
    ResultView()
}
