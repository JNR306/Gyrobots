//
//  Gyrobots.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 11.01.26.
//

import Foundation
import SwiftUI

@main
struct Gyrobots: App {
    
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                Image(.BG)
                  .resizable()
                  .aspectRatio(contentMode: .fill)
                  .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                  .clipped()
                  .ignoresSafeArea()
                  //.border(.blue, width: 7)
                Group {
                    switch appState.currentView {
                    case .MAIN_MENU:
                        MainMenu()
                            .id("MainMenu")
                            .zIndex(2.0)
                            .transition(.push(from: .bottom))
                    case .GAME:
                        GameView()
                            .ignoresSafeArea()
                            .overlay {
                                GameOverlay()
                            }
                            .id("GameView")
                            .zIndex(2.1)
                            .transition(.push(from: .bottom))
                    }
                }
            }
            .environment(appState)
            .onAppear {
                if appState.gameScene == nil {
                    appState.prepareGame()
                }
            }
        }
    }
}
