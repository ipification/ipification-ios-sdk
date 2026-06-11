//
//  AuthChannel.swift
//  IPificationSDK
//

import Foundation

/// An authentication channel that the SDK may use during a multi-channel flow.
public enum AuthChannel {
    /// Authenticate through the IPification mobile-data flow.
    case IP
    /// Authenticate by sending and verifying an SMS one-time password.
    case SMS
}
