//
//  NetworkSocket.swift
//
//  Created by IPification on 10/12/20.
//  Copyright © 2020 IPification. All rights reserved.
//

import Foundation
import Network
import NetworkExtension

@available(iOS 12.0, *)
@available(iOSApplicationExtension 12.0, macOS 10.14 ,*)
internal class NetworkSocket: RawSocketProtocol {
    /// Completes the socket operation with an instant-messaging session.
    func handleIMResponse(_ imSession: IMSession) {
        onLogs(String(format: "[Auth Request] handle IM Response with sessionID: %@", imSession.sessionID ?? " "))
        guard completeOnce() else {
            return
        }
        doHandleIMResponse?(imSession)
    }
    /// The host name used by the active network connection.
    var host = ""
    /// The TCP port used by the active network connection.
    var port:UInt16 = 443
    /// Indicates whether the socket has received response data.
    var receivedData: Bool = false
    /// Indicates whether the connection is ready to send a request.
    var isConnectReady : Bool? = nil
    /// Indicates whether the socket is waiting for local-network permission.
    private var isWaitingForLocalNetworkPermission = false
    /// Indicates whether local-network permission may be blocking the connection.
    private var isPossibleLocalNetworkPermissionRequired = false
    /// Indicates whether a local-network permission timeout has been scheduled.
    private var localNetworkPermissionTimeoutScheduled = false
    /// The maximum number of retries after a connection reset.
    private let maxConnectionResetRetries = 1
    /// The maximum number of retries after a request timeout.
    private let maxRequestTimeoutRetries = 1
    /// The number of connection-reset retries already attempted.
    private var connectionResetRetryCount = 0
    /// The number of request-timeout retries already attempted.
    private var requestTimeoutRetryCount = 0
    /// The read timeout used by the current request attempt.
    private var currentReadTimeout: TimeInterval = 0
    /// Indicates whether the socket is currently retrying the request.
    var isRetryingRequest = false
    
    /// The parsed endpoint for the active request.
    var endpoint: URLComponents? = nil;
    /// The request associated with the active socket operation.
    var cellularRequest: RequestProtocol? = nil
    /// Whether generated carrier headers are included in the request.
    private var enableCarrierHeaders: Bool = true
    /// Indicates whether the request belongs to an instant-messaging flow.
    private var isIMFlow = false
    /// Indicates whether a terminal callback has already been delivered.
    private var didComplete = false
    /// The response bytes accumulated from the socket.
    var mData = Data()

    /// The number of response bytes processed during the previous read.
    var previousByteLengh = 0

    /// Called when the transport receives a valid SDK response.
    public var callbackSuccess: ((_ response: ResponseProtocol) -> Void)?
    /// Called when the transport fails or receives an invalid response.
    public var callbackFailed: ((_ response: IPificationException) -> Void)?
    /// Called when the authentication flow must continue at another URL.
    public var continueCallRequest: ((_ url: String) -> Void)?
    /// Called with transport diagnostic messages.
    public var callbackLog: ((_ response: String) -> Void)?
    public var doHandleIMResponse: ((_ imSession: IMSession) -> Void)?
    /**
     * Initializes the NetworkSocket.
     *
     * - Parameters:
     *   - endpoint: The URLComponents representing the target endpoint.
     *   - cellularRequest: The request protocol object containing request parameters.
     *   - enableCarrierHeaders: Flag to enable or disable carrier headers.
     *   - isOnlyIM: Flag indicating if this is an IM-only flow.
     */
    init(endpoint : URLComponents, cellularRequest: RequestProtocol, enableCarrierHeaders: Bool , isOnlyIM: Bool) {
        self.endpoint = endpoint
        self.cellularRequest = cellularRequest
        self.enableCarrierHeaders = enableCarrierHeaders
        self.delegate = NetworkDelegate(endpoint: endpoint, cellularRequest: cellularRequest, cellularCallback: self, enableCarrierHeaders: self.enableCarrierHeaders)
        self.isIMFlow = isOnlyIM
    }
    
    /**
     * Continues the request with a new URL.
     * Handles URL encoding if necessary and invokes the continue callback.
     *
     * - Parameter url: The URL string to continue the request with.
     */
    public func continueRequest(_ url: String) {
        guard completeOnce() else {
            return
        }
        onLogs("continue request \(url)")
        onLogs("--------")
        var covertedUrl = url
        if(url.isEscaped() == false){
            onLogs("url is not encoded. ...")
            covertedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        }
        
        onLogs(String(format: "make request to url: %@", covertedUrl))
        continueCallRequest?(covertedUrl)
    }
    
    /**
     * Handles successful response.
     * Invokes the success callback with the response.
     *
     * - Parameter response: The response protocol object containing the response data.
     */
    func onSuccess(response: ResponseProtocol) {
        guard completeOnce() else {
            return
        }
        callbackSuccess?(response)
    }
    
    /**
     * Handles error response.
     * Logs the error and invokes the failure callback.
     *
     * - Parameter error: The IPificationException containing error details.
     */
    func onError(error: IPificationException) {
        onLogs("network error: \(error.localizedDescription)")
        guard completeOnce() else {
            return
        }
        callbackFailed?(error)
    }

    func completeOnce() -> Bool {
        if didComplete {
            return false
        }
        didComplete = true
        return true
    }
    
    /**
     * Logs messages when debug mode is enabled.
     * Invokes the log callback if debugging is enabled in configuration.
     *
     * - Parameter log: The log message to record.
     */
    func onLogs(_ log: String) {
        if(IPConfiguration.sharedInstance.debug){
            callbackLog?(log)
        }
    }
    
    /// The delegate that formats requests and interprets socket responses.
    var delegate: NetworkDelegate?
    
    /**
     * Forces disconnection of the network connection.
     *
     * - Parameter sessionID: The session ID to disconnect.
     */
    func forceDisconnect(_ sessionID: UInt32) {
        onLogs("forcing network disconnection")
        if connection != nil && connection.state != .cancelled {
            connection.cancel()
        }
    }
    /// The active Network framework connection.
    var connection:NWConnection!
    /// The serial queue used for network connection events.
    var queue: DispatchQueue!
   
    
    /**
     * Performs the authorization request.
     * Initiates the network request for authorization.
     */
    func performDoAuthorization() {
        //check celullar enable / disable
        self.performRequest()
    }
    
    
    /**
     * Performs the coverage check request.
     * Initiates the network request for coverage checking.
     */
    func performCheckCoverage() {
        //check celullar enable / disable
        self.performRequest()
    }
    
    /**
     * Performs the network request.
     * Extracts host and port from endpoint and initiates connection.
     */
    internal func performRequest(){
        didComplete = false
        connectionResetRetryCount = 0
        requestTimeoutRetryCount = 0
        currentReadTimeout = cellularRequest!.readTimeout
        
        host = endpoint!.host!
        let p = endpoint!.port ?? (endpoint!.scheme == "http" ? 80 : 443)
        port = UInt16(p)
        let requiredInterface = isIMFlow ? "default" : "cellular"
        onLogs("network force start host=\(host) port=\(port) tls=\(endpoint!.scheme == "https") interface=\(requiredInterface)")
        logResolvedIPsIfDebug(host: host)
        do{
            try connectTo(host, port: port, enableTLS: endpoint!.scheme == "https", tlsSettings: nil)
        }catch{
            onLogs("network force failed to start host=\(host) error=\(error.localizedDescription)")
            self.delegate?.didDisconnect(socket: self, error: error)
        }
        
    }
        
    /**
     * Establishes a network connection to the specified host and port.
     * Configures TLS, TCP options, and cellular interface requirements.
     *
     * - Parameters:
     *   - host: The host name or IP address to connect to.
     *   - port: The port number to connect to.
     *   - enableTLS: Flag to enable TLS encryption.
     *   - tlsSettings: Optional TLS settings dictionary.
     * - Throws: Error if connection setup fails.
     */
    func connectTo(_ host: String, port: UInt16, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) throws {
        receivedData = false
        mData = Data()
        previousByteLengh = 0
        isWaitingForLocalNetworkPermission = false
        localNetworkPermissionTimeoutScheduled = false
        let p =  NWEndpoint.Port.init(rawValue: port)
        let h = NWEndpoint.Host.init(host)
        let options = NWProtocolTLS.Options()
        
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = Int(cellularRequest!.connectTimeout / 1000)
        tcpOptions.noDelay = true

//        tcpOptions.enableKeepalive = true
//        tcpOptions.keepaliveIdle = 10
//        tcpOptions.keepaliveCount = 10
//        tcpOptions.keepaliveInterval = 10
        
        let params = NWParameters(tls: enableTLS ? options : nil, tcp: tcpOptions)
        
        if(!isIMFlow){
            params.requiredInterfaceType = .cellular
        }
        onLogs("network force config host=\(host) port=\(port) connectTimeout=\(tcpOptions.connectionTimeout)s requiredInterface=\(!isIMFlow ? "cellular" : "default")")
        
        self.connection =  NWConnection.init(host:  h  , port: p!, using: params)
        
        
        connection.stateUpdateHandler = { (newState) in
//            print("TCP state change to: \(newState)")

            switch newState {
            case .ready:
                self.onLogs("network force state ready host=\(host)")
                self.isConnectReady = true
                self.isWaitingForLocalNetworkPermission = false
                self.isPossibleLocalNetworkPermissionRequired = false
                self.delegate?.didConnect(socket: self)
                
                break
            case .waiting(let error):
                self.onLogs("network force state waiting host=\(host) error=\(error.debugDescription)")
                if let unsatisfiedReason = self.currentPathUnsatisfiedReasonDescription() {
                    self.onLogs("network force path unsatisfiedReason host=\(host) reason=\(unsatisfiedReason)")
                }
                self.isConnectReady = false
                let isLocalNetworkPermissionDenied = self.isLocalNetworkPermissionDenied()
                let shouldWaitForPossibleLocalNetworkPermission = self.shouldWaitForPossibleLocalNetworkPermission(error, host: host)
                self.onLogs("network force Local Network permission check host=\(host) isLocalNetworkPermissionDenied=\(isLocalNetworkPermissionDenied) isPossibleLocalNetworkPermissionRequired=\(shouldWaitForPossibleLocalNetworkPermission)")
                if isLocalNetworkPermissionDenied || shouldWaitForPossibleLocalNetworkPermission {
                    self.isConnectReady = nil
                    self.isWaitingForLocalNetworkPermission = true
                    self.isPossibleLocalNetworkPermissionRequired = shouldWaitForPossibleLocalNetworkPermission
                    self.onLogs("network force waiting for Local Network permission host=\(host)")
                    self.scheduleLocalNetworkPermissionTimeout(host: host)
                    break
                }
                self.isWaitingForLocalNetworkPermission = false
                self.isPossibleLocalNetworkPermissionRequired = false
                if error == .posix(POSIXErrorCode.ENETDOWN) && self.receivedData == false {
                    self.onLogs("network is unavailable")
                    self.receivedData = true
                    self.delegate?.errorNetwork(error.debugDescription)
                    self.disconnect(becauseOf: error)
                } else if self.retryAfterConnectionResetIfNeeded(error, host: host, port: port, enableTLS: enableTLS, tlsSettings: tlsSettings) == false {
                    self.delegate?.didDisconnect(socket: self, error: self.connectionFailureMessage(for: error, host: host, port: port))
                    self.disconnect(becauseOf: error)
                }
                break
            
            case .failed(let error):
                self.isConnectReady = false
                self.isWaitingForLocalNetworkPermission = false
                self.isPossibleLocalNetworkPermissionRequired = false
                self.onLogs("network force state failed host=\(host) error=\(error.debugDescription)")
                if self.retryAfterConnectionResetIfNeeded(error, host: host, port: port, enableTLS: enableTLS, tlsSettings: tlsSettings) == false {
                    self.delegate?.didDisconnect(socket: self, error: self.connectionFailureMessage(for: error, host: host, port: port))
                    self.disconnect(becauseOf: error)
                }
                break
            case .cancelled:
                self.isConnectReady = false
                self.isWaitingForLocalNetworkPermission = false
                self.isPossibleLocalNetworkPermissionRequired = false
                self.onLogs("network force state cancelled host=\(host)")
                break
            case .setup:
                self.onLogs("network force state setup host=\(host)")
                break
            case .preparing:
                self.onLogs("network force state preparing host=\(host)")
                DispatchQueue.main.asyncAfter(deadline: .now() + self.currentReadTimeout / 1000) {
                    if(self.isConnectReady == nil){
                        if self.isWaitingForLocalNetworkPermission {
                            self.onLogs("network force timeout skipped while waiting for Local Network permission host=\(host)")
                            return
                        }
                        self.isConnectReady = false
                        self.onLogs("network force timeout host=\(host) after=\(self.currentReadTimeout / 1000)s")
                        self.delegate?.didDisconnect(socket: self, error: self.connectionTimeoutMessage(host: host, port: port))
                        self.stop()
                    }
                }
                break
            default:
                self.onLogs("network force state changed host=\(host)")
                break
            }
        }
        
        connection.start(queue: queue)
        
    }

    private func isLocalNetworkPermissionDenied() -> Bool {
        guard #available(iOS 14.2, macOS 11.0, *) else {
            return false
        }
        return connection.currentPath?.unsatisfiedReason == .localNetworkDenied
    }

    private func currentPathUnsatisfiedReasonDescription() -> String? {
        guard #available(iOS 14.2, macOS 11.0, *) else {
            return nil
        }
        guard let reason = connection.currentPath?.unsatisfiedReason else {
            return nil
        }
        return "\(reason)"
    }

    private func shouldWaitForPossibleLocalNetworkPermission(_ error: NWError, host: String) -> Bool {
        guard #available(iOS 14.2, macOS 11.0, *) else {
            return false
        }

        guard error == .posix(POSIXErrorCode.ENETDOWN), connection.currentPath?.unsatisfiedReason == .notAvailable else {
            return false
        }

        let (_, isWifiOn, _, wifiIPv4, _, wifiIPv6) = ConnectionManager.checkNetworkInterfaces()
        guard isWifiOn else {
            return false
        }

        let ips = resolvedIPs(for: host)
        let wifiIPs = [wifiIPv4, wifiIPv6].compactMap { $0 }
        let isSamePrivateRangeAsWifi = ips.contains { resolvedIP in
            wifiIPs.contains { wifiIP in
                isSamePrivateIPRange(resolvedIP, wifiIP)
            }
        }
        if isSamePrivateRangeAsWifi {
            onLogs("network force possible Local Network permission host=\(host) reason=notAvailable ips=\(ips.joined(separator: ",")) wifiIps=\(wifiIPs.joined(separator: ","))")
        }
        return isSamePrivateRangeAsWifi
    }

    private func scheduleLocalNetworkPermissionTimeout(host: String) {
        if localNetworkPermissionTimeoutScheduled {
            return
        }
        localNetworkPermissionTimeoutScheduled = true
        let configuration = IPConfiguration.sharedInstance
        let isFirstLocalNetworkPermissionPrompt = configuration.hasSeenLocalNetworkPermissionPrompt == false
        configuration.markLocalNetworkPermissionPromptSeen()
        let timeout = (isFirstLocalNetworkPermissionPrompt ? configuration.LocalNetworkPermissionFirstPromptTimeout : configuration.LocalNetworkPermissionTimeout) / 1000
        self.onLogs("network force Local Network permission timeout scheduled host=\(host) firstPrompt=\(isFirstLocalNetworkPermissionPrompt) timeout=\(timeout)s")
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
            guard self.isWaitingForLocalNetworkPermission else {
                return
            }
            guard self.isLocalNetworkPermissionDenied() || self.isPossibleLocalNetworkPermissionRequired else {
                self.isWaitingForLocalNetworkPermission = false
                self.isPossibleLocalNetworkPermissionRequired = false
                self.onLogs("network force Local Network permission timeout skipped because permission is no longer required host=\(host)")
                return
            }
            let graceTimeout = configuration.LocalNetworkPermissionGraceTimeout / 1000
            self.onLogs("network force Local Network permission still required host=\(host), grace=\(graceTimeout)s")
            DispatchQueue.main.asyncAfter(deadline: .now() + graceTimeout) {
                guard self.isWaitingForLocalNetworkPermission else {
                    return
                }
                guard self.isLocalNetworkPermissionDenied() || self.isPossibleLocalNetworkPermissionRequired else {
                    self.isWaitingForLocalNetworkPermission = false
                    self.isPossibleLocalNetworkPermissionRequired = false
                    self.onLogs("network force Local Network permission grace skipped because permission is no longer required host=\(host)")
                    return
                }
                self.isWaitingForLocalNetworkPermission = false
                self.isPossibleLocalNetworkPermissionRequired = false
                self.onLogs("network force Local Network permission timeout host=\(host) after=\(timeout + graceTimeout)s")
                self.delegate?.didDisconnect(socket: self, error: self.localNetworkPermissionRequiredMessage(host: host))
                self.disconnect(becauseOf: nil)
            }
        }
    }

    private func localNetworkPermissionRequiredMessage(host: String) -> String {
        let url = endpoint?.url?.absoluteString ?? host
        return "Failed to connect to \(url) - Local Network permission required"
    }

    private func connectionFailureMessage(for error: NWError, host: String, port: UInt16) -> String {
        if error == .posix(POSIXErrorCode.ETIMEDOUT) {
            return "\(connectionTimeoutMessage(host: host, port: port)) (Operation timed out)"
        }
        return "Failed to connect to \(host):\(port) - \(error.localizedDescription)"
    }

    private func retryAfterConnectionResetIfNeeded(_ error: NWError, host: String, port: UInt16, enableTLS: Bool, tlsSettings: [NSObject : AnyObject]?) -> Bool {
        guard error == .posix(POSIXErrorCode.ECONNRESET), receivedData == false, connectionResetRetryCount < maxConnectionResetRetries else {
            return false
        }

        connectionResetRetryCount += 1
        onLogs("network force retry host=\(host) reason=connection_reset attempt=\(connectionResetRetryCount)/\(maxConnectionResetRetries)")
        currentReadTimeout = 5000
        isRetryingRequest = true
        if connection != nil && connection.state != .cancelled {
            connection.cancel()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try self.connectTo(host, port: port, enableTLS: enableTLS, tlsSettings: tlsSettings)
                self.isRetryingRequest = false
            } catch {
                self.isRetryingRequest = false
                self.onLogs("network force retry failed to start host=\(host) error=\(error.localizedDescription)")
                self.delegate?.didDisconnect(socket: self, error: error)
            }
        }
        return true
    }

    func retryAfterRequestTimeoutIfNeeded() -> Bool {
        guard receivedData == false, requestTimeoutRetryCount < maxRequestTimeoutRetries else {
            return false
        }

        requestTimeoutRetryCount += 1
        onLogs("network force retry host=\(host) reason=request_timeout attempt=\(requestTimeoutRetryCount)/\(maxRequestTimeoutRetries)")
        currentReadTimeout = 5000
        isRetryingRequest = true
        if connection != nil && connection.state != .cancelled {
            connection.cancel()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                guard let endpoint = self.endpoint else {
                    self.isRetryingRequest = false
                    self.delegate?.didDisconnect(socket: self, error: "Cannot retry request: endpoint is nil")
                    return
                }
                try self.connectTo(self.host, port: self.port, enableTLS: endpoint.scheme == "https", tlsSettings: nil)
                self.isRetryingRequest = false
            } catch {
                self.isRetryingRequest = false
                self.onLogs("network force retry failed to start host=\(self.host) error=\(error.localizedDescription)")
                self.delegate?.didDisconnect(socket: self, error: error)
            }
        }
        return true
    }

    func readTimeoutForCurrentAttempt() -> TimeInterval {
        return currentReadTimeout > 0 ? currentReadTimeout : cellularRequest!.readTimeout
    }

    private func connectionTimeoutMessage(host: String, port: UInt16) -> String {
        return "Failed to connect to \(host):\(port) - Timeout after \(cellularRequest!.connectTimeout / 1000)s"
    }
    
    /**
     * Disconnects the network connection due to an error.
     * Cancels the connection if it's not already cancelled.
     *
     * - Parameter error: Optional error that caused the disconnection.
     */
    func disconnect(becauseOf error: Error?) {
        onLogs("network force disconnect host=\(host) error=\(error?.localizedDescription ?? "")")
        if connection != nil && connection.state != .cancelled {
            connection.cancel()
        }
    }
    
    /**
     * Forces disconnection of the network connection due to an error.
     * Cancels the connection if it's not already cancelled.
     *
     * - Parameter error: Optional error that caused the forced disconnection.
     */
    func forceDisconnect(becauseOf error: Error?) {
        onLogs("forcing network disconnection: \(error?.localizedDescription ?? "unknown error")")
        if connection != nil && connection.state != .cancelled {
            connection.cancel()
        }
    }
    
    /**
     * Writes data to the network connection.
     * Sends data and notifies delegate on completion or error.
     *
     * - Parameters:
     *   - data: The data to write to the connection.
     *   - withTag: Tag identifier for this write operation.
     */
    func writeData(_ data: Data, withTag: Int) {
        onLogs("writing request data")
        connection.send(content: data, completion: .contentProcessed({[weak self] (sendError) in
            guard let self = self else {return}
            guard let delegate = self.delegate else {return}
            if let sendError = sendError {
                self.onLogs("failed to write request data: \(sendError.localizedDescription)")
                self.connection.cancel()
                delegate.didDisconnect(socket: self, error: sendError)
            }else {
                self.onLogs("request data written")
                delegate.didWriteData(data, withTag: withTag, from: self)
            }
        }))
    }
    /**
     * Stops the network connection.
     * Cancels the active connection.
     */
    func stop() {
        self.connection.cancel()
//        NSLog("did stop")
    }

    /**
     * Reads data from the network connection.
     * Receives data in chunks and notifies delegate when complete.
     *
     * - Parameter tag: Tag identifier for this read operation.
     */
    func readDataWithTag(_ tag: Int) {
        self.onLogs("readDataWithTag")
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) {(data, contentContext, isComplete, error) in
            self.onLogs("received...")
            var datalength = 0
            if let error = error {
                self.onLogs("error - \(error.localizedDescription)\n")
                // Handle error in reading
                self.connection.cancel()
                self.delegate?.didDisconnect(socket: self, error: error)

                return
            } else {
                if let d = data {
                    datalength = d.count
                    self.mData.append(d)
//                    self.delegate?.receivedData = true
//                    print(isComplete)
//                    print("isFinal: \(contentContext?.isFinal)")
//                    print(datalength)
                    self.onLogs("Data received: \(datalength) bytes, previous: \(self.previousByteLengh), isComplete: \(isComplete), isFinal: \(contentContext?.isFinal ?? false)")

                    if (IPConfiguration.sharedInstance.debug){
                        let str = String(decoding: d, as: UTF8.self)
                        self.onLogs("Data package received: \(str)")
                    }
                    
                    if datalength < self.previousByteLengh || datalength < 4096 {
//                        NSLog("did receive, EOF")
                        self.delegate?.didReadData(self.mData, withTag: tag, sock: self)
                        self.stop()
                        return
                    }
                    self.previousByteLengh = datalength
                    self.readDataWithTag(tag)
                }

            }
        }
    }
    
    /**
     * Reads data up to a specified length.
     *
     * - Parameters:
     *   - length: The maximum length of data to read.
     *   - tag: Tag identifier for this read operation.
     */
    func readDataToLength(_ length: Int, withTag tag: Int) {
//        print("readDataToLength", length)
    }
    
    /**
     * Reads data until a specific data pattern is found.
     *
     * - Parameters:
     *   - data: The data pattern to read until.
     *   - tag: Tag identifier for this read operation.
     */
    func readDataToData(_ data: Data, withTag tag: Int) {
        onLogs("reading data until delimiter")
    }
    
    /**
     * Reads data until a specific data pattern is found, with a maximum length.
     *
     * - Parameters:
     *   - data: The data pattern to read until.
     *   - tag: Tag identifier for this read operation.
     *   - maxLength: Maximum length of data to read.
     */
    func readDataToData(_ data: Data, withTag tag: Int, maxLength: Int) {
//        print("readDataToData", maxLength)
    }
    /**
     * Deinitializes the NetworkSocket.
     * Cancels the connection if still active.
     */
    deinit {
        if connection != nil && connection.state != .cancelled {
            connection.cancel()
        }
    }

    private func logResolvedIPsIfDebug(host: String) {
        guard IPConfiguration.sharedInstance.debug else {
            return
        }

        let ips = resolvedIPs(for: host)
        onLogs("network force resolved host=\(host) ips=\(ips.joined(separator: ","))")
    }

    private func resolvedIPs(for host: String) -> [String] {
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var result: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(host, nil, &hints, &result)
        guard status == 0, let firstResult = result else {
            return ["getaddrinfo failed: \(String(cString: gai_strerror(status)))"]
        }

        defer {
            freeaddrinfo(firstResult)
        }

        var ips: [String] = []
        var pointer: UnsafeMutablePointer<addrinfo>? = firstResult

        while let currentPointer = pointer {
            let addressInfo = currentPointer.pointee
            if let address = addressInfo.ai_addr {
                var hostBuffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                let nameInfoStatus = getnameinfo(
                    address,
                    addressInfo.ai_addrlen,
                    &hostBuffer,
                    socklen_t(hostBuffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )

                if nameInfoStatus == 0 {
                    ips.append(String(cString: hostBuffer))
                }
            }

            pointer = addressInfo.ai_next
        }

        return Array(Set(ips)).sorted()
    }

    private func isPrivateIPAddress(_ ipAddress: String) -> Bool {
        if ipAddress.hasPrefix("10.") || ipAddress.hasPrefix("192.168.") || ipAddress.hasPrefix("169.254.") {
            return true
        }

        let ipv4Parts = ipAddress.split(separator: ".").compactMap { Int($0) }
        if ipv4Parts.count == 4 && ipv4Parts[0] == 172 && (16...31).contains(ipv4Parts[1]) {
            return true
        }

        let lowercasedIPAddress = ipAddress.lowercased()
        return lowercasedIPAddress.hasPrefix("fc") || lowercasedIPAddress.hasPrefix("fd") || lowercasedIPAddress.hasPrefix("fe80:")
    }

    private func isSamePrivateIPRange(_ firstIPAddress: String, _ secondIPAddress: String) -> Bool {
        let firstParts = firstIPAddress.split(separator: ".").compactMap { Int($0) }
        let secondParts = secondIPAddress.split(separator: ".").compactMap { Int($0) }
        guard firstParts.count == 4, secondParts.count == 4 else {
            return false
        }

        if firstParts[0] == 10, secondParts[0] == 10 {
            return true
        }
        return false
    }
    
}
extension String {
    /**
     * Checks if the string is URL encoded.
     *
     * - Returns: True if the string is percent-encoded, false otherwise.
     */
    func isEscaped() -> Bool {
        return self.removingPercentEncoding != self
    }
}
