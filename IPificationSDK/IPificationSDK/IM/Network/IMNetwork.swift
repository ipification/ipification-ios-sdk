//
//  IMNetwork.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 16/12/2021.
//  Copyright © 2021 IPification Dev Team. All rights reserved.
//

import Foundation
import UIKit

@objc class IMNetwork: NSObject {
    
    /// The process-wide network client for instant-messaging authentication.
    public static let sharedInstance = IMNetwork()
    
    /// Indicates whether redirect processing should stop after a terminal response.
    private var stopCheck302 = false
    
    private override init() {
        super.init()
    }
    func completeSession(imSession: IMSession, completion: @escaping(AuthorizationResponse?, IPificationException?) -> (Void))
        {
            stopCheck302 = false
            
//            print(String(format: "%@/%@", imSession.imboxEndpoint!, imSession.sessionID!))
            guard let imboxEndpoint = imSession.imboxEndpoint, let sessionID = imSession.sessionID, let url = URL(string: String(format: "%@/%@", imboxEndpoint, sessionID)) else {
                let error = IPificationException(IPificationError.authorized_failed, "completeSession - invalid session url")
                completion(nil, error)
                return
            }
            let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
            let loadDataTask = session.dataTask(with: url) { (data, response, error) in
                if let err = error {
                    print("error is \(err.localizedDescription)")
                    let error = IPificationException(IPificationError.authorized_failed, "completeSession - error \(err.localizedDescription)");
                    completion(nil, error)
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    let resUrl = (httpResponse.allHeaderFields["Location"] ?? httpResponse.allHeaderFields["location"]) as? String
                    if(statusCode > 300 && statusCode < 399 && resUrl != nil){
                        let response = AuthorizationResponse(res: resUrl ?? "")
                        if(response.getCode() != nil){
                            completion(response, nil)
                        }else{
                            let error = IPificationException(IPificationError.authorized_failed, "completeSession error - \(response.getPlainResponse()) - \(response.getError())");
                            completion(response, error)
                        }
                    }else{
                        completion(nil, self.sessionStatusError(from: data, prefix: "completeSession"))
                       
                    }
                    
                }else{
                    completion(nil, self.sessionStatusError(from: data, prefix: "completeSession"))
                  
                }
                
            }
            loadDataTask.resume()
        }
    
    func getRedirectLink(url: String, completion: @escaping(String?, IPificationException?) -> (Void))
        {
            stopCheck302 = true
            guard let url = URL(string: String(format: "%@", url)) else {
                let error = IPificationException(IPificationError.authorized_failed, "invalid redirect url")
                completion(nil, error)
                return
            }
            let session = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
            let loadDataTask = session.dataTask(with: url) { (data, response, error) in
                if let err = error {
                    print("error is \(err.localizedDescription)")
                    let error = IPificationException(IPificationError.authorized_failed, err.localizedDescription);
                    completion(nil, error)
                    return
                }
                if let httpResponse = response as? HTTPURLResponse {
                    let statusCode = httpResponse.statusCode
                    let resUrl = (httpResponse.allHeaderFields["Location"] ?? httpResponse.allHeaderFields["location"]) as? String

//                    print(statusCode,resUrl)
                    if(statusCode > 300 && statusCode < 399 || statusCode == 200){
                        completion(resUrl, nil)
                    }else{
                        let error = IPificationException(IPificationError.authorized_failed, "error with code: \(statusCode)");
                        completion(nil, error)
                    }
                    
                }else{
                    let error = IPificationException(IPificationError.authorized_failed, "");
                    completion(nil, error)
                }
                
            }
            loadDataTask.resume()
        }

    private func sessionStatusError(from data: Data?, prefix: String) -> IPificationException {
        guard let data = data else {
            return IPificationException(IPificationError.authorized_failed, "\(prefix) - empty response")
        }

        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any], let sessionStatus = json["session_status"] as? String {
                return IPificationException(IPificationError.authorized_failed, sessionStatus)
            }
        } catch {
            let body = String(decoding: data, as: UTF8.self)
            return IPificationException(IPificationError.authorized_failed, "\(prefix) - \(body) -  \(error.localizedDescription)")
        }

        let body = String(decoding: data, as: UTF8.self)
        return IPificationException(IPificationError.authorized_failed, "\(prefix) - \(body)")
    }
    
    
}
extension IMNetwork: URLSessionDelegate, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        // Stops the redirection, and returns (internally) the response body.
//        print(request.url!.absoluteString)
        if(request.url?.absoluteString.starts(with: IPConfiguration.sharedInstance.REDIRECT_URI) == true || stopCheck302){
            completionHandler(nil)
        }else{
            completionHandler(request)
        }
       
    }
}
