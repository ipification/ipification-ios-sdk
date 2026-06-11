//
//  RequestProtocol.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 3/6/2021.
//  Copyright © 2021 IPification Mobile. All rights reserved.
//

import Foundation

/// Defines the request data required by the SDK network transport.
public protocol RequestProtocol: AnyObject {
    /// The maximum time to wait for response data, in milliseconds.
    var readTimeout: TimeInterval {get set}
    /// The maximum time to wait for a connection, in milliseconds.
    var connectTimeout: TimeInterval {get set}
//    var dnsConnectionTimeout : TimeInterval {get set}
//    var isIPv4PreferredOverIPv6 : Bool {get set}
    /**
     generate URLComponents
     */
    func toUri() -> URLComponents
    func parseToURLComponents() -> URLComponents?
    func formatedHeaders(enableCarrierHeaders: Bool) ->String
    
//    var isEncoded : Bool{get set}
    /// Indicates whether the request follows a server redirect.
    var isRedirect : Bool{get set}
}
