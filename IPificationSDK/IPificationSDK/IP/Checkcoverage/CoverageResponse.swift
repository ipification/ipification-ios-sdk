//
//  CoverageResponse.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//

import Foundation

/// Wraps the server response from a coverage check.
public class CoverageResponse: ResponseProtocol{
    
    /// The unmodified coverage response body.
    var res: String
    init(res : String) {
        self.res = res
    }
    /// Returns the operator code reported by the coverage service, when available.
    public func getOperatorCode() -> String?{
        let data =  Data(res.utf8)
        
        do {
            // make sure this JSON is in the format we expect
            if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                return json["operator_code"] as? String ?? nil
            }
        } catch let error as NSError {
            print("Failed to parse data : \(error.localizedDescription)")
        }
        return nil
    }
    /// Indicates whether IPification authentication is available for the request.
    public func isAvailable() -> Bool{
        let data =  Data(res.utf8)
        
        do {
            // make sure this JSON is in the format we expect
            if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                return json["available"] as? Bool ?? false
            }
        } catch let error as NSError {
            print("Failed to parse data : \(error.localizedDescription)")
        }
        return false
    }
   
    /// Returns the error message reported by the coverage service.
    public func getError() -> String {
        if let dataURL = URL(string: res) {
            let params = dataURL.params()
            if let error = params["error"] as? String, let errorDescription = params["error_description"] as? String {
                return "\(error) \(errorDescription)"
            } else {
                return params["error_description"] as? String ?? ""
            }
        }
        // 15092021 - fixed the case return error in body with errorMessage
        do {
            let data =  Data(res.utf8)
            // make sure this JSON is in the format we expect
            if let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] {
                return json["errorMessage"] as? String ?? ""
            }
        } catch let error as NSError {
            print("Failed to parse data : \(error.localizedDescription)")
        }
        return ""
    }
    
    
    /// Returns the unmodified coverage response body.
    public func getPlainResponse() -> String {
        return res
    }
    
    
    /// Returns `nil`; authorization codes do not apply to coverage responses.
    public func getCode() -> String? {
        // do nothing
        return nil
    }
    /// Returns `nil`; authorization state does not apply to coverage responses.
    public func getState() -> String? {
        // do nothing
        return nil
    }
}
