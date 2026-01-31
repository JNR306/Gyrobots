//
//  Gyrobots.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 11.01.26.
//

import Foundation
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    static func lockOrientation() {
        print("lock")
        print(AppDelegate.orientationLock)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        let currentOrientation = windowScene.interfaceOrientation
        let mask: UIInterfaceOrientationMask
        
        switch currentOrientation {
        case .landscapeLeft: mask = .landscapeLeft
        case .landscapeRight: mask = .landscapeRight
        case .portrait: mask = .portrait
        case .portraitUpsideDown: mask = .portraitUpsideDown
        default: mask = .all
        }
        
        AppDelegate.orientationLock = mask
        
        print(AppDelegate.orientationLock)
        
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }

    static func unlockOrientation() {
        print("unlock")
        AppDelegate.orientationLock = .all
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
            windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}

@main
struct Gyrobots: App {
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
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
                    case .DISCONNECTED:
                        Disconnected()
                            .id("Disconnected")
                            .zIndex(2.2)
                            .transition(.push(from: .bottom))
                    case .ROLE_INTRO:
                        RoleIntro()
                            .id("RoleIntro")
                            .zIndex(2.2)
                            .transition(.push(from: .bottom))
                    }
                    
                }
            }
            .environment(AppState.shared)
        }
    }
}
