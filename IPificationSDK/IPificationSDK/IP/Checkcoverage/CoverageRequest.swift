//
//  CoverageRequest.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//
import Foundation

/// Defines the endpoint, parameters, headers, and timeouts for a coverage check.
public class CoverageRequest : RequestProtocol {
    /// The maximum time to wait for coverage response data, in milliseconds.
    public var readTimeout: TimeInterval = IPConfiguration.sharedInstance.CoverageReadTimeout
    /// The maximum time to wait for the coverage connection, in milliseconds.
    public var connectTimeout: TimeInterval = IPConfiguration.sharedInstance.CoverageConnectTimeout
//    public var dnsConnectionTimeout : TimeInterval = IPConfiguration.sharedInstance.CoverageConnectTimeout
//    public var isIPv4PreferredOverIPv6 : Bool = true
    
    /// The coverage endpoint URL.
    internal var endpoint: URL?
    /// The query parameters appended to the coverage endpoint.
    internal var queryParams: [String: String]? = nil
    /// The HTTP headers included in the coverage request.
    internal var headers: [String: String]? = nil
    
//    public var isEncoded: Bool = false
    
    /// Indicates whether this request follows a redirect returned by the backend.
    public var isRedirect: Bool = false

    public init(endpoint: URL?, queryParams: [String: String]?, headers: [String: String]?, connectTimeout: TimeInterval, 
                readTimeout: TimeInterval){
        self.endpoint = endpoint
        self.queryParams = queryParams
        self.headers = headers
        self.connectTimeout = connectTimeout
        self.readTimeout = readTimeout
//        self.dnsConnectionTimeout = dnsConnectionTimeout
    }

    /// Builds a `CoverageRequest` with optional headers and query parameters.
    public class Builder {
        
        public init() {
            self.endpoint = URL(string: IPConfiguration.sharedInstance.COVERAGE_URL)
        }
        /// The coverage endpoint being configured.
        var endpoint: URL? = nil
        /// The query parameters collected by the builder.
        var queryParams: [String: String]? = nil
        /// The HTTP headers collected by the builder.
        var headers: [String: String]? = nil
        
        /// The response timeout configured by the builder, in milliseconds.
        var readTimeout: TimeInterval = IPConfiguration.sharedInstance.CoverageReadTimeout
        /// The connection timeout configured by the builder, in milliseconds.
        var connectTimeout: TimeInterval = IPConfiguration.sharedInstance.CoverageConnectTimeout
//        var isIPv4PreferredOverIPv6 : Bool = true
//        internal var dnsConnectionTimeout : TimeInterval = IPConfiguration.sharedInstance.CoverageConnectTimeout
        
        /// Adds or replaces an HTTP header.
        public func addHeader(key: String, value :String){
            if(self.headers == nil){
                self.headers =  [String: String]()
            }
            self.headers![key] = value
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
        /// Creates a coverage request from the current builder values.
        public func build() -> CoverageRequest {
            return CoverageRequest(
                endpoint: endpoint,
                queryParams: queryParams,
                headers: headers,
                connectTimeout: connectTimeout,
                readTimeout: readTimeout
//                dnsConnectionTimeout: connectTimeout
            )
        }
        
    }
    /// Returns URL components containing the normalized coverage query parameters.
    public func toUri() -> URLComponents{
        var url = parseToURLComponents()! as URLComponents
        var query = [URLQueryItem]()
        if(queryParams != nil){
            for item in queryParams! {
                if(item.key == "phone"){
                    //01102021 remove + and trail space for phone
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
