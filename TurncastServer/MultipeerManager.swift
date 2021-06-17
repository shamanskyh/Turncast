//
//  MultipeerManager.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 1/1/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import MultipeerMessages
import os
import SwiftUI

protocol MetadataSource: AnyObject {
    var albumImage: Image { get set }
    var albumImageURL: URL? { get set }
    var albumTitle: String { get set }
    var albumArtist: String { get set }
    var blockBroadcast: Bool { get set }
}

class MultipeerManager: NSObject {
    
    let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "multipeer-manager")
    
    // callback for updates
    private weak var delegate: MetadataSource?
    
    private var peers = [MCPeerID]()
    
    private let serverPeerID = MCPeerID(displayName: "Turncast Server")
    
    private let session: MCSession
    
    private let serviceBrowser: MCNearbyServiceBrowser
    
    init(delegate: MetadataSource) {
        self.delegate = delegate
        
        session = MCSession(peer: serverPeerID, securityIdentity: nil, encryptionPreference: .none)
        
        serviceBrowser = MCNearbyServiceBrowser(peer: serverPeerID, serviceType: turncastServiceType)
        
        super.init()
        
        serviceBrowser.delegate = self
        serviceBrowser.startBrowsingForPeers()
        
        session.delegate = self
    }
    
    private func broadcast(message: MultipeerMessage, to peers: [MCPeerID]) {
        logger.debug("Broadcasting message to peers: \(peers, privacy: .public)")
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(message)
                try strongSelf.session.send(data, toPeers: peers, with: .reliable)
            } catch {
                strongSelf.logger.error("\(error.localizedDescription)")
            }
        }
    }
    
    func broadcast(message: MultipeerMessage) {
        self.broadcast(message: message, to: peers)
    }
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        logger.debug("Found peer \(peerID, privacy: .public)")
        
        if !peers.contains(peerID) {
            logger.debug("Adding peer \(peerID, privacy: .public) to list")
            peers.append(peerID)
        }
        
        // send the IP Address so the client knows how to get the stream
        if let ipAddress = IPAddressHelper.getIPAddress() ?? IPAddressHelper.getIPAddress(for: .en1) {
            logger.debug("Detected server IP address of \(ipAddress, privacy: .public)")
            let data = ipAddress.data(using: .utf8)
            logger.debug("Inviting \(peerID, privacy: .public) to session")
            browser.invitePeer(peerID, to: session, withContext: data, timeout: 120.0)
        } else {
            logger.error("Could not detect server IP Address")
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        if let index = peers.firstIndex(of: peerID) {
            logger.debug("Removing \(peerID, privacy: .public) from session")
            peers.remove(at: index)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        logger.error("Did not start browsing for peers")
        logger.error("\(error.localizedDescription)")
    }
}

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        logger.debug("\(peerID, privacy: .public) did change state \(state.rawValue, privacy: .public)")
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
        // do something with the received data
        logger.debug("received data from \(peerID, privacy: .public)")
        
        let decoder = JSONDecoder()
        if let multipeerMessage = try? decoder.decode(MultipeerMessage.self, from: data) {
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return }
                switch multipeerMessage {
                case .broadcastUpdate:
                    if let delegate = strongSelf.delegate {
                        strongSelf.broadcast(message: .albumTitle(delegate.albumTitle))
                        strongSelf.broadcast(message: .artist(delegate.albumArtist))
                        if let imageURL = delegate.albumImageURL {
                            strongSelf.broadcast(message: .imageURL(imageURL))
                        } else {
                            strongSelf.broadcast(message: .clearImageURL)
                        }
                    }
                case .albumTitle(let title):
                    strongSelf.delegate?.blockBroadcast = true
                    strongSelf.delegate?.albumTitle = title
                    strongSelf.delegate?.blockBroadcast = false
                    strongSelf.broadcast(message: multipeerMessage, to: strongSelf.peers.filter({ $0 != peerID }))
                case .artist(let artist):
                    strongSelf.delegate?.blockBroadcast = true
                    strongSelf.delegate?.albumArtist = artist
                    strongSelf.delegate?.blockBroadcast = false
                    strongSelf.broadcast(message: multipeerMessage, to: strongSelf.peers.filter({ $0 != peerID }))
                case .imageURL(let url):
                    DispatchQueue.global(qos: .background).async {
                        if let nsImage = NSImage(contentsOf: url) {
                            let image = Image(nsImage: nsImage)
                            DispatchQueue.main.async {
                                guard let strongSelf = self else { return }
                                strongSelf.delegate?.blockBroadcast = true
                                strongSelf.delegate?.albumImage = image
                                strongSelf.delegate?.blockBroadcast = false
                                strongSelf.broadcast(message: multipeerMessage, to: strongSelf.peers.filter({ $0 != peerID }))
                            }
                        }
                    }
                case .clearImageURL:
                    strongSelf.delegate?.blockBroadcast = true
                    strongSelf.delegate?.albumImageURL = nil
                    strongSelf.delegate?.blockBroadcast = false
                }
            }
        }
    }
}
