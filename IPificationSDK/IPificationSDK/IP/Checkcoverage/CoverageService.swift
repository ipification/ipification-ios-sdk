//
//  CoverageService.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 27/3/2020.
//  Copyright © 2020 IPification Mobile. All rights reserved.
//

import Foundation
import UIKit


/// Checks whether IPification authentication is available for a device or phone number.
public class CoverageService {
    
    /// Enables diagnostic log callbacks for this service instance.
    public var debug: Bool = false

    /// The coverage request currently being processed.
    var coverageRequest: CoverageRequest? = nil

    /// Called when a coverage check completes successfully.
    public var callbackSuccess: ((_ response: CoverageResponse) -> Void)?
    /// Called when a coverage check fails or cannot be started.
    public var callbackFailed: ((_ error: IPificationException) -> Void)?
    /// Called with diagnostic messages when logging is enabled.
    public var callbackLog: ((_ response: String) -> Void)?
    /// Indicates whether a coverage request is currently running.
    var coverageRequesting = false
    
    /**
     * Initializes the CoverageService.
     * Sets up IPConfiguration and CookieManager instances.
     */
    public init() {
        
        IPConfiguration.sharedInstance.initData()
    }
    
    @available(*, deprecated, message: "Use `startCheckCoverage` instead.")
    /**
     * Check Coverage API.
     * This function will return `true` (supported) or `false` (not supported) or an error.
     *
     * - Parameter customCoverageRequest: CoverageRequest object which includes timeout and other optional parameters.
     */
    public func checkCoverage(_ customCoverageRequest : CoverageRequest? = nil){
        startCheckCoverage(customCoverageRequest)
    }
    
    /**
     *
     * Check Coverage API.
     * This function will return `true` (supported) or `false` (not supported) or an error.
     * - Parameter customCoverageRequest: CoverageRequest object which includes timeout and other optional parameters.
     */
    public func startCheckCoverage(_ customCoverageRequest : CoverageRequest? = nil){
    
        // validate
        if(IPConfiguration.sharedInstance.COVERAGE_URL == ""){
            callbackFailed?( IPificationException(IPificationError.validation, "COVERAGE_URL is nil. Please check your configuration file" ))
            return
        }
        if(IPConfiguration.sharedInstance.CLIENT_ID == ""){
            callbackFailed?( IPificationException(IPificationError.validation, "CLIENT_ID is nil. Please check your configuration file" ))
            return
        }
        
//        IPConfiguration.sharedInstance.debug = debug

        //create request
        let coverageBuilder = CoverageRequest.Builder()
        
        if(coverageRequest != nil){
            coverageBuilder.readTimeout = coverageRequest!.readTimeout
            coverageBuilder.connectTimeout = coverageRequest!.connectTimeout
//            coverageBuilder.dnsConnectionTimeout = coverageRequest!.dnsConnectionTimeout
        }
        
        // add client_id to the request parameter
        coverageBuilder.addQueryParam(key: "client_id", value: IPConfiguration.sharedInstance.CLIENT_ID)
//        let mnc = IPHeaders.activeMNC()
//        let mcc = IPHeaders.activeMCC()
//        if(mcc != "" && mnc != ""){
//            coverageBuilder.addQueryParam(key: "mnc", value: mnc)
//            coverageBuilder.addQueryParam(key: "mcc", value: mcc)
//        }
        
        self.coverageRequest = coverageBuilder.build()
        
        _doCheckCoverage(phone: nil)
    }
    
    @available(*, deprecated, message: "Use `startCheckCoverage` instead.")
    /**
     *
     * Check Coverage API.
     * This function will return `true` (supported) or `false` (not supported) or an error.
     * - Parameter customCoverageRequest: CoverageRequest object which includes timeout and other optional parameters.
     */
    public func checkCoverage(phoneNumber phone: String, _ customCoverageRequest : CoverageRequest? = nil){
        startCheckCoverage(phoneNumber: phone, customCoverageRequest)
    }
    
    /**
     *
     * Check Coverage API.
     * This function will return `true` (supported) or `false` (not supported) or an error.
     * - Parameter phone: client input phone number
     * - Parameter customCoverageRequest: CoverageRequest object which includes timeout and other optional parameters.
     */
    public func startCheckCoverage(phoneNumber phone: String, _ customCoverageRequest : CoverageRequest? = nil){
    
        // validate
        if(IPConfiguration.sharedInstance.COVERAGE_URL == ""){
            callbackFailed?( IPificationException(IPificationError.validation, "COVERAGE_URL is nil. Please check your configuration file" ))
            return
        }
        if(IPConfiguration.sharedInstance.CLIENT_ID == ""){
            callbackFailed?( IPificationException(IPificationError.validation, "CLIENT_ID is nil. Please check your configuration file" ))
            return
        }
        if(phone == ""){
            callbackFailed?( IPificationException(IPificationError.validation, "phoneNumber parameter cannot be empty" ))
            return
        }
        
//        IPConfiguration.sharedInstance.debug = debug

        //create request
        let coverageBuilder = CoverageRequest.Builder()
        
        if(coverageRequest != nil){
            coverageBuilder.readTimeout = coverageRequest!.readTimeout
            coverageBuilder.connectTimeout = coverageRequest!.connectTimeout
//            coverageBuilder.dnsConnectionTimeout = coverageRequest!.dnsConnectionTimeout
        }
        
        // add client_id to the request parameter
        coverageBuilder.addQueryParam(key: "client_id", value: IPConfiguration.sharedInstance.CLIENT_ID)
        
        // add phone to the request parameter
        coverageBuilder.addQueryParam(key: "phone", value: phone)
        
//        let mnc = IPHeaders.activeMNC()
//        let mcc = IPHeaders.activeMCC()
//        if(mcc != "" && mnc != ""){
//            coverageBuilder.addQueryParam(key: "mnc", value: mnc)
//            coverageBuilder.addQueryParam(key: "mcc", value: mcc)
//        }
        
        self.coverageRequest = coverageBuilder.build()
        
        _doCheckCoverage(phone: phone)
    }
    
    /**
     * Executes the coverage check request.
     * Validates the request, creates a network socket, and handles the response or error.
     *
     * - Parameter phone: Optional phone number for error reporting.
     */
    private func _doCheckCoverage(phone: String?){
        
        //validate request
        let isValid = self.validateRequest()
        if(isValid == false){
            return
        }
        
        if #available(iOS 12, *) {
            
            if(self.coverageRequesting){
                print("proccessing check coverage... ignore")
                return
            }
            self.onLogs("checkCoverage - make request : \(coverageRequest!.toUri().string ?? "")")
            self.coverageRequesting = true
            let networkSocket = NetworkSocket(endpoint: coverageRequest!.toUri(), cellularRequest: coverageRequest!, enableCarrierHeaders: IPConfiguration.sharedInstance.enableCarrierHeaders, isOnlyIM: false)
            networkSocket.queue = DispatchQueue.main
            networkSocket.callbackSuccess = { (response) -> Void in
                self.onLogs("checkCoverage Result: success: \(response.getPlainResponse())")
                self.coverageRequesting = false
                if let coverageResponse = response as? CoverageResponse {
                    self.callbackSuccess?(coverageResponse)
                } else {
                    self.onLogs("checkCoverage Result: error: unexpected response type \(type(of: response))")
                }
            }
            networkSocket.callbackFailed = { (error) -> Void in
                self.coverageRequesting = false
                
                var logData = ""

                var errorDesc = error.localizedDescription
                self.onLogs("checkCoverage Result: error: \(errorDesc)")
//                //limit the error message
                if (errorDesc.count > IPConfiguration.sharedInstance.MAX_LOG_LENGTH){
                    errorDesc = errorDesc.substring(str: errorDesc, start: 0, end: IPConfiguration.sharedInstance.MAX_LOG_LENGTH)
                }
                if errorDesc != ""{
                    logData += "error_description=\(errorDesc);"
                }
//                
                APIManager.sharedInstance.sendErrorReport(phone: phone, api: IPConfiguration.sharedInstance.COVERAGE_API_STR,logData: logData)
                self.callbackFailed?(error)
            }
            
            networkSocket.callbackLog = callbackLog
            networkSocket.performCheckCoverage()
        }
        else{
            // Get the current OS version
            let osVersion = UIDevice.current.systemVersion
            // Create the error with the OS version in the message
            let error = IPificationException(IPificationError.unsupported_version, "unsupported version (OS version: \(osVersion))")
            self.callbackFailed?(error)
            self.onLogs("error: unsupported version (OS version: \(osVersion)")
            let logData = "error_description=unsupported version (OS version: \(osVersion));"
            APIManager.sharedInstance.sendErrorReport(phone: phone, api: IPConfiguration.sharedInstance.COVERAGE_API_STR, logData: logData)

        }
    }

    /**
     * Validates the coverage request.
     * Checks if the coverage URL is properly formatted and contains required components.
     *
     * - Returns: True if the request is valid, false otherwise.
     */
    private func validateRequest () -> Bool {
        var coverageEndpoint = coverageRequest?.parseToURLComponents()
        if(coverageEndpoint == nil){
            callbackFailed?( IPificationException(IPificationError.validation, "COVERAGE URL IS NOT CORRECT (001)"))
            return false
        }
        coverageEndpoint = coverageRequest?.toUri()
        if(coverageEndpoint == nil || coverageEndpoint?.host == nil){
            callbackFailed?( IPificationException(IPificationError.validation, "COVERAGE URL IS NOT CORRECT (002)"))
            return false
        }
        onLogs("coverage endpoint: \(coverageEndpoint?.string ?? "")")
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
