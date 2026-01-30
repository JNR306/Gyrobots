//
//  AnimatedBackground.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 30.01.26.
//

import SwiftUI

struct AnimatedBackground: View {
    
    @State private var isAnimatingBackground = false

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Image(.BG)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                Image(.BG)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .offset(y: -geo.size.height)
            .offset(y: isAnimatingBackground ? geo.size.height : 0)
            .animation(.linear(duration: 10).repeatForever(autoreverses: false), value: isAnimatingBackground)
            .onAppear {
                withAnimation {
                    isAnimatingBackground = true
                }
            }
        }
    }
}

#Preview {
    AnimatedBackground()
}
