//
//  ConnectionManager.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//


import Foundation
/// Provides internal network-interface and connectivity checks used by the SDK.
public class ConnectionManager {
    
    /// The process-wide connection manager.
    static let sharedInstance = ConnectionManager()
    
    
     // Return IP address String, port String & sockaddr of WWAN interface (pdp_ip0), or `nil`
     func getInterface(host: String) -> (String?, String?, UnsafeMutablePointer<sockaddr>?) {
        
        var hostv4 : String?
        var servicev4 : String?
        
        var hostv6 : String?
        var servicev6 : String?
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        var clt : UnsafeMutablePointer<sockaddr>?
        
        guard getifaddrs(&ifaddr) == 0 else {
            return (nil, nil, clt)
        }
        guard let firstAddr = ifaddr else {
            return (nil, nil, clt)
        }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let flags = Int32(ifptr.pointee.ifa_flags)
            
            /// Check for running IPv4 interfaces. Skip the loopback interface.
              if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) { //Interested in IPv4 for in particular case
                    
                    // Check interface name:
                    let name = String(cString: interface.ifa_name)
                    
                    if  name.hasPrefix("pdp_ip0") { //cellular interface
                        
                        // Convert interface address to a human readable string:
                        let ifa_addr_Value = interface.ifa_addr.pointee
                        clt = UnsafeMutablePointer<sockaddr>.allocate(capacity: 1)
                        clt?.initialize(repeating: ifa_addr_Value, count: 1)
                        
                        var hostnameBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        var serviceBuffer = [CChar](repeating: 0, count: Int(NI_MAXSERV))
                        getnameinfo(interface.ifa_addr, socklen_t(ifa_addr_Value.sa_len),
                                    &hostnameBuffer, socklen_t(hostnameBuffer.count),
                                    &serviceBuffer,
                                    socklen_t(serviceBuffer.count),
                                    NI_NUMERICHOST | NI_NUMERICSERV)
                        hostv4 = String(cString: hostnameBuffer)
                        servicev4 = String(cString: serviceBuffer)
                        break;
                    }
                }
                if addrFamily == UInt8(AF_INET6) { //Interested in IPv4 for in particular case
                                    
                        // Check interface name:
                        let name = String(cString: interface.ifa_name)
                        
                        if  name.hasPrefix("pdp_ip0") { //cellular interface
                            
                            // Convert interface address to a human readable string:
                            let ifa_addr_Value = interface.ifa_addr.pointee
                            clt = UnsafeMutablePointer<sockaddr>.allocate(capacity: 1)
                            clt?.initialize(repeating: ifa_addr_Value, count: 1)
                            
                            var hostnameBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            var serviceBuffer = [CChar](repeating: 0, count: Int(NI_MAXSERV))
                            getnameinfo(interface.ifa_addr, socklen_t(ifa_addr_Value.sa_len),
                                        &hostnameBuffer, socklen_t(hostnameBuffer.count),
                                        &serviceBuffer,
                                        socklen_t(serviceBuffer.count),
                                        NI_NUMERICHOST | NI_NUMERICSERV)
                            hostv6 = String(cString: hostnameBuffer)
                            servicev6 = String(cString: serviceBuffer)
                            break;
                        }
                    }
            }
        }
        freeifaddrs(ifaddr)
        if(hostv4 == nil && hostv6 != nil){
            return (hostv6, servicev6, clt)
        }
        return (hostv4, servicev4, clt)
    }
    
    
    public static func checkNetworkInterfaces() -> (Bool, Bool, String?, String?, String?, String?) {
        // Get list of all interfaces on the local machine:
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0 else {
            return (false, false, nil, nil, nil, nil)
        }
        guard let firstAddr = ifaddr else {
            return (false, false, nil, nil, nil, nil)
        }
        
        var is3GOn = false
        var isWifiOn = false
        var cellularIPv4: String? = nil
        var wifiIPv4: String? = nil
        var cellularIPv6: String? = nil
        var wifiIPv6: String? = nil
        
        // Iterate over each interface
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let flags = Int32(interface.ifa_flags)
            guard let address = interface.ifa_addr else {
                continue
            }
            
            // Check for active, non-loopback IP interfaces
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                let addrFamily = address.pointee.sa_family
                if addrFamily == UInt8(AF_INET) || addrFamily == UInt8(AF_INET6) {
                    let name = String(cString: interface.ifa_name)
                    
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(address, socklen_t(address.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    let ipAddress = String(cString: hostname)
                    
                    if name.hasPrefix("pdp_ip") {
                        is3GOn = true
                        if addrFamily == UInt8(AF_INET) {
                            cellularIPv4 = cellularIPv4 ?? ipAddress
                        } else if isUsableIPv6(ipAddress) {
                            cellularIPv6 = cellularIPv6 ?? ipAddress
                        }
                    }
                    if name.hasPrefix("en0") {
                        isWifiOn = true
                        if addrFamily == UInt8(AF_INET) {
                            wifiIPv4 = wifiIPv4 ?? ipAddress
                        } else if isUsableIPv6(ipAddress) {
                            wifiIPv6 = wifiIPv6 ?? ipAddress
                        }
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)  // Free the interface list memory
        return (is3GOn, isWifiOn, cellularIPv4, wifiIPv4, cellularIPv6, wifiIPv6)
    }

    // Return preferred IP address strings of WWAN and Wi‑Fi interfaces.
    public static func checkOnly3G() -> (Bool, Bool, String?, String?) {
        let (is3GOn, isWifiOn, cellularIPv4, _, cellularIPv6, _) = checkNetworkInterfaces()
        return (is3GOn, isWifiOn, cellularIPv4 ?? "", cellularIPv6 ?? "")
    }

    private static func isUsableIPv6(_ ipAddress: String) -> Bool {
        let normalizedAddress = ipAddress.lowercased()
        return normalizedAddress != "::" &&
            normalizedAddress != "::1" &&
            normalizedAddress.hasPrefix("fe80:") == false &&
            normalizedAddress.hasPrefix("fc") == false &&
            normalizedAddress.hasPrefix("fd") == false
    }

    
//    internal static func  printAddresses() {
//        var addrList : UnsafeMutablePointer<ifaddrs>?
//        guard
//            getifaddrs(&addrList) == 0,
//            let firstAddr = addrList
//        else { return }
//        defer { freeifaddrs(addrList) }
//        var result = "";
//        for cursor in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
//            let interfaceName = String(cString: cursor.pointee.ifa_name)
//            let addrStr: String
//            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
//            if
//                let addr = cursor.pointee.ifa_addr,
//                getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, socklen_t(0), NI_NUMERICHOST) == 0,
//                hostname[0] != 0
//            {
//                addrStr = String(cString: hostname)
//            } else {
//                addrStr = "?"
//            }
//            result += interfaceName
//            result += " "
//            result += addrStr
//            result += "\n"
//        }
//        print(result)
//        return
//    }
}
