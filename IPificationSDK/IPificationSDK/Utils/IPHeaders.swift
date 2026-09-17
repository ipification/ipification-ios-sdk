//
//  IPHeaders.swift
//  IPificationSDK
//
//  Created by IPification Mobile on 12/5/2021.
//  Copyright © 2021 IPification Mobile. All rights reserved.
//

import Foundation
import UIKit
import CoreTelephony


struct IPHeaders {
    
    /// Header key for the device platform type.
    static let DEVICE_TYPE = "device-type"
    /// Header key for the device model name.
    static let DEVICE_NAME = "device-name"
    /// Header key for the IPification SDK version.
    static let IP_SDK_VERSION = "ip-sdk-version"
    /// Header key for the operating-system version.
    static let OS_VERSION = "os-version"
    /// Header key for the operating-system SDK identifier.
    static let OS_SDK = "os-sdk"
    /// Header key for the SDK implementation type.
    static let SDK_TYPE = "sdk-type"
    /// Header key for the host app bundle identifier.
    static let APP_PACKAGE = "app-package"
    /// Header key for the host app marketing version (CFBundleShortVersionString).
    static let APP_VERSION = "app-version"
    /// Header key for the host app build number (CFBundleVersion).
    static let APP_BUILD = "app-build"
    /// Header key reporting whether the SDK sends error reports (`on` / `off`).
    static let ERROR_REPORT = "error-report"
    
    /// Header key indicating whether the device supports dual SIM.
    static let DUAL_SIM_PHONE = "dual-sim-phone"
    /// Header key for the SIM currently providing mobile data.
    static let ACTIVE_DATA_SESSION_SIM = "active-data-session-sim"
    /// Header key for the most recently active data SIM.
    static let LAST_ACTIVE_DATA_SESSION_SIM = "last-active-data-session-sim"
    /// Header key for the first SIM mobile country code.
    static let MCC1 = "mcc-1"
    /// Header key for the first SIM mobile network code.
    static let MNC1 = "mnc-1"
    /// Header key for errors reading the first SIM network code.
    static let MNC1_ERROR_MSG = "mnc-1-error-msg"
    /// Header key for the second SIM mobile country code.
    static let MCC2 = "mcc-2"
    /// Header key for the second SIM mobile network code.
    static let MNC2 = "mnc-2"
    /// Header key for errors reading the second SIM network code.
    static let MNC2_ERROR_MSG = "mnc-2-error-msg"
    /// Header key indicating whether Wi-Fi is active.
    static let IS_WIFI_ON = "wifi"
    
    /// Header key for the active mobile country code.
    static let ACTIVE_MCC = "active-mcc"
    /// Header key for the active mobile network code.
    static let ACTIVE_MNC = "active-mnc"
    /// Header key for the device's cellular IP address.
    static let PRIVATE_IP = "private-ip"
    /// Header key for the device's Wi-Fi IP address.
    static let WIFI_IP = "wifi-ip"
    /// Header key for the active carrier country name.
    static let ACTIVE_COUNTRY_NAME = "active-country-name"
    /// Header key for the active carrier name.
    static let ACTIVE_OPERATOR_NAME = "active-operator-name"
    /// Header key for the first SIM country name.
    static let SIM1_COUNTRY_NAME = "sim1-country-name"
    /// Header key for the first SIM operator name.
    static let SIM1_OPERATOR_NAME = "sim1-operator-name"
    /// Header key for the second SIM country name.
    static let SIM2_COUNTRY_NAME = "sim2-country-name"
    /// Header key for the second SIM operator name.
    static let SIM2_OPERATOR_NAME = "sim2-operator-name"
    
    public static func generate(headers current: [String: String]?, _ enableCarrierHeaders: Bool) -> [String: String]{
        var headers = [String: String]()
        if(current != nil){
            headers = current!
        }
        
        if(enableCarrierHeaders){
            //01102021: fixed sending header in all requests
            headers[DEVICE_TYPE] = "ios"
            headers[DEVICE_NAME] = UIDevice.deviceModelName
            headers[OS_VERSION] = UIDevice.current.systemVersion
            headers[IP_SDK_VERSION] = IPConfiguration.sharedInstance.SDK_TYPE_VALUE + "-" + IPConfiguration.sharedInstance.CURRENT_VERSION
            // host app package info
            if let appPackage = hostAppPackage() {
                headers[APP_PACKAGE] = appPackage
            }
            if let appVersion = hostAppVersion() {
                headers[APP_VERSION] = appVersion
            }
            if let appBuild = hostAppBuild() {
                headers[APP_BUILD] = appBuild
            }
            // whether this client will send error reports to the SDK log endpoint
            headers[ERROR_REPORT] = IPConfiguration.sharedInstance.sendErrorReportsEnabled ? "on" : "off"
            let (_, isWifiOn, cellularIPv4, wifiIPv4, cellularIPv6, wifiIPv6) = ConnectionManager.checkNetworkInterfaces()
            headers[IS_WIFI_ON] = (isWifiOn == true ? "yes" : "no")
            let privateIP: String
            if let cellularIPv4 = cellularIPv4, let cellularIPv6 = cellularIPv6 {
                privateIP = "\(cellularIPv4)|\(cellularIPv6)"
            } else {
                privateIP = cellularIPv4 ?? cellularIPv6 ?? ""
            }
            headers[PRIVATE_IP] = privateIP
            if isWifiOn {
                if let wifiIPv4 = wifiIPv4, let wifiIPv6 = wifiIPv6 {
                    headers[WIFI_IP] = "\(wifiIPv4)|\(wifiIPv6)"
                } else {
                    headers[WIFI_IP] = wifiIPv4 ?? wifiIPv6 ?? ""
                }
            }
            // disable adding carrier information
//            if #available(iOS 12.0, *){
//                let os = ProcessInfo.processInfo.operatingSystemVersion
//                let is16OrNewer = ProcessInfo.processInfo.isOperatingSystemAtLeast(
//                    OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 0)
//                )
//                if is16OrNewer {
//                    headers[DUAL_SIM_PHONE] = "ua"
//                    return headers
//                }
// 
//                let info: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()
//                if let carriers = info.serviceSubscriberCellularProviders{
//                    if(carriers.count == 1){
//                        // 1 sim
//                        let carrier: CTCarrier? = carriers.first?.value
//                        if(carrier != nil){
//                            // add carrier header info
//                            headers[DUAL_SIM_PHONE] = "no"
//                            headers[MCC1] = checkValidMCC(mcc: carrier!.mobileCountryCode)
//                            headers[MNC1] = checkValidMNC(mnc: carrier!.mobileNetworkCode)
//                            
//                            headers[SIM1_COUNTRY_NAME] = IsoCountryCodes.find(key: carrier!.isoCountryCode ?? "" )?.name ?? carrier!.isoCountryCode
//                            headers[SIM1_OPERATOR_NAME] = checkValidMCN(mcn: carrier!.carrierName)
//                            
//                            //fix bug #16
//                            headers[ACTIVE_DATA_SESSION_SIM] = String(format: "%@%@", carrier!.mobileCountryCode ?? "", carrier!.mobileNetworkCode ?? "")
//                            headers[ACTIVE_COUNTRY_NAME] = IsoCountryCodes.find(key: carrier!.isoCountryCode ?? "" )?.name ?? carrier!.isoCountryCode
//                            headers[ACTIVE_OPERATOR_NAME] = checkValidMCN(mcn: carrier!.carrierName)
//                        }
//                    }
//                    else if(carriers.count > 1){
//                        headers[DUAL_SIM_PHONE] = "yes"
//                        var index = 0
//                        for (_ , carrier) in info.serviceSubscriberCellularProviders ?? [:] {
//                            if(index == 0){
//                                headers[MCC1] = checkValidMCC(mcc: carrier.mobileCountryCode)
//                                headers[MNC1] = checkValidMNC(mnc: carrier.mobileNetworkCode)
//                                headers[SIM1_COUNTRY_NAME] = IsoCountryCodes.find(key: carrier.isoCountryCode ?? "" )?.name ?? carrier.isoCountryCode ?? ""
//                                headers[SIM1_OPERATOR_NAME] = checkValidMCN(mcn: carrier.carrierName)
//                            }
//                            if(index == 1){
//                                headers[MCC2] = checkValidMCC(mcc: carrier.mobileCountryCode)
//                                headers[MNC2] = checkValidMNC(mnc: carrier.mobileNetworkCode)
//                                headers[SIM2_COUNTRY_NAME] = IsoCountryCodes.find(key: carrier.isoCountryCode ?? "" )?.name ?? carrier.isoCountryCode ?? ""
//                                headers[SIM2_OPERATOR_NAME] = checkValidMCN(mcn: carrier.carrierName)
//                            }
//                            index += 1
//                        }
//                        
//                        if #available(iOS 13.0, *) {
//                            let dataServiceIdentifier = info.dataServiceIdentifier
//                            if(dataServiceIdentifier != nil && info.serviceSubscriberCellularProviders != nil && info.serviceSubscriberCellularProviders?.index(forKey: dataServiceIdentifier!) != nil){
//                                let currentProvider  = info.serviceSubscriberCellularProviders![dataServiceIdentifier!]
//                                if(currentProvider != nil){
//                                    if(is3GOn()){
//                                        headers[ACTIVE_COUNTRY_NAME] = IsoCountryCodes.find(key: currentProvider!.isoCountryCode ?? "" )?.name ?? currentProvider!.isoCountryCode ?? ""
//                                        headers[ACTIVE_OPERATOR_NAME] = checkValidMCN(mcn: currentProvider!.carrierName)
//
//                                        headers[ACTIVE_MCC] = checkValidMCC(mcc: currentProvider!.mobileCountryCode ?? "")
//                                        headers[ACTIVE_MNC] = checkValidMNC(mnc: currentProvider!.mobileNetworkCode ?? "")
//                                        headers[ACTIVE_DATA_SESSION_SIM] = String(format: "%@%@", checkValidMCC(mcc: currentProvider!.mobileCountryCode ?? ""), checkValidMNC(mnc: currentProvider!.mobileNetworkCode ?? "")
//                                        )
//                                    }else{
//                                        headers[ACTIVE_MCC] = checkValidMCC(mcc: currentProvider!.mobileCountryCode ?? "")
//                                        headers[ACTIVE_MNC] = checkValidMNC(mnc: currentProvider!.mobileNetworkCode ?? "")
//                                        headers[LAST_ACTIVE_DATA_SESSION_SIM] = String(format: "%@%@", checkValidMCC(mcc: currentProvider!.mobileCountryCode ?? ""), checkValidMNC(mnc: currentProvider!.mobileNetworkCode ?? "")
//                                        )
//                                    }
//                                    
//                                }else{
//                                    if(is3GOn()){
//                                        headers[ACTIVE_DATA_SESSION_SIM] = ""
//                                        headers[MNC2_ERROR_MSG] = "nil01"
//                                    }
//                                    
//                                }
//                            }
//                            
//                        } else {
//                            // Fallback on earlier versions
//                            headers[ACTIVE_DATA_SESSION_SIM] = ""
//                            headers[MNC2_ERROR_MSG] = "nil02"
//                        }
//                        
//                        
//                        
//                    }else{
//                        headers[DUAL_SIM_PHONE] = String(format: "%d", carriers.count)
//                    }
//                }
//                
//            } else {
//                // Fallback on earlier versions
//                headers[DUAL_SIM_PHONE] = "no"
//                let info: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()
//                if let carrier = info.subscriberCellularProvider{
//                    headers[MCC1] = checkValidMCC(mcc: carrier.mobileCountryCode)
//                    headers[MNC1] = checkValidMNC(mnc: carrier.mobileNetworkCode)
//                    headers[SIM1_COUNTRY_NAME] = IsoCountryCodes.find(key: carrier.isoCountryCode ?? "" )?.name ?? carrier.isoCountryCode
//                    headers[SIM1_OPERATOR_NAME] = checkValidMCN(mcn: carrier.carrierName)
//                }else{
//                    headers[MCC1] = ""
//                    headers[MNC1] = ""
//                    headers[MNC1_ERROR_MSG] = "nil"
//                }
//            }
        }
        
        return headers
    }
    /// The bundle identifier of the host app, when available.
    public static func hostAppPackage() -> String? {
        return nonEmpty(Bundle.main.bundleIdentifier)
    }

    /// The marketing version (CFBundleShortVersionString) of the host app, when available.
    public static func hostAppVersion() -> String? {
        return nonEmpty(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    /// The build number (CFBundleVersion) of the host app, when available.
    public static func hostAppBuild() -> String? {
        return nonEmpty(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), value.isEmpty == false else {
            return nil
        }
        return value
    }

    public static func activeMNC() -> String{
        // iOS 16+ → immediately return ""
        if #available(iOS 16, *) {
            return ""
        }
        let activeCarrier = getActiveCarrier()
        let mnc = activeCarrier?.mobileNetworkCode ?? ""
        if (mnc == "" || mnc == "65535"){
            return ""
        }
        return mnc
    }
    
    public static func activeMCC() -> String{
        // iOS 16+ → immediately return ""
        if #available(iOS 16, *) {
            return ""
        }
        let activeCarrier = getActiveCarrier()
        let mcc = activeCarrier?.mobileCountryCode ?? ""
        if (mcc == "" || mcc == "65535"){
            return ""
        }
        return mcc
    }
    // internal issue
    public static func checkValidMCC(mcc : String?) -> String {
        // iOS 16+ → immediately return ""
        if #available(iOS 16, *) {
            return ""
        }
        if (mcc == nil || mcc == "" || mcc == "65535"){
            return ""
        }
        return mcc ?? ""
    }
    
    
    // internal issue
    public static func checkValidMNC(mnc : String?) -> String {
        // iOS 16+ → immediately return ""
        if #available(iOS 16, *) {
            return ""
        }
        if (mnc == nil || mnc == "" || mnc == "65535"){
            return ""
        }
        return mnc ?? ""
    }
    
    // internal issue
    public static func checkValidMCN(mcn : String?) -> String {
        // iOS 16+ → immediately return ""
        if #available(iOS 16, *) {
            return ""
        }
        if (mcn == nil || mcn == "" || mcn == "--"){
            return ""
        }
        return mcn ?? ""
    }
    
    private static func getActiveCarrier() -> CTCarrier?{
        if #available(iOS 12.0, *) {
            let info: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()
            if let carriers = info.serviceSubscriberCellularProviders{
                
                if(carriers.count == 1){
                    // 1 sim
                    let carrier: CTCarrier? = carriers.first?.value
                    return carrier
                }
                else if(carriers.count > 1){
                    if #available(iOS 13.0, *) {
                        let dataServiceIdentifier = info.dataServiceIdentifier
                        if(dataServiceIdentifier != nil && info.serviceSubscriberCellularProviders != nil && info.serviceSubscriberCellularProviders?.index(forKey: dataServiceIdentifier!) != nil){
                            let currentProvider  = info.serviceSubscriberCellularProviders![dataServiceIdentifier!]
                            return currentProvider
                        }
                        return nil
                    } else {
                        // Fallback on earlier versions
                        return nil
                    }
                }
            }
        } else {
            // Fallback on earlier versions
            let info: CTTelephonyNetworkInfo = CTTelephonyNetworkInfo()
            if let carrier = info.subscriberCellularProvider{
                return carrier
            }
        }
        
        return nil
    }
    private static func is3GOn()-> Bool{
        let (is3GOn, _ , _ , _) =  ConnectionManager.checkOnly3G()
        if(is3GOn == true){
            return true
        }
        return false
    }
}
