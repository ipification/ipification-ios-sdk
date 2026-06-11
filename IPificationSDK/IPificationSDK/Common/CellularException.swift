//
//  CellularException.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//

import Foundation

/// Stable numeric error codes exposed by the SDK.
public struct IPificationSDKErrorCode {
    /// A general validation or configuration error.
    public static let generalError = 800
    /// Cellular networking is not active.
    public static let networkIsNotActive = 1000
    /// A network connection or transport operation failed.
    public static let networkError = 1001
    /// A required phone number is empty.
    public static let emptyPhoneNumber = 1002
    /// The client identifier is empty.
    public static let emptyClientId = 1003
    /// The redirect URI is empty.
    public static let emptyRedirectUri = 1004
    /// The OAuth scope is empty.
    public static let emptyScope = 1005
    /// The current iOS version is unsupported.
    public static let unsupportedVersion = 1006
    /// The coverage endpoint is empty or invalid.
    public static let emptyCoverageEndpoint = 1007
    /// A required login hint is empty.
    public static let emptyLoginHint = 1008
    /// The authorization endpoint is empty or invalid.
    public static let emptyAuthEndpoint = 1009
    /// The required network is unavailable.
    public static let networkIsUnavailable = 1010
    /// No usable SIM is available.
    public static let simIsUnavailable = 1011
    /// iOS local-network permission is required to continue.
    public static let localNetworkPermissionRequired = 1012
    /// A required instant-messaging header is empty.
    public static let emptyIMHeader = 2001
    /// Instant-messaging authentication failed.
    public static let imFailed = 2002
    /// Instant-messaging authentication has no usable network.
    public static let imNoNetworkError = 2003
    /// No instant-messaging app priority was configured.
    public static let emptyIMPriorityAppList = 2005
    /// The network response could not be processed.
    public static let networkResponseFailed = 803
    /// The server returned an unsuccessful response.
    public static let serverResponseFailed = 804
}

/// High-level categories of errors produced by the SDK.
public enum IPificationError {
    
    /// Validation error cases.
    /// ERRORCODE: validation
    /// ERROR MESSAGE: CLIENT_ID is nil
    /// ERROR MESSAGE: REDIRECT_URI is nil
    /// ERROR MESSAGE: Scope cannot be empty
    /// ERROR MESSAGE: login_hint cannot be empty when scope is ip:phone_verify or ip:profile
    case validation
    
    
    /// Error when the app or service version is unsupported (for versions under 12).
    /// ERRORCODE: unsupported_version
    /// ERROR MESSAGE: The version of the app or service is not supported (version under 12).
    case unsupported_version
    
    /// Error when the cellular service is not active.
    /// ERRORCODE: notActive
    /// ERROR MESSAGE: CELLULAR_NOT_ACTIVE {detail error message}
    case notActive
    
    /// Error when the connection cannot be established.
    /// ERRORCODE: cannot_connect
    /// ERROR MESSAGE: Failed to connect - Timeout {timeout value}
    /// ERROR MESSAGE: {error message from network connection}
    case cannot_connect

    /// Error when iOS Local Network permission is still required to continue the request.
    /// ERRORCODE: localNetworkPermissionRequired
    /// ERROR MESSAGE: Failed to connect to {url} - Local Network permission required
    case localNetworkPermissionRequired
    
    /// deprecated 
    /// Error due to a connection error.
    /// ERRORCODE: connection_error
    /// ERROR MESSAGE: {error message from network connection}
    case connection_error
    
    
    
    
    /// Error when authorization fails.
    /// ERRORCODE: authorized_failed
    /// ERROR MESSAGE: {error response from server}
    case authorized_failed
    
    /// Error when checking coverage fails.
    /// ERRORCODE: check_coverage_failed
    /// ERROR MESSAGE: {error response from server}
    case check_coverage_failed
    
    /// for IM only
    /// Error when the user cancels the operation.
    /// ERRORCODE: user_cancel
    case user_cancel

    /// The default numeric SDK error code for this category.
    public var code: Int {
        switch self {
        case .validation:
            return IPificationSDKErrorCode.generalError
        case .unsupported_version:
            return IPificationSDKErrorCode.unsupportedVersion
        case .notActive:
            return IPificationSDKErrorCode.networkIsNotActive
        case .cannot_connect:
            return IPificationSDKErrorCode.networkError
        case .localNetworkPermissionRequired:
            return IPificationSDKErrorCode.localNetworkPermissionRequired
        case .connection_error:
            return IPificationSDKErrorCode.networkError
        case .authorized_failed:
            return IPificationSDKErrorCode.serverResponseFailed
        case .check_coverage_failed:
            return IPificationSDKErrorCode.serverResponseFailed
        case .user_cancel:
            return IPificationSDKErrorCode.imFailed
        }
    }
    
}


/// Provides structured details about a failed SDK operation.
public struct IPificationException: Error {
    /// The unmodified server response associated with the failure, when available.
    public let rawResponse: String?
    /// The protocol or backend error code, when available.
    public let errorCode: String?
    /// The protocol or backend error description, when available.
    public let errorDescription: String?
    /// A human-readable summary of the failure.
    public let message: String
    /// The high-level SDK error category.
    public let error: IPificationError
    init(_ error : IPificationError, _ message: String, errorCode: String? = nil, errorDescription: String? = nil, rawResponse: String? = nil) {
        self.message = message
        self.error = error
        self.errorCode = errorCode
        self.errorDescription = errorDescription
        self.rawResponse = rawResponse
    }

    /// A human-readable description of the failure.
    public var localizedDescription: String {
        return message
    }
    
    /// The high-level SDK error category.
    public var sdkErrorCode: IPificationError {
        return error
    }

    /// The most specific numeric SDK error code available for this failure.
    public var sdkErrorCodeNumber: Int {
        switch error {
        case .validation:
            return validationErrorCodeNumber()
        default:
            return error.code
        }
    }

    /// Indicates whether granting iOS local-network permission may resolve the failure.
    public var isLocalNetworkPermissionRequired: Bool {
        return error == .localNetworkPermissionRequired
    }

    private func validationErrorCodeNumber() -> Int {
        if message.contains("CLIENT_ID") || message.contains("client_id") {
            return IPificationSDKErrorCode.emptyClientId
        }
        if message.contains("REDIRECT_URI") || message.contains("redirect_uri") {
            return IPificationSDKErrorCode.emptyRedirectUri
        }
        if message.contains("login_hint") {
            return IPificationSDKErrorCode.emptyLoginHint
        }
        if message.contains("Scope") || message.contains("scope") {
            return IPificationSDKErrorCode.emptyScope
        }
        if message.contains("COVERAGE_URL") || message.contains("COVERAGE URL") || message.contains("Coverage endpoint") {
            return IPificationSDKErrorCode.emptyCoverageEndpoint
        }
        if message.contains("AUTHORIZATION_URL") || message.contains("AUTH URL") || message.contains("Auth endpoint") {
            return IPificationSDKErrorCode.emptyAuthEndpoint
        }
        if message.contains("phoneNumber") {
            return IPificationSDKErrorCode.emptyPhoneNumber
        }
        if message.contains("IM_PRIORITY_APP_LIST") {
            return IPificationSDKErrorCode.emptyIMPriorityAppList
        }
        return error.code
    }
    
   
}
