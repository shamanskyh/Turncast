//
//  MultipeerManager.swift
//  Turncast
//
//  Created by Harry Shamansky on 1/1/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import MultipeerMessages
import SwiftUI

class MultipeerManager: NSObject {
    
    static let shared = MultipeerManager()
    
    private let session: MCSession
    
    private let clientPeerID = MCPeerID(displayName: UIDevice.current.name)
    
    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    
    private var serverPeerID: MCPeerID?
    
    var serverIPAddress: String?
    
    weak var metadataStore: MetadataStore?
    
    weak var streamSource: StreamSource?
    
    override init() {
        session = MCSession(peer: clientPeerID, securityIdentity: nil, encryptionPreference: .none)
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: clientPeerID, discoveryInfo: nil, serviceType: turncastServiceType)
        super.init()
        session.delegate = self
        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()
        
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc func didEnterForeground() {
        sendMessageToServer(message: .broadcastUpdate)
    }
    
    func sendMessageToServer(message: MultipeerMessage) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(message), let serverPeerID = serverPeerID {
            do {
                try session.send(data, toPeers: [serverPeerID], with: .reliable)
            } catch {
                print(error)
            }
        }
    }
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        serverPeerID = peerID
        if let data = context {
            serverIPAddress = String(data: data, encoding: .utf8)
        }
        
        // start playing
        #if os(tvOS)
        streamSource?.playing = true
        #endif
        
        invitationHandler(true, session)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
            self?.sendMessageToServer(message: .broadcastUpdate)
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print(error)
    }
}

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("\(peerID) did change state \(state)")
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // no-op
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // no-op
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // no-op
    }
    
    func session(_ session: MCSession,
                 didReceive data: Data,
                 fromPeer peerID: MCPeerID) {
        let decoder = JSONDecoder()
        if let message = try? decoder.decode(MultipeerMessage.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                switch message {
                case .broadcastUpdate:
                    // we don't respond to these
                    break
                case .albumTitle(let title):
                    strongSelf.metadataStore?.blockUpdates = true
                    strongSelf.metadataStore?.albumTitle = title
                    strongSelf.metadataStore?.blockUpdates = false
                case .artist(let artist):
                    strongSelf.metadataStore?.blockUpdates = true
                    strongSelf.metadataStore?.artist = artist
                    strongSelf.metadataStore?.blockUpdates = false
                case .imageURL(let url):
                    strongSelf.metadataStore?.blockUpdates = true
                    DispatchQueue.global(qos: .background).async {
                        guard let strongSelf = self else { return }
                        if let data = try? Data(contentsOf: url), let uiImage = UIImage(data: data) {
                            let swiftUIImage = Image(uiImage: uiImage)
                            if let cgImage = uiImage.cgImage {
                                DispatchQueue.main.sync {
                                    guard let strongSelf = self else { return }
                                    strongSelf.metadataStore?.albumImageData = cgImage
                                    strongSelf.metadataStore?.albumImage = swiftUIImage
                                }
                            }
                        }
                        strongSelf.metadataStore?.blockUpdates = false
                    }
                case .clearImageURL:
                    strongSelf.metadataStore?.blockUpdates = true
                    strongSelf.metadataStore?.albumImage = Image("NoInfo")
                    strongSelf.metadataStore?.blockUpdates = false
                    
                }
            }
        }
    }
}
