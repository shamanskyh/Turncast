//
//  IPAddressHelper.swift
//  Turncast Server
//
//  Created by Harry Shamansky on 1/2/21.
//  Copyright © 2021 Harry Shamansky. All rights reserved.
//

import Foundation

class IPAddressHelper {
    enum NetworkingInterface: String {
        case en0 = "en0"
        case en1 = "en1"
    }
    
    static func getIPAddress(for interface: NetworkingInterface = .en0) -> String? {
        var address : String?

        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }

        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let networkingInterface = ifptr.pointee

            // Check for IPv4 or IPv6 interface:
            let addrFamily = networkingInterface.ifa_addr.pointee.sa_family
            if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {

                // Check interface name:
                let name = String(cString: networkingInterface.ifa_name)
                if  name == interface.rawValue {

                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(networkingInterface.ifa_addr, socklen_t(networkingInterface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    let possibleAddress = String(cString: hostname)
                    if !possibleAddress.contains(":") {
                        address = possibleAddress
                    }
                }
            }
        }
        freeifaddrs(ifaddr)

        return address
    }
}
