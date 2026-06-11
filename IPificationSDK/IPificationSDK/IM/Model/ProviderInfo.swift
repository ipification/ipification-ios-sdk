//
//  ProviderInfo.swift
//  IPificationSDK
//
//  Created by IPification Dev Team on 16/12/2021.
//  Copyright © 2021 IPification Dev Team. All rights reserved.
//

import Foundation
internal class ProviderInfo {
    /// The provider identifier displayed by the SDK.
    var brand: String?
    /// The deep link used to start authentication with the provider.
    var message: String?
    /// The provider URL scheme used for installation checks.
    var bundleName: String?
    /// Indicates whether the provider app is installed.
    var installed: Bool?
    
    init(){
        
    }
    init(brand: String?, message: String?,bundleName: String?, installed: Bool?) {
        self.brand = brand
        self.message = message
        self.bundleName = bundleName
        self.installed = installed
    }
    func getBrand() -> String{
        if(brand == "wa"){
            return "Whatsapp"
        }
        return brand ?? "" 
    }
    
}
