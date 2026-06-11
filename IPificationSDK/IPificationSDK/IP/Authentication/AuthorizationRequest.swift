//
//  AuthorizationRequest.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//
import Foundation

/// Defines the endpoint, parameters, headers, and timeouts for authorization.
public class AuthorizationRequest : RequestProtocol{
    /// The maximum time to wait for authorization response data, in milliseconds.
    public var readTimeout: TimeInterval = IPConfiguration.sharedInstance.AuthReadTimeout
    /// The maximum time to wait for the authorization connection, in milliseconds.
    public var connectTimeout: TimeInterval = IPConfiguration.sharedInstance.AuthConnectTimeout
//    public var dnsConnectionTimeout : TimeInterval = IPConfiguration.sharedInstance.AuthConnectTimeout
//    public var isIPv4PreferredOverIPv6 : Bool = true
    
    //11042022
    // fix bug encoded url
//    public var isEncoded : Bool = false
    /// Indicates whether this request follows a redirect returned by the backend.
    public var isRedirect : Bool = false
    
    /// The authorization endpoint URL.
    internal var endpoint: URL?
    /// The query parameters appended to the authorization endpoint.
    internal var queryParams: [String: String]? = nil
    /// The HTTP headers included in the authorization request.
    internal var headers: [String: String]? = nil
    
    /// The OAuth scope requested by this authorization operation.
    internal var scope : String?
    /// The OAuth state value used to correlate the response.
    internal var state : String?
    public init() {
    }
    public init(endpoint: URL) {
        self.endpoint = endpoint
    }

    public init(endpoint: URL?, queryParams: [String: String]?, headers: [String: String]?,
                connectTimeout: TimeInterval, readTimeout: TimeInterval, 
//                isIPv4PreferredOverIPv6: Bool,
//                dnsConnectionTimeout : TimeInterval, 
                scope: String?, state: String? ){
        self.endpoint = endpoint
        self.queryParams = queryParams
        self.headers = headers
        self.connectTimeout = connectTimeout
        self.readTimeout = readTimeout
//        self.isIPv4PreferredOverIPv6 = isIPv4PreferredOverIPv6
//        self.dnsConnectionTimeout = dnsConnectionTimeout
        self.scope = scope
        self.state = state
    }

    /// Builds an `AuthorizationRequest` with optional headers and query parameters.
    public class Builder {
        public init(){
            self.endpoint = URL(string: IPConfiguration.sharedInstance.AUTHORIZATION_URL)
        }
        public init(url : String){
            self.endpoint = URL(string: url)
        }
        /// The authorization endpoint being configured.
        var endpoint: URL? = nil
        /// The query parameters collected by the builder.
        var queryParams: [String: String]? = nil
        /// The HTTP headers collected by the builder.
        var headers: [String: String]? = nil
        
        /// The response timeout configured by the builder, in milliseconds.
        var readTimeout: TimeInterval = IPConfiguration.sharedInstance.AuthReadTimeout
        /// The connection timeout configured by the builder, in milliseconds.
        var connectTimeout: TimeInterval = IPConfiguration.sharedInstance.AuthConnectTimeout
//        var isIPv4PreferredOverIPv6 : Bool = true
        /// The OAuth scope configured by the builder.
        internal var scope : String?
        /// The OAuth state value configured by the builder.
        internal var state : String?
        
//        internal var dnsConnectionTimeout : TimeInterval = IPConfiguration.sharedInstance.AuthConnectTimeout
        
        /// Adds or replaces an HTTP header.
        public func addHeader(key: String, value :String){
            if(self.headers == nil){
                self.headers =  [String: String]()
            }
            self.headers![key] = value
        }
        /// Sets the OAuth scope for the request.
        public func setScope(value: String){
            self.scope = value
        }
        /// Sets the OAuth state value for the request.
        public func setState(value: String){
            self.state = value
        }
        /// Adds or replaces a URL query parameter.
        public func addQueryParam(key: String, value :String){
            if(self.queryParams == nil){
                self.queryParams =  [String: String]()
            }
            self.queryParams![key] = value
        }
        
        /// Sets the connection timeout, in milliseconds.
        public func setConnectTimeout(value :TimeInterval){
            connectTimeout = value
        }
        /// Sets the response timeout, in milliseconds.
        public func setReadTimeout(value : TimeInterval){
            readTimeout = value
        }
//        public func setIPv4OverIPv6(value : Bool){
//            isIPv4PreferredOverIPv6 = value
//        }
        /// Creates an authorization request from the current builder values.
        public func build() -> AuthorizationRequest {
            return AuthorizationRequest(
                endpoint: endpoint,
                queryParams: queryParams,
                headers: headers,
                connectTimeout: connectTimeout,
                readTimeout: readTimeout,
//                isIPv4PreferredOverIPv6: isIPv4PreferredOverIPv6,
//                dnsConnectionTimeout: connectTimeout,
                scope: scope,
                state: state
                
            )
        }
    }

    /// Returns URL components containing the normalized request query parameters.
    public func toUri() -> URLComponents {
        guard var url = parseToURLComponents() else {
            print("Failed to parse URL components, returning empty URLComponents")
            return URLComponents()
        }
        var query = [URLQueryItem]()
        if(queryParams != nil){
            for item in queryParams! {
                if(item.key == "login_hint"){
                    //01102021 remove + and trail space for login_hint
                    var newValue = item.value
                    newValue = newValue.replacingOccurrences(of: "+", with: "")
                    newValue = newValue.replacingOccurrences(of: " ", with: "")
                    query.append(URLQueryItem(name: item.key, value: newValue))
                }else{
                    query.append(URLQueryItem(name: item.key, value: item.value.trimmingTrailingSpaces))
                }
                
            }
            url.queryItems = query
        }
        
        return url
    }
    /// Converts the configured endpoint into URL components.
    public func parseToURLComponents() -> URLComponents?{
        guard let endpointURL = self.endpoint else {
            return nil
        }
        let endpoint = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)
        return endpoint
    }
    /// Returns the request headers formatted for the underlying socket transport.
    /// - Parameter enableCarrierHeaders: Whether SDK-generated carrier headers are included.
    public func formatedHeaders(enableCarrierHeaders: Bool) ->String{
        if(headers == nil || headers?.count == 0){
            headers = [String: String]()
        }
//        headers!["charset"] = "utf-8"
//        if(headers!["Accept"]  == nil){
//            headers!["Accept"] = "*/*"
//        }
        
        headers = IPHeaders.generate(headers: headers!, enableCarrierHeaders)
        
        var result = ""
        for item in headers! {
            result += item.key + ": " + item.value + "\r\n"
        }
        return result
    }
}

extension String {
    /// A copy of the string with trailing whitespace and newlines removed.
    var trimmingTrailingSpaces: String {
        if let range = rangeOfCharacter(from: .whitespacesAndNewlines, options: [.anchored, .backwards]) {
            return String(self[..<range.lowerBound]).trimmingTrailingSpaces
        }
        return self
    }
}
