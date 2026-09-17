//
//  AuthorizationService.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//

import Foundation
import UIKit


/// Provides IP-based, SMS, and instant-messaging authorization flows.
public class AuthorizationService {
    /// The view controller used to present instant-messaging authentication UI.
    var viewController: UIViewController?
    /// Locale used by the instant-messaging authentication UI.
    public var locale: IPificationLocale = IPificationLocale.sharedInstance
    /// Theme used by the instant-messaging authentication UI.
    public var theme: IPificationTheme = IPificationTheme.sharedInstance
    
    /// Indicates whether an authorization request is currently running.
    var authRequesting = false

    
    /// Enables diagnostic log callbacks for this service instance.
    public var debug: Bool = false
    /// Whether generated carrier headers are enabled for the active request.
    private var enableCarrierHeaders: Bool = true
    /// The authorization request currently being processed.
    var authorizationRequest : AuthorizationRequest? = nil
    /// The parsed endpoint of the active authorization request.
    var endpoint: URLComponents? = nil;
    /// Indicates whether the current configuration supports an IM fallback.
    var supportIMFlow: Bool = false
    /// Indicates whether the IM fallback has already been attempted.
    var triedIMFlow: Bool = false
    /// The login hint retained for fallback authentication channels.
    private var authLoginHint: String? = nil
    
    /// Called when authorization completes successfully.
    public var callbackSuccess: ((_ response: AuthorizationResponse) -> Void)?
    /// Called when authorization fails or cannot be started.
    public var callbackFailed: ((_ response: IPificationException) -> Void)?
    /// Called when the user cancels instant-messaging authentication.
    public var callbackIMCanceled: (() -> Void)?
    /// Called with diagnostic messages when logging is enabled.
    public var callbackLog: ((_ response: String) -> Void)?
    //01102021 set redirect to not send our header
    /// Indicates whether the active request follows an authorization redirect.
    private var isRedirect = false
    
    /// The state value expected in the authorization response.
    private var currentState = ""
    private weak var multiAuthCallback: MultiAuthCallback?
    /// Bridges `SMSCallback` events to `multiAuthCallback` during SMS fallback and OTP verification.
    private var multiAuthSMSCallback: MultiAuthSMSCallback?

    private func clearCookiesIfNeeded() {
        if IPConfiguration.sharedInstance.enableCookieHandling {
            CookieManager.sharedInstance.initData()
        }
    }
    
    /**
     * Initializes the AuthorizationService.
     * Sets up IPConfiguration and CookieManager instances.
     */
    public init() {
        IPConfiguration.sharedInstance.initData()
    }
    
    @available(*, deprecated, message: "Use `startAuthentication` instead.")
    /**
     * Perform authentication.
     *
     * - Parameters:
     *   - authRequest: The AuthorizationRequest object which includes optional parameters for the request. Default is nil.
     */
    public func startAuthorization(_ authRequest : AuthorizationRequest? = nil) {
        clearCookiesIfNeeded()
        doAuthorization(authRequest, false)
    }
    
    @available(*, deprecated, message: "Use `startAuthentication` instead.")
    /**
     * Perform authentication with a view controller.
     *
     * - Parameters:
     *   - viewController: The UIViewController instance from which the IM authorization process is started.
     *   - authRequest: The AuthorizationRequest object which includes optional parameters for the request. Default is nil.
     */
    public func startAuthorization(viewController: UIViewController, _ authRequest : AuthorizationRequest? = nil) {
        self.viewController = viewController
        clearCookiesIfNeeded()
        doAuthorization(authRequest, false)
    }
    
    /**
     * Perform authentication.
     *
     * - Parameters:
     *   - authRequest: The AuthorizationRequest object which includes optional parameters for the request. Default is nil.
     */
    public func startAuthentication(_ authRequest : AuthorizationRequest? = nil) {
        clearCookiesIfNeeded()
        doAuthorization(authRequest, false)
    }
    /**
     * Perform authentication.
     *
     * - Parameters:
     *   - viewController: The UIViewController instance from which the IM authorization process is started.
     *   - authRequest: The AuthorizationRequest object which includes optional parameters for the request. Default is nil.
     */
    public func startAuthentication(viewController: UIViewController, _ authRequest : AuthorizationRequest? = nil) {
        self.viewController = viewController
        clearCookiesIfNeeded()
        doAuthorization(authRequest, false)
    }

    /// Starts authentication using the configured channel order and callback interface.
    public func startAuthentication(_ authRequest: AuthorizationRequest? = nil, callback: MultiAuthCallback) {
        self.multiAuthCallback = callback
        self.callbackSuccess = { response in
            callback.onSuccess(response: response)
        }
        self.callbackFailed = { error in
            callback.onError(error: error)
        }
        clearCookiesIfNeeded()
        startConfiguredAuthentication(authRequest)
    }

    /// Starts authentication using the configured channels and a presenting view controller.
    public func startAuthentication(viewController: UIViewController, _ authRequest: AuthorizationRequest? = nil, callback: MultiAuthCallback) {
        self.viewController = viewController
        self.multiAuthCallback = callback
        self.callbackSuccess = { response in
            callback.onSuccess(response: response)
        }
        self.callbackFailed = { error in
            callback.onError(error: error)
        }
        clearCookiesIfNeeded()
        startConfiguredAuthentication(authRequest)
    }

    /// Starts standalone SMS authentication for a phone number.
    public func startSMSAuthentication(phoneNumber: String, scope: String = "openid ip:phone_verify", callback: SMSCallback) {
        SMSServices.startVerification(phoneNumber: phoneNumber, scope: scope, callback: callback)
    }

    /// Verifies an OTP received during SMS authentication.
    public func verifySMSOTP(otpCode: String, authReqId: String, nonce: String, callback: SMSCallback) {
        SMSServices.verifyOTP(otpCode: otpCode, authReqId: authReqId, nonce: nonce, callback: callback)
    }

    /// Verifies an OTP for a flow started with `startAuthentication(_:callback:)` that fell back to SMS.
    ///
    /// The result is delivered to the `MultiAuthCallback` supplied to `startAuthentication`:
    /// `onSMSSuccess(response:)` on success, `onError(error:)` on failure.
    public func verifySMSOTP(otpCode: String, authReqId: String, nonce: String) {
        guard let callback = multiAuthCallback else {
            let error = IPificationException(IPificationError.validation, "verifySMSOTP requires a MultiAuthCallback. Start the flow with startAuthentication(_:callback:) or pass an SMSCallback explicitly.")
            callbackFailed?(error)
            return
        }
        let bridge = multiAuthSMSCallback ?? MultiAuthSMSCallback(callback: callback)
        multiAuthSMSCallback = bridge
        SMSServices.verifyOTP(otpCode: otpCode, authReqId: authReqId, nonce: nonce, callback: bridge)
    }
    /**
     * Perform IM (Instant Messaging) authentication only.
     *
     * - Parameters:
     *   - viewController: The UIViewController instance from which the IM authorization process is started.
     *   - authRequest: The AuthorizationRequest object which includes optional parameters for the request. Default is nil.
     */
    public func startIMAuthorization(viewController: UIViewController, _ authRequest : AuthorizationRequest? = nil) {
        self.viewController = viewController
        clearCookiesIfNeeded()
        doAuthorization(authRequest, true)
    }

    private func startConfiguredAuthentication(_ authRequest: AuthorizationRequest? = nil) {
        let channels = IPConfiguration.sharedInstance.AUTH_CHANNELS
        if channels.isEmpty || channels.first == .IP {
            doAuthorization(authRequest, false)
            return
        }
        if channels.first == .SMS {
            startSMSFallback(authRequest: authRequest, reason: nil)
        }
    }

    private func shouldFallbackToSMS() -> Bool {
        let channels = IPConfiguration.sharedInstance.AUTH_CHANNELS
        guard let ipIndex = channels.firstIndex(of: .IP) else { return false }
        return channels.dropFirst(ipIndex + 1).contains(.SMS)
    }

    private func startSMSFallback(authRequest: AuthorizationRequest?, reason: IPificationException?) {
        guard let callback = multiAuthCallback else {
            if let reason = reason {
                callbackFailed?(reason)
            }
            return
        }
        let phoneNumber = authRequest?.queryParams?["login_hint"] ?? authorizationRequest?.queryParams?["login_hint"] ?? authLoginHint
        guard let smsPhoneNumber = phoneNumber, smsPhoneNumber.isEmpty == false else {
            let error = IPificationException(IPificationError.validation, "login_hint cannot be empty for SMS authentication")
            callback.onError(error: error)
            return
        }
        let scope = authRequest?.scope ?? IPConfiguration.sharedInstance.SMS_SCOPE_VERIFY_PHONE
        let bridge = MultiAuthSMSCallback(callback: callback)
        multiAuthSMSCallback = bridge
        SMSServices.startVerification(phoneNumber: smsPhoneNumber, scope: scope, callback: bridge)
    }
    
    
    /**
     * Executes the authorization flow.
     * Validates configuration, builds the authorization request, and initiates either IP or IM flow based on parameters.
     *
     * - Parameters:
     *   - authRequest: The AuthorizationRequest object which includes optional parameters for the request. Default is nil.
     *   - isOnlyIM: Flag to indicate if only IM (Instant Messaging) flow should be used. Default is false.
     */
    private func doAuthorization(_ authRequest : AuthorizationRequest? = nil, _ isOnlyIM: Bool = false) {
        // validate
        if(IPConfiguration.sharedInstance.AUTHORIZATION_URL == ""){
            let error = IPificationException(IPificationError.validation, "AUTHORIZATION_URL is nil" )
            reportAuthError(error)
            callbackFailed?(error)
            return
        }
        if(IPConfiguration.sharedInstance.REDIRECT_URI == ""){
            let error = IPificationException(IPificationError.validation, "REDIRECT_URI is nil" )
            reportAuthError(error)
            callbackFailed?(error)
            return
        }
        if(IPConfiguration.sharedInstance.CLIENT_ID == ""){
            let error = IPificationException(IPificationError.validation, "CLIENT_ID is nil" )
            reportAuthError(error)
            callbackFailed?(error)
            return
        }
        
        isRedirect = false
        authLoginHint = authRequest?.queryParams?["login_hint"]
        let configuration = IPConfiguration.sharedInstance
        let builder = AuthorizationRequest.Builder()
        var isRequestParamPresent = false
        var defaultScope = configuration.DEFAULT_SCOPE
        var consentIdValue = configuration.CONSENT_ID_VALUE
        if(authRequest != nil){
            //add checking for case client use request param, not other params
            if(authRequest!.queryParams?["request"] != nil && authRequest!.queryParams?["request"] != ""){
                defaultScope = ""
                consentIdValue = ""
                isRequestParamPresent = true
            }
            
            //20210 internal issue
            var scope = authRequest?.scope ?? defaultScope
            // check only when enableParamsValidation = true
            if(IPConfiguration.sharedInstance.enableParamsValidation){
                if(isRequestParamPresent == false && IPConfiguration.sharedInstance.customUrls == false){
                    if(scope == ""){
                        let error = IPificationException(IPificationError.validation, "Scope cannot be empty")
                        reportAuthError(error)
                        callbackFailed?(error)
                        return
                    }
                    //20092021 Add validation for empty login_hint
                    if(scope == "openid" || scope.contains("ip:phone_verify") == true || scope.contains("ip:profile") == true){
                        if(authRequest!.queryParams?.isEmpty == true || authRequest!.queryParams?["login_hint"] == nil || authRequest!.queryParams?["login_hint"] == ""){
                            let error = IPificationException(IPificationError.validation, "login_hint cannot be empty when scope is ip:phone_verify or ip:profile")
                            reportAuthError(error)
                            callbackFailed?(error)
                            return
                        }
                    }
                }
            }
            
            builder.queryParams = authRequest!.queryParams
            builder.headers = authRequest!.headers
            builder.readTimeout = authRequest!.readTimeout
            builder.connectTimeout = authRequest!.connectTimeout
//            builder.dnsConnectionTimeout = authRequest!.dnsConnectionTimeout
            builder.scope = scope
            builder.state = authRequest!.state
            if(scope.contains(" ")){
                scope = scope.replacingOccurrences(of: " ", with: "+")
            }
            
            if(scope != ""){
                builder.addQueryParam(key: "scope", value: scope)
            }
            
            
            if(authRequest?.queryParams != nil){
                for param in authRequest!.queryParams!{
                    var value = param.value
                    if(value.contains(" ") == true){
                        value = value.replacingOccurrences(of: " ", with: "+")
                    }
                    builder.queryParams![param.key] = value
                }
            }
            // 10092021 internal issue
            // remove default scope value
//            else{
//                builder.addQueryParam(key: "scope", value: "openid")
//            }
            if(authRequest!.state != nil && authRequest!.state != ""){
                currentState = authRequest!.state!
                builder.addQueryParam(key: "state", value: currentState)
                IPConfiguration.sharedInstance.currentState = currentState
            }
            //remove auto generate state
            else if(IPConfiguration.sharedInstance.automaticStateGenerationEnabled == true){
                currentState = IPConfiguration.sharedInstance.generateState()
                builder.addQueryParam(key: "state", value: currentState)
                IPConfiguration.sharedInstance.currentState = currentState
            }
            
            
        }
        builder.addQueryParam(key: "client_id", value: IPConfiguration.sharedInstance.CLIENT_ID)
        
        
        if(consentIdValue != ""){
            // internal issue
            if(authRequest!.queryParams?["consent_id"] == nil || authRequest!.queryParams?["consent_id"] == "" ){
                builder.addQueryParam(key: "consent_id", value: consentIdValue)
            }
            
            if(authRequest!.queryParams?["consent_timestamp"] == nil || authRequest!.queryParams?["consent_timestamp"] == "" ){
                let unixTime = Date().currentTimeinSeconds()
                builder.addQueryParam(key: "consent_timestamp", value: "\(unixTime)")
            }
        }
        
        if(IPConfiguration.sharedInstance.RESPONSE_TYPE_VALUE != ""){
            builder.addQueryParam(key: "response_type", value: IPConfiguration.sharedInstance.RESPONSE_TYPE_VALUE)
        }
        
        builder.addQueryParam(key: "redirect_uri", value: IPConfiguration.sharedInstance.REDIRECT_URI)
        //deprecated
//        let mnc = IPHeaders.activeMNC()
//        let mcc = IPHeaders.activeMCC()
        
        //not enable if IMFlow only or Wifi only
//        print(isOnlyIM, triedIMFlow)
//        if(mcc != "" && mnc != "" && isOnlyIM == false){
//            builder.addQueryParam(key: "mnc", value: mnc)
//            builder.addQueryParam(key: "mcc", value: mcc)
//        }
        
        if(IPConfiguration.sharedInstance.IM_AUTO_MODE){
            if(IPConfiguration.sharedInstance.IM_PRIORITY_APP_LIST.isEmpty){
                let error = IPificationException(IPificationError.validation, "IM_PRIORITY_APP_LIST is empty")
                reportAuthError(error)
                callbackFailed?(error)
                return
            }
            builder.queryParams!["channel"] = IPConfiguration.sharedInstance.IM_PRIORITY_APP_LIST.joined(separator: "+")
        }

        authorizationRequest = builder.build()

        if(isOnlyIM == false ){
            supportIMFlow = authorizationRequest?.queryParams?["channel"] != nil
            let channels = authorizationRequest?.queryParams?["channel"]
            if let channels = channels, channels.contains("ip") == false {
                onLogs("[Auth Request] onlyIM Flow \(channels)")
                doIMRequest()
            } else {
                onLogs("[Auth Request] IP Flow with supportIMFlow: \(supportIMFlow)")
                doRequest()
            }
        } else {
            supportIMFlow = true
            onLogs("[Auth Request] onlyIM Flow")
            doIMRequest()
        }
    }
    
    
    /**
     * Checks the current IP address.
     * For debugging purposes only. Makes a request to Amazon's checkip service.
     */
    /// Checks the current client IP through the configured authorization endpoint.
    public func checkIPAddress() {
        isRedirect = false
        let builder = AuthorizationRequest.Builder()
        builder.endpoint = URL(string: "https://checkip.amazonaws.com/")
        authorizationRequest = builder.build()
        doRequest()
    }
    
    /**
     * Checks the IP address using a custom URL.
     * Added to sync with Android implementation for checking IP.
     *
     * - Parameter url: The URL to use for checking the IP address.
     */
    /// Checks an explicitly supplied URL as part of the IP authorization flow.
    public func checkRequestedIP(url:String) {
        isRedirect = false
        let builder = AuthorizationRequest.Builder()
        builder.endpoint = URL(string: url)
        authorizationRequest = builder.build()
        doRequest()
    }
    
    /**
     * Checks if the device is connected to 3G only (no WiFi).
     *
     * - Returns: True if only 3G is enabled and WiFi is disabled, false otherwise.
     */
    private func is3GOnly()-> Bool{
        let (is3GOn, isWifiOn, _, _) =  ConnectionManager.checkOnly3G()
        if(is3GOn == true && isWifiOn == false){
            return true
        }
        return false
    }

    private func reportAuthError(_ error: IPificationException) {
        var errorDesc = error.localizedDescription
        if (errorDesc.count > IPConfiguration.sharedInstance.MAX_LOG_LENGTH) {
            errorDesc = errorDesc.substring(str: errorDesc, start: 0, end: IPConfiguration.sharedInstance.MAX_LOG_LENGTH)
        }

        var logData = ""
        if self.currentState != "" {
            logData += "state=\(self.currentState);"
        }
        if errorDesc != "" {
            logData += "error_description=\(errorDesc);"
        }

        let phone = self.authorizationRequest?.queryParams?["login_hint"] ?? authLoginHint
        APIManager.sharedInstance.sendErrorReport(phone: phone, api: IPConfiguration.sharedInstance.AUTH_API_STR, logData: logData)
    }
    /**
     * Executes the authorization request using IP flow.
     * Validates the request, creates a network socket, and handles the response or error.
     * Falls back to IM flow if supported and IP flow fails.
     */
    func doRequest(){
        let isValid = self.validateRequest()
        if(isValid == false){
            return
        }
        
        if #available(iOS 12, *) {
            
            if(authRequesting){
                print("proccessing authentication... ignore")
                return
            }
            authRequesting = true
            self.onLogs("make request : \(authorizationRequest!.toUri().string ?? "")")
            let networkSocket = NetworkSocket(endpoint: authorizationRequest!.toUri(), cellularRequest: authorizationRequest!, enableCarrierHeaders: isRedirect ? false: IPConfiguration.sharedInstance.enableCarrierHeaders, isOnlyIM: false)
            networkSocket.queue = DispatchQueue.main
            networkSocket.callbackSuccess = { (response) -> Void in
                self.onLogs("Auth Result: success: \(response.getPlainResponse())")
                self.authRequesting = false
                if let authResponse = response as? AuthorizationResponse {
                    self.callbackSuccess?(authResponse)
                } else {
                    self.onLogs("Auth Result: error: unexpected response type \(type(of: response))")
                }
            }
            networkSocket.continueCallRequest = { (url) -> Void in
                self.authRequesting = false
//                print("networkSocket.continueCallRequest", url)
                self.handleRequest(url, isOnlyIM: false)
            }
            networkSocket.doHandleIMResponse = { (imSession) -> Void in
                self.authRequesting = false
                self.handleIMResponse(imSession: imSession)
            }
            networkSocket.callbackFailed = { (error) -> Void in
                self.authRequesting = false
                
                self.onLogs("Auth Result: error: \(error.localizedDescription)")
                if(self.supportIMFlow == true && self.triedIMFlow == false && self.is3GOnly() == false){
                    self.triedIMFlow = true
                    self.doIMRequest()
                    return
                }
                if self.shouldFallbackToSMS() {
                    self.startSMSFallback(authRequest: self.authorizationRequest, reason: error)
                    return
                }
                self.reportAuthError(error)
                self.callbackFailed?(error)
            }
            networkSocket.callbackLog = { (log) -> Void in
                self.onLogs("\(log)")
                self.callbackLog?(log)
            }
            networkSocket.performDoAuthorization()
        }
        else{
            // Get the current OS version
            let osVersion = UIDevice.current.systemVersion
            // Create the error with the OS version in the message
            let error = IPificationException(IPificationError.unsupported_version, "unsupported version (OS version: \(osVersion))")
            self.onLogs("Auth Result: error: unsupported version (OS version: \(osVersion))")
            self.callbackFailed?(error)
            self.reportAuthError(error)
        }
    }

    /// Executes the authorization request using instant messaging.
    func doIMRequest(){
        onLogs("start doIMRequest")
        guard validateRequest() else {
            return
        }

        authorizationRequest?.queryParams?.removeValue(forKey: "mnc")
        authorizationRequest?.queryParams?.removeValue(forKey: "mcc")

        if #available(iOS 12, *) {
            onLogs("doIMRequest make request : \(authorizationRequest!.toUri().string ?? "")")
            let networkSocket = NetworkSocket(
                endpoint: authorizationRequest!.toUri(),
                cellularRequest: authorizationRequest!,
                enableCarrierHeaders: isRedirect ? false : IPConfiguration.sharedInstance.enableCarrierHeaders,
                isOnlyIM: true
            )
            networkSocket.queue = DispatchQueue.main
            networkSocket.callbackSuccess = { response in
                self.onLogs("doIMRequest success: \(response.getPlainResponse())")
                if let authResponse = response as? AuthorizationResponse {
                    self.callbackSuccess?(authResponse)
                } else {
                    self.onLogs("doIMRequest error: unexpected response type \(type(of: response))")
                }
            }
            networkSocket.continueCallRequest = { url in
                self.handleRequest(url, isOnlyIM: true)
            }
            networkSocket.doHandleIMResponse = { imSession in
                self.handleIMResponse(imSession: imSession)
            }
            networkSocket.callbackFailed = { error in
                self.onLogs("doIMRequest error: \(error.localizedDescription)")
                self.reportAuthError(error)
                self.callbackFailed?(error)
            }
            networkSocket.callbackLog = { log in
                self.onLogs(log)
                self.callbackLog?(log)
            }
            networkSocket.performDoAuthorization()
        } else {
            let osVersion = UIDevice.current.systemVersion
            let error = IPificationException(IPificationError.unsupported_version, "unsupported version (OS version: \(osVersion))")
            onLogs("doIMRequest error: unsupported version (OS version: \(osVersion))")
            reportAuthError(error)
            callbackFailed?(error)
        }
    }

    /// Presents the instant-messaging authentication UI for a valid session.
    private func handleIMResponse(imSession: IMSession){
        DispatchQueue.main.async {
            if imSession.canOpen() == false && IPConfiguration.sharedInstance.validateIMApps {
                self.onLogs("handleIMResponse : There is no supported IM app in this device")
                let error = IPificationException(IPificationError.validation, "There is no supported IM app in this device")
                self.reportAuthError(error)
                self.callbackFailed?(error)
                return
            }

            guard let viewController = self.viewController else {
                let error = IPificationException(IPificationError.validation, "ViewController is nil.")
                self.reportAuthError(error)
                self.callbackFailed?(error)
                return
            }

            let ipIM = IPificationIMInstance()
            ipIM.callbackFailed = self.callbackFailed
            ipIM.callbackCanceled = self.callbackIMCanceled
            ipIM.callbackSuccess = self.callbackSuccess
            ipIM.callbackLog = self.callbackLog
            ipIM.imLocale = self.locale
            ipIM.imTheme = self.theme
            ipIM.imSession = imSession
            viewController.present(ipIM.viewControllerForLogin(), animated: true)
        }
    }
    
    
    /**
     * Handles redirect requests during the authorization flow.
     * Validates the URL and creates a new authorization request for the redirect.
     *
     * - Parameters:
     *   - url: The redirect URL to handle.
     *   - isOnlyIM: Flag to indicate if only IM flow should be used.
     */
    private func handleRequest(_ url : String?, isOnlyIM: Bool) {
        guard let redirectUrl = url, URL(string: redirectUrl) != nil else {
            let error = IPificationException(IPificationError.validation, "URL is not valid \(url ?? "")" )
            reportAuthError(error)
            callbackFailed?(error)
            return
        }
        let builder = AuthorizationRequest.Builder(url: redirectUrl)
        //set redirect to not send our header
        isRedirect = true
        
        authorizationRequest = builder.build()
//        authorizationRequest?.isEncoded = url!.isEscaped()
        authorizationRequest?.isRedirect = true
        
        if(isOnlyIM){
            doIMRequest()
        }else{
            doRequest()
        }
    }
    
    /**
     * Validates the authorization request.
     * Checks if view controller is present when needed and validates the authorization URL.
     *
     * - Returns: True if the request is valid, false otherwise.
     */
    private func validateRequest () -> Bool {
        if(supportIMFlow && viewController == nil){
            let error = IPificationException(IPificationError.validation, "ViewController is nil.")
            reportAuthError(error)
            callbackFailed?(error)
            return false
        }
        var endpoint = authorizationRequest?.parseToURLComponents()
        
        if(endpoint == nil){
            let error = IPificationException(IPificationError.validation, "AUTH URL IS NOT CORRECT")
            reportAuthError(error)
            callbackFailed?(error)
            return false
        }
        endpoint = authorizationRequest?.toUri()
        if(endpoint == nil || endpoint!.host == nil){
            let error = IPificationException(IPificationError.validation, "AUTH URL IS NOT CORRECT (002)")
            reportAuthError(error)
            callbackFailed?(error)
            return false
        }
        
        return true
    }
    
    /**
     * Logs messages when debug mode is enabled.
     *
     * - Parameter log: The log message to record.
     */
    func onLogs(_ log: String) {
        if(IPConfiguration.sharedInstance.debug){
            IPLogs.sharedInstance.append(log)
        }
    }
    
}

extension Date {
    /**
     * Converts the current date to Unix timestamp in seconds.
     *
     * - Returns: The Unix timestamp as Int64.
     */
    func currentTimeinSeconds() -> Int64 {
        return Int64(self.timeIntervalSince1970)
    }
}

private class MultiAuthSMSCallback: SMSCallback {
    private weak var callback: MultiAuthCallback?

    init(callback: MultiAuthCallback) {
        self.callback = callback
    }

    func onAuthInitiated(response: SMSAuthResponse) {
        callback?.onOTPRequired(response: response)
    }

    func onSuccess(response: SMSTokenResponse) {
        callback?.onSMSSuccess(response: response)
    }

    func onError(error: IPificationException) {
        callback?.onError(error: error)
    }
}
