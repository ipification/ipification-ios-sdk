//
//  APIManager.swift
//  IPificationSDK
//
//  Created by IPification on 1/11/2022.
//  Copyright © 2022 IPification. All rights reserved.
//

import Foundation
import UIKit

@objc class APIManager: NSObject {
   
    /// The process-wide API manager used by internal SDK services.
    public static let sharedInstance = APIManager()
       
    private override init() {
        super.init()
    }
    
    func getLogUrl() -> String{
        if IPConfiguration.sharedInstance.BASE_URL == nil {
            let url = IPConfiguration.sharedInstance.ENV == .SANDBOX ? IPConfiguration.sharedInstance.SDK_LOG_URL_STAGE :  IPConfiguration.sharedInstance.SDK_LOG_URL_LIVE;
            return url
        }
        let url = (IPConfiguration.sharedInstance.BASE_URL ?? "") + IPConfiguration.sharedInstance.SDK_LOG_PATH
        return url
    }
    
    /// Sends a diagnostic error report to the IPification SDK log endpoint.
    /// - Parameters:
    ///   - phone: The phone number (login hint) associated with the request, when available.
    ///   - api: The API being reported (`COVERAGE` or `AUTH`).
    ///   - logData: The error description payload.
    ///   - state: The OAuth state of the authorization request, when available. Sent as its own `state` field.
    func sendErrorReport(phone: String?, api: String, logData: String, state: String? = nil)
    {
        if(IPConfiguration.sharedInstance.sendErrorReportsEnabled == false){
            onLogs("disabled send log. ignored")
            // do nothing
            return
        }
        let url = getLogUrl()
        onLogs("debug url: \(url)")
        let errorType = parseType(logData: logData)

        var requestBodyComponents = URLComponents()
        var queryItems = [
            URLQueryItem(name: "log_data", value: logData),
            URLQueryItem(name: "type", value: errorType),
            URLQueryItem(name: "api", value: api),
            URLQueryItem(name: "phone", value: phone)
        ]
        if let state = state, state.isEmpty == false {
            queryItems.append(URLQueryItem(name: "state", value: state))
        }
        requestBodyComponents.queryItems = queryItems
        onLogs("debug logData: \(logData)\n")
        if let phone = phone, phone != "" {
            onLogs("debug phone: \(phone)\n")
        }
        if let state = state, state != "" {
            onLogs("debug state: \(state)\n")
        }
        
        guard let reportUrl = URL(string: url) else {
            onLogs("sendErrorReport failed invalid url: \(url)\n")
            return
        }

        var request = URLRequest(url: reportUrl)
        request.httpMethod = "POST"
        //
        request.timeoutInterval = IPConfiguration.sharedInstance.ErrorReportTimeout
        request.httpBody = requestBodyComponents.query?.data(using: .utf8)
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.addValue(IPConfiguration.sharedInstance.CLIENT_ID, forHTTPHeaderField: "IP-client-id")
        
        
        //2.1.0
        let headers = IPHeaders.generate(headers: nil, true)
        for item in headers {
            request.addValue(item.value, forHTTPHeaderField: item.key)
        }

        let session = URLSession.shared
        let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
            if(error != nil){
                print(error?.localizedDescription ?? "")
                self.onLogs("sendErrorReport failed \(error?.localizedDescription ?? "failed ")\n")
                return
            }
            if response is HTTPURLResponse {
                self.onLogs("sendErrorReport success \n")
            }
            
        })

        task.resume()
    }
    func parseType(logData: String) -> String {
        if(logData.contains("interaction_required")){
            return "INTERACTION_REQUIRED"
        }
        if(logData.contains("failed to connect")){
            return "TIMEOUT"
        }
        if(logData.contains("CELLULAR_NOT_ACTIVE")){
            return "CELLULAR_NOT_ACTIVE"
        }
        return "UNKNOWN"
    }
    
    func onLogs(_ log: String) {
        if(IPConfiguration.sharedInstance.debug){
            IPLogs.sharedInstance.append(log)
        }
    }
}
