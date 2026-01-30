//
//  AnimatedBackground.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 30.01.26.
//

import SwiftUI

struct AnimatedBackground: View {
    
    let duration: TimeInterval = 10

    var body: some View {
        GeometryReader { geo in
            TimelineView(.periodic(from: .now, by: 1/60)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let progress = (t.truncatingRemainder(dividingBy: duration)) / duration //0.0 to 1.0
                
                VStack(spacing: 0) {
                    Image(.BG)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                    Image(.BG)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                .offset(y: -geo.size.height + (progress * geo.size.height))
            }
        }
        .ignoresSafeArea()
        .drawingGroup()
    }
}

#Preview {
    AnimatedBackground()
}
