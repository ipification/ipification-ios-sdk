//
//  NetworkDelegate.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 3/6/2021.
//  Copyright © 2021 IPification Mobile. All rights reserved.
//

import Foundation

@available(iOS 12.0, *)
class NetworkDelegate{
    
    /// The endpoint currently handled by the network delegate.
    var endpoint: URLComponents;
    /// Whether generated carrier headers are included in the request.
    var enableCarrierHeaders: Bool = true
    /// The HTTP GET request template used by the socket transport.
    let requestStrFrmt =  "GET %@ HTTP/1.1\r\n%@%@Host: %@\r\n\r\n";
    /// The request whose URL, headers, and timeouts are being processed.
    var cellularRequest : RequestProtocol
    
    /// Indicates whether response data has been received.
    var receivedData: Bool? = nil
    /// Indicates whether the current operation failed at the network layer.
    var isNetworkError = false
    /// The callback that receives transport results.
    var cellularCallback: CallbackProtocol
    
    /// The host associated with the active request.
    var currentHost = ""
    
    init(endpoint: URLComponents,
        cellularRequest: RequestProtocol,
        cellularCallback: CallbackProtocol,
        enableCarrierHeaders: Bool) {
        self.endpoint = endpoint
        self.cellularRequest = cellularRequest
        self.cellularCallback = cellularCallback
        self.enableCarrierHeaders = enableCarrierHeaders
    }
    
    
    /// Handles a successful connection from the SDK socket transport.
    public func didConnect(socket: NetworkSocket){
        onLogs("socket connected")
        let requestURL = cellularRequest.toUri()
        currentHost = requestURL.host ?? endpoint.host!
//        onLogs(log: "socket - didConnectToHost")
        var path = requestURL.percentEncodedPath
        if(path == "") {
            path = "/"
        }
        onLogs("request path: \(path)")
        let query = requestURL.percentEncodedQuery != nil ? "?" + requestURL.percentEncodedQuery! : ""
        onLogs("request query: \(query)")
        onLogs("new path: " + path)
        onLogs("new query: " + query)
        
        let cookies = loadCookies(host: currentHost, path: path)//"Cookie: theme=light; authToken=Fb2#fhyYxa7@ed;\r\n"
        let body =  String(format: requestStrFrmt, path + query , cellularRequest.formatedHeaders(enableCarrierHeaders: enableCarrierHeaders),
                           cookies, currentHost);
        onLogs(String(format: "[Auth Request] request body : %@", body))
        
        socket.writeData(body.data(using: .utf8)!, withTag: 1)
        socket.readDataWithTag(1)
        

        let readTimeout = socket.readTimeoutForCurrentAttempt()
        DispatchQueue.main.asyncAfter(deadline: .now() + readTimeout / 1000) {
            if(self.receivedData == nil && self.isNetworkError == false){
                if socket.retryAfterRequestTimeoutIfNeeded() {
                    return
                }
                self.receivedData = false
                let error = IPificationException(IPificationError.cannot_connect, "Failed to connect to \(self.endpoint.url?.absoluteString ?? "") - Timeout \(readTimeout/1000)");
                self.cellularCallback.onError(error: error)
                socket.connection.cancel()
            }
        }

    }
    
   
    
    /// Handles a socket disconnection reported with a system error.
    public func didDisconnect(socket sock: NetworkSocket, error err: Error?) {
        print("disconnecct" , err?.localizedDescription ?? "error")
        if sock.isRetryingRequest {
            return
        }
        if(receivedData == nil && isNetworkError == false){
            receivedData = false
            let error = IPificationException(IPificationError.cannot_connect, err?.localizedDescription ?? "Cannot connect to server");
            cellularCallback.onError(error: error)
        }
        
    }
    /// Handles a socket disconnection reported with a textual transport error.
    public func didDisconnect(socket sock: NetworkSocket, error err: String?) {
        if sock.isRetryingRequest {
            return
        }
        
        if(receivedData == nil && isNetworkError == false){
            receivedData = false
            let error = IPificationException(networkErrorCode(for: err), err ?? "Cannot connect to server");
            cellularCallback.onError(error: error)
        }
        
    }

    private func networkErrorCode(for message: String?) -> IPificationError {
        if message?.contains("Local Network permission required") == true {
            return .localNetworkPermissionRequired
        }
        return .cannot_connect
    }
    
    func didReadData(_ data: Data, withTag: Int, sock: NetworkSocket){
        onLogs("[didReadData] received response")
        let str = String(decoding: data, as: UTF8.self)
//        print(str)
        var array = str.components(separatedBy: "\r\n\r\n")
        
        
        receivedData = true
        var result = array.count > 1 ? array[1] : ""
        
        if(cellularRequest is CoverageRequest){
            let cellularResponse = CoverageResponse(res: result)
            onLogs(String(format: "-- response Data:\n%@\n--", str))
            // 15092021
            // fix issue not available in success case
            if(cellularResponse.getPlainResponse().contains("available") == true){
                cellularCallback.onSuccess(response: cellularResponse)
            } else {
                let error = IPificationException(IPificationError.check_coverage_failed, cellularResponse.getPlainResponse());
                cellularCallback.onError(error: error)
            }
        }else{
           
            onLogs(String(format: "-- response Data:\n%@\n", str))

            if((str.contains("Location") || str.contains("location")) && str.contains("200 OK") == false){
               array = str.components(separatedBy: "\r\n")
                for data in array{
                    if let header = parseHeaderLine(data), header.name.caseInsensitiveCompare("Location") == .orderedSame {
                        result = header.value
                        onLogs(String(format: "-- response url:%@\n", result))
                        break
                    }
                }
            }
            if(IPConfiguration.sharedInstance.enableCookieHandling && (str.contains("set-cookie") || str.contains("Set-Cookie"))){
                onLogs("processing response cookies")
               array = str.components(separatedBy: "\r\n")
                for data in array{
                    if let header = parseHeaderLine(data), header.name.caseInsensitiveCompare("Set-Cookie") == .orderedSame {
                        saveCookie(rawCookie: header.value)
                    }
                }
            }
            var isIMExist = false
            let imSession = IMSession()
            if(str.contains("imbox_session_id")){
                isIMExist = true
                array = str.components(separatedBy: "\r\n")
                for data in array{
                    guard let header = parseHeaderLine(data) else {
                        continue
                    }
                    if(header.name.caseInsensitiveCompare("imbox_session_id") == .orderedSame){
                        imSession.sessionID = header.value
                        onLogs("sessionID \(imSession.sessionID ?? "")")
                    }
                    if(header.name.caseInsensitiveCompare("viber_link") == .orderedSame){
                        imSession.viberLink = header.value
                    }
                    if(header.name.caseInsensitiveCompare("telegram_link") == .orderedSame){
                        imSession.telegramLink = header.value
                    }
                    if(header.name.caseInsensitiveCompare("wa_link") == .orderedSame){
                        imSession.whatsappLink = header.value
                    }
                    if(header.name.caseInsensitiveCompare("imbox_endpoint") == .orderedSame){
                        imSession.imboxEndpoint = header.value
                    }
                }
            }
//            print("result",result, str)
            var cellularResponse = AuthorizationResponse(res: result)
            if(isIMExist && imSession.isValid()){
                cellularCallback.handleIMResponse(imSession)
                return
            }
            //debug
//            print(cellularResponse.getPlainResponse())
            if(cellularResponse.getPlainResponse().starts(with: "http") && cellularResponse.getPlainResponse().starts(with: IPConfiguration.sharedInstance.REDIRECT_URI) != true){
                cellularCallback.continueRequest(cellularResponse.getPlainResponse())
                return
            }
//            print(cellularResponse.getPlainResponse())
            if(cellularResponse.getPlainResponse().starts(with: "/")){
                var components = URLComponents()
                components.scheme = endpoint.scheme
                components.host = endpoint.host
                components.path = cellularResponse.getPlainResponse()
//                print(cellularResponse.getPlainResponse())
                var newRq = components.url!.absoluteString
                if(cellularResponse.getPlainResponse().isEscaped() == false){
                    newRq = newRq.removingPercentEncoding ?? newRq
                }
                onLogs(String(format: "-- url encoded: %d\n", cellularResponse.getPlainResponse().isEscaped()))
                onLogs(String(format: "-- newRq :%@\n", newRq))
                cellularCallback.continueRequest(newRq)
                return
            }

            if(cellularResponse.getCode() == nil || cellularResponse.getCode() == ""){
                onLogs("authorization response does not contain a code")
                if(result.isEmpty){
                    let array = str.components(separatedBy: "\r\n")
                    if(array.count > 1){
                        let res = array[0].replacingOccurrences(of:"HTTP/1.1", with: "")
                        cellularResponse = AuthorizationResponse(res: res)
                    }else{
                        cellularResponse = AuthorizationResponse(res: str)
                    }
                }
                let error = IPificationException(IPificationError.authorized_failed, cellularResponse.getError(), errorCode: cellularResponse.getErrorCode(), errorDescription: cellularResponse.getErrorDescription(), rawResponse: cellularResponse.getPlainResponse());
                onLogs(String(format: "error! return full response: %@", str))
                onLogs("failed to parse authorization response")
                cellularCallback.onError(error: error)
                return 
            }
            cellularCallback.onSuccess(response: cellularResponse)
        }
    }
    
    
    func didWriteData(_ data: Data?, withTag: Int, from: NetworkSocket){
        onLogs("request data written")
    }
    private func parseHeaderLine(_ line: String) -> (name: String, value: String)? {
        guard let separatorIndex = line.firstIndex(of: ":") else {
            return nil
        }

        let name = line[..<separatorIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let valueStart = line.index(after: separatorIndex)
        let value = line[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)

        guard name.isEmpty == false else {
            return nil
        }

        return (name, value)
    }
    func errorNetwork(_ error: String){
        isNetworkError = true
        cellularCallback.onError(error: IPificationException(IPificationError.notActive, "CELLULAR_NOT_ACTIVE (\(error))"))
    }

    private func headerValue(from headerLine: String) -> String? {
        guard let separatorRange = headerLine.range(of: ":") else {
            onLogs("Invalid header: \(headerLine)")
            return nil
        }

        return String(headerLine[separatorRange.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
    
    //01102021
    //add support coookies
    func saveCookie(rawCookie: String){
//        onLogs("start save cookie \(rawCookie)")
        let rawCookieParams = rawCookie.components(separatedBy: ";");
        let rawCookieNameAndValue = rawCookieParams[0].split(separator: "=", maxSplits: 1);
        if (rawCookieNameAndValue.count != 2) {
//            onLogs("Invalid cookie: missing name and value.");
            return
        }
//
        let cookieName = rawCookieNameAndValue[0].trimmingCharacters(in: .whitespaces);
        let cookieValue = rawCookieNameAndValue[1].trimmingCharacters(in: .whitespaces);
        
        var isSecure = "FALSE"
        var domain = currentHost
        var path = "/"
        var httpOnly = false
        var expiresDate: Date? = nil
        
        for i in 0..<rawCookieParams.count {
            let rawCookieParamNameAndValue = rawCookieParams[i].split(separator: "=", maxSplits: 1);
            
            let paramName = rawCookieParamNameAndValue[0].trimmingCharacters(in: .whitespaces);
            
            if (paramName == "Secure" || paramName == "secure") {
                isSecure = "TRUE"
            }
            else if (paramName == "HttpOnly") {
                httpOnly = true
            }
            else {
                if (rawCookieParamNameAndValue.count != 2) {
                    
//                    onLogs("Invalid cookie: attribute not a flag or missing value. \(rawCookieParamNameAndValue)");
                    
                }else{
                    let paramValue = rawCookieParamNameAndValue[1].trimmingCharacters(in: .whitespaces);
                    if (paramName.caseInsensitiveCompare("expires") == .orderedSame) {
                        expiresDate = parseCookieDate(paramValue)
                    } else if (paramName.caseInsensitiveCompare("max-age") == .orderedSame ) {
                        if let maxAge = TimeInterval(paramValue) {
                            expiresDate = Date(timeIntervalSinceNow: maxAge)
                        }
                    } else if (paramName.caseInsensitiveCompare("domain") == .orderedSame ) {
                        domain = normalizedCookieDomain(paramValue)
                    } else if (paramName.caseInsensitiveCompare("path") == .orderedSame ) {
                        path = paramValue
                    }
                }

                
            }
            
        }
        let cookie = saveCookie(name: cookieName, value: cookieValue, domain: normalizedCookieDomain(domain), path: path, isSecure: isSecure, httpOnly: httpOnly, expiresDate: expiresDate)
        if let cookie = cookie {
//            onLogs("--- savedCookie \(cookie?.name) \(cookie?.domain)")
            CookieManager.sharedInstance.append(cookie: cookie)
        }
    }
    
    func saveCookie(name: String, value: String, domain: String, path: String, isSecure: String, httpOnly: Bool, expiresDate: Date?) -> HTTPCookie?{
//        onLogs("--- saveCookie \(name) \(value) \(domain) \(path) \(isSecure) \(httpOnly)")
//        if(httpOnly == false){
//            return nil
//        }
        var cookieProps: [HTTPCookiePropertyKey : Any] = [
            HTTPCookiePropertyKey.name: name,
            HTTPCookiePropertyKey.value: value,
            HTTPCookiePropertyKey.domain: domain,
            HTTPCookiePropertyKey.path: path
        ]
        if let expiresDate = expiresDate {
            cookieProps[HTTPCookiePropertyKey.expires] = expiresDate
        }
        if(isSecure == "TRUE"){
            cookieProps[HTTPCookiePropertyKey.secure] = isSecure
        }

        let cookie = HTTPCookie(properties: cookieProps)
        return cookie
    }
    
    func loadCookies(host : String, path : String) -> String{
        var result = "Cookie: "
        onLogs("loadCookies: \(host) \(path)")
        let cookies = CookieManager.sharedInstance.getCookies()
        var isExist = false
        for cookie in cookies {
//            print(cookie.domain, cookie.path, cookie.isSecure, cookie.isHTTPOnly, host, path)
//            onLogs("cookie: \(cookie.domain) \(cookie.path)")
            let domainMatches = cookieDomainMatches(host: host, cookieDomain: cookie.domain)
            let pathMatches = path.starts(with: cookie.path)
            onLogs("cookie domain match: \(domainMatches) - path match: \(pathMatches)")
            if(domainMatches && pathMatches){
//                var tempPath = ""
//                var tempSecure = ""
//                var tempHttpOnly = ""
//                if(cookie.path != "/"){
//                    tempPath = " Path=\(cookie.path);"
//                }
//                if(cookie.isSecure){
//                    tempSecure = " Secure;"
//                }
//                if(cookie.isHTTPOnly){
//                    tempHttpOnly = " HttpOnly;"
//                }
                
                result += "\(cookie.name)=\(cookie.value); "
                isExist = true
            }
        }
        result += "\r\n"
        if(isExist == false){
            result = ""
        }
        onLogs("loadCookies - result: \(result)")
        return result
    }
    func onLogs(_ log: String) {
        if(IPConfiguration.sharedInstance.debug){
            cellularCallback.onLogs(log)
        }
    }

    private func normalizedCookieDomain(_ domain: String) -> String {
        let trimmedDomain = domain.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmedDomain.hasPrefix(".") {
            return String(trimmedDomain.dropFirst())
        }
        return trimmedDomain
    }

    private func cookieDomainMatches(host: String, cookieDomain: String) -> Bool {
        let normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedDomain = normalizedCookieDomain(cookieDomain)

        return normalizedHost == normalizedDomain || normalizedHost.hasSuffix("." + normalizedDomain)
    }

    private func parseCookieDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "EEE, dd-MMM-yyyy HH:mm:ss zzz"
        ]

        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }
}
