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
        
    var body: some Scene {
        WindowGroup {
            ZStack {
                AnimatedBackground()
                    .id("AnimatedBackground")
                    .ignoresSafeArea()
                Group {
                    switch AppState.shared.currentView {
                    case .MAIN_MENU:
                        MainMenu()
                            .id("MainMenu")
                            .zIndex(2.0)
                            .transition(.push(from: .bottom))
                        
                    case .PLAY_MENU:
                        PlayMenu()
                            .id("PlayMenu")
                            .zIndex(2.1)
                            .transition(.push(from: .bottom))
                        
                    case .WAITING:
                        Waiting()
                            .id("Waiting")
                            .zIndex(2.2)
                            .transition(.push(from: .bottom))
                        
                    case .ROOM_LIST:
                        RoomList()
                            .id("RoomList")
                            .zIndex(2.2)
                            .transition(.push(from: .bottom))
                        
                    case .GAME:
                        GameView()
                            .ignoresSafeArea()
                            .overlay {
                                GameOverlay()
                            }
                            .id("GameView")
                            .zIndex(2.3)
                            .transition(.push(from: .bottom))
                        
                    case .RESULT:
                        ResultView()
                            .id("ResultView")
                            .zIndex(2.2)
                            .transition(.push(from: .bottom))
                        
                    case .LEVEL_SELECTION:
                        LevelSelection()
                            .id("LevelSelection")
                            .zIndex(2.1)
                            .transition(.push(from: .bottom))
                    case .JOINING:
                        Joining()
                            .id("Joining")
                            .zIndex(2.2)
                            .transition(.push(from: .bottom))
                    }
                    
                }
            }
            .environment(AppState.shared)
        }
    }
}
