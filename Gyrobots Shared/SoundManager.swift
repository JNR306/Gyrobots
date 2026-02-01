//
//  SoundManager.swift
//  Gyrobots
//
//  Created by Mert on 1.02.2026.
//


import AVFoundation

final class SoundManager {
    static let shared = SoundManager()

    private var sfxPlayers: [String: AVAudioPlayer] = [:]
    private var musicPlayer: AVAudioPlayer?

    // MARK: - SFX (short sounds)
    func playSFX(_ file: String, volume: Float = 1.0) {
        if let p = sfxPlayers[file] {
            p.currentTime = 0
            p.volume = volume
            p.play()
            return
        }
        guard let url = Bundle.main.url(forResource: file, withExtension: nil) else {
            print("Missing SFX file:", file)
            return
        }
        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.volume = volume
            p.prepareToPlay()
            p.play()
            sfxPlayers[file] = p
        } catch {
            print("SFX audio error:", error)
        }
    }

    // MARK: - Music (one looping track at a time)
    func playMusic(_ file: String, volume: Float = 0.5, loop: Bool = true) {
        // If same track already playing, do nothing
        if musicPlayer?.url == Bundle.main.url(forResource: file, withExtension: nil),
           musicPlayer?.isPlaying == true {
            return
        }

        stopMusic()

        guard let url = Bundle.main.url(forResource: file, withExtension: nil) else {
            print("Missing music file:", file)
            return
        }

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = loop ? -1 : 0
            p.volume = volume
            p.prepareToPlay()
            p.play()
            musicPlayer = p
        } catch {
            print("Music audio error:", error)
        }
    }

    func stopMusic() {
        musicPlayer?.stop()
        musicPlayer = nil
    }
}
