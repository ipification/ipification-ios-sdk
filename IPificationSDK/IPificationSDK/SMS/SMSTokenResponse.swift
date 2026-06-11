//
//  SMSTokenResponse.swift
//  IPificationSDK
//

import Foundation

/// Contains identity claims returned after successful SMS OTP verification.
public class SMSTokenResponse {
    /// The subject identifier associated with the authenticated user.
    public let sub: String?
    /// The authenticated phone number, when included in the response.
    public let phoneNumber: String?
    /// A Boolean value indicating whether the backend verified the phone number.
    public let phoneNumberVerified: Bool
    /// The login hint associated with the authentication request.
    public let loginHint: String?
    /// The unmodified response body returned by the SMS backend.
    public let rawResponse: String?

    public init(sub: String? = nil, phoneNumber: String? = nil, phoneNumberVerified: Bool = false, loginHint: String? = nil, rawResponse: String? = nil) {
        self.sub = sub
        self.phoneNumber = phoneNumber
        self.phoneNumberVerified = phoneNumberVerified
        self.loginHint = loginHint
        self.rawResponse = rawResponse
    }
}
