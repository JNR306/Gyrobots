//
//  MultipeerManager.swift
//  Gyrobots
//
//  Created by Mert on 26.01.2026.
//


import Foundation
import MultipeerConnectivity

final class MultipeerManager: NSObject {

    static let serviceType = "gyrobots-mp"   // must be <= 15 chars, lowercase, digits, hyphen

    let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private(set) var session: MCSession!

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    // Callbacks
    var onReceivedMessage: ((MPMessage) -> Void)?
    var onConnectedPeersChanged: (([MCPeerID]) -> Void)?

    override init() {
        super.init()
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    func startHosting() {
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID,
                                              discoveryInfo: nil,
                                              serviceType: Self.serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }

    func startJoining() {
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        session.disconnect()
    }

    func send(_ message: MPMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: session.connectedPeers, with: .unreliable)
        } catch {
            print("MP send error:", error)
        }
    }
}

// MARK: - MCSessionDelegate
extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            self.onConnectedPeersChanged?(session.connectedPeers)
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let msg = try JSONDecoder().decode(MPMessage.self, from: data)
            DispatchQueue.main.async {
                self.onReceivedMessage?(msg)
            }
        } catch {
            print("MP decode error:", error)
        }
    }

    // Unused required delegates:
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID,
                 certificateHandler: @escaping (Bool) -> Void) { certificateHandler(true) }
}

// MARK: - Advertiser / Browser
extension MultipeerManager: MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session) // auto-accept
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}
