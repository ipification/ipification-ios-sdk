//
//  AuthorizationResponse.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//

import Foundation

/// Wraps the redirect response returned by an authorization request.
public class AuthorizationResponse : ResponseProtocol{
    
    /// The unmodified authorization redirect response.
    var res: String
    init(res : String) {
        self.res = res
    }
    /// Returns the unmodified redirect URL received from the authorization server.
    public func getPlainResponse() ->String{
        return self.res
    }
    /// Returns the authorization code from the redirect URL, when present.
    public func getCode() -> String?{
        let dataURL =  URL(string: res)
        if(dataURL != nil && dataURL?.params() != nil ){
            return dataURL?.params()["code"] as? String
        }
        return nil
    }
    /// Returns the state value from the redirect URL, when present.
    public func getState() -> String?{
        let dataURL =  URL(string: res)
        if(dataURL != nil && dataURL?.params() != nil ){
            return dataURL?.params()["state"] as? String
        }
        return nil
    }
    /// Returns a human-readable error assembled from the redirect response.
    public func getError() -> String{
        if let dataURL = URL(string: res) {
            let params = dataURL.params()
            if let error = params["error"] as? String, let errorDescription = params["error_description"] as? String {
                return "\(error) \(errorDescription)"
            } else {
                return params["error_description"] as? String ?? res
            }
        }
        return "Failed to parse data : " + res
    }
    
    /// Returns the OAuth error code from the redirect response.
    public func getErrorCode() -> String? {
        guard let dataURL = URL(string: res) else {
            return nil
        }
        let params = dataURL.params()
        return params["error"] as? String
    }
    
    /// Returns the OAuth error description from the redirect response.
    public func getErrorDescription() -> String? {
        guard let dataURL = URL(string: res) else {
            return nil
        }
        let params = dataURL.params()
        return params["error_description"] as? String
    }
    
    /// Returns `false`; availability applies only to coverage responses.
    public func isAvailable() -> Bool {
        return false
    }
    
}
