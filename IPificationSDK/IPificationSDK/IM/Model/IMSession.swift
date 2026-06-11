
//
//  IMSession.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 16/12/2021.
//  Copyright © 2021 IPification Dev Team. All rights reserved.
//

import Foundation
import UIKit

/// Represents an instant-messaging authentication session and its available providers.
public class IMSession{
    /// The backend identifier of the instant-messaging session.
    var sessionID: String?
    /// The deep link for Telegram authentication.
    var telegramLink: String?
    /// The deep link for Viber authentication.
    var viberLink: String?
    /// The deep link for WhatsApp authentication.
    var whatsappLink: String?
    /// The backend endpoint used to complete the IM session.
    var imboxEndpoint: String?
    init(){
        
    }
    init(sessionID: String?, imboxEndpoint: String?, whatsappLink: String?, telegramLink: String?, viberLink: String?) {
        self.sessionID = sessionID
        self.imboxEndpoint = imboxEndpoint
        self.whatsappLink = whatsappLink
        self.telegramLink = telegramLink
        self.viberLink = viberLink
    }
    
    func isValid() -> Bool{
        if(sessionID == nil || sessionID == ""){
            return false
        }
        if(imboxEndpoint == nil || imboxEndpoint == ""){
            return false
        }
        if("\(whatsappLink ?? "")\(telegramLink ?? "")\(viberLink ?? "")" == ""){
            return false
        }
        return true
        
    }
    func availableProviders() -> [ProviderInfo] {
        var list : [ProviderInfo] = []
        if( whatsappLink != nil && whatsappLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "whatsapp://msg")!)
            //            print("whatsappLink",canOpen)
            let wa = ProviderInfo(brand: "wa", message: whatsappLink, bundleName: "whatsapp", installed: canOpen)
            list.append(wa)
        }
        if( telegramLink != nil && telegramLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "telegram://msg")!)
            //            print("telegramLink",canOpen)
            let telegram = ProviderInfo(brand: "telegram", message: telegramLink, bundleName: "telegram", installed: canOpen)
            list.append(telegram)
        }
        if( viberLink != nil && viberLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "viber://msg")!)
            //            print("viberLink",canOpen)
            let viber = ProviderInfo(brand: "viber", message: viberLink, bundleName: "viber", installed: canOpen)
            list.append(viber)
        }
        return list
    }
    
    func canOpen() -> Bool {
        var isExist = false
        if( whatsappLink != nil && whatsappLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "whatsapp://msg")!)
            //            print("whatsappLink",canOpen)
            if(canOpen){
                isExist = true
            }
        }
        if( telegramLink != nil && telegramLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "telegram://msg")!)
            //            print("telegramLink",canOpen)
            if(canOpen){
                isExist = true
            }
            
        }
        if( viberLink != nil && viberLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "viber://msg")!)
            //            print("viberLink",canOpen)
            if(canOpen){
                isExist = true
            }
            
        }
        return isExist
    }
    func findFirstInstalledApp(supportedProviders: [ProviderInfo]?) -> ProviderInfo? {
        if supportedProviders == nil{
            return nil
        }
        let priorityList = IPConfiguration.sharedInstance.IM_PRIORITY_APP_LIST  // wa , telegram , viber
        if(supportedProviders!.isEmpty == false && priorityList.isEmpty == false){
            for priorityItem in priorityList {
                for availableItem in supportedProviders! {
                    if(priorityItem == availableItem.brand && availableItem.installed == true){
                        return availableItem
                    }
                }
            }
        }
        for availableItem in supportedProviders! {
            if(availableItem.installed == true){
                return availableItem
            }
        }
        return nil
    }
    
    func onlyAvailableAppList() -> [ProviderInfo] {
        var list : [ProviderInfo] = []
        if( whatsappLink != nil && whatsappLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "whatsapp://msg")!)
            //            print("whatsappLink",canOpen)
            if(canOpen){
                let wa = ProviderInfo(brand: "wa", message: whatsappLink, bundleName: "whatsapp", installed: canOpen)
                list.append(wa)
            }
        }
        if( telegramLink != nil && telegramLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "telegram://msg")!)
            //            print("telegramLink",canOpen)
            if(canOpen){
                let telegram = ProviderInfo(brand: "telegram", message: telegramLink, bundleName: "telegram", installed: canOpen)
                list.append(telegram)
            }
        }
        if( viberLink != nil && viberLink != ""){
            let canOpen =  UIApplication.shared.canOpenURL(URL(string: "viber://msg")!)
            //            print("viberLink",canOpen)
            if(canOpen){
                let viber = ProviderInfo(brand: "viber", message: viberLink, bundleName: "viber", installed: canOpen)
                list.append(viber)
            }
        }
        return list
    }
}
