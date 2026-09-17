//
//  SMSCallback.swift
//  IPificationSDK
//

import Foundation

/// Receives state changes from a standalone SMS authentication flow.
public protocol SMSCallback: AnyObject {
    /// Called when the backend accepts the request and an OTP must be verified.
    func onAuthInitiated(response: SMSAuthResponse)
    /// Called after the OTP is verified successfully.
    func onSuccess(response: SMSTokenResponse)
    /// Called when SMS authentication cannot continue or fails.
    func onError(error: IPificationException)
}

/// Receives results from an authentication flow that may use IP or SMS.
public protocol MultiAuthCallback: AnyObject {
    /// Called when IP-based authentication succeeds.
    func onSuccess(response: AuthorizationResponse)
    /// Called when the flow falls back to SMS and requires an OTP.
    ///
    /// Collect the code from the user and pass it to `AuthorizationService.verifySMSOTP(otpCode:authReqId:nonce:)`;
    /// the result arrives in `onSMSSuccess(response:)` or `onError(error:)` on this same callback.
    func onOTPRequired(response: SMSAuthResponse)
    /// Called after the SMS OTP is verified successfully.
    ///
    /// Optional. The default implementation does nothing, so existing conformers keep compiling.
    func onSMSSuccess(response: SMSTokenResponse)
    /// Called when authentication cannot continue or fails.
    func onError(error: IPificationException)
}

public extension MultiAuthCallback {
    func onSMSSuccess(response: SMSTokenResponse) {
    }
}
